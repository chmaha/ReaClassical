--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main

---------------------------------------------------------------------

function main()
  Undo_BeginBlock()

  local selected_tracks = CountSelectedTracks(0)
  if selected_tracks > 1 or selected_tracks == 0 then
    ShowMessageBox("Please select a single child track from the first group", "Move Track Up in All Groups", 0)
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

  local tracks_per_group = child_count + 1

  if folder_count == 0 then
    ShowMessageBox("This function can only be used on a project with one or more folders",
      "Move Track Up in All Groups", 0)
    return
  end

  local track = GetSelectedTrack(0, 0)
  local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

  --select track above (to use same code as Track Down!)
  local earlier_track = GetTrack(0, track_idx - 1)
  if earlier_track then
    track_idx = GetMediaTrackInfo_Value(earlier_track, "IP_TRACKNUMBER") - 1
  else
    ShowMessageBox("Please select a child track in the folder", "Move Track Up in All Groups", 0)
    return
  end

  if track_idx == 0 then
    ShowMessageBox("The track is already the first child in the folder", "Move Track Up in All Groups", 0)
    return
  elseif track_idx >= tracks_per_group - 1 then
    ShowMessageBox("Please select a child track in the first folder", "Move Track Up in All Groups", 0)
    return
  end

  local next_track = GetTrack(0, track_idx + 1)
  SetOnlyTrackSelected(next_track)
  local similar_tracks = {}
  for i = track_idx + 1, folder_count * tracks_per_group + tracks_per_group - 1, tracks_per_group do
    table.insert(similar_tracks, i)
  end
  for _, idx in pairs(similar_tracks) do
    local source_track = GetTrack(0, idx)
    SetOnlyTrackSelected(source_track)
    ReorderSelectedTracks(idx - 1, 0)
  end
  SetOnlyTrackSelected(track)

  if folder_count > 1 then
    local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
    Main_OnCommand(F8_sync, 0)
  else
    local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
    Main_OnCommand(F7_sync, 0)
  end
  Undo_EndBlock("Move Track Up in All Groups", -1)
end

---------------------------------------------------------------------

main()
