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

local main, get_color_table
local xfade_check, empty_items_check, folder_check
local trackname_check, delete_empty_items, pastel_color
local color_folder_children
local rgba_to_native, get_rank_color
local build_unified_index, build_spatial_index
local find_items_at_position_spatial
local get_folder_children, is_item_colorized, group_items_fast
local update_progress, do_processing_step
local extract_take_number_from_filename

-- Check for ReaImGui
local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'
local ctx = nil
local window_open = true
local progress_stage = ""
local progress_percent = 0.0
local progress_details = ""
local processing_complete = false
local auto_close_timer = 0
local auto_close_delay = 1.0 -- seconds before auto-close

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

function update_progress(stage, percent, details)
    progress_stage = stage
    progress_percent = percent
    progress_details = details or ""
end

---------------------------------------------------------------------

function is_item_colorized(item)
    local _, colorized = GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", false)
    return colorized == "y"
end

---------------------------------------------------------------------

function build_unified_index()
    local group_map = {}
    local items_by_track = {}
    local all_items = {}

    local num_tracks = CountTracks(0)

    for t = 0, num_tracks - 1 do
        local track = GetTrack(0, t)
        items_by_track[track] = {}

        local num_items = CountTrackMediaItems(track)
        for i = 0, num_items - 1 do
            local item = GetTrackMediaItem(track, i)

            local _, existing_take_num = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
            if existing_take_num == "" then
                local take_num = extract_take_number_from_filename(item)
                if take_num then
                    GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", tostring(take_num), true)
                end
            end

            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")

            local item_data = {
                item = item,
                track = track,
                position = pos,
                length = len,
                item_end = pos + len
            }

            table.insert(all_items, item_data)
            table.insert(items_by_track[track], item_data)
        end
    end

    local spatial_buckets, bucket_size = build_spatial_index(all_items)

    return {
        group_map = group_map,
        items_by_track = items_by_track,
        all_items = all_items,
        spatial_buckets = spatial_buckets,
        bucket_size = bucket_size
    }
end

---------------------------------------------------------------------

function build_spatial_index(all_items, bucket_size)
    bucket_size = bucket_size or 0.1
    local buckets = {}

    for _, item_data in ipairs(all_items) do
        local start_bucket = math.floor(item_data.position / bucket_size)
        local end_bucket = math.floor(item_data.item_end / bucket_size)

        for bucket_id = start_bucket, end_bucket do
            if not buckets[bucket_id] then
                buckets[bucket_id] = {}
            end
            table.insert(buckets[bucket_id], item_data)
        end
    end

    return buckets, bucket_size
end

---------------------------------------------------------------------

function find_items_at_position_spatial(spatial_buckets, bucket_size, position, selected_tracks, tolerance)
    tolerance = tolerance or 0.0001
    local items = {}
    local seen = {}

    local bucket_id = math.floor(position / bucket_size)

    for bid = bucket_id - 1, bucket_id + 1 do
        local bucket = spatial_buckets[bid]
        if bucket then
            for _, item_data in ipairs(bucket) do
                if selected_tracks[item_data.track] and not seen[item_data.item] then
                    local item_pos = item_data.position
                    local item_end = item_data.item_end

                    if position >= (item_pos - tolerance) and position <= (item_end + tolerance) then
                        table.insert(items, item_data.item)
                        seen[item_data.item] = true
                    end
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

local processing_step = 0
local group_state
local num_pre_selected = 0
local pre_selected = {}
local num_of_project_items = 0
local empty_count = 0
local folders = 0
local auto_color_pref = 0
local ranking_color_pref = 0
local unified_index = nil
local frame_count = 0

-- Incremental processing state
local current_item_index = 0
local total_items_to_process = 0
local selected_tracks = {}
local group_counter = 1
local folder_tracks = {}
local current_folder_index = 1
local first_folder_children = {}
local items_per_batch = 999999
local groups_per_batch = 999999

-- Coloring state
local sorted_group_ids = {}
local current_group_index = 0
local groups = {}
local colors = nil
local unedited_color = nil

-- Vertical workflow coloring state
local all_folders = {}
local index_for_folder_pastel = 0
local guid_lookup = {}

function do_processing_step()
    -- Give the UI a few frames to render before starting
    if frame_count < 3 then
        frame_count = frame_count + 1
        return false
    end
    if processing_step == 0 then
        update_progress("Checking Items", 5, "Checking for empty items...")
        processing_step = 1
        return false
    elseif processing_step == 1 then
        empty_count = empty_items_check(num_of_project_items)
        if empty_count > 0 then
            delete_empty_items(num_of_project_items)
        end
        processing_step = 2
        return false
    elseif processing_step == 2 then
        Undo_BeginBlock()
        update_progress("Clearing Groups", 8, "Clearing existing group IDs...")
        processing_step = 3
        return false
    elseif processing_step == 3 then
        for track_idx = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, track_idx)
            for item_idx = 0, CountTrackMediaItems(track) - 1 do
                local item = GetTrackMediaItem(track, item_idx)
                SetMediaItemInfo_Value(item, "I_GROUPID", 0)
            end
        end
        Main_OnCommand(40769, 0)
        processing_step = 4
        return false
    elseif processing_step == 4 then
        folders = folder_check()
        local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
        auto_color_pref = 0
        ranking_color_pref = 0
        if input ~= "" then
            local table = {}
            for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
            if table[5] then auto_color_pref = tonumber(table[5]) or 0 end
            if table[6] then ranking_color_pref = tonumber(table[6]) or 0 end
        end
        processing_step = 5
        return false
    elseif processing_step == 5 then
        unified_index = build_unified_index()
        unified_index.group_map = {} -- Initialize group_map here
        processing_step = 6
        return false

        -- HORIZONTAL WORKFLOW - BATCH ITEM PROCESSING
    elseif processing_step == 6 then
        if folders == 0 or folders == 1 then
            -- Start horizontal workflow
            xfade_check()
            local first_track = GetTrack(0, 0)
            if not first_track then
                processing_step = 100 -- Skip to finalization
                return false
            end

            total_items_to_process = CountTrackMediaItems(first_track)
            if total_items_to_process == 0 then
                processing_step = 100 -- Skip to finalization
                return false
            end

            Main_OnCommand(40296, 0) -- Select all tracks

            selected_tracks = {}
            local num_tracks = CountSelectedTracks(0)
            for i = 0, num_tracks - 1 do
                selected_tracks[GetSelectedTrack(0, i)] = true
            end

            current_item_index = 0
            group_counter = 1
            update_progress("Grouping Items", 30, string.format("Processing items (0/%d)", total_items_to_process))
            processing_step = 7 -- Go to horizontal processing loop
        else
            -- Start vertical workflow
            folder_tracks = {}
            local num_tracks = CountTracks(0)

            for i = 0, num_tracks - 1 do
                local track = GetTrack(0, i)
                local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
                if depth == 1 then
                    table.insert(folder_tracks, track)
                end
            end

            if #folder_tracks == 0 then
                processing_step = 100 -- Skip to finalization
                return false
            end

            local first_folder = folder_tracks[1]
            first_folder_children = get_folder_children(first_folder)

            selected_tracks = { [first_folder] = true }
            for _, child in ipairs(first_folder_children) do
                selected_tracks[child] = true
            end

            total_items_to_process = CountTrackMediaItems(first_folder)
            current_item_index = 0
            group_counter = 1
            current_folder_index = 1

            update_progress("Grouping Items", 30, string.format("Folder 1 (0/%d items)", total_items_to_process))
            processing_step = 20 -- Go to vertical processing loop
        end
        return false

        -- HORIZONTAL WORKFLOW - PROCESS BATCH OF ITEMS PER FRAME
    elseif processing_step == 7 then
        local first_track = GetTrack(0, 0)
        if current_item_index < total_items_to_process then
            -- Process a batch of items
            local batch_end = math.min(current_item_index + items_per_batch, total_items_to_process)

            for i = current_item_index, batch_end - 1 do
                local item = GetTrackMediaItem(first_track, i)
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local mid_point = pos + (len / 2)

                local items_to_group = find_items_at_position_spatial(
                    unified_index.spatial_buckets,
                    unified_index.bucket_size,
                    mid_point,
                    selected_tracks
                )

                group_items_fast(items_to_group, group_counter)

                -- Build group_map as we go
                if not unified_index.group_map[group_counter] then
                    unified_index.group_map[group_counter] = {}
                end
                for _, grouped_item in ipairs(items_to_group) do
                    table.insert(unified_index.group_map[group_counter], grouped_item)
                end

                group_counter = group_counter + 1
            end

            current_item_index = batch_end

            local progress = 30 + (current_item_index / total_items_to_process * 30)
            update_progress("Grouping Items", progress,
                string.format("Processing items (%d/%d)", current_item_index, total_items_to_process))
            return false
        else
            -- Finished horizontal grouping
            Main_OnCommand(42579, 0)
            Main_OnCommand(42578, 0)
            Main_OnCommand(40297, 0)
            processing_step = 101 -- Go directly to coloring
            return false
        end

        -- VERTICAL WORKFLOW - PROCESS BATCH OF ITEMS PER FRAME (FIRST FOLDER)
    elseif processing_step == 20 then
        local first_folder = folder_tracks[1]
        if current_item_index < total_items_to_process then
            -- Process a batch of items
            local batch_end = math.min(current_item_index + items_per_batch, total_items_to_process)

            for i = current_item_index, batch_end - 1 do
                local item = GetTrackMediaItem(first_folder, i)
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local mid_point = pos + (len / 2)

                local items_to_group = find_items_at_position_spatial(
                    unified_index.spatial_buckets,
                    unified_index.bucket_size,
                    mid_point,
                    selected_tracks
                )

                group_items_fast(items_to_group, group_counter)

                -- Build group_map as we go
                if not unified_index.group_map[group_counter] then
                    unified_index.group_map[group_counter] = {}
                end
                for _, grouped_item in ipairs(items_to_group) do
                    table.insert(unified_index.group_map[group_counter], grouped_item)
                end

                group_counter = group_counter + 1
            end

            current_item_index = batch_end

            local progress = 30 + (current_item_index / total_items_to_process * 15)
            update_progress("Grouping Items", progress,
                string.format("Folder 1 (%d/%d items)", current_item_index, total_items_to_process))
            return false
        else
            current_folder_index = 2
            processing_step = 21 -- Go to remaining folders
            return false
        end

        -- VERTICAL WORKFLOW - PROCESS REMAINING FOLDERS
    elseif processing_step == 21 then
        update_progress("Debug", 45,
            string.format("Step 21 START - folder_index=%d, total=%d", current_folder_index, #folder_tracks))

        if current_folder_index <= #folder_tracks then
            local folder = folder_tracks[current_folder_index]
            local folder_children = get_folder_children(folder)

            selected_tracks = { [folder] = true }
            for _, child in ipairs(folder_children) do
                selected_tracks[child] = true
            end

            total_items_to_process = CountTrackMediaItems(folder)
            current_item_index = 0

            update_progress("Grouping Items", 45 + (current_folder_index / #folder_tracks * 15),
                string.format("Folder %d/%d (0/%d items)", current_folder_index, #folder_tracks, total_items_to_process))
            processing_step = 22 -- Process items in this folder
            return false
        else
            processing_step = 101 -- Go directly to coloring
            return false
        end

        -- VERTICAL WORKFLOW - PROCESS BATCH OF ITEMS IN CURRENT FOLDER
    elseif processing_step == 22 then
        local folder = folder_tracks[current_folder_index]
        if current_item_index < total_items_to_process then
            -- Process a batch of items
            local batch_end = math.min(current_item_index + items_per_batch, total_items_to_process)

            for i = current_item_index, batch_end - 1 do
                local item = GetTrackMediaItem(folder, i)
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local mid_point = pos + (len / 2)

                local items_to_group = find_items_at_position_spatial(
                    unified_index.spatial_buckets,
                    unified_index.bucket_size,
                    mid_point,
                    selected_tracks
                )

                group_items_fast(items_to_group, group_counter)

                -- Build group_map as we go
                if not unified_index.group_map[group_counter] then
                    unified_index.group_map[group_counter] = {}
                end
                for _, grouped_item in ipairs(items_to_group) do
                    table.insert(unified_index.group_map[group_counter], grouped_item)
                end

                group_counter = group_counter + 1
            end

            current_item_index = batch_end

            local base_progress = 45 + ((current_folder_index - 2) / (#folder_tracks - 1) * 15)
            local item_progress = (current_item_index / total_items_to_process) * (15 / (#folder_tracks - 1))
            update_progress("Grouping Items", base_progress + item_progress,
                string.format("Folder %d (%d/%d items)",
                    current_folder_index, current_item_index, total_items_to_process))
            return false
        else
            -- Finished this folder, move to next
            current_folder_index = current_folder_index + 1
            processing_step = 21
            return false
        end

        -- FINALIZATION - Skip directly to coloring preparation
    elseif processing_step == 101 then
        local _, workflow_check = GetProjExtState(0, "ReaClassical", "Workflow")

        if workflow_check == "Horizontal" then
            -- Prepare for coloring
            update_progress("Preparing Colors", 65, "Setting up color data...")
            colors = get_color_table()
            unedited_color = colors.dest_items

            -- Initialize state for incremental group building
            groups = {}
            current_item_index = 0
            total_items_to_process = CountMediaItems(0)
            processing_step = 101.5 -- Go to incremental group building
        else
            -- Vertical workflow - skip coloring here, do it after window closes
            update_progress("Finalizing", 90, "Preparing to finalize...")
            processing_step = 110 -- Skip to finalization
        end
        return false

        -- BUILD GROUPS TABLE INCREMENTALLY
    elseif processing_step == 101.5 then
        if current_item_index < total_items_to_process then
            -- Process a batch of items
            local batch_end = math.min(current_item_index + items_per_batch, total_items_to_process)

            for i = current_item_index, batch_end - 1 do
                local item = GetMediaItem(0, i)
                local group_id = GetMediaItemInfo_Value(item, "I_GROUPID") or 0
                if not groups[group_id] then groups[group_id] = {} end
                table.insert(groups[group_id], item)
            end

            current_item_index = batch_end

            local progress = 65 + (current_item_index / total_items_to_process * 5)
            update_progress("Preparing Colors", progress,
                string.format("Building color groups (%d/%d items)", current_item_index, total_items_to_process))
            return false
        else
            -- Done building groups, prepare to color
            sorted_group_ids = {}
            for gid in pairs(groups) do table.insert(sorted_group_ids, gid) end
            table.sort(sorted_group_ids)

            current_group_index = 1
            update_progress("Coloring Items (Pass 1)", 70,
                string.format("Starting initial coloring (%d groups)", #sorted_group_ids))
            processing_step = 102 -- Go to pass 1 coloring
            return false
        end

        -- HORIZONTAL WORKFLOW - PASS 1: COLOR BY RANK OR TAKE NUMBER
    elseif processing_step == 102 then
        if current_group_index <= #sorted_group_ids then
            -- Process a batch of groups
            local batch_end = math.min(current_group_index + groups_per_batch, #sorted_group_ids + 1)

            for i = current_group_index, batch_end - 1 do
                local gid = sorted_group_ids[i]
                local grouped_items = groups[gid]

                -- Extract take number from first item in group
                local take_number = nil
                local _, take_num_str = GetSetMediaItemInfo_String(grouped_items[1], "P_EXT:item_take_num", "", false)
                if take_num_str ~= "" then
                    take_number = tonumber(take_num_str)
                end

                -- Check if any item is ranked and ranking_color_pref is 0
                local has_rank = false
                local rank_color = nil
                for _, item in ipairs(grouped_items) do
                    if not is_item_colorized(item) then
                        local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
                        if ranked ~= "" and ranking_color_pref == 0 then
                            has_rank = true
                            rank_color = get_rank_color(ranked)
                            break
                        end
                    end
                end

                -- Pass 1: Color by rank or take number (ignore src_guid for now)
                local final_color
                if has_rank and rank_color then
                    final_color = rank_color
                elseif auto_color_pref == 1 then
                    final_color = 0
                elseif take_number then
                    final_color = pastel_color(take_number - 1)
                else
                    final_color = 0
                end

                -- Apply color to all items in group (optimized - use group_map)
                local group_id = GetMediaItemInfo_Value(grouped_items[1], "I_GROUPID")
                if group_id > 0 and unified_index.group_map[group_id] then
                    -- Use pre-built group map for O(1) lookup
                    for _, item in ipairs(unified_index.group_map[group_id]) do
                        if not is_item_colorized(item) then
                            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", final_color)
                            GetSetMediaItemInfo_String(item, "P_EXT:saved_color", final_color, true)
                        end
                    end
                else
                    -- Fallback for ungrouped items
                    for _, item in ipairs(grouped_items) do
                        if not is_item_colorized(item) then
                            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", final_color)
                            GetSetMediaItemInfo_String(item, "P_EXT:saved_color", final_color, true)
                        end
                    end
                end
            end

            current_group_index = batch_end

            local progress = 70 + ((current_group_index - 1) / #sorted_group_ids * 10)
            update_progress("Coloring Items (Pass 1)", progress,
                string.format("Initial coloring (%d/%d groups)", current_group_index - 1, #sorted_group_ids))
            return false
        else
            -- Done with pass 1, build GUID lookup for pass 2
            update_progress("Coloring Items", 80, "Building GUID lookup table...")

            -- Build a lookup table: guid -> item for fast O(1) lookups in pass 2
            guid_lookup = {}
            for _, item_data in ipairs(unified_index.all_items) do
                local _, guid = GetSetMediaItemInfo_String(item_data.item, "GUID", "", false)
                if guid ~= "" then
                    guid_lookup[guid] = item_data.item
                end
            end

            -- Reset for Pass 2: iterate through all items
            current_item_index = 0
            total_items_to_process = CountMediaItems(0)
            processing_step = 102.5 -- Go to pass 2
            return false
        end

        -- HORIZONTAL WORKFLOW - PASS 2: RECOLOR ITEMS WITH SRC_GUID (like vertical workflow)
    elseif processing_step == 102.5 then
        if current_item_index < total_items_to_process then
            -- Process a batch of items
            local batch_end = math.min(current_item_index + items_per_batch, total_items_to_process)

            for i = current_item_index, batch_end - 1 do
                local item = GetMediaItem(0, i)

                -- Skip if this item is manually colorized
                if not is_item_colorized(item) then
                    local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")

                    if group_id > 0 and unified_index.group_map[group_id] then
                        local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)

                        -- Only process non-ranked items with src_guid (unless auto_color_pref == 1 or ranking_color_pref == 1)
                        if (ranked == "" or ranking_color_pref == 1) then
                            local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                            if src_guid ~= "" and auto_color_pref ~= 1 then
                                -- Use O(1) lookup instead of O(n) get_item_by_guid
                                local src_item = guid_lookup[src_guid]
                                if src_item then
                                    local color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")

                                    -- Color all items in this group (skip individual checks for speed)
                                    for _, grouped_item in ipairs(unified_index.group_map[group_id]) do
                                        SetMediaItemInfo_Value(grouped_item, "I_CUSTOMCOLOR", color_val)
                                        GetSetMediaItemInfo_String(grouped_item, "P_EXT:saved_color", color_val, true)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            current_item_index = batch_end

            local progress = 80 + (current_item_index / total_items_to_process * 10)
            update_progress("Coloring Items (Pass 2)", progress,
                string.format("Coloring edits (%d/%d items)", current_item_index, total_items_to_process))
            return false
        else
            -- Done coloring groups, now color tracks
            processing_step = 103
            return false
        end
    elseif processing_step == 103 then
        update_progress("Coloring Items", 90, "Coloring tracks...")
        -- Color all tracks at once at the end
        for _, gid in ipairs(sorted_group_ids) do
            local grouped_items = groups[gid]
            if grouped_items and #grouped_items > 0 then
                local first_track = GetMediaItem_Track(grouped_items[1])
                if first_track then
                    SetMediaTrackInfo_Value(first_track, "I_CUSTOMCOLOR", unedited_color)
                    color_folder_children(first_track, unedited_color)
                end
            end
        end
        processing_step = 110 -- Go to finalization
        return false
    elseif processing_step == 110 then
        update_progress("Preparing Colors", 90, "Setting up for coloring...")

        local _, workflow_check = GetProjExtState(0, "ReaClassical", "Workflow")
        if workflow_check == "Vertical" or workflow_check ~= "Horizontal" then
            -- Prepare vertical coloring
            colors = get_color_table()
            unedited_color = colors.dest_items

            -- Build ALL folder lists (both pastel and dest)
            local num_tracks = CountTracks(0)
            local first_folder_done = false
            local pastel_folders = {}
            local dest_folders = {}

            for t = 0, num_tracks - 1 do
                local track = GetTrack(0, t)
                local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
                if depth == 1 then
                    if not first_folder_done then
                        table.insert(dest_folders, track)
                        first_folder_done = true
                    else
                        table.insert(pastel_folders, track)
                    end
                end
            end

            -- Combine all folders for processing
            all_folders = {}
            for _, f in ipairs(pastel_folders) do table.insert(all_folders, { folder = f, is_dest = false }) end
            for _, f in ipairs(dest_folders) do table.insert(all_folders, { folder = f, is_dest = true }) end

            index_for_folder_pastel = 0
            current_folder_index = 0

            processing_step = 110.1 -- Go to pass 1
        else
            processing_step = 111   -- Skip to coloring message for horizontal
        end
        return false

        -- VERTICAL WORKFLOW - PASS 1: Color all folders and items
    elseif processing_step == 110.1 then
        if current_folder_index < #all_folders then
            current_folder_index = current_folder_index + 1
            local folder_info = all_folders[current_folder_index]
            local track = folder_info.folder
            local is_dest = folder_info.is_dest

            -- Set folder color
            local folder_color
            if is_dest then
                folder_color = colors.dest_items
            else
                folder_color = pastel_color(index_for_folder_pastel)
                index_for_folder_pastel = index_for_folder_pastel + 1
            end

            SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", folder_color)
            color_folder_children(track, folder_color)

            -- ONLY process items on the parent folder track (first track)
            -- These are the "parent" items that represent each group
            local num_items = CountTrackMediaItems(track)
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)

                -- Skip if this parent item is manually colorized
                if not is_item_colorized(item) then
                    local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")

                    if group_id > 0 and unified_index.group_map[group_id] then
                        local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)

                        local color_to_use
                        if ranked ~= "" and ranking_color_pref == 0 then
                            color_to_use = get_rank_color(ranked)
                        elseif auto_color_pref == 1 then
                            -- When auto_color_pref == 1, use default REAPER color (0)
                            color_to_use = 0
                        else
                            -- Pass 1: just use folder color, ignore src_guid
                            color_to_use = folder_color
                        end

                        if color_to_use then
                            -- Color all items in this group (skip individual checks for speed)
                            for _, grouped_item in ipairs(unified_index.group_map[group_id]) do
                                SetMediaItemInfo_Value(grouped_item, "I_CUSTOMCOLOR", color_to_use)
                            end
                        end
                    end
                end
            end

            local progress = 90 + (current_folder_index / (#all_folders * 2) * 8)
            update_progress("Coloring Items (Pass 1)", progress,
                string.format("Initial coloring: folder %d of %d", current_folder_index, #all_folders))
            return false
        else
            -- Pass 1 done, build GUID lookup table for pass 2
            update_progress("Coloring Items", 94, "Building GUID lookup table...")

            -- Build a lookup table: guid -> item for fast O(1) lookups in pass 2
            guid_lookup = {}
            for _, item_data in ipairs(unified_index.all_items) do
                local _, guid = GetSetMediaItemInfo_String(item_data.item, "GUID", "", false)
                if guid ~= "" then
                    guid_lookup[guid] = item_data.item
                end
            end

            current_folder_index = 0
            processing_step = 110.2
            return false
        end

        -- VERTICAL WORKFLOW - PASS 2: Recolor items with src_guid to get source colors
    elseif processing_step == 110.2 then
        if current_folder_index < #all_folders then
            current_folder_index = current_folder_index + 1
            local folder_info = all_folders[current_folder_index]
            local track = folder_info.folder

            -- ONLY process items on the parent folder track (first track)
            local num_items = CountTrackMediaItems(track)
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)

                -- Skip if this parent item is manually colorized
                if not is_item_colorized(item) then
                    local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")

                    if group_id > 0 and unified_index.group_map[group_id] then
                        local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)

                        -- Only process non-ranked items with src_guid (unless auto_color_pref == 1 or ranking_color_pref == 1)
                        if (ranked == "" or ranking_color_pref == 1) then
                            local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                            if src_guid ~= "" and auto_color_pref ~= 1 then
                                -- Use O(1) lookup instead of O(n) get_item_by_guid
                                local src_item = guid_lookup[src_guid]
                                if src_item then
                                    local color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")

                                    -- Color all items in this group (skip individual checks for speed)
                                    for _, grouped_item in ipairs(unified_index.group_map[group_id]) do
                                        SetMediaItemInfo_Value(grouped_item, "I_CUSTOMCOLOR", color_val)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            local progress = 90 + ((#all_folders + current_folder_index) / (#all_folders * 2) * 8)
            update_progress("Coloring Items (Pass 2)", progress,
                string.format("Coloring edits: folder %d of %d", current_folder_index, #all_folders))
            return false
        else
            -- Done coloring
            processing_step = 112 -- Skip to selection restoration
            return false
        end
    elseif processing_step == 111 then
        -- Horizontal workflow coloring message
        update_progress("Coloring Items", 95, "Applying colors - this will take a moment...")
        processing_step = 111.5
        return false
    elseif processing_step == 111.5 then
        Undo_EndBlock('Prepare Takes', -1)
        processing_step = 112
        return false
    elseif processing_step == 112 then
        -- Restore selections AFTER coloring
        update_progress("Finalizing", 98, "Restoring selections...")
        if num_pre_selected > 0 then
            Main_OnCommand(40297, 0)
            if pre_selected[1] and pcall(SetOnlyTrackSelected, pre_selected[1]) then
                for i = 2, #pre_selected do
                    if pre_selected[i] then
                        pcall(SetTrackSelected, pre_selected[i], true)
                    end
                end
            end
        end
        PreventUIRefresh(-1)
        UpdateArrange()
        UpdateTimeline()
        update_progress("Complete", 100, "All done!")
        return true -- Processing complete
    end
    return false
end

function main()
    if window_open and not processing_complete then
        local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoResize

        -- Center window on first display and set fixed size
        if frame_count == 0 then
            local viewport_center_x, viewport_center_y = ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))
            ImGui.SetNextWindowPos(ctx, viewport_center_x, viewport_center_y, ImGui.Cond_Appearing, 0.5, 0.5)
        end

        -- Fixed size
        ImGui.SetNextWindowSize(ctx, 420, 120, ImGui.Cond_Always)

        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical - Preparing Takes", true, window_flags)
        window_open = open_ref

        if opened then
            ImGui.Text(ctx, progress_stage)
            ImGui.Spacing(ctx)

            ImGui.PushItemWidth(ctx, 400)
            ImGui.ProgressBar(ctx, progress_percent / 100.0, 0, 0)
            ImGui.PopItemWidth(ctx)

            if progress_details ~= "" then
                ImGui.Spacing(ctx)
                ImGui.TextWrapped(ctx, progress_details)
            end

            ImGui.End(ctx)
        end

        -- Process one step per frame
        processing_complete = do_processing_step()
        defer(main)
    elseif processing_complete then
        -- Show completion message
        local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoResize

        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical - Preparing Takes", true, window_flags)
        window_open = open_ref

        if opened then
            ImGui.Text(ctx, "✓ Processing Complete")
            ImGui.Spacing(ctx)

            -- Keep progress bar at 100% to maintain layout
            ImGui.PushItemWidth(ctx, 400)
            ImGui.ProgressBar(ctx, 1.0, 0, 0)
            ImGui.PopItemWidth(ctx)

            ImGui.Spacing(ctx)
            ImGui.Text(ctx, "Takes prepared successfully!")
            ImGui.End(ctx)
        end

        auto_close_timer = auto_close_timer + 1
        if auto_close_timer > (auto_close_delay * 30) then -- ~30 fps
            window_open = false
            SetProjExtState(0, "ReaClassical", "Prepared_Takes", "y")
            return
        end

        defer(main)
    end
end

-- Initialize and validate
local _, workflow_check = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow_check == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

group_state = GetToggleCommandState(1156)
if group_state ~= 1 then
    Main_OnCommand(1156, 0)
end

num_pre_selected = CountSelectedTracks(0)
if num_pre_selected > 0 then
    for i = 0, num_pre_selected - 1, 1 do
        local track = GetSelectedTrack(0, i)
        table.insert(pre_selected, track)
    end
end

num_of_project_items = CountMediaItems(0)
if num_of_project_items == 0 then
    return
end

PreventUIRefresh(1)
-- Initialize ImGui context and start
ctx = ImGui.CreateContext("ReaClassical Prepare Takes")
update_progress("Initializing", 0, "Starting preparation...")

defer(main)

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

function xfade_check()
    local first_track = GetTrack(0, 0)
    local num_of_items = CountTrackMediaItems(first_track)
    local xfade = false
    local tolerance = 0.001

    for i = 0, num_of_items - 2 do
        local item1 = GetTrackMediaItem(first_track, i)
        local item2 = GetTrackMediaItem(first_track, i + 1)
        local pos1 = GetMediaItemInfo_Value(item1, "D_POSITION")
        local pos2 = GetMediaItemInfo_Value(item2, "D_POSITION")
        local len1 = GetMediaItemInfo_Value(item1, "D_LENGTH")
        local end1 = pos1 + len1
        if end1 > (pos2 + tolerance) then
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
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    package.path = package.path .. ";" .. script_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
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
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y"
            or listenback_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^LIVE") or trackname_check(track, "^REF") or trackname_check(track, "^LISTENBACK")

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
    local hue = (index * golden_ratio_conjugate) % 1.0

    local saturation = 0.45 + 0.15 * math.sin(index * 1.7)
    local lightness = 0.70 + 0.1 * math.cos(index * 1.1)

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

function extract_take_number_from_filename(item)
    local take = GetActiveTake(item)
    if not take then return nil end

    local source = GetMediaItemTake_Source(take)
    if not source then return nil end

    local filename = GetMediaSourceFileName(source, "")

    -- Match any number that occurs just before the file extension
    -- e.g., "left_T056.wav" -> 056, "violin_123.flac" -> 123, "take42.wav" -> 42
    local take_num = string.match(filename, "(%d+)%.[^.]+$")

    if take_num then
        return tonumber(take_num)
    end

    return nil
end
