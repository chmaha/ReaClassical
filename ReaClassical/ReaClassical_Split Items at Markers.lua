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
local main, split_items_at_markers, clear_item_names_from_selected
local get_selected_media_item_at, count_selected_media_items, get_folder_parent_track
local get_items_at_midpoint, get_folder_range_for_item
local select_midpoint_peers

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

    if CountSelectedMediaItems(0) == 0 then
        MB("Please select at least one item.", "ReaClassical Error", 0)
        return
    end

    split_items_at_markers()
    Undo_EndBlock('ReaClassical Split Items at Markers', -1)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function get_folder_parent_track(track)
    local track_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    if track_depth == 1 then return track end
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = track_idx - 1, 0, -1 do
        local parent_track = GetTrack(0, i)
        local parent_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")
        if parent_depth == 1 then return parent_track end
    end
    return track
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

function split_items_at_markers()
    local cursor_pos = GetCursorPosition()

    local first_selected_item = GetSelectedMediaItem(0, 0)
    if not first_selected_item then return end

    local selected_track = GetMediaItemTrack(first_selected_item)
    local parent_track = get_folder_parent_track(selected_track)
    local parent_track_index = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER")

    local original_take = GetActiveTake(first_selected_item)
    local original_item_name = ""
    if original_take then original_item_name = GetTakeName(original_take) end
    local original_item_start = GetMediaItemInfo_Value(first_selected_item, "D_POSITION")
    local original_item_length = GetMediaItemInfo_Value(first_selected_item, "D_LENGTH")
    local original_item_end = original_item_start + original_item_length

    local marker_data = {}
    local _, num_markers, _ = CountProjectMarkers(0)
    local has_named_markers = false

    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, _, name, markrgnindex = EnumProjectMarkers(i)
        if retval and not isrgn then
            if pos > original_item_start and pos < original_item_end then
                if name ~= "" then has_named_markers = true end
                local label = name ~= "" and name or ("Marker " .. tostring(markrgnindex))
                table.insert(marker_data, { pos = pos, name = label, has_name = (name ~= ""), marker_index = markrgnindex })
            end
        end
    end

    if #marker_data == 0 then return end

    table.sort(marker_data, function(a, b) return a.pos < b.pos end)

    local markers_to_delete = {}

    for _, marker in ipairs(marker_data) do
        SetEditCurPos(marker.pos, false, false)
        Main_OnCommand(40289, 0) -- Unselect all items

        local item_count = CountMediaItems(0)
        for i = 0, item_count - 1 do
            local item = GetMediaItem(0, i)
            local track = GetMediaItemTrack(item)
            local item_parent_track = get_folder_parent_track(track)
            local item_parent_track_index = GetMediaTrackInfo_Value(item_parent_track, "IP_TRACKNUMBER")

            if item_parent_track_index == parent_track_index then
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len

                if marker.pos > item_pos and marker.pos < item_end then
                    table.insert(markers_to_delete, marker.marker_index)

                    SetMediaItemSelected(item, true)
                    select_midpoint_peers()
                    Main_OnCommand(40012, 0) -- Split at edit cursor

                    clear_item_names_from_selected()

                    if has_named_markers then
                        local new_item_count = CountMediaItems(0)
                        for j = 0, new_item_count - 1 do
                            local new_item = GetMediaItem(0, j)
                            local new_track = GetMediaItemTrack(new_item)
                            local new_item_parent_track = get_folder_parent_track(new_track)
                            local new_parent_track_index = GetMediaTrackInfo_Value(new_item_parent_track, "IP_TRACKNUMBER")
                            local new_item_pos = GetMediaItemInfo_Value(new_item, "D_POSITION")

                            if new_parent_track_index == parent_track_index
                                    and math.abs(new_item_pos - marker.pos) < 0.0001 then
                                local take = GetActiveTake(new_item)
                                if take then
                                    GetSetMediaItemTakeInfo_String(take, "P_NAME", marker.name, true)
                                    break
                                end
                            end
                        end
                    end

                    break
                end
            end
        end
    end

    -- Subtake numbering: group items by midpoint rather than I_GROUPID.
    -- For each parent-track item within the original bounds, find all its
    -- folder peers via midpoint matching and treat them as a unit.
    if not has_named_markers then
        local item_count = CountMediaItems(0)

        -- Collect reference items on the parent track within original bounds,
        -- ordered by position.
        local ref_items = {}
        for i = 0, item_count - 1 do
            local item = GetMediaItem(0, i)
            local track = GetMediaItemTrack(item)
            -- Only look at items directly on the parent track
            if GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") == parent_track_index then
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_end = item_pos + GetMediaItemInfo_Value(item, "D_LENGTH")
                if item_pos >= original_item_start - 0.0001 and item_end <= original_item_end + 0.0001 then
                    table.insert(ref_items, item)
                end
            end
        end

        -- Sort by position
        table.sort(ref_items, function(a, b)
            return GetMediaItemInfo_Value(a, "D_POSITION") < GetMediaItemInfo_Value(b, "D_POSITION")
        end)

        -- For each reference item, find all midpoint peers and assign the suffix
        local seen = {}
        for idx, ref_item in ipairs(ref_items) do
            if not seen[ref_item] then
                local suffix = string.format("%02d", idx)
                local peers = get_items_at_midpoint(ref_item)
                for _, peer in ipairs(peers) do
                    seen[peer] = true
                    local peer_parent = get_folder_parent_track(GetMediaItemTrack(peer))
                    if GetMediaTrackInfo_Value(peer_parent, "IP_TRACKNUMBER") == parent_track_index then
                        local take = GetActiveTake(peer)
                        if take then
                            local take_name = GetTakeName(take)
                            local base_name = (take_name ~= "" and take_name) or original_item_name
                            GetSetMediaItemTakeInfo_String(take, "P_NAME", base_name .. "-" .. suffix, true)
                        end
                    end
                end
            end
        end
    end

    -- Delete markers within original bounds (reverse order to preserve indices)
    table.sort(markers_to_delete, function(a, b) return a > b end)
    for _, marker_idx in ipairs(markers_to_delete) do
        DeleteProjectMarker(0, marker_idx, false)
    end

    Main_OnCommand(40289, 0) -- Unselect all items
    SetEditCurPos(cursor_pos, false, false)
end

---------------------------------------------------------------------

function clear_item_names_from_selected()
    local selected_item_count = count_selected_media_items()
    for i = 0, selected_item_count - 1 do
        local item = get_selected_media_item_at(i)
        if item then
            local take = GetActiveTake(item)
            if take then GetSetMediaItemTakeInfo_String(take, "P_NAME", "", true) end
        end
    end
end

---------------------------------------------------------------------

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then selected_count = selected_count + 1 end
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
            if selected_count == index then return item end
            selected_count = selected_count + 1
        end
    end
    return nil
end

---------------------------------------------------------------------

function select_midpoint_peers()
    local sel_track = GetSelectedTrack(0, 0)
    if not sel_track then return end
    local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local folder_start, folder_end = nil, nil
    local start_search = track_num
    if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
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
    if not folder_start then return end
    local seed_items = {}
    local num_sel = CountSelectedMediaItems(0)
    for i = 0, num_sel - 1 do
        seed_items[#seed_items + 1] = GetSelectedMediaItem(0, i)
    end
    for _, ref_item in ipairs(seed_items) do
        local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
        local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
        local mid = pos + len * 0.5
        local tolerance = 0.0001
        for t = folder_start, folder_end do
            local track = GetTrack(0, t)
            local n = CountTrackMediaItems(track)
            for i = 0, n - 1 do
                local item = GetTrackMediaItem(track, i)
                local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
                local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
                if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                    SetMediaItemSelected(item, true)
                end
            end
        end
    end
end

---------------------------------------------------------------------

main()