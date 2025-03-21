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
local move_destination_folder, calculate_destination_info, get_tracks_per_group
local get_selected_media_item_at, count_selected_media_items
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
    local moveable_dest = 0

    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[12] then moveable_dest = tonumber(table[12]) or 0 end
    end

    local left_pos, right_pos
    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    if start_time ~= end_time then
        left_pos = start_time
        right_pos = end_time
    else
        local num = count_selected_media_items()
        if num == 0 then
            MB(
                "Please select one or more consecutive media items on a parent track " ..
                "or make a time selection before running the function.",
                "Source Markers to Item Edge or Time Selection: Error", 0)
            return
        end

        local first_item = get_selected_media_item_at(0)
        left_pos = GetMediaItemInfo_Value(first_item, "D_POSITION")
        local last_item
        if num > 1 then
            last_item = get_selected_media_item_at(num - 1)
            local start = GetMediaItemInfo_Value(last_item, "D_POSITION")
            local length = GetMediaItemInfo_Value(last_item, "D_LENGTH")
            right_pos = start + length
        else
            local length = GetMediaItemInfo_Value(first_item, "D_LENGTH")
            right_pos = left_pos + length
        end
    end

    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then
            break
        else
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
        end
        i = i + 1
    end

    local selected_track = GetSelectedTrack(0, 0)
    local dest_track_num = calculate_destination_info()

    local track_number = math.floor(get_track_number())

    if moveable_dest == 1 then
        move_destination_folder(track_number)
    end

    if dest_track_num and dest_track_num > track_number then
        track_number = track_number + get_tracks_per_group()
    end

    local colors = get_color_table()
    if selected_track then SetOnlyTrackSelected(selected_track) end
    AddProjectMarker2(0, false, left_pos, 0, track_number .. ":SOURCE-IN", 998, colors.source_marker)
    AddProjectMarker2(0, false, right_pos, 0, track_number .. ":SOURCE-OUT", 999, colors.source_marker)
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

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            selected_count = selected_count + 1
        end
    end

    return selected_count
end

---------------------------------------------------------------------

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end


---------------------------------------------------------------------

main()
