--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, takename_check, check_position, get_track_info
local select_CD_track_items, next_track, switch_highlight
local is_item_start_crossfaded, pos_check

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()

    local take_name, selected_item = takename_check()
    if take_name == -1 or take_name == "" then
        ShowMessageBox('Please select an item that starts a CD track', "Select CD track start", 0)
        return
    end

    local item_start_crossfaded, first_track, num_of_items, item_number, count = pos_check(selected_item)

    if item_start_crossfaded then
        Main_OnCommand(40769, 0) -- unselect all
        SetMediaItemSelected(selected_item, true)
        ShowMessageBox('The selected track start is crossfaded' ..
            'and therefore cannot be moved', "Select CD track start", 0)
        return
    end

    if item_number + count == num_of_items - 1 then
        Main_OnCommand(40769, 0) -- unselect all
        SetMediaItemSelected(selected_item, true)
        ShowMessageBox('The selected track is already in last position', "Select CD track start", 0)
        return
    end



    next_track(first_track, item_number, count)

    local ReaClassical_TrackLeft = NamedCommandLookup("_RS18fe066cb8806e30b0371fc30a79c67ce2b807f1")
    Main_OnCommand(ReaClassical_TrackLeft, 0)

    switch_highlight(selected_item)

    Undo_EndBlock("Move Track Right", -1)
end

---------------------------------------------------------------------

function takename_check()
    local item = GetSelectedMediaItem(0, 0)
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
    return item_number
end

---------------------------------------------------------------------

function get_track_info()
    local first_track = GetTrack(0, 0)
    return first_track, GetTrackNumMediaItems(first_track)
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

function next_track(first_track, item_number, count)
    Main_OnCommand(40769, 0) -- unselect all
    local next_track_item = GetTrackMediaItem(first_track, item_number + count + 1)
    SetMediaItemSelected(next_track_item, true)
end

---------------------------------------------------------------------

function switch_highlight(item)
    Main_OnCommand(40769, 0) -- unselect all
    SetMediaItemSelected(item, true)
end

---------------------------------------------------------------------

function pos_check(selected_item)
    local first_track, num_of_items = get_track_info()
    local item_number = check_position(selected_item)
    local item_start_crossfaded = is_item_start_crossfaded(first_track, item_number)
    local count = select_CD_track_items(item_number, num_of_items, first_track)
    Main_OnCommand(40769, 0) -- unselect all
    SetMediaItemSelected(selected_item, true)
    return item_start_crossfaded, first_track, num_of_items, item_number, count
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

main()
