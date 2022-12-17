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
local horizontal, horizontal_color, horizontal_group, shift, vertical, vertical_color, vertical_group
local empty_folder_check, copy_track_items, tracks_per_folder

function Main()
  if r.CountMediaItems(0) == 0 then
    r.ShowMessageBox("Please add your takes before running...", "Prepare Takes", 0)
    return  
  end
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()
  r.Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
  local total_tracks = r.CountTracks(0)
  local folders = 0
  local empty = false
  for i = 0, total_tracks - 1, 1 do
    local track = r.GetTrack(0, i)
    if r.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1.0 then
      folders = folders + 1
      local items = r.CountTrackMediaItems(track)
      if items == 0 then
        empty = true
      end
    end
  end

  local first_item = r.GetMediaItem(0, 0)
  local position = r.GetMediaItemInfo_Value(first_item, "D_POSITION")
  if position == 0.0 then
    shift()
  end

  if empty then
    local folder_size = tracks_per_folder()
    copy_track_items(folder_size, total_tracks)
  end

  if folders == 0 or folders == 1 then
    horizontal()
  else
    vertical()
  end
  r.Main_OnCommand(40042, 0) -- go to start of project
  r.Main_OnCommand(40939, 0) -- select track 01
  if empty then
    r.ShowMessageBox("Your folder tracks were empty. Items from first child tracks were therefore copied to folder tracks and muted to act as guide tracks."
      , "Guide Tracks Created", 0)
  end
  r.Undo_EndBlock('Prepare Takes', 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.UpdateTimeline()
end

function shift()
  r.Main_OnCommand(40182, 0) -- select all items
  local nudge_right = r.NamedCommandLookup("_SWS_NUDGESAMPLERIGHT")
  r.Main_OnCommand(nudge_right, 0) -- shift items by 1 sample to the right
  r.Main_OnCommand(40289, 0) -- unselect all items
end

function horizontal_color()
  r.Main_OnCommand(40706, 0)
end

function vertical_color()
  r.Main_OnCommand(40042, 0) -- Transport: Go to start of project
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
  r.Main_OnCommand(40421, 0) -- Item: Select all items in track
  r.Main_OnCommand(40706, 0) -- Item: Set to one random color
end

local function horizontal_group()
  r.Main_OnCommand(40296, 0) -- Track: Select all tracks
  r.Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
  local select_under = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
  r.Main_OnCommand(select_under, 0) -- XENAKIOS_SELITEMSUNDEDCURSELTX
  r.Main_OnCommand(40032, 0) -- Item grouping: Group items
end

function vertical_group(length)
  local track = r.GetSelectedTrack(0, 0)
  local item = r.AddMediaItemToTrack(track)
  r.SetMediaItemPosition(item, length + 1, false)

  while r.IsMediaItemSelected(item) == false do
    r.Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    local select_under = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    r.Main_OnCommand(select_under, 0) -- XENAKIOS_SELITEMSUNDEDCURSELTX
    r.Main_OnCommand(40032, 0) -- Item grouping: Group items
  end
  r.DeleteTrackMediaItem(track, item)
end

function horizontal()
  local length = r.GetProjectLength(0)
  local num_of_tracks = r.CountTracks(0)
  local last_track = r.GetTrack(0, num_of_tracks - 1)
  local new_item = r.AddMediaItemToTrack(last_track)
  r.SetMediaItemPosition(new_item, length + 1, false)
  local num_of_items = r.CountMediaItems(0)
  local last_item = r.GetMediaItem(0, num_of_items - 1)
  r.SetEditCurPos(0, false, false)

  while r.IsMediaItemSelected(last_item) == false do
    horizontal_group()
    horizontal_color()
  end

  r.DeleteTrackMediaItem(last_track, last_item)
  r.SelectAllMediaItems(0, false)
  r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  r.SetEditCurPos(0, false, false)
end

function vertical()
  r.Undo_BeginBlock()
  local select_all_folders = r.NamedCommandLookup("_SWS_SELALLPARENTS")
  r.Main_OnCommand(select_all_folders, 0) -- select all folders
  local num_of_folders = r.CountSelectedTracks(0)
  local length = r.GetProjectLength(0)
  local first_track = r.GetTrack(0, 0)
  r.SetOnlyTrackSelected(first_track)
  for i = 1, num_of_folders, 1 do
    vertical_color()
    vertical_group(length)
    local next_folder = r.NamedCommandLookup("_SWS_SELNEXTFOLDER")
    r.Main_OnCommand(next_folder, 0) -- select next folder
  end
  r.SelectAllMediaItems(0, false)
  r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  r.SetEditCurPos(0, false, false)
end

function copy_track_items(folder_size, total_tracks)
  local pos = 0;
  for i = 1, total_tracks - 1, folder_size do
    local track = r.GetTrack(0, i)
    local previous_track = r.GetTrack(0, i - 1)
    local count_items = r.CountTrackMediaItems(previous_track)
    if count_items > 0 then goto continue end -- guard clause for populated folder
    r.SetOnlyTrackSelected(track)
    local num_of_items = r.CountTrackMediaItems(track)
    if num_of_items == 0 then goto continue end -- guard clause for empty first child
    for j = 0, num_of_items - 1 do
      local item = r.GetTrackMediaItem(track, j)
      if j == 0 then
        pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
      end
      r.SetMediaItemSelected(item, 1)
    end
    r.Main_OnCommand(40698, 0) -- Edit: Copy items
    local previous_track = r.GetTrack(0, i - 1)
    r.SetOnlyTrackSelected(previous_track)
    r.SetEditCurPos(pos, false, false)
    r.Main_OnCommand(42398, 0) -- Item: Paste items/tracks
    r.Main_OnCommand(40719, 0) -- Item properties: Mute
    r.Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
    ::continue::
  end
end

function tracks_per_folder()
  local first_track = r.GetTrack(0, 0)
  r.SetOnlyTrackSelected(first_track)
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
  local selected_tracks = r.CountSelectedTracks(0)
  r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  return selected_tracks
end

Main()
