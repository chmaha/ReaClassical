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
local SDmarkers, select_matching_folder

function Main()
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()

  if SDmarkers() == 4 then
    r.Main_OnCommand(40927, 0) -- Options: Enable auto-crossfade on split
    local focus = r.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    r.Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
    r.Main_OnCommand(40310, 0) -- Set ripple per-track
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.GoToMarker(0, 998, false)
    select_matching_folder()
    r.Main_OnCommand(40625, 0) -- Time Selection: Set start point
    r.GoToMarker(0, 999, false)
    r.Main_OnCommand(40626, 0) -- Time Selection: Set end point
    local start_time, end_time = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local sel_length = end_time - start_time
    r.Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    r.Main_OnCommand(41383, 0) -- Edit: Copy items/tracks/envelope points (depending on focus) within time selection, if any (smart copy)
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.Main_OnCommand(40939, 0) -- Track: Select track 01
    r.GoToMarker(0, 996, false)
    local select_under = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    r.Main_OnCommand(select_under, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    r.Main_OnCommand(40912, 0) -- Options: Toggle auto-crossfade on split (OFF)
    r.Main_OnCommand(40186, 0) -- Item: Split items at edit or play cursor (ignoring grouping)
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items

    r.Main_OnCommand(40625, 0) -- Time Selection: Set start point
    r.GoToMarker(0, 997, false)
    r.Main_OnCommand(40626, 0) -- Time Selection: Set end point
    r.Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    r.Main_OnCommand(40309, 0) -- ripple off
    r.Main_OnCommand(40630, 0) -- Go to start of time selection
    local delete = r.NamedCommandLookup("_XENAKIOS_TSADEL")
    r.Main_OnCommand(delete, 0) -- Adaptive delete
    local paste = r.NamedCommandLookup("_SWS_AWPASTE")
    r.Main_OnCommand(paste, 0) -- SWS_AWPASTE
    r.Main_OnCommand(41206, 0) -- Item: Move and stretch items to fit time selection

    r.Main_OnCommand(41173, 0) -- Item navigation: Move cursor to start of items
    local fade_left = r.NamedCommandLookup("_SWS_MOVECURFADELEFT")
    r.Main_OnCommand(fade_left, 0) -- SWS_MOVECURFADELEFT
    r.Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
    r.Main_OnCommand(40417, 0) -- Item Navigation: Select and move to next item
    r.Main_OnCommand(fade_left, 0) -- SWS_MOVECURFADELEFT
    r.Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
    r.Main_OnCommand(40912, 0) -- Options: Toggle auto-crossfade on split (OFF) 
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
    r.DeleteProjectMarker(NULL, 996, false)
    r.DeleteProjectMarker(NULL, 997, false)
    r.DeleteProjectMarker(NULL, 998, false)
    r.DeleteProjectMarker(NULL, 999, false)
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.Main_OnCommand(40310, 0) -- Ripple per-track
  else
    r.ShowMessageBox("Please add 4 markers: DEST-IN, DEST-OUT, SOURCE-IN and SOURCE-OUT", "Insert with timestretching", 0)
  end
  r.Undo_EndBlock('Insert with Timestretching', 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.UpdateTimeline()
end

function SDmarkers()
  local retval, num_markers, num_regions = r.CountProjectMarkers(0)
  local exists = 0
  for i = 0, num_markers + num_regions - 1, 1 do
    local retval, isrgn, pos, rgnend, label, markrgnindexnumber = r.EnumProjectMarkers(i)
    if label == "DEST-IN" or label == "DEST-OUT" or string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT")
    then
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
