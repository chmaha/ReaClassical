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
local build_spatial_index
local find_items_at_position_spatial
local get_folder_children, is_item_colorized
local get_folder_items_at_midpoint
local update_progress, do_processing_step
local extract_take_number_from_filename

-- Check for ReaImGui
local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

local group_state = GetToggleCommandState(1156)
if group_state ~= 1 then
    Main_OnCommand(1156, 0)     -- Enable item grouping
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
local auto_close_delay = 1.0

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

-- Returns all items on tracks folder_start..folder_end whose span contains
-- the midpoint of ref_item. Replaces I_GROUPID-based peer lookup.
function get_folder_items_at_midpoint(ref_item, folder_start, folder_end)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
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

-- Resolve folder track index range (0-based) for a given folder parent track.
local function get_folder_range(folder_track)
    local folder_start = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
    local folder_end = folder_start
    local num_tracks = CountTracks(0)
    local x = folder_start + 1
    while x < num_tracks do
        local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
        folder_end = x
        if d < 0 then break end
        x = x + 1
    end
    return folder_start, folder_end
end

---------------------------------------------------------------------

function build_spatial_index(all_items, bucket_size)
    bucket_size = bucket_size or 0.1
    local buckets = {}
    for _, item_data in ipairs(all_items) do
        local start_bucket = math.floor(item_data.position / bucket_size)
        local end_bucket   = math.floor(item_data.item_end / bucket_size)
        for bucket_id = start_bucket, end_bucket do
            if not buckets[bucket_id] then buckets[bucket_id] = {} end
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
        if depth > 0 then table.insert(children, tr) end
        depth = depth + folder_depth
        if depth <= 0 then break end
        idx = idx + 1
    end
    return children
end

---------------------------------------------------------------------

local processing_step = 0
local num_pre_selected = 0
local pre_selected = {}
local num_of_project_items = 0
local empty_count = 0
local folders = 0
local auto_color_pref = 0
local ranking_color_pref = 0
local frame_count = 0

-- Processing state
local current_item_index = 0
local total_items_to_process = 0
local folder_tracks = {}
local current_folder_index = 1
local first_folder_children = {}

-- Coloring state
local colors = nil
local unedited_color = nil
local all_folders = {}
local index_for_folder_pastel = 0
local guid_lookup = {}

-- Spatial index (built once, used for take number extraction only)
local spatial_buckets = nil
local spatial_bucket_size = 0.1
local all_items_flat = {}

function do_processing_step()
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
        if empty_count > 0 then delete_empty_items(num_of_project_items) end
        processing_step = 2
        return false
    elseif processing_step == 2 then
        Undo_BeginBlock()
        update_progress("Scanning Items", 8, "Building item index...")
        processing_step = 3
        return false
    elseif processing_step == 3 then
        -- Clear any existing group IDs from previous runs
        for track_idx = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, track_idx)
            for item_idx = 0, CountTrackMediaItems(track) - 1 do
                local item = GetTrackMediaItem(track, item_idx)
                SetMediaItemInfo_Value(item, "I_GROUPID", 0)
            end
        end
        Main_OnCommand(40769, 0) -- unselect all items
        processing_step = 3.5
        return false
    elseif processing_step == 3.5 then
        -- Conform child items to their parent: copy position, length, source offset
        -- and fade lengths/shapes from each parent track item to all folder peers.
        -- Corrects any child misalignment before coloring begins.
        local num_tracks = CountTracks(0)
        for t = 0, num_tracks - 1 do
            local track = GetTrack(0, t)
            if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                local folder_start = t
                local folder_end = t
                local x = t + 1
                while x < num_tracks do
                    local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                    folder_end = x
                    if d < 0 then break end
                    x = x + 1
                end
                local n = CountTrackMediaItems(track)
                for i = 0, n - 1 do
                    local ref_item = GetTrackMediaItem(track, i)
                    local ref_take = GetActiveTake(ref_item)
                    if ref_take then
                        local ref_pos             = GetMediaItemInfo_Value(ref_item, "D_POSITION")
                        local ref_len             = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
                        local ref_soffs           = GetMediaItemTakeInfo_Value(ref_take, "D_STARTOFFS")
                        local ref_fadeinlen       = GetMediaItemInfo_Value(ref_item, "D_FADEINLEN")
                        local ref_fadeoutlen      = GetMediaItemInfo_Value(ref_item, "D_FADEOUTLEN")
                        local ref_fadeinlen_auto  = GetMediaItemInfo_Value(ref_item, "D_FADEINLEN_AUTO")
                        local ref_fadeoutlen_auto = GetMediaItemInfo_Value(ref_item, "D_FADEOUTLEN_AUTO")
                        local ref_fadeinshape     = GetMediaItemInfo_Value(ref_item, "C_FADEINSHAPE")
                        local ref_fadeoutshape    = GetMediaItemInfo_Value(ref_item, "C_FADEOUTSHAPE")
                        local peers               = get_folder_items_at_midpoint(ref_item, folder_start, folder_end)
                        for _, peer in ipairs(peers) do
                            if peer ~= ref_item then
                                local peer_take = GetActiveTake(peer)
                                if peer_take then
                                    SetMediaItemInfo_Value(peer, "D_POSITION", ref_pos)
                                    SetMediaItemInfo_Value(peer, "D_LENGTH", ref_len)
                                    SetMediaItemTakeInfo_Value(peer_take, "D_STARTOFFS", ref_soffs)
                                    SetMediaItemInfo_Value(peer, "D_FADEINLEN", ref_fadeinlen)
                                    SetMediaItemInfo_Value(peer, "D_FADEOUTLEN", ref_fadeoutlen)
                                    SetMediaItemInfo_Value(peer, "D_FADEINLEN_AUTO", ref_fadeinlen_auto)
                                    SetMediaItemInfo_Value(peer, "D_FADEOUTLEN_AUTO", ref_fadeoutlen_auto)
                                    SetMediaItemInfo_Value(peer, "C_FADEINSHAPE", ref_fadeinshape)
                                    SetMediaItemInfo_Value(peer, "C_FADEOUTSHAPE", ref_fadeoutshape)
                                end
                            end
                        end
                    end
                end
            end
        end
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
        -- Build flat item list and spatial index for take number extraction
        all_items_flat = {}
        for t = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, t)
            for i = 0, CountTrackMediaItems(track) - 1 do
                local item = GetTrackMediaItem(track, i)
                -- Extract and store take number while we're here
                local _, existing = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
                if existing == "" then
                    local take_num = extract_take_number_from_filename(item)
                    if take_num then
                        GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", tostring(take_num), true)
                    end
                end
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                table.insert(all_items_flat, {
                    item = item,
                    track = track,
                    position = pos,
                    length = len,
                    item_end = pos + len
                })
            end
        end
        spatial_buckets, spatial_bucket_size = build_spatial_index(all_items_flat, 0.1)
        processing_step = 6
        return false
    elseif processing_step == 6 then
        -- No grouping needed — go straight to coloring
        if folders == 0 or folders == 1 then
            update_progress("Coloring Items", 30, "Preparing horizontal coloring...")
            processing_step = 101
        else
            update_progress("Coloring Items", 30, "Preparing vertical coloring...")
            processing_step = 110
        end
        return false

        -- HORIZONTAL WORKFLOW COLORING
    elseif processing_step == 101 then
        colors = get_color_table()
        unedited_color = colors.dest_items

        -- Collect folder tracks for horizontal (just one folder)
        folder_tracks = {}
        for t = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, t)
            if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                table.insert(folder_tracks, track)
                break -- horizontal has one folder
            end
        end

        if #folder_tracks == 0 then
            processing_step = 112
            return false
        end

        local first_folder = folder_tracks[1]
        total_items_to_process = CountTrackMediaItems(first_folder)
        current_item_index = 0
        update_progress("Coloring Items (Pass 1)", 35,
            string.format("Coloring items (0/%d)", total_items_to_process))
        processing_step = 102
        return false
    elseif processing_step == 102 then
        -- Horizontal pass 1: color by rank or take number
        local first_folder = folder_tracks[1]
        local folder_start, folder_end = get_folder_range(first_folder)

        if current_item_index < total_items_to_process then
            local batch_end = math.min(current_item_index + 999999, total_items_to_process)
            for i = current_item_index, batch_end - 1 do
                local ref_item = GetTrackMediaItem(first_folder, i)
                if not is_item_colorized(ref_item) then
                    local peers = get_folder_items_at_midpoint(ref_item, folder_start, folder_end)

                    -- Determine color from rank or take number
                    local _, ranked = GetSetMediaItemInfo_String(ref_item, "P_EXT:item_rank", "", false)
                    local color_to_use
                    if ranked ~= "" and ranking_color_pref == 0 then
                        color_to_use = get_rank_color(ranked)
                    elseif auto_color_pref == 1 then
                        color_to_use = 0
                    else
                        local _, take_num_str = GetSetMediaItemInfo_String(ref_item, "P_EXT:item_take_num", "", false)
                        local take_number = tonumber(take_num_str)
                        color_to_use = take_number and pastel_color(take_number - 1) or 0
                    end

                    for _, peer in ipairs(peers) do
                        if not is_item_colorized(peer) then
                            SetMediaItemInfo_Value(peer, "I_CUSTOMCOLOR", color_to_use)
                            GetSetMediaItemInfo_String(peer, "P_EXT:saved_color", color_to_use, true)
                        end
                    end
                end
            end
            current_item_index = batch_end
            local progress = 35 + (current_item_index / total_items_to_process * 25)
            update_progress("Coloring Items (Pass 1)", progress,
                string.format("Coloring items (%d/%d)", current_item_index, total_items_to_process))
            return false
        else
            -- Build GUID lookup for pass 2
            guid_lookup = {}
            for _, item_data in ipairs(all_items_flat) do
                local _, guid = GetSetMediaItemInfo_String(item_data.item, "GUID", "", false)
                if guid ~= "" then guid_lookup[guid] = item_data.item end
            end
            current_item_index = 0
            processing_step = 102.5
            return false
        end
    elseif processing_step == 102.5 then
        -- Horizontal pass 2: recolor edits to match source color
        local first_folder = folder_tracks[1]
        local folder_start, folder_end = get_folder_range(first_folder)

        if current_item_index < total_items_to_process then
            local batch_end = math.min(current_item_index + 999999, total_items_to_process)
            for i = current_item_index, batch_end - 1 do
                local ref_item = GetTrackMediaItem(first_folder, i)
                if not is_item_colorized(ref_item) then
                    local _, ranked = GetSetMediaItemInfo_String(ref_item, "P_EXT:item_rank", "", false)
                    if (ranked == "" or ranking_color_pref == 1) then
                        local _, src_guid = GetSetMediaItemInfo_String(ref_item, "P_EXT:src_guid", "", false)
                        if src_guid ~= "" and auto_color_pref ~= 1 then
                            local src_item = guid_lookup[src_guid]
                            if src_item then
                                local color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                                local peers = get_folder_items_at_midpoint(ref_item, folder_start, folder_end)
                                for _, peer in ipairs(peers) do
                                    if not is_item_colorized(peer) then
                                        SetMediaItemInfo_Value(peer, "I_CUSTOMCOLOR", color_val)
                                        GetSetMediaItemInfo_String(peer, "P_EXT:saved_color", color_val, true)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            current_item_index = batch_end
            local progress = 60 + (current_item_index / total_items_to_process * 20)
            update_progress("Coloring Items (Pass 2)", progress,
                string.format("Coloring edits (%d/%d)", current_item_index, total_items_to_process))
            return false
        else
            processing_step = 103
            return false
        end
    elseif processing_step == 103 then
        -- Color tracks
        update_progress("Coloring Tracks", 90, "Coloring tracks...")
        for _, track_info in ipairs(folder_tracks) do
            SetMediaTrackInfo_Value(track_info, "I_CUSTOMCOLOR", unedited_color)
            color_folder_children(track_info, unedited_color)
        end
        processing_step = 112
        return false

        -- VERTICAL WORKFLOW COLORING
    elseif processing_step == 110 then
        colors = get_color_table()
        unedited_color = colors.dest_items

        local num_tracks = CountTracks(0)
        local first_folder_done = false
        local pastel_folders = {}
        local dest_folders = {}

        for t = 0, num_tracks - 1 do
            local track = GetTrack(0, t)
            if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                if not first_folder_done then
                    table.insert(dest_folders, track)
                    first_folder_done = true
                else
                    table.insert(pastel_folders, track)
                end
            end
        end

        all_folders = {}
        for _, f in ipairs(pastel_folders) do table.insert(all_folders, { folder = f, is_dest = false }) end
        for _, f in ipairs(dest_folders) do table.insert(all_folders, { folder = f, is_dest = true }) end

        index_for_folder_pastel = 0
        current_folder_index = 0
        update_progress("Coloring Items (Pass 1)", 35, "Starting vertical coloring...")
        processing_step = 110.1
        return false
    elseif processing_step == 110.1 then
        -- Vertical pass 1: color by rank or folder color
        if current_folder_index < #all_folders then
            current_folder_index = current_folder_index + 1
            local folder_info = all_folders[current_folder_index]
            local track = folder_info.folder
            local is_dest = folder_info.is_dest

            local folder_color
            if is_dest then
                folder_color = colors.dest_items
            else
                folder_color = pastel_color(index_for_folder_pastel)
                index_for_folder_pastel = index_for_folder_pastel + 1
            end

            SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", folder_color)
            color_folder_children(track, folder_color)

            local folder_start, folder_end = get_folder_range(track)
            local num_items = CountTrackMediaItems(track)
            for i = 0, num_items - 1 do
                local ref_item = GetTrackMediaItem(track, i)
                if not is_item_colorized(ref_item) then
                    local _, ranked = GetSetMediaItemInfo_String(ref_item, "P_EXT:item_rank", "", false)
                    local color_to_use
                    if ranked ~= "" and ranking_color_pref == 0 then
                        color_to_use = get_rank_color(ranked)
                    elseif auto_color_pref == 1 then
                        color_to_use = 0
                    else
                        color_to_use = folder_color
                    end
                    if color_to_use then
                        local peers = get_folder_items_at_midpoint(ref_item, folder_start, folder_end)
                        for _, peer in ipairs(peers) do
                            SetMediaItemInfo_Value(peer, "I_CUSTOMCOLOR", color_to_use)
                        end
                    end
                end
            end

            local progress = 35 + (current_folder_index / (#all_folders * 2) * 50)
            update_progress("Coloring Items (Pass 1)", progress,
                string.format("Folder %d of %d", current_folder_index, #all_folders))
            return false
        else
            -- Build GUID lookup for pass 2
            guid_lookup = {}
            for _, item_data in ipairs(all_items_flat) do
                local _, guid = GetSetMediaItemInfo_String(item_data.item, "GUID", "", false)
                if guid ~= "" then guid_lookup[guid] = item_data.item end
            end
            current_folder_index = 0
            processing_step = 110.2
            return false
        end
    elseif processing_step == 110.2 then
        -- Vertical pass 2: recolor edits to match source color
        if current_folder_index < #all_folders then
            current_folder_index = current_folder_index + 1
            local folder_info = all_folders[current_folder_index]
            local track = folder_info.folder
            local folder_start, folder_end = get_folder_range(track)
            local num_items = CountTrackMediaItems(track)
            for i = 0, num_items - 1 do
                local ref_item = GetTrackMediaItem(track, i)
                if not is_item_colorized(ref_item) then
                    local _, ranked = GetSetMediaItemInfo_String(ref_item, "P_EXT:item_rank", "", false)
                    if (ranked == "" or ranking_color_pref == 1) then
                        local _, src_guid = GetSetMediaItemInfo_String(ref_item, "P_EXT:src_guid", "", false)
                        if src_guid ~= "" and auto_color_pref ~= 1 then
                            local src_item = guid_lookup[src_guid]
                            if src_item then
                                local color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                                local peers = get_folder_items_at_midpoint(ref_item, folder_start, folder_end)
                                for _, peer in ipairs(peers) do
                                    SetMediaItemInfo_Value(peer, "I_CUSTOMCOLOR", color_val)
                                end
                            end
                        end
                    end
                end
            end
            local progress = 60 + (current_folder_index / (#all_folders * 2) * 35)
            update_progress("Coloring Items (Pass 2)", progress,
                string.format("Folder %d of %d", current_folder_index, #all_folders))
            return false
        else
            processing_step = 112
            return false
        end
    elseif processing_step == 112 then
        update_progress("Finalizing", 98, "Restoring selections...")
        if num_pre_selected > 0 then
            Main_OnCommand(40297, 0)
            if pre_selected[1] and pcall(SetOnlyTrackSelected, pre_selected[1]) then
                for i = 2, #pre_selected do
                    if pre_selected[i] then pcall(SetTrackSelected, pre_selected[i], true) end
                end
            end
        end
        Undo_EndBlock('Prepare Takes', -1)
        PreventUIRefresh(-1)
        UpdateArrange()
        UpdateTimeline()
        update_progress("Complete", 100, "All done!")
        return true
    end
    return false
end

function main()
    if window_open and not processing_complete then
        local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoResize

        if frame_count == 0 then
            local viewport_center_x, viewport_center_y = ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))
            ImGui.SetNextWindowPos(ctx, viewport_center_x, viewport_center_y, ImGui.Cond_Appearing, 0.5, 0.5)
        end

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

        processing_complete = do_processing_step()
        defer(main)
    elseif processing_complete then
        local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoResize

        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical - Preparing Takes", true, window_flags)
        window_open = open_ref

        if opened then
            ImGui.Text(ctx, "✓ Processing Complete")
            ImGui.Spacing(ctx)
            ImGui.PushItemWidth(ctx, 400)
            ImGui.ProgressBar(ctx, 1.0, 0, 0)
            ImGui.PopItemWidth(ctx)
            ImGui.Spacing(ctx)
            ImGui.Text(ctx, "Takes prepared successfully!")
            ImGui.End(ctx)
        end

        auto_close_timer = auto_close_timer + 1
        if auto_close_timer > (auto_close_delay * 30) then
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

num_pre_selected = CountSelectedTracks(0)
if num_pre_selected > 0 then
    for i = 0, num_pre_selected - 1, 1 do
        table.insert(pre_selected, GetSelectedTrack(0, i))
    end
end

num_of_project_items = CountMediaItems(0)
if num_of_project_items == 0 then return end

PreventUIRefresh(1)
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
    if not rank_str or rank_str == "" then return nil end
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
            xfade = true; break
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
        if not take then count = count + 1 end
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
        local track               = GetTrack(0, i)
        local _, mixer_state      = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state        = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, live_state       = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, submix_state     = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state         = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state        = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state   = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local special_states      = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y"
            or listenback_state == "y" or rcmaster_state == "y"
        local special_names       = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
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
        if not take then DeleteTrackMediaItem(GetMediaItemTrack(item), item) end
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
    local q = lightness < 0.5 and (lightness * (1 + saturation)) or (lightness + saturation - lightness * saturation)
    local p = 2 * lightness - q
    local r = h2rgb(p, q, hue + 1 / 3)
    local g = h2rgb(p, q, hue)
    local b = h2rgb(p, q, hue - 1 / 3)
    return ColorToNative(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) | 0x1000000
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
        if depth > 0 then SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", folder_color) end
        depth = depth + folder_depth
        if depth <= 0 then break end
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
    local take_num = string.match(filename, "(%d+)%.[^.]+$")
    if take_num then return tonumber(take_num) end
    return nil
end
