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

local CD_MARKER_COLOR = ColorToNative(230, 236, 245) | 0x1000000
local CD_REGION_COLOR = ColorToNative(201, 211, 227) | 0x1000000

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local snap_automation = require("ReaClassical_Snapshot_Automation")
local album_meta_store = require("ReaClassical_Album_Metadata")
local solo_first_folder = require("ReaClassical_Folder_Solo").solo_first_folder
local cover_art = require("ReaClassical_Cover_Art")

local run_create_cd_markers, run_create_cd_markers_inner, capture_item_selection
local get_info, cd_markers, find_current_start, create_marker
local renumber_markers, add_pregap, find_project_end, end_marker
local frame_check, delete_markers, remove_negative_position_items_from_folder
local delete_empty_items_from_folder, return_custom_length
local fade_equations, pos_check, is_item_start_crossfaded, is_item_end_crossfaded
local steps_by_length, generate_interpolated_fade, convert_fades_to_env, room_tone
local add_roomtone_fadeout, check_saved_state, album_item_count
local split_and_tag_final_item, recalculate
local check_first_track_for_names, delete_all_markers_and_regions
local shift_folder_items_and_markers, shift_all_markers_and_regions

local editor_main, parse_item_name, serialize_metadata, increment_isrc
local update_marker_and_region, update_album_marker, propagate_album_field
local track_has_valid_items, track_has_any_named_items, create_metadata_report_and_cue
local render_ddp_preset, render_cue_audio_preset, render_flac_preset, render_opus_preset
local render_mp3_preset, render_stems_preset
local open_render_dialog
local apply_render_metadata
local get_export_dir, get_active_folder_track

local minimum_points = 15
local points = {}

local _, digital_release_str = GetProjExtState(0, "ReaClassical", "digital_release_only")
local digital_release_only = digital_release_str == "1"

local render_settings = require("ReaClassical_Render_Settings")
local samplerate_list = render_settings.samplerate_list
local samplerate_labels = render_settings.samplerate_labels
local bitdepth_list = render_settings.bitdepth_list
local bitdepth_labels = render_settings.bitdepth_labels
local dither_list = render_settings.dither_list
local build_wav_format = render_settings.build_wav_format
local build_flac_format = render_settings.build_flac_format
local dither_value_for = render_settings.dither_value_for
local mp3_samplerate_for = render_settings.mp3_samplerate_for

local render_samplerate, render_bitdepth, render_dither = render_settings.load()

local render_range = require("ReaClassical_Render_Range")
local track_range_input = ""

local roomtone_import = require("ReaClassical_RoomTone_Import")
local enum_project_markers = require("ReaClassical_Marker_Enum")
local set_project_marker_by_index = require("ReaClassical_Marker_Set")
local br_env_properties = require("ReaClassical_BR_Envelope_Properties")

if not _G.RC_SCRIPT_ARGS and not _clara_or_debug then
    local imgui_exists = APIExists("ImGui_GetVersion")
    if not imgui_exists then
        MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
        return
    end
end

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

local ImGui, ctx

if not _G.RC_SCRIPT_ARGS and not _clara_or_debug then
    set_action_options(2)

    package.path = ImGui_GetBuiltinPath() .. '/?.lua'
    ImGui = require 'imgui' '0.10'

    ctx = ImGui.CreateContext('DDP Metadata Editor')
end

local window_open = true

local ddp_window_has_drawn = false

local labels = { "Title", "Performer", "Songwriter", "Composer", "Arranger", "Message", "ISRC" }
local keys = { "title", "performer", "songwriter", "composer", "arranger", "message", "isrc" }

local album_keys_line1 = { "title", "performer", "songwriter", "composer", "arranger" }
local album_labels_line1 = { "Album Title", "Performer", "Songwriter", "Composer", "Arranger" }
local album_keys_line2 = { "genre", "identification", "language", "catalog", "message" }
local album_labels_line2 = { "Genre", "Identification", "Language", "Catalog (EAN/UPC)", "Message" }

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
local album_metadata, album_legacy_item
local track_items_metadata = {}

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

function capture_item_selection()
    local items = {}
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            table.insert(items, item)
        end
    end
    return items
end

function run_create_cd_markers_inner(selected_track)
    if not _G.RC_SCRIPT_ARGS then
        local not_saved = check_saved_state()
        if not_saved then
            MB("Please save your project before running this function.", "Create CD Markers", 0)
            return false
        end
    end

    selected_track = GetTrack(0, 0)
    if not selected_track then
        MB("Error: No track selected.", "Create CD Markers", 0)
        return false
    end

    local empty_removed = delete_empty_items_from_folder(selected_track)
    if empty_removed > 0 then
        ShowConsoleMsg("Deleted " .. empty_removed .. " empty item(s) from first folder.\n")
    end

    solo_first_folder()

    local track_color = CD_MARKER_COLOR

    local num_of_items = 0
    if selected_track then num_of_items = album_item_count(selected_track) end
    if not selected_track or num_of_items == 0 then
        MB("Error: No media items found.", "Create CD Markers", 0)
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
    queue_ddp_warnings(validate_ddp_metadata(selected_track, num_of_items))
    PreventUIRefresh(1)
    room_tone(redbook_project_length * 60, selected_track)
    renumber_markers(track_color)
    PreventUIRefresh(-1)

    UpdateArrange()
    SetOnlyTrackSelected(selected_track)

    local _, converted = GetProjExtState(0, "ReaClassical", "SnapshotsConvertedToAutomation")
    if converted == "1" then
        snap_automation.convert_snapshots_to_automation()
    end

    return true
end

function run_create_cd_markers(selected_track)
    local saved_selection = capture_item_selection()
    local success = run_create_cd_markers_inner(selected_track)
    Main_OnCommand(40289, 0)
    for _, item in ipairs(saved_selection) do
        if ValidatePtr2(0, item, "MediaItem*") then
            SetMediaItemSelected(item, true)
        end
    end
    return success
end

function get_info(track)
    if not track then return nil end
    local str = album_meta_store.get_album_metadata_str(track)
    return str or false
end

function recalculate()
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

function cd_markers(selected_track, num_of_items, track_color)
    local album_metadata_str = get_info(selected_track)
    if not album_metadata_str then
        album_metadata_str = split_and_tag_final_item(selected_track)
    end

    delete_markers()

    SNM_SetIntConfigVar('projfrbase', 75)
    Main_OnCommand(40904, 0)
    Main_OnCommand(40754, 0)

    local pregap_len, offset, postgap = return_custom_length()

    if digital_release_only then
        offset = 0
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
        if take_name then
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
                            marker_count, CD_REGION_COLOR)
                    end
                    previous_start = current_start
                    previous_offset = final_offset
                    previous_takename = take_name
                    marker_count = marker_count + 1
                end
            end
        end
    end
    if marker_count == 0 then
        return false
    end
    if marker_count > 99 then
        redbook_total_tracks_error = true
    end
    local final_region_start = frame_check(previous_start - previous_offset)
    local final_region_end = frame_check(final_end) + postgap
    if final_region_end - final_region_start < 4 then
        redbook_track_length_errors = redbook_track_length_errors + 1
    end
    AddProjectMarker2(0, true, final_region_start, final_region_end,
        previous_takename:match("^[!]*([^|]*)"),
        marker_count, CD_REGION_COLOR)
    local redbook_project_length
    if marker_count ~= 0 then
        add_pregap(selected_track, track_color)
        redbook_project_length = end_marker(selected_track, album_metadata_str, postgap, num_of_items,
            track_color)
    end
    Main_OnCommand(40753, 0)
    return true, redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length
end

function find_current_start(selected_track, i)
    local current_item = GetTrackMediaItem(selected_track, i)
    local take = GetActiveTake(current_item)
    if not take then return nil, nil, 0 end

    local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    take_name = take_name:gsub("|$", "")

    local offset_str = take_name:match("|OFFSET=([%d%.%-]+)")
    local offset_val = offset_str and tonumber(offset_str) or 0

    if offset_str then
        take_name = take_name:gsub("|OFFSET=[%d%.%-]+", "|OFFSET=" .. offset_val)
    end
    GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name, true)

    local item_pos = GetMediaItemInfo_Value(current_item, "D_POSITION")
    return item_pos, take_name, offset_val, current_item
end

function create_marker(current_start, marker_count, take_name, offset, track_color, item)
    local added_marker = false
    if take_name ~= "" then
        local corrected_current_start = frame_check(current_start - offset)
        local clean_name = take_name:gsub("|OFFSET=[%d%.%-]+", "")
        local track_title = "#" .. clean_name:match("^[!]*(.+)")

        local marker_num = AddProjectMarker2(0, false, corrected_current_start, 0, track_title,
            marker_count + 1, track_color)
        added_marker = true

        if marker_num then
            local num_m = GetNumRegionsOrMarkers(0)
            for i = 0, num_m - 1 do
                local _, isrgn, _, _, _, markrgnindexnumber = enum_project_markers(0, i)
                if not isrgn and markrgnindexnumber == marker_num then
                    local _, guid = GetSetProjectInfo_String(0, "MARKER_GUID:" .. tostring(i), "", false)

                    GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", guid, true)

                    break
                end
            end
        end
    end
    return added_marker
end

function renumber_markers(track_color)
    local num_markers = GetNumRegionsOrMarkers(0)

    local markers = {}
    for i = 0, num_markers - 1 do
        local marker = GetRegionOrMarker(0, i, "")
        if marker and GetRegionOrMarkerInfo_Value(0, marker, "B_ISREGION") == 0 then
            local pos = GetRegionOrMarkerInfo_Value(0, marker, "D_STARTPOS")
            local _, name = GetSetRegionOrMarkerInfo_String(0, marker, "P_NAME", "", false)
            local _, guid = GetSetRegionOrMarkerInfo_String(0, marker, "GUID", "", false)
            markers[#markers + 1] = { pos = pos, name = name, guid = guid }
        end
    end

    for new_idx, m in ipairs(markers) do
        local marker = GetRegionOrMarker(0, -1, m.guid)
        if marker then
            SetRegionOrMarkerInfo_Value(0, marker, "I_NUMBER", new_idx - 1)
            SetRegionOrMarkerInfo_Value(0, marker, "I_CUSTOMCOLOR", track_color)
            GetSetRegionOrMarkerInfo_String(0, marker, "P_NAME", m.name, true)
        end
    end
end

function add_pregap(selected_track, track_color)
    local first_item_start, _ = find_current_start(selected_track, 0)
    local _, _, first_marker, _, _, _ = enum_project_markers(0, 0)
    local first_pregap
    if first_marker - first_item_start < 2 then
        first_pregap = -first_item_start + 2 -
            (first_marker - first_item_start)
    else
        first_pregap = -first_item_start
    end

    shift_folder_items_and_markers(selected_track, first_pregap)
    shift_all_markers_and_regions(first_pregap)

    AddProjectMarker2(0, false, 0, 0, "!", 0, track_color)
    SNM_SetDoubleConfigVar('projtimeoffs', 0)
end

function find_project_end(selected_track, num_of_items)
    local final_item = GetTrackMediaItem(selected_track, num_of_items - 1)
    local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
    local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
    return final_start + final_length
end

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

function frame_check(pos)
    if digital_release_only then
        return pos
    end

    local cd_fps = 75

    local nearest_grid = math.floor(pos * cd_fps + 0.5) / cd_fps

    if math.abs(pos - nearest_grid) > 1e-12 then
        nearest_grid = math.floor(pos * cd_fps) / cd_fps
    end

    return nearest_grid
end

function delete_markers()
    delete_all_markers_and_regions()
    Main_OnCommand(40182, 0)
    Main_OnCommand(42387, 0)
    Main_OnCommand(40289, 0)
end

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

function pos_check(item, selected_track)
    local item_number = GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    local item_start_crossfaded = is_item_start_crossfaded(selected_track, item_number)
    local item_end_crossfaded = is_item_end_crossfaded(selected_track, item_number)
    return item_start_crossfaded, item_end_crossfaded
end

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

function steps_by_length(length)
    if ((length * 10) < minimum_points) then
        return minimum_points
    else
        return length * 10
    end
end

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

        local end_val = 0
        if is_fade_in then
            local _, value = Envelope_Evaluate(env, end_time, 44100, 128)
            end_val = ScaleFromEnvelopeMode(is_scale, value)
        end
        local val = ScaleToEnvelopeMode(is_scale, end_val)
        table.insert(values, val)
        table.insert(times, item_pos + end_time)

        if sort then Envelope_SortPoints(env) end

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
    br_env_properties.set(env, false, false, false, false, 0, 0, true)
    local fade_in_start = 0
    local fade_out_start = item_length - fade_out_length

    local item_start_crossfaded, item_end_crossfaded = pos_check(item, selected_track)

    if fade_in_length > 0 and not item_start_crossfaded then
        generate_interpolated_fade(item_pos, env, fade_in_start, fade_in_length, fade_in_shape, fade_in_curvature, true,
            false)
    end
    if fade_out_length > 0 and not item_end_crossfaded then
        generate_interpolated_fade(item_pos, env, fade_out_start, item_length, fade_out_shape, fade_out_curvature, false,
            false)
    end
    Envelope_SortPoints(env)
end

function fade_equations()
    local fade_table = {}

    fade_table.fade_calc = function(fade_type, time, start_time, end_time, curve, is_fade_in)
        if end_time <= start_time then return 1 end
        time = time < start_time and start_time or time > end_time and end_time or time

        local pos = (time - start_time) / (end_time - start_time)

        local fade_func = fade_table.fadein[fade_type]

        if not fade_func then
            MB("Error: Invalid fade_type:" .. fade_type, "RoomTone Automation", 0)
            return 0
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

    local rt_item = roomtone_import.ensure_item(rt_track)
    if rt_item then
        local short_by = roomtone_import.resize_to(rt_item, project_length)
        if short_by > 0 then
            local msg = string.format(
                "RoomTone audio doesn't cover the full album -- short by %.1f seconds", short_by)
            say(msg)
            if not (APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed) then
                queue_extra_warning(msg, "RoomTone")
            end
        end
    end

    Main_OnCommand(40769, 0)

    for i = 0, num_of_selected_track_items - 1 do
        local item = GetTrackMediaItem(selected_track, i)
        SetMediaItemSelected(item, 1)
    end

    Main_OnCommand(40693, 0)
    Main_OnCommand(40693, 0)

    for i = 0, num_of_selected_track_items - 1 do
        local item = GetTrackMediaItem(selected_track, i)
        convert_fades_to_env(item, selected_track)
    end

    SetOnlyTrackSelected(rt_track)
    Main_OnCommand(41866, 0)
    Main_OnCommand(40332, 0)
    Main_OnCommand(40333, 0)

    local rt_vol = GetTrackEnvelopeByName(rt_track, "Volume")
    br_env_properties.set(rt_vol, true, true, true, true, 0, 0, true)

    for _, val in pairs(points) do
        InsertEnvelopePoint(rt_vol, val.time, val.value, 0, 1, false, false)
    end

    add_roomtone_fadeout(rt_track, project_length)

    Main_OnCommand(40769, 0)
end

function add_roomtone_fadeout(rt_track, project_length)
    local rt_vol = GetTrackEnvelopeByName(rt_track, "Volume")
    if not rt_vol then
        rt_vol = GetTrackEnvelope(rt_track, 0)
    end

    local max_value = 716.21785031261

    local fade_start = project_length - 4.0
    local fade_end = fade_start + 2.0

    local num_points = 10

    for i = 0, num_points do
        local t = i / num_points
        local time = fade_start + t * (fade_end - fade_start)
        local value = max_value * (1 - (t ^ 2 * (3 - 2 * t)))
        InsertEnvelopePoint(rt_vol, time, value, 0, 1, false, false)
    end

    Envelope_SortPoints(rt_vol)
end

function check_saved_state()
    local full_project_name = GetProjectName(0)
    return full_project_name == ""
end

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

        if start - prev_end > 60 then
            break
        end

        count = count + 1
        prev_end = start + GetMediaItemInfo_Value(item, "D_LENGTH")
    end

    return count
end

function split_and_tag_final_item(track)
    if not track then return end

    local item_name = "@MyAlbumTitle|COMPOSER=Various|PERFORMER=Various|MESSAGE=Created with ReaClassical"
    album_meta_store.set_album_metadata_str(track, item_name, nil)
    return item_name
end

function check_first_track_for_names(track)
    if not track then
        MB("No track found", "Error", 0)
        return false
    end

    local itemCount = CountTrackMediaItems(track)
    if itemCount == 0 then
        MB("No items on the first track", "Error", 0)
        return false
    end

    local prevEnd = nil

    for i = 0, itemCount - 1 do
        local item = GetTrackMediaItem(track, i)
        local itemStart = GetMediaItemInfo_Value(item, "D_POSITION")
        local itemEnd = itemStart + GetMediaItemInfo_Value(item, "D_LENGTH")

        if prevEnd and (itemStart - prevEnd) > 60 then
            break
        end
        prevEnd = itemEnd

        local takeCount = CountTakes(item)
        for t = 0, takeCount - 1 do
            local take = GetMediaItemTake(item, t)
            if take then
                local takeName = GetTakeName(take)
                if takeName ~= "" and string.sub(takeName, 1, 1) ~= "@" then
                    return true
                end
            end
        end
    end

    MB(
        "Please add take names to items on the first folder's parent track (press N then select an item).",
        "No track markers created",
        0
    )
    return false
end

function delete_all_markers_and_regions()
    local num_markers = GetNumRegionsOrMarkers(0)
    local total = num_markers

    for i = total - 1, 0, -1 do
        local retval, is_region, pos, rgnend, name, markrgnindexnumber =
            enum_project_markers(0, i)

        if retval then
            DeleteProjectMarker(0, markrgnindexnumber, is_region)
        end
    end
end

function shift_folder_items_and_markers(parent_track, shift_amount)
    if not parent_track or shift_amount == 0 then return end

    local tracks_to_shift = { parent_track }
    local folder_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")

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

    local all_tracks = {}
    for i = 0, CountTracks(0) - 1 do
        table.insert(all_tracks, GetTrack(0, i))
    end

    for _, tr in ipairs(all_tracks) do
        local num_envs = CountTrackEnvelopes(tr)
        for e = 0, num_envs - 1 do
            local env = GetTrackEnvelope(tr, e)

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

            local num_ai = CountAutomationItems(env)
            for ai = 0, num_ai - 1 do
                local ai_pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
                GetSetAutomationItemInfo(env, ai, "D_POSITION", ai_pos + shift_amount, true)
            end
        end
    end

    local folder_items = {}
    for _, tr in ipairs(tracks_to_shift) do
        local num_items = CountTrackMediaItems(tr)
        for i = 0, num_items - 1 do
            table.insert(folder_items, GetTrackMediaItem(tr, i))
        end
    end

    if shift_amount > 0 then
        for i = #folder_items, 1, -1 do
            local item = folder_items[i]
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", pos + shift_amount)
        end
    else
        for i = 1, #folder_items do
            local item = folder_items[i]
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", pos + shift_amount)
        end
    end
end

function shift_all_markers_and_regions(shift_amount)
    if not shift_amount or shift_amount == 0 then return end

    local markers = {}
    local num_markers = GetNumRegionsOrMarkers(0)
    local total = num_markers

    for i = 0, total - 1 do
        local _, isrgn, pos, rgnend, name, idx, color = enum_project_markers(0, i)
        markers[#markers + 1] = {
            isrgn = isrgn,
            pos = pos,
            rgnend = rgnend,
            name = name,
            idx = idx,
            color = color
        }
    end

    for _, m in ipairs(markers) do
        DeleteProjectMarker(0, m.idx, m.isrgn)
    end

    for _, m in ipairs(markers) do
        if m.isrgn then
            AddProjectMarker2(0, true, m.pos + shift_amount, m.rgnend + shift_amount, m.name, -1, m.color)
        else
            AddProjectMarker2(0, false, m.pos + shift_amount, 0, m.name, -1, m.color)
        end
    end
end

function remove_negative_position_items_from_folder(parent_track)
    if not parent_track then return 0 end

    local tracks_to_clean = { parent_track }
    local folder_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")

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

function delete_empty_items_from_folder(parent_track)
    if not parent_track then return 0 end

    local tracks_to_clean = { parent_track }
    local folder_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")

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
            if not GetActiveTake(item) then
                DeleteTrackMediaItem(track, item)
                removed_count = removed_count + 1
            end
        end
    end

    return removed_count
end

function parse_item_name(name, is_album)
    local data = {}
    local parts = {}
    for part in name:gmatch("[^|]+") do table.insert(parts, part) end
    if #parts > 0 then
        if is_album then
            data.title = parts[1]:gsub("^@", "")
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
            local title_part = parts[1] or name
            data.title = title_part:gsub("^!", "")
            for i = 2, #parts do
                local k, v = parts[i]:match("^(%w+)=(.+)$")
                if k and v then
                    k = k:lower()
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
        if is_album then
            data.genre = "Classical"
            data.language = "English"
        end
    end
    return data
end

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

function increment_isrc(isrc, offset)
    local prefix, year, seq = isrc:match("^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$")
    if not prefix or not year or not seq then return isrc end
    local new_seq = tonumber(seq) + offset
    return string.format("%s%s%05d", prefix, year, new_seq)
end

function catalog_checksum_valid(catalog)
    local sum = 0
    local weight = 3
    for i = #catalog - 1, 1, -1 do
        sum = sum + tonumber(catalog:sub(i, i)) * weight
        weight = weight == 3 and 1 or 3
    end
    local expected = (10 - (sum % 10)) % 10
    return expected == tonumber(catalog:sub(-1))
end

function catalog_is_valid(v)
    return v == "" or (v:match("^%d+$") ~= nil and (#v == 12 or #v == 13) and catalog_checksum_valid(v))
end

function isrc_is_valid(v)
    return v == "" or v:match(isrc_pattern) ~= nil
end

local function has_control_chars(str)
    return str:find("%c") ~= nil
end

local function escape_control_chars(str)
    return (str:gsub("%c", function(c)
        if c == "\r" then return "\\r" end
        if c == "\n" then return "\\n" end
        if c == "\t" then return "\\t" end
        return string.format("\\x%02X", c:byte())
    end))
end

local function find_non_latin1_chars(str)
    local bad, seen = {}, {}
    local ok = pcall(function()
        for _, cp in utf8.codes(str) do
            if cp < 0x20 or cp == 0x7F then
            elseif not ((cp >= 0x20 and cp <= 0x7E) or (cp >= 0xA0 and cp <= 0xFF)) then
                local ch = utf8.char(cp)
                if not seen[ch] then
                    seen[ch] = true
                    bad[#bad + 1] = ch
                end
            end
        end
    end)
    if not ok and not seen["<invalid encoding>"] then
        seen["<invalid encoding>"] = true
        bad[#bad + 1] = "invalid encoding"
    end
    return bad
end

local function latin1_field_problem(v)
    if not v or v == "" then return nil end
    if has_control_chars(v) then
        return "Contains an embedded line break or other control character -- "
            .. "CD-Text/AMF fields must be a single line."
    end
    local bad = find_non_latin1_chars(v)
    if #bad > 0 then
        return "Not representable in CD-Text (Latin-1 only): " .. table.concat(bad, ", ")
    end
    return nil
end

local function flag_latin1_problem(ctx, problem)
    if problem and ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, problem)
    end
end

function validate_ddp_metadata(selected_track, num_of_items)
    local latin1_lines = {}
    local control_char_lines = {}
    local isrc_seen = {}
    local isrc_dupes = {}
    local empty_title_tracks = {}

    local album_str = get_info(selected_track)
    local album = album_str and parse_item_name(album_str, true) or {}
    local album_fields = { "title", "performer", "songwriter", "composer", "arranger", "message", "identification" }
    for _, field in ipairs(album_fields) do
        local v = album[field]
        if v and v ~= "" then
            if has_control_chars(v) then
                control_char_lines[#control_char_lines + 1] = string.format('Album %s: "%s"',
                    field:gsub("^%l", string.upper), escape_control_chars(v))
            end
            local bad = find_non_latin1_chars(v)
            if #bad > 0 then
                latin1_lines[#latin1_lines + 1] = string.format('Album %s: "%s" (%s)',
                    field:gsub("^%l", string.upper), escape_control_chars(v), table.concat(bad, ", "))
            end
        end
    end

    local track_fields = { "title", "performer", "songwriter", "composer", "arranger", "message" }
    for i = 0, num_of_items - 1 do
        local _, take_name = find_current_start(selected_track, i)
        if take_name and take_name ~= "" and not take_name:match("^@") then
            local track = parse_item_name(take_name, false)
            local track_num = i + 1

            for _, field in ipairs(track_fields) do
                local v = track[field]
                if v and v ~= "" then
                    if has_control_chars(v) then
                        control_char_lines[#control_char_lines + 1] = string.format('Track %d %s: "%s"',
                            track_num, field:gsub("^%l", string.upper), escape_control_chars(v))
                    end
                    local bad = find_non_latin1_chars(v)
                    if #bad > 0 then
                        latin1_lines[#latin1_lines + 1] = string.format('Track %d %s: "%s" (%s)',
                            track_num, field:gsub("^%l", string.upper), escape_control_chars(v),
                            table.concat(bad, ", "))
                    end
                end
            end

            if not track.title or track.title:match("^%s*$") then
                empty_title_tracks[#empty_title_tracks + 1] = track_num
            end

            if track.isrc and track.isrc ~= "" then
                if isrc_seen[track.isrc] then
                    isrc_dupes[track.isrc] = isrc_dupes[track.isrc] or { isrc_seen[track.isrc] }
                    table.insert(isrc_dupes[track.isrc], track_num)
                else
                    isrc_seen[track.isrc] = track_num
                end
            end
        end
    end

    local warnings = {}

    if #control_char_lines > 0 then
        warnings[#warnings + 1] = "The following text contains an embedded line break or other control "
            .. "character (CD-Text/AMF fields must be a single line):\n\n" .. table.concat(control_char_lines, "\n")
    end

    if #latin1_lines > 0 then
        warnings[#warnings + 1] = "The following text isn't representable in CD-Text (Latin-1 only) and may not "
            .. "display correctly:\n\n" .. table.concat(latin1_lines, "\n")
    end

    if next(isrc_dupes) then
        local lines = {}
        for isrc, tracks in pairs(isrc_dupes) do
            lines[#lines + 1] = isrc .. " (tracks " .. table.concat(tracks, ", ") .. ")"
        end
        warnings[#warnings + 1] = "The same ISRC is used on more than one track:\n\n" .. table.concat(lines, "\n")
            .. "\n\nThis isn't a DDP spec violation, but is non-standard replicator practice."
    end

    if #empty_title_tracks > 0 then
        warnings[#warnings + 1] = "The following track(s) have no title:\n\nTrack "
            .. table.concat(empty_title_tracks, ", ")
    end

    return warnings
end

function queue_ddp_warnings(warnings)
    if warnings and #warnings > 0 then
        _G.RC_DDP_PENDING_WARNINGS = warnings
    end
end

function queue_extra_warning(text, title)
    local queue = _G.RC_DDP_PENDING_WARNINGS or {}
    for _, existing in ipairs(queue) do
        if (type(existing) == "table" and existing.text or existing) == text then return end
    end
    queue[#queue + 1] = { text = text, title = title }
    _G.RC_DDP_PENDING_WARNINGS = queue
end

function show_pending_ddp_warnings()
    local warnings = _G.RC_DDP_PENDING_WARNINGS
    if not warnings then return end
    _G.RC_DDP_PENDING_WARNINGS = nil
    for _, warning in ipairs(warnings) do
        if type(warning) == "table" then
            MB(warning.text, warning.title or "CD-Text Warning", 0)
        else
            MB(warning, "CD-Text Warning", 0)
        end
    end
end

function serialize_album_metadata_safe()
    local displayed_catalog = album_metadata.catalog
    if displayed_catalog and not catalog_is_valid(displayed_catalog) then
        album_metadata.catalog = ""
    end
    local new_name = serialize_metadata(album_metadata, true)
    album_metadata.catalog = displayed_catalog
    return new_name
end

function serialize_track_metadata_safe(md)
    local displayed_isrc = md.isrc
    if displayed_isrc and not isrc_is_valid(displayed_isrc) then
        md.isrc = ""
    end
    local new_name = serialize_metadata(md, false)
    md.isrc = displayed_isrc
    return new_name
end

function update_marker_and_region(item)
    if not item then return end

    local take = GetActiveTake(item)
    if not take then return end

    local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not item_name or item_name == "" then return end

    local clean_name = item_name:gsub("|OFFSET=[%d%.%-]+", "")

    local track = GetMediaItemTrack(item)
    local track_color = GetTrackColor(track)

    local ok, guid = GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", "", false)
    if not ok or guid == "" then return end

    local ok_index, mark_index_str = GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. guid, "", false)
    if not ok_index or mark_index_str == "" then return end

    local mark_index = tonumber(mark_index_str)
    if not mark_index then return end

    local retval, isrgn, pos, _, _, markrgnID, color = enum_project_markers(0, mark_index)
    if retval and not isrgn and (track_color == color or color == CD_MARKER_COLOR) then
        set_project_marker_by_index(0, mark_index, false, pos, 0, markrgnID, "#" .. clean_name, color)
    end

    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local num_markers = GetNumRegionsOrMarkers(0)

    for idx = 0, num_markers - 1 do
        local _, isrgn, pos, rgnend, _, markrgnID, color = enum_project_markers(0, idx)
        if isrgn and item_pos >= pos and item_pos < rgnend then
            if track_color == color or color == CD_REGION_COLOR then
                set_project_marker_by_index(0, idx, true, pos, rgnend, markrgnID,
                    parse_item_name(clean_name, false).title, color)
            end
            break
        end
    end
end

function update_album_marker(item_name)
    if not item_name or not item_name:match("^@") then return end

    local num_markers = GetNumRegionsOrMarkers(0)
    for idx = 0, num_markers - 1 do
        local _, isrgn, pos, _, name, markrgnID, color = enum_project_markers(0, idx)
        if not isrgn and name:match("^@") then
            set_project_marker_by_index(0, idx, false, pos, 0, markrgnID, item_name, color)
            break
        end
    end
end

function propagate_album_field(field)
    local val, mixed = nil, false

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

    local desired = nil
    if val then
        desired = mixed and "Various" or val
    end

    album_metadata[field] = desired
end

function track_has_valid_items(track)
    if not track then return false end
    if CountTrackMediaItems(track) == 0 then return false end
    return album_meta_store.get_album_metadata_str(track) ~= nil
end

function track_has_any_named_items(track)
    if not track then return false end
    local item_count = CountTrackMediaItems(track)
    if item_count == 0 then return false end
    for i = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if name and name:match("%S") then return true end
        end
    end
    return false
end

function create_metadata_report_and_cue()
    dofile(script_path .. "lib/ReaClassical_Metadata Report.lua")
end

function get_active_folder_track()
    local track = GetTrack(0, 0)
    if not track then return nil, true end
    return track, false
end

function get_export_dir()
    local slash = package.config:sub(1, 1)
    local abs_dir = GetProjectPath() .. slash .. "Exports"
    RecursiveCreateDirectory(abs_dir, 0)

    return "Exports/"
end

function apply_render_metadata()
    local proj = 0
    local folder_track = get_active_folder_track()
    local genre = "Classical"
    local album_title, album_performer, album_catalog

    if folder_track then
        local album_str = get_info(folder_track)
        if album_str then
            local album = parse_item_name(album_str, true)
            if album.genre and album.genre ~= "" then genre = album.genre end
            album_title = album.title
            album_performer = album.performer
            album_catalog = album.catalog
        end
    end

    local function tag(key, value)
        GetSetProjectInfo_String(proj, "RENDER_METADATA", key .. "|" .. value, true)
    end

    tag("APE:Artist", "$marker(PERFORMER)[|]")
    tag("APE:Composer", "$marker(COMPOSER)[|]")
    tag("APE:Genre", genre)
    tag("APE:ISRC", "$marker(ISRC)[|]")
    tag("APE:Title", "$region")
    tag("APE:Track", "$markernumber")
    tag("ASWG:artist", "$marker(PERFORMER)[|]")
    tag("ASWG:composer", "$marker(COMPOSER)[|]")
    tag("ASWG:genre", genre)
    tag("ASWG:isrcId", "$marker(ISRC)[|]")
    tag("ASWG:project", "$region")
    tag("AXML:ISRC", "$marker(ISRC)[|]")
    tag("CAFINFO:artist", "$marker(PERFORMER)[|]")
    tag("CAFINFO:composer", "$marker(COMPOSER)[|]")
    tag("CAFINFO:genre", genre)
    tag("CAFINFO:title", "$region")
    tag("CAFINFO:track number", "$markernumber")
    tag("CART:Artist", "$marker(PERFORMER)[|]")
    tag("CART:Category", genre)
    tag("CART:CutID", "$markernumber")
    tag("CART:Title", "$region")
    tag("CUE:DISC_PERFORMER", "$marker(PERFORMER)[|]")
    tag("CUE:DISC_TITLE", "$region")
    tag("CUE:INDEX", "$markernumber")
    tag("ID3:TCOM", "$marker(COMPOSER)[|]")
    tag("ID3:TCON", genre)
    tag("ID3:TIT2", "$region")
    tag("ID3:TPE1", "$marker(PERFORMER)[|]")
    tag("ID3:TRCK", "$markernumber")
    tag("ID3:TSRC", "$marker(ISRC)[|]")
    tag("IFF:AUTH", "$marker(PERFORMER)[|]")
    tag("IFF:NAME", "$region")
    tag("INFO:IART", "$marker(PERFORMER)[|]")
    tag("INFO:IGNR", genre)
    tag("INFO:INAM", "$region")
    tag("INFO:TRCK", "$markernumber")
    tag("IXML:PROJECT", "$region")
    tag("VORBIS:ARTIST", "$marker(PERFORMER)[|]")
    tag("VORBIS:COMPOSER", "$marker(COMPOSER)[|]")
    tag("VORBIS:GENRE", genre)
    tag("VORBIS:ISRC", "$marker(ISRC)[|]")
    tag("VORBIS:PERFORMER", "$marker(PERFORMER)[|]")
    tag("VORBIS:TITLE", "$region")
    tag("VORBIS:TRACKNUMBER", "$markernumber")
    tag("XMP:dc/title", "$region")
    tag("XMP:dm/artist", "$marker(PERFORMER)[|]")
    tag("XMP:dm/composer", "$marker(COMPOSER)[|]")
    tag("XMP:dm/genre", genre)
    tag("XMP:dm/trackNumber", "$markernumber")

    if album_title and album_title ~= "" then
        tag("ID3:TALB", album_title)
        tag("VORBIS:ALBUM", album_title)
        tag("INFO:IPRD", album_title)
        tag("APE:Album", album_title)
    end
    if album_performer and album_performer ~= "" then
        tag("ID3:TPE2", album_performer)
        tag("VORBIS:ALBUMARTIST", album_performer)
        tag("APE:Album Artist", album_performer)
    end
    if album_catalog and album_catalog ~= "" then
        tag("ID3:TXXX:CATALOGNUMBER", album_catalog)
        tag("VORBIS:CATALOGNUMBER", album_catalog)
        tag("APE:Catalog", album_catalog)
    end

    local cover_path = cover_art.find()
    if cover_path then
        tag("ID3:APIC_FILE", cover_path)
        tag("ID3:APIC_TYPE", "3")
        tag("ID3:APIC_DESC", "Cover")
        tag("FLACPIC:APIC_FILE", cover_path)
        tag("FLACPIC:APIC_TYPE", "3")
        tag("FLACPIC:APIC_DESC", "Cover")
    end
end

function render_ddp_preset()
    solo_first_folder()
    local proj = 0

    local fmt = string.char(0x20, 0x70, 0x64, 0x64)
    GetSetProjectInfo_String(proj, "RENDER_FORMAT", fmt, true)

    GetSetProjectInfo(proj, "RENDER_SRATE", 44100, true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 1, true)

    local export_dir = get_export_dir()
    GetSetProjectInfo_String(proj, "RENDER_FILE", export_dir .. "DDP", true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "IMAGE.DAT", true)

    GetSetProjectInfo(proj, "RENDER_SETTINGS", 0, true)
    GetSetProjectInfo(proj, "RENDER_DITHER",   1, true)

    Main_OnCommand(42230, 0)
end

function render_cue_audio_preset()
    solo_first_folder()
    local proj = 0

    GetSetProjectInfo_String(proj, "RENDER_FORMAT", build_wav_format(render_bitdepth), true)

    GetSetProjectInfo(proj, "RENDER_SRATE", render_samplerate, true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 1, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS", 0, true)
    GetSetProjectInfo(proj, "RENDER_DITHER", dither_value_for(render_bitdepth, render_dither), true)

    local export_dir = get_export_dir()
    GetSetProjectInfo_String(proj, "RENDER_FILE", export_dir .. "Audio+CUE", true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$project", true)

    Main_OnCommand(42230, 0)
end

function render_wav_preset()
    solo_first_folder()
    local proj = 0

    GetSetProjectInfo_String(proj, "RENDER_FORMAT", build_wav_format(render_bitdepth), true)

    GetSetProjectInfo(proj, "RENDER_SRATE", render_samplerate, true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS", 512, true)
    GetSetProjectInfo(proj, "RENDER_DITHER", dither_value_for(render_bitdepth, render_dither), true)

    local export_dir = get_export_dir()
    GetSetProjectInfo_String(proj, "RENDER_FILE", export_dir, true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$format_$samplerate_$bitdepth/$regionnumber $region", true)

    apply_render_metadata()
    Main_OnCommand(42230, 0)
end

function render_flac_preset()
    solo_first_folder()
    local proj = 0

    GetSetProjectInfo_String(proj, "RENDER_FORMAT", build_flac_format(render_bitdepth), true)

    GetSetProjectInfo(proj, "RENDER_SRATE", render_samplerate, true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS", 512, true)
    GetSetProjectInfo(proj, "RENDER_DITHER", dither_value_for(render_bitdepth, render_dither), true)

    local export_dir = get_export_dir()
    GetSetProjectInfo_String(proj, "RENDER_FILE", export_dir, true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$format_$samplerate_$bitdepth/$regionnumber $region", true)

    apply_render_metadata()
    Main_OnCommand(42230, 0)
end

function render_opus_preset()
    solo_first_folder()
    local proj = 0

    GetSetProjectInfo_String(proj, "RENDER_FORMAT", "U2dnTwAAIEMACgAAAAIAAAA=", true)

    GetSetProjectInfo(proj, "RENDER_SRATE", 48000, true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS", 512, true)

    local export_dir = get_export_dir()
    GetSetProjectInfo_String(proj, "RENDER_FILE", export_dir, true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$format_160/$regionnumber $region", true)

    apply_render_metadata()
    Main_OnCommand(42230, 0)
end

function render_mp3_preset()
    solo_first_folder()
    local proj = 0

    GetSetProjectInfo_String(proj, "RENDER_FORMAT", "bDNwbUABAAAAAAAAAgAAAP////8EAAAAQAEAAAAAAAA=", true)

    GetSetProjectInfo(proj, "RENDER_SRATE", mp3_samplerate_for(render_samplerate), true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS", 512, true)

    local export_dir = get_export_dir()
    GetSetProjectInfo_String(proj, "RENDER_FILE", export_dir, true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$format_320/$regionnumber $region", true)

    apply_render_metadata()
    Main_OnCommand(42230, 0)
end

function render_stems_preset()
    solo_first_folder()
    local proj = 0

    GetSetProjectInfo_String(proj, "RENDER_FORMAT", build_wav_format(render_bitdepth), true)

    GetSetProjectInfo(proj, "RENDER_SRATE", render_samplerate, true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS", 128 | 512, true)
    GetSetProjectInfo(proj, "RENDER_DITHER", dither_value_for(render_bitdepth, render_dither), true)

    local export_dir = get_export_dir()
    GetSetProjectInfo_String(proj, "RENDER_FILE", export_dir, true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN",
        "Stems_$format_$samplerate_$bitdepth/$regionnumber $region - $track", true)

    apply_render_metadata()

    Main_OnCommand(40297, 0)
    local mixer_count = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            SetTrackSelected(track, true)
            mixer_count = mixer_count + 1
        end
    end

    if mixer_count == 0 then
        say("No mixer tracks found to render stems from")
        SetOnlyTrackSelected(GetTrack(0, 0))
        return
    end

    Main_OnCommand(42230, 0)

    SetOnlyTrackSelected(GetTrack(0, 0))
end

function open_render_dialog()
    solo_first_folder()
    apply_render_metadata()
    local SOURCE_BITS = 1 | 2 | 8 | 32 | 64 | 128 | 4096
    local current_settings = GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
    GetSetProjectInfo(0, "RENDER_SETTINGS", (math.floor(current_settings) & ~SOURCE_BITS) | 512, true)
    GetSetProjectInfo(0, "RENDER_SRATE", render_samplerate, true)
    GetSetProjectInfo_String(0, "RENDER_FORMAT", build_wav_format(render_bitdepth), true)
    GetSetProjectInfo(0, "RENDER_DITHER", dither_value_for(render_bitdepth, render_dither), true)
    Main_OnCommand(40015, 0)
end

function editor_main()
    if not window_open then
        create_metadata_report_and_cue()
        return
    end

    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    if gui_mode.accessible() then
        create_metadata_report_and_cue()
        gui_mode.switch_window("ReaClassical_Create CD Markers.lua")
        return
    end

    if ddp_window_has_drawn then
        show_pending_ddp_warnings()
    end

    local _, FLT_MAX = ImGui.NumericLimits_Float()
    ImGui.SetNextWindowSizeConstraints(ctx, 1200, 500, FLT_MAX, FLT_MAX)
    local opened, open_ref = ImGui.Begin(ctx, "ReaClassical DDP Metadata Editor", window_open)
    window_open = open_ref

    if opened then
        ddp_window_has_drawn = true
        local selected_track, no_folder_found = get_active_folder_track()
        if no_folder_found then
            ImGui.Text(ctx, "This project has no tracks yet.")
        elseif selected_track and not track_has_valid_items(selected_track) then
            if track_has_any_named_items(selected_track) then
                ImGui.TextWrapped(ctx,
                    "This folder hasn't been designated as a CD album yet. " ..
                    "Please close (press Y) and re-open the DDP Metadata Editor to set it up.")
            else
                ImGui.Text(ctx, "No valid item names found for DDP metadata editing.")
            end
        elseif selected_track then
            local _, trigger = GetProjExtState(0, "ReaClassical", "ddp_refresh_trigger")
            if trigger == "y" then
                editing_track = nil
                SetProjExtState(0, "ReaClassical", "ddp_refresh_trigger", "")
            end

            if pending_reinit then
                editing_track = nil
                pending_reinit = false
            end

            if editing_track ~= selected_track then
                local is_track_switch = (editing_track ~= nil)

                editing_track = selected_track
                selected_track_row = nil

                if is_track_switch then
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", "")
                end

                points = {}

                Undo_BeginBlock()
                run_create_cd_markers(selected_track)
                Undo_EndBlock("Create CD/DDP Markers", -1)

                create_metadata_report_and_cue()
                album_metadata, album_legacy_item = nil, nil
                local album_str, legacy_item = album_meta_store.get_album_metadata_str(selected_track)
                if album_str then
                    album_metadata = parse_item_name(album_str, true)
                    album_legacy_item = legacy_item
                end

                track_items_metadata = {}
                local item_count = CountTrackMediaItems(selected_track)
                local prev_end
                for i = 0, item_count - 1 do
                    local item = GetTrackMediaItem(selected_track, i)
                    local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                    if prev_end and (item_start - prev_end) > 60 then
                        break
                    end
                    prev_end = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")

                    local take = GetActiveTake(item)
                    local name = take and select(2, GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)) or ""
                    if name and name:match("%S") and not name:match("^@") then
                        track_items_metadata[i] = parse_item_name(name, false)
                    end
                end

                local _, stored_guid = GetProjExtState(0, "ReaClassical", "ddp_selected_item_guid")
                local any_item_selected = false
                for i = 0, CountMediaItems(0) - 1 do
                    if IsMediaItemSelected(GetMediaItem(0, i)) then
                        any_item_selected = true
                        break
                    end
                end
                if stored_guid ~= "" and not any_item_selected then
                    local found = false
                    for i = 0, item_count - 1 do
                        local item = GetTrackMediaItem(selected_track, i)
                        local _, item_guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
                        if item_guid == stored_guid then
                            if GetMediaItemInfo_Value(item, "B_UISEL") ~= 1 then
                                Main_OnCommand(40289, 0)
                                SetMediaItemSelected(item, true)
                                UpdateArrange()
                            end
                            found = true
                            break
                        end
                    end
                    if not found then
                        SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", "")
                    end
                end
            end

            local function commit_album_metadata()
                local new_name = serialize_album_metadata_safe()
                album_meta_store.set_album_metadata_str(selected_track, new_name, album_legacy_item)
                update_album_marker(new_name)
            end

            local force_writeback = {}

            local TRACK_ALBUM_SHARED_KEYS = {
                performer = true, songwriter = true, composer = true,
                arranger = true, message = true,
            }

            local function album_copy_context_menu(key)
                if ImGui.BeginPopupContextItem(ctx, "##albumctx_" .. key) then
                    local val = album_metadata[key]
                    if ImGui.MenuItem(ctx, "Copy to all tracks", nil, false, val ~= nil and val ~= "") then
                        for j = 0, CountTrackMediaItems(selected_track) - 1 do
                            local md = track_items_metadata[j]
                            if md then
                                md[key] = val
                                force_writeback[j] = true
                            end
                        end
                    end
                    ImGui.EndPopup(ctx)
                end
            end

            local function track_copy_context_menu(i, key)
                if ImGui.BeginPopupContextItem(ctx, "##trackctx_" .. i .. "_" .. key) then
                    local md = track_items_metadata[i]
                    local cur_val = md[key] or ""

                    if ImGui.MenuItem(ctx, "Copy to all tracks", nil, false, cur_val ~= "") then
                        for j = 0, CountTrackMediaItems(selected_track) - 1 do
                            local other = track_items_metadata[j]
                            if other then
                                other[key] = cur_val
                                force_writeback[j] = true
                            end
                        end
                    end

                    if i > 0 then
                        local has_later_track = i < CountTrackMediaItems(selected_track) - 1
                        if ImGui.MenuItem(ctx, "Copy to all later tracks", nil, false,
                            cur_val ~= "" and has_later_track) then
                            for j = i + 1, CountTrackMediaItems(selected_track) - 1 do
                                local other = track_items_metadata[j]
                                if other then
                                    other[key] = cur_val
                                    force_writeback[j] = true
                                end
                            end
                        end
                    end

                    local prev_idx
                    for j = i - 1, 0, -1 do
                        if track_items_metadata[j] then
                            prev_idx = j
                            break
                        end
                    end
                    local prev_val = prev_idx and (track_items_metadata[prev_idx][key] or "") or nil
                    if ImGui.MenuItem(ctx, "Copy from previous track", nil, false,
                        prev_val ~= nil and prev_val ~= "") then
                        md[key] = prev_val
                        force_writeback[i] = true
                    end

                    if TRACK_ALBUM_SHARED_KEYS[key] then
                        local album_val = album_metadata and album_metadata[key] or nil
                        if ImGui.MenuItem(ctx, "Copy from album", nil, false,
                            album_val ~= nil and album_val ~= "") then
                            md[key] = album_val
                            force_writeback[i] = true
                        end
                    end

                    ImGui.EndPopup(ctx)
                end
            end

            if album_metadata then
                local btn_label = "Recalculate"
                local btn_text_w = ImGui.CalcTextSize(ctx, btn_label)
                local pad_x = select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))
                local btn_w = btn_text_w + pad_x * 2
                local window_w = select(1, ImGui.GetContentRegionAvail(ctx))
                ImGui.Text(ctx, "Album Metadata:")
                ImGui.SameLine(ctx)
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x999999FF)
                ImGui.Text(ctx, "(right-click a field to copy)")
                ImGui.PopStyleColor(ctx)
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, (window_w - btn_w) / 2)
                if ImGui.Button(ctx, btn_label) then
                    recalculate()
                end
                ImGui.Separator(ctx)

                ImGui.Dummy(ctx, 0, 10)

                local spacing = 5

                ImGui.Text(ctx, "Digital Release Only")
                ImGui.SameLine(ctx)
                local digital_changed
                digital_changed, digital_release_only = ImGui.Checkbox(ctx, "##digital_release_chk", digital_release_only)
                if digital_changed then
                    SetProjExtState(0, "ReaClassical", "digital_release_only", digital_release_only and "1" or "0")
                    editing_track = nil
                    points = {}
                    Undo_BeginBlock()
                    run_create_cd_markers(selected_track)
                    Undo_EndBlock("Create CD/DDP Markers", -1)
                end

                ImGui.SameLine(ctx)
                local avail = select(1, ImGui.GetContentRegionAvail(ctx))
                local text_w = ImGui.CalcTextSize(ctx, "Manual Contributors Entry")
                local checkbox_w = ImGui.GetFrameHeight(ctx)

                ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + avail - (text_w + checkbox_w + 8))

                ImGui.Text(ctx, "Manual Contributors Entry")
                ImGui.SameLine(ctx)

                _, manual_people_entry = ImGui.Checkbox(ctx, "##manual_people_chk", manual_people_entry)
                SetProjExtState(0, "ReaClassical", "manual_people_entry", manual_people_entry and "1" or "0")

                local line1_units = { 2, 1, 1, 1, 1 }
                local line2_units = { 1, 1, 0.75, 0.6, 2 }

                local avail_w = select(1, ImGui.GetContentRegionAvail(ctx))

                local total_units1, total_units2 = 0, 0
                for _, u in ipairs(line1_units) do total_units1 = total_units1 + u end
                for _, u in ipairs(line2_units) do total_units2 = total_units2 + u end

                local line1_widths, line2_widths = {}, {}
                for i, u in ipairs(line1_units) do
                    line1_widths[i] = (avail_w - spacing * (#line1_units - 1)) * (u / total_units1)
                end
                for i, u in ipairs(line2_units) do
                    line2_widths[i] = (avail_w - spacing * (#line2_units - 1)) * (u / total_units2)
                end

                if not manual_people_entry then
                    local album_changed = false

                    for _, f in ipairs({ "performer", "songwriter", "composer", "arranger" }) do
                        local old_value = album_metadata[f]
                        propagate_album_field(f)
                        if album_metadata[f] ~= old_value then
                            album_changed = true
                        end
                    end

                    if album_changed then
                        commit_album_metadata()
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
                    local line1_problem = latin1_field_problem(album_metadata[album_keys_line1[j]])
                    if line1_problem then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Border, 0xFF4040FF)
                        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1.5)
                    end
                    changed, album_metadata[album_keys_line1[j]] = ImGui.InputText(
                        ctx,
                        albumkeys1_widget_id,
                        album_metadata[album_keys_line1[j]] or "",
                        128
                    )
                    if line1_problem then
                        ImGui.PopStyleVar(ctx)
                        ImGui.PopStyleColor(ctx)
                    end
                    flag_latin1_problem(ctx, line1_problem)
                    if album_keys_line1[j] ~= "title" then
                        album_copy_context_menu(album_keys_line1[j])
                    end
                    ImGui.PopItemWidth(ctx)
                    ImGui.EndGroup(ctx)
                    if j < #album_keys_line1 then ImGui.SameLine(ctx, 0, spacing) end
                    if changed then
                        commit_album_metadata()
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
                        local catalog_invalid = key == "catalog"
                            and not catalog_is_valid(album_metadata.catalog or "")
                        if catalog_invalid then
                            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF4040FF)
                        end
                        local line2_problem = key ~= "catalog" and latin1_field_problem(album_metadata[key])
                        if line2_problem then
                            ImGui.PushStyleColor(ctx, ImGui.Col_Border, 0xFF4040FF)
                            ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1.5)
                        end
                        changed, album_metadata[key] = ImGui.InputText(
                            ctx,
                            albumkeys2_widget_id,
                            album_metadata[key] or "",
                            128
                        )
                        if line2_problem then
                            ImGui.PopStyleVar(ctx)
                            ImGui.PopStyleColor(ctx)
                        end
                        flag_latin1_problem(ctx, line2_problem)
                        if catalog_invalid then
                            ImGui.PopStyleColor(ctx)
                        end
                        if key == "message" then
                            album_copy_context_menu(key)
                        end
                    end

                    ImGui.PopItemWidth(ctx)
                    ImGui.EndGroup(ctx)
                    if j < #album_keys_line2 then ImGui.SameLine(ctx, 0, spacing) end

                    if changed then
                        if key == "catalog" and album_metadata.catalog then
                            album_metadata.catalog = album_metadata.catalog:gsub("%D", "")
                        end

                        commit_album_metadata()
                    end
                end
            end
            ImGui.Dummy(ctx, 0, 10)
            ImGui.Text(ctx, "Track Metadata:")
            ImGui.SameLine(ctx)
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x999999FF)
            ImGui.Text(ctx, "(right-click a field to copy)")
            ImGui.PopStyleColor(ctx)

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
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x56A0D3FF)
                ImGui.Text(ctx, "(marker offsets active)")
                ImGui.PopStyleColor(ctx)
            end

            ImGui.Separator(ctx)

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
                recalculate()
            end

            local item_count = CountTrackMediaItems(selected_track)

            local show_move_buttons = false
            if selected_track_row ~= nil then
                for i = 0, item_count - 1 do
                    local check_item = GetTrackMediaItem(selected_track, i)
                    if GetMediaItemInfo_Value(check_item, "B_UISEL") == 1 then
                        local check_take = GetActiveTake(check_item)
                        if check_take then
                            local _, check_name = GetSetMediaItemTakeInfo_String(check_take, "P_NAME", "", false)
                            if check_name and not check_name:match("^@") then
                                show_move_buttons = true
                                break
                            end
                        end
                    end
                end
            end

            if show_move_buttons then
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, "Move Album Track Up") then
                    local item = GetTrackMediaItem(selected_track, selected_track_row)
                    local _, item_guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", item_guid)

                    Main_OnCommand(move_album_track_up, 0)

                    pending_reinit = true
                end
                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, "Move Album Track Down") then
                    local item = GetTrackMediaItem(selected_track, selected_track_row)
                    local _, item_guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", item_guid)

                    Main_OnCommand(move_album_track_down, 0)

                    pending_reinit = true
                end
            end

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

            checkbox_w = ImGui.GetFrameHeight(ctx)
            local track_number_w = ImGui.CalcTextSize(ctx, "00")

            local avail_w = select(1, ImGui.GetContentRegionAvail(ctx))

            local fixed_width = checkbox_w + spacing + track_number_w + spacing
            local metadata_width = avail_w - fixed_width - spacing * #keys

            local normal_boxes = #keys - 1
            local total_units = normal_boxes + 2
            local normal_box_w = metadata_width / total_units
            local title_box_w = 2 * normal_box_w

            local first_isrc = nil

            local _, ddp_table_avail_h = ImGui.GetContentRegionAvail(ctx)
            local ddp_footer_h = ImGui.GetFrameHeightWithSpacing(ctx) + 30
            ImGui.BeginChild(ctx, "##ddp_track_table", 0, ddp_table_avail_h - ddp_footer_h)

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

            local seed_md = track_items_metadata[0]
            if seed_md and seed_md.isrc and seed_md.isrc:match(isrc_pattern) then
                first_isrc = seed_md.isrc
            end

            local any_changed = false
            local changed

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

            local _, stored_guid = GetProjExtState(0, "ReaClassical", "ddp_selected_item_guid")

            if current_selected_item then
                local _, item_guid = GetSetMediaItemInfo_String(current_selected_item, "GUID", "", false)
                if item_guid ~= stored_guid then
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", item_guid)
                end
            else
                if stored_guid ~= "" then
                    SetProjExtState(0, "ReaClassical", "ddp_selected_item_guid", "")
                end
            end

            for i = 0, item_count - 1 do
                local item = GetTrackMediaItem(selected_track, i)
                local take = GetActiveTake(item)
                local md = track_items_metadata[i]
                if md then
                    if i > 0 then
                        local _, actual_item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                        local has_exclamation = actual_item_name:match("^!")
                        local checkbox_state = has_exclamation ~= nil
                        local checkbox_changed
                        local checkbox_id = "##checkbox_" .. i .. "_" .. tostring(selected_track)
                        checkbox_changed, checkbox_state = ImGui.Checkbox(ctx, checkbox_id, checkbox_state)

                        if checkbox_changed then
                            local _, current_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                            local new_name

                            if checkbox_state then
                                if not current_name:match("^!") then
                                    new_name = "!" .. current_name
                                end
                            else
                                if current_name:match("^!") then
                                    new_name = current_name:gsub("^!", "")
                                end
                            end

                            if new_name then
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                                points = {}
                                Undo_BeginBlock()
                                run_create_cd_markers(selected_track)
                                Undo_EndBlock("Create CD/DDP Markers", -1)
                            end
                        end

                        ImGui.SameLine(ctx, 0, spacing)
                    else
                        ImGui.Dummy(ctx, checkbox_w, 0)
                        ImGui.SameLine(ctx, 0, spacing)
                    end

                    local track_number_str = string.format("%02d", track_number_counter)

                    local is_selected_row = (selected_track_row == i)

                    local cursor_x_before = ImGui.GetCursorPosX(ctx)
                    local cursor_y_before = ImGui.GetCursorPosY(ctx)

                    if is_selected_row then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x56A0D3FF)
                    end
                    ImGui.Text(ctx, track_number_str)
                    if is_selected_row then
                        ImGui.PopStyleColor(ctx)
                    end

                    ImGui.SetCursorPos(ctx, cursor_x_before, cursor_y_before)
                    ImGui.InvisibleButton(ctx, "##tracknum_" .. i, track_number_w + 10, ImGui.GetTextLineHeight(ctx))

                    if ImGui.IsItemClicked(ctx) then
                        Main_OnCommand(40289, 0)
                        SetMediaItemSelected(item, true)
                        Main_OnCommand(40034, 0)
                        UpdateArrange()
                        selected_track_row = i
                    end

                    ImGui.SameLine(ctx, 0, spacing)

                    local original_title = md.title
                    ImGui.PushItemWidth(ctx, title_box_w)
                    local title_widget_id = "##" .. i .. "_title_" .. tostring(selected_track)
                    local title_problem = latin1_field_problem(md.title)
                    if title_problem then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Border, 0xFF4040FF)
                        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1.5)
                    end
                    changed, md.title = ImGui.InputText(ctx, title_widget_id, md.title or "", 128)
                    if title_problem then
                        ImGui.PopStyleVar(ctx)
                        ImGui.PopStyleColor(ctx)
                    end
                    flag_latin1_problem(ctx, title_problem)
                    any_changed = any_changed or changed
                    track_copy_context_menu(i, "title")
                    ImGui.PopItemWidth(ctx)
                    if md.title == "" then md.title = original_title end

                    for j = 2, #keys do
                        ImGui.SameLine(ctx, 0, spacing)
                        ImGui.BeginGroup(ctx)
                        ImGui.PushItemWidth(ctx, normal_box_w)
                        local keys_widget_id = "##" .. i .. "_" .. keys[j] .. " " .. tostring(selected_track)
                        local isrc_editable = keys[j] == "isrc" and (manual_isrc_entry or i == 0)
                        if keys[j] == "isrc" and not manual_isrc_entry and i > 0 then
                            ImGui.BeginDisabled(ctx)
                        end
                        local isrc_invalid = isrc_editable and not isrc_is_valid(md.isrc or "")
                        if isrc_invalid then
                            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF4040FF)
                        end
                        local track_field_problem = keys[j] ~= "isrc" and latin1_field_problem(md[keys[j]])
                        if track_field_problem then
                            ImGui.PushStyleColor(ctx, ImGui.Col_Border, 0xFF4040FF)
                            ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize, 1.5)
                        end
                        changed, md[keys[j]] = ImGui.InputText(ctx, keys_widget_id, md[keys[j]] or "", 128)
                        if track_field_problem then
                            ImGui.PopStyleVar(ctx)
                            ImGui.PopStyleColor(ctx)
                        end
                        flag_latin1_problem(ctx, track_field_problem)
                        if isrc_invalid then
                            ImGui.PopStyleColor(ctx)
                        end
                        if keys[j] == "isrc" and not manual_isrc_entry and i > 0 then
                            ImGui.EndDisabled(ctx)
                        end
                        if keys[j] ~= "isrc" then
                            track_copy_context_menu(i, keys[j])
                        end
                        any_changed = any_changed or changed

                        if keys[j] == "isrc" then
                            if manual_isrc_entry then
                                if changed then
                                    local stripped = md.isrc:gsub("%-", "")
                                    if stripped ~= md.isrc then
                                        md.isrc = stripped
                                        any_changed = true
                                    end
                                end
                            else
                                if i == 0 then
                                    if md.isrc == "" then
                                        first_isrc = nil
                                    else
                                        local stripped = md.isrc:gsub("%-", "")
                                        if stripped ~= md.isrc then
                                            md.isrc = stripped
                                            any_changed = true
                                        end
                                        if md.isrc:match(isrc_pattern) then
                                            first_isrc = md.isrc
                                        end
                                    end
                                else
                                    if first_isrc then
                                        md.isrc = increment_isrc(first_isrc, track_number_counter - 1)
                                    else
                                        md.isrc = ""
                                    end
                                end
                            end
                        end

                        ImGui.PopItemWidth(ctx)
                        ImGui.EndGroup(ctx)
                    end

                    if any_changed or first_run or force_writeback[i] then
                        local _, original_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                        local has_exclamation = original_name:match("^!")

                        local new_name = serialize_track_metadata_safe(md)

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
            ImGui.EndChild(ctx)
            first_run = false
        else
            ImGui.Text(ctx, "No track selected. Please select a folder track to edit metadata.")
        end
        ImGui.Dummy(ctx, 0, 10)
        ImGui.Separator(ctx)

        local spacing_y = select(2, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))
        local cursor_y = ImGui.GetCursorPosY(ctx)
        local line_y = cursor_y - spacing_y
        local space_below_line = ImGui.GetWindowHeight(ctx) - line_y
        local row_offset = (space_below_line - ImGui.GetFrameHeight(ctx)) / 2 - spacing_y
        if row_offset > 0 then
            ImGui.SetCursorPosY(ctx, cursor_y + row_offset)
        end

        local render_buttons = {
            { label = "DDP",       fn = render_ddp_preset,       tooltip = "Apply the DDP render preset (44.1kHz/16-bit/triangular, Red Book) and render silently" },
            { label = "Cue Audio", fn = render_cue_audio_preset, tooltip = "Apply the Cue Audio render preset and render silently" },
            { label = "WAV",       fn = render_wav_preset,       tooltip = "Apply the WAV render preset and render silently",
              range_eligible = true },
            { label = "FLAC",      fn = render_flac_preset,      tooltip = "Apply the FLAC render preset and render silently",
              range_eligible = true },
            { label = "Opus 160",  fn = render_opus_preset,      tooltip = "Apply the Opus 160 render preset and render silently",
              range_eligible = true },
            { label = "MP3 320",   fn = render_mp3_preset,       tooltip = "Apply the MP3 320 render preset and render silently",
              range_eligible = true },
            { label = "M: Stems",  fn = render_stems_preset,     tooltip = "Render the M: mixer tracks as stems through the master (one WAV per track per CD track), using the dropdowns to the left",
              range_eligible = true },
            { label = "Custom",    fn = open_render_dialog,      tooltip = "Open the REAPER render dialog, pre-filled with the dropdowns to the left" },
        }

        local btn_pad_x = select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding))
        local item_spacing_x = select(1, ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing))
        local bottom_avail_w = select(1, ImGui.GetContentRegionAvail(ctx))

        local export_label = "Render:"
        local export_label_w = ImGui.CalcTextSize(ctx, export_label) + item_spacing_x

        local total_btn_w = export_label_w
        for _, b in ipairs(render_buttons) do
            total_btn_w = total_btn_w + ImGui.CalcTextSize(ctx, b.label) + btn_pad_x * 2
        end
        total_btn_w = total_btn_w + item_spacing_x * (#render_buttons - 1)

        local combo_w = 100
        local dither_combo_w = 120
        local combos_w = combo_w * 2 + dither_combo_w + item_spacing_x * 2
        local group_gap = item_spacing_x * 2

        local tracks_label = "Tracks:"
        local tracks_box_w = 150
        local tracks_w = ImGui.CalcTextSize(ctx, tracks_label) + item_spacing_x + tracks_box_w

        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx)
            + bottom_avail_w - tracks_w - group_gap - combos_w - group_gap - total_btn_w)
        ImGui.AlignTextToFramePadding(ctx)

        ImGui.Text(ctx, tracks_label)
        ImGui.SameLine(ctx)
        ImGui.PushItemWidth(ctx, tracks_box_w)
        local _, new_track_range = ImGui.InputTextWithHint(
            ctx, "##track_range", "e.g. 1-3,5", track_range_input, 40)
        track_range_input = new_track_range
        ImGui.PopItemWidth(ctx)
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx,
                "Limits WAV / FLAC / Opus 160 / MP3 320 / M: Stems to these CD track numbers.\n"
                .. "Blank = all tracks. DDP, Cue Audio, and Custom always render the full album.")
        end

        ImGui.SameLine(ctx, 0, group_gap)
        local srate_preview = "44.1 kHz"
        for idx, sr in ipairs(samplerate_list) do
            if sr == render_samplerate then srate_preview = samplerate_labels[idx] end
        end
        ImGui.PushItemWidth(ctx, combo_w)
        if ImGui.BeginCombo(ctx, "##render_samplerate", srate_preview) then
            for idx, sr in ipairs(samplerate_list) do
                local is_sel = (render_samplerate == sr)
                if ImGui.Selectable(ctx, samplerate_labels[idx], is_sel) then
                    render_samplerate = sr
                    render_settings.save_samplerate(sr)
                end
                if is_sel then ImGui.SetItemDefaultFocus(ctx) end
            end
            ImGui.EndCombo(ctx)
        end
        ImGui.PopItemWidth(ctx)
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Render sample rate (Cue Audio / WAV / FLAC / Custom)")
        end

        ImGui.SameLine(ctx)
        local bitdepth_preview = "16-bit"
        for idx, bd in ipairs(bitdepth_list) do
            if bd == render_bitdepth then bitdepth_preview = bitdepth_labels[idx] end
        end
        ImGui.PushItemWidth(ctx, combo_w)
        if ImGui.BeginCombo(ctx, "##render_bitdepth", bitdepth_preview) then
            for idx, bd in ipairs(bitdepth_list) do
                local is_sel = (render_bitdepth == bd)
                if ImGui.Selectable(ctx, bitdepth_labels[idx], is_sel) then
                    render_bitdepth = bd
                    render_settings.save_bitdepth(bd)
                    if bd ~= 16 then
                        render_dither = "Off"
                        render_settings.save_dither("Off")
                    end
                end
                if is_sel then ImGui.SetItemDefaultFocus(ctx) end
            end
            ImGui.EndCombo(ctx)
        end
        ImGui.PopItemWidth(ctx)
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Render bit depth (Cue Audio / WAV / FLAC / Custom)")
        end

        ImGui.SameLine(ctx)
        local dither_disabled = render_bitdepth ~= 16
        if dither_disabled then ImGui.BeginDisabled(ctx) end
        ImGui.PushItemWidth(ctx, dither_combo_w)
        if ImGui.BeginCombo(ctx, "##render_dither", render_dither) then
            for _, d in ipairs(dither_list) do
                local is_sel = (render_dither == d)
                if ImGui.Selectable(ctx, d, is_sel) then
                    render_dither = d
                    render_settings.save_dither(d)
                end
                if is_sel then ImGui.SetItemDefaultFocus(ctx) end
            end
            ImGui.EndCombo(ctx)
        end
        ImGui.PopItemWidth(ctx)
        if dither_disabled then ImGui.EndDisabled(ctx) end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx,
                "Dither, 16-bit only (Cue Audio / WAV / FLAC / Custom)\n"
                .. "Triangular: light dither, unshaped\n"
                .. "HP filtered: dither + noise shaping\n"
                .. "Noise shaping: noise shaping alone, no dither\n"
                .. "Off: neither")
        end

        ImGui.SameLine(ctx, 0, group_gap)
        ImGui.Text(ctx, export_label)
        ImGui.SameLine(ctx)
        for i, b in ipairs(render_buttons) do
            if i > 1 then ImGui.SameLine(ctx) end
            if ImGui.Button(ctx, b.label) then
                recalculate()
                if b.range_eligible and track_range_input ~= "" then
                    local regions = render_range.get_regions(0)
                    local track_set, err = render_range.parse(track_range_input, #regions)
                    if err then
                        MB("Invalid track range: " .. err, "Render Track Range", 0)
                    else
                        render_range.render_subset(0, track_set, b.fn)
                    end
                else
                    b.fn()
                end
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, b.tooltip)
            end
        end

        if gui_mode.imgui_shortcut(ImGui, ctx) then gui_mode.toggle_and_announce() end
        if gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end
        ImGui.End(ctx)
    end

    defer(editor_main)
end

local function run_create_cd_markers_wrapped(track)
    if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.no_undo_wrap then
        return run_create_cd_markers(track)
    end
    Undo_BeginBlock()
    local success = run_create_cd_markers(track)
    Undo_EndBlock("Create CD/DDP Markers", -1)
    return success
end

if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.action == "render" then
    points = {}
    local success = run_create_cd_markers_wrapped()
    if not success then return end
    local fmt = _G.RC_SCRIPT_ARGS.format
    local preset_fn
    if     fmt == "ddp"    then preset_fn = render_ddp_preset
    elseif fmt == "cue"    then preset_fn = render_cue_audio_preset
    elseif fmt == "wav"    then preset_fn = render_wav_preset
    elseif fmt == "flac"   then preset_fn = render_flac_preset
    elseif fmt == "opus"   then preset_fn = render_opus_preset
    elseif fmt == "mp3"    then preset_fn = render_mp3_preset
    elseif fmt == "stems"  then preset_fn = render_stems_preset
    elseif fmt == "custom" then preset_fn = open_render_dialog
    end

    local range_str = _G.RC_SCRIPT_ARGS.track_range
    local range_msg = ""
    if range_str then
        local regions = render_range.get_regions(0)
        local track_set, err = render_range.parse(range_str, #regions)
        if err then
            say("Invalid track range: " .. err)
            return
        end
        render_range.render_subset(0, track_set, preset_fn)
        range_msg = " (tracks " .. range_str .. ")"
    else
        preset_fn()
    end

    if fmt ~= "custom" then
        say("Rendered: " .. fmt:upper() .. range_msg)
    end
    return
end

if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.action == "set_album" then
    local sel_track = GetTrack(0, 0)
    if not sel_track then
        say("Error: No tracks in project.")
        return
    end
    local _, legacy_item = album_meta_store.get_album_metadata_str(sel_track)
    album_meta_store.set_album_metadata_str(sel_track, _G.RC_SCRIPT_ARGS.name, legacy_item)
    points = {}
    Undo_BeginBlock()
    local success = run_create_cd_markers(sel_track)
    Undo_EndBlock("Create CD/DDP Markers", -1)
    if success then
        create_metadata_report_and_cue()
        say("Album metadata set, CD/DDP markers updated")
    end
    return
end

local selected_track = GetTrack(0, 0)
if not selected_track then
    if _G.RC_SCRIPT_ARGS then
        say("Error: No tracks in project.")
        return
    end
else
    points = {}
    local success = run_create_cd_markers_wrapped(selected_track)
    if not success then return end
    if _G.RC_SCRIPT_ARGS then
        create_metadata_report_and_cue()
        if not _G.RC_SCRIPT_ARGS.silent then
            say("CD/DDP markers created")
        end
        return
    end
end

local _, ddp_silent_flag = GetProjExtState(0, "ReaClassical", "ddp_silent")
if ddp_silent_flag == "y" then
    SetProjExtState(0, "ReaClassical", "ddp_silent", "")
    return
end

if _clara_or_debug then
    dofile(script_path .. "lib/ReaClassical_Accessible DDP Metadata Editor.lua")
    return
end

defer(editor_main)
