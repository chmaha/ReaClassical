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

local main, get_color_table, get_path, edge_check, return_check_length

---------------------------------------------------------------------

function main()
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local sdmousehover = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[9] then sdmousehover = tonumber(table[9]) end
    end

    local cur_pos
    if sdmousehover == 1 then
        _, _, cur_pos = BR_TrackAtMouseCursor()
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
                DeleteProjectMarker(project, 996, false)
            end
            i = i + 1
        end


        if edge_check(cur_pos) == true then
            local response = ShowMessageBox(
                "The marker you are trying to add would either be on or close to an item edge or existing crossfade. Continue?",
                "Add Dest-IN Marker", 4)
            if response ~= 6 then return end
        end
        --DeleteProjectMarker(NULL, 996, false)
        local colors = get_color_table()
        AddProjectMarker2(0, false, cur_pos, 0, "DEST-IN", 996, colors.dest_marker)
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

function edge_check(cur_pos)
    local num_of_items = 0
    local check_length = return_check_length()
    local first_track = GetTrack(0, 0)
    if first_track then num_of_items = CountTrackMediaItems(first_track) end
    local new_pos = 0
    local clash = false
    for i = 0, num_of_items - 1 do
        local item = GetTrackMediaItem(first_track, i)
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_fadein_len = GetMediaItemInfo_Value(item, "D_FADEINLEN")
        local item_fadein_end = item_start + item_fadein_len
        if cur_pos > item_start and cur_pos < item_fadein_end + check_length then
            clash = true
            break
        end
        local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_start + item_length
        local item_fadeout_len = GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
        local item_fadeout_start = item_end - item_fadeout_len
        if cur_pos > item_fadeout_start - check_length and cur_pos < item_end then
            clash = true
            break
        end
    end

    return clash
end

---------------------------------------------------------------------

function return_check_length()
    local check_length = 0.5
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[7] then check_length = table[7] / 1000 end
    end
    return check_length
end

---------------------------------------------------------------------

main()
