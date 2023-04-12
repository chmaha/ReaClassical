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
local select_matching_folder, source_markers

function Main()
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()

  if source_markers() == 2 then
    local focus = r.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    r.Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
    r.Main_OnCommand(40310, 0) -- Set ripple per-track
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.GoToMarker(0, 998, false)
    select_matching_folder()
    r.Main_OnCommand(40625, 0) -- Time Selection: Set start point
    r.GoToMarker(0, 999, false)
    r.Main_OnCommand(40626, 0) -- Time Selection: Set end point
    r.Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    r.Main_OnCommand(41990, 0) -- Toggle ripple per-track (off)
    local delete = r.NamedCommandLookup("_XENAKIOS_TSADEL")
    r.Main_OnCommand(delete, 0) -- XENAKIOS_TSADEL
    r.Main_OnCommand(40630, 0) -- Go to start of time selection
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
    r.DeleteProjectMarker(NULL, 998, false)
    r.DeleteProjectMarker(NULL, 999, false)
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.Main_OnCommand(41990, 0) -- Toggle ripple per-track (off)
  else
    r.ShowMessageBox("Please use SOURCE-IN and SOURCE-OUT markers", "Delete Leaving Silence", 0)
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

Main()
