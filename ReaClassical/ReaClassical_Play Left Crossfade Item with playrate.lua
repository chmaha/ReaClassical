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
local main, move_cursor_to_time_selection_midpoint, get_color_table
local get_path, on_stop
---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local audition_speed = 0.75
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[9] then audition_speed = tonumber(table[9]) or 0.75 end
end

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local marker_actions = NamedCommandLookup("_SWSMA_ENABLE")
    Main_OnCommand(marker_actions, 0)
    local in_bounds = GetToggleCommandStateEx(32065, 43664)
    if in_bounds ~= 1 then CrossfadeEditor_OnCommand(43664) end
    -- check if left or right item is muted
    local left_mute = GetToggleCommandStateEx(32065, 43633)
    local right_mute = GetToggleCommandStateEx(32065, 43634)
    if left_mute == 1 then CrossfadeEditor_OnCommand(43633) end
    if right_mute == 0 then CrossfadeEditor_OnCommand(43634) end
    local midpoint = move_cursor_to_time_selection_midpoint()
    local colors = get_color_table()
    CSurf_OnPlayRateChange(audition_speed)
    -- prevent action 43491 from not playing if mouse cursor doesn't move
    CrossfadeEditor_OnCommand(43483) -- decrease preview momentarily

    CrossfadeEditor_OnCommand(43491) -- set pre/post and play both items
    AddProjectMarker2(0, false, midpoint, 0, "!1016", 1016, colors.audition)
    on_stop()
end

---------------------------------------------------------------------

function move_cursor_to_time_selection_midpoint()
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        return nil -- no active time selection
    end

    local midpoint = (start_time + end_time) / 2
    SetEditCurPos(midpoint, true, false) -- move cursor, seek playback if playing
    return midpoint
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

function on_stop()
    if GetPlayState() == 0 then
        DeleteProjectMarker(NULL, 1016, false)
        Main_OnCommand(41185, 0) -- Item properties: Unsolo all
        return
    else
        defer(on_stop)
    end
end

---------------------------------------------------------------------

main()
