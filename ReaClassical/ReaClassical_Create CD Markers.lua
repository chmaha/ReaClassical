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

---------------------------------------------------------------------
-- Forward declarations
---------------------------------------------------------------------

-- CD Marker functions
local run_create_cd_markers, get_info, cd_markers, find_current_start, create_marker
local renumber_markers, add_pregap, find_project_end, end_marker
local frame_check, delete_markers, remove_negative_position_items_from_folder
local empty_items_check, return_custom_length
local fade_equations, pos_check, is_item_start_crossfaded, is_item_end_crossfaded
local steps_by_length, generate_interpolated_fade, convert_fades_to_env, room_tone
local add_roomtone_fadeout, check_saved_state, album_item_count
local split_and_tag_final_item
local check_first_track_for_names, delete_all_markers_and_regions
local shift_folder_items_and_markers, shift_all_markers_and_regions

-- Metadata Editor functions
local editor_main, parse_item_name, serialize_metadata, increment_isrc
local update_marker_and_region, update_album_marker, propagate_album_field
local track_has_valid_items, create_metadata_report_and_cue

---------------------------------------------------------------------
-- Shared state
---------------------------------------------------------------------

local minimum_points = 15
local points = {}

local _, digital_release_str = GetProjExtState(0, "ReaClassical", "digital_release_only")
local digital_release_only = digital_release_str == "1"

---------------------------------------------------------------------
-- Extension checks
---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------
-- Workflow check
---------------------------------------------------------------------

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

---------------------------------------------------------------------
-- Metadata Editor state
---------------------------------------------------------------------

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('DDP Metadata Editor')
local window_open = true

local labels = { "Title", "Performer", "Songwriter", "Composer", "Arranger", "Message", "ISRC" }
local keys = { "title", "performer", "songwriter", "composer", "arranger", "message", "isrc" }

local album_keys_line1 = { "title", "performer", "songwriter", "composer", "arranger" }
local album_labels_line1 = { "Album Title", "Performer", "Songwriter", "Composer", "Arranger" }
local album_keys_line2 = { "genre", "identification", "language", "catalog", "message" }
local album_labels_line2 = { "Genre", "Identification", "Language", "Catalog", "Message" }

local genre_list = {
    "Adult Contemporary",
    "Alternative Rock",
    "Childrens Music",
    "Classical",
    "Contemporary Christian",
    "Country",
    "Dance",
    "Easy Listening",
    "Erotic",
    "Folk",
    "Gospel",
    "Hip Hop",
    "Jazz",
    "Latin",
    "Musical",
    "New Age",
    "Opera",
    "Operetta",
    "Pop",
    "Rap",
    "Reggae",
    "Rock Music",
    "Rhythm & Blues",
    "Sound Effects",
    "Soundtrack",
    "Spoken Word",
    "World Music"
}

local language_list = {
    "Albanian",
    "Amharic",
    "Arabic",
    "Armenian",
    "Assamese",
    "Azerbaijani",
    "Bambora",
    "Basque",
    "Bengali",
    "Bielorussian",
    "Breton",
    "Bulgarian",
    "Burmese",
    "Catalan",
    "Chinese",
    "Churash",
    "Croatian",
    "Czech",
    "Danish",
    "Dari",
    "Dutch",
    "English",
    "Esperanto",
    "Estonian",
    "Faroese",
    "Finnish",
    "Flemish",
    "French",
    "Frisian",
    "Fulani",
    "Gaelic",
    "Galician",
    "Georgian",
    "German",
    "Greek",
    "Gujurati",
    "Gurani",
    "Hausa",
    "Hebrew",
    "Hindi",
    "Hungarian",
    "Icelandic",
    "Indonesian",
    "Irish",
    "Italian",
    "Japanese",
    "Kannada",
    "Kazakh",
    "Khmer",
    "Korean",
    "Laotian",
    "Lappish",
    "Latin",
    "Latvian",
    "Lithuanian",
    "Luxembourgian",
    "Macedonian",
    "Malagasay",
    "Malaysian",
    "Maltese",
    "Marathi",
    "Moldavian",
    "Ndebele",
    "Nepali",
    "Norwegian",
    "Occitan",
    "Oriya",
    "Papamiento",
    "Persian",
    "Polish",
    "Portugese",
    "Punjabi",
    "Pushtu",
    "Quechua",
    "Romanian",
    "Romansh",
    "Russian",
    "Ruthenian",
    "Serbian",
    "Serbo-croat",
    "Shona",
    "Sinhalese",
    "Slovak",
    "Slovenian",
    "Somali",
    "Spanish",
    "SrananTongo",
    "Swahili",
    "Swedish",
    "Tadzhik",
    "Tamil",
    "Tatar",
    "Telugu",
    "Thai",
    "Turkish",
    "Ukrainian",
    "Urdu",
    "Uzbek",
    "Vietnamese",
    "Wallon",
    "Welsh",
    "Zulu"
}

local isrc_pattern = "^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$"

local editing_track
local album_metadata, album_item
local track_items_metadata = {}
local prev_isrc_values = {}

local _, manual_isrc_entry_str = GetProjExtState(0, "ReaClassical", "manual_isrc_entry")
local manual_isrc_entry = manual_isrc_entry_str == "1"

local _, manual_people_entry_str = GetProjExtState(0, "ReaClassical", "manual_people_entry")
local manual_people_entry = manual_people_entry_str == "1"

local add_marker_offsets = NamedCommandLookup("_RS65a051a97f34fadc9634caba5c969f1806c59d15")
local remove_marker_offsets = NamedCommandLookup("_RSf14f3ed014dba3bb83124c6f48361ff0187ef84d")
local reposition_album_tracks = NamedCommandLookup("_RScd77c8197880fdf5bef78b3cf0227a460e75d40c")
local move_album_track_up = NamedCommandLookup("_RS18fe066cb8806e30b0371fc30a79c67ce2b807f1")
local move_album_track_down = NamedCommandLookup("_RS6d1212ff49d4205e6f7f0d7c30ae539d3da05f6f")

local first_run = true
local selected_track_row = nil
local pending_reinit = false

---------------------------------------------------------------------
--                    CD MARKER FUNCTIONS
---------------------------------------------------------------------

function run_create_cd_markers(selected_track)
    local not_saved = check_saved_state()
    if not_saved then
        MB("Please save your project before running this function.", "Create CD Markers", 0)
        return false
    end

    if not selected_track then
        MB("Error: No track selected.", "Create CD Markers", 0)
        return false
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
            return false
        end
        selected_track = folder_track
    end

    local track_color = GetTrackColor(selected_track)

    local num_of_items = 0
    if selected_track then num_of_items = album_item_count(selected_track) end
    if not selected_track or num_of_items == 0 then
        MB("Error: No media items found.", "Create CD Markers", 0)
        return false
    end
    local empty_count = empty_items_check(selected_track, num_of_items)
    if empty_count > 0 then
        MB("Error: Empty items found on first track. Delete them to continue.", "Create CD Markers", 0)
        return false
    end

    local removed = remove_negative_position_items_from_folder(selected_track)
    if removed > 0 then
        ShowConsoleMsg("Cleaned up " .. removed .. " invalid item(s) from folder.\n")
    end

    local names_on_first_track = check_first_track_for_names(selected_track)
    if not names_on_first_track then return false end

    SetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?", "yes")
    local success, redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length = cd_markers(
        selected_track,
        num_of_items, track_color)
    if not success then return false end
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
    SetOnlyTrackSelected(selected_track)
    return true
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
    local album_metadata_str = get_info(selected_track)
    if not album_metadata_str then
        album_metadata_str = split_and_tag_final_item(selected_track)
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
                    AddProjectMarker2(0, false, frame_check(current_start - (pregap_len + final_offset)), 0, "!",
                        marker_count,
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
        redbook_project_length = end_marker(selected_track, album_metadata_str, postgap, num_of_items,
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

function end_marker(selected_track, album_metadata_str, postgap, num_of_items, track_color)
    local final_item = GetTrackMediaItem(selected_track, num_of_items - 1)
    local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
    local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
    local final_end = final_start + final_length
    local catalog = ""

    local album_info = album_metadata_str .. catalog

    if not album_metadata_str:match("MESSAGE=") then
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
        if prev_end >= item_pos - 1e-9 then
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
        if next_pos <= item_end + 1e-9 then
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
        return (curve * pos ^ 4) +
            (1 - curve) * (1 - (1 - pos) ^ 2 * (2 - math.pi / 4 - (1 - math.pi / 4) * (1 - pos) ^ 2))
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
    local is_first_item = true

    -- Loop through items to find last item and last unnamed take
    for i = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = pos + len

        -- Track the last item before a >= 1 min gap (skip gap check for first item)
        if not is_first_item and pos - last_end >= gap_threshold then
            break
        end
        is_first_item = false

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
    local _, num_markers, num_regions = CountProjectMarkers(0)
    local total = num_markers + num_regions

    -- Iterate backwards by project index
    for i = total - 1, 0, -1 do
        local retval, is_region, pos, rgnend, name, markrgnindexnumber =
            EnumProjectMarkers(i)

        if retval then
            DeleteProjectMarker(0, markrgnindexnumber, is_region)
        end
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

    -- Shift all track envelope points AND automation items
    for _, tr in ipairs(tracks_to_shift) do
        local num_envs = CountTrackEnvelopes(tr)
        for e = 0, num_envs - 1 do
            local env = GetTrackEnvelope(tr, e)

            -- Shift regular envelope points
            local num_points = CountEnvelopePoints(env)
            local points_data = {}
            for p = 0, num_points - 1 do
                local retval, time, value, shape, tension, selected = GetEnvelopePoint(env, p)
                table.insert(points_data, {
                    time = time + shift_amount,
                    value = value,
                    shape = shape,
                    tension = tension,
                    selected = selected
                })
            end

            DeleteEnvelopePointRange(env, -1000000, 1000000)

            for _, pt in ipairs(points_data) do
                InsertEnvelopePoint(env, pt.time, pt.value, pt.shape, pt.tension, pt.selected, true)
            end

            Envelope_SortPoints(env)

            -- Shift automation items
            local num_ai = CountAutomationItems(env)
            for ai = 0, num_ai - 1 do
                local ai_pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
                GetSetAutomationItemInfo(env, ai, "D_POSITION", ai_pos + shift_amount, true)
            end
        end
    end

    -- Collect all items in all tracks
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
--                 METADATA EDITOR FUNCTIONS
---------------------------------------------------------------------

function parse_item_name(name, is_album)
    local data = {}
    local parts = {}
    for part in name:gmatch("[^|]+") do table.insert(parts, part) end
    if #parts > 0 then
        if is_album then
            data.title = parts[1]:gsub("^@", "")
            -- Set defaults for genre and language
            data.genre = "Classical"
            data.language = "English"
            for i = 2, #parts do
                local k, v = parts[i]:match("^(%w+)=(.+)$")
                if k and v then
                    k = k:lower()
                    for j = 1, #album_keys_line1 do if k == album_keys_line1[j] then data[k] = v end end
                    for j = 1, #album_keys_line2 do if k == album_keys_line2[j] then data[k] = v end end
                end
            end
        else
            -- Strip ! prefix from title for display purposes
            local title_part = parts[1] or name
            data.title = title_part:gsub("^!", "")
            for i = 2, #parts do
                local k, v = parts[i]:match("^(%w+)=(.+)$")
                if k and v then
                    k = k:lower()
                    -- Preserve OFFSET
                    if k == "offset" then
                        data._offset = v
                    else
                        for _, kk in ipairs(keys) do
                            if k == kk then data[k] = v end
                        end
                    end
                end
            end
        end
    else
        data.title = name:gsub("^@", ""):gsub("^!", "")
        -- Set defaults for genre and language when creating new album metadata
        if is_album then
            data.genre = "Classical"
            data.language = "English"
        end
    end
    return data
end

---------------------------------------------------------------------

function serialize_metadata(data, is_album)
    local parts = {}
    if is_album then
        parts[#parts + 1] = "@" .. (data.title or "")
        for _, k in ipairs(album_keys_line1) do
            if k ~= "title" and data[k] and data[k] ~= "" then parts[#parts + 1] = k:upper() .. "=" .. data[k] end
        end
        for _, k in ipairs(album_keys_line2) do
            if data[k] and data[k] ~= "" then parts[#parts + 1] = k:upper() .. "=" .. data[k] end
        end
    else
        parts[#parts + 1] = data.title or ""

        -- Insert OFFSET immediately after title if present
        if data._offset and data._offset ~= "" then
            parts[#parts + 1] = "OFFSET=" .. data._offset
        end

        for _, k in ipairs(keys) do
            if k ~= "title" and data[k] and data[k] ~= "" then
                parts[#parts + 1] = k:upper() .. "=" .. data[k]
            end
        end
    end
    return table.concat(parts, "|")
end

---------------------------------------------------------------------

function increment_isrc(isrc, offset)
    local prefix, year, seq = isrc:match("^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$")
    if not prefix or not year or not seq then return isrc end
    local new_seq = tonumber(seq) + offset
    return string.format("%s%s%05d", prefix, year, new_seq)
end

---------------------------------------------------------------------

function update_marker_and_region(item)
    if not item then return end

    local take = GetActiveTake(item)
    if not take then return end

    local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not item_name or item_name == "" then return end

    -- Clean name (remove OFFSET)
    local clean_name = item_name:gsub("|OFFSET=[%d%.%-]+", "")

    local track = GetMediaItemTrack(item)
    local track_color = GetTrackColor(track)

    -- Get stored marker GUID from item's P_EXT:cdmarker
    local ok, guid = GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", "", false)
    if not ok or guid == "" then return end

    -- Find marker index using GUID
    local ok_index, mark_index_str = GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. guid, "", false)
    if not ok_index or mark_index_str == "" then return end

    local mark_index = tonumber(mark_index_str)
    if not mark_index then return end

    -- Update the marker
    local retval, isrgn, pos, _, _, markrgnID, color = EnumProjectMarkers3(0, mark_index)
    if retval and not isrgn and track_color == color then
        SetProjectMarkerByIndex(0, mark_index, false, pos, 0, markrgnID, "#" .. clean_name, color)
    end

    -- Find and update the associated region
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local num_markers, num_regions = CountProjectMarkers(0)

    for idx = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, rgnend, _, markrgnID, color = EnumProjectMarkers3(0, idx)
        if isrgn and pos <= item_pos and item_pos <= rgnend then
            if track_color == color then
                SetProjectMarkerByIndex(0, idx, true, pos, rgnend, markrgnID,
                    parse_item_name(clean_name, false).title, color)
            end
            break
        end
    end
end

---------------------------------------------------------------------

function update_album_marker(item)
    if not item then return end
    local take = GetActiveTake(item)
    if not take then return end
    local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not item_name or not item_name:match("^@") then return end

    local num_markers, num_regions = CountProjectMarkers(0)
    for idx = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, _, name, markrgnID = EnumProjectMarkers(idx)
        if not isrgn and name:match("^@") then
            SetProjectMarkerByIndex(0, idx, false, pos, 0, markrgnID, item_name, 0)
            break
        end
    end
end

---------------------------------------------------------------------

function propagate_album_field(field)
    local val, mixed = nil, false

    -- Gather track values
    for _, md in pairs(track_items_metadata) do
        if md and md[field] and md[field] ~= "" then
            if not val then
                val = md[field]
            elseif val ~= md[field] then
                mixed = true
                break
            end
        end
    end

    -- Determine desired album value
    local desired = nil
    if val then
        desired = mixed and "Various" or val
    end

    album_metadata[field] = desired
end

---------------------------------------------------------------------

function track_has_valid_items(track)
    if not track then return false end
    local item_count = CountTrackMediaItems(track)
    if item_count == 0 then return false end
    for i = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if name and (name:match("^@") or name:match("^#")) then return true end
        end
    end
    return false
end

---------------------------------------------------------------------

function create_metadata_report_and_cue()
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    dofile(script_path .. "ReaClassical_Metadata Report.lua")
end

---------------------------------------------------------------------
--                    METADATA EDITOR GUI
---------------------------------------------------------------------

function editor_main()
    if not window_open then
        create_metadata_report_and_cue()
        return
    end

    local _, FLT_MAX = ImGui.NumericLimits_Float()
    ImGui.SetNextWindowSizeConstraints(ctx, 1100, 500, FLT_MAX, FLT_MAX)
    local opened, open_ref = ImGui.Begin(ctx, "ReaClassical DDP Metadata Editor", window_open)
    window_open = open_ref

    if opened then
        local selected_track = GetSelectedTrack(0, 0)
        if selected_track then
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
                if folder_track then selected_track = folder_track end
            end
        end
        local valid_items = track_has_valid_items(selected_track)

        if selected_track and not valid_items then
            ImGui.Text(ctx, "No valid item names found for DDP metadata editing.")
        elseif selected_track then
            local _, trigger = GetProjExtState(0, "ReaClassical", "ddp_refresh_trigger")
            if trigger == "y" then
                editing_track = nil
                SetProjExtState(0, "ReaClassical", "ddp_refresh_trigger", "")
            end

            -- Handle pending re-init from move operations BEFORE checking editing_track
            if pending_reinit then
                editing_track = nil
                pending_reinit = false
            end

            if editing_track ~= selected_track then
                -- Check if we're actually switching to a different track (not just re-initing)
                local is_track_switch = (editing_track ~= nil)

                editing_track = selected_track
                selected_track_row = nil -- Reset selection when switching tracks

                -- Only clear stored GUID if actually switching tracks
                if is_track_switch then
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", "")
                end

                -- Reset points table before creating CD markers
                points = {}

                Undo_BeginBlock()
                run_create_cd_markers(selected_track)
                Undo_EndBlock("Create CD/DDP Markers", -1)

                create_metadata_report_and_cue()
                album_metadata, album_item = nil, nil
                for i = 0, CountTrackMediaItems(selected_track) - 1 do
                    local item = GetTrackMediaItem(selected_track, i)
                    local take = GetActiveTake(item)
                    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    if name:match("^@") then
                        album_metadata = parse_item_name(name, true)
                        album_item = item
                        break
                    end
                end

                track_items_metadata = {}
                local item_count = CountTrackMediaItems(selected_track)
                for i = 0, item_count - 1 do
                    local item = GetTrackMediaItem(selected_track, i)
                    local take = GetActiveTake(item)
                    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    if name and name:match("%S") and not name:match("^@") then
                        track_items_metadata[i] = parse_item_name(name, false)
                    end
                end

                -- Restore selection from stored GUID after re-init
                local _, stored_guid = GetProjExtState(0, "ReaClassical", "ddp_selected_item_guid")
                if stored_guid ~= "" then
                    local found = false
                    -- Find and select the item with this GUID
                    for i = 0, item_count - 1 do
                        local item = GetTrackMediaItem(selected_track, i)
                        local _, item_guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
                        if item_guid == stored_guid then
                            -- Check if it's already selected
                            if GetMediaItemInfo_Value(item, "B_UISEL") ~= 1 then
                                Main_OnCommand(40289, 0) -- Unselect all items
                                SetMediaItemSelected(item, true)
                                UpdateArrange()
                            end
                            found = true
                            break
                        end
                    end
                    -- If we didn't find the GUID, clear it
                    if not found then
                        SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", "")
                    end
                end
            end

            if album_metadata then
                local previous_valid_catalog = album_metadata.catalog or ""
                local function recalculate()
                    local refresh_track = GetSelectedTrack(0, 0)
                    if refresh_track then
                        points = {}
                        Undo_BeginBlock()
                        run_create_cd_markers(refresh_track)
                        Undo_EndBlock("Create CD/DDP Markers", -1)
                        create_metadata_report_and_cue()
                        editing_track = nil
                    end
                end

local btn_label = "Recalculate"
local btn_text_w = ImGui.CalcTextSize(ctx, btn_label)
local pad_x = select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))
local btn_w = btn_text_w + pad_x * 2
local window_w = select(1, ImGui.GetContentRegionAvail(ctx))
ImGui.Text(ctx, "Album Metadata:")
ImGui.SameLine(ctx)
ImGui.SetCursorPosX(ctx, (window_w - btn_w) / 2)
if ImGui.Button(ctx, btn_label) then
    recalculate()
end
ImGui.Separator(ctx)

                ImGui.Dummy(ctx, 0, 10)

                local spacing = 5

                -- Left-align Digital Release Only checkbox
                ImGui.Text(ctx, "Digital Release Only")
                ImGui.SameLine(ctx)
                local digital_changed
                digital_changed, digital_release_only = ImGui.Checkbox(ctx, "##digital_release_chk", digital_release_only)
                if digital_changed then
                    SetProjExtState(0, "ReaClassical", "digital_release_only", digital_release_only and "1" or "0")
                    editing_track = nil
                    -- Reset points and re-run Create CD Markers
                    points = {}
                    Undo_BeginBlock()
                    run_create_cd_markers(selected_track)
                    Undo_EndBlock("Create CD/DDP Markers", -1)
                end

                -- Right-align Manual Contributors Entry checkbox
                ImGui.SameLine(ctx)
                local avail = select(1, ImGui.GetContentRegionAvail(ctx))
                local text_w = ImGui.CalcTextSize(ctx, "Manual Contributors Entry")
                local checkbox_w = ImGui.GetFrameHeight(ctx)

                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + avail - (text_w + checkbox_w + 8))

                ImGui.Text(ctx, "Manual Contributors Entry")
                ImGui.SameLine(ctx)

                _, manual_people_entry = ImGui.Checkbox(ctx, "##manual_people_chk", manual_people_entry)
                SetProjExtState(0, "ReaClassical", "manual_people_entry", manual_people_entry and "1" or "0")

                -- Units remain the same, only width calculation changes
                local line1_units = { 2, 1, 1, 1, 1 }
                local line2_units = { 1, 1, 0.75, 0.6, 2 }

                -- Total horizontal space available *right now*
                local avail_w = select(1, ImGui.GetContentRegionAvail(ctx))

                local total_units1, total_units2 = 0, 0
                for _, u in ipairs(line1_units) do total_units1 = total_units1 + u end
                for _, u in ipairs(line2_units) do total_units2 = total_units2 + u end

                -- Compute widths as a fraction of available window space
                local line1_widths, line2_widths = {}, {}
                for i, u in ipairs(line1_units) do
                    line1_widths[i] = (avail_w - spacing * (#line1_units - 1)) * (u / total_units1)
                end
                for i, u in ipairs(line2_units) do
                    line2_widths[i] = (avail_w - spacing * (#line2_units - 1)) * (u / total_units2)
                end

                if not manual_people_entry then
                    -- Track if any field changed
                    local album_changed = false

                    -- Propagate performer, songwriter, composer, arranger
                    for _, f in ipairs({ "performer", "songwriter", "composer", "arranger" }) do
                        local old_value = album_metadata[f]
                        propagate_album_field(f)
                        if album_metadata[f] ~= old_value then
                            album_changed = true
                        end
                    end

                    -- Write back to album item and update marker only if something changed
                    if album_changed and album_item then
                        local take = GetActiveTake(album_item)
                        if take then
                            local new_name = serialize_metadata(album_metadata, true)
                            GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                            update_album_marker(album_item)
                        end
                    end
                end

                for j = 1, #album_keys_line1 do
                    if not manual_people_entry and (album_keys_line1[j] ~= "title") then
                        ImGui.BeginDisabled(ctx)
                    end
                    ImGui.BeginGroup(ctx)
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, album_labels_line1[j])
                    ImGui.PushItemWidth(ctx, line1_widths[j])
                    local changed
                    local albumkeys1_widget_id = "##album_" .. album_keys_line1[j] .. "_" .. tostring(selected_track)
                    changed, album_metadata[album_keys_line1[j]] = ImGui.InputText(
                        ctx,
                        albumkeys1_widget_id,
                        album_metadata[album_keys_line1[j]] or "",
                        128
                    )
                    ImGui.PopItemWidth(ctx)
                    ImGui.EndGroup(ctx)
                    if j < #album_keys_line1 then ImGui.SameLine(ctx, 0, spacing) end
                    if changed and GetSelectedTrack(0, 0) == editing_track then
                        local take = GetActiveTake(album_item)
                        local new_name = serialize_metadata(album_metadata, true)
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                        update_album_marker(album_item)
                    end
                    if not manual_people_entry and (album_keys_line1[j] ~= "title") then
                        ImGui.EndDisabled(ctx)
                    end
                end

                for j = 1, #album_keys_line2 do
                    ImGui.BeginGroup(ctx)
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, album_labels_line2[j])
                    ImGui.PushItemWidth(ctx, line2_widths[j])

                    local key = album_keys_line2[j]
                    local changed
                    local albumkeys2_widget_id = "##album_" .. key .. "_" .. tostring(selected_track)

                    if key == "genre" then
                        -- Genre dropdown
                        local current_genre = album_metadata.genre or ""
                        local preview_value = current_genre
                        if ImGui.BeginCombo(ctx, albumkeys2_widget_id, preview_value) then
                            for _, genre in ipairs(genre_list) do
                                local is_selected = (current_genre == genre)
                                if ImGui.Selectable(ctx, genre, is_selected) then
                                    album_metadata.genre = genre
                                    changed = true
                                end
                                if is_selected then
                                    ImGui.SetItemDefaultFocus(ctx)
                                end
                            end
                            ImGui.EndCombo(ctx)
                        end
                    elseif key == "language" then
                        -- Language dropdown
                        local current_language = album_metadata.language or ""
                        local preview_value = current_language
                        if ImGui.BeginCombo(ctx, albumkeys2_widget_id, preview_value) then
                            for _, language in ipairs(language_list) do
                                local is_selected = (current_language == language)
                                if ImGui.Selectable(ctx, language, is_selected) then
                                    album_metadata.language = language
                                    changed = true
                                end
                                if is_selected then
                                    ImGui.SetItemDefaultFocus(ctx)
                                end
                            end
                            ImGui.EndCombo(ctx)
                        end
                    else
                        -- Regular text input for other fields
                        changed, album_metadata[key] = ImGui.InputText(
                            ctx,
                            albumkeys2_widget_id,
                            album_metadata[key] or "",
                            128
                        )
                    end

                    ImGui.PopItemWidth(ctx)
                    ImGui.EndGroup(ctx)
                    if j < #album_keys_line2 then ImGui.SameLine(ctx, 0, spacing) end

                    if changed and GetSelectedTrack(0, 0) == editing_track then
                        if key == "catalog" then
                            local v = album_metadata.catalog or ""

                            if not v:match("^%d*$") or (v ~= "" and (#v ~= 12 and #v ~= 13)) then
                                album_metadata.catalog = previous_valid_catalog
                                goto skip_album_write
                            end

                            previous_valid_catalog = v
                        end

                        local take = GetActiveTake(album_item)
                        local new_name = serialize_metadata(album_metadata, true)
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                        update_album_marker(album_item)

                        ::skip_album_write::
                    end
                end
            end
            ImGui.Dummy(ctx, 0, 10)
            ImGui.Text(ctx, "Track Metadata:")

            -- Check if any items have offsets and show indicator
            local has_offsets = false
            if selected_track then
                for i = 0, CountTrackMediaItems(selected_track) - 1 do
                    local item = GetTrackMediaItem(selected_track, i)
                    local take = GetActiveTake(item)
                    if take then
                        local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                        if name and name:match("|OFFSET=") then
                            has_offsets = true
                            break
                        end
                    end
                end
            end

            if has_offsets then
                ImGui.SameLine(ctx)
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x56A0D3FF) -- Carolina blue
                ImGui.Text(ctx, "(marker offsets active)")
                ImGui.PopStyleColor(ctx)
            end

            ImGui.Separator(ctx)

            -- Left-side buttons for marker offsets
            if ImGui.Button(ctx, "Add Marker Offsets") then
                Main_OnCommand(add_marker_offsets, 0)
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Manually move CD markers to desired start times then press this button...")
            end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Remove All Marker Offsets") then
                Main_OnCommand(remove_marker_offsets, 0)
            end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Reposition Album Tracks") then
                Main_OnCommand(reposition_album_tracks, 0)
            end

            local item_count = CountTrackMediaItems(selected_track)

            -- Check if we should show move buttons (non-album item selected)
            local show_move_buttons = false
            if selected_track_row ~= nil then
                -- Check if any item on this track is selected and it's not an album item
                for i = 0, item_count - 1 do
                    local check_item = GetTrackMediaItem(selected_track, i)
                    if GetMediaItemInfo_Value(check_item, "B_UISEL") == 1 then
                        local check_take = GetActiveTake(check_item)
                        if check_take then
                            local _, check_name = GetSetMediaItemTakeInfo_String(check_take, "P_NAME", "", false)
                            -- Show buttons if item is selected and NOT an album item
                            if check_name and not check_name:match("^@") then
                                show_move_buttons = true
                                break
                            end
                        end
                    end
                end
            end

            -- Show move buttons on same line if appropriate
            if show_move_buttons then
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, "Move Album Track Up") then
                    -- Store the GUID before moving
                    local item = GetTrackMediaItem(selected_track, selected_track_row)
                    local _, item_guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", item_guid)

                    -- Execute move
                    Main_OnCommand(move_album_track_up, 0)

                    -- Schedule re-init for next frame
                    pending_reinit = true
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, "Move Album Track Down") then
                    -- Store the GUID before moving
                    local item = GetTrackMediaItem(selected_track, selected_track_row)
                    local _, item_guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", item_guid)

                    -- Execute move
                    Main_OnCommand(move_album_track_down, 0)

                    -- Schedule re-init for next frame
                    pending_reinit = true
                end
            end

            -- right-align the checkbox group
            ImGui.SameLine(ctx)
            local avail = select(1, ImGui.GetContentRegionAvail(ctx))
            local text_w = ImGui.CalcTextSize(ctx, "Manual ISRC entry")
            local checkbox_w = ImGui.GetFrameHeight(ctx)

            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + avail - (text_w + checkbox_w + 8))

            ImGui.Text(ctx, "Manual ISRC entry")
            ImGui.SameLine(ctx)

            _, manual_isrc_entry = ImGui.Checkbox(ctx, "##manual_isrc_chk", manual_isrc_entry)
            SetProjExtState(0, "ReaClassical", "manual_isrc_entry", manual_isrc_entry and "1" or "0")

            local spacing = 5

            local track_number_counter = 1

            -- Calculate fixed widths for checkbox and track number
            checkbox_w = ImGui.GetFrameHeight(ctx)
            local track_number_w = ImGui.CalcTextSize(ctx, "00")

            -- Get total available width
            local avail_w = select(1, ImGui.GetContentRegionAvail(ctx))

            -- Calculate space available for metadata boxes after accounting for fixed elements
            local fixed_width = checkbox_w + spacing + track_number_w + spacing
            local metadata_width = avail_w - fixed_width - spacing * #keys

            -- Distribute width among metadata boxes (title gets 2 units, others get 1)
            local normal_boxes = #keys - 1
            local total_units = normal_boxes + 2 -- 6 normal boxes + 2 units for title
            local normal_box_w = metadata_width / total_units
            local title_box_w = 2 * normal_box_w

            local first_isrc = nil

            -- Add "!" header above checkbox column with tooltip, centered over checkboxes
            local exclaim_text_w = ImGui.CalcTextSize(ctx, "!")
            local center_offset = (checkbox_w - exclaim_text_w) / 2

            ImGui.BeginGroup(ctx)
            ImGui.Dummy(ctx, checkbox_w, 0)
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + center_offset)
            ImGui.AlignTextToFramePadding(ctx)
            ImGui.Text(ctx, "!")
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Enable visual countdown")
            end
            ImGui.EndGroup(ctx)
            ImGui.SameLine(ctx, 0, spacing + 12)

            ImGui.Dummy(ctx, track_number_w, 0)
            ImGui.SameLine(ctx, 0, spacing)
            for j = 1, #keys do
                ImGui.BeginGroup(ctx)
                local w = (j == 1) and title_box_w or normal_box_w
                ImGui.Dummy(ctx, w, 0)
                ImGui.AlignTextToFramePadding(ctx)
                ImGui.Text(ctx, labels[j])
                ImGui.EndGroup(ctx)
                if j < #keys then ImGui.SameLine(ctx, 0, spacing) end
            end

            ImGui.Dummy(ctx, 0, 5)

            for i = 0, item_count - 1 do
                local md = track_items_metadata[i]
                if md and md.isrc and md.isrc:match(isrc_pattern) then
                    first_isrc = md.isrc
                    break
                end
            end

            local any_changed = false
            local changed

            -- Reset selection and check for exactly one selected item
            selected_track_row = nil
            local selected_count = 0
            local current_selected_item = nil
            for check_i = 0, item_count - 1 do
                local check_item = GetTrackMediaItem(selected_track, check_i)
                if GetMediaItemInfo_Value(check_item, "B_UISEL") == 1 then
                    selected_count = selected_count + 1
                    if selected_count == 1 then
                        selected_track_row = check_i
                        current_selected_item = check_item
                    else
                        selected_track_row = nil
                        current_selected_item = nil
                        break
                    end
                end
            end

            -- Store selected item GUID when selection changes (don't force restore every frame)
            local _, stored_guid = GetProjExtState(0, "ReaClassical", "ddp_selected_item_guid")

            if current_selected_item then
                local _, item_guid = GetSetMediaItemInfo_String(current_selected_item, "GUID", "", false)
                if item_guid ~= stored_guid then
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", item_guid)
                end
            else
                -- No selection, clear the stored GUID
                if stored_guid ~= "" then
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", "")
                end
            end

            for i = 0, item_count - 1 do
                local item = GetTrackMediaItem(selected_track, i)
                local take = GetActiveTake(item)
                local md = track_items_metadata[i]
                if md then
                    -- Only show checkbox for tracks after the first one (i > 0)
                    if i > 0 then
                        -- Check if the actual item name has ! prefix
                        local _, actual_item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                        local has_exclamation = actual_item_name:match("^!")
                        local checkbox_state = has_exclamation ~= nil
                        local checkbox_changed
                        local checkbox_id = "##checkbox_" .. i .. "_" .. tostring(selected_track)
                        checkbox_changed, checkbox_state = ImGui.Checkbox(ctx, checkbox_id, checkbox_state)

                        if checkbox_changed then
                            -- Get current item name
                            local _, current_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                            local new_name

                            if checkbox_state then
                                -- Add ! prefix if not present
                                if not current_name:match("^!") then
                                    new_name = "!" .. current_name
                                end
                            else
                                -- Remove ! prefix if present
                                if current_name:match("^!") then
                                    new_name = current_name:gsub("^!", "")
                                end
                            end

                            -- Update item name if changed
                            if new_name then
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                                -- Recalculate CD markers
                                points = {}
                                Undo_BeginBlock()
                                run_create_cd_markers(selected_track)
                                Undo_EndBlock("Create CD/DDP Markers", -1)
                            end
                        end

                        ImGui.SameLine(ctx, 0, spacing)
                    else
                        -- For first track, add empty space where checkbox would be
                        ImGui.Dummy(ctx, checkbox_w, 0)
                        ImGui.SameLine(ctx, 0, spacing)
                    end

                    -- Track number with clickable selection
                    local track_number_str = string.format("%02d", track_number_counter)

                    -- Check if this row is selected
                    local is_selected_row = (selected_track_row == i)

                    -- Save cursor position
                    local cursor_x_before = ImGui.GetCursorPosX(ctx)
                    local cursor_y_before = ImGui.GetCursorPosY(ctx)

                    -- Draw track number text with color based on selection
                    if is_selected_row then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x56A0D3FF)
                    end
                    ImGui.Text(ctx, track_number_str)
                    if is_selected_row then
                        ImGui.PopStyleColor(ctx)
                    end

                    -- Create clickable area over the track number
                    ImGui.SetCursorPos(ctx, cursor_x_before, cursor_y_before)
                    ImGui.InvisibleButton(ctx, "##tracknum_" .. i, track_number_w + 10, ImGui.GetTextLineHeight(ctx))

                    -- Check if clicked
                    if ImGui.IsItemClicked(ctx) then
                        -- Deselect all items first
                        for j = 0, item_count - 1 do
                            local other_item = GetTrackMediaItem(selected_track, j)
                            SetMediaItemSelected(other_item, false)
                        end
                        -- Select only this item in REAPER
                        SetMediaItemSelected(item, true)
                        UpdateArrange()
                        -- Track the selected row
                        selected_track_row = i
                    end

                    ImGui.SameLine(ctx, 0, spacing)

                    local original_title = md.title
                    ImGui.PushItemWidth(ctx, title_box_w)
                    local title_widget_id = "##" .. i .. "_title_" .. tostring(selected_track)
                    changed, md.title = ImGui.InputText(ctx, title_widget_id, md.title or "", 128)
                    any_changed = any_changed or changed
                    ImGui.PopItemWidth(ctx)
                    if md.title == "" then md.title = original_title end

                    for j = 2, #keys do
                        ImGui.SameLine(ctx, 0, spacing)
                        ImGui.BeginGroup(ctx)
                        ImGui.PushItemWidth(ctx, normal_box_w)
                        local keys_widget_id = "##" .. i .. "_" .. keys[j] .. " " .. tostring(selected_track)
                        if keys[j] == "isrc" and not manual_isrc_entry and i > 0 then
                            ImGui.BeginDisabled(ctx)
                        end
                        changed, md[keys[j]] = ImGui.InputText(ctx, keys_widget_id, md[keys[j]] or "", 128)
                        if keys[j] == "isrc" and not manual_isrc_entry and i > 0 then
                            ImGui.EndDisabled(ctx)
                        end
                        any_changed = any_changed or changed

                        if keys[j] == "isrc" then
                            local prev_isrc = prev_isrc_values[i] or md.isrc -- default to current
                            if manual_isrc_entry then
                                -- In manual mode, validate after input
                                if changed then
                                    if md.isrc ~= "" and not md.isrc:match(isrc_pattern) then
                                        md.isrc = prev_isrc -- revert if invalid
                                    end
                                end
                            else
                                -- Auto-increment mode (existing logic)
                                if i == 0 then
                                    if md.isrc == "" then
                                        first_isrc = nil
                                    elseif md.isrc:match(isrc_pattern) then
                                        first_isrc = md.isrc
                                    else
                                        md.isrc = first_isrc or ""
                                    end
                                else
                                    if first_isrc then
                                        md.isrc = increment_isrc(first_isrc, track_number_counter - 1)
                                    else
                                        if md.isrc ~= "" and not md.isrc:match(isrc_pattern) then
                                            md.isrc = ""
                                        end
                                    end
                                end
                            end
                            -- Store current value as previous for next frame
                            prev_isrc_values[i] = md.isrc
                        end

                        ImGui.PopItemWidth(ctx)
                        ImGui.EndGroup(ctx)
                    end

                    if any_changed or first_run then
                        -- Get the original item name to check for ! prefix
                        local _, original_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                        local has_exclamation = original_name:match("^!")

                        local new_name = serialize_metadata(md, false)

                        -- Preserve ! prefix if it was there
                        if has_exclamation then
                            new_name = "!" .. new_name
                        end

                        GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                        update_marker_and_region(item)
                    end

                    track_number_counter = track_number_counter + 1
                    ImGui.Dummy(ctx, 0, 10)
                end
            end
            first_run = false
        else
            ImGui.Text(ctx, "No track selected. Please select a folder track to edit metadata.")
        end
        -- keyboard shortcut capture
        if not ImGui.IsAnyItemActive(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Y, false) then
            window_open = false
        end
        ImGui.End(ctx)
    end

    defer(editor_main)
end

---------------------------------------------------------------------
--                         ENTRY POINT
---------------------------------------------------------------------

-- Initial run: create CD markers, then open editor
local selected_track = GetSelectedTrack(0, 0)
if selected_track then
    points = {}
    Undo_BeginBlock()
    run_create_cd_markers(selected_track)
    Undo_EndBlock("Create CD/DDP Markers", -1)
end

defer(editor_main)