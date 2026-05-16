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
local main, select_previous_and_next, heal
local count_selected_media_items, get_selected_media_item_at
local deselect_items_not_on_track, get_folder_items_at_midpoint
local get_folder_range

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

    local selected, prev_startoffs, next_end, next_fadeout_len, next_fadeout_shape,
          total_selected_length = select_previous_and_next()

    if selected then
        heal(prev_startoffs, next_end, next_fadeout_len, next_fadeout_shape,
             total_selected_length)
    end

    Undo_EndBlock('Heal Edit', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function get_folder_range(parent_track)
    local parent_index = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local folder_start, folder_end = nil, nil
    for t = parent_index, num_tracks - 1 do
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
    return folder_start, folder_end
end

---------------------------------------------------------------------

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

function select_previous_and_next()
    -- Get selected items
    local sel_count = count_selected_media_items()
    if sel_count == 0 then
        MB("No items selected.", "Error", 0)
        return false
    end

    -- Check all selected items have P_EXT:SD == "y"
    for i = 0, sel_count - 1 do
        local item = get_selected_media_item_at(i)
        local _, sd_flag = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
        if sd_flag ~= "y" then
            MB("All selected items must be S-D edits", "Error", 0)
            return false
        end
    end

    -- Get the track of the first selected item
    local first_item = get_selected_media_item_at(0)
    local track = GetMediaItem_Track(first_item)

    deselect_items_not_on_track(track)

    -- Check if the track is a parent (has child tracks)
    local parent_is_parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
    if not parent_is_parent then
        MB("The selected item(s) must be on a parent track.", "Error", 0)
        return false
    end

    -- Collect all items on this track
    local item_count = CountTrackMediaItems(track)
    local selected_indexes = {}

    for i = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, i)
        if IsMediaItemSelected(item) then
            table.insert(selected_indexes, i)
        end
    end

    -- Check that selected items are adjacent (no skipped indexes)
    if #selected_indexes > 1 then
        for i = 1, #selected_indexes - 1 do
            if selected_indexes[i + 1] ~= selected_indexes[i] + 1 then
                MB("Selected items are not adjacent on the track.", "Error", 0)
                return false
            end
        end
    end

    -- Determine previous and next items (if any)
    local first_index = selected_indexes[1]
    local last_index = selected_indexes[#selected_indexes]

    local prev_item = nil
    local next_item = nil

    if first_index > 0 then
        prev_item = GetTrackMediaItem(track, first_index - 1)
    end
    if last_index < item_count - 1 then
        next_item = GetTrackMediaItem(track, last_index + 1)
    end

    -- Final check: both prev and next must exist
    if not prev_item or not next_item then
        MB("No previous or next item found on this track.", "Info", 0)
        return false
    end

    -- === Additional checks ===
    -- 1) Check if both have the same source media file
    local prev_take = GetActiveTake(prev_item)
    local next_take = GetActiveTake(next_item)
    if not prev_take or not next_take then
        MB("Missing active take in one of the items.", "Error", 0)
        return false
    end

    local prev_src = GetMediaItemTake_Source(prev_take)
    local next_src = GetMediaItemTake_Source(next_take)

    local prev_path = GetMediaSourceFileName(prev_src, "")
    local next_path = GetMediaSourceFileName(next_src, "")

    if prev_path ~= next_path then
        MB("Previous and next items use different source media files.", "Error", 0)
        return false
    end

    -- 2) Check D_STARTOFFS timing relationship
    local prev_startoffs = GetMediaItemTakeInfo_Value(prev_take, "D_STARTOFFS")
    local next_startoffs = GetMediaItemTakeInfo_Value(next_take, "D_STARTOFFS")
    local prev_length = GetMediaItemInfo_Value(prev_item, "D_LENGTH")
    local next_length = GetMediaItemInfo_Value(next_item, "D_LENGTH")

    local next_fadein = GetMediaItemInfo_Value(next_item, "D_FADEINLEN")
    local next_fadein_auto = GetMediaItemInfo_Value(next_item, "D_FADEINLEN_AUTO")

    if next_fadein_auto > 0 then
        next_fadein = next_fadein_auto
    end

    if next_startoffs <= (prev_startoffs + prev_length - (next_fadein + 0.0001)) then
        MB("Next item starts before previous item in source media.", "Error", 0)
        return false
    end

    -- Passed all checks — keep originals and add prev/next to selection
    if prev_item then SetMediaItemSelected(prev_item, true) end
    if next_item then SetMediaItemSelected(next_item, true) end

    -- === Gather fade info ===
    local next_fadeout_len = GetMediaItemInfo_Value(next_item, "D_FADEOUTLEN")
    local next_fadeout_len_auto = GetMediaItemInfo_Value(next_item, "D_FADEOUTLEN_AUTO")

    if next_fadeout_len_auto > 0 then
        next_fadeout_len = next_fadeout_len_auto
    end

    local fadeout_shape = GetMediaItemInfo_Value(next_item, "C_FADEOUTSHAPE")

    -- next_end is the source-file position where next_item ends
    local next_end = next_startoffs + next_length

    -- total_selected_length: timeline span of everything selected
    -- (prev + edit items + next), measured on the parent track
    sel_count = count_selected_media_items()
    local first_sel_item = get_selected_media_item_at(0)
    local last_sel_item  = get_selected_media_item_at(sel_count - 1)

    local first_pos  = GetMediaItemInfo_Value(first_sel_item, "D_POSITION")
    local last_pos   = GetMediaItemInfo_Value(last_sel_item,  "D_POSITION")
    local last_len   = GetMediaItemInfo_Value(last_sel_item,  "D_LENGTH")

    local total_selected_length = (last_pos + last_len) - first_pos

    return true, prev_startoffs, next_end, next_fadeout_len, fadeout_shape,
           total_selected_length
end

---------------------------------------------------------------------

function heal(prev_startoffs, next_end, next_fadeout_len, next_fadeout_shape,
             total_selected_length)
    local sel_count = count_selected_media_items()
    if sel_count == 0 then
        MB("No items selected.", "Error", 0)
        return false
    end

    -- prev_item is the first selected item (added by select_previous_and_next)
    local prev_item  = get_selected_media_item_at(0)
    local prev_track = GetMediaItem_Track(prev_item)
    local prev_pos   = GetMediaItemInfo_Value(prev_item, "D_POSITION")

    local folder_start, folder_end = get_folder_range(prev_track)

    -- Peers of prev_item across the folder (these survive and get extended)
    local prev_peers = folder_start
        and get_folder_items_at_midpoint(prev_item, folder_start, folder_end)
        or  { prev_item }

    local is_prev_peer = {}
    for _, item in ipairs(prev_peers) do is_prev_peer[item] = true end

    -- ---------------------------------------------------------------
    -- Step 1: delete every selected item that is NOT a prev peer.
    -- This removes the edit items and the next item, on all tracks,
    -- by using midpoint matching for each non-prev selected item.
    -- ---------------------------------------------------------------
    -- Collect the non-prev selected parent-track items first
    local to_process = {}
    for i = 0, sel_count - 1 do
        local item = get_selected_media_item_at(i)
        if not is_prev_peer[item] then
            to_process[#to_process + 1] = item
        end
    end
    -- For each, delete it and all its folder peers via midpoint matching
    local deleted = {}
    for _, item in ipairs(to_process) do
        if not deleted[item] then
            local peers = folder_start
                and get_folder_items_at_midpoint(item, folder_start, folder_end)
                or  { item }
            for _, peer in ipairs(peers) do
                if not is_prev_peer[peer] and not deleted[peer] then
                    deleted[peer] = true
                    DeleteTrackMediaItem(GetMediaItem_Track(peer), peer)
                end
            end
        end
    end

    -- ---------------------------------------------------------------
    -- Step 2: extend each prev peer in source time to reach next_end,
    -- and copy the fadeout shape.
    -- ---------------------------------------------------------------
    local new_prev_length = next_end - prev_startoffs
    if new_prev_length <= 0 then return end

    for _, item in ipairs(prev_peers) do
        local take = GetActiveTake(item)
        if take then
            SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", prev_startoffs)
            SetMediaItemInfo_Value(item, "D_LENGTH", new_prev_length)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", next_fadeout_len)
            SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE",    next_fadeout_shape)
            SetMediaItemSelected(item, true)
        end
    end

    -- ---------------------------------------------------------------
    -- Step 3: ripple items after prev_item on all folder tracks.
    -- length_diff = how much longer/shorter the new prev is compared
    -- to the entire selected span (prev + edits + next).
    -- ---------------------------------------------------------------
    local length_diff = new_prev_length - total_selected_length

    if length_diff ~= 0 then
        local ripple_tracks = {}
        if folder_start then
            for t = folder_start, folder_end do
                ripple_tracks[#ripple_tracks + 1] = GetTrack(0, t)
            end
        else
            ripple_tracks[1] = prev_track
        end

        -- Find earliest item position strictly after prev_item's start
        -- on any folder track (these are the items to ripple)
        local next_group_start_pos = nil
        for _, track in ipairs(ripple_tracks) do
            local n = CountTrackMediaItems(track)
            for j = 0, n - 1 do
                local item = GetTrackMediaItem(track, j)
                local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
                if ipos > prev_pos then
                    if not next_group_start_pos or ipos < next_group_start_pos then
                        next_group_start_pos = ipos
                    end
                    break
                end
            end
        end

        if next_group_start_pos then
            for _, track in ipairs(ripple_tracks) do
                local n = CountTrackMediaItems(track)
                for j = 0, n - 1 do
                    local item = GetTrackMediaItem(track, j)
                    local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
                    if ipos >= next_group_start_pos then
                        SetMediaItemInfo_Value(item, "D_POSITION", ipos + length_diff)
                    end
                end
            end
        end
    end

    Main_OnCommand(40289, 0) -- Item: Unselect all items
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
            if selected_count == index then return item end
            selected_count = selected_count + 1
        end
    end
    return nil
end

---------------------------------------------------------------------

function deselect_items_not_on_track(track)
    local num_items = CountMediaItems(0)
    for i = 0, num_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if GetMediaItem_Track(item) ~= track then
                SetMediaItemSelected(item, false)
            end
        end
    end
end

---------------------------------------------------------------------

main()