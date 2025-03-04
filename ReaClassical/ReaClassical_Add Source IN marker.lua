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

local main, folder_check, get_track_number, get_color_table, get_path
local move_destination_folder, move_destination_folder_to_top, get_tracks_per_group
local calculate_destination_info

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local sdmousehover = 0
    local moveable_dest = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[8] then sdmousehover = tonumber(table[8]) or 0 end
        if table[12] then moveable_dest = tonumber(table[12]) or 0 end
    end

    local selected_track = GetSelectedTrack(0, 0)
    local destination_folder, dest_track_num = calculate_destination_info()
    if moveable_dest == 0 and tonumber(dest_track_num) ~= 1 then
        move_destination_folder_to_top(destination_folder, dest_track_num)
        local vert_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(vert_sync, 0)
        dest_track_num = 1
    end

    local cur_pos, track
    if sdmousehover == 1 then
        track, _, cur_pos = BR_TrackAtMouseCursor()
    else
        cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    end

    if cur_pos ~= -1 then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then
                break
            else
                DeleteProjectMarker(project, 998, false)
            end
            i = i + 1
        end

        local track_number = math.floor(get_track_number(track))
        local colors = get_color_table()
        
        if moveable_dest == 1 then
            move_destination_folder(track_number)
        end
        
        if dest_track_num and dest_track_num > track_number then
            track_number = track_number + get_tracks_per_group()
        end
        
        if selected_track then SetOnlyTrackSelected(selected_track) end
        AddProjectMarker2(0, false, cur_pos, 0, track_number .. ":SOURCE-IN", 998, colors.source_marker)
    end
    PreventUIRefresh(-1)
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

function get_track_number(track)
    if not track then track = GetSelectedTrack(0, 0) end
    if folder_check() == 0 or track == nil then
        return 1
    elseif GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        return GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    else
        local folder = GetParentTrack(track)
        return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
    end
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
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

function move_destination_folder_to_top(destination_folder, dest_track_num)
    if dest_track_num - 1 > 0 then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(0, 0)
    end
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
    return destination_folder, dest_track_num
end

---------------------------------------------------------------------

main()
