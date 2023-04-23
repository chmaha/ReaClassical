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
local copy_source, create_crossfades, clean_up, lock_items
local markers, select_matching_folder, split_at_dest_in, unlock_items, ripple_lock_mode
local create_dest_in, return_xfade_length, xfade

function Main()
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()
  local replace_toggle = r.NamedCommandLookup("_RSfb9968dc637180b9e9d1627a5be31048ae2034e9")
  local dest_in, dest_out, source_count = markers()
  ripple_lock_mode()
  if r.GetToggleCommandState(replace_toggle) == 1 and dest_in == 1 and dest_out == 0 and source_count == 2 then
    lock_items()
    local sel_length = copy_source()
    split_at_dest_in()
    r.MoveEditCursor(sel_length, true)
    r.Main_OnCommand(40309, 0) -- Toggle ripple editing per-track
    r.Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    r.Main_OnCommand(40630, 0) -- Go to start of time selection
    local delete = r.NamedCommandLookup("_XENAKIOS_TSADEL")
    r.Main_OnCommand(delete, 0) -- Adaptive Delete
    r.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
    r.Main_OnCommand(40310, 0) -- Toggle ripple editing per-track
    unlock_items()
    local cur_pos = create_crossfades(dest_out)
    clean_up()
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    create_dest_in(dest_out, cur_pos)
  elseif dest_in == 1 and source_count == 2 then
    lock_items()
    copy_source()
    split_at_dest_in()
    r.Main_OnCommand(40625, 0) -- Time Selection: Set start point
    r.GoToMarker(0, 997, false)
    r.Main_OnCommand(40626, 0) -- Time Selection: Set end point
    r.Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
    r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
    r.Main_OnCommand(40630, 0) -- Go to start of time selection
    local delete = r.NamedCommandLookup("_XENAKIOS_TSADEL")
    r.Main_OnCommand(delete, 0) -- Adaptive Delete
    local paste = r.NamedCommandLookup("_SWS_AWPASTE")
    r.Main_OnCommand(paste, 0) -- SWS_AWPASTE
    unlock_items()
    local cur_pos = create_crossfades(dest_out)
    clean_up()
    r.Main_OnCommand(40289, 0) -- Item: Unselect all items
    r.Main_OnCommand(40310, 0) -- Toggle ripple editing per-track
    create_dest_in(dest_out, cur_pos)
  else
    r.ShowMessageBox("Please add at least 3 valid source-destination markers: \n 3-point edit: DEST-IN, SOURCE-IN and SOURCE-OUT \n 4-point edit: DEST-IN, DEST-OUT, SOURCE-IN and SOURCE-OUT"
      , "Source-Destination Edit", 0)
    return
  end

  r.Undo_EndBlock('VERTICAL One-Window S-D Editing', 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.UpdateTimeline()
end

function markers()
  local retval, num_markers, num_regions = r.CountProjectMarkers(0)
  local source_count = 0
  local dest_in = 0
  local dest_out = 0
  for i = 0, num_markers + num_regions - 1, 1 do
    local retval, isrgn, pos, rgnend, label, markrgnindexnumber = r.EnumProjectMarkers(i)
    if label == "DEST-IN" then
      dest_in = 1
    elseif label == "DEST-OUT" then
      dest_out = 1
    elseif label == string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT") then
      source_count = source_count + 1
    end
  end
  return dest_in, dest_out, source_count
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

function copy_source()
  local focus = r.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
  r.Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
  r.Main_OnCommand(40311, 0) -- Set ripple-all-tracks
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
  return sel_length
end

function split_at_dest_in()
  r.Main_OnCommand(40927, 0) -- Options: Enable auto-crossfade on split
  r.Main_OnCommand(40939, 0) -- Track: Select track 01
  r.GoToMarker(0, 996, false)
  local select_under = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
  r.Main_OnCommand(select_under, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
  r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
  local selected_items = r.CountSelectedMediaItems(0)
  r.Main_OnCommand(40912, 0) -- Options: Toggle auto-crossfade on split (OFF)
  if selected_items > 0 then
    r.Main_OnCommand(40186, 0) -- Item: Split items at edit or play cursor (ignoring grouping)
  end
  r.Main_OnCommand(40289, 0) -- Item: Unselect all items
end

function create_crossfades(dest_out)
  r.Main_OnCommand(41173, 0) -- Item navigation: Move cursor to start of items
  local xfade_len = return_xfade_length()
  r.MoveEditCursor(-xfade_len, false)
  r.Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
  r.MoveEditCursor(xfade_len, false)
  r.MoveEditCursor(-0.0001, false)
  xfade(xfade_len)
  r.Main_OnCommand(41174, 0) -- Item navigation: Move cursor to end of items
  local cur_pos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
  r.MoveEditCursor(0.001, false)
  local select_under = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
  r.Main_OnCommand(select_under, 0)
  r.MoveEditCursor(-0.001, false)
  r.MoveEditCursor(-xfade_len, false)
  r.Main_OnCommand(41305, 0) -- Item edit: Trim left edge of item to edit cursor
  r.MoveEditCursor(xfade_len, false)
  r.MoveEditCursor(-0.0001, false)
  xfade(xfade_len)
  r.Main_OnCommand(40912, 0) -- Options: Toggle auto-crossfade on split (OFF) 
  r.Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
  return cur_pos
end

function clean_up()
  r.DeleteProjectMarker(NULL, 996, false)
  r.DeleteProjectMarker(NULL, 997, false)
  r.DeleteProjectMarker(NULL, 998, false)
  r.DeleteProjectMarker(NULL, 999, false)
  r.Main_OnCommand(42395, 0) -- Clear tempo envelope
end

function lock_items()
  r.Main_OnCommand(40182, 0) -- select all items
  r.Main_OnCommand(40939, 0) -- select track 01
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- select children of track 1
  local unselect_items = r.NamedCommandLookup("_SWS_UNSELONTRACKS")
  r.Main_OnCommand(unselect_items, 0) -- unselect items in first folder
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

function create_dest_in(dest_out, cur_pos)
  r.SetEditCurPos(cur_pos, false, false)
  if dest_out == 0 then
    r.AddProjectMarker2(0, false, cur_pos, 0, "DEST-IN", 996, r.ColorToNative(22, 141, 195) | 0x1000000)
  end
end

function return_xfade_length()
  local xfade_len = 0.035
  local bool = r.HasExtState("ReaClassical", "Preferences")
  if bool then 
    input = r.GetExtState("ReaClassical", "Preferences")
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    xfade_len = table[1]/1000
  end
  return xfade_len
end

function xfade(xfade_len)
  local select_items = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
  r.Main_OnCommand(select_items, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
  --r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  r.MoveEditCursor(-xfade_len, false)
  r.Main_OnCommand(40625, 0) -- Time selection: Set start point
  r.MoveEditCursor(xfade_len, false)
  r.Main_OnCommand(40626, 0) -- Time selection: Set end point
  r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection
  r.Main_OnCommand(40635, 0) -- Time selection: Remove time selection
  r.MoveEditCursor(0.001, false)
  r.Main_OnCommand(select_items, 0)
  r.MoveEditCursor(-0.001, false)
end

Main()
