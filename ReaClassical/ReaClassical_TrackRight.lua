--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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
local r = reaper
local takename_check, check_position, get_track_info, select_CD_track_items, last_pos_check, next_track, switch_highlight
---------------------------------------------------------------------------------------
function Main()
    r.Undo_BeginBlock()

    local take_name, selected_item = takename_check()
    if take_name == -1 or take_name == "" then
        r.ShowMessageBox('Please select an item that starts a CD track', "Select CD track start", 0)
        return
    end

    local first_track, num_of_items, item_number, count = last_pos_check(selected_item)

    if item_number + count == num_of_items - 1 then
        r.Main_OnCommand(40769,0) -- unselect all
        r.SetMediaItemSelected(selected_item, true)
        r.ShowMessageBox('The selected track is already in last position', "Select CD track start", 0)
        return
    end

    next_track(first_track, item_number, count)

    local ReaClassical_TrackLeft = r.NamedCommandLookup("_RS18fe066cb8806e30b0371fc30a79c67ce2b807f1")
    r.Main_OnCommand(ReaClassical_TrackLeft,0)

    switch_highlight(selected_item)

    r.Undo_EndBlock("Move Track Right", -1)
end

---------------------------------------------------------------------------------------
function takename_check()
    local item = r.GetSelectedMediaItem(0, 0)
    if item then
      local take = r.GetActiveTake(item) 
      local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      return take_name, item
    else
      return -1
    end
end

---------------------------------------------------------------------------------------
function check_position(item)
    local item_number = r.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    return item_number
end

---------------------------------------------------------------------------------------
function get_track_info()
    local first_track = r.GetTrack(0, 0)
    return first_track, r.GetTrackNumMediaItems(first_track)
end

---------------------------------------------------------------------------------------
function select_CD_track_items(item_number, num_of_items, track)
    local count = 0
    local added_item
    if item_number ~= num_of_items - 1 then
        for i = item_number + 1, num_of_items - 1, 1 do
            added_item = r.GetTrackMediaItem(track, i)
            local take = r.GetActiveTake(added_item)
            local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if take_name == "" then
                r.SetMediaItemSelected(added_item, true)
                count = count + 1
            else
                break
            end
        end
    end
    return count
end

---------------------------------------------------------------------------------------
function next_track(first_track, item_number, count)
    r.Main_OnCommand(40769,0) -- unselect all
    local next_track_item = r.GetTrackMediaItem(first_track, item_number + count + 1)
    r.SetMediaItemSelected(next_track_item, true)
end
---------------------------------------------------------------------------------------
function switch_highlight(item)
    r.Main_OnCommand(40769,0) -- unselect all
    r.SetMediaItemSelected(item, true)
end
---------------------------------------------------------------------------------------
function last_pos_check(item)
    local first_track, num_of_items = get_track_info()
    local item_number = check_position(item)
    local count = select_CD_track_items(item_number, num_of_items, first_track)
    return first_track, num_of_items, item_number, count
end

Main()
