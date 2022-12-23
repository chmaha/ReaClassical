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
local first_track = r.GetTrack(0, 0)
local num_of_items = r.CountTrackMediaItems(first_track)
local cd_markers, find_current_start, create_marker, renumber_markers, add_pregap, end_marker, frame_check
local get_info, save_metadata, find_project_end

function Main()
  local choice = r.ShowMessageBox("WARNING: This will delete all existing markers and track titles will be pulled from item take names."
    ,
    "Create CD/DDP markers", 1)
  if choice ~= 2 then
    cd_markers()
  end
end

function get_info()
  local metadata_saved = r.GetExtState("Create CD Markers", "Album Metadata")
  local ret, user_inputs, fields
  if metadata_saved then
    ret, user_inputs = r.GetUserInputs('CD/DDP Album information', 4,
    'Album Title,Performer,Composer,Genre,extrawidth=100',
    metadata_saved)
  else
    ret, user_inputs = r.GetUserInputs('CD/DDP Album information', 4,
      'Album Title,Performer,Composer,Genre,extrawidth=100',
      'My Classical Album,Performer,Composer,Classical')
  end
  fields = {}
  for word in user_inputs:gmatch('([^,]+)') do fields[#fields + 1] = word end
  if not ret then
    r.ShowMessageBox('Only writing track metadata', "Cancelled", 0)
  elseif #fields ~= 4 then
    r.ShowMessageBox('Empty fields not supported: Not writing album metadata', "Warning", 0)
  end
  return user_inputs, fields
end

function cd_markers()
  local delete_markers = r.NamedCommandLookup("_SWSMARKERLIST9")
  r.Main_OnCommand(delete_markers, 0)
  local delete_regions = r.NamedCommandLookup("_SWSMARKERLIST10")
  r.Main_OnCommand(delete_regions, 0)

  r.SNM_SetIntConfigVar('projfrbase', 75)
  r.Main_OnCommand(40754, 0) --enable snap to grid
  local final_end = find_project_end()
  local previous_start
  local previous_takename
  local marker_count = 0
  for i = 0, num_of_items - 1, 1 do
    local current_start, take_name = find_current_start(i)
    local added_marker = create_marker(current_start, marker_count, take_name)
    if added_marker then
      if marker_count > 0 then
        r.AddProjectMarker(0, true, frame_check(previous_start), frame_check(current_start), previous_takename, marker_count)
      end
      previous_start = current_start
      previous_takename = take_name
      marker_count = marker_count + 1
    end
  end
  r.AddProjectMarker(0, true, frame_check(previous_start), frame_check(final_end) + 7, previous_takename, marker_count)
  if marker_count ~= 0 then
    local user_inputs, fields = get_info()
    if #fields == 4 then save_metadata(user_inputs) end
    end_marker(fields)
    renumber_markers()
    add_pregap()
  else
    r.ShowMessageBox('Please add some take names to media items (F2)', "No track markers created", 0)
  end
  r.Main_OnCommand(40753, 0) -- Snapping: Disable snap
end

function find_current_start(i)
  local current_item = r.GetTrackMediaItem(first_track, i)
  local take = r.GetActiveTake(current_item)
  local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  return r.GetMediaItemInfo_Value(current_item, "D_POSITION"), take_name
end

function create_marker(current_start, marker_count, take_name)
  local added_marker = false
  if take_name ~= "" then
    local corrected_current_start = frame_check(current_start)
    local track_title = "#" .. take_name
    r.AddProjectMarker(0, false, corrected_current_start, 0, track_title, marker_count + 1)
    added_marker = true
  end
  return added_marker
end

function renumber_markers()
  r.Main_OnCommand(40898, 0)
end

function add_pregap()
  local first_item_start, _ = find_current_start(0)
  local _, _, first_marker, _, _, _ = r.EnumProjectMarkers(0)
  local first_pregap
  if first_marker - first_item_start < 2 then
    first_pregap = first_item_start - 2 + (first_marker - first_item_start) -- Ensure initial pre-gap is at least 2 seconds in length
  else
    first_pregap = first_item_start
  end
  if first_pregap > 0 then
    r.GetSet_LoopTimeRange(true, false, 0, first_pregap, false)
    r.Main_OnCommand(40201, 0) -- Time selection: Remove contents of time selection (moving later items)
  elseif first_pregap < 0 then
    r.GetSet_LoopTimeRange(true, false, 0, 0 - first_pregap, false)
    r.Main_OnCommand(40200, 0) -- Time selection: Insert empty space at time selection (moving later items)
    r.GetSet_LoopTimeRange(true, false, 0, 0, false)
  end
  r.AddProjectMarker(0, false, 0, 0, "!", 0)
  r.SNM_SetDoubleConfigVar('projtimeoffs', 0)
end

function find_project_end()
  local final_item = r.GetTrackMediaItem(first_track, num_of_items - 1)
  local final_start = r.GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = r.GetMediaItemInfo_Value(final_item, "D_LENGTH")
  return final_start + final_length
end

function end_marker(fields)
  local final_item = r.GetTrackMediaItem(first_track, num_of_items - 1)
  local final_start = r.GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = r.GetMediaItemInfo_Value(final_item, "D_LENGTH")
  local final_end = final_start + final_length
  if #fields == 4 then
    local album_info = "@" .. fields[1] .. "|PERFORMER=" .. fields[2] .. "|COMPOSER=" .. fields[3] ..
        "|GENRE=" .. fields[4]
    r.AddProjectMarker(0, false, frame_check(final_end) + 1, 0, album_info, 0)
  end
  r.AddProjectMarker(0, false, frame_check(final_end) + 7, 0, "=END", 0)
end

function frame_check(pos)
  local nearest_grid = r.BR_GetClosestGridDivision(pos)
  if pos ~= nearest_grid then
    pos = r.BR_GetPrevGridDivision(pos)
  end
  return pos
end

function save_metadata(user_inputs)
  r.SetExtState("Create CD Markers", "Album Metadata", user_inputs, false)
end

Main()
