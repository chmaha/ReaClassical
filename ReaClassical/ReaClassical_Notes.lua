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

local main, get_take_number, rgba_to_native, get_color_table
local pastel_color, get_item_color, apply_rank_color
local strip_rank_prefix, get_items_at_midpoint
local get_folder_range_for_item

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ranking_color_pref = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[6] then ranking_color_pref = tonumber(table[6]) or 0 end
end

set_action_options(2)

package.path        = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui         = require 'imgui' '0.10'

local ctx           = ImGui.CreateContext('ReaClassical Notes Window')
local window_open   = true

local DEFAULT_W     = 350
local DEFAULT_H     = 375

local MIN_H_PROJECT = 60
local MIN_H_TRACK   = 80
local MIN_H_ITEM    = 80

local track_note    = ""
local item_note     = ""
local item_rank     = ""
local item_take_num = ""
local item_name     = ""

local editing_track = nil
local editing_item  = nil

local RANKS         = {
    { name = "Excellent",     rgba = 0x39FF1499, prefix = "Excellent" },
    { name = "Very Good",     rgba = 0x32CD3299, prefix = "Very Good" },
    { name = "Good",          rgba = 0x00AD8399, prefix = "Good" },
    { name = "OK",            rgba = 0xFFFFAA99, prefix = "OK" },
    { name = "Below Average", rgba = 0xFFBF0099, prefix = "Below Average" },
    { name = "Poor",          rgba = 0xFF753899, prefix = "Poor" },
    { name = "Unusable",      rgba = 0xDC143C99, prefix = "Unusable" },
    { name = "False Start",   rgba = 0x2A2A2AFF, prefix = "False Start" },
    { name = "No Rank",       rgba = 0x00000000, prefix = "" }
}

---------------------------------------------------------------------

function strip_rank_prefix(name)
    local all_prefixes = { "Excellent", "Very Good", "Good", "OK", "Below Average", "Poor", "Unusable", "False Start" }
    for _, prefix in ipairs(all_prefixes) do
        if name == prefix then return "" end
        name = name:gsub("^" .. prefix .. "%-", "")
    end
    return name
end

---------------------------------------------------------------------

-- Resolves the folder track range (0-based indices) that contains ref_item.
function get_folder_range_for_item(ref_item)
    local track = GetMediaItem_Track(ref_item)
    local track_num = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local start_search = track_num
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
    local folder_start, folder_end = nil, nil
    for t = start_search, num_tracks - 1 do
        local tt = GetTrack(0, t)
        if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    return folder_start, folder_end
end

---------------------------------------------------------------------

function get_items_at_midpoint(ref_item)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    local folder_start, folder_end = get_folder_range_for_item(ref_item)
    if not folder_start then return result end
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

---------------------------------------------------------------------

function main()
    local item         = GetSelectedMediaItem(0, 0)
    local track        = GetSelectedTrack(0, 0)
    local proj         = 0

    local project_note = GetSetProjectNotes(proj, false, "")

    if editing_item and not ValidatePtr2(0, editing_item, "MediaItem*") then
        editing_item = nil
        item_note = ""
        item_rank = ""
        item_take_num = ""
        item_name = ""
    end

    if editing_track and not ValidatePtr2(0, editing_track, "MediaTrack*") then
        editing_track = nil
        track_note = ""
    end

    if editing_track ~= track then
        ImGui.SetWindowFocus(ctx)
        if editing_track then
            GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
        end

        editing_track = track
        if track then
            local _, note = GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", "", false)
            track_note = note
        end
    end

    if editing_item ~= item then
        ImGui.SetWindowFocus(ctx)
        if editing_item then
            GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_rank", item_rank, true)
            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_take_num", item_take_num, true)
            local take = GetActiveTake(editing_item)
            if take then
                local base_name = item_name
                local final_name = base_name
                if item_rank ~= "" then
                    local rank_index = tonumber(item_rank)
                    if rank_index and RANKS[rank_index] and RANKS[rank_index].prefix ~= "" then
                        if base_name ~= "" then
                            final_name = RANKS[rank_index].prefix .. "-" .. base_name
                        else
                            final_name = RANKS[rank_index].prefix
                        end
                    end
                end
                GetSetMediaItemTakeInfo_String(take, "P_NAME", final_name, true)
            end
        end

        editing_item = item
        if item then
            local _, note = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
            item_note = note

            local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
            if rank_str ~= "" then
                local rank_num = tonumber(rank_str)
                item_rank = (rank_num and rank_num >= 1 and rank_num <= 9) and tostring(rank_num) or ""
            else
                item_rank = ""
            end

            local _, item_take_num_stored = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
            item_take_num = item_take_num_stored ~= "" and item_take_num_stored or get_take_number(item)

            local take = GetActiveTake(item)
            if take then
                local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                item_name = strip_rank_prefix(name)
            else
                item_name = ""
            end
        else
            item_rank = ""
            item_take_num = ""
            item_note = ""
            item_name = ""
        end
    end

    if window_open then
        local _, FLT_MAX = ImGui.NumericLimits_Float()
        ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)
        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Notes", window_open)
        window_open = open_ref

        if opened then
            local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

            local static_height    = 5 * ImGui.GetTextLineHeightWithSpacing(ctx) + 60
            local dynamic_h        = math.max(0, avail_h - static_height)

            local base_total       = MIN_H_PROJECT + MIN_H_TRACK + MIN_H_ITEM
            local extra            = math.max(0, dynamic_h - base_total)

            local h_project        = math.max(MIN_H_PROJECT, MIN_H_PROJECT + extra * 0.2)
            local h_track          = math.max(MIN_H_TRACK, MIN_H_TRACK + extra * 0.4)
            local h_item           = math.max(MIN_H_ITEM, MIN_H_ITEM + extra * 0.4)

            ImGui.Text(ctx, "Project Note:")
            local changed_project
            changed_project, project_note = ImGui.InputTextMultiline(ctx, "##project_note", project_note, avail_w,
                h_project)
            if changed_project then
                GetSetProjectNotes(proj, true, project_note)
            end

            ImGui.Text(ctx, "Track Note:")
            local changed_track
            changed_track, track_note = ImGui.InputTextMultiline(ctx, "##track_note", track_note, avail_w, h_track)
            if changed_track and editing_track then
                GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
            end

            if editing_item then
                local item_id = tostring(editing_item):sub(-8)
                ImGui.PushID(ctx, item_id)

                ImGui.Text(ctx, "Item Name:")
                ImGui.SetNextItemWidth(ctx, avail_w)
                local changed_name
                changed_name, item_name = ImGui.InputText(ctx, "##item_name", item_name)
                if changed_name and editing_item then
                    local take = GetActiveTake(editing_item)
                    if take then
                        local base_name = item_name
                        local final_name = base_name
                        if item_rank ~= "" then
                            local rank_index = tonumber(item_rank)
                            if rank_index and RANKS[rank_index] and RANKS[rank_index].prefix ~= "" then
                                if base_name ~= "" then
                                    final_name = RANKS[rank_index].prefix .. "-" .. base_name
                                else
                                    final_name = RANKS[rank_index].prefix
                                end
                            end
                        end
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", final_name, true)
                    end
                end

                local half_w = (avail_w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)) / 2

                ImGui.BeginGroup(ctx)
                ImGui.Text(ctx, "Item Rank:")

                local display_index = item_rank == "" and 9 or tonumber(item_rank)

                ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, RANKS[display_index].rgba)
                ImGui.SetNextItemWidth(ctx, half_w)
                if ImGui.BeginCombo(ctx, "##item_rank", RANKS[display_index].name) then
                    for i, rank in ipairs(RANKS) do
                        ImGui.PushStyleColor(ctx, ImGui.Col_Header, rank.rgba)
                        local is_selected = (display_index == i)
                        if ImGui.Selectable(ctx, rank.name, is_selected) then
                            item_rank = (i == 9) and "" or tostring(i)
                            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_rank", item_rank, true)
                            apply_rank_color(editing_item, item_rank)
                        end
                        if is_selected then ImGui.SetItemDefaultFocus(ctx) end
                        ImGui.PopStyleColor(ctx)
                    end
                    ImGui.EndCombo(ctx)
                end
                ImGui.PopStyleColor(ctx)
                ImGui.EndGroup(ctx)

                ImGui.SameLine(ctx)
                ImGui.BeginGroup(ctx)
                ImGui.Text(ctx, "Take Number:")

                ImGui.SetNextItemWidth(ctx, half_w - 30)
                local changed_take_num
                changed_take_num, item_take_num = ImGui.InputText(ctx, "##item_take_num", item_take_num)
                if changed_take_num and editing_item then
                    GetSetMediaItemInfo_String(editing_item, "P_EXT:item_take_num", item_take_num, true)
                end

                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, "↻##reset_take", 25, 0) then
                    item_take_num = get_take_number(editing_item)
                    GetSetMediaItemInfo_String(editing_item, "P_EXT:item_take_num", item_take_num, true)
                end
                if ImGui.IsItemHovered(ctx) then
                    ImGui.SetTooltip(ctx, "Reset to filename take number")
                end

                ImGui.EndGroup(ctx)

                ImGui.Text(ctx, "Item Note:")
                local changed_item
                changed_item, item_note = ImGui.InputTextMultiline(ctx, "##item_note", item_note, avail_w, h_item)
                if changed_item and editing_item then
                    GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
                    UpdateArrange()
                end
                ImGui.PopID(ctx)
            end

            if not ImGui.IsAnyItemActive(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_N, false) then
                window_open = false
            end
            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

function get_take_number(item)
    local take = GetActiveTake(item)
    if not take then return "" end
    local src = GetMediaItemTake_Source(take)
    local filename = GetMediaSourceFileName(src, "")
    local take_num = tonumber(
        filename:match("(%d+)%)?%s*%[chan%s*%d+%]%.[^%.]+$")
        or filename:match("(%d+)%)?%.[^%.]+$")
    )
    return take_num and tostring(take_num) or ""
end

---------------------------------------------------------------------

function rgba_to_native(rgba)
    local r = (rgba >> 24) & 0xFF
    local g = (rgba >> 16) & 0xFF
    local b = (rgba >> 8) & 0xFF
    return ColorToNative(r, g, b)
end

---------------------------------------------------------------------

function get_color_table()
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    package.path = package.path .. ";" .. script_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function pastel_color(index)
    local golden_ratio_conjugate = 0.61803398875
    local hue                    = (index * golden_ratio_conjugate) % 1.0
    local saturation             = 0.45 + 0.15 * math.sin(index * 1.7)
    local lightness              = 0.70 + 0.1 * math.cos(index * 1.1)

    local function h2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    local q = lightness < 0.5 and (lightness * (1 + saturation))
        or (lightness + saturation - lightness * saturation)
    local p = 2 * lightness - q

    local r = h2rgb(p, q, hue + 1 / 3)
    local g = h2rgb(p, q, hue)
    local b = h2rgb(p, q, hue - 1 / 3)

    local color_int = ColorToNative(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )
    return color_int | 0x1000000
end

---------------------------------------------------------------------

function get_item_color(item)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local colors = get_color_table()

    local color_to_use = nil
    local _, saved_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)

    if saved_guid ~= "" then
        local total_items = CountMediaItems(0)
        for i = 0, total_items - 1 do
            local test_item = GetMediaItem(0, i)
            local _, test_guid = GetSetMediaItemInfo_String(test_item, "GUID", "", false)
            if test_guid == saved_guid then
                color_to_use = GetMediaItemInfo_Value(test_item, "I_CUSTOMCOLOR")
                break
            end
        end
    end

    if workflow == "Horizontal" then
        local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
        if saved_color ~= "" then
            color_to_use = tonumber(saved_color)
        else
            color_to_use = colors.dest_items
        end
    elseif not color_to_use then
        local item_track = GetMediaItemTrack(item)
        local folder_tracks = {}
        local num_tracks = CountTracks(0)

        for t = 0, num_tracks - 1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth > 0 then table.insert(folder_tracks, track) end
        end

        local parent_folder = nil
        local track_idx = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER") - 1
        for t = track_idx, 0, -1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth > 0 then parent_folder = track; break end
        end

        local folder_index = 0
        if parent_folder then
            for i, track in ipairs(folder_tracks) do
                if track == parent_folder then
                    folder_index = i - 2
                    break
                end
            end
            if folder_index < 0 then
                color_to_use = colors.dest_items
            else
                color_to_use = pastel_color(folder_index)
            end
        else
            color_to_use = colors.dest_items
        end
    end

    return color_to_use
end

---------------------------------------------------------------------

function apply_rank_color(item, rank)
    local color_to_use

    if rank == "" or ranking_color_pref == 1 then
        color_to_use = get_item_color(item)
    else
        GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)
        local rank_index = tonumber(rank)
        if rank_index and RANKS[rank_index] then
            color_to_use = rgba_to_native(RANKS[rank_index].rgba) | 0x1000000
        else
            color_to_use = get_item_color(item)
        end
    end

    -- Apply color and rank name to the item and all its midpoint peers
    local peers = get_items_at_midpoint(item)
    for _, peer in ipairs(peers) do
        SetMediaItemInfo_Value(peer, "I_CUSTOMCOLOR", color_to_use)

        local peer_take = GetActiveTake(peer)
        if peer_take then
            local _, peer_name = GetSetMediaItemTakeInfo_String(peer_take, "P_NAME", "", false)
            local peer_base = strip_rank_prefix(peer_name)
            local peer_final = peer_base
            if rank ~= "" then
                local rank_index = tonumber(rank)
                if rank_index and RANKS[rank_index] and RANKS[rank_index].prefix ~= "" then
                    peer_final = peer_base ~= "" and (RANKS[rank_index].prefix .. "-" .. peer_base)
                                                 or  RANKS[rank_index].prefix
                end
            end
            GetSetMediaItemTakeInfo_String(peer_take, "P_NAME", peer_final, true)
        end

        GetSetMediaItemInfo_String(peer, "P_EXT:item_rank", rank, true)
        GetSetMediaItemInfo_String(peer, "P_EXT:colorized", "", true)
    end

    -- Also update the take name for the triggering item itself using item_name
    local take = GetActiveTake(item)
    if take then
        local base_name = item_name
        local final_name = base_name
        if rank ~= "" then
            local rank_index = tonumber(rank)
            if rank_index and RANKS[rank_index] and RANKS[rank_index].prefix ~= "" then
                final_name = base_name ~= "" and (RANKS[rank_index].prefix .. "-" .. base_name)
                                              or  RANKS[rank_index].prefix
            end
        end
        GetSetMediaItemTakeInfo_String(take, "P_NAME", final_name, true)
    end

    UpdateArrange()
end

---------------------------------------------------------------------

defer(main)