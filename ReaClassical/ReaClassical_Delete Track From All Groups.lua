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

local main, delete_mixer, delete_tracks, evaluate_project
local get_regular_track, handle_invalid, move_up

---------------------------------------------------------------------

function main()
  Undo_BeginBlock()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
      MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
      return
  end
  local selected_tracks = CountSelectedTracks(0)
  if selected_tracks > 1 or selected_tracks == 0 then
    MB("Please select a single mixer track", "Delete Track From All Groups", 0)
    return
  end

  -- get folder, tracks per group and child count
  local folder_count, tracks_per_group, child_count = evaluate_project()

  if folder_count == 0 then
    MB("This function can only be used on a project with one of more folders",
      "Delete Track From All Groups",
      0)
    return
  end

  local track = GetSelectedTrack(0, 0)
  local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", 0)

  local orig_selection
  if mixer_state == "y" then
    orig_selection = track
    Main_OnCommand(40769, 0) -- unselect all items
    track = get_regular_track(track, folder_count, tracks_per_group)
    if track then
      SetTrackSelected(track, true)
    else
      MB("The track is missing!", "Delete Track From All Groups", 0)
      return
    end
  else
    MB("Please select a single mixer track", "Delete Track From All Groups", 0)
    return
  end

  local track_idx = delete_tracks(track, child_count, tracks_per_group, folder_count)

  if track_idx > 0 then
    delete_mixer(folder_count, tracks_per_group, track_idx)
  else
    local messages = {
      [-1] = "Please select a mixer track not associated with the parent track",
      [-2] = "You are already at the minimum number of tracks to form a folder"
    }
    if messages[track_idx] then
      handle_invalid(messages[track_idx], orig_selection)
    end
  end

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

function delete_mixer(folder_count, tracks_per_group, track_idx)
  local mixer_location = (folder_count * (tracks_per_group - 1)) + track_idx
  local mixer = GetTrack(0, mixer_location)
  DeleteTrack(mixer)
end

---------------------------------------------------------------------

function delete_tracks(track, child_count, tracks_per_group, folder_count)
  local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

  if track_idx == 0 or track_idx > child_count then
    return -1
  end

  if tracks_per_group == 2 then
    return -2
  end

  if track_idx == child_count then
    move_up(folder_count, tracks_per_group)
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
  return track_idx
end

---------------------------------------------------------------------

function evaluate_project()
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
  return folder_count, tracks_per_group, child_count
end

---------------------------------------------------------------------

function get_regular_track(track, folder_count, tracks_per_group)
  local mixer_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
  local track_idx = mixer_idx - (folder_count * tracks_per_group)
  return GetTrack(0, track_idx)
end

---------------------------------------------------------------------

function handle_invalid(message, orig_selection)
  MB(message, "Delete Track From All Groups", 0)
  Main_OnCommand(40769, 0) -- Unselect all items
  SetTrackSelected(orig_selection, true)
end

---------------------------------------------------------------------

function move_up(folder_count, tracks_per_group)
  local track = GetSelectedTrack(0, 0)
  local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

  local earlier_track = GetTrack(0, track_idx - 1)
  if earlier_track then
    track_idx = GetMediaTrackInfo_Value(earlier_track, "IP_TRACKNUMBER") - 1
  else
    MB("Please select a child track in the folder", "Move Track Up in All Groups", 0)
    return
  end

  if track_idx == 0 then
    MB("The track is already the first child in the folder", "Move Track Up in All Groups", 0)
    return
  elseif track_idx >= tracks_per_group - 1 then
    MB("Please select a child track in the first folder", "Move Track Up in All Groups", 0)
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
end

---------------------------------------------------------------------

main()
