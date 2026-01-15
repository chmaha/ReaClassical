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

local main, empty_items_check
local get_cd_track_groups, get_items_containing_midpoint
local get_parent_folder, get_folder_children
local items_overlap
---------------------------------------------------------------------

function main()
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
    
    -- Get the currently selected track
    local selected_track = GetSelectedTrack(0, 0)
    if not selected_track then
        MB("Error: No track selected. Please select a folder track or a track within a folder.", "Reposition Tracks", 0)
        return
    end
    
    -- Check if it's a folder, if not try to find parent folder
    local folder_depth = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")
    local folder_track = nil
    
    if folder_depth == 1 then
        -- It's a folder
        folder_track = selected_track
    else
        -- Not a folder, try to find parent folder
        folder_track = get_parent_folder(selected_track)
        if not folder_track then
            MB("Error: Selected track is not in a folder. Please select a folder track or a track within a folder.", "Reposition Tracks", 0)
            return
        end
    end
    
    local num_of_items = CountTrackMediaItems(folder_track)
    if num_of_items == 0 then
        MB("Error: No media items found on folder track.", "Reposition Album Tracks", 0)
        return
    end
    
    local empty_count = empty_items_check(folder_track, num_of_items)
    if empty_count > 0 then
        MB("Error: Empty items found on folder track. Delete them to continue.", "Reposition Tracks", 0)
        return
    end

    local bool, gap = GetUserInputs('Reposition Tracks', 1, "No. of seconds between items?", ',')

    if not bool then
        return
    elseif gap == "" then
        MB("Please enter a number!", "Reposition Album Tracks", 0)
        return
    else
        -- Get all CD track groups from the folder
        local cd_track_groups = get_cd_track_groups(folder_track)
        
        if #cd_track_groups == 0 then
            MB("No named items found on parent track.", "Reposition Tracks", 0)
            return
        end
        
        -- Store original positions of ALL items before moving anything
        local original_positions = {}
        for _, group in ipairs(cd_track_groups) do
            for _, item in ipairs(group.all_items) do
                if not original_positions[item] then
                    original_positions[item] = GetMediaItemInfo_Value(item, "D_POSITION")
                end
            end
        end
        
        -- Position each CD track group
        local previous_end_position = nil
        
        for i, group in ipairs(cd_track_groups) do
            local new_start_position
            
            if i == 1 then
                -- First group stays where it is
                new_start_position = group.start_position
            else
                -- Subsequent groups: position gap seconds after previous group ends
                new_start_position = previous_end_position + gap
            end
            
            -- Calculate shift for this group
            local shift = new_start_position - group.start_position
            
            -- Move ALL items in this group by the same shift
            for _, item in ipairs(group.all_items) do
                local original_pos = original_positions[item]
                SetMediaItemInfo_Value(item, "D_POSITION", original_pos + shift)
            end
            
            -- Calculate where this group ends (after shifting)
            previous_end_position = group.end_position + shift
        end
    end
    
    local create_cd_markers = NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")
    local _, run = GetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?")
    if run == "yes" then Main_OnCommand(create_cd_markers, 0) end
    Undo_EndBlock("Reposition Tracks", 0)
end

---------------------------------------------------------------------

function items_overlap(item1, item2)
    -- Check if two items overlap
    local pos1 = GetMediaItemInfo_Value(item1, "D_POSITION")
    local len1 = GetMediaItemInfo_Value(item1, "D_LENGTH")
    local end1 = pos1 + len1
    
    local pos2 = GetMediaItemInfo_Value(item2, "D_POSITION")
    local len2 = GetMediaItemInfo_Value(item2, "D_LENGTH")
    local end2 = pos2 + len2
    
    local tolerance = 0.0001
    
    -- Items overlap if one starts before the other ends (with tolerance)
    return (pos1 < end2 + tolerance) and (pos2 < end1 + tolerance)
end

---------------------------------------------------------------------

function get_cd_track_groups(parent_track)
    local item_count = CountTrackMediaItems(parent_track)
    local groups = {}
    local i = 0
    
    while i < item_count do
        local item = GetTrackMediaItem(parent_track, i)
        local take = GetActiveTake(item)
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        
        -- Treat "@" prefix items as unnamed
        local is_named = take_name ~= "" and not take_name:match("^@")
        
        -- Only start a group if this item has a name (is a CD track start)
        if is_named then
            -- Check if this named item overlaps with any item from the previous group
            local should_merge_with_previous = false
            if #groups > 0 then
                local prev_group = groups[#groups]
                -- Check if current item overlaps with any item in previous group
                for _, prev_item in ipairs(prev_group.all_items) do
                    if items_overlap(item, prev_item) then
                        should_merge_with_previous = true
                        break
                    end
                end
            end
            
            local parent_track_items = {}
            local all_items_in_group = {}
            local all_items_hash = {}
            
            if should_merge_with_previous then
                -- Merge with previous group instead of creating new one
                local prev_group = groups[#groups]
                all_items_in_group = prev_group.all_items
                all_items_hash = {}
                for _, existing_item in ipairs(all_items_in_group) do
                    all_items_hash[existing_item] = true
                end
            end
            
            -- Add the named item
            table.insert(parent_track_items, item)
            i = i + 1
            
            -- Continue adding unnamed items from parent track until we hit another named item or end
            while i < item_count do
                local next_item = GetTrackMediaItem(parent_track, i)
                local next_take = GetActiveTake(next_item)
                local _, next_name = GetSetMediaItemTakeInfo_String(next_take, "P_NAME", "", false)
                
                -- Check if next item is a named CD track (not "@" prefix)
                local next_is_named = next_name ~= "" and not next_name:match("^@")
                
                if next_is_named then
                    -- Check if this next named item overlaps with current group
                    local overlaps_current = false
                    for _, current_item in ipairs(parent_track_items) do
                        if items_overlap(next_item, current_item) then
                            overlaps_current = true
                            break
                        end
                    end
                    
                    if overlaps_current then
                        -- Include this overlapping named item in current group
                        table.insert(parent_track_items, next_item)
                        i = i + 1
                    else
                        -- Hit a non-overlapping named item - stop here
                        break
                    end
                else
                    -- Unnamed item - add to this group
                    table.insert(parent_track_items, next_item)
                    i = i + 1
                end
            end
            
            -- Now for EACH parent item, get items from lower tracks whose range contains the parent item's midpoint
            for _, parent_item in ipairs(parent_track_items) do
                -- Add the parent item itself
                if not all_items_hash[parent_item] then
                    all_items_hash[parent_item] = true
                    table.insert(all_items_in_group, parent_item)
                end
                
                -- Get items from other tracks in folder that contain this parent item's midpoint
                local overlapping = get_items_containing_midpoint(parent_item)
                for _, overlap_item in ipairs(overlapping) do
                    if not all_items_hash[overlap_item] then
                        all_items_hash[overlap_item] = true
                        table.insert(all_items_in_group, overlap_item)
                    end
                end
            end
            
            -- Calculate start and end positions
            local start_pos = nil
            local max_end = 0
            for _, grp_item in ipairs(all_items_in_group) do
                local pos = GetMediaItemInfo_Value(grp_item, "D_POSITION")
                local len = GetMediaItemInfo_Value(grp_item, "D_LENGTH")
                if start_pos == nil or pos < start_pos then
                    start_pos = pos
                end
                max_end = math.max(max_end, pos + len)
            end
            
            if should_merge_with_previous then
                -- Update the previous group
                local prev_group = groups[#groups]
                prev_group.all_items = all_items_in_group
                prev_group.start_position = start_pos
                prev_group.end_position = max_end
            else
                -- Create new group
                local group = {
                    all_items = all_items_in_group,
                    start_position = start_pos,
                    end_position = max_end
                }
                table.insert(groups, group)
            end
        else
            -- Unnamed item at start - skip it (shouldn't happen based on requirements)
            i = i + 1
        end
    end
    
    return groups
end

---------------------------------------------------------------------

function get_items_containing_midpoint(item)
    -- Returns all items (in folder hierarchy) whose range contains this item's midpoint
    local results = {}
    
    local track = GetMediaItemTrack(item)
    local folder = get_parent_folder(track)
    
    -- Get all tracks to check
    local tracks_to_check = {}
    if folder then
        local children = get_folder_children(folder)
        tracks_to_check[folder] = true
        for _, child in ipairs(children) do
            tracks_to_check[child] = true
        end
    else
        tracks_to_check[track] = true
    end
    
    -- Calculate this item's midpoint
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
    local mid = pos + (len / 2)
    local tolerance = 0.0001
    
    -- Find all items whose range contains this midpoint
    for check_track, _ in pairs(tracks_to_check) do
        local num_items = CountTrackMediaItems(check_track)
        for i = 0, num_items - 1 do
            local check_item = GetTrackMediaItem(check_track, i)
            if check_item ~= item then
                local item_pos = GetMediaItemInfo_Value(check_item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(check_item, "D_LENGTH")
                local item_end = item_pos + item_len
                
                -- Does this item's range contain the midpoint?
                if mid >= (item_pos - tolerance) and mid <= (item_end + tolerance) then
                    table.insert(results, check_item)
                end
            end
        end
    end
    
    return results
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

function empty_items_check(track, num_of_items)
    local count = 0
    for i = 0, num_of_items - 1, 1 do
        local current_item = GetTrackMediaItem(track, i)
        local take = GetActiveTake(current_item)
        if not take then
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------------------

main()