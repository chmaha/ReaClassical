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
local track_check, media_razor_group

function Main()

  if track_check() == 0 then
    local boolean, num = r.GetUserInputs("Create Folder", 1, "How many tracks?", 10)
    if boolean == true then
      for i = 1, tonumber(num), 1 do
        r.InsertTrackAtIndex(0, true)
      end
      for i = 0, tonumber(num) - 1, 1 do
        local track = r.GetTrack(0, i)
        r.SetTrackSelected(track, 1)
      end
      local folder = r.NamedCommandLookup("_SWS_MAKEFOLDER")
      r.Main_OnCommand(folder, 0)
      for i = 0, tonumber(num) - 1, 1 do
        local track = r.GetTrack(0, i)
        r.SetTrackSelected(track, 0)
      end
    end
    media_razor_group()
  else
    r.ShowMessageBox("Please use this function with an empty project", "Create Destination Group", 0)
  end
end

function track_check()
  return r.CountTracks(0)
end

function media_razor_group()
  local select_all_folders = r.NamedCommandLookup("_SWS_SELALLPARENTS")
  r.Main_OnCommand(select_all_folders, 0) -- select all folders
  local num_of_folders = r.CountSelectedTracks(0)
  local first_track = r.GetTrack(0, 0)
  r.SetOnlyTrackSelected(first_track)
  if num_of_folders > 1 then
    for i = 1, num_of_folders, 1 do
      local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
      r.Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
      r.Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
      local next_folder = r.NamedCommandLookup("_SWS_SELNEXTFOLDER")
      r.Main_OnCommand(next_folder, 0) -- select next folder
    end
  else
    local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
    r.Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
    r.Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
  end
  r.Main_OnCommand(40939, 0) -- Track: Select track 01
end

Main()
