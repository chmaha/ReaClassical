--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

OPTIMIZED VERSION - Performance improvements for large projects

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

local main, shift, color_items, vertical_razor, group_items
local vertical_group, horizontal, vertical, get_color_table
local xfade_check, empty_items_check, get_path, folder_check
local trackname_check, delete_empty_items, pastel_color, nudge_right
local color_group_items, color_folder_children, scroll_to_first_track
local select_children_of_selected_folders, select_next_folder
local select_all_parents, get_item_by_guid, rgba_to_native, get_rank_color
local build_group_map, horizontal_fast, vertical_fast
local find_items_at_position, find_items_at_position_on_selected_tracks
local group_items_fast, get_folder_children

-- Rank color options (matching Notes Dialog)
local RANKS = {
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

function main()
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
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end

    local num_pre_selected = CountSelectedTracks(0)
    local pre_selected = {}
    if num_pre_selected > 0 then
        for i = 0, num_pre_selected - 1, 1 do
            local track = GetSelectedTrack(0, i)
            table.insert(pre_selected, track)
        end
    end

    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    local start_time, end_time = GetSet_ArrangeView2(0, false, 0, 0, 0, false)
    local num_of_project_items = CountMediaItems(0)
    if num_of_project_items == 0 then
        return
    end
    local empty_count = empty_items_check(num_of_project_items)
    if empty_count > 0 then
        delete_empty_items(num_of_project_items)
    end

    PreventUIRefresh(1)
    Undo_BeginBlock()

    -- Clear all group IDs in one pass
    for track_idx = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, track_idx)
        for item_idx = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, item_idx)
            SetMediaItemInfo_Value(item, "I_GROUPID", 0)
        end
    end

    Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
    local folders = folder_check()

    local first_item = GetMediaItem(0, 0)
    local position = GetMediaItemInfo_Value(first_item, "D_POSITION")
    if position == 0.0 then
        shift()
    end

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local color_pref = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[5] then color_pref = tonumber(table[5]) or 0 end
    end

    local edits = false
    if folders == 0 or folders == 1 then
        edits = horizontal_fast()  -- Use optimized version
    else
        vertical_fast()  -- Use optimized version
    end
    
    -- Build group map once for all coloring operations
    local group_map = build_group_map()
    
    PreventUIRefresh(-1)
    color_items(edits, color_pref, group_map)
    PreventUIRefresh(1)

    GetSet_ArrangeView2(0, true, 0, 0, start_time, end_time)
    SetEditCurPos(cur_pos, 0, 0)

    scroll_to_first_track()

    if num_pre_selected > 0 then
        Main_OnCommand(40297, 0) --unselect_all
        SetOnlyTrackSelected(pre_selected[1])
        for _, track in ipairs(pre_selected) do
            if pcall(IsTrackSelected, track) then SetTrackSelected(track, 1) end
        end
    end

    Undo_EndBlock('Prepare Takes', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function build_group_map()
    local groups = {}
    local num_items = CountMediaItems(0)
    
    for i = 0, num_items - 1 do
        local item = GetMediaItem(0, i)
        local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
        
        if group_id > 0 then
            if not groups[group_id] then
                groups[group_id] = {}
            end
            table.insert(groups[group_id], item)
        end
    end
    
    return groups
end

---------------------------------------------------------------------

function find_items_at_position(position, tolerance)
    tolerance = tolerance or 0.0001
    local items = {}
    local num_tracks = CountTracks(0)
    
    for t = 0, num_tracks - 1 do
        local track = GetTrack(0, t)
        local num_items = CountTrackMediaItems(track)
        
        for i = 0, num_items - 1 do
            local item = GetTrackMediaItem(track, i)
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_end = item_pos + item_len
            
            -- Check if position falls within item
            if position >= (item_pos - tolerance) and position <= (item_end + tolerance) then
                table.insert(items, item)
            end
        end
    end
    
    return items
end

---------------------------------------------------------------------

function find_items_at_position_on_selected_tracks(position, tolerance)
    tolerance = tolerance or 0.0001
    local items = {}
    local num_tracks = CountTracks(0)
    
    for t = 0, num_tracks - 1 do
        local track = GetTrack(0, t)
        -- Only check selected tracks
        if IsTrackSelected(track) then
            local num_items = CountTrackMediaItems(track)
            
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len
                
                -- Check if position falls within item
                if position >= (item_pos - tolerance) and position <= (item_end + tolerance) then
                    table.insert(items, item)
                end
            end
        end
    end
    
    return items
end

---------------------------------------------------------------------

function group_items_fast(items, group_id)
    for _, item in ipairs(items) do
        SetMediaItemInfo_Value(item, "I_GROUPID", group_id)
    end
end

---------------------------------------------------------------------

function horizontal_fast()
    local edits = xfade_check()
    local first_track = GetTrack(0, 0)
    if not first_track then return edits end
    
    local num_items = CountTrackMediaItems(first_track)
    if num_items == 0 then return edits end
    
    -- Select all tracks first (like original does)
    Main_OnCommand(40296, 0) -- Track: Select all tracks
    
    local group = 1
    
    -- Iterate through items on first track to establish grouping positions
    for i = 0, num_items - 1 do
        local item = GetTrackMediaItem(first_track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local mid_point = pos + (len / 2)
        
        -- Find all items on SELECTED tracks at this mid-point position
        local items_to_group = find_items_at_position_on_selected_tracks(mid_point)
        
        -- Assign group ID to all found items
        group_items_fast(items_to_group, group)
        
        group = group + 1
    end
    
    -- Create track media/razor editing group
    Main_OnCommand(42579, 0) -- Remove from all groups
    Main_OnCommand(42578, 0) -- Create new group
    Main_OnCommand(40297, 0) -- Unselect all tracks
    
    return edits
end

---------------------------------------------------------------------

function vertical_fast()
    -- Get all folder parent tracks
    local folder_tracks = {}
    local num_tracks = CountTracks(0)
    
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth == 1 then
            table.insert(folder_tracks, track)
        end
    end
    
    if #folder_tracks == 0 then return end
    
    local first_folder = folder_tracks[1]
    local first_folder_children = get_folder_children(first_folder)
    
    -- Select first folder and its children
    SetOnlyTrackSelected(first_folder)
    for _, child in ipairs(first_folder_children) do
        SetTrackSelected(child, true)
    end
    
    -- Process first folder (horizontal grouping like original)
    local num_items = CountTrackMediaItems(first_folder)
    local group = 1
    
    for i = 0, num_items - 1 do
        local item = GetTrackMediaItem(first_folder, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local mid_point = pos + (len / 2)
        
        -- Find items at this position on selected tracks (folder + children)
        local items_to_group = find_items_at_position_on_selected_tracks(mid_point)
        
        group_items_fast(items_to_group, group)
        group = group + 1
    end
    
    -- Create track media/razor editing group for first folder
    Main_OnCommand(42579, 0) -- Remove from all groups
    Main_OnCommand(42578, 0) -- Create new group
    Main_OnCommand(40421, 0) -- Select all items in track
    
    -- Process remaining folders (vertical grouping)
    for f = 2, #folder_tracks do
        local folder = folder_tracks[f]
        local folder_children = get_folder_children(folder)
        
        -- Select this folder and its children
        SetOnlyTrackSelected(folder)
        for _, child in ipairs(folder_children) do
            SetTrackSelected(child, true)
        end
        
        -- Create track media/razor editing group
        Main_OnCommand(42579, 0)
        Main_OnCommand(42578, 0)
        Main_OnCommand(40421, 0) -- Select all items in track
        
        -- For each item on the folder track, group vertically
        local folder_items = CountTrackMediaItems(folder)
        for i = 0, folder_items - 1 do
            local item = GetTrackMediaItem(folder, i)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local mid_point = pos + (len / 2)
            
            -- Find items at this position on selected tracks
            local items_to_group = find_items_at_position_on_selected_tracks(mid_point)
            
            group_items_fast(items_to_group, group)
            group = group + 1
        end
    end
    
    Main_OnCommand(40289, 0) -- Unselect all items
    Main_OnCommand(40297, 0) -- Unselect all tracks
end

---------------------------------------------------------------------

function get_folder_children(parent_track)
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

function shift()
    Main_OnCommand(40182, 0) -- select all items
    nudge_right(1)
    Main_OnCommand(40289, 0) -- unselect all items
end

---------------------------------------------------------------------

function rgba_to_native(rgba)
    local r = (rgba >> 24) & 0xFF
    local g = (rgba >> 16) & 0xFF
    local b = (rgba >> 8) & 0xFF
    return ColorToNative(r, g, b)
end

---------------------------------------------------------------------

function get_rank_color(rank_str)
    if not rank_str or rank_str == "" then
        return nil
    end
    
    local rank_index = tonumber(rank_str)
    if rank_index and rank_index >= 1 and rank_index <= 8 then
        return rgba_to_native(RANKS[rank_index].rgba) | 0x1000000
    end
    
    return nil
end

---------------------------------------------------------------------

function color_items(edits, color_pref, group_map)
    local colors = get_color_table()
    local unedited_color = colors.dest_items

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")

    if workflow == "Horizontal" and not edits then
        local color_index = 0
        local num_items = CountMediaItems(0)

        -- Collect items by group ID
        local groups = {}
        for i = 0, num_items - 1 do
            local item = GetMediaItem(0, i)
            local group_id = GetMediaItemInfo_Value(item, "I_GROUPID") or 0
            if not groups[group_id] then groups[group_id] = {} end
            table.insert(groups[group_id], item)
        end

        -- Sort group IDs
        local sorted_group_ids = {}
        for gid in pairs(groups) do table.insert(sorted_group_ids, gid) end
        table.sort(sorted_group_ids)

        -- Color each group
        local first_group = true
        for _, gid in ipairs(sorted_group_ids) do
            local grouped_items = groups[gid]

            -- Check if any item is ranked and color_pref is 0
            local has_rank = false
            local rank_color = nil
            for _, item in ipairs(grouped_items) do
                local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
                if ranked ~= "" and color_pref == 0 then
                    has_rank = true
                    rank_color = get_rank_color(ranked)
                    break
                end
            end
            
            if has_rank and rank_color then
                -- Apply rank color using optimized function
                for _, item in ipairs(grouped_items) do
                    color_group_items(item, rank_color, group_map)
                    GetSetMediaItemInfo_String(item, "P_EXT:saved_color", rank_color, true)
                end
                
                local first_track = GetMediaItem_Track(grouped_items[1])
                if first_track then
                    SetMediaTrackInfo_Value(first_track, "I_CUSTOMCOLOR", unedited_color)
                    color_folder_children(first_track, unedited_color)
                end
                
                color_index = color_index + 1
                goto continue_group
            end

            -- Determine group color (original logic for non-ranked items)
            local group_color = nil
            for _, item in ipairs(grouped_items) do
                local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                if src_guid ~= "" then
                    local src_item = get_item_by_guid(0, src_guid)
                    if src_item then
                        group_color = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                        break
                    end
                end
            end

            if not group_color then
                if first_group then
                    group_color = unedited_color
                    first_group = false
                else
                    group_color = pastel_color(color_index)
                    color_index = color_index + 1
                end
            end

            -- Apply color using optimized function
            for _, item in ipairs(grouped_items) do
                color_group_items(item, group_color, group_map)
                local color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
                GetSetMediaItemInfo_String(item, "P_EXT:saved_color", color, true)
            end

            local first_track = GetMediaItem_Track(grouped_items[1])
            if first_track then
                SetMediaTrackInfo_Value(first_track, "I_CUSTOMCOLOR", unedited_color)
                color_folder_children(first_track, unedited_color)
            end

            ::continue_group::
        end
    elseif workflow == "Vertical" then
        local num_tracks = CountTracks(0)
        local first_folder_done = false
        local index_for_folder_pastel = 0

        local pastel_folders = {}
        local dest_folders = {}

        -- First pass: categorize folders
        for t = 0, num_tracks - 1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            local is_folder = depth == 1
            local should_color_dest = false

            if is_folder then
                if not first_folder_done then
                    should_color_dest = true
                    first_folder_done = true
                end

                if should_color_dest then
                    table.insert(dest_folders, track)
                else
                    table.insert(pastel_folders, track)
                end
            end
        end

        -- Second pass: pastel folders
        for _, track in ipairs(pastel_folders) do
            local num_items = CountTrackMediaItems(track)
            local folder_color = pastel_color(index_for_folder_pastel)
            SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", folder_color)
            index_for_folder_pastel = index_for_folder_pastel + 1
            color_folder_children(track, folder_color)

            -- Color items
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)
                local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
                
                if ranked ~= "" and color_pref == 0 then
                    local rank_color = get_rank_color(ranked)
                    if rank_color then
                        color_group_items(item, rank_color, group_map)
                    end
                elseif ranked == "" or color_pref == 1 then
                    local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                    local color_val = folder_color
                    if src_guid ~= "" then
                        local src_item = get_item_by_guid(0, src_guid)
                        if src_item then
                            color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                        end
                    end
                    color_group_items(item, color_val, group_map)
                end
            end
        end

        -- Third pass: dest folders
        for _ = 1, 2 do
            for _, track in ipairs(dest_folders) do
                local num_items = CountTrackMediaItems(track)
                local folder_color = unedited_color
                SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", colors.dest_items)
                color_folder_children(track, colors.dest_items)

                for i = 0, num_items - 1 do
                    local item = GetTrackMediaItem(track, i)
                    local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
                    
                    if ranked ~= "" and color_pref == 0 then
                        local rank_color = get_rank_color(ranked)
                        if rank_color then
                            color_group_items(item, rank_color, group_map)
                        end
                    elseif ranked == "" or color_pref == 1 then
                        local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                        local color_val = folder_color
                        if src_guid ~= "" then
                            local src_item = get_item_by_guid(0, src_guid)
                            if src_item then
                                color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                            end
                        end
                        color_group_items(item, color_val, group_map)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------

function xfade_check()
    local first_track = GetTrack(0, 0)
    local num_of_items = CountTrackMediaItems(first_track)
    local xfade = false
    for i = 0, num_of_items - 2 do
        local item1 = GetTrackMediaItem(first_track, i)
        local item2 = GetTrackMediaItem(first_track, i + 1)
        local pos1 = GetMediaItemInfo_Value(item1, "D_POSITION")
        local pos2 = GetMediaItemInfo_Value(item2, "D_POSITION")
        local len1 = GetMediaItemInfo_Value(item1, "D_LENGTH")
        local end1 = pos1 + len1
        if end1 > pos2 then
            xfade = true
            break
        end
    end
    return xfade
end

---------------------------------------------------------------------

function empty_items_check(num_of_items)
    local count = 0
    for i = 0, num_of_items - 1, 1 do
        local current_item = GetMediaItem(0, i)
        local take = GetActiveTake(current_item)
        if not take then
            count = count + 1
        end
    end
    return count
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

function folder_check()
    local folders = 0
    local tracks_per_group = 1
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^LIVE") or trackname_check(track, "^REF")

        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        elseif folders == 1 and not (special_states or special_names) then
            tracks_per_group = tracks_per_group + 1
        end
    end
    return folders, tracks_per_group, total_tracks
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function delete_empty_items(num_of_project_items)
    for i = num_of_project_items - 1, 0, -1 do
        local item = GetMediaItem(0, i)
        local take = GetActiveTake(item)

        if not take then
            DeleteTrackMediaItem(GetMediaItemTrack(item), item)
        end
    end
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

function color_group_items(item, color_val, group_map)
    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_val)
    
    if not group_map then
        -- Fallback to original method if no group_map provided
        local group = GetMediaItemInfo_Value(item, "I_GROUPID")
        if group > 0 then
            local total = CountMediaItems(0)
            for j = 0, total - 1 do
                local other = GetMediaItem(0, j)
                if GetMediaItemInfo_Value(other, "I_GROUPID") == group then
                    SetMediaItemInfo_Value(other, "I_CUSTOMCOLOR", color_val)
                end
            end
        end
    else
        -- Use pre-built group map for O(1) lookup
        local group = GetMediaItemInfo_Value(item, "I_GROUPID")
        if group > 0 and group_map[group] then
            for _, other in ipairs(group_map[group]) do
                SetMediaItemInfo_Value(other, "I_CUSTOMCOLOR", color_val)
            end
        end
    end
end

---------------------------------------------------------------------

function color_folder_children(parent_track, folder_color)
    if not parent_track or not folder_color then return end

    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1

    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end

        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if depth > 0 then
            SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", folder_color)
        end

        depth = depth + folder_depth

        if depth <= 0 then
            break
        end

        idx = idx + 1
    end
end

---------------------------------------------------------------------

function nudge_right(nudgeSamples)
    local sampleRate = GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
    local nudgeAmount = nudgeSamples / sampleRate

    local numTracks = CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = GetTrack(0, i)
        local itemCount = CountTrackMediaItems(track)
        for j = 0, itemCount - 1 do
            local item = GetTrackMediaItem(track, j)
            if IsMediaItemSelected(item) then
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                SetMediaItemInfo_Value(item, "D_POSITION", pos + nudgeAmount)
            end
        end
    end
end

---------------------------------------------------------------------

function scroll_to_first_track()
    local track1 = GetTrack(0, 0)
    if not track1 then return end

    local saved_sel = {}
    local count_sel = CountSelectedTracks(0)
    for i = 0, count_sel - 1 do
        saved_sel[i+1] = GetSelectedTrack(0, i)
    end

    Main_OnCommand(40297, 0)
    SetTrackSelected(track1, true)
    Main_OnCommand(40913, 0)

    Main_OnCommand(40297, 0)
    for _, tr in ipairs(saved_sel) do
        SetTrackSelected(tr, true)
    end
end

---------------------------------------------------------------------

function select_children_of_selected_folders()
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) then
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if depth == 1 then
                local j = i + 1
                while j < track_count do
                    local ch_tr = GetTrack(0, j)
                    SetTrackSelected(ch_tr, true)

                    local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
                    if ch_depth == -1 then
                        break
                    end

                    j = j + 1
                end
            end
        end
    end
end

---------------------------------------------------------------------

function select_next_folder()
    local num_tracks = CountTracks(0)
    local depth = 0
    local target_depth = -1

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if target_depth ~= -1 then
            if depth == target_depth and folder_change == 1 then
                Main_OnCommand(40297, 0)
                SetTrackSelected(tr, true)
                return
            elseif depth < target_depth then
                target_depth = -1
            end
        else
            if IsTrackSelected(tr) and folder_change == 1 then
                target_depth = depth
            end
        end

        depth = depth + folder_change
    end
end

---------------------------------------------------------------------

function select_all_parents()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folderdepth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if folderdepth == 1 then
            SetMediaTrackInfo_Value(tr, "I_SELECTED", 1)
        else
            SetMediaTrackInfo_Value(tr, "I_SELECTED", 0)
        end
    end
end

---------------------------------------------------------------------

function get_item_by_guid(project, guid)
    if not guid or guid == "" then return nil end
    project = project or 0

    local numItems = reaper.CountMediaItems(project)
    for i = 0, numItems - 1 do
        local item = reaper.GetMediaItem(project, i)
        local retval, itemGUID = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
        if retval and itemGUID == guid then
            return item
        end
    end

    return nil
end

---------------------------------------------------------------------

main()