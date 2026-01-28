--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

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

local main, get_info, cd_markers, find_current_start, create_marker
local renumber_markers, add_pregap, find_project_end, end_marker
local frame_check, delete_markers, remove_negative_position_items_from_folder
local empty_items_check, return_custom_length
local fade_equations, pos_check, is_item_start_crossfaded, is_item_end_crossfaded
local steps_by_length, generate_interpolated_fade, convert_fades_to_env, room_tone
local add_roomtone_fadeout, check_saved_state, album_item_count
local split_and_tag_final_item, restore_RCMix
local check_first_track_for_names, delete_all_markers_and_regions
local shift_folder_items_and_markers, shift_all_markers_and_regions

local minimum_points = 15
local points = {}
local RCMix_markers = {}

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
  MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
  return
end

local _, digital_release_str = GetProjExtState(0, "ReaClassical", "digital_release_only")
local digital_release_only = digital_release_str == "1"

function main()
  Undo_BeginBlock()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
      modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
      .. "+N to use this function.", "ReaClassical Error", 0)
    return
  end

  local not_saved = check_saved_state()
  if not_saved then
    MB("Please save your project before running this function.", "Create CD Markers", 0)
    return
  end

  local selected_track = GetSelectedTrack(0, 0)
  if not selected_track then
    MB("Error: No track selected.", "Create CD Markers", 0)
    return
  end

  -- Find folder parent (or use selected if already a folder)
  local depth = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")
  if depth ~= 1 then
    local track_index = GetMediaTrackInfo_Value(selected_track, "IP_TRACKNUMBER") - 1
    local folder_track = nil
    for i = track_index - 1, 0, -1 do
      local t = GetTrack(0, i)
      if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
        folder_track = t
        break
      end
    end
    if not folder_track then
      MB("Error: The selected track is not inside a folder. Please select a folder or a child track inside a folder.",
        "Create CD Markers", 0)
      return
    end
    selected_track = folder_track
  end

  local track_color = GetTrackColor(selected_track)

  local num_of_items = 0
  if selected_track then num_of_items = album_item_count(selected_track) end
  if not selected_track or num_of_items == 0 then
    MB("Error: No media items found.", "Create CD Markers", 0)
    return
  end
  local empty_count = empty_items_check(selected_track, num_of_items)
  if empty_count > 0 then
    MB("Error: Empty items found on first track. Delete them to continue.", "Create CD Markers", 0)
    return
  end

  local removed = remove_negative_position_items_from_folder(selected_track)
  if removed > 0 then
    ShowConsoleMsg("Cleaned up " .. removed .. " invalid item(s) from folder.\n")
  end

  local names_on_first_track = check_first_track_for_names(selected_track)
  if not names_on_first_track then return end

  SetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?", "yes")
  local success, redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length = cd_markers(
    selected_track,
    num_of_items, track_color)
  if not success then return end
  if redbook_track_length_errors > 0 then
    MB(
      'This album does not meet the Red Book standard as at least one of the CD tracks is under 4 seconds in length.',
      "Warning", 0)
  end
  if redbook_total_tracks_error == true then
    MB('This album does not meet the Red Book standard as it contains more than 99 tracks.',
      "Warning", 0)
  end
  if redbook_project_length > 79.57 then
    MB('This album does not meet the Red Book standard as it is longer than 79.57 minutes.',
      "Warning", 0)
  end
  PreventUIRefresh(1)
  room_tone(redbook_project_length * 60, selected_track)
  renumber_markers(track_color)
  PreventUIRefresh(-1)

  UpdateArrange()

  local ddp_editor = NamedCommandLookup("_RS5a9d8a4bab9aff7879af27a7d054e3db8da4e256")
  Main_OnCommand(ddp_editor, 0)
  restore_RCMix()

  Undo_EndBlock("Create CD/DDP Markers", -1)
end

---------------------------------------------------------------------

function get_info(track)
  if not track then return nil end

  for i = 0, GetTrackNumMediaItems(track) - 1 do
    local item = GetTrackMediaItem(track, i)
    if item then
      local take = GetActiveTake(item)
      if take then
        local take_name = GetTakeName(take)
        if take_name and take_name:match("^@") then
          return take_name:gsub("|$", "")
        end
      end
    end
  end
  return false
end

---------------------------------------------------------------------

function cd_markers(selected_track, num_of_items, track_color)
  local album_metadata = get_info(selected_track)
  if not album_metadata then
    album_metadata = split_and_tag_final_item(selected_track)
    -- MB("No album metadata found.\n" ..
    --   "Added generic album metadata to end of album:\n" ..
    --   "You can open metadata.txt to edit…", "Create CD Markers", 0)
  end

  delete_markers()

  SNM_SetIntConfigVar('projfrbase', 75)
  Main_OnCommand(40904, 0) -- set grid to frames
  Main_OnCommand(40754, 0) -- enable snap to grid

  local pregap_len, offset, postgap = return_custom_length()

  if digital_release_only then
    offset = 0 -- Override offset for digital releases
  end

  if tonumber(pregap_len) < 1 then pregap_len = 1 end
  local final_end = find_project_end(selected_track, num_of_items)
  local previous_start, previous_offset
  local redbook_track_length_errors = 0
  local redbook_total_tracks_error = false
  local previous_takename
  local marker_count = 0

  for i = 0, num_of_items - 1, 1 do
    local current_start, take_name, manual_offset, current_item = find_current_start(selected_track, i)
    local final_offset = offset + manual_offset
    if not take_name:match("^@") then
      local added_marker = create_marker(current_start, marker_count, take_name, final_offset,
        track_color, current_item)
      if added_marker then
        if take_name:match("^!") and marker_count > 0 then
          AddProjectMarker2(0, false, frame_check(current_start - (pregap_len + final_offset)), 0, "!", marker_count,
            track_color)
        end
        if marker_count > 0 then
          if current_start - previous_start < 4 then
            redbook_track_length_errors = redbook_track_length_errors + 1
          end
          AddProjectMarker2(0, true, frame_check(previous_start - previous_offset),
            frame_check(current_start - final_offset),
            previous_takename:match("^[!]*([^|]*)"),
            marker_count, track_color)
        end
        previous_start = current_start
        previous_offset = final_offset
        previous_takename = take_name
        marker_count = marker_count + 1
      end
    end
  end
  if marker_count == 0 then
    return false
  end
  if marker_count > 99 then
    redbook_total_tracks_error = true
  end
  AddProjectMarker2(0, true, frame_check(previous_start - previous_offset), frame_check(final_end) + postgap,
    previous_takename:match("^[!]*([^|]*)"),
    marker_count, track_color)
  local redbook_project_length
  if marker_count ~= 0 then
    add_pregap(selected_track, track_color)
    redbook_project_length = end_marker(selected_track, album_metadata, postgap, num_of_items,
      track_color)
  end
  Main_OnCommand(40753, 0) -- Snapping: Disable snap
  return true, redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length
end

---------------------------------------------------------------------

function find_current_start(selected_track, i)
  local current_item = GetTrackMediaItem(selected_track, i)
  local take = GetActiveTake(current_item)
  if not take then return nil, nil, 0 end

  local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  take_name = take_name:gsub("|$", "") -- remove trailing pipe if present

  -- Extract OFFSET if present
  local offset_str = take_name:match("|OFFSET=([%d%.%-]+)")
  local offset_val = offset_str and tonumber(offset_str) or 0

  -- Ensure OFFSET stays in the name (so editing metadata won't remove it)
  if offset_str then
    take_name = take_name:gsub("|OFFSET=[%d%.%-]+", "|OFFSET=" .. offset_val)
  end
  GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name, true)

  local item_pos = GetMediaItemInfo_Value(current_item, "D_POSITION")
  return item_pos, take_name, offset_val, current_item
end

---------------------------------------------------------------------

function create_marker(current_start, marker_count, take_name, offset, track_color, item)
  local added_marker = false
  if take_name ~= "" then
    local corrected_current_start = frame_check(current_start - offset)
    local clean_name = take_name:gsub("|OFFSET=[%d%.%-]+", "")
    local track_title = "#" .. clean_name:match("^[!]*(.+)")

    -- Add marker and get its marker number
    local marker_num = AddProjectMarker2(0, false, corrected_current_start, 0, track_title,
      marker_count + 1, track_color)
    added_marker = true

    if marker_num then
      -- Find the enumeration index for this marker number
      local num_m, num_r = CountProjectMarkers(0)
      for i = 0, num_m + num_r - 1 do
        local _, isrgn, _, _, _, markrgnindexnumber = EnumProjectMarkers3(0, i)
        if not isrgn and markrgnindexnumber == marker_num then
          -- Get GUID using enumeration index
          local _, guid = GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(i), "", false)

          -- Store GUID in item
          GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", guid, true)

          break
        end
      end
    end
  end
  return added_marker
end

---------------------------------------------------------------------

function renumber_markers(track_color)
  local num_markers, num_regions = CountProjectMarkers(0)
  local marker_idx = 0

  for i = 0, num_markers + num_regions - 1 do
    local _, isrgn, pos, rgnend, name = EnumProjectMarkers(i)
    if not isrgn then
      SetProjectMarkerByIndex(0, i, isrgn, pos, rgnend, marker_idx, name, track_color)
      marker_idx = marker_idx + 1
    end
  end
end

---------------------------------------------------------------------

function add_pregap(selected_track, track_color)
  local first_item_start, _ = find_current_start(selected_track, 0)
  local _, _, first_marker, _, _, _ = EnumProjectMarkers(0)
  local first_pregap
  if first_marker - first_item_start < 2 then
    first_pregap = -first_item_start + 2 -
        (first_marker - first_item_start) -- Ensure initial pre-gap is at least 2 seconds in length
  else
    first_pregap = -first_item_start
  end

  shift_folder_items_and_markers(selected_track, first_pregap)
  shift_all_markers_and_regions(first_pregap)

  AddProjectMarker2(0, false, 0, 0, "!", 0, track_color)
  SNM_SetDoubleConfigVar('projtimeoffs', 0)
end

---------------------------------------------------------------------

function find_project_end(selected_track, num_of_items)
  local final_item = GetTrackMediaItem(selected_track, num_of_items - 1)
  local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
  return final_start + final_length
end

---------------------------------------------------------------------

function end_marker(selected_track, album_metadata, postgap, num_of_items, track_color)
  local final_item = GetTrackMediaItem(selected_track, num_of_items - 1)
  local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
  local final_end = final_start + final_length
  local catalog = ""

  local album_info = album_metadata .. catalog

  if not album_metadata:match("MESSAGE=") then
    album_info = album_info .. "|MESSAGE=Created with ReaClassical"
  end

  AddProjectMarker2(0, false, frame_check(final_end) + (postgap - 3), 0, album_info, 0, track_color)
  AddProjectMarker2(0, false, frame_check(final_end) + postgap, 0, "=END", 0, track_color)

  return (frame_check(final_end) + postgap) / 60
end

---------------------------------------------------------------------

function frame_check(pos)
  if digital_release_only then
    return pos -- No frame snapping for digital releases
  end

  local cd_fps = 75

  -- nearest CD frame
  local nearest_grid = math.floor(pos * cd_fps + 0.5) / cd_fps

  -- if pos isn't exactly on the grid, move back to previous frame
  if math.abs(pos - nearest_grid) > 1e-12 then
    nearest_grid = math.floor(pos * cd_fps) / cd_fps
  end

  return nearest_grid
end

---------------------------------------------------------------------

function delete_markers()
  delete_all_markers_and_regions()
  Main_OnCommand(40182, 0) -- select all items
  Main_OnCommand(42387, 0) -- Delete all take markers
  Main_OnCommand(40289, 0) -- Unselect all items
end

---------------------------------------------------------------------

function empty_items_check(selected_track, num_of_items)
  local count = 0
  for i = 0, num_of_items - 1, 1 do
    local current_item = GetTrackMediaItem(selected_track, i)
    local take = GetActiveTake(current_item)
    if not take then
      count = count + 1
    end
  end
  return count
end

---------------------------------------------------------------------

function return_custom_length()
  local pregap_len = 3
  local offset = 0.2
  local postgap = 7
  local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
  if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[2] then offset = table[2] / 1000 end
    if table[3] then pregap_len = table[3] end
    if table[4] then postgap = table[4] end
  end
  return pregap_len, offset, postgap
end

---------------------------------------------------------------------

function pos_check(item, selected_track)
  local item_number = GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
  local item_start_crossfaded = is_item_start_crossfaded(selected_track, item_number)
  local item_end_crossfaded = is_item_end_crossfaded(selected_track, item_number)
  return item_start_crossfaded, item_end_crossfaded
end

---------------------------------------------------------------------

function is_item_start_crossfaded(selected_track, item_number)
  local bool = false
  local item = GetTrackMediaItem(selected_track, item_number)
  local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
  local prev_item = GetTrackMediaItem(selected_track, item_number - 1)
  if prev_item then
    local prev_pos = GetMediaItemInfo_Value(prev_item, "D_POSITION")
    local prev_len = GetMediaItemInfo_Value(prev_item, "D_LENGTH")
    local prev_end = prev_pos + prev_len
    if prev_end > item_pos then
      bool = true
    end
  end
  return bool
end

---------------------------------------------------------------------

function is_item_end_crossfaded(selected_track, item_number)
  local bool = false
  local item = GetTrackMediaItem(selected_track, item_number)
  local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_pos + item_length
  local next_item = GetTrackMediaItem(selected_track, item_number + 1)
  if next_item then
    local next_pos = GetMediaItemInfo_Value(next_item, "D_POSITION")
    if next_pos < item_end then
      bool = true
    end
  end
  return bool
end

---------------------------------------------------------------------

function steps_by_length(length)
  if ((length * 10) < minimum_points) then
    return minimum_points
  else
    return length * 10
  end
end

---------------------------------------------------------------------
-- Thanks to user odedd for parts that involve converting fades to points
function generate_interpolated_fade(item_pos, env, start_time, end_time, shape, curvature, is_fade_in, sort)
  local fade_table = fade_equations()

  local take = Envelope_GetParentTake(env, 0, -1)
  local play_rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  start_time = start_time * play_rate
  end_time = end_time * play_rate
  if shape > 8 then shape = 1 end

  local length = end_time - start_time
  local steps = steps_by_length(length / play_rate)
  local is_scale = GetEnvelopeScalingMode(env)
  local safety_margin = 0.0000001 * play_rate

  local values = {}
  local times = {}

  -- interpolate fade curve with existing points
  if end_time > start_time then
    for i = 0, steps - 1 do
      local time = start_time + (i * (length / steps))
      local point_val = fade_table.fade_calc(shape, time, start_time, end_time, curvature, is_fade_in)

      local _, multiplier = Envelope_Evaluate(env, time, 44100, 128)
      multiplier = ScaleFromEnvelopeMode(is_scale, multiplier)

      local val = ScaleToEnvelopeMode(is_scale, point_val * multiplier)

      table.insert(values, val)
      table.insert(times, item_pos + time)
    end

    DeleteEnvelopePointRange(env, start_time, end_time + safety_margin)

    -- determine and insert last point
    local end_val = 0
    if is_fade_in then
      local _, value = Envelope_Evaluate(env, end_time, 44100, 128)
      end_val = ScaleFromEnvelopeMode(is_scale, value)
    end
    local val = ScaleToEnvelopeMode(is_scale, end_val)
    table.insert(values, val)
    table.insert(times, item_pos + end_time)

    if sort then Envelope_SortPoints(env) end

    -- reverse values against time to make crossfade
    local reversed_values = {}
    for i = #values, 1, -1 do
      table.insert(reversed_values, values[i])
    end

    for i = 1, #times do
      local point = {
        time = times[i],
        value = reversed_values[i]
      }
      table.insert(points, point)
    end
  end
end

---------------------------------------------------------------------

function convert_fades_to_env(item, selected_track)
  local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
  local fade_in_length = GetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO") ~= 0 and
      GetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO") or GetMediaItemInfo_Value(item, "D_FADEINLEN")
  local fade_out_length = GetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO") ~= 0 and
      GetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO") or GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
  local fade_in_curvature = GetMediaItemInfo_Value(item, "D_FADEINDIR")
  local fade_out_curvature = GetMediaItemInfo_Value(item, "D_FADEOUTDIR")
  local fade_in_shape = GetMediaItemInfo_Value(item, "C_FADEINSHAPE") + 1
  local fade_out_shape = GetMediaItemInfo_Value(item, "C_FADEOUTSHAPE") + 1
  local take = GetActiveTake(item)
  local env = GetTakeEnvelopeByName(take, "Volume")
  local brENV = BR_EnvAlloc(env, false)
  BR_EnvSetProperties(brENV, false, false, false, false, 0, 0, true)
  BR_EnvFree(brENV, true)
  local fade_in_start = 0
  local fade_out_start = item_length - fade_out_length

  local item_start_crossfaded, item_end_crossfaded = pos_check(item, selected_track)

  if fade_in_length > 0 and not item_start_crossfaded then
    -- create fade in if no overlap
    generate_interpolated_fade(item_pos, env, fade_in_start, fade_in_length, fade_in_shape, fade_in_curvature, true,
      false)
  end
  if fade_out_length > 0 and not item_end_crossfaded then
    -- create fade out if no overlap
    generate_interpolated_fade(item_pos, env, fade_out_start, item_length, fade_out_shape, fade_out_curvature, false,
      false)
  end
  Envelope_SortPoints(env)
end

---------------------------------------------------------------------
-- https://www.desmos.com/calculator/uhpwaovv3g
-- https://www.desmos.com/calculator/u5scukhlbg
-- Maths and graphs from forum member ess7
function fade_equations()
  local fade_table = {}

  fade_table.fade_calc = function(fade_type, time, start_time, end_time, curve, is_fade_in)
    if end_time <= start_time then return 1 end
    time = time < start_time and start_time or time > end_time and end_time or time

    local pos = (time - start_time) / (end_time - start_time)

    local fade_func = fade_table.fadein[fade_type]

    if not fade_func then
      MB("Error: Invalid fade_type:" .. fade_type, "RoomTone Automation", 0)
      return 0 -- Or some default behavior
    end

    return fade_table.fadein[fade_type](table.unpack(is_fade_in and { pos, curve } or { 1 - pos, -curve }))
  end

  fade_table.f1 = function(pos, curve)
    return curve < 0 and (1 + curve) * pos * (2 - pos) - curve * (1 - (1 - pos) ^ 8) ^ .5 or
        (1 - curve) * pos * (2 - pos) + curve * pos ^ 4
  end
  fade_table.f2 = function(pos, curve)
    return curve < 0 and (1 + curve) * pos - curve * (1 - (1 - pos) ^ 2) or
        (1 - curve) * pos + curve * pos ^ 2
  end
  fade_table.f3 = function(pos, curve)
    return curve < 0 and (1 + curve) * pos - curve * (1 - (1 - pos) ^ 4) or
        (1 - curve) * pos + curve * pos ^ 4
  end
  fade_table.f4a = function(pos, curve)
    return (curve * pos ^ 4) + (1 - curve) * (1 - (1 - pos) ^ 2 * (2 - math.pi / 4 - (1 - math.pi / 4) * (1 - pos) ^ 2))
  end
  fade_table.f4b = function(pos, curve)
    return (curve + 1) * (1 - pos ^ 2 * (2 - math.pi / 4 - (1 - math.pi / 4) * (pos ^ 2))) - curve * ((1 - pos) ^ 4)
  end
  fade_table.f4 = function(pos, curve)
    return curve < 0 and (1 - fade_table.f4b(pos, curve) ^ 2) ^ .5 or fade_table.f4a(pos, curve)
  end
  fade_table.warp1 = function(pos, time)
    return time == .5 and pos or
        ((pos * (1 - 2 * time) + time ^ 2) ^ .5 - time) / (1 - 2 * time)
  end
  fade_table.warp2 = function(pos, time)
    local g = fade_table.warp1(pos, time); return (2 * time - 1) * g ^ 2 + (2 - 2 * time) * g
  end

  fade_table.fadein = {
    function(pos, curve)
      curve = curve or 0
      return fade_table.f3(pos, curve)
    end,
    function(pos, curve)
      curve = curve or 0
      return fade_table.f1(pos, curve)
    end,
    function(pos, curve)
      curve = curve or 1
      return fade_table.f2(pos, curve)
    end,
    function(pos, curve)
      curve = curve or -1
      return fade_table.f3(pos, curve)
    end,
    function(pos, curve)
      curve = curve or 1
      return fade_table.f3(pos, curve)
    end,
    function(pos, curve)
      curve = curve or 0
      local x = fade_table.warp2(pos, .25 * (curve + 2))
      return (3 - 2 * x) * x ^ 2
    end,
    function(pos, curve)
      curve = curve or 0
      local x = fade_table.warp2(pos, (5 * curve + 8) / 16)
      return x <= .5 and 8 * x ^ 4 or 1 - 8 * (1 - x) ^ 4
    end,
    function(pos, curve)
      curve = curve or 0
      return fade_table.f4(pos, curve)
    end,
  }

  return fade_table
end

---------------------------------------------------------------------

function room_tone(project_length, selected_track)
  local num_of_selected_track_items = CountTrackMediaItems(selected_track)

  local rt_track
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    local ret, name = GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
    if ret and string.match(name, "^RoomTone") then
      rt_track = track
      break
    end
  end
  if not rt_track then
    return
  end
  Main_OnCommand(40769, 0) -- unselect all tracks, items etc

  for i = 0, num_of_selected_track_items - 1 do
    local item = GetTrackMediaItem(selected_track, i)
    SetMediaItemSelected(item, 1)
  end

  -- hacky way to activate item volume envelopes for function
  Main_OnCommand(40693, 0) -- setvolume envelope active
  Main_OnCommand(40693, 0) -- setvolume envelope inactive

  for i = 0, num_of_selected_track_items - 1 do
    local item = GetTrackMediaItem(selected_track, i)
    convert_fades_to_env(item, selected_track)
  end

  SetOnlyTrackSelected(rt_track)
  Main_OnCommand(41866, 0) -- show volume envelope
  Main_OnCommand(40332, 0) -- select all points
  Main_OnCommand(40333, 0) -- delete all points

  local rt_vol = GetTrackEnvelopeByName(rt_track, "Volume")
  local brRT = BR_EnvAlloc(rt_vol, false)
  BR_EnvSetProperties(brRT, true, true, true, true, 0, 0, true)
  BR_EnvFree(brRT, true)

  for _, val in pairs(points) do
    InsertEnvelopePoint(rt_vol, val.time, val.value, 0, 1, false, false)
  end

  add_roomtone_fadeout(rt_track, project_length)

  Main_OnCommand(40769, 0) -- unselect all tracks, items etc
end

---------------------------------------------------------------------

function add_roomtone_fadeout(rt_track, project_length)
  local rt_vol = GetTrackEnvelopeByName(rt_track, "Volume")
  if not rt_vol then
    rt_vol = GetTrackEnvelope(rt_track, 0)
  end

  local max_value = 716.21785031261

  local fade_start = project_length - 4.0 -- Start fade 4 seconds before =END marker
  local fade_end = fade_start + 2.0       -- 2-second fade-out duration

  local num_points = 10

  -- S-curve fade-out
  for i = 0, num_points do
    local t = i / num_points
    local time = fade_start + t * (fade_end - fade_start)
    local value = max_value * (1 - (t ^ 2 * (3 - 2 * t)))
    InsertEnvelopePoint(rt_vol, time, value, 0, 1, false, false)
  end

  Envelope_SortPoints(rt_vol)
end

---------------------------------------------------------------------

function check_saved_state()
  local full_project_name = GetProjectName(0)
  return full_project_name == ""
end

---------------------------------------------------------------------

function album_item_count(track)
  if not track then return 0 end

  local item_count = CountTrackMediaItems(track)
  if item_count == 0 then return 0 end

  local first_item = GetTrackMediaItem(track, 0)
  GetSetMediaItemInfo_String(first_item, "P_EXT:cdmarker", "", true)
  local count = 1
  local prev_item = GetTrackMediaItem(track, 0)
  local prev_end = GetMediaItemInfo_Value(prev_item, "D_POSITION") +
      GetMediaItemInfo_Value(prev_item, "D_LENGTH")

  for i = 1, item_count - 1 do
    local item = GetTrackMediaItem(track, i)
    GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", "", true)
    local start = GetMediaItemInfo_Value(item, "D_POSITION")

    if start - prev_end > 60 then -- More than 1 minute gap
      break
    end

    count = count + 1
    prev_end = start + GetMediaItemInfo_Value(item, "D_LENGTH")
  end

  return count
end

---------------------------------------------------------------------

function split_and_tag_final_item(track)
  if not track then return end

  local item_count = CountTrackMediaItems(track)
  if item_count == 0 then return end

  local last_item = nil
  local unnamed_item = nil
  local last_end = 0
  local gap_threshold = 60 -- seconds

  -- Loop through items to find last item and last unnamed take
  for i = 0, item_count - 1 do
    local item = GetTrackMediaItem(track, i)
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = pos + len

    -- Track the last item before a ≥1 min gap
    if pos - last_end >= gap_threshold then
      break
    end
    last_item = item
    last_end = item_end

    -- Check if item has a take without a name
    local take = GetActiveTake(item)
    if take then
      local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      if name == "" then
        unnamed_item = item
      end
    end
  end

  -- Prefer unnamed take if available
  local target_item = unnamed_item or last_item
  if not target_item then return false end

  local take = GetActiveTake(target_item)
  if not take then return false end

  -- If we have an unnamed take, just rename it (no split)
  local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  local item_name = "@MyAlbumTitle|COMPOSER=Various|PERFORMER=Various|MESSAGE=Created with ReaClassical"
  if name == "" then
    GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
    return item_name
  end

  -- Otherwise, split 1 second before end (fallback)
  local pos = GetMediaItemInfo_Value(target_item, "D_POSITION")
  local len = GetMediaItemInfo_Value(target_item, "D_LENGTH")
  local split_pos = pos + math.max(0, len - 1)

  SetEditCurPos(split_pos, false, false)

  Main_OnCommand(40289, 0) -- Unselect all items
  SetMediaItemSelected(target_item, true)
  Main_OnCommand(40012, 0) -- Split items at edit cursor

  -- Get the new item (the one after the split)
  local new_item = nil
  local new_item_count = CountTrackMediaItems(track)
  for i = 0, new_item_count - 1 do
    local item = GetTrackMediaItem(track, i)
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    if math.abs(item_pos - split_pos) < 0.0001 then
      new_item = item
      break
    end
  end

  if not new_item then return false end

  local new_take = GetActiveTake(new_item)
  if not new_take then return false end
  GetSetMediaItemTakeInfo_String(new_take, "P_NAME", item_name, true)

  return item_name
end

---------------------------------------------------------------------

function check_first_track_for_names(track)
  -- Get the selected track
  if not track then
    MB("No track found", "Error", 0)
    return false
  end

  -- Get number of items on the track
  local itemCount = CountTrackMediaItems(track)
  if itemCount == 0 then
    MB("No items on the first track", "Error", 0)
    return false
  end

  local prevEnd = nil

  -- Check each item for at least one take name that doesn't start with "@"
  for i = 0, itemCount - 1 do
    local item = GetTrackMediaItem(track, i)
    local itemStart = GetMediaItemInfo_Value(item, "D_POSITION")
    local itemEnd = itemStart + GetMediaItemInfo_Value(item, "D_LENGTH")

    -- Stop checking if gap to previous item >= 60 seconds
    if prevEnd and (itemStart - prevEnd) >= 60 then
      break
    end
    prevEnd = itemEnd

    local takeCount = CountTakes(item)
    for t = 0, takeCount - 1 do
      local take = GetMediaItemTake(item, t)
      if take then
        local takeName = GetTakeName(take)
        if takeName ~= "" and string.sub(takeName, 1, 1) ~= "@" then
          return true -- Found a valid take name
        end
      end
    end
  end

  -- If no valid takes found
  MB(
    "Please add take names to all items that you want to be CD track starts (Select item then press F2)",
    "No track markers created",
    0
  )
  return false
end

---------------------------------------------------------------------

function delete_all_markers_and_regions()
  RCMix_markers = {} -- reset storage

  local _, num_markers, num_regions = CountProjectMarkers(0)
  local total = num_markers + num_regions

  -- Iterate backwards by project index
  for i = total - 1, 0, -1 do
    local retval, is_region, pos, rgnend, name, markrgnindexnumber =
        EnumProjectMarkers(i)

    if retval then
      if name and name:match("^RCmix") then
        -- Store RCMix marker/region
        table.insert(RCMix_markers, {
          is_region = is_region,
          pos       = pos,
          rgnend    = rgnend,
          name      = name
        })
      end
      DeleteProjectMarker(0, markrgnindexnumber, is_region)
    end
  end
end

---------------------------------------------------------------------

function restore_RCMix()
  for _, m in ipairs(RCMix_markers) do
    AddProjectMarker2(
      0,             -- project
      m.is_region,   -- is region
      m.pos,         -- position
      m.rgnend or 0, -- region end (ignored for markers)
      m.name,        -- name
      -1,            -- auto index
      0              -- color (0 = default)
    )
  end
end

---------------------------------------------------------------------

function shift_folder_items_and_markers(parent_track, shift_amount)
  if not parent_track or shift_amount == 0 then return end

  local tracks_to_shift = { parent_track }
  local folder_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")

  -- Collect all tracks in folder (parent + children)
  if folder_depth == 1 then
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local depth = 1
    for i = parent_idx + 1, num_tracks - 1 do
      local tr = GetTrack(0, i)
      depth = depth + GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
      table.insert(tracks_to_shift, tr)
      if depth <= 0 then break end
    end
  end

  -- Collect all items in all tracks first
  local folder_items = {}
  for _, tr in ipairs(tracks_to_shift) do
    local num_items = CountTrackMediaItems(tr)
    for i = 0, num_items - 1 do
      table.insert(folder_items, GetTrackMediaItem(tr, i))
    end
  end

  -- Determine iteration order based on shift direction
  if shift_amount > 0 then
    -- Move forward: iterate from last to first
    for i = #folder_items, 1, -1 do
      local item = folder_items[i]
      local pos = GetMediaItemInfo_Value(item, "D_POSITION")
      SetMediaItemInfo_Value(item, "D_POSITION", pos + shift_amount)
    end
  else
    -- Move backward: iterate from first to last
    for i = 1, #folder_items do
      local item = folder_items[i]
      local pos = GetMediaItemInfo_Value(item, "D_POSITION")
      SetMediaItemInfo_Value(item, "D_POSITION", pos + shift_amount)
    end
  end
end

---------------------------------------------------------------------

function shift_all_markers_and_regions(shift_amount)
  if not shift_amount or shift_amount == 0 then return end

  local markers = {}
  local _, num_markers, num_regions = CountProjectMarkers(0)
  local total = num_markers + num_regions

  -- Collect all markers and regions
  for i = 0, total - 1 do
    local _, isrgn, pos, rgnend, name, idx = EnumProjectMarkers(i)
    markers[#markers + 1] = {
      isrgn = isrgn,
      pos = pos,
      rgnend = rgnend,
      name = name,
      idx = idx
    }
  end

  -- Delete all markers/regions by their true index
  for _, m in ipairs(markers) do
    DeleteProjectMarker(0, m.idx, m.isrgn)
  end

  -- Recreate markers/regions with shifted positions
  for _, m in ipairs(markers) do
    if m.isrgn then
      -- Region
      AddProjectMarker2(0, true, m.pos + shift_amount, m.rgnend + shift_amount, m.name, -1, 0, 0)
    else
      -- Marker
      AddProjectMarker2(0, false, m.pos + shift_amount, 0, m.name, -1, 0, 0)
    end
  end
end

---------------------------------------------------------------------

function remove_negative_position_items_from_folder(parent_track)
  if not parent_track then return 0 end

  local tracks_to_clean = { parent_track }
  local folder_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")

  -- Collect all tracks in folder
  if folder_depth == 1 then
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local depth = 1
    for i = parent_idx + 1, num_tracks - 1 do
      local tr = GetTrack(0, i)
      depth = depth + GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
      table.insert(tracks_to_clean, tr)
      if depth <= 0 then break end
    end
  end

  local removed_count = 0
  for _, track in ipairs(tracks_to_clean) do
    for j = CountTrackMediaItems(track) - 1, 0, -1 do
      local item = GetTrackMediaItem(track, j)
      local pos = GetMediaItemInfo_Value(item, "D_POSITION")
      if pos < 0 then
        DeleteTrackMediaItem(track, item)
        removed_count = removed_count + 1
      end
    end
  end

  return removed_count
end

---------------------------------------------------------------------

main()
