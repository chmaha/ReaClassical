--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

local main, get_color_table, get_path

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()

    -- Get the first folder parent track (track 1)
    local parent_track = GetTrack(0, 0)
    
    -- Count the number of selected media items
    local num = CountSelectedMediaItems(0)
    
    if num == 0 then
        ShowMessageBox(
        "Please select one or more consecutive media items in the first folder before running the function.",
            "Destination Markers to Item Edge: Error", 0)
        return
    end

    local folder_tracks = {}
    local num_tracks = CountTracks(0)
    local found_folder_end = false
    
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if i == 0 or GetParentTrack(track) == parent_track then
            table.insert(folder_tracks, track)
        else
            found_folder_end = true
            break
        end
    end
    
    for i = 0, num - 1 do
        local item = GetSelectedMediaItem(0, i)
        local item_track = GetMediaItem_Track(item)

        local found = false
        for _, folder_track in ipairs(folder_tracks) do
            if item_track == folder_track then
                found = true
                break
            end
        end
        
        if not found then
            MB("Any selected items should be in the first folder.", "Error", 0)
            return
        end
    end

    -- Set marker positions
    local first_item = GetSelectedMediaItem(0, 0)
    local left_pos = GetMediaItemInfo_Value(first_item, "D_POSITION")
    local last_item, right_pos
    if num > 1 then
        last_item = GetSelectedMediaItem(0, num - 1)
        local start = GetMediaItemInfo_Value(last_item, "D_POSITION")
        local length = GetMediaItemInfo_Value(last_item, "D_LENGTH")
        right_pos = start + length
    else
        local length = GetMediaItemInfo_Value(first_item, "D_LENGTH")
        right_pos = left_pos + length
    end

    -- Remove old markers
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then
            break
        else
            DeleteProjectMarker(project, 996, false)
            DeleteProjectMarker(project, 997, false)
        end
        i = i + 1
    end

    -- Get color table and add new markers
    local colors = get_color_table()
    AddProjectMarker2(0, false, left_pos, 0, "DEST-IN", 996, colors.dest_marker)
    AddProjectMarker2(0, false, right_pos, 0, "DEST-OUT", 997, colors.dest_marker)

    Undo_EndBlock("Destination Markers to Item Edge", 0)
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
