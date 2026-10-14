--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

if not _G.RC_SCRIPT_ARGS and gui_mode.accessible() then
    say("GUI blocked (accessible mode) -- use Toggle GUI Mode to override")
    return
end

local main, save_marker_data, load_marker_data, clean_up_orphans
local init_marker_data, get_saud_regions, monitor_playback
local move_to_marker, set_track_selected, play_from_marker
local convert_at_marker, solo, delete_all_saud_take_markers
local source_pos_to_project_pos, get_all_saud_take_markers
local folder_check, get_track_number, get_track_prefix, get_color_table
local find_source_marker, get_item_at_position
local project_pos_to_source_pos, set_take_marker_with_length
local convert_existing_pair_to_take_marker
local remove_take_marker_by_chunk

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

do
    local saud_mode = 0
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local t = {}
        for entry in input:gmatch('([^,]+)') do t[#t + 1] = entry end
        if t[15] then saud_mode = tonumber(t[15]) or 0 end
    end
    if saud_mode ~= 1 then
        MB("Source Audition Mode is not enabled.\n\nPlease activate it in ReaClassical Project Preferences (F5) before using this manager.",
            "Source Audition Manager", 0)
        return
    end
end

package.path      = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui       = require 'imgui' '0.10'

do
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
end
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")
local enum_project_markers = require("ReaClassical_Marker_Enum")

local ctx         = ImGui.CreateContext('Source Audition Marker Manager')
local window_open = true

set_action_options(2)

local COLORS            = {
    { name = "Excellent",     rgba = 0x39FF1499 },
    { name = "Very Good",     rgba = 0x32CD3299 },
    { name = "Good",          rgba = 0x00AD8399 },
    { name = "OK",            rgba = 0xFFFFAA99 },
    { name = "Below Average", rgba = 0xFFBF0099 },
    { name = "Poor",          rgba = 0xFF753899 },
    { name = "Unusable",      rgba = 0xDC143C99 },
    { name = "No Rank",       rgba = 0x00000000 }
}

local marker_data       = {}
local playback_monitor  = false
local current_sao_pos   = nil
local last_play_pos     = -1
local sort_mode         = "time"

local EXT_STATE_SECTION = "ReaClassical_SAI_Manager"

local audition_manager  = NamedCommandLookup("_RS238a7e78cb257490252b3dde18274d00f9a1cf10")
SetToggleCommandState(1, audition_manager, 1)

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    monitor_playback()

    if window_open then
        ImGui.SetNextWindowSize(ctx, 750, 300, ImGui.Cond_FirstUseEver)
        local opened, open_ref = ImGui.Begin(ctx, 'Source Audition Manager', window_open)
        window_open = open_ref

        if opened then
            if ImGui.Button(ctx, '■ Stop', 80, 0) then
                OnStopButton()
                playback_monitor = false
                current_sao_pos = nil
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, 'Delete All Audition Markers', 180, 0) then
                delete_all_saud_take_markers()
            end

            ImGui.Separator(ctx)

            local regions = get_saud_regions()

            if #regions == 0 then
                ImGui.Text(ctx,
                    "No S-AUD take marker regions found. Use Source IN/OUT to create audition pairs.")
            else
                if ImGui.BeginTable(ctx, 'MarkerTable', 7, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg) then
                    ImGui.TableSetupColumn(ctx, 'Audition',
                        ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 60)
                    ImGui.TableSetupColumn(ctx, 'Item',
                        ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 120)
                    ImGui.TableSetupColumn(ctx, 'Time',
                        ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 80)
                    ImGui.TableSetupColumn(ctx, 'Rank',
                        ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 120)
                    ImGui.TableSetupColumn(ctx, 'Notes', ImGui.TableColumnFlags_WidthStretch)
                    ImGui.TableSetupColumn(ctx, 'Convert',
                        ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 60)
                    ImGui.TableSetupColumn(ctx, 'Delete',
                        ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 50)
                    ImGui.TableHeadersRow(ctx)

                    ImGui.TableSetColumnIndex(ctx, 0)
                    local avail = ImGui.GetContentRegionAvail(ctx)
                    local text = "Audition"
                    local text_width = ImGui.CalcTextSize(ctx, text)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                    ImGui.Text(ctx, text)

                    ImGui.TableSetColumnIndex(ctx, 1)
                    local item_header = "Item" .. (sort_mode == "item" and " ▼" or "")
                    if ImGui.Selectable(ctx, item_header .. "##item_sort", false) then
                        sort_mode = "item"
                        save_marker_data()
                    end

                    ImGui.TableSetColumnIndex(ctx, 2)
                    local time_header = "Time" .. (sort_mode == "time" and " ▼" or "")
                    if ImGui.Selectable(ctx, time_header .. "##time_sort", false) then
                        sort_mode = "time"
                        save_marker_data()
                    end

                    ImGui.TableSetColumnIndex(ctx, 3)
                    local rank_header = "Rank" .. (sort_mode == "rank" and " ▼" or "")
                    if ImGui.Selectable(ctx, rank_header .. "##rank_sort", false) then
                        sort_mode = "rank"
                        save_marker_data()
                    end

                    ImGui.TableSetColumnIndex(ctx, 5)
                    avail = ImGui.GetContentRegionAvail(ctx)
                    text = "Convert"
                    text_width = ImGui.CalcTextSize(ctx, text)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                    ImGui.Text(ctx, text)

                    ImGui.TableSetColumnIndex(ctx, 6)
                    avail = ImGui.GetContentRegionAvail(ctx)
                    text = "Delete"
                    text_width = ImGui.CalcTextSize(ctx, text)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                    ImGui.Text(ctx, text)

                    for _, region in ipairs(regions) do
                        ImGui.TableNextRow(ctx)

                        local mdata = marker_data[region.data_key]
                        if not mdata then
                            mdata = { notes = "", color_idx = 8 }
                            marker_data[region.data_key] = mdata
                        end

                        if mdata.color_idx ~= 8 then
                            local color = COLORS[mdata.color_idx].rgba
                            ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg0, color)
                        end

                        ImGui.TableNextColumn(ctx)
                        local avail_width = ImGui.GetContentRegionAvail(ctx)
                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 30) * 0.5)
                        if ImGui.Button(ctx, '▶##play' .. region.data_key, 30, 0) then
                            play_from_marker(region)
                        end

                        ImGui.TableNextColumn(ctx)
                        if ImGui.Selectable(ctx, region.item_name .. '##sel' .. region.data_key, false) then
                            move_to_marker(region.proj_start)
                        end

                        ImGui.TableNextColumn(ctx)
                        ImGui.Text(ctx, region.time_str)

                        ImGui.TableNextColumn(ctx)
                        ImGui.SetNextItemWidth(ctx, -1)
                        if ImGui.BeginCombo(ctx, '##rank' .. region.data_key, COLORS[mdata.color_idx].name) then
                            for j, col in ipairs(COLORS) do
                                local is_selected = (mdata.color_idx == j)
                                if ImGui.Selectable(ctx, col.name, is_selected) then
                                    mdata.color_idx = j
                                    save_marker_data()
                                end
                                if is_selected then
                                    ImGui.SetItemDefaultFocus(ctx)
                                end
                            end
                            ImGui.EndCombo(ctx)
                        end

                        ImGui.TableNextColumn(ctx)
                        ImGui.SetNextItemWidth(ctx, -1)
                        local rv_notes, new_notes = ImGui.InputText(ctx, '##notes' .. region.data_key,
                            mdata.notes)
                        if rv_notes then
                            mdata.notes = new_notes
                            save_marker_data()
                        end

                        ImGui.TableNextColumn(ctx)
                        avail_width = ImGui.GetContentRegionAvail(ctx)
                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 40) * 0.5)
                        if region.is_real then
                            local cx, cy = ImGui.GetCursorScreenPos(ctx)
                            local draw_list = ImGui.GetWindowDrawList(ctx)
                            local frame_h = ImGui.GetFrameHeight(ctx)
                            ImGui.DrawList_AddRectFilled(draw_list, cx, cy, cx + 40, cy + frame_h, 0x32CD32CC, 4.0)
                            ImGui.Dummy(ctx, 40, frame_h)
                        else
                            if ImGui.Button(ctx, '⚡##convert' .. region.data_key, 40, 0) then
                                convert_at_marker(region)
                            end
                        end

                        ImGui.TableNextColumn(ctx)
                        avail_width = ImGui.GetContentRegionAvail(ctx)
                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 30) * 0.5)
                        if ImGui.Button(ctx, '✕##delete' .. region.data_key, 30, 0) then
                            Undo_BeginBlock()
                            if region.is_real then
                                local i = 0
                                while true do
                                    local project, _ = EnumProjects(i)
                                    if project == nil then break end
                                    DeleteProjectMarker(project, 998, false)
                                    DeleteProjectMarker(project, 999, false)
                                    i = i + 1
                                end
                            else
                                remove_take_marker_by_chunk(region.item, region.src_start, "S-AUD")
                            end
                            marker_data[region.data_key] = nil
                            save_marker_data()
                            Undo_EndBlock("Delete audition pair", -1)
                            UpdateArrange()
                        end
                    end

                    ImGui.EndTable(ctx)
                end
            end
            if ImGui.IsWindowFocused(ctx) and gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end
            ImGui.End(ctx)
        end
    end

    if window_open then
        defer(main)
    else
        clean_up_orphans()
        SetToggleCommandState(1, audition_manager, 0)
    end
end

function delete_all_saud_take_markers()
    Undo_BeginBlock()
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then break end
        local num_items = CountMediaItems(project)
        for j = 0, num_items - 1 do
            local item = GetMediaItem(project, j)
            if item then
                local take = GetActiveTake(item)
                if take then
                    local num_markers = GetNumTakeMarkers(take)
                    for m = num_markers - 1, 0, -1 do
                        local _, name = GetTakeMarker(take, m)
                        if name == "S-AUD" then
                            DeleteTakeMarker(take, m)
                        end
                    end
                end
            end
        end
        i = i + 1
    end

    marker_data = {}
    save_marker_data()

    Undo_EndBlock("Delete all S-AUD take markers", -1)
    UpdateArrange()
end

function get_all_saud_take_markers()
    local results = {}
    local num_items = CountMediaItems(0)

    for j = 0, num_items - 1 do
        local item = GetMediaItem(0, j)
        if item then
            local take = GetActiveTake(item)
            if take then
                local _, chunk = GetItemStateChunk(item, "", false)
                if chunk and chunk:find("S%-AUD") then
                    local item_guid = BR_GetMediaItemGUID(item)
                    local item_track = GetMediaItem_Track(item)
                    local track_number = math.floor(get_track_number(item_track))

                    local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    local item_name = take_name ~= "" and take_name or ("Track " .. track_number)

                    local _, track_name = GetSetMediaTrackInfo_String(item_track, "P_NAME", "", false)
                    local track_prefix = track_name:match("^([^:]+:)")
                    if track_prefix then
                        item_name = track_prefix .. " " .. item_name
                    end

                    for src_start_str, name, _, length_str in
                    chunk:gmatch('TKM%s+(%-?[%d%.e%+%-]+)%s+(%S+)%s+(%S+)%s+(%-?[%d%.e%+%-]+)')
                    do
                        if name == "S-AUD" then
                            local src_start = tonumber(src_start_str)
                            local length = tonumber(length_str)
                            if src_start and length and length > 0 then
                                local src_end = src_start + length
                                local proj_start = source_pos_to_project_pos(take, item, src_start)
                                local proj_end = source_pos_to_project_pos(take, item, src_end)
                                if proj_start and proj_end then
                                    local data_key = item_guid .. ":" .. string.format("%.10g", src_start)
                                    table.insert(results, {
                                        item = item,
                                        take = take,
                                        item_guid = item_guid,
                                        item_name = item_name,
                                        track_number = track_number,
                                        src_start = src_start,
                                        src_end = src_end,
                                        proj_start = proj_start,
                                        proj_end = proj_end,
                                        data_key = data_key,
                                        time_str = format_timestr(proj_start, ""),
                                        color_idx = marker_data[data_key]
                                            and marker_data[data_key].color_idx or 8
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return results
end

function get_saud_regions()
    local regions = get_all_saud_take_markers()

    local proj = EnumProjects(-1)
    local in_pos = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos = find_source_marker(proj, 999, "SOURCE-OUT")

    local _, in_stored = GetProjExtState(0, "ReaClassical", "SourceInTrackNum")
    local _, out_stored = GetProjExtState(0, "ReaClassical", "SourceOutTrackNum")
    local in_track_num = tonumber(in_stored)
    local out_track_num = tonumber(out_stored)

    if in_pos and out_pos and in_track_num and out_track_num
        and in_track_num == out_track_num and in_pos < out_pos then
        local item, take = get_item_at_position(in_pos, in_track_num)
        if item and take then
            local item_guid = BR_GetMediaItemGUID(item)
            local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local item_name = take_name ~= "" and take_name or ("Track " .. in_track_num)

            local item_track = GetMediaItem_Track(item)
            local _, track_name = GetSetMediaTrackInfo_String(item_track, "P_NAME", "", false)
            local track_prefix = track_name:match("^([^:]+:)")
            if track_prefix then
                item_name = track_prefix .. " " .. item_name
            end

            local src_start = project_pos_to_source_pos(take, item, in_pos)
            local src_end = project_pos_to_source_pos(take, item, out_pos)
            local data_key = item_guid .. ":" .. string.format("%.10g", src_start)

            table.insert(regions, {
                item = item,
                take = take,
                item_guid = item_guid,
                item_name = item_name,
                track_number = in_track_num,
                src_start = src_start,
                src_end = src_end,
                proj_start = in_pos,
                proj_end = out_pos,
                data_key = data_key,
                time_str = format_timestr(in_pos, ""),
                color_idx = marker_data[data_key]
                    and marker_data[data_key].color_idx or 8,
                is_real = true
            })
        end
    end

    if sort_mode == "time" then
        table.sort(regions, function(a, b) return a.proj_start < b.proj_start end)
    elseif sort_mode == "item" then
        table.sort(regions, function(a, b)
            if a.item_name == b.item_name then
                return a.proj_start < b.proj_start
            end
            return a.item_name < b.item_name
        end)
    elseif sort_mode == "rank" then
        table.sort(regions, function(a, b)
            if a.color_idx == b.color_idx then
                return a.proj_start < b.proj_start
            end
            if a.color_idx == 8 then return false end
            if b.color_idx == 8 then return true end
            return a.color_idx < b.color_idx
        end)
    end

    return regions
end

function save_marker_data()
    SetExtState(EXT_STATE_SECTION, "sort_mode", sort_mode, true)

    for data_key, data in pairs(marker_data) do
        SetProjExtState(0, "saud_marker", data_key .. "_NOTES", data.notes or "")
        SetProjExtState(0, "saud_marker", data_key .. "_COLOR", tostring(data.color_idx or 8))
    end

    MarkProjectDirty(0)
end

function load_marker_data()
    if HasExtState(EXT_STATE_SECTION, "sort_mode") then
        sort_mode = GetExtState(EXT_STATE_SECTION, "sort_mode")
        if sort_mode ~= "time" and sort_mode ~= "item" and sort_mode ~= "rank" then
            sort_mode = "time"
        end
    end
end

function clean_up_orphans()
    local current_keys = {}
    local regions = get_all_saud_take_markers()
    for _, region in ipairs(regions) do
        current_keys[region.data_key] = true
    end

    local proj = EnumProjects(-1)
    local in_pos = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos = find_source_marker(proj, 999, "SOURCE-OUT")
    local _, in_stored = GetProjExtState(0, "ReaClassical", "SourceInTrackNum")
    local in_track_num = tonumber(in_stored)
    if in_pos and out_pos and in_track_num then
        local item, take = get_item_at_position(in_pos, in_track_num)
        if item and take then
            local item_guid = BR_GetMediaItemGUID(item)
            local src_start = project_pos_to_source_pos(take, item, in_pos)
            local data_key = item_guid .. ":" .. string.format("%.10g", src_start)
            current_keys[data_key] = true
        end
    end

    local all_keys = {}
    local i = 0
    while true do
        local ok, key = EnumProjExtState(0, "saud_marker", i)
        if not ok then break end
        table.insert(all_keys, key)
        i = i + 1
    end

    local deleted_count = 0
    for _, key in ipairs(all_keys) do
        local data_key = key:match("^(.+)_NOTES$") or key:match("^(.+)_COLOR$")
        if data_key and not current_keys[data_key] then
            SetProjExtState(0, "saud_marker", key, "")
            deleted_count = deleted_count + 1
        end
    end

    if deleted_count > 0 then
        MarkProjectDirty(0)
    end
end

function init_marker_data()
    marker_data = {}
    local regions = get_all_saud_take_markers()

    for _, region in ipairs(regions) do
        local saved_notes = ""
        local saved_color = 8

        local has_notes, notes = GetProjExtState(0, "saud_marker", region.data_key .. "_NOTES")
        local has_color, color = GetProjExtState(0, "saud_marker", region.data_key .. "_COLOR")

        if has_notes == 1 then saved_notes = notes end
        if has_color == 1 then saved_color = tonumber(color) or 8 end

        marker_data[region.data_key] = {
            notes = saved_notes,
            color_idx = saved_color
        }
    end

    local proj = EnumProjects(-1)
    local in_pos = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos = find_source_marker(proj, 999, "SOURCE-OUT")
    local _, in_stored = GetProjExtState(0, "ReaClassical", "SourceInTrackNum")
    local in_track_num = tonumber(in_stored)
    if in_pos and out_pos and in_track_num then
        local item, take = get_item_at_position(in_pos, in_track_num)
        if item and take then
            local item_guid = BR_GetMediaItemGUID(item)
            local src_start = project_pos_to_source_pos(take, item, in_pos)
            local data_key = item_guid .. ":" .. string.format("%.10g", src_start)

            local saved_notes = ""
            local saved_color = 8
            local has_notes, notes = GetProjExtState(0, "saud_marker", data_key .. "_NOTES")
            local has_color, color = GetProjExtState(0, "saud_marker", data_key .. "_COLOR")
            if has_notes == 1 then saved_notes = notes end
            if has_color == 1 then saved_color = tonumber(color) or 8 end

            marker_data[data_key] = {
                notes = saved_notes,
                color_idx = saved_color
            }
        end
    end
end

function monitor_playback()
    if not playback_monitor then
        return
    end

    local play_state = GetPlayState()

    if play_state & 1 == 1 and current_sao_pos then
        local play_pos = GetPlayPosition()

        if play_pos >= current_sao_pos and last_play_pos < current_sao_pos then
            OnStopButton()
            playback_monitor = false
            current_sao_pos = nil
        end

        last_play_pos = play_pos
    else
        if play_state & 1 == 0 then
            playback_monitor = false
            current_sao_pos = nil
        end
    end
end

function move_to_marker(pos)
    SetEditCurPos(pos, true, true)
end

function set_track_selected(track_number)
    if track_number then
        for i = 0, CountTracks(0) - 1 do
            local tr = GetTrack(0, i)
            SetTrackSelected(tr, false)
        end

        local track = GetTrack(0, track_number - 1)
        if track then
            SetTrackSelected(track, true)
            solo()
        end
    end
end

function play_from_marker(region)
    set_track_selected(region.track_number)

    current_sao_pos = region.proj_end
    playback_monitor = true
    last_play_pos = region.proj_start - 1

    SetEditCurPos(region.proj_start, true, true)
    OnPlayButton()
end

function convert_at_marker(region)
    Undo_BeginBlock()

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")

    local item_track = GetMediaItem_Track(region.item)
    local track_number = region.track_number
    local track_prefix = get_track_prefix(item_track)

    local colors = get_color_table()
    local marker_color
    if workflow == "Horizontal" then
        marker_color = colors.source_marker
    else
        marker_color = item_track and GetTrackColor(item_track) or colors.source_marker
    end

    local proj = EnumProjects(-1)
    convert_existing_pair_to_take_marker(proj)

    local in_label = (workflow == "Horizontal") and "SOURCE-IN" or (track_prefix .. ":SOURCE-IN")
    local out_label = (workflow == "Horizontal") and "SOURCE-OUT" or (track_prefix .. ":SOURCE-OUT")
    AddProjectMarker2(0, false, region.proj_start, 0, in_label, 998, marker_color)
    AddProjectMarker2(0, false, region.proj_end, 0, out_label, 999, marker_color)
    SetProjExtState(0, "ReaClassical", "SourceInTrackNum", tostring(track_number))
    SetProjExtState(0, "ReaClassical", "SourceOutTrackNum", tostring(track_number))

    remove_take_marker_by_chunk(region.item, region.src_start, "S-AUD")

    set_track_selected(track_number)
    SetEditCurPos(region.proj_start, true, true)

    Undo_EndBlock("Convert S-AUD to SOURCE-IN/OUT", -1)
    UpdateArrange()
end

function convert_existing_pair_to_take_marker(proj)
    local black_color = ColorToNative(0, 0, 0) | 0x1000000

    local in_pos = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos = find_source_marker(proj, 999, "SOURCE-OUT")

    local _, in_stored = GetProjExtState(0, "ReaClassical", "SourceInTrackNum")
    local _, out_stored = GetProjExtState(0, "ReaClassical", "SourceOutTrackNum")
    local in_track_num = tonumber(in_stored)
    local out_track_num = tonumber(out_stored)

    if not in_pos or not out_pos or not in_track_num or not out_track_num
        or in_track_num ~= out_track_num then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    if in_pos >= out_pos then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    local item_in, take_in = get_item_at_position(in_pos, in_track_num)
    local item_out, _ = get_item_at_position(out_pos, in_track_num)

    if not item_in or not item_out or item_in ~= item_out then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    local _, existing_chunk = GetItemStateChunk(item_in, "", false)
    if existing_chunk and existing_chunk:find("\n%s*TKM%s+%-?[%d%.e%+%-]+%s+S%-AUD%s+") then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    if take_in then
        local src_in = project_pos_to_source_pos(take_in, item_in, in_pos)
        local src_out = project_pos_to_source_pos(take_in, item_in, out_pos)
        if src_in and src_out then
            set_take_marker_with_length(item_in, src_in, src_out, "S-AUD", black_color)
        end
    end

    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then break end
        DeleteProjectMarker(project, 998, false)
        DeleteProjectMarker(project, 999, false)
        i = i + 1
    end
end

function remove_take_marker_by_chunk(item, src_start, name)
    local _, chunk = GetItemStateChunk(item, "", false)
    if not chunk or chunk == "" then return end

    local new_lines = {}
    local removed = false
    for line in chunk:gmatch("[^\n]+") do
        if not removed then
            local tm_src, tm_name = line:match(
                '%s*TKM%s+(%-?[%d%.e%+%-]+)%s+(%S+)'
            )
            if tm_name == name and tm_src then
                local tm_pos = tonumber(tm_src)
                if tm_pos and math.abs(tm_pos - src_start) < 0.0001 then
                    removed = true
                    goto continue
                end
            end
        end
        new_lines[#new_lines + 1] = line
        ::continue::
    end

    if removed then
        SetItemStateChunk(item, table.concat(new_lines, "\n"), false)
    end
end

function set_take_marker_with_length(item, src_start, src_end, name, color)
    local _, chunk = GetItemStateChunk(item, "", false)
    if not chunk or chunk == "" then return end

    local length = src_end - src_start
    local marker_line = string.format(
        '    TKM %.14g %s %d %.14g',
        src_start, name, color, length
    )

    local insert_pos = chunk:find("\n>%s*$")
    if insert_pos then
        chunk = chunk:sub(1, insert_pos - 1) .. "\n" .. marker_line .. chunk:sub(insert_pos)
    else
        chunk = chunk:gsub("(>)%s*$", marker_line .. "\n>")
    end

    SetItemStateChunk(item, chunk, false)
end

function find_source_marker(proj, marker_id, marker_type)
    local num_markers = GetNumRegionsOrMarkers(proj)

    for i = 0, num_markers - 1 do
        local _, isrgn, pos, _, raw_label, markrgnindexnumber = enum_project_markers(proj, i)
        if not isrgn and markrgnindexnumber == marker_id then
            local label = raw_label:match(":(.+)$") or raw_label
            if label == marker_type then
                return pos
            end
        end
    end

    return nil
end

function get_item_at_position(proj_pos, track_number)
    local tr = GetTrack(0, track_number - 1)
    if not tr then return nil, nil end

    local tracks_to_check = { tr }
    if GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
        local depth = 1
        local idx = track_number
        while depth > 0 and idx < CountTracks(0) do
            local child = GetTrack(0, idx)
            if child then
                tracks_to_check[#tracks_to_check + 1] = child
                depth = depth + GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
            end
            idx = idx + 1
        end
    end

    for _, check_tr in ipairs(tracks_to_check) do
        local num_items = CountTrackMediaItems(check_tr)
        for j = 0, num_items - 1 do
            local item = GetTrackMediaItem(check_tr, j)
            if item then
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                if proj_pos >= item_pos and proj_pos <= item_pos + item_len then
                    local take = GetActiveTake(item)
                    if take then return item, take end
                end
            end
        end
    end

    return nil, nil
end

function source_pos_to_project_pos(take, item, src_pos)
    if not take or not item then return nil end
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local take_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local take_rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if take_rate == 0 then return nil end
    return item_pos + (src_pos - take_offset) / take_rate
end

function project_pos_to_source_pos(take, item, proj_pos)
    if not take or not item then return nil end
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local take_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local take_rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    return take_offset + (proj_pos - item_pos) * take_rate
end

function folder_check()
    local folders = 0
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        end
    end
    return folders
end

function get_track_number(track)
    if not track then track = GetSelectedTrack(0, 0) end
    if folder_check() == 0 or track == nil then
        return 1
    elseif GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        return GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    else
        local folder = GetParentTrack(track)
        return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
    end
end

function get_track_prefix(track)
    if not track then track = GetSelectedTrack(0, 0) end
    if folder_check() == 0 or track == nil then
        return "1"
    end
    local folder
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        folder = track
    else
        folder = GetParentTrack(track)
    end
    if folder then
        local _, name = GetTrackName(folder)
        local prefix = name:match("^(.-):")
        if prefix then return prefix end
    end
    return tostring(math.floor(GetMediaTrackInfo_Value(folder or track, "IP_TRACKNUMBER")))
end

function solo()
    local cache = track_scan.build()
    local set_track_value = track_write.set_track_value
    local set_send_value = track_write.set_send_value

    Main_OnCommand(40491, 0)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if cache.tags[track].listenback then
            set_track_value(track, "I_RECARM", 1)
        end
    end
    local selected_track = GetSelectedTrack(0, 0)
    local parent = selected_track and GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH") or 0

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local t = cache.tags[track]
        local mixer_state = t.mixer
        local aux_state = t.aux
        local submix_state = t.submix
        local rt_state = t.roomtone
        local ref_state = t.rcref
        local listenback_state = t.listenback
        local rcmaster_state = t.rcmaster
        local playback_state = t.playback

        if mixer_state or aux_state or submix_state or rt_state
            or ref_state or listenback_state or playback_state then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                set_send_value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state or aux_state or submix_state or rt_state
                or ref_state or listenback_state or rcmaster_state or playback_state) then
            if IsTrackSelected(track) and parent ~= 1 then
                set_track_value(track, "I_SOLO", 2)
                set_track_value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                set_track_value(track, "I_SOLO", 0)
                set_track_value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                set_track_value(track, "B_MUTE", 1)
                set_track_value(track, "I_SOLO", 0)
            else
                set_track_value(track, "B_MUTE", 0)
                set_track_value(track, "I_SOLO", 0)
            end
        end

        if rt_state then
            if IsTrackSelected(track) then
                set_track_value(track, "B_MUTE", 0)
                set_track_value(track, "I_SOLO", 0)
            end
        end

        if ref_state then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0)
                mute_state = 0
                solo_state = 1
            elseif ref_is_guide == 1 then
                mute_state = 0
                solo_state = 0
            end

            set_track_value(track, "B_MUTE", mute_state)
            set_track_value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state then
            set_track_value(track, "B_MUTE", 0)
            set_track_value(track, "I_SOLO", 0)
        end
    end
end

function get_color_table()
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
    return require("ReaClassical_Colors_Table")
end

load_marker_data()
clean_up_orphans()
init_marker_data()
defer(main)
