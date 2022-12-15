--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022 chmaha

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
local select_matching_folder, lock_items, unlock_items, source_markers, ripple_lock_mode

function Main()
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()
  r.Main_OnCommand(40927, 0) -- Options: Enable auto-crossfade on split
  if source_markers() == 2 then
    ripple_lock_mode()
    local focus = r.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    r.Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
    r.GoToMarker(0, 998, false)
    lock_items()
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.Main_OnCommand(40625, 0) -- Time Selection: Set start point
    r.GoToMarker(0, 999, false)
    r.Main_OnCommand(40626, 0) -- Time Selection: Set end point
    r.Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    local folder = r.GetSelectedTrack(0, 0)
    if r.GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER") == 1 then
      r.Main_OnCommand(40311, 0) -- Set ripple-all-tracks
    else
      r.Main_OnCommand(40310, 0) -- Set ripple-per-track
    end
    local delete = r.NamedCommandLookup("_XENAKIOS_TSADEL")
    r.Main_OnCommand(delete, 0) -- XENAKIOS_TSADEL
    r.Main_OnCommand(40630, 0) -- Go to start of time selection
    unlock_items()
    local fade_right = r.NamedCommandLookup("_SWS_MOVECURFADERIGHT")
    r.Main_OnCommand(fade_right, 0)
    local select_under = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    r.Main_OnCommand(select_under, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks

    local fade_left = r.NamedCommandLookup("_SWS_MOVECURFADELEFT")
    r.Main_OnCommand(fade_left, 0) -- SWS_MOVECURFADELEFT
    r.Main_OnCommand(fade_left, 0) -- SWS_MOVECURFADELEFT
    r.Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
    r.DeleteProjectMarker(NULL, 998, false)
    r.DeleteProjectMarker(NULL, 999, false)
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.Main_OnCommand(40310, 0) -- Ripple per-track
  else
    r.ShowMessageBox("Please use SOURCE-IN and SOURCE-OUT markers", "Delete With Ripple", 0)
  end
  r.Undo_EndBlock('Cut and Ripple', 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.UpdateTimeline()

end

function source_markers()
  local retval, num_markers, num_regions = r.CountProjectMarkers(0)
  local exists = 0
  for i = 0, num_markers + num_regions - 1, 1 do
    local retval, isrgn, pos, rgnend, label, markrgnindexnumber = r.EnumProjectMarkers(i)
    if string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT") then
      exists = exists + 1
    end
  end
  return exists
end

function select_matching_folder()
  local cursor = r.GetCursorPosition()
  local marker_id, _ = r.GetLastMarkerAndCurRegion(0, cursor)
  local _, _, _, _, label, _, _ = r.EnumProjectMarkers3(0, marker_id)
  local folder_number = tonumber(string.match(label, "(%d*):SOURCE*"))
  for i = 0, r.CountTracks(0) - 1, 1 do
    local track = r.GetTrack(0, i)
    if r.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") == folder_number then
      r.SetOnlyTrackSelected(track)
      break
    end
  end
end

function lock_items()
  select_matching_folder()
  r.Main_OnCommand(40182, 0) -- select all items
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- select children of folder
  local unselect_items = r.NamedCommandLookup("_SWS_UNSELONTRACKS")
  r.Main_OnCommand(unselect_items, 0) -- unselect items in folder
  local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
  r.Main_OnCommand(unselect_children, 0) -- unselect children of folder
  local total_items = r.CountSelectedMediaItems(0)
  for i = 0, total_items - 1, 1 do
    local item = r.GetSelectedMediaItem(0, i)
    r.SetMediaItemInfo_Value(item, "C_LOCK", 1)
  end
end

function unlock_items()
  local total_items = r.CountMediaItems(0)
  for i = 0, total_items - 1, 1 do
    local item = r.GetMediaItem(0, i)
    r.SetMediaItemInfo_Value(item, "C_LOCK", 0)
  end
end

function ripple_lock_mode()
  local _, original_ripple_lock_mode = reaper.get_config_var_string("ripplelockmode")
  original_ripple_lock_mode = tonumber(original_ripple_lock_mode)
  if original_ripple_lock_mode ~= 2 then
    reaper.SNM_SetIntConfigVar("ripplelockmode", 2)
  end
end

Main()
