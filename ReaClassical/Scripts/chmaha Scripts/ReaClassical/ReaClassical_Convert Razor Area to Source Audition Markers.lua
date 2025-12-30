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

local main, folder_check, get_track_number
local move_destination_folder, calculate_destination_info, get_tracks_per_group
local select_first_razor
---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    PreventUIRefresh(1)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")

    local sai_manager = NamedCommandLookup("_RS238a7e78cb257490252b3dde18274d00f9a1cf10")
    Main_OnCommand(sai_manager, 0)
    local moveable_dest = 0
    
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[12] then moveable_dest = tonumber(table[12]) or 0 end
    end

    -- local first_run = false
    local razor_enabled = GetToggleCommandState(42618) == 1
    if not razor_enabled then
        Main_OnCommand(42618, 0)
        -- first_run = true
    end

    Main_OnCommand(40635, 0) -- remove time selection
    Main_OnCommand(42474, 0) -- set selection to razor edit

    local left_pos, right_pos
    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    if start_time ~= end_time then
        left_pos = start_time
        right_pos = end_time
        select_first_razor()
        local selected_track = GetSelectedTrack(0, 0)
        local dest_track_num = calculate_destination_info()

        local track_number = math.floor(get_track_number())

        if moveable_dest == 1 then
            move_destination_folder(track_number)
        end

        if dest_track_num and dest_track_num > track_number then
            track_number = track_number + get_tracks_per_group()
        end

        if selected_track then SetOnlyTrackSelected(selected_track) end

        local marker_color = selected_track and GetTrackColor(selected_track) or 0

        AddProjectMarker2(0, false, left_pos, 0, track_number .. ":SAI", -1, marker_color)
        AddProjectMarker2(0, false, right_pos, 0, track_number .. ":SAO", -1, marker_color)
    -- elseif not first_run then
    --     MB("Error: Create a razor edit area before running.", "Set Source Audition Markers", 0)
    --     return
    end
    
    Main_OnCommand(40635, 0) -- remove time selection
    Main_OnCommand(42406, 0) -- remove razor edit areas
    PreventUIRefresh(-1)
    Undo_EndBlock("Source Markers to Item Edge", 0)
end

---------------------------------------------------------------------

function folder_check()
    local folders = 0
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        end
    end
    return folders
end

---------------------------------------------------------------------

function get_track_number()
    local selected = GetSelectedTrack(0, 0)
    if folder_check() == 0 or selected == nil then
        return 1
    elseif GetMediaTrackInfo_Value(selected, "I_FOLDERDEPTH") == 1 then
        return GetMediaTrackInfo_Value(selected, "IP_TRACKNUMBER")
    else
        local folder = GetParentTrack(selected)
        return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
    end
end

---------------------------------------------------------------------

function move_destination_folder(track_number)
    local destination_folder = nil
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track
                break
            end
        end
    end

    if not destination_folder then return end

    local target_track = GetTrack(0, track_number - 1)
    if not target_track then return end

    local destination_index = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    local target_index = track_number - 1

    if destination_index ~= target_index then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(target_index, 0)
    end
end

---------------------------------------------------------------------

function calculate_destination_info()
    local track_count = CountTracks(0)
    local destination_folder = GetTrack(0, 0)
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track
                break
            end
        end
    end
    local dest_track_num = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER")
    return dest_track_num
end

---------------------------------------------------------------------

function get_tracks_per_group()
    local track_count = CountTracks(0)
    if track_count == 0 then return 0 end

    local tracks_per_group = 1
    local first_track = GetTrack(0, 0)
    if not first_track or GetMediaTrackInfo_Value(first_track, "I_FOLDERDEPTH") ~= 1 then
        return 0 -- No valid parent folder
    end

    for i = 1, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth == 1 then
                break -- New parent folder found, stop counting
            end
            tracks_per_group = tracks_per_group + 1
        end
    end
    return tracks_per_group
end

---------------------------------------------------------------------

function select_first_razor()
    local trackCount = CountTracks(0)

    -- deselect all tracks
    Main_OnCommand(40297, 0) -- Unselect all tracks

    for i = 0, trackCount - 1 do
        local track = GetTrack(0, i)
        local ok, area = GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
        if ok and area ~= "" then
            -- select this track
            SetTrackSelected(track, true)
            return -- stop after the first one
        end
    end
end

---------------------------------------------------------------------

main()
