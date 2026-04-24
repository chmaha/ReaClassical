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

local main, source_markers, select_matching_folder
local adaptive_delete, count_selected_media_items, get_selected_media_item_at
local nudge_xfades_at_source_boundaries

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()

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

    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end

    if source_markers() == 2 then
        SetCursorContext(1, nil)
        Main_OnCommand(40310, 0) -- Set ripple per-track
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        GoToMarker(0, 998, false)
        select_matching_folder()
        nudge_xfades_at_source_boundaries()
        Main_OnCommand(40625, 0)  -- Time Selection: Set start point
        GoToMarker(0, 999, false)
        Main_OnCommand(40626, 0)  -- Time Selection: Set end point
        Main_OnCommand(40718, 0)  -- Select all items on selected tracks in current time selection
        Main_OnCommand(40034, 0)  -- Item Grouping: Select all items in group(s)
        Main_OnCommand(41990, 0)  -- Toggle ripple per-track (off)
        adaptive_delete()
        Main_OnCommand(40630, 0)  -- Go to start of time selection
        Main_OnCommand(40020, 0)  -- Time Selection: Remove time selection and loop point selection
        DeleteProjectMarker(nil, 998, false)
        DeleteProjectMarker(nil, 999, false)
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(41990, 0) -- Toggle ripple per-track (on)
    else
        MB("Please use SOURCE-IN and SOURCE-OUT markers", "Delete Leaving Silence", 0)
    end
    Undo_EndBlock('Cut and Ripple', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function source_markers()
    local _, num_markers, num_regions = CountProjectMarkers(0)
    local exists = 0
    for i = 0, num_markers + num_regions - 1, 1 do
        local _, _, _, _, label, _ = EnumProjectMarkers(i)
        if string.match(label, ".+:SOURCE%-IN") or string.match(label, ".+:SOURCE%-OUT") then
            exists = exists + 1
        end
    end
    return exists
end

---------------------------------------------------------------------

function select_matching_folder()
    local _, stored = GetProjExtState(0, "ReaClassical", "SourceInTrackNum")
    local folder_number = tonumber(stored)
    if not folder_number then return end
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") == folder_number then
            SetOnlyTrackSelected(track)
            break
        end
    end
end

---------------------------------------------------------------------

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
        Main_OnCommand(40312, 0) -- Delete items in time selection
    else
        Main_OnCommand(40006, 0) -- Delete items or time selection contents
    end
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function nudge_xfades_at_source_boundaries()
    local epsilon = 0.0001

    local source_in_pos, source_out_pos = nil, nil
    local _, num_markers, num_regions = CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local _, _, pos, _, _, id = EnumProjectMarkers2(0, i)
        if id == 998 then source_in_pos = pos end
        if id == 999 then source_out_pos = pos end
    end

    if not source_in_pos or not source_out_pos then return end

    local sel_track = GetSelectedTrack(0, 0)
    if not sel_track then return end
    local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local folder_start, folder_end = nil, nil

    for t = track_num, num_tracks - 1 do
        local track = GetTrack(0, t)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth == 1 then
            folder_start = t
            folder_end = t
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

    if not folder_start then return end

    local function find_overlap_at_pos(pos)
        local ref_track = GetTrack(0, folder_start)
        local n = CountTrackMediaItems(ref_track)
        for i = 0, n - 2 do
            local item_a = GetTrackMediaItem(ref_track, i)
            local item_b = GetTrackMediaItem(ref_track, i + 1)
            local a_start = GetMediaItemInfo_Value(item_a, "D_POSITION")
            local a_end   = a_start + GetMediaItemInfo_Value(item_a, "D_LENGTH")
            local b_start = GetMediaItemInfo_Value(item_b, "D_POSITION")
            if a_end > b_start then
                -- marker falls within the overlap region
                if pos > b_start and pos < a_end then
                    return item_a, item_b, a_end - b_start
                end
            end
        end
        return nil, nil, nil
    end

    local function move_xfade_boundaries(gid_a, gid_b, new_a_end, new_b_start)
        for t = folder_start, folder_end do
            local track = GetTrack(0, t)
            local n = CountTrackMediaItems(track)
            for j = 0, n - 1 do
                local item = GetTrackMediaItem(track, j)
                local gid = GetMediaItemInfo_Value(item, "I_GROUPID")
                if gid ~= 0 then
                    if gid == gid_a then
                        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                        SetMediaItemInfo_Value(item, "D_LENGTH", new_a_end - pos)
                    elseif gid == gid_b then
                        local old_end = GetMediaItemInfo_Value(item, "D_POSITION")
                                      + GetMediaItemInfo_Value(item, "D_LENGTH")
                        SetMediaItemInfo_Value(item, "D_POSITION", new_b_start)
                        SetMediaItemInfo_Value(item, "D_LENGTH", old_end - new_b_start)
                    end
                end
            end
        end
    end

    -- Check and fix SOURCE-IN (nudge rightward into source region)
    local a, b, overlap_len_in = find_overlap_at_pos(source_in_pos)
    if a and b then
        local gid_a = GetMediaItemInfo_Value(a, "I_GROUPID")
        local gid_b = GetMediaItemInfo_Value(b, "I_GROUPID")
        local new_b_start = source_in_pos + epsilon
        local new_a_end   = new_b_start + overlap_len_in
        move_xfade_boundaries(gid_a, gid_b, new_a_end, new_b_start)
    end

    -- Check and fix SOURCE-OUT (nudge leftward into source region)
    local c, d, overlap_len_out = find_overlap_at_pos(source_out_pos)
    if c and d then
        local gid_c = GetMediaItemInfo_Value(c, "I_GROUPID")
        local gid_d = GetMediaItemInfo_Value(d, "I_GROUPID")
        local new_c_end   = source_out_pos - epsilon
        local new_d_start = new_c_end - overlap_len_out
        move_xfade_boundaries(gid_c, gid_d, new_c_end, new_d_start)
    end
end

---------------------------------------------------------------------

main()