--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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
local cd_markers, find_current_start, create_marker, renumber_markers, add_pregap, end_marker, frame_check
local get_info, save_metadata, find_project_end, add_codes, save_codes, delete_markers, empty_items_check
local first_track = r.GetTrack(0, 0)
if first_track then NUM_OF_ITEMS = r.CountTrackMediaItems(first_track) end

function Main()
  r.Undo_BeginBlock()
  if not first_track or NUM_OF_ITEMS == 0 then
    r.ShowMessageBox("Error: No media items found.","Create CD Markers",0)
    return
  end
  local empty_count = empty_items_check()
  if empty_count > 0 then
    r.ShowMessageBox("Error: Empty items found on first track. Delete them to continue.","Create CD Markers",0)
    return
  end
  local choice = r.ShowMessageBox("WARNING: This will delete all existing markers, regions and item take markers. Track titles will be pulled from item take names. Continue?"
    ,
    "Create CD/DDP markers", 4)
  if choice == 6 then
    r.SetProjExtState(0, "Create CD Markers", "Run?", "yes")
    cd_markers()
  end
  r.Undo_EndBlock("Create CD/DDP Markers", -1)
end

function get_info()
  local _, metadata_saved = r.GetProjExtState(0, "Create CD Markers", "Album Metadata")
  local ret, user_inputs, metadata_table
  if metadata_saved ~= "" then
    ret, user_inputs = r.GetUserInputs('CD/DDP Album information', 4,
      'Album Title,Performer,Composer,Genre,extrawidth=100',
      metadata_saved)
  else
    ret, user_inputs = r.GetUserInputs('CD/DDP Album information', 4,
      'Album Title,Performer,Composer,Genre,extrawidth=100',
      'My Classical Album,Performer,Composer,Classical')
  end
  metadata_table = {}
  for entry in user_inputs:gmatch('([^,]+)') do metadata_table[#metadata_table + 1] = entry end
  if not ret then
    r.ShowMessageBox('Only writing track metadata', "Cancelled", 0)
  elseif #metadata_table ~= 4 then
    r.ShowMessageBox('Empty metadata_table not supported: Not writing album metadata', "Warning", 0)
  end
  return user_inputs, metadata_table
end

function cd_markers()
  delete_markers()

  r.SNM_SetIntConfigVar('projfrbase', 75)
  r.Main_OnCommand(40754, 0) --enable snap to grid

  local code_input, code_table = add_codes()
  if code_input ~= "" then
    save_codes(code_input)
  end

  local final_end = find_project_end()
  local previous_start
  local previous_takename
  local marker_count = 0
  for i = 0, NUM_OF_ITEMS - 1, 1 do
    local current_start, take_name = find_current_start(i)
    local added_marker = create_marker(current_start, marker_count, take_name, code_table)
    if added_marker then
      if take_name:match("^!") and marker_count > 0 then
        r.AddProjectMarker(0, false, frame_check(current_start) - 3.2, 0, "!", marker_count)
      end
      if marker_count > 0 then
        r.AddProjectMarker(0, true, frame_check(previous_start) - 0.2, frame_check(current_start) - 0.2, previous_takename:match("^[!]*(.+)"),
          marker_count)
      end
      previous_start = current_start
      previous_takename = take_name
      marker_count = marker_count + 1
    end
  end
  if marker_count == 0 then
    r.ShowMessageBox('Please add take names to all items that you want to be CD tracks (Select item then press F2)', "No track markers created", 0)
    return
  end
  r.AddProjectMarker(0, true, frame_check(previous_start) - 0.2, frame_check(final_end) + 7, previous_takename, marker_count)
  if marker_count ~= 0 then
    local user_inputs, metadata_table = get_info()
    if #metadata_table == 4 then save_metadata(user_inputs) end
    end_marker(metadata_table, code_table)
    renumber_markers()
    add_pregap()
  end
  r.Main_OnCommand(40753, 0) -- Snapping: Disable snap
end

function find_current_start(i)
  local current_item = r.GetTrackMediaItem(first_track, i)
  local take = r.GetActiveTake(current_item)
  local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  return r.GetMediaItemInfo_Value(current_item, "D_POSITION"), take_name
end

function create_marker(current_start, marker_count, take_name, code_table)
  local added_marker = false
  local track_title
  if take_name ~= "" then
    local corrected_current_start = frame_check(current_start) - 0.2
    if #code_table == 5 then
      track_title = "#" .. take_name:match("^[!]*(.+)") .. "|ISRC=" .. code_table[2] .. code_table[3] .. code_table[4] .. string.format("%05d", code_table[5] + marker_count)
    else
      track_title = "#" .. take_name:match("^[!]*(.+)")
    end
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
  local final_item = r.GetTrackMediaItem(first_track, NUM_OF_ITEMS - 1)
  local final_start = r.GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = r.GetMediaItemInfo_Value(final_item, "D_LENGTH")
  return final_start + final_length
end

function end_marker(metadata_table, code_table)
  local final_item = r.GetTrackMediaItem(first_track, NUM_OF_ITEMS - 1)
  local final_start = r.GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = r.GetMediaItemInfo_Value(final_item, "D_LENGTH")
  local final_end = final_start + final_length
  if #metadata_table == 4 and #code_table == 5 then
    local album_info = "@" ..
        metadata_table[1] ..
        "|CATALOG=" .. code_table[1] .. "|PERFORMER=" .. metadata_table[2] .. "|COMPOSER=" .. metadata_table[3] ..
        "|GENRE=" .. metadata_table[4]
    r.AddProjectMarker(0, false, frame_check(final_end) + 1, 0, album_info, 0)
  elseif #metadata_table == 4 then
    local album_info = "@" ..
        metadata_table[1] .. "|PERFORMER=" .. metadata_table[2] .. "|COMPOSER=" .. metadata_table[3] ..
        "|GENRE=" .. metadata_table[4]
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
  r.SetProjExtState(0, "Create CD Markers", "Album Metadata", user_inputs)
end

function save_codes(code_input)
  r.SetProjExtState(0, "Create CD Markers", "Codes", code_input)
end

function add_codes()
  local _, code_saved = r.GetProjExtState(0, "Create CD Markers", "Codes")
  local codes_response = r.ShowMessageBox("Add UPC/ISRC codes?", "CD codes", 4)
  local ret2
  local code_input = ""
  local code_table = {}
  if codes_response == 6 then
    if code_saved ~= "" then
      ret2, code_input = r.GetUserInputs('UPC/ISRC Codes', 5,
        'UPC or EAN,ISRC Country Code,ISRC Registrant Code,ISRC Year (YY),ISRC Designation Code (5 digits),extrawidth=100'
        ,
        code_saved)
    else
      ret2, code_input = r.GetUserInputs('UPC/ISRC Codes', 5,
        'UPC or EAN,ISRC Country Code,ISRC Registrant Code,ISRC Year (YY),ISRC Designation Code (5 digits),extrawidth=100'
        ,
        ',')
    end
    for num in code_input:gmatch('([^,]+)') do code_table[#code_table + 1] = num end
    if not ret2 then
      r.ShowMessageBox('Not writing UPC/EAN or ISRC codes', "Cancelled", 0)
    elseif #code_table ~= 5 then
      r.ShowMessageBox('Empty code metadata_table not supported: Not writing UPC/EAN or ISRC codes', "Warning",
        0)
    end
  end
  return code_input, code_table
end

function delete_markers()
  local delete_markers = r.NamedCommandLookup("_SWSMARKERLIST9")
  r.Main_OnCommand(delete_markers, 0)
  local delete_regions = r.NamedCommandLookup("_SWSMARKERLIST10")
  r.Main_OnCommand(delete_regions, 0)
  r.Main_OnCommand(40182, 0) -- select all items
  r.Main_OnCommand(42387, 0) -- Delete all take markers
  r.Main_OnCommand(40289, 0) -- Unselect all items
end

function empty_items_check()
  local count = 0
  for i = 0, NUM_OF_ITEMS - 1, 1 do
    local current_item = r.GetTrackMediaItem(first_track, i)
    local take = r.GetActiveTake(current_item)
    if not take then 
      count = count + 1 
    end 
  end
  return count
end

Main()

