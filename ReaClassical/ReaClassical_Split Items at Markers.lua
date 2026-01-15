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
local select_items_containing_midpoint, get_folder_children, get_parent_folder

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
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end
    
    -- Check if any item is selected
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
    -- Get the folder parent track (the first track in the folder)
    local track_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    
    -- If this track is a folder parent itself, return it
    if track_depth == 1 then
        return track
    end
    
    -- Otherwise, walk backwards to find the folder parent
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    
    for i = track_idx - 1, 0, -1 do
        local parent_track = GetTrack(0, i)
        local parent_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")
        
        if parent_depth == 1 then
            return parent_track
        end
    end
    
    -- If no folder parent found, return the original track
    return track
end

---------------------------------------------------------------------

function split_items_at_markers()
    local cursor_pos = GetCursorPosition() -- Save current edit cursor position

    -- Get the first selected item and find its folder parent track
    local first_selected_item = GetSelectedMediaItem(0, 0)
    if not first_selected_item then return end
    
    local selected_track = GetMediaItemTrack(first_selected_item)
    local parent_track = get_folder_parent_track(selected_track)
    local parent_track_index = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER")

    -- Get the original item bounds and name for subtake numbering
    local original_take = GetActiveTake(first_selected_item)
    local original_item_name = ""
    if original_take then
        original_item_name = GetTakeName(original_take)
    end
    local original_item_start = GetMediaItemInfo_Value(first_selected_item, "D_POSITION")
    local original_item_length = GetMediaItemInfo_Value(first_selected_item, "D_LENGTH")
    local original_item_end = original_item_start + original_item_length

    -- Collect all regular (non-region) markers and their names
    local marker_data = {}
    local _, num_markers, _ = CountProjectMarkers(0)
    local has_named_markers = false
    
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, _, name, markrgnindex = EnumProjectMarkers(i)
        if retval and not isrgn then
            -- Only include markers within the original item bounds
            if pos > original_item_start and pos < original_item_end then
                if name ~= "" then
                    has_named_markers = true
                end
                local label = name ~= "" and name or ("Marker " .. tostring(markrgnindex))
                table.insert(marker_data, {pos = pos, name = label, has_name = (name ~= ""), marker_index = markrgnindex})
            end
        end
    end

    -- If no markers within bounds, do nothing
    if #marker_data == 0 then
        return
    end

    -- Sort markers by position
    table.sort(marker_data, function(a, b) return a.pos < b.pos end)

    -- Store markers to delete (those within original bounds)
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
                    -- Mark this marker for deletion
                    table.insert(markers_to_delete, marker.marker_index)

                    SetMediaItemSelected(item, true)
                    select_items_containing_midpoint()
                    Main_OnCommand(40012, 0) -- Split at edit cursor

                    clear_item_names_from_selected()

                    -- If using named markers, name the item starting at this marker
                    if has_named_markers then
                        local new_item_count = CountMediaItems(0)
                        for j = 0, new_item_count - 1 do
                            local new_item = GetMediaItem(0, j)
                            local new_track = GetMediaItemTrack(new_item)
                            local new_item_parent_track = get_folder_parent_track(new_track)
                            local new_parent_track_index = GetMediaTrackInfo_Value(new_item_parent_track, "IP_TRACKNUMBER")
                            local new_item_pos = GetMediaItemInfo_Value(new_item, "D_POSITION")

                            if new_parent_track_index == parent_track_index and math.abs(new_item_pos - marker.pos) < 0.0001 then
                                local take = GetActiveTake(new_item)
                                if take then
                                    GetSetMediaItemTakeInfo_String(take, "P_NAME", marker.name, true)
                                    break
                                end
                            end
                        end
                    end

                    break -- Only process one group per marker
                end
            end
        end
    end

    -- If using subtake numbering, name only the items within original bounds
    if not has_named_markers then
        -- Collect all unique group IDs within the original item bounds
        local group_positions = {}
        local item_count = CountMediaItems(0)
        
        for i = 0, item_count - 1 do
            local item = GetMediaItem(0, i)
            local track = GetMediaItemTrack(item)
            local track_index = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
            local item_parent_track = get_folder_parent_track(track)
            local item_parent_track_index = GetMediaTrackInfo_Value(item_parent_track, "IP_TRACKNUMBER")
            
            -- Only look at parent track items within original bounds
            if item_parent_track_index == parent_track_index and track_index == parent_track_index then
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len
                
                -- Check if item is completely within original bounds (not extending beyond)
                if item_pos >= original_item_start - 0.0001 and item_end <= original_item_end + 0.0001 then
                    local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
                    if group_id > 0 then
                        if not group_positions[group_id] then
                            group_positions[group_id] = item_pos
                        end
                    end
                end
            end
        end
        
        -- Sort groups by their position
        local sorted_groups = {}
        for group_id, pos in pairs(group_positions) do
            table.insert(sorted_groups, {group_id = group_id, pos = pos})
        end
        table.sort(sorted_groups, function(a, b) return a.pos < b.pos end)
        
        -- Create mapping from group_id to suffix number
        local group_to_suffix = {}
        for idx, group_data in ipairs(sorted_groups) do
            group_to_suffix[group_data.group_id] = string.format("%02d", idx)
        end
        
        -- Now apply suffixes to items with these group IDs
        for i = 0, item_count - 1 do
            local item = GetMediaItem(0, i)
            local track = GetMediaItemTrack(item)
            local item_parent_track = get_folder_parent_track(track)
            local item_parent_track_index = GetMediaTrackInfo_Value(item_parent_track, "IP_TRACKNUMBER")
            
            if item_parent_track_index == parent_track_index then
                local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
                
                if group_id > 0 and group_to_suffix[group_id] then
                    local take = GetActiveTake(item)
                    if take then
                        local take_name = GetTakeName(take)
                        -- Use existing name if present, otherwise use original name
                        local base_name = (take_name ~= "" and take_name) or original_item_name
                        local subtake_name = base_name .. "-" .. group_to_suffix[group_id]
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", subtake_name, true)
                    end
                end
            end
        end
    end

    -- Delete markers within original bounds (in reverse order to maintain indices)
    table.sort(markers_to_delete, function(a, b) return a > b end)
    for _, marker_idx in ipairs(markers_to_delete) do
        DeleteProjectMarker(0, marker_idx, false)
    end

    -- Unselect all items
    Main_OnCommand(40289, 0)

    SetEditCurPos(cursor_pos, false, false) -- Restore cursor position
end

---------------------------------------------------------------------

function clear_item_names_from_selected()
    local selected_item_count = count_selected_media_items()
    for i = 0, selected_item_count - 1 do
        local item = get_selected_media_item_at(i)
        if item then
            local take = GetActiveTake(item)
            if take then
                GetSetMediaItemTakeInfo_String(take, "P_NAME", "", true)
            end
        end
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

function select_items_containing_midpoint()
    local num_sel = CountSelectedMediaItems(0)
    if num_sel == 0 then return end

    -- Get the folder tracks for all selected items
    local folder_tracks = {}
    for i = 0, num_sel - 1 do
        local item = GetSelectedMediaItem(0, i)
        local track = GetMediaItemTrack(item)
        local folder = get_parent_folder(track)
        if folder then
            folder_tracks[folder] = true
        end
    end

    -- Get all tracks within the relevant folders
    local tracks_to_check = {}
    for folder, _ in pairs(folder_tracks) do
        local children = get_folder_children(folder)
        tracks_to_check[folder] = true -- Include folder track itself
        for _, child in ipairs(children) do
            tracks_to_check[child] = true
        end
    end

    -- Collect selected items' midpoints
    local positions_to_check = {}
    for i = 0, num_sel - 1 do
        local item = GetSelectedMediaItem(0, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local mid = pos + (len / 2)
        table.insert(positions_to_check, mid)
    end

    local tolerance = 0.0001

    -- For each midpoint position, select items in folder that contain it
    for _, check_pos in ipairs(positions_to_check) do
        for track, _ in pairs(tracks_to_check) do
            local num_items = CountTrackMediaItems(track)
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len

                -- Select if this item's span contains the check position
                if check_pos >= (item_pos - tolerance) and check_pos <= (item_end + tolerance) then
                    SetMediaItemSelected(item, true)
                end
            end
        end
    end
end

---------------------------------------------------------------------

function get_parent_folder(track)
    -- Returns the parent folder track, or nil if track is not in a folder
    if not track then return nil end

    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

    -- Walk backwards to find parent folder
    for i = track_idx, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end

        local depth = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
        if depth == 1 then
            return t
        end
    end

    return nil
end

---------------------------------------------------------------------

function get_folder_children(parent_track)
    -- Returns all child tracks of a folder
    local children = {}
    if not parent_track then return children end

    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1

    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end

        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if depth > 0 then
            table.insert(children, tr)
        end

        depth = depth + folder_depth

        if depth <= 0 then break end

        idx = idx + 1
    end

    return children
end

---------------------------------------------------------------------

main()