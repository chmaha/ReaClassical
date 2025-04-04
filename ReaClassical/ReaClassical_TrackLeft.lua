--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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
---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local take_name, selected_item = takename_check()
    if take_name == -1 or take_name == "" then
        MB('Please select an item that starts a CD track', "Select CD track start", 0)
        return
    end

    local ret, item_number = check_position(selected_item)
    if ret then
        MB('The selected track is already in first position', "Select CD track start", 0)
        return
    end

    PreventUIRefresh(1)
    local first_track, num_of_items = get_track_info()

    local item_start_crossfaded = is_item_start_crossfaded(first_track, item_number)
    if item_start_crossfaded then
        Main_OnCommand(40769, 0) -- unselect all
        SetMediaItemSelected(selected_item, true)
        MB('The selected track start is crossfaded and ' ..
            'therefore cannot be moved', "Select CD track start", 0)
        return
    end

    local count = select_CD_track_items(item_number, num_of_items, first_track)



    local new_track_item, postgap = calc_postgap(count, num_of_items, first_track, selected_item)

    select_and_cut()

    -- shift all future tracks back length of selected track postgap
    if item_number + count ~= num_of_items - 1 then
        shift(first_track, new_track_item, postgap, 0, "left")
    end

    go_to_previous(item_number, first_track)
    paste()

    selected_item = get_selected_media_item_at(0)

    -- shift forward all future tracks the length of track postgap
    shift(first_track, selected_item, postgap, count, "right")

    Main_OnCommand(40769, 0) -- unselect all
    SetMediaItemSelected(selected_item, true)
    PreventUIRefresh(-1)
    Undo_EndBlock("Move Track Left", -1)
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

function get_track_info()
    local first_track = GetTrack(0, 0)
    return first_track, GetTrackNumMediaItems(first_track)
end

---------------------------------------------------------------------

function paste()
    Main_OnCommand(42398, 0)
end

---------------------------------------------------------------------

function select_and_cut()
    Main_OnCommand(40034, 0) -- select all items in groups
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
        Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    end
    local selected_item_count = count_selected_media_items()
    for i = 0, selected_item_count - 1 do
        items_to_move[#items_to_move + 1] = get_selected_media_item_at(i)
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

main()
