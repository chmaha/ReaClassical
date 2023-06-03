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
local mixer, solo, track_check, bus_check, load_prefs, save_prefs

function Main()
  if track_check() == 0 then
    r.ShowMessageBox("Please add at least one track or folder before running", "Classical Take Record", 0)
    return
  end
  local take_record_toggle = r.NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")
  r.Undo_BeginBlock()
  if r.GetPlayState() == 0 then
    r.SetToggleCommandState(1, take_record_toggle, 1)
    r.RefreshToolbar2(1, take_record_toggle)
    local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
    r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    mixer()
    local selected = solo()
    if not selected then
      r.ShowMessageBox("Please select a folder or track before running", "Classical Take Record", 0)
      r.SetToggleCommandState(1, take_record_toggle, 0)
      return
    end
    r.Main_OnCommand(40491, 0) -- Track: Unarm all tracks for recording
    local arm = r.NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
    r.Main_OnCommand(arm, 0) -- Xenakios/SWS: Set selected tracks record armed
    local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
    r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
    local cursor_pos = r.GetCursorPosition()
    save_prefs(cursor_pos)
    r.Main_OnCommand(1013, 0) -- Transport: Record
    r.Undo_EndBlock('Classical Take Record', 0)
  else
    r.SetToggleCommandState(1, take_record_toggle, 0)
    r.RefreshToolbar2(1, take_record_toggle)
    r.Main_OnCommand(40667, 0) -- Transport: Stop (save all recorded media)
    local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
    r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    r.Main_OnCommand(40289,0) -- Unselect all items
    local ret, cursor_pos = load_prefs()
    if ret then
      r.SetEditCurPos(cursor_pos, true, false)
    end
    local unarm = r.NamedCommandLookup("_XENAKIOS_SELTRAX_RECUNARMED")
    r.Main_OnCommand(unarm, 0) -- Xenakios/SWS: Set selected tracks record unarmed
    
    local num_tracks = r.CountTracks(0)
    local selected_track = r.GetSelectedTrack(0,0)
    local current_num = r.GetMediaTrackInfo_Value(selected_track, 'IP_TRACKNUMBER')
    local bool = false
    for i=current_num,num_tracks-1,1 do
      local track = r.GetTrack(0, i)
      if r.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        r.Main_OnCommand(40297,0) -- deselect all tracks
        r.SetTrackSelected(track, true)
        local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
        r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        solo()
        local arm = r.NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
        r.Main_OnCommand(arm, 0) -- Xenakios/SWS: Set selected tracks record armed
        mixer()
        local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
        r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
        r.Main_OnCommand(40913,0) -- adjust scroll to selected tracks
        bool = true
        r.TrackList_AdjustWindows(false)
        break
      end
    end
    if bool == false then
      local duplicate = reaper.NamedCommandLookup("_RS2c6e13d20ab617b8de2c95a625d6df2fde4265ff")
      r.Main_OnCommand(duplicate,0)
      local arm = r.NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
      r.Main_OnCommand(arm, 0) -- Xenakios/SWS: Set selected tracks record armed
      local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
      r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
      r.Main_OnCommand(40913,0) -- adjust scroll to selected tracks
    end
    r.Undo_EndBlock('Classical Take Record Stop', 0)
  end
  r.UpdateArrange()
  r.UpdateTimeline()
end

function solo()
  local track = r.GetSelectedTrack(0, 0)
  if not track then
    return false
  end
  r.SetMediaTrackInfo_Value(track, "I_SOLO", 2)

  for i = 0, r.CountTracks(0) - 1, 1 do
    track = r.GetTrack(0, i)
    if r.IsTrackSelected(track) == false then
      r.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
      i = i + 1
    end
  end
  return true
end

function bus_check(track)
  _, trackname = r.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  return string.find(trackname, "^@")
end

function mixer()
  for i = 0, r.CountTracks(0) - 1, 1 do
    local track = r.GetTrack(0, i)
    if bus_check(track) then
      native_color = r.ColorToNative(76,145,101)
      r.SetTrackColor(track, native_color)
      r.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
    end
    if r.IsTrackSelected(track) or bus_check(track) then
      r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
    else
      r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
    end
  end
end

function track_check()
  return r.CountTracks(0)
end


function load_prefs()
  return r.GetProjExtState(0,"ReaClassical", "Classical Take Record Cursor Position")
end

function save_prefs(input)
  r.SetProjExtState(0,"ReaClassical", "Classical Take Record Cursor Position", input)
end

-----------------------------------------------------------------------

Main()
