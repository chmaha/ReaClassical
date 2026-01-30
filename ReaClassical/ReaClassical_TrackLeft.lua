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

local main, takename_check, check_position, get_track_info, paste
local select_and_cut, go_to_previous, shift, select_CD_track_items
local calc_postgap, is_item_start_crossfaded
local get_selected_media_item_at, count_selected_media_items
local select_items_containing_midpoint, get_folder_children
local is_folder_track, shift_track_automation
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
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end
    local take_name, selected_item = takename_check()
    if take_name == -1 or take_name == "" then
        MB('Please select an item that starts a CD track', "Select CD track start", 0)
        return
    end

    -- Verify the selected item is on a folder parent track
    local selected_track = GetMediaItemTrack(selected_item)
    if not is_folder_track(selected_track) then
        MB('Please select an item on a parent folder track', "Select CD track start", 0)
        return
    end

    local ret, item_number = check_position(selected_item)
    if ret then
        MB('The selected track is already in first position', "Select CD track start", 0)
        return
    end

    PreventUIRefresh(1)
    local folder_track, num_of_items = get_track_info(selected_item)

    local item_start_crossfaded = is_item_start_crossfaded(folder_track, item_number)
    if item_start_crossfaded then
        Main_OnCommand(40769, 0) -- unselect all
        SetMediaItemSelected(selected_item, true)
        MB('The selected track start is crossfaded and ' ..
            'therefore cannot be moved', "Select CD track start", 0)
        return
    end

    local count = select_CD_track_items(item_number, num_of_items, folder_track)



    local new_track_item, postgap = calc_postgap(count, num_of_items, folder_track, selected_item)

    select_and_cut()

    -- shift all future tracks back length of selected track postgap
    if item_number + count ~= num_of_items - 1 then
        shift(folder_track, new_track_item, postgap, 0, "left")
    end

    go_to_previous(item_number, folder_track)
    paste()

    selected_item = get_selected_media_item_at(0)

    -- shift forward all future tracks the length of track postgap
    shift(folder_track, selected_item, postgap, count, "right")

    Main_OnCommand(40769, 0) -- unselect all
    SetOnlyTrackSelected(folder_track)
    SetMediaItemSelected(selected_item, true)
    PreventUIRefresh(-1)
    Undo_EndBlock("Move Track Left", -1)
end

---------------------------------------------------------------------

function is_folder_track(track)
    if not track then return false end
    local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    return folder_depth == 1
end

---------------------------------------------------------------------

function takename_check()
    local item = get_selected_media_item_at(0)
    if item then
        local take = GetActiveTake(item)
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        return take_name, item
    else
        return -1
    end
end

---------------------------------------------------------------------

function check_position(item)
    local item_number = GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    return item_number == 0, item_number
end

---------------------------------------------------------------------

function get_track_info(item)
    local folder_track = GetMediaItemTrack(item)
    return folder_track, GetTrackNumMediaItems(folder_track)
end

---------------------------------------------------------------------

function paste()
    Main_OnCommand(42398, 0)
end

---------------------------------------------------------------------

function select_and_cut()
    select_items_containing_midpoint()
    Main_OnCommand(40699, 0) -- paste items
end

---------------------------------------------------------------------

function go_to_previous(item_number, track)
    for i = item_number - 1, 0, -1 do
        local first_prev_item = GetTrackMediaItem(track, i)
        local take = GetActiveTake(first_prev_item)
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        local first_prev_pos = GetMediaItemInfo_Value(first_prev_item, "D_POSITION")
        local second_prev_item = GetTrackMediaItem(track, i - 1)
        if second_prev_item then
            local second_prev_pos = GetMediaItemInfo_Value(second_prev_item, "D_POSITION")
            local second_prev_len = GetMediaItemInfo_Value(second_prev_item, "D_LENGTH")
            local second_prev_end = second_prev_pos + second_prev_len
            if take_name ~= "" and first_prev_pos > second_prev_end then
                local prev_item_pos = GetMediaItemInfo_Value(first_prev_item, "D_POSITION")
                SetEditCurPos(prev_item_pos, false, false)
                break
            end
        else
            if take_name ~= "" then
                local prev_item_pos = GetMediaItemInfo_Value(first_prev_item, "D_POSITION")
                SetEditCurPos(prev_item_pos, false, false)
                break
            end
        end
    end
end

---------------------------------------------------------------------

function shift_track_automation(track, start_time, end_time, shift_amount)
    -- Shift all automation (points and automation items) within the time range
    local num_envs = CountTrackEnvelopes(track)
    
    for e = 0, num_envs - 1 do
        local env = GetTrackEnvelope(track, e)
        
        -- Shift regular envelope points within the time range
        local num_points = CountEnvelopePoints(env)
        local points_to_shift = {}
        
        for p = 0, num_points - 1 do
            local retval, time, value, shape, tension, selected = GetEnvelopePoint(env, p)
            if time >= start_time and time <= end_time then
                table.insert(points_to_shift, {
                    index = p,
                    time = time,
                    new_time = time + shift_amount,
                    value = value,
                    shape = shape,
                    tension = tension,
                    selected = selected
                })
            end
        end
        
        -- Delete and recreate shifted points
        for i = #points_to_shift, 1, -1 do
            local pt = points_to_shift[i]
            DeleteEnvelopePointRange(env, pt.time - 0.0001, pt.time + 0.0001)
        end
        
        for _, pt in ipairs(points_to_shift) do
            InsertEnvelopePoint(env, pt.new_time, pt.value, pt.shape, pt.tension, pt.selected, true)
        end
        
        Envelope_SortPoints(env)
        
        -- Shift automation items within the time range
        local num_ai = CountAutomationItems(env)
        for ai = 0, num_ai - 1 do
            local ai_pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
            local ai_len = GetSetAutomationItemInfo(env, ai, "D_LENGTH", 0, false)
            local ai_end = ai_pos + ai_len
            
            -- If automation item overlaps with the time range, shift it
            if ai_pos < end_time and ai_end > start_time then
                GetSetAutomationItemInfo(env, ai, "D_POSITION", ai_pos + shift_amount, true)
            end
        end
    end
end

---------------------------------------------------------------------

function shift(track, item, shift_amount, items_in_track, direction)
    local num_of_items = GetTrackNumMediaItems(track)
    local item_number = GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    local items_to_move = {}
    if direction == "right" then
        item_number = item_number + items_in_track + 1
        shift_amount = -shift_amount
    end
    Main_OnCommand(40289, 0) -- unselect all items
    for i = item_number, num_of_items - 1, 1 do
        local track_item = GetTrackMediaItem(track, i)
        SetMediaItemSelected(track_item, true)
        select_items_containing_midpoint()
    end
    local selected_item_count = count_selected_media_items()
    for i = 0, selected_item_count - 1 do
        items_to_move[#items_to_move + 1] = get_selected_media_item_at(i)
    end
    
    -- Calculate time range for automation shifting
    local min_pos = nil
    local max_end = 0
    for _, v in pairs(items_to_move) do
        local item_pos = GetMediaItemInfo_Value(v, "D_POSITION")
        local item_len = GetMediaItemInfo_Value(v, "D_LENGTH")
        if min_pos == nil or item_pos < min_pos then
            min_pos = item_pos
        end
        max_end = math.max(max_end, item_pos + item_len)
    end
    
    -- Collect all unique tracks
    local tracks_hash = {}
    for _, v in pairs(items_to_move) do
        local item_track = GetMediaItemTrack(v)
        tracks_hash[item_track] = true
    end
    
    -- Shift automation for all affected tracks
    if min_pos then
        for item_track, _ in pairs(tracks_hash) do
            shift_track_automation(item_track, min_pos, max_end, -shift_amount)
        end
    end
    
    Main_OnCommand(40289, 0) -- unselect all items
    for _, v in pairs(items_to_move) do
        local item_pos = GetMediaItemInfo_Value(v, "D_POSITION")
        SetMediaItemInfo_Value(v, "D_POSITION", item_pos - shift_amount)
    end
end

---------------------------------------------------------------------

function select_CD_track_items(item_number, num_of_items, track)
    local count = 0
    if item_number ~= num_of_items - 1 then
        for i = item_number + 1, num_of_items - 1, 1 do
            local item = GetTrackMediaItem(track, i)
            local prev_item = GetTrackMediaItem(track, i - 1)
            local take = GetActiveTake(item)
            local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local prev_pos = GetMediaItemInfo_Value(prev_item, "D_POSITION")
            local prev_len = GetMediaItemInfo_Value(prev_item, "D_LENGTH")
            local prev_end = prev_pos + prev_len
            local next_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if take_name == "" or next_pos < prev_end then
                SetMediaItemSelected(item, true)
                count = count + 1
            else
                break
            end
        end
    end
    return count
end

---------------------------------------------------------------------

function calc_postgap(count, num_of_items, track, selected_item)
    local last_item_of_track = get_selected_media_item_at(0 + count)
    local last_item_of_track_pos = GetMediaItemInfo_Value(last_item_of_track, "D_POSITION")
    local last_item_of_track_length = GetMediaItemInfo_Value(last_item_of_track, "D_LENGTH")
    local last_item_of_track_end = last_item_of_track_pos + last_item_of_track_length

    local _, last_item_number = check_position(last_item_of_track)
    local postgap
    local new_track_item
    if last_item_number ~= num_of_items - 1 then
        new_track_item = GetTrackMediaItem(track, last_item_number + 1)
        local new_track_pos = GetMediaItemInfo_Value(new_track_item, "D_POSITION")
        postgap = new_track_pos - last_item_of_track_end
    else
        new_track_item = selected_item
        postgap = 4
    end
    return new_track_item, postgap
end

---------------------------------------------------------------------

function is_item_start_crossfaded(first_track, item_number)
    local item = GetTrackMediaItem(first_track, item_number)
    local next_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local prev_item = GetTrackMediaItem(first_track, item_number - 1)
    if prev_item then
        local prev_pos = GetMediaItemInfo_Value(prev_item, "D_POSITION")
        local prev_len = GetMediaItemInfo_Value(prev_item, "D_LENGTH")
        local prev_end = prev_pos + prev_len
        if prev_end > next_pos then
            return true
        end
    end
    return false
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

    -- Get the folder track for the first selected item
    local first_item = GetSelectedMediaItem(0, 0)
    local first_track = GetMediaItemTrack(first_item)
    local folder_track = first_track

    -- If it's not a folder track, this shouldn't happen due to validation
    if not is_folder_track(folder_track) then
        return
    end

    -- Get all tracks within this specific folder only
    local tracks_to_check = {}
    tracks_to_check[folder_track] = true -- Include folder track itself
    local children = get_folder_children(folder_track)
    for _, child in ipairs(children) do
        tracks_to_check[child] = true
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