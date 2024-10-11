--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, add_track_to_folder

---------------------------------------------------------------------

function main()
  Undo_BeginBlock()
  -- get folder and child count
  local num_of_tracks = CountTracks(0)
  local folder_count = 0
  local child_count = 0
  for i = 0, num_of_tracks - 1 do
    local track = GetTrack(0, i)
    local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local patterns = { "^M:", "^@", "^#", "^RCMASTER", "^RoomTone", "^REF" }
    local bus = false
    for _, pattern in ipairs(patterns) do
      if string.match(name, pattern) then
        bus = true
        break
      end
    end
    if depth == 1 then
      folder_count = folder_count + 1
    elseif depth ~= 1 and folder_count == 1 and not bus then
      child_count = child_count + 1
    end
  end

  if folder_count == 0 then
    ShowMessageBox("Add one or more folders before running.", "Add Track To All Groups", 0)
    return
  end

  local ret, name = GetUserInputs("Add Track To All Groups", 1, "Track Name:", "")
  if not ret then return end

  -- add new track to penultimate position
  for i = 0, num_of_tracks - 1 + folder_count, 1 do
    local track = GetTrack(0, i)
    local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    if depth == 1 then
      add_track_to_folder(i + child_count)
    end
    if depth == -1 then
      -- switch with last track in folder
      SetOnlyTrackSelected(track)
      ReorderSelectedTracks(i - 1, 0)
    end
  end

  --add new mixer track
  local tracks_per_folder = child_count+2
  local index = (folder_count*tracks_per_folder)+tracks_per_folder-1
  add_track_to_folder(index)
  local new_track = GetTrack(0,index)
  GetSetMediaTrackInfo_String(new_track, "P_NAME", "M:" .. name, 1)
  GetSetMediaTrackInfo_String(new_track, "P_EXT:mix_order", index, 1) -- force mix_order reset
  if folder_count > 1 then
    local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
    Main_OnCommand(F8_sync, 0)
  else
    local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
    Main_OnCommand(F7_sync, 0)
  end
  Undo_EndBlock("Add Track to Folder", -1)
end

---------------------------------------------------------------------

function add_track_to_folder(num)
  InsertTrackAtIndex(num, 1)
end

---------------------------------------------------------------------

main()
