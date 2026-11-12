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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local sd_xfade = require("ReaClassical_SD_Crossfade_Utils")

local main, get_selected_media_item_at, count_selected_media_items
local is_in_first_folder

function main()
    Undo_BeginBlock()
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
    local left_pos, right_pos
    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    if start_time ~= end_time then
        left_pos = start_time
        right_pos = end_time
    else
        local num = count_selected_media_items()
        if num == 0 then
            MB(
                "Please select one or more consecutive media items " ..
                "or make a time selection before running the function.",
                "Destination Markers to Item Edge / Time Selection: Error", 0)
            return
        end

        local first_item = get_selected_media_item_at(0)
        if not is_in_first_folder(first_item) then
            MB("Please select one or more consecutive media items in the first folder.",
                "Destination Markers to Item Edge / Time Selection: Error", 0)
            return
        end
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
        left_pos = left_pos + sd_xfade.get_in_crossfade_overlap(first_item)
    end

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

    SetProjExtState(0, "ReaClassical", "DestInTrackNum", "1")
    SetProjExtState(0, "ReaClassical", "DestOutTrackNum", "1")

    local colors = require("ReaClassical_Colors_Table")
    local marker_color = (workflow == "Horizontal") and colors.dest_marker or colors.dest_items

    local in_label = (workflow == "Horizontal") and "DEST-IN" or "D:DEST-IN"
    local out_label = (workflow == "Horizontal") and "DEST-OUT" or "D:DEST-OUT"
    AddProjectMarker2(0, false, left_pos, 0, in_label, 996, marker_color)
    AddProjectMarker2(0, false, right_pos, 0, out_label, 997, marker_color)
    say("Destination markers set")

    Undo_EndBlock("Destination Markers to Item Edge", 0)
end

function is_in_first_folder(item)
    local first_folder
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            first_folder = track
            break
        end
    end
    if not first_folder then return true end
    local track = GetMediaItem_Track(item)
    return track == first_folder or GetParentTrack(track) == first_folder
end

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

main()
