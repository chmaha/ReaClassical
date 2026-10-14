--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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

local main, source_markers, adaptive_delete
local return_xfade_length, crossfade_join
local select_item_under_cursor_on_selected_track
local count_selected_media_items, get_selected_media_item_at
local nudge_xfades_at_source_markers, get_items_at_midpoint
local select_midpoint_peers, ripple_close_gap
local sanitize_marker_zones

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local function say(msg)
    if APIExists("osara_outputMessage") then osara_outputMessage(tostring(msg)) end
end
local sd_xfade = require("ReaEdit_SD_Crossfade_Utils")
local enum_project_markers = require("ReaEdit_Marker_Enum")

function main()
    if CountTracks(0) == 0 then return end
    PreventUIRefresh(1)
    Undo_BeginBlock()

    Main_OnCommand(40927, 0)
    Main_OnCommand(41121, 0)
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0)
    end
    local removed_note = ""
    if source_markers() == 2 then
        SetCursorContext(1, nil)
        GoToMarker(0, 998, false)
        Main_OnCommand(40296, 0)
        removed_note = sanitize_marker_zones({
            { id = 998, label = "SOURCE-IN" },
            { id = 999, label = "SOURCE-OUT" },
        })
        local source_in_pos = GetCursorPosition()
        nudge_xfades_at_source_markers()
        Main_OnCommand(40289, 0)
        Main_OnCommand(40625, 0)
        GoToMarker(0, 999, false)
        Main_OnCommand(40626, 0)
        Main_OnCommand(40718, 0)
        select_midpoint_peers()
        Main_OnCommand(40311, 0)
        adaptive_delete()
        Main_OnCommand(40630, 0)

        local xfade_len = return_xfade_length()
        local applied_len, shortened = crossfade_join(source_in_pos, xfade_len)
        SetEditCurPos(source_in_pos, false, false)
        Main_OnCommand(40020, 0)
        DeleteProjectMarker(nil, 998, false)
        DeleteProjectMarker(nil, 999, false)
        Main_OnCommand(40289, 0)
        Main_OnCommand(40310, 0)
        local completion = "Deleted with ripple"
        if shortened then
            local warning = string.format(
                "Crossfade shortened to %d ms due to limited source material.",
                math.floor(applied_len * 1000 + 0.5))
            if not APIExists("osara_outputMessage") then
                removed_note = (removed_note ~= "" and (removed_note .. "\n") or "") .. warning
            end
            completion = completion .. ". " .. warning
        end
        say(completion)
    else
        MB("Please use SOURCE-IN and SOURCE-OUT markers", "Delete With Ripple", 0)
    end
    Undo_EndBlock('Cut and Ripple', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()

    if removed_note ~= "" then
        MB(removed_note, "Delete With Ripple", 0)
    end
end

function source_markers()
    local num_markers = GetNumRegionsOrMarkers(0)
    local exists = 0
    for i = 0, num_markers - 1, 1 do
        local _, _, _, _, label, _ = enum_project_markers(0, i)
        if label == "SOURCE-IN" or label == "SOURCE-OUT" then
            exists = exists + 1
        end
    end
    return exists
end

function sanitize_marker_zones(zones)
    local xfade_len = return_xfade_length()
    local margin = xfade_len + 0.05
    local tracks = sd_xfade.all_tracks()
    local positions = {}
    local num_markers = GetNumRegionsOrMarkers(0)
    for i = 0, num_markers - 1 do
        local _, _, pos, _, _, id = enum_project_markers(0, i)
        positions[id] = pos
    end
    local notes = {}
    for _, zone in ipairs(zones) do
        local pos = positions[zone.id]
        if pos then
            local removed = sd_xfade.remove_extra_overlaps(
                tracks, pos - margin, pos + margin)
            if removed > 0 then
                notes[#notes + 1] = string.format("%d near %s", removed, zone.label)
            end
        end
    end
    if #notes == 0 then return "" end
    return "Removed sliver edit(s): " .. table.concat(notes, ", ") .. "."
end

function return_xfade_length()
    local xfade_len = 0.035
    local _, input = GetProjExtState(0, "ReaEdit", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[1] then xfade_len = table[1] / 1000 end
    end
    return xfade_len
end

function crossfade_join(join_pos, xfade_len)
    Main_OnCommand(40289, 0)
    SetEditCurPos(join_pos + xfade_len - 0.0001, false, false)
    select_item_under_cursor_on_selected_track()
    select_midpoint_peers()
    local right_items = {}
    for i = 0, count_selected_media_items() - 1 do
        right_items[#right_items + 1] = get_selected_media_item_at(i)
    end
    local neighbors = sd_xfade.get_adjacent_neighbors(right_items, "left")
    return sd_xfade.create_crossfade(right_items, neighbors, "left", xfade_len)
end

function adaptive_delete()
    local sel_items = {}
    local item_count = count_selected_media_items()
    for i = 0, item_count - 1 do
        sel_items[#sel_items + 1] = get_selected_media_item_at(i)
    end

    local time_sel_start, time_sel_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local items_in_time_sel = {}

    if time_sel_end - time_sel_start > 0 then
        for _, item in ipairs(sel_items) do
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_sel = GetMediaItemInfo_Value(item, "B_UISEL") == 1

            if item_sel then
                local intersectmatches = 0
                if time_sel_start >= item_pos and time_sel_end <= item_pos + item_len then
                    intersectmatches = intersectmatches + 1
                end
                if item_pos >= time_sel_start and item_pos + item_len <= time_sel_end then
                    intersectmatches = intersectmatches + 1
                end
                if time_sel_start <= item_pos + item_len and time_sel_end >= item_pos + item_len then
                    intersectmatches = intersectmatches + 1
                end
                if time_sel_end >= item_pos and time_sel_start < item_pos then
                    intersectmatches = intersectmatches + 1
                end

                if intersectmatches > 0 then
                    table.insert(items_in_time_sel, item)
                end
            end
        end
    end

    if #items_in_time_sel > 0 then
        Main_OnCommand(40312, 0)
    else
        ripple_close_gap(time_sel_start, time_sel_end)
    end
end

function ripple_close_gap(gap_start, gap_end)
    local shift = gap_end - gap_start
    local epsilon = 0.0001
    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if pos >= gap_end - epsilon then
                SetMediaItemInfo_Value(item, "D_POSITION", pos - shift)
            end
        end
    end
end

function select_item_under_cursor_on_selected_track()
    Main_OnCommand(40289, 0)

    local curpos = GetCursorPosition()
    local item_count = CountMediaItems(0)

    for i = 0, item_count - 1 do
        local item = GetMediaItem(0, i)
        local track = GetMediaItem_Track(item)
        local track_sel = IsTrackSelected(track)

        if track_sel then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_end = item_pos + item_len

            if curpos >= item_pos and curpos <= item_end then
                SetMediaItemInfo_Value(item, "B_UISEL", 1)
            end
        end
    end
end

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            selected_count = selected_count + 1
        end
    end

    return selected_count
end

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

function get_items_at_midpoint(ref_item)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    for t = 0, CountTracks(0) - 1 do
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

function nudge_xfades_at_source_markers()
    local xfade_len = return_xfade_length()
    local epsilon = 0.0001

    local source_in_pos, source_out_pos = nil, nil
    local num_markers = GetNumRegionsOrMarkers(0)
    for i = 0, num_markers - 1 do
        local _, _, pos, _, _, id = enum_project_markers(0, i)
        if id == 998 then source_in_pos = pos end
        if id == 999 then source_out_pos = pos end
    end

    if not source_in_pos or not source_out_pos then return end

    local in_zone_left   = source_in_pos - xfade_len
    local in_zone_right  = source_in_pos
    local out_zone_left  = source_out_pos
    local out_zone_right = source_out_pos + xfade_len

    local ref_track
    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        if CountTrackMediaItems(track) > 0 then ref_track = track; break end
    end
    if not ref_track then return end

    local function find_overlap_in_zone(zone_left, zone_right)
        local n = CountTrackMediaItems(ref_track)
        for i = 0, n - 2 do
            local item_a = GetTrackMediaItem(ref_track, i)
            local item_b = GetTrackMediaItem(ref_track, i + 1)
            local a_start = GetMediaItemInfo_Value(item_a, "D_POSITION")
            local a_end   = a_start + GetMediaItemInfo_Value(item_a, "D_LENGTH")
            local b_start = GetMediaItemInfo_Value(item_b, "D_POSITION")
            if a_end > b_start then
                local overlap_left  = b_start
                local overlap_right = a_end
                if overlap_left < zone_right and overlap_right > zone_left then
                    return item_a, item_b
                end
            end
        end
        return nil, nil
    end

    local function move_xfade_boundaries(ref_a, ref_b, new_a_end, new_b_start)
        local peers_a = get_items_at_midpoint(ref_a)
        local peers_b = get_items_at_midpoint(ref_b)
        for _, item in ipairs(peers_a) do
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_LENGTH", new_a_end - ipos)
        end
        for _, item in ipairs(peers_b) do
            local old_end = GetMediaItemInfo_Value(item, "D_POSITION")
                          + GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_POSITION", new_b_start)
            SetMediaItemInfo_Value(item, "D_LENGTH",   old_end - new_b_start)
        end
    end

    local a, b = find_overlap_in_zone(in_zone_left, in_zone_right)
    if a and b then
        local new_b_start = source_in_pos + epsilon
        local new_a_end   = new_b_start + xfade_len
        move_xfade_boundaries(a, b, new_a_end, new_b_start)
    end

    local c, d = find_overlap_in_zone(out_zone_left, out_zone_right)
    if c and d then
        local new_c_end   = source_out_pos - epsilon
        local new_d_start = new_c_end - xfade_len
        move_xfade_boundaries(c, d, new_c_end, new_d_start)
    end
end

function select_midpoint_peers()
    local seed_items = {}
    local num_sel = CountSelectedMediaItems(0)
    for i = 0, num_sel - 1 do
        seed_items[#seed_items + 1] = GetSelectedMediaItem(0, i)
    end
    for _, ref_item in ipairs(seed_items) do
        for _, item in ipairs(get_items_at_midpoint(ref_item)) do
            SetMediaItemSelected(item, true)
        end
    end
end

main()
