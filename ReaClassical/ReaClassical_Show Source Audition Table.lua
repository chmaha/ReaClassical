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

local main, save_marker_data, load_marker_data, clean_up_orphans
local init_marker_data, get_saud_regions, monitor_playback
local move_to_marker, set_track_selected, play_from_marker
local convert_at_marker, solo, delete_all_saud_take_markers
local source_pos_to_project_pos, get_all_saud_take_markers
local folder_check, get_track_number, get_color_table, get_path
local find_source_marker, get_item_at_position
local project_pos_to_source_pos, set_take_marker_with_length
local convert_existing_pair_to_take_marker
local remove_take_marker_by_chunk

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path      = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui       = require 'imgui' '0.10'

local ctx         = ImGui.CreateContext('Source Audition Marker Manager')
local window_open = true

set_action_options(2)

-- Rank color options (slightly desaturated for better readability)
local COLORS                        = {
    { name = "Excellent",     rgba = 0x39FF1499 }, -- Bright lime green
    { name = "Very Good",     rgba = 0x32CD3299 }, -- Lime green
    { name = "Good",          rgba = 0x00AD8399 }, -- Teal green
    { name = "OK",            rgba = 0xFFFFAA99 }, -- Soft yellow
    { name = "Below Average", rgba = 0xFFBF0099 }, -- Gold/amber
    { name = "Poor",          rgba = 0xFF753899 }, -- Orange
    { name = "Unusable",      rgba = 0xDC143C99 }, -- Crimson red
    { name = "No Rank",       rgba = 0x00000000 }  -- Transparent for default table color
}

-- Storage for marker data (keyed by item_guid:srcpos)
local marker_data                   = {}
local playback_monitor              = false
local current_sao_pos               = nil
local last_play_pos                 = -1
local sort_mode                     = "time" -- "time", "item", or "rank"

-- ExtState keys for persistent storage
local EXT_STATE_SECTION             = "ReaClassical_SAI_Manager"

local audition_manager              = NamedCommandLookup("_RS238a7e78cb257490252b3dde18274d00f9a1cf10")
SetToggleCommandState(1, audition_manager, 1)

---------------------------------------------------------------------

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    -- Monitor playback for auto-stop at region end
    monitor_playback()

    if window_open then
        ImGui.SetNextWindowSize(ctx, 750, 300, ImGui.Cond_FirstUseEver)
        local opened, open_ref = ImGui.Begin(ctx, 'Source Audition Manager', window_open)
        window_open = open_ref

        if opened then
            -- Global stop button at the top
            if ImGui.Button(ctx, '■ Stop', 80, 0) then
                OnStopButton()
                playback_monitor = false
                current_sao_pos = nil
            end

            -- Delete all S-AUD take markers button
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
                -- Create table
                if ImGui.BeginTable(ctx, 'MarkerTable', 7, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg) then
                    -- Setup columns
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

                    -- Manually draw centered header for Audition
                    ImGui.TableSetColumnIndex(ctx, 0)
                    local avail = ImGui.GetContentRegionAvail(ctx)
                    local text = "Audition"
                    local text_width = ImGui.CalcTextSize(ctx, text)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                    ImGui.Text(ctx, text)

                    -- Clickable Item header to sort by item name
                    ImGui.TableSetColumnIndex(ctx, 1)
                    local item_header = "Item" .. (sort_mode == "item" and " ▼" or "")
                    if ImGui.Selectable(ctx, item_header .. "##item_sort", false) then
                        sort_mode = "item"
                        save_marker_data()
                    end

                    -- Clickable Time header to sort by timeline
                    ImGui.TableSetColumnIndex(ctx, 2)
                    local time_header = "Time" .. (sort_mode == "time" and " ▼" or "")
                    if ImGui.Selectable(ctx, time_header .. "##time_sort", false) then
                        sort_mode = "time"
                        save_marker_data()
                    end

                    -- Clickable Rank header to sort by rank
                    ImGui.TableSetColumnIndex(ctx, 3)
                    local rank_header = "Rank" .. (sort_mode == "rank" and " ▼" or "")
                    if ImGui.Selectable(ctx, rank_header .. "##rank_sort", false) then
                        sort_mode = "rank"
                        save_marker_data()
                    end

                    -- Manually draw centered header for Convert
                    ImGui.TableSetColumnIndex(ctx, 5)
                    avail = ImGui.GetContentRegionAvail(ctx)
                    text = "Convert"
                    text_width = ImGui.CalcTextSize(ctx, text)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                    ImGui.Text(ctx, text)

                    -- Manually draw centered header for Delete
                    ImGui.TableSetColumnIndex(ctx, 6)
                    avail = ImGui.GetContentRegionAvail(ctx)
                    text = "Delete"
                    text_width = ImGui.CalcTextSize(ctx, text)
                    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail - text_width) * 0.5)
                    ImGui.Text(ctx, text)

                    -- Display regions
                    for _, region in ipairs(regions) do
                        ImGui.TableNextRow(ctx)

                        -- Get marker data
                        local mdata = marker_data[region.data_key]
                        if not mdata then
                            mdata = { notes = "", color_idx = 8 }
                            marker_data[region.data_key] = mdata
                        end

                        -- Apply row background color based on rank if set
                        if mdata.color_idx ~= 8 then
                            local color = COLORS[mdata.color_idx].rgba
                            ImGui.TableSetBgColor(ctx, ImGui.TableBgTarget_RowBg0, color)
                        end

                        -- Column 1: Play button
                        ImGui.TableNextColumn(ctx)
                        local avail_width = ImGui.GetContentRegionAvail(ctx)
                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 30) * 0.5)
                        if ImGui.Button(ctx, '▶##play' .. region.data_key, 30, 0) then
                            play_from_marker(region)
                        end

                        -- Column 2: Item name (clickable to navigate)
                        ImGui.TableNextColumn(ctx)
                        if ImGui.Selectable(ctx, region.item_name .. '##sel' .. region.data_key, false) then
                            move_to_marker(region.proj_start)
                        end

                        -- Column 3: Time range
                        ImGui.TableNextColumn(ctx)
                        ImGui.Text(ctx, region.time_str)

                        -- Column 4: Rank picker
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

                        -- Column 5: Notes input
                        ImGui.TableNextColumn(ctx)
                        ImGui.SetNextItemWidth(ctx, -1)
                        local rv_notes, new_notes = ImGui.InputText(ctx, '##notes' .. region.data_key,
                            mdata.notes)
                        if rv_notes then
                            mdata.notes = new_notes
                            save_marker_data()
                        end

                        -- Column 6: Convert button or green indicator for real pair
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

                        -- Column 7: Delete button
                        ImGui.TableNextColumn(ctx)
                        avail_width = ImGui.GetContentRegionAvail(ctx)
                        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (avail_width - 30) * 0.5)
                        if ImGui.Button(ctx, '✕##delete' .. region.data_key, 30, 0) then
                            Undo_BeginBlock()
                            if region.is_real then
                                -- Delete the real SOURCE-IN/OUT project markers
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

            ImGui.End(ctx)
        end
    end

    if window_open then
        defer(main)
    else
        -- Window is closing, run cleanup before exit
        clean_up_orphans()
        SetToggleCommandState(1, audition_manager, 0)
    end
end

---------------------------------------------------------------------

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

    -- Clear marker data since all markers are deleted
    marker_data = {}
    save_marker_data()

    Undo_EndBlock("Delete all S-AUD take markers", -1)
    UpdateArrange()
end

---------------------------------------------------------------------

function get_all_saud_take_markers()
    -- Walk all items in current project, parse chunks for S-AUD TKM lines with length
    local results = {}
    local num_items = CountMediaItems(0)

    for j = 0, num_items - 1 do
        local item = GetMediaItem(0, j)
        if item then
            local take = GetActiveTake(item)
            if take then
                local _, chunk = GetItemStateChunk(item, "", false)
                if chunk and chunk:find("S%-AUD") then
                    -- Get item GUID for data key
                    local item_guid = BR_GetMediaItemGUID(item)
                    local item_track = GetMediaItem_Track(item)
                    local track_number = math.floor(get_track_number(item_track))

                    -- Get item name for display
                    local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    local item_name = take_name ~= "" and take_name or ("Track " .. track_number)

                    -- Prefix with track name prefix (e.g. "S2:", "D:") if present
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

---------------------------------------------------------------------

function get_saud_regions()
    local regions = get_all_saud_take_markers()

    -- Also include the real SOURCE-IN/OUT pair if one exists
    local proj = EnumProjects(-1)
    local in_pos, in_track_num = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos, out_track_num = find_source_marker(proj, 999, "SOURCE-OUT")

    if in_pos and out_pos and in_track_num and out_track_num
        and in_track_num == out_track_num and in_pos < out_pos then
        local item, take = get_item_at_position(in_pos, in_track_num)
        if item and take then
            local item_guid = BR_GetMediaItemGUID(item)
            local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local item_name = take_name ~= "" and take_name or ("Track " .. in_track_num)

            -- Prefix with track name prefix (e.g. "S2:", "D:") if present
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

    -- Sort based on current sort mode
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

---------------------------------------------------------------------

function save_marker_data()
    -- Save sort mode
    SetExtState(EXT_STATE_SECTION, "sort_mode", sort_mode, true)

    -- Save each marker's data using item_guid:srcpos as key
    -- First clear old entries
    -- (We just overwrite with current data)
    for data_key, data in pairs(marker_data) do
        SetProjExtState(0, "saud_marker", data_key .. "_NOTES", data.notes or "")
        SetProjExtState(0, "saud_marker", data_key .. "_COLOR", tostring(data.color_idx or 8))
    end

    MarkProjectDirty(0)
end

---------------------------------------------------------------------

function load_marker_data()
    -- Load sort mode
    if HasExtState(EXT_STATE_SECTION, "sort_mode") then
        sort_mode = GetExtState(EXT_STATE_SECTION, "sort_mode")
        -- Remove invalid sort modes from old version
        if sort_mode ~= "time" and sort_mode ~= "item" and sort_mode ~= "rank" then
            sort_mode = "time"
        end
    end
end

---------------------------------------------------------------------

function clean_up_orphans()
    -- Collect all current S-AUD data keys
    local current_keys = {}
    local regions = get_all_saud_take_markers()
    for _, region in ipairs(regions) do
        current_keys[region.data_key] = true
    end

    -- Also include the real pair's data key if it exists
    local proj = EnumProjects(-1)
    local in_pos, in_track_num = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos = find_source_marker(proj, 999, "SOURCE-OUT")
    if in_pos and out_pos and in_track_num then
        local item, take = get_item_at_position(in_pos, in_track_num)
        if item and take then
            local item_guid = BR_GetMediaItemGUID(item)
            local src_start = project_pos_to_source_pos(take, item, in_pos)
            local data_key = item_guid .. ":" .. string.format("%.10g", src_start)
            current_keys[data_key] = true
        end
    end

    -- Collect ALL ProjExtState keys for saud_marker
    local all_keys = {}
    local i = 0
    while true do
        local ok, key = EnumProjExtState(0, "saud_marker", i)
        if not ok then break end
        table.insert(all_keys, key)
        i = i + 1
    end

    -- Delete orphaned entries
    local deleted_count = 0
    for _, key in ipairs(all_keys) do
        -- Extract data_key from the stored key (remove _NOTES or _COLOR suffix)
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

---------------------------------------------------------------------

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

    -- Also load data for the real pair if it exists
    local proj = EnumProjects(-1)
    local in_pos, in_track_num = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos = find_source_marker(proj, 999, "SOURCE-OUT")
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

---------------------------------------------------------------------

function monitor_playback()
    if not playback_monitor then
        return
    end

    local play_state = GetPlayState()

    -- If playing and we have a target end position
    if play_state & 1 == 1 and current_sao_pos then
        local play_pos = GetPlayPosition()

        -- Check if we've reached or passed the end position
        if play_pos >= current_sao_pos and last_play_pos < current_sao_pos then
            OnStopButton()
            playback_monitor = false
            current_sao_pos = nil
        end

        last_play_pos = play_pos
    else
        -- Playback stopped, reset monitoring
        if play_state & 1 == 0 then
            playback_monitor = false
            current_sao_pos = nil
        end
    end
end

---------------------------------------------------------------------

function move_to_marker(pos)
    SetEditCurPos(pos, true, true)
end

---------------------------------------------------------------------

function set_track_selected(track_number)
    if track_number then
        -- Unselect all tracks first
        for i = 0, CountTracks(0) - 1 do
            local tr = GetTrack(0, i)
            SetTrackSelected(tr, false)
        end

        -- Select the parent track (track_number - 1 because tracks are 0-indexed)
        local track = GetTrack(0, track_number - 1)
        if track then
            SetTrackSelected(track, true)
            solo()
        end
    end
end

---------------------------------------------------------------------

function play_from_marker(region)
    set_track_selected(region.track_number)

    -- Set the end position for auto-stop
    current_sao_pos = region.proj_end
    playback_monitor = true
    last_play_pos = region.proj_start - 1

    -- Move to position and play
    SetEditCurPos(region.proj_start, true, true)
    OnPlayButton()
end

---------------------------------------------------------------------

function convert_at_marker(region)
    Undo_BeginBlock()

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")

    -- Get the track and color for the new project markers
    local item_track = GetMediaItem_Track(region.item)
    local track_number = region.track_number

    local colors = get_color_table()
    local marker_color
    if workflow == "Horizontal" then
        marker_color = colors.source_marker
    else
        marker_color = item_track and GetTrackColor(item_track) or colors.source_marker
    end

    -- Before placing new project markers, convert any existing pair to a take marker
    local proj = EnumProjects(-1)
    convert_existing_pair_to_take_marker(proj)

    -- Add real project markers
    AddProjectMarker2(0, false, region.proj_start, 0,
        track_number .. ":SOURCE-IN", 998, marker_color)
    AddProjectMarker2(0, false, region.proj_end, 0,
        track_number .. ":SOURCE-OUT", 999, marker_color)

    -- Remove the S-AUD take marker
    remove_take_marker_by_chunk(region.item, region.src_start, "S-AUD")

    -- Select the track and move cursor
    set_track_selected(track_number)
    SetEditCurPos(region.proj_start, true, true)

    Undo_EndBlock("Convert S-AUD to SOURCE-IN/OUT", -1)
    UpdateArrange()
end

---------------------------------------------------------------------

function convert_existing_pair_to_take_marker(proj)
    local black_color = ColorToNative(0, 0, 0) | 0x1000000

    local in_pos, in_track_num = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos, out_track_num = find_source_marker(proj, 999, "SOURCE-OUT")

    -- No pair or mismatched track numbers: just delete both
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

    -- Guard: backwards pair
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

    -- Guard: must be in the same item
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

    -- Guard: target item already has an S-AUD take marker
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

    -- Convert pair to take marker
    if take_in then
        local src_in = project_pos_to_source_pos(take_in, item_in, in_pos)
        local src_out = project_pos_to_source_pos(take_in, item_in, out_pos)
        if src_in and src_out then
            set_take_marker_with_length(item_in, src_in, src_out, "S-AUD", black_color)
        end
    end

    -- Delete both project markers across all tabs
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then break end
        DeleteProjectMarker(project, 998, false)
        DeleteProjectMarker(project, 999, false)
        i = i + 1
    end
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function find_source_marker(proj, marker_id, marker_type)
    local _, num_markers, num_regions = CountProjectMarkers(proj)

    for i = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, _, raw_label, markrgnindexnumber = EnumProjectMarkers2(proj, i)
        if not isrgn and markrgnindexnumber == marker_id then
            local number, label = raw_label:match("(%d+):(.+)")
            if label and label == marker_type then
                return pos, tonumber(number)
            end
        end
    end

    return nil, nil
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function source_pos_to_project_pos(take, item, src_pos)
    if not take or not item then return nil end
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local take_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local take_rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if take_rate == 0 then return nil end
    return item_pos + (src_pos - take_offset) / take_rate
end

---------------------------------------------------------------------

function project_pos_to_source_pos(take, item, proj_pos)
    if not take or not item then return nil end
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local take_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local take_rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    return take_offset + (proj_pos - item_pos) * take_rate
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function solo()
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or rcmaster_state == "y") then
            if IsTrackSelected(track) and parent ~= 1 then
                SetMediaTrackInfo_Value(track, "I_SOLO", 2)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if rt_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if live_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if ref_state == "y" then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0) -- unsolo all tracks
                mute_state = 0
                solo_state = 1
            end

            SetMediaTrackInfo_Value(track, "B_MUTE", mute_state)
            SetMediaTrackInfo_Value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

-- Initialize and start
load_marker_data()
clean_up_orphans()
init_marker_data()
defer(main)