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

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local left_pos, right_pos
    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    if start_time ~= end_time then
        left_pos = start_time
        right_pos = end_time
    else
        local num = CountSelectedMediaItems(0)
        if num == 0 then
            MB(
                "Please select one or more consecutive media items on a parent track " ..
                "or make a time selection before running the function.",
                "Source Markers to Item Edge or Time Selection: Error", 0)
            return
        end

        local first_item = GetSelectedMediaItem(0, 0)
        left_pos = GetMediaItemInfo_Value(first_item, "D_POSITION")
        local last_item
        if num > 1 then
            last_item = GetSelectedMediaItem(0, num - 1)
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

    local track_number = math.floor(get_track_number())
    local colors = get_color_table()
    AddProjectMarker2(0, false, left_pos, 0, track_number .. ":SOURCE-IN", 998, colors.source_marker)
    AddProjectMarker2(0, false, right_pos, 0, track_number .. ":SOURCE-OUT", 999, colors.source_marker)

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

main()
