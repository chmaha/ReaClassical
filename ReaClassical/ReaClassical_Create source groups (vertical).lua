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
local create_destination_group, create_source_groups, folder_check, mixer, solo, sync_routing_and_fx
local media_razor_group, bus_check, remove_track_groups, add_track_groups

function Main()

  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()

  if r.CountTracks(0) == 0 then
    boolean, num = r.GetUserInputs("Create Destination & Source Groups", 1, "How many tracks per group?", 10)
    num = tonumber(num)
    if boolean == true and num > 1 then 
      create_destination_group() 
    elseif boolean == true and num < 2 then
      r.ShowMessageBox("You need 2 or more tracks to make a source group!","Create Source Groups",0)
    end
    if folder_check() == 1 then
      create_source_groups()
      add_track_groups()
      media_razor_group()
    end
  elseif folder_check() > 1 then
    sync_routing_and_fx()
    remove_track_groups()
    add_track_groups()
    media_razor_group()
  elseif folder_check() == 1 then
    remove_track_groups()
    create_source_groups()
    add_track_groups()
    media_razor_group()
  else
    r.ShowMessageBox("In order to use this script either:\n1. Run on an empty project\n2. Run with one existing folder\n3. Run on multiple existing folders to sync routing/fx", "Create Source Groups", 0)
  end
  r.Undo_EndBlock('Create Source Groups', 0)
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.UpdateTimeline()
end

function create_destination_group()
    for i = 1, num, 1 do
      r.InsertTrackAtIndex(0, true)
    end
    for i = 0, num - 1, 1 do
      local track = r.GetTrack(0, i)
      r.SetTrackSelected(track, 1)
    end
    local make_folder = r.NamedCommandLookup("_SWS_MAKEFOLDER")
    r.Main_OnCommand(make_folder, 0) -- make folder from tracks
    for i = 0, num - 1, 1 do
      local track = r.GetTrack(0, i)
      r.SetTrackSelected(track, 0)
    end
  end

function solo()
  local track = r.GetSelectedTrack(0, 0)
  r.SetMediaTrackInfo_Value(track, "I_SOLO", 2)

  for i = 0, r.CountTracks(0) - 1, 1 do
    track = r.GetTrack(0, i)
    if r.IsTrackSelected(track) == false then
      r.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
      i = i + 1
    end
  end
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

function folder_check()
  local folders = 0
  local total_tracks = r.CountTracks(0)
  for i = 0, total_tracks - 1, 1 do
    local track = r.GetTrack(0, i)
    if r.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
      folders = folders + 1
    end
  end
  return folders
end

function sync_routing_and_fx()
  local ans = r.ShowMessageBox("This will sync your source group routing and fx \nto match that of the destination group. Continue?", "Sync Source & Destination", 4)

  if ans == 6 then
    local first_track = r.GetTrack(0, 0)
    r.SetOnlyTrackSelected(first_track)
    local collapse = r.NamedCommandLookup("_SWS_COLLAPSE")
    r.Main_OnCommand(collapse, 0) -- collapse folder

    for i = 1, folder_check() - 1, 1 do
      local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
      r.Main_OnCommand(select_children, 0) --SWS_SELCHILDREN2
      local copy_folder_routing = r.NamedCommandLookup("_S&M_COPYSNDRCV2")
      r.Main_OnCommand(copy_folder_routing, 0) -- copy folder track routing
      r.Main_OnCommand(42579, 0) -- Track: Remove selected tracks from all track media/razor editing groups
      local copy = r.NamedCommandLookup("_S&M_COPYSNDRCV1") -- SWS/S&M: Copy selected tracks (with routing)
      r.Main_OnCommand(copy, 0)
      local paste = r.NamedCommandLookup("_SWS_AWPASTE")
      r.Main_OnCommand(paste, 0) -- SWS_AWPASTE
      r.Main_OnCommand(40421, 0) -- Item: Select all items in track
      local delete_items = r.NamedCommandLookup("_SWS_DELALLITEMS")
      r.Main_OnCommand(delete_items, 0)
      local paste_folder_routing = r.NamedCommandLookup("_S&M_PASTSNDRCV2")
      r.Main_OnCommand(paste_folder_routing, 0) -- paste folder track routing
      local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
      r.Main_OnCommand(unselect_children, 0) -- unselect children
      r.Main_OnCommand(40042, 0) --move edit cursor to start
      local next_folder = r.NamedCommandLookup("_SWS_SELNEXTFOLDER")
      r.Main_OnCommand(next_folder, 0) --select next folder

      --Account for empty folders
      local length = r.GetProjectLength(0)
      local old_tr = r.GetSelectedTrack(0, 0)
      local new_item = r.AddMediaItemToTrack(old_tr)
      r.SetMediaItemPosition(new_item, length + 1, false)

      select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
      r.Main_OnCommand(select_children, 0) --SWS_SELCHILDREN2
      r.Main_OnCommand(40421, 0) --select all items on track

      local selected_tracks = r.CountSelectedTracks(0)
      for i = 1, selected_tracks, 1 do
        r.Main_OnCommand(40117, 0) -- Move items up to previous folder
      end
      r.Main_OnCommand(40005, 0) --delete selected tracks
      local select_only = r.NamedCommandLookup("_SWS_SELTRKWITEM")
      r.Main_OnCommand(select_only, 0) --SWS: Select only track(s) with selected item(s)
      local dup_tr = r.GetSelectedTrack(0, 0)
      local tr_items = r.CountTrackMediaItems(dup_tr)
      local last_item = r.GetTrackMediaItem(dup_tr, tr_items - 1)
      r.DeleteTrackMediaItem(dup_tr, last_item)
      r.Main_OnCommand(40289, 0) -- Unselect all items
    end

    local first_track = r.GetTrack(0, 0)
    r.SetOnlyTrackSelected(first_track)
    solo()
    local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
    r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    mixer()
    local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
    r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
  end
end

function create_source_groups()
  local first_track = r.GetTrack(0, 0)
  r.SetOnlyTrackSelected(first_track)
  i = 0
  while i < 6 do
    local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
    r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    r.Main_OnCommand(42579, 0) -- Track: Remove selected tracks from all track media/razor editing groups
    local copy = r.NamedCommandLookup("_S&M_COPYSNDRCV1") -- SWS/S&M: Copy selected tracks (with routing)
    r.Main_OnCommand(copy, 0)
    local paste = r.NamedCommandLookup("_SWS_AWPASTE")
    r.Main_OnCommand(paste, 0) -- SWS_AWPASTE
    r.Main_OnCommand(40421, 0) -- Item: Select all items in track
    local delete_items = r.NamedCommandLookup("_SWS_DELALLITEMS")
    r.Main_OnCommand(delete_items, 0)
    i = i + 1
  end
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
  r.Main_OnCommand(40296, 0) -- Track: Select all tracks
  local collapse = r.NamedCommandLookup("_SWS_COLLAPSE")
  r.Main_OnCommand(collapse, 0) -- collapse folder
  r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  r.Main_OnCommand(40939, 0) -- Track: Select track 01
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)

  solo()
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
  mixer()
  local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
  r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)

  r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
  r.Main_OnCommand(40939, 0) -- select track 01
end

function remove_track_groups()
  r.Main_OnCommand(40296,0) -- select all tracks
  local remove_grouping = r.NamedCommandLookup("_S&M_REMOVE_TR_GRP")
  r.Main_OnCommand(remove_grouping,0)
  r.Main_OnCommand(40297,0) -- unselect all tracks
end  

function add_track_groups()
  local select_all_folders = r.NamedCommandLookup("_SWS_SELALLPARENTS")
  r.Main_OnCommand(select_all_folders, 0) -- select all folders
  local num_of_folders = r.CountSelectedTracks(0)
  local first_track = r.GetTrack(0, 0)
  r.SetOnlyTrackSelected(first_track)
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
  local folder_tracks = r.CountSelectedTracks(0)
  local i = 0
  while i < num_of_folders do
    local j = 0
    while j < folder_tracks do
      local track = r.GetSelectedTrack(0, j)
      if not bus_check(track) then
        r.GetSetTrackGroupMembership(track, "VOLUME_LEAD", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "VOLUME_FOLLOW", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "PAN_LEAD", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "PAN_FOLLOW", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "POLARITY_LEAD", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "POLARITY_FOLLOW", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "AUTOMODE_LEAD", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "AUTOMODE_FOLLOW", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "MUTE_LEAD", 2 ^ j, 2 ^ j)
        r.GetSetTrackGroupMembership(track, "MUTE_FOLLOW", 2 ^ j, 2 ^ j)
      end
      j = j + 1
    end
    local next_folder = r.NamedCommandLookup("_SWS_SELNEXTFOLDER")
    r.Main_OnCommand(next_folder, 0) --select next folder
    r.Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    i = i + 1
  end
end  

Main()
