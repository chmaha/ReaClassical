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

local main

---------------------------------------------------------------------

function main()
  Undo_BeginBlock()

  local selected_tracks = CountSelectedTracks(0)
  if selected_tracks > 1 then
    ShowMessageBox("Please select a single child track","Delete Track From All Groups", 0)
    return
  end

  -- get folder and child count
  local num_of_tracks = CountTracks(0)
  local folder_count = 0
  local child_count = 0
  for i = 0, num_of_tracks - 1 do
    local track = GetTrack(0, i)
    local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local patterns = { "^M:", "^@", "^#", "^RCMASTER", "^RoomTone" }
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

  local tracks_per_group = child_count + 1

  if folder_count == 0 then
    ShowMessageBox("This function can only be used on a project with one of more folders", "Delete Track From All Groups", 0)
    return
  end

  local track = GetSelectedTrack(0, 0)
  local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

  if track_idx == 0 or track_idx > child_count then
    ShowMessageBox("Please select a child track from the first group", "Delete Track From All Groups", 0)
    return
  end

  if track_idx == child_count then
    local move_up = NamedCommandLookup("_RSaa782166e9bad06e1e776c2daa81b51d7f25220e")
    reaper.Main_OnCommand(move_up, 0)
    track = GetSelectedTrack(0, 0)
    track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
  end

  local similar_tracks = {}
  for i = track_idx + (folder_count - 1) * tracks_per_group, track_idx, -tracks_per_group do
    table.insert(similar_tracks, i)
  end
  for _, idx in pairs(similar_tracks) do
    local source_track = GetTrack(0, idx)
    DeleteTrack(source_track)
  end

  --delete mixer track
  local mixer_location = (folder_count * (tracks_per_group-1)) + track_idx
  local mixer = GetTrack(0, mixer_location)
  DeleteTrack(mixer)

  if folder_count > 1 then
    local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
    Main_OnCommand(F8_sync, 0)
  else
    local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
    Main_OnCommand(F7_sync, 0)
  end
  Undo_EndBlock("Delete Track From All Groups", -1)
end

---------------------------------------------------------------------

main()
