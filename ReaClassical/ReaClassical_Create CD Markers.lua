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

for key in pairs(reaper) do _G[key] = reaper[key] end

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local first_track = GetTrack(0, 0)
    if first_track then NUM_OF_ITEMS = CountTrackMediaItems(first_track) end
    if not first_track or NUM_OF_ITEMS == 0 then
        ShowMessageBox("Error: No media items found.", "Create CD Markers", 0)
        return
    end
    local empty_count = empty_items_check(first_track)
    if empty_count > 0 then
        ShowMessageBox("Error: Empty items found on first track. Delete them to continue.", "Create CD Markers", 0)
        return
    end
    local choice = ShowMessageBox(
        "WARNING: This will delete all existing markers, regions and item take markers. Track titles will be pulled from item take names. Continue?"
        ,
        "Create CD/DDP markers", 4)
    if choice == 6 then
        SetProjExtState(0, "Create CD Markers", "Run?", "yes")
        local redbook_track_length_errors, redbook_total_tracks_error, redbook_project_length = cd_markers(first_track)
        if redbook_track_length_errors > 0 then
            ShowMessageBox(
                'This album does not meet the Red Book standard as at least one of the CD tracks is under 4 seconds in length.',
                "Warning", 0)
        end
        if redbook_total_tracks_error == true then
            ShowMessageBox('This album does not meet the Red Book standard as it contains more than 99 tracks.',
                "Warning", 0)
        end
        if redbook_project_length > 79.57 then
            ShowMessageBox('This album does not meet the Red Book standard as it is longer than 79.57 minutes.',
                "Warning", 0)
        end
    end
    Undo_EndBlock("Create CD/DDP Markers", -1)
end

---------------------------------------------------------------------

function get_info()
    local _, metadata_saved = GetProjExtState(0, "Create CD Markers", "Album Metadata")
    local ret, user_inputs, metadata_table
    if metadata_saved ~= "" then
        ret, user_inputs = GetUserInputs('CD/DDP Album information', 4,
            'Album Title,Performer,Composer,Genre,extrawidth=100',
            metadata_saved)
    else
        ret, user_inputs = GetUserInputs('CD/DDP Album information', 4,
            'Album Title,Performer,Composer,Genre,extrawidth=100',
            'My Classical Album,Performer,Composer,Classical')
    end
    metadata_table = {}
    for entry in user_inputs:gmatch('([^,]+)') do metadata_table[#metadata_table + 1] = entry end
    if not ret then
        ShowMessageBox('Only writing track metadata', "Cancelled", 0)
    elseif #metadata_table ~= 4 then
        ShowMessageBox('Empty metadata_table not supported: Not writing album metadata', "Warning", 0)
    end
    return user_inputs, metadata_table
end

---------------------------------------------------------------------

function cd_markers(first_track)
    delete_markers()

    SNM_SetIntConfigVar('projfrbase', 75)
    Main_OnCommand(40754, 0) --enable snap to grid

    local code_input, code_table = add_codes()
    if code_input ~= "" then
        save_codes(code_input)
    end
    local pregap_len, offset, postgap = return_custom_length()

    start_check(first_track, offset) -- move items to right if not enough room for first offset

    if tonumber(pregap_len) < 1 then pregap_len = 1 end
    local final_end = find_project_end(first_track)
    local previous_start
    local redbook_track_length_errors = 0
    local redbook_total_tracks_error = false
    local previous_takename
    local marker_count = 0
    for i = 0, NUM_OF_ITEMS - 1, 1 do
        local current_start, take_name = find_current_start(first_track, i)
        local added_marker = create_marker(current_start, marker_count, take_name, code_table, offset)
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
        ShowMessageBox('Please add take names to all items that you want to be CD tracks (Select item then press F2)',
            "No track markers created", 0)
        return
    end
    if marker_count > 99 then
        redbook_total_tracks_error = true
    end
    AddProjectMarker(0, true, frame_check(previous_start - offset), frame_check(final_end) + postgap, previous_takename,
        marker_count)
    local redbook_project_length
    if marker_count ~= 0 then
        local user_inputs, metadata_table = get_info()
        if #metadata_table == 4 then save_metadata(user_inputs) end
        redbook_project_length = end_marker(first_track, metadata_table, code_table, postgap)
        renumber_markers()
        add_pregap(first_track)
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

function create_marker(current_start, marker_count, take_name, code_table, offset)
    local added_marker = false
    local track_title
    if take_name ~= "" then
        local corrected_current_start = frame_check(current_start - offset)
        if #code_table == 5 then
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
    Main_OnCommand(40898, 0)
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

function find_project_end(first_track)
    local final_item = GetTrackMediaItem(first_track, NUM_OF_ITEMS - 1)
    local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
    local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
    return final_start + final_length
end

---------------------------------------------------------------------

function end_marker(first_track, metadata_table, code_table, postgap)
    local final_item = GetTrackMediaItem(first_track, NUM_OF_ITEMS - 1)
    local final_start = GetMediaItemInfo_Value(final_item, "D_POSITION")
    local final_length = GetMediaItemInfo_Value(final_item, "D_LENGTH")
    local final_end = final_start + final_length
    if #metadata_table == 4 and #code_table == 5 then
        local album_info = "@" ..
            metadata_table[1] ..
            "|CATALOG=" .. code_table[1] .. "|PERFORMER=" .. metadata_table[2] .. "|COMPOSER=" .. metadata_table[3] ..
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
    SetProjExtState(0, "Create CD Markers", "Album Metadata", user_inputs)
end

---------------------------------------------------------------------

function save_codes(code_input)
    SetProjExtState(0, "Create CD Markers", "Codes", code_input)
end

---------------------------------------------------------------------

function add_codes()
    local _, code_saved = GetProjExtState(0, "Create CD Markers", "Codes")
    local codes_response = ShowMessageBox("Add UPC/ISRC codes?", "CD codes", 4)
    local ret2
    local code_input = ""
    local code_table = {}
    if codes_response == 6 then
        if code_saved ~= "" then
            ret2, code_input = GetUserInputs('UPC/ISRC Codes', 5,
                'UPC or EAN,ISRC Country Code,ISRC Registrant Code,ISRC Year (YY),ISRC Designation Code (5 digits),extrawidth=100'
                ,
                code_saved)
        else
            ret2, code_input = GetUserInputs('UPC/ISRC Codes', 5,
                'UPC or EAN,ISRC Country Code,ISRC Registrant Code,ISRC Year (YY),ISRC Designation Code (5 digits),extrawidth=100'
                ,
                ',')
        end
        for num in code_input:gmatch('([^,]+)') do code_table[#code_table + 1] = num end
        if not ret2 then
            ShowMessageBox('Not writing UPC/EAN or ISRC codes', "Cancelled", 0)
        elseif #code_table ~= 5 then
            ShowMessageBox('Empty code metadata_table not supported: Not writing UPC/EAN or ISRC codes', "Warning",
                0)
        end
    end
    return code_input, code_table
end

---------------------------------------------------------------------

function delete_markers()
    local delete_markers = NamedCommandLookup("_SWSMARKERLIST9")
    Main_OnCommand(delete_markers, 0)
    local delete_regions = NamedCommandLookup("_SWSMARKERLIST10")
    Main_OnCommand(delete_regions, 0)
    Main_OnCommand(40182, 0) -- select all items
    Main_OnCommand(42387, 0) -- Delete all take markers
    Main_OnCommand(40289, 0) -- Unselect all items
end

---------------------------------------------------------------------

function empty_items_check(first_track)
    local count = 0
    for i = 0, NUM_OF_ITEMS - 1, 1 do
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
        offset = table[2] / 1000
        pregap_len = table[3]
        postgap = table[4]
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

main()
