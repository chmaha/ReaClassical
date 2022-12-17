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
local mixer, solo, track_check

function Main()
  if track_check() == 0 then
    r.ShowMessageBox("Please add at least one track or folder before running", "Classical Take Record", 0)
    return
  end
  local take_record_toggle = r.NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")
  if r.GetPlayState() == 0 then
    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    r.SetToggleCommandState(1, take_record_toggle, 1)
    r.RefreshToolbar2(1, take_record_toggle)
    solo()
    r.Main_OnCommand(40491, 0) -- Track: Unarm all tracks for recording
    local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
    r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    mixer()
    local arm = r.NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
    r.Main_OnCommand(arm, 0) -- Xenakios/SWS: Set selected tracks record armed
    r.Main_OnCommand(1013, 0) -- Transport: Record

    r.Undo_EndBlock('Classical Take Record', 0)
    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.UpdateTimeline()
  else
    r.PreventUIRefresh(1)
    r.Undo_BeginBlock()
    r.SetToggleCommandState(1, take_record_toggle, 0)
    r.RefreshToolbar2(1, take_record_toggle)
    r.Main_OnCommand(40667, 0) -- Transport: Stop (save all recorded media)
    local unarm = r.NamedCommandLookup("_XENAKIOS_SELTRAX_RECUNARMED")
    r.Main_OnCommand(unarm, 0) -- Xenakios/SWS: Set selected tracks record unarmed
    local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
    r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)

    r.Undo_EndBlock('Classical Take Record Stop', 0)
    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.UpdateTimeline()
  end
end

function solo()
  local track = r.GetSelectedTrack(0, 0)
  r.SetMediaTrackInfo_Value(track, "I_SOLO", 1)

  for i = 0, r.CountTracks(0) - 1, 1 do
    track = r.GetTrack(0, i)
    if r.IsTrackSelected(track) == false then
      r.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
      i = i + 1
    end
  end
end

function mixer()
  for i = 0, r.CountTracks(0) - 1, 1 do
    local track = r.GetTrack(0, i)
    if r.IsTrackSelected(track) then
      r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
    else
      r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
    end
  end
end

function track_check()
  return r.CountTracks(0)
end

Main()
