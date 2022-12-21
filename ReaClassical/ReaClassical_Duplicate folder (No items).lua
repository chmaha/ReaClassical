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
local mixer, solo, track_check, media_razor_group

function Main()
  if track_check() == 0 then
    r.ShowMessageBox("Please add at least one track or folder before running", "Duplicate folder (no items)", 0)
    return
  end
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()

  r.Main_OnCommand(40340, 0)
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
  local copy = r.NamedCommandLookup("_S&M_COPYSNDRCV1") -- SWS/S&M: Copy selected tracks (with routing)
  r.Main_OnCommand(copy, 0)
  local paste = r.NamedCommandLookup("_SWS_AWPASTE")
  r.Main_OnCommand(paste, 0) -- SWS_AWPASTE
  r.Main_OnCommand(40421, 0) -- Item: Select all items in track
  local delete_items = r.NamedCommandLookup("_SWS_DELALLITEMS")
  r.Main_OnCommand(delete_items, 0)
  mixer()
  local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
  r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
  solo()
  media_razor_group()
  r.Undo_EndBlock('Duplicate folder (No items)', 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.UpdateTimeline()
  r.TrackList_AdjustWindows(false)
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

function media_razor_group()
  r.Main_OnCommand(40296, 0) -- Select all tracks
  r.Main_OnCommand(42579, 0) -- Track: Remove selected tracks from all track media/razor editing groups
  local select_all_folders = r.NamedCommandLookup("_SWS_SELALLPARENTS")
  r.Main_OnCommand(select_all_folders, 0) -- select all folders
  local num_of_folders = r.CountSelectedTracks(0)
  local first_track = r.GetTrack(0, 0)
  r.SetOnlyTrackSelected(first_track)
  for i = 1, num_of_folders, 1 do
    local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
    r.Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
    r.Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
    local next_folder = r.NamedCommandLookup("_SWS_SELNEXTFOLDER")
    r.Main_OnCommand(next_folder, 0) -- select next folder
  end
end

Main()
