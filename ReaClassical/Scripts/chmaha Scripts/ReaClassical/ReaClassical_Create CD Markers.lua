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
local frame_check, save_codes, add_codes, delete_markers
local empty_items_check, return_custom_length, start_check
local fade_equations, pos_check, is_item_start_crossfaded, is_item_end_crossfaded
local steps_by_length, generate_interpolated_fade, convert_fades_to_env, room_tone
local add_roomtone_fadeout, check_saved_state, album_item_count

local count_markers, create_filename, create_cue_entries, create_string
local ext_mod, save_file, format_time, parse_cue_file, import_sony_metadata
local create_plaintext_report, create_html_report, any_isrc_present
local time_to_mmssff, subtract_time_strings, add_pregaps_to_table
local formatted_pos_out, parse_markers, checksum, get_txt_file
local create_metadata_report_and_file, split_and_tag_final_item
local check_first_track_for_names, delete_all_markers_and_regions

local minimum_points = 15
local points = {}

---------------------------------------------------------------------

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

  local names_on_first_track = check_first_track_for_names()
  if not names_on_first_track then return end

  local metadata_file = get_txt_file()
  local f = io.open(metadata_file, "r")
  if f then
    local _, stored_checksum = GetProjExtState(0, "ReaClassical", "MetadataChecksum")
    stored_checksum = tonumber(stored_checksum) or 0
    local new_checksum = tonumber(checksum(metadata_file))
    f:close()
    if stored_checksum == 0 then
      SetProjExtState(0, "ReaClassical", "MetadataChecksum", new_checksum)
    end
    if stored_checksum ~= new_checksum then
      local metadata_choice = MB(
        "Change detected in metadata.txt. Would you like to update the project with the new values?",
        "Metadata Change Detected", 4)
      if metadata_choice == 6 then
        local success = import_sony_metadata(metadata_file)
        if not success then
          MB("Error importing new metadata. Using old values…", "Metadata Import Error", 0)
        end
      end
    end
  end

  local _, ddp_run = GetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?")
  local use_existing = false
  if ddp_run ~= "" then
    local saved_values_response = MB("Would you like to use the existing saved values for UPC/ISRC?",
      "Create CD Markers", 4)
    if saved_values_response == 6 then
      use_existing = true
    end
  end

  SetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?", "yes")
  local success, redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length = cd_markers(
    first_track,
    num_of_items, use_existing)
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
  room_tone(redbook_project_length * 60)
  renumber_markers()
  PreventUIRefresh(-1)

  PreventUIRefresh(1)
  local ret1, num_of_markers = count_markers()
  if not ret1 then return end
  local ret2, filename = create_filename()
  if not ret2 then return end
  local fields, extension, production_year = create_cue_entries(filename)

  local string, catalog_number, album_length = create_string(fields, num_of_markers, extension)
  local path, slash, cue_file = save_file(fields, string)

  local txtOutputPath = path .. slash .. 'album_report.txt'
  local HTMLOutputPath = path .. slash .. 'album_report.html'
  local albumTitle, albumPerformer, tracks = parse_cue_file(cue_file, album_length, num_of_markers)
  if albumTitle and albumPerformer and #tracks > 0 then
    create_plaintext_report(albumTitle, albumPerformer, tracks, txtOutputPath, album_length, catalog_number,
      production_year)
    create_html_report(albumTitle, albumPerformer, tracks, HTMLOutputPath, album_length, catalog_number,
      production_year)
  end


  MB("DDP Markers and regions have been successfully added to the project.\n\n" ..
    "Create the DDP fileset, matching audio for the generated CUE,\n" ..
    "and/or individual files via the ReaClassical 'All Settings' presets\nin the Render dialog.\n\n" ..
    "The album reports and CUE file have been written to:\n" .. path, "Create CD Markers", 0)
  PreventUIRefresh(-1)

  create_metadata_report_and_file()

  Undo_EndBlock("Create CD/DDP Markers", -1)
end

---------------------------------------------------------------------

function get_info()
  local track = GetTrack(0, 0) -- Get first track
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

function cd_markers(first_track, num_of_items, use_existing)
  local album_metadata = get_info()
  if not album_metadata then
    album_metadata = split_and_tag_final_item()
    MB("No album metadata found.\n" ..
      "Added generic album metadata to end of album:\n" ..
      "You can open metadata.txt to edit…", "Create CD Markers", 0)
  end

  delete_markers()

  SNM_SetIntConfigVar('projfrbase', 75)
  Main_OnCommand(40904, 0) -- set grid to frames
  Main_OnCommand(40754, 0) -- enable snap to grid

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
    if not take_name:match("^@") then
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
            previous_takename:match("^[!]*([^|]*)"),
            marker_count)
        end
        previous_start = current_start
        previous_takename = take_name
        marker_count = marker_count + 1
      end
    end
  end
  if marker_count == 0 then
    -- MB('Please add take names to all items that you want to be CD track starts (Select item then press F2)',
    --   "No track markers created", 0)
    return false
  end
  if marker_count > 99 then
    redbook_total_tracks_error = true
  end
  AddProjectMarker(0, true, frame_check(previous_start - offset), frame_check(final_end) + postgap,
    previous_takename:match("^[!]*([^|]*)"),
    marker_count)
  local redbook_project_length
  if marker_count ~= 0 then
    add_pregap(first_track)
    redbook_project_length = end_marker(first_track, album_metadata, postgap, num_of_items, upc_ret, code_table)
  end
  Main_OnCommand(40753, 0) -- Snapping: Disable snap
  return true, redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length
end

---------------------------------------------------------------------

function find_current_start(first_track, i)
  local current_item = GetTrackMediaItem(first_track, i)
  local take = GetActiveTake(current_item)
  local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  take_name = take_name:gsub("|$", "")
  GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name, true)
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

function end_marker(first_track, album_metadata, postgap, num_of_items, upc_ret, code_table)
  local final_item = GetTrackMediaItem(first_track, num_of_items - 1)
  local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
  local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
  local final_end = final_start + final_length
  local catalog = ""
  if upc_ret and code_table[1] ~= "" then
    catalog = "|CATALOG=" .. code_table[1]
  end

  local album_info = album_metadata .. catalog

  if not album_metadata:match("MESSAGE=") then
    album_info = album_info .. "|MESSAGE=Created with ReaClassical"
  end

  AddProjectMarker(0, false, frame_check(final_end) + (postgap - 3), 0, album_info, 0)
  AddProjectMarker(0, false, frame_check(final_end) + postgap, 0, "=END", 0)

  return (frame_check(final_end) + postgap) / 60
end

---------------------------------------------------------------------

function frame_check(pos)
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
  delete_all_markers_and_regions()
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
  local track = GetTrack(0, 0)
  if not track then return 0 end

  local item_count = CountTrackMediaItems(track)
  if item_count == 0 then return 0 end

  local count = 1
  local prev_item = GetTrackMediaItem(track, 0)
  local prev_end = GetMediaItemInfo_Value(prev_item, "D_POSITION") +
      GetMediaItemInfo_Value(prev_item, "D_LENGTH")

  for i = 1, item_count - 1 do
    local item = GetTrackMediaItem(track, i)
    local start = GetMediaItemInfo_Value(item, "D_POSITION")

    if start - prev_end > 60 then -- More than 1 minute gap
      break
    end

    count = count + 1
    prev_end = start + GetMediaItemInfo_Value(item, "D_LENGTH")
  end

  return count
end

----------------------------------------------------------

function count_markers()
  local num_of_markers = CountProjectMarkers(0)
  if num_of_markers == 0 then
    MB('Please use "Create CD Markers script" first', "Create CUE file", 0)
    return false
  end
  return true, num_of_markers
end

----------------------------------------------------------

function create_filename()
  local full_project_name = GetProjectName(0)
  if full_project_name == "" then
    MB("Please save your project first!", "Create CUE file", 0)
    return false
  else
    return true, full_project_name:match("^(.+)[.].*$")
  end
end

----------------------------------------------------------

function create_cue_entries(filename)
  local year = tonumber(os.date("%Y"))
  local extension = "wav"

  local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
  if input ~= "" then
    local prefs_table = {}
    for entry in input:gmatch('([^,]+)') do prefs_table[#table + 1] = entry end
    if prefs_table[10] then year = tonumber(prefs_table[10]) end
    if prefs_table[11] then extension = tostring(prefs_table[11]) end
  end

  local album_metadata = parse_markers()

  if album_metadata.genre == nil then album_metadata.genre = "Unknown" end
  if album_metadata.performer == nil then album_metadata.performer = "Unknown" end
  if album_metadata.title == nil then album_metadata.title = "Unknown" end

  local fields = {
    album_metadata.genre,
    year,
    album_metadata.performer,
    album_metadata.title,
    filename .. '.' .. extension
  }

  return fields, extension:upper(), year
end

----------------------------------------------------------

function create_string(fields, num_of_markers, extension)
  local format = ext_mod(extension)

  local _, _, album_pos_out, _, _ = EnumProjectMarkers2(0, num_of_markers - 1)
  local album_length = format_time(album_pos_out)
  local _, _, _, _, album_meta = EnumProjectMarkers2(0, num_of_markers - 2)
  local catalog_number = album_meta:match('CATALOG=([%w%d]+)') or ""
  local out_str

  if catalog_number ~= "" then
    out_str =
        'REM COMMENT "Generated by ReaClassical"' ..
        '\nREM GENRE ' .. fields[1] ..
        '\nREM DATE ' .. fields[2] ..
        '\nREM ALBUM_LENGTH ' .. album_length ..
        '\nCATALOG ' .. catalog_number ..
        '\nPERFORMER ' .. '"' .. fields[3] .. '"' ..
        '\nTITLE ' .. '"' .. fields[4] .. '"' ..
        '\nFILE ' .. '"' .. fields[5] .. '"' .. ' ' .. format .. '\n'
  else
    out_str =
        'REM COMMENT "Generated by ReaClassical"' ..
        '\nREM GENRE ' .. fields[1] ..
        '\nREM DATE ' .. fields[2] ..
        '\nREM ALBUM_LENGTH ' .. album_length ..
        '\nPERFORMER ' .. '"' .. fields[3] .. '"' ..
        '\nTITLE ' .. '"' .. fields[4] .. '"' ..
        '\nFILE ' .. '"' .. fields[5] .. '"' .. ' ' .. format .. '\n'
  end

  local ind3 = '   '
  local ind5 = '     '

  local marker_id = 1
  local is_pregap = false
  local pregap_start = ""
  for i = 0, num_of_markers - 1 do
    local _, _, raw_pos_out, _, name_out = EnumProjectMarkers2(0, i)
    if name_out:find("^#") then
      local perf = name_out:match("PERFORMER=([^|]+)")
      local isrc_code = name_out:match('ISRC=([%w%d]+)') or ""
      name_out = name_out:match("^#([^|]+)")
      local formatted_time = format_time(raw_pos_out)

      if not perf then perf = fields[3] end

      local id = ("%02d"):format(marker_id)
      marker_id = marker_id + 1
      if name_out == nil or name_out == '' then name_out = 'Untitled' end

      if isrc_code ~= "" then
        out_str = out_str .. ind3 .. 'TRACK ' .. id .. ' AUDIO' .. '\n' ..
            ind5 .. 'TITLE ' .. '"' .. name_out .. '"' .. '\n' ..
            ind5 .. 'PERFORMER ' .. '"' .. perf .. '"' .. '\n' ..
            ind5 .. 'ISRC ' .. isrc_code .. '\n'
        if is_pregap then
          out_str = out_str .. ind5 .. 'INDEX 00 ' .. pregap_start .. '\n'
          is_pregap = false
        end
        out_str = out_str .. ind5 .. 'INDEX 01 ' .. formatted_time .. '\n'
      else
        out_str = out_str .. ind3 .. 'TRACK ' .. id .. ' AUDIO' .. '\n' ..
            ind5 .. 'TITLE ' .. '"' .. name_out .. '"' .. '\n' ..
            ind5 .. 'PERFORMER ' .. '"' .. perf .. '"' .. '\n'
        if is_pregap then
          out_str = out_str .. ind5 .. 'INDEX 00 ' .. pregap_start .. '\n'
          is_pregap = false
        end
        out_str = out_str .. ind5 .. 'INDEX 01 ' .. formatted_time .. '\n'
      end
    elseif name_out:find("^!") then
      is_pregap = true
      pregap_start = format_time(raw_pos_out)
    end
  end

  return out_str, catalog_number, album_length
end

----------------------------------------------------------

function ext_mod(extension)
  local list = { "AIFF", "MP3" }
  for _, v in pairs(list) do
    if extension == v then
      return extension
    end
  end
  return "WAVE"
end

----------------------------------------------------------

function save_file(fields, out_str)
  local _, path = EnumProjects(-1)
  local slash = package.config:sub(1, 1)
  if path == "" then
    path = GetProjectPath()
  else
    local pattern = "(.+)" .. slash .. ".+[.][Rr][Pp][Pp]"
    path = path:match(pattern)
  end
  local file = path .. slash .. fields[5]:match('^(.+)[.].+') .. '.cue'
  local f = io.open(file, 'w')
  if f then
    f:write(out_str)
    f:close()
  else
    MB(
      "There was an error creating the file. " ..
      "Copy and paste the contents of the following console window to a new .cue file.",
      "Create CUE file", 0)
    ShowConsoleMsg(out_str)
  end
  return path, slash, file
end

----------------------------------------------------------

function format_time(pos_out)
  pos_out = format_timestr_pos(pos_out, '', 5)
  local time = {}
  for num in pos_out:gmatch('[%d]+') do
    if tonumber(num) > 10 then num = tonumber(num) end
    time[#time + 1] = num
  end
  if tonumber(time[1]) > 0 then time[2] = tonumber(time[2]) + tonumber(time[1]) * 60 end
  return table.concat(time, ':', 2)
end

-----------------------------------------------------------------

function parse_cue_file(cueFilePath, albumLength, num_of_markers)
  local file = io.open(cueFilePath, "r")

  if not file then
    return
  end

  local albumTitle, albumPerformer
  local tracks = {}

  local currentTrack = {}

  for line in file:lines() do
    if line:find("^TITLE") then
      albumTitle = line:match('"([^"]+)"')
    elseif line:find("^PERFORMER") then
      albumPerformer = line:match('"([^"]+)"')
    elseif line:find("^%s+TRACK") then
      currentTrack = {
        number = tonumber(line:match("(%d+)")),
      }
    elseif line:find("^%s+PERFORMER") then
      currentTrack.performer = line:match('"([^"]+)"')
    elseif line:find("^%s+TITLE") then
      currentTrack.title = line:match('"([^"]+)"')
    elseif line:find("^%s+ISRC") then
      currentTrack.isrc = line:match("ISRC%s+(%S+)")
    elseif line:find("^%s+INDEX 01") then
      local mm, ss, ff = line:match("(%d+):(%d+):(%d+)")
      currentTrack.mm = tonumber(mm)
      currentTrack.ss = tonumber(ss)
      currentTrack.ff = tonumber(ff)
      table.insert(tracks, currentTrack)
    end
  end

  file:close()

  tracks = add_pregaps_to_table(tracks, num_of_markers)

  table.sort(tracks, function(a, b)
    return (a.mm * 60 + a.ss + a.ff / 75) < (b.mm * 60 + b.ss + b.ff / 75)
  end)


  for i = 2, #tracks do
    local secondTimeString = string.format("%02d:%02d:%02d", tracks[i].mm, tracks[i].ss, tracks[i].ff)
    local firstTimeString = string.format("%02d:%02d:%02d", tracks[i - 1].mm, tracks[i - 1].ss, tracks[i - 1].ff)
    tracks[i - 1].length = subtract_time_strings(secondTimeString, firstTimeString)
  end

  -- Deal with final track length based on album length
  local firstTimeString = string.format("%02d:%02d:%02d", tracks[#tracks].mm, tracks[#tracks].ss, tracks[#tracks].ff)
  tracks[#tracks].length = subtract_time_strings(albumLength, firstTimeString)

  return albumTitle, albumPerformer, tracks
end

-----------------------------------------------------------------

function create_plaintext_report(albumTitle, albumPerformer, tracks, txtOutputPath, albumLength, catalog_number,
                                 production_year)
  local file = io.open(txtOutputPath, "w")

  if not file then
    return
  end

  local date = os.date("*t")
  local hour = date.hour % 12
  hour = hour == 0 and 12 or hour
  local ampm = date.hour >= 12 and "PM" or "AM"
  local formattedDate = string.format("%d/%02d/%d %d:%02d%s", date.day, date.month, date.year, hour, date.min, ampm)
  file:write("Generated by ReaClassical (" .. formattedDate .. ")\n\n")
  file:write("Album: ", (albumTitle or "") .. "\n")
  file:write("Year: ", (production_year or "") .. "\n")
  file:write("Album Performer: ", (albumPerformer or "") .. "\n")

  if catalog_number ~= "" then
    file:write("UPC/EAN: ", (catalog_number or "") .. "\n\n")
  else
    file:write("\n")
  end

  file:write("-----------------------------\n")
  file:write("Total Running Time: " .. albumLength .. "\n")
  file:write("-----------------------------\n\n")

  for _, track in ipairs(tracks or {}) do
    local isrcSeparator = track.isrc and " | " or ""

    track.number = track.title == "pregap" and "p" or string.format("%02d", track.number or 0)
    track.title = track.title == "pregap" and "" or track.title

    track.title = track.title:match("^[!]*([^|]*)")

    if track.title == "" then
      file:write(string.format("%-2s | %02d:%02d:%02d | %s |\n",
        track.number or "", track.mm or 0, track.ss or 0, track.ff or 0, track.length))
    else
      file:write(string.format("%-2s | %02d:%02d:%02d | %-8s | %s%s%s \n",
        track.number or "", track.mm or 0, track.ss or 0, track.ff or 0, track.length or "", track.title or "",
        isrcSeparator, track.isrc or ""))
    end
  end

  file:close()
end

-----------------------------------------------------------------

function create_html_report(albumTitle, albumPerformer, tracks, htmlOutputPath, albumLength, catalog_number,
                            production_year)
  local file = io.open(htmlOutputPath, "w")

  if not file then
    return
  end

  file:write("<html>\n<head>\n")
  file:write("<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Barlow:wght@200&display=swap'>\n")
  file:write(
    "<link rel='stylesheet' href='https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css'>\n")
  file:write("<style>\n")
  file:write("  .greenlabel {\n    color: #a0c96d;\n  }\n")
  file:write("  .redlabel {\n    color: #ff6961;\n  }\n")
  file:write("  .bluelabel {\n    color: #6fb8df;\n  }\n")
  file:write("  .greylabel {\n    color: #757575;\n  }\n")
  file:write("body {\n")
  file:write("  padding: 20px;\n")
  file:write("  font-family: 'Barlow', sans-serif;\n")
  file:write("}\n")
  file:write(".container {\n")
  file:write("  margin-top: 20px;\n")
  file:write("}\n")
  file:write("table {\n")
  file:write("  margin-top: 20px;\n")
  file:write("}\n")
  file:write("table {\n")
  file:write("  margin-top: 20px;\n")
  file:write("}\n")
  file:write("</style>\n</head>\n<body>\n")

  local date = os.date("*t")
  local hour = date.hour % 12
  hour = hour == 0 and 12 or hour
  local ampm = date.hour >= 12 and "PM" or "AM"
  local formattedDate = string.format("%d/%02d/%d %d:%02d%s", date.day, date.month, date.year, hour, date.min, ampm)
  file:write("<div class='container'>\n")
  file:write("  <h3><span class='greylabel'>Generated by ReaClassical (" .. formattedDate .. ")</span></h2>\n\n")
  file:write("  <h2><span class='greenlabel'>Album:</span> ", (albumTitle or ""), "</h3>\n")
  file:write("  <h2><span class='redlabel'>Year:</span> ", (production_year or ""), "</h3>\n")
  file:write("  <h2><span class='bluelabel'>Album Performer:</span> ", (albumPerformer or ""), "</h3>\n")

  if catalog_number ~= "" then
    file:write("  <h2><span class='greenlabel'>UPC/EAN:</span> ", catalog_number, "</h3>\n")
  end

  file:write("  <h2><span class='bluelabel'>Total Running Time:</span> " .. albumLength .. "</h3>\n\n")

  file:write("  <table class='table table-striped'>\n")
  file:write("    <thead class='thead-light'>\n")
  file:write("      <tr>\n")
  file:write("        <th>Track</th>\n")
  file:write("        <th>Start</th>\n")
  file:write("        <th>Length</th>\n")
  file:write("        <th>Title</th>\n")
  if any_isrc_present(tracks) then
    file:write("        <th>ISRC</th>\n")
  end
  file:write("      </tr>\n")
  file:write("    </thead>\n")
  file:write("    <tbody>\n")

  for _, track in ipairs(tracks or {}) do
    track.number = track.title == "pregap" and "p" or tostring(track.number or "")
    track.title = track.title == "pregap" and "" or track.title

    track.title = track.title:match("^[!]*([^|]*)")

    file:write("      <tr>\n")
    file:write("        <td>" .. track.number .. "</td>\n")
    file:write("        <td>" ..
      string.format("%02d:%02d:%02d", track.mm or 0, track.ss or 0, track.ff or 0) .. "</td>\n")
    file:write("        <td>" .. (track.length or "") .. "</td>\n")
    file:write("        <td>" .. (track.title or "") .. "</td>\n")
    if any_isrc_present(tracks) then
      file:write("        <td>" .. (track.isrc or "") .. "</td>\n")
    end
    file:write("      </tr>\n")
  end

  file:write("    </tbody>\n")
  file:write("  </table>\n")
  file:write("</div>\n</body>\n</html>")

  file:close()
end

-----------------------------------------------------------------

function any_isrc_present(tracks)
  for _, track in ipairs(tracks or {}) do
    if track.isrc then
      return true
    end
  end
  return false
end

-----------------------------------------------------------------

function time_to_mmssff(timeString)
  local minutes, seconds, frames = timeString:match("(%d+):(%d+):(%d+)")
  return tonumber(minutes), tonumber(seconds), tonumber(frames)
end

-----------------------------------------------------------------

function subtract_time_strings(timeString1, timeString2)
  local minutes1, seconds1, frames1 = time_to_mmssff(timeString1)
  local minutes2, seconds2, frames2 = time_to_mmssff(timeString2)

  local totalFrames1 = frames1 + seconds1 * 75 + minutes1 * 60 * 75
  local totalFrames2 = frames2 + seconds2 * 75 + minutes2 * 60 * 75

  local differenceFrames = totalFrames1 - totalFrames2

  local minutesResult = math.floor(differenceFrames / 75 / 60)
  local secondsResult = math.floor(differenceFrames / 75) % 60
  local framesResult = differenceFrames % 75

  local paddedMinutes = string.format("%02d", minutesResult)
  local paddedSeconds = string.format("%02d", secondsResult)
  local paddedFrames = string.format("%02d", framesResult)

  return paddedMinutes .. ":" .. paddedSeconds .. ":" .. paddedFrames
end

-----------------------------------------------------------------

function add_pregaps_to_table(tracks, num_of_markers)
  local pregap
  for i = 0, num_of_markers - 1 do
    local _, _, raw_pos_out, _, name_out = EnumProjectMarkers2(0, i)
    if string.sub(name_out, 1, 1) == "!" then
      formatted_pos_out = format_time(raw_pos_out)
      local mm, ss, ff = formatted_pos_out:match("(%d+):(%d+):(%d+)")
      pregap = {
        title = "pregap",
        mm = tonumber(mm),
        ss = tonumber(ss),
        ff = tonumber(ff)
      }
      table.insert(tracks, pregap)
    end
  end
  return tracks
end

-----------------------------------------------------------------

function parse_markers()
  local num_markers = CountProjectMarkers(0)
  local metadata = {}

  -- First pass: Extract album-wide metadata
  for i = 0, num_markers - 1 do
    local _, isrgn, _, _, name, _ = EnumProjectMarkers(i)
    if not isrgn then -- Only process markers
      local album_marker = name:match("^@(.-)|")
      if album_marker then
        metadata = {
          title = album_marker,
          catalog = name:match("CATALOG=([^|]+)") or name:match("EAN=([^|]+)")
              or name:match("UPC=([^|]+)") or nil,
          performer = name:match("PERFORMER=([^|]+)") or nil,
          songwriter = name:match("SONGWRITER=([^|]+)") or nil,
          composer = name:match("COMPOSER=([^|]+)") or nil,
          arranger = name:match("ARRANGER=([^|]+)") or nil,
          message = name:match("MESSAGE=([^|]+)") or nil,
          identification = name:match("IDENTIFICATION=([^|]+)") or nil,
          genre = name:match("GENRE=([^|]+)") or nil,
          language = name:match("LANGUAGE=([^|]+)") or nil
        }
        break -- Stop early after finding album metadata
      end
    end
  end

  return metadata
end

---------------------------------------------------------------------

function checksum(filename)
  local file = io.open(filename, "rb")
  if not file then return nil, "Cannot open file" end

  local file_checksum = 0
  for line in file:lines() do
    for i = 1, #line do
      file_checksum = (file_checksum + line:byte(i)) % 0xFFFFFFFF
    end
  end

  file:close()
  return file_checksum
end

---------------------------------------------------------------------

function get_txt_file()
  local _, path = EnumProjects(-1)
  local slash = package.config:sub(1, 1)
  if path == "" then
    path = GetProjectPath()
  else
    local pattern = "(.+)" .. slash .. ".+[.][Rr][Pp][Pp]"
    path = path:match(pattern)
  end
  local file = path .. slash .. 'metadata.txt'
  return file
end

---------------------------------------------------------------------

function import_sony_metadata(metadata_file)
  local file = io.open(metadata_file, "r")
  if not file then return false end

  local metadata = { album = {}, tracks = {} }
  local track_number = nil
  local expected_tracks = nil

  for line in file:lines() do
    local key, value = line:match("^(.-)%s*=%s*(.-)$")
    if key and value:match("%w") then
      if key == "Last Track Number" then
        expected_tracks = tonumber(value)
      elseif key:match("^Track %d+ Title$") then
        track_number = tonumber(key:match("Track (%d+) Title"))
        if track_number then
          metadata.tracks[track_number] = metadata.tracks[track_number] or {}
          metadata.tracks[track_number].title = value
        end
      elseif track_number and key:match("^Track %d+ ") then
        local field = key:match("^Track %d+ (.+)")
        metadata.tracks[track_number] = metadata.tracks[track_number] or {}
        metadata.tracks[track_number][field:lower()] = value
      elseif key == "Album Title" then
        metadata.album.title = value
      elseif key == "Performer" then
        metadata.album.performer = value
      elseif key == "Songwriter" then
        metadata.album.songwriter = value
      elseif key == "Composer" then
        metadata.album.composer = value
      elseif key == "Arranger" then
        metadata.album.arranger = value
      elseif key == "Identification" then
        metadata.album.identification = value
      elseif key == "Album Message" then
        metadata.album.message = value
      elseif key == "Genre Code" then
        metadata.album.genre = value
      elseif key == "Language" then
        metadata.album.language = value
      end
    end
  end

  file:close()

  if not expected_tracks or #metadata.tracks ~= expected_tracks then
    return false
  end

  local first_track = GetTrack(0, 0) -- Get the first track
  if not first_track then return end

  local num_items = CountTrackMediaItems(first_track)
  track_number = 0
  for i = 0, num_items - 1 do
    local item = GetTrackMediaItem(first_track, i)
    if item then
      local take = GetActiveTake(item)
      if take then
        local take_name = GetTakeName(take)

        -- Handle album-wide metadata for @ item
        if take_name and take_name:sub(1, 1) == "@" then
          local new_take_name = "@" .. (metadata.album.title or "")

          if metadata.album.performer then
            new_take_name = new_take_name .. "|PERFORMER=" .. metadata.album.performer
          end
          if metadata.album.songwriter then
            new_take_name = new_take_name .. "|SONGWRITER=" .. metadata.album.arranger
          end
          if metadata.album.composer then
            new_take_name = new_take_name .. "|COMPOSER=" .. metadata.album.composer
          end
          if metadata.album.arranger then
            new_take_name = new_take_name .. "|ARRANGER=" .. metadata.album.arranger
          end
          if metadata.album.genre then
            new_take_name = new_take_name .. "|GENRE=" .. metadata.album.genre
          end
          if metadata.album.identification then
            new_take_name = new_take_name .. "|IDENTIFICATION=" .. metadata.album.identification
          end
          if metadata.album.language then
            new_take_name = new_take_name .. "|LANGUAGE=" .. metadata.album.language
          end
          if metadata.album.catalog then
            new_take_name = new_take_name .. "|CATALOG=" .. metadata.album.catalog
          end
          if metadata.album.message then
            new_take_name = new_take_name .. "|MESSAGE=" .. metadata.album.message
          end

          -- Apply metadata to the @ item
          GetSetMediaItemTakeInfo_String(take, "P_NAME", new_take_name, true)

          -- Process track metadata for all other takes
        elseif take_name and take_name ~= "" then
          track_number = track_number + 1 -- Assuming items are in order
          if metadata.tracks[track_number] then
            local new_take_name = metadata.tracks[track_number].title or ""

            if metadata.tracks[track_number].performer then
              new_take_name = new_take_name .. "|PERFORMER=" .. metadata.tracks[track_number].performer
            end
            if metadata.tracks[track_number].songwriter then
              new_take_name = new_take_name .. "|SONGWRITER=" .. metadata.tracks[track_number].arranger
            end
            if metadata.tracks[track_number].composer then
              new_take_name = new_take_name .. "|COMPOSER=" .. metadata.tracks[track_number].composer
            end
            if metadata.tracks[track_number].arranger then
              new_take_name = new_take_name .. "|ARRANGER=" .. metadata.tracks[track_number].arranger
            end
            if metadata.tracks[track_number].message then
              new_take_name = new_take_name .. "|MESSAGE=" .. metadata.tracks[track_number].message
            end

            -- Apply metadata to the take name
            GetSetMediaItemTakeInfo_String(take, "P_NAME", new_take_name, true)
          end
        end
      end
    end
  end

  return true
end

---------------------------------------------------------------------

function create_metadata_report_and_file()
  local metadata_report = NamedCommandLookup("_RS9dfbe237f69ecb0151b67e27e607b93a7bd0c4b4")
  Main_OnCommand(metadata_report, 0)
end

---------------------------------------------------------------------

function split_and_tag_final_item()
  local track = GetTrack(0, 0)
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

function check_first_track_for_names()
  -- Get the first track
  local track = GetTrack(0, 0)
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
    local _, num_markers, num_regions = CountProjectMarkers(0)
    local total = num_markers + num_regions

    -- Iterate backwards by project index
    for i = total - 1, 0, -1 do
        local retval, is_region, _, _, _, markrgnindexnumber = EnumProjectMarkers(i)
        if retval then
            DeleteProjectMarker(0, markrgnindexnumber, is_region)
        end
    end
end

---------------------------------------------------------------------

main()
