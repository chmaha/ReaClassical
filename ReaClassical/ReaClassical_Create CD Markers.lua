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

local main, get_info, cd_markers, find_current_start, create_marker
local renumber_markers, add_pregap, find_project_end, end_marker
local frame_check, save_metadata, save_codes, add_codes, delete_markers
local empty_items_check, return_custom_length, start_check
local fade_equations, pos_check, is_item_start_crossfaded, is_item_end_crossfaded
local steps_by_length, generate_interpolated_fade, convert_fades_to_env, room_tone, add_roomtone_fadeout
local check_saved_state, album_item_count

local minimum_points = 15
local points = {}

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
  MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
  return
end

function main()
  Undo_BeginBlock()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
    MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
    return
  end

  local not_saved = check_saved_state()
  if not_saved then
    MB("Please save your project before running this function.", "Create CD Markers", 0)
    return
  end

  local first_track = GetTrack(0, 0)
  local num_of_items = 0
  if first_track then num_of_items = album_item_count() end
  if not first_track or num_of_items == 0 then
    MB("Error: No media items found.", "Create CD Markers", 0)
    return
  end
  local empty_count = empty_items_check(first_track, num_of_items)
  if empty_count > 0 then
    MB("Error: Empty items found on first track. Delete them to continue.", "Create CD Markers", 0)
    return
  end

  local _, ddp_run = GetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?")
  local use_existing = false
  if ddp_run ~= "" then
    local saved_values_response = MB("Would you like to use the existing saved values?", "Create CD Markers", 4)
    if saved_values_response == 6 then
      use_existing = true
    end
  end
  SetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?", "yes")
  local redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length = cd_markers(first_track,
    num_of_items, use_existing)
  if redbook_track_length_errors == -1 then return end
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
  room_tone(redbook_project_length * 60)
  renumber_markers()
  PreventUIRefresh(-1)
  local create_cue = NamedCommandLookup("_RSa012bb075440de1ce27f06b6e12b88877848ca5b")
  Main_OnCommand(create_cue, 0)

  Undo_EndBlock("Create CD/DDP Markers", -1)
end

---------------------------------------------------------------------

function get_info(use_existing)
  local _, metadata_saved = GetProjExtState(0, "ReaClassical", "AlbumMetadata")
  local ret, user_inputs
  local metadata_table = {}
  if use_existing and metadata_saved ~= "" then
    for entry in metadata_saved:gmatch('([^,]+)') do metadata_table[#metadata_table + 1] = entry end
  else
    repeat
      if metadata_saved ~= "" then
        ret, user_inputs = GetUserInputs('CD/DDP Album information', 4,
          'Album Title,Performer,Composer,Genre,extrawidth=100',
          metadata_saved)
      else
        ret, user_inputs = GetUserInputs('CD/DDP Album information', 4,
          'Album Title,Performer,Composer,Genre,extrawidth=100',
          'My Classical Album,Performer,Composer,Classical')
      end
      for entry in user_inputs:gmatch('([^,]+)') do metadata_table[#metadata_table + 1] = entry end
      if #metadata_table ~= 4 and ret then
        MB("Please complete all four metadata entries", "Add Album Metadata", 0)
      end
    until not ret or (#metadata_table == 4)
  end
  return user_inputs, metadata_table
end

---------------------------------------------------------------------

function cd_markers(first_track, num_of_items, use_existing)
  delete_markers()

  SNM_SetIntConfigVar('projfrbase', 75)
  Main_OnCommand(40754, 0) --enable snap to grid

  local upc_ret, isrc_ret, upc_input, isrc_input, code_table = add_codes(use_existing)
  if upc_ret and not use_existing then save_codes("UPC", upc_input) end
  if isrc_ret and not use_existing then save_codes("ISRC", isrc_input) end
  local pregap_len, offset, postgap = return_custom_length()

  start_check(first_track, offset) -- move items to right if not enough room for first offset

  if tonumber(pregap_len) < 1 then pregap_len = 1 end
  local final_end = find_project_end(first_track, num_of_items)
  local previous_start
  local redbook_track_length_errors = 0
  local redbook_total_tracks_error = false
  local previous_takename
  local marker_count = 0
  for i = 0, num_of_items - 1, 1 do
    local current_start, take_name = find_current_start(first_track, i)
    local added_marker = create_marker(current_start, marker_count, take_name, isrc_ret, code_table, offset)
    if added_marker then
      if take_name:match("^!") and marker_count > 0 then
        AddProjectMarker(0, false, frame_check(current_start - (pregap_len + offset)), 0, "!", marker_count)
      end
      if marker_count > 0 then
        if current_start - previous_start < 4 then
          redbook_track_length_errors = redbook_track_length_errors + 1
        end
        AddProjectMarker(0, true, frame_check(previous_start - offset), frame_check(current_start - offset),
          previous_takename:match("^[!]*(.+)"),
          marker_count)
      end
      previous_start = current_start
      previous_takename = take_name
      marker_count = marker_count + 1
    end
  end
  if marker_count == 0 then
    MB('Please add take names to all items that you want to be CD track starts (Select item then press F2)',
      "No track markers created", 0)
    return -1
  end
  if marker_count > 99 then
    redbook_total_tracks_error = true
  end
  AddProjectMarker(0, true, frame_check(previous_start - offset), frame_check(final_end) + postgap,
    previous_takename:match("^[!]*(.+)"),
    marker_count)
  local redbook_project_length
  if marker_count ~= 0 then
    local user_inputs, metadata_table = get_info(use_existing)
    if #metadata_table == 4 and not use_existing then save_metadata(user_inputs) end
    add_pregap(first_track)
    redbook_project_length = end_marker(first_track, metadata_table, upc_ret, code_table, postgap, num_of_items)
  end
  Main_OnCommand(40753, 0) -- Snapping: Disable snap
  return redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length
end

---------------------------------------------------------------------

function find_current_start(first_track, i)
  local current_item = GetTrackMediaItem(first_track, i)
  local take = GetActiveTake(current_item)
  local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  return GetMediaItemInfo_Value(current_item, "D_POSITION"), take_name
end

---------------------------------------------------------------------

function create_marker(current_start, marker_count, take_name, isrc_ret, code_table, offset)
  local added_marker = false
  local track_title
  if take_name ~= "" then
    local corrected_current_start = frame_check(current_start - offset)
    if #code_table == 5 and isrc_ret then
      track_title = "#" ..
          take_name:match("^[!]*(.+)") ..
          "|ISRC=" ..
          code_table[2] .. code_table[3] .. code_table[4] .. string.format("%05d", code_table[5] + marker_count)
    else
      track_title = "#" .. take_name:match("^[!]*(.+)")
    end
    AddProjectMarker(0, false, corrected_current_start, 0, track_title, marker_count + 1)
    added_marker = true
  end
  return added_marker
end

---------------------------------------------------------------------

function renumber_markers()
  local num_markers, num_regions = CountProjectMarkers(0)
  local marker_idx = 0

  for i = 0, num_markers + num_regions - 1 do
    local _, isrgn, pos, rgnend, name = EnumProjectMarkers(i)
    if not isrgn then
      SetProjectMarkerByIndex(0, i, isrgn, pos, rgnend, marker_idx, name, 0)
      marker_idx = marker_idx + 1
    end
  end
end

---------------------------------------------------------------------

function add_pregap(first_track)
  local first_item_start, _ = find_current_start(first_track, 0)
  local _, _, first_marker, _, _, _ = EnumProjectMarkers(0)
  local first_pregap
  if first_marker - first_item_start < 2 then
    first_pregap = first_item_start - 2 +
        (first_marker - first_item_start) -- Ensure initial pre-gap is at least 2 seconds in length
  else
    first_pregap = first_item_start
  end
  if first_pregap > 0 then
    GetSet_LoopTimeRange(true, false, 0, first_pregap, false)
    Main_OnCommand(40201, 0) -- Time selection: Remove contents of time selection (moving later items)
  elseif first_pregap < 0 then
    GetSet_LoopTimeRange(true, false, 0, 0 - first_pregap, false)
    Main_OnCommand(40200, 0) -- Time selection: Insert empty space at time selection (moving later items)
    GetSet_LoopTimeRange(true, false, 0, 0, false)
  end
  AddProjectMarker(0, false, 0, 0, "!", 0)
  SNM_SetDoubleConfigVar('projtimeoffs', 0)
end

---------------------------------------------------------------------

function find_project_end(first_track, num_of_items)
  local final_item = GetTrackMediaItem(first_track, num_of_items - 1)
  local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
  return final_start + final_length
end

---------------------------------------------------------------------

function end_marker(first_track, metadata_table, upc_ret, code_table, postgap, num_of_items)
  local final_item = GetTrackMediaItem(first_track, num_of_items - 1)
  local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
  local final_end = final_start + final_length
  local catalog = ""
  if #metadata_table == 4 and upc_ret then
    if code_table[1] ~= "" then
      catalog = "|CATALOG=" .. code_table[1]
    end
    local album_info = "@" ..
        metadata_table[1] ..
        catalog .. "|PERFORMER=" .. metadata_table[2] .. "|COMPOSER=" .. metadata_table[3] ..
        "|GENRE=" .. metadata_table[4] .. "|MESSAGE=Created with ReaClassical"
    AddProjectMarker(0, false, frame_check(final_end) + (postgap - 3), 0, album_info, 0)
  elseif #metadata_table == 4 then
    local album_info = "@" ..
        metadata_table[1] .. "|PERFORMER=" .. metadata_table[2] .. "|COMPOSER=" .. metadata_table[3] ..
        "|GENRE=" .. metadata_table[4] .. "|MESSAGE=Created with ReaClassical"
    AddProjectMarker(0, false, frame_check(final_end) + (postgap - 3), 0, album_info, 0)
  end
  AddProjectMarker(0, false, frame_check(final_end) + postgap, 0, "=END", 0)
  return (frame_check(final_end) + postgap) / 60
end

---------------------------------------------------------------------

function frame_check(pos)
  local nearest_grid = BR_GetClosestGridDivision(pos)
  if pos ~= nearest_grid then
    pos = BR_GetPrevGridDivision(pos)
  end
  return pos
end

---------------------------------------------------------------------

function save_metadata(user_inputs)
  SetProjExtState(0, "ReaClassical", "AlbumMetadata", user_inputs)
end

---------------------------------------------------------------------

function save_codes(type, input)
  SetProjExtState(0, "ReaClassical", type, input)
end

---------------------------------------------------------------------

function add_codes(use_existing)
  local _, upc_saved = GetProjExtState(0, "ReaClassical", "UPC")
  local _, isrc_saved = GetProjExtState(0, "ReaClassical", "ISRC")
  local upc_ret
  local isrc_ret
  local upc_input = ""
  local isrc_input = ""
  local code_table = { "", "", "", "", "" }

  if use_existing and upc_saved ~= "" then
    code_table[1] = upc_saved
    upc_ret = true
  else
    local codes_response1 = MB("Add UPC or EAN?", "CD codes", 4)
    if codes_response1 == 6 then
      repeat
        if upc_saved ~= "" then
          upc_ret, upc_input = GetUserInputs('UPC/EAN', 1,
            'UPC or EAN,extrawidth=100', upc_saved)
        else
          upc_ret, upc_input = GetUserInputs('UPC/EAN', 1,
            'UPC or EAN,extrawidth=100', '')
        end

        if not upc_input:match('^%d+$') or (#upc_input ~= 12 and #upc_input ~= 13) then
          MB('UPC = 12-digit number; EAN = 13-digit number.', "Invalid UPC", 0)
        end
      until ((upc_input:match('^%d+$') and (#upc_input == 12 or #upc_input == 13))) or not upc_ret

      if upc_ret then code_table[1] = upc_input end
    end
  end

  if use_existing and isrc_saved ~= "" then
    isrc_ret = true
    local i = 2
    for entry in isrc_saved:gmatch('([^,]+)') do
      code_table[i] = entry
      i = i + 1
    end
  else
    local codes_response2 = MB("Add ISRC?", "CD codes", 4)
    if codes_response2 == 6 then
      repeat
        if isrc_saved ~= "" then
          isrc_ret, isrc_input = GetUserInputs('ISRC', 4,
            'ISRC Country Code,ISRC Registrant Code,ISRC Year (YY),' ..
            'ISRC Designation Code,extrawidth=100', isrc_saved)
        else
          isrc_ret, isrc_input = GetUserInputs('ISRC', 4,
            'ISRC Country Code,ISRC Registrant Code,ISRC Year (YY),' ..
            'ISRC Designation Code,extrawidth=100', '')
        end

        local isrc_entries = {}
        for entry in isrc_input:gmatch('([^,]+)') do
          isrc_entries[#isrc_entries + 1] = entry
        end

        if #isrc_entries == 4 then
          local country_code = isrc_entries[1]
          local registrant_code = isrc_entries[2]
          local year = isrc_entries[3]
          local designation_code = isrc_entries[4]

          if not country_code:match('^[A-Z][A-Z]$') then
            MB('ISRC Country Code must be 2 uppercase letters.', "Invalid ISRC", 0)
          elseif not registrant_code:match('^[A-Z0-9][A-Z0-9][A-Z0-9]$') then
            MB('ISRC Registrant Code must be 3 alphanumeric characters.', "Invalid ISRC", 0)
          elseif not year:match('^%d%d$') then
            MB('ISRC Year must be 2 digits.', "Invalid ISRC", 0)
          elseif not (designation_code:match("^(%d+)$") and #designation_code <= 5) then
            MB('ISRC Designation Code must be up to 5 digits.', "Invalid ISRC", 0)
          else
            break
          end
        else
          MB('You must provide all 4 ISRC components.', "Invalid ISRC", 0)
        end
        isrc_input = ""
      until not isrc_ret

      local j = 2
      if isrc_ret then
        for entry in isrc_input:gmatch('([^,]+)') do
          code_table[j] = entry
          j = j + 1
        end
      elseif #code_table ~= 5 then
        MB('Empty code metadata_table not supported: Not adding ISRC codes', "Warning",
          0)
      end
    end
  end
  return upc_ret, isrc_ret, upc_input, isrc_input, code_table
end

---------------------------------------------------------------------

function delete_markers()
  local delete_all_markers = NamedCommandLookup("_SWSMARKERLIST9")
  Main_OnCommand(delete_all_markers, 0)
  local delete_regions = NamedCommandLookup("_SWSMARKERLIST10")
  Main_OnCommand(delete_regions, 0)
  Main_OnCommand(40182, 0) -- select all items
  Main_OnCommand(42387, 0) -- Delete all take markers
  Main_OnCommand(40289, 0) -- Unselect all items
end

---------------------------------------------------------------------

function empty_items_check(first_track, num_of_items)
  local count = 0
  for i = 0, num_of_items - 1, 1 do
    local current_item = GetTrackMediaItem(first_track, i)
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

function start_check(first_track, offset)
  local first_item = GetTrackMediaItem(first_track, 0)
  local position = GetMediaItemInfo_Value(first_item, "D_POSITION")
  if position < offset then
    GetSet_LoopTimeRange(true, false, 0, offset - position, false)
    Main_OnCommand(40200, 0) -- insert time at time selection
    Main_OnCommand(40635, 0) -- remove time selection
  end
end

---------------------------------------------------------------------

function pos_check(item)
  local first_track = GetTrack(0, 0)
  local item_number = GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
  local item_start_crossfaded = is_item_start_crossfaded(first_track, item_number)
  local item_end_crossfaded = is_item_end_crossfaded(first_track, item_number)
  return item_start_crossfaded, item_end_crossfaded
end

---------------------------------------------------------------------

function is_item_start_crossfaded(first_track, item_number)
  local bool = false
  local item = GetTrackMediaItem(first_track, item_number)
  local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
  local prev_item = GetTrackMediaItem(first_track, item_number - 1)
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

function is_item_end_crossfaded(first_track, item_number)
  local bool = false
  local item = GetTrackMediaItem(first_track, item_number)
  local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
  local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_pos + item_length
  local next_item = GetTrackMediaItem(first_track, item_number + 1)
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

function convert_fades_to_env(item)
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

  local item_start_crossfaded, item_end_crossfaded = pos_check(item)

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

function room_tone(project_length)
  local first_track = GetTrack(0, 0)
  local num_of_first_track_items = CountTrackMediaItems(first_track)

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

  for i = 0, num_of_first_track_items - 1 do
    local item = GetTrackMediaItem(first_track, i)
    SetMediaItemSelected(item, 1)
  end

  -- hacky way to activate item volume envelopes for function
  Main_OnCommand(40693, 0) -- setvolume envelope active
  Main_OnCommand(40693, 0) -- setvolume envelope inactive

  for i = 0, num_of_first_track_items - 1 do
    local item = GetTrackMediaItem(first_track, i)
    convert_fades_to_env(item)
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

function album_item_count()
  local track = reaper.GetTrack(0, 0)
  if not track then return 0 end

  local item_count = reaper.CountTrackMediaItems(track)
  if item_count == 0 then return 0 end

  local count = 1
  local prev_item = reaper.GetTrackMediaItem(track, 0)
  local prev_end = reaper.GetMediaItemInfo_Value(prev_item, "D_POSITION") +
      reaper.GetMediaItemInfo_Value(prev_item, "D_LENGTH")

  for i = 1, item_count - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    if start - prev_end > 60 then   -- More than 1 minute gap
      break
    end

    count = count + 1
    prev_end = start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  end

  return count
end

---------------------------------------------------------------------

main()
