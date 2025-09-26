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
local main
local move_cursor_to_time_selection_midpoint
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

    DeleteProjectMarker(NULL, 1016, false)
    CSurf_OnPlayRateChange(audition_speed)
    -- check if left or right item is muted
    local left_mute = GetToggleCommandStateEx(32065, 43633)
    local right_mute = GetToggleCommandStateEx(32065, 43634)
    if right_mute == 1 then CrossfadeEditor_OnCommand(43634) end
    if left_mute == 0 then CrossfadeEditor_OnCommand(43633) end

    -- prevent action 43491 from not playing if mouse cursor doesn't move
    CrossfadeEditor_OnCommand(43483) -- decrease preview momentarily

    CrossfadeEditor_OnCommand(43491) -- set pre/post and play both items
    move_cursor_to_time_selection_midpoint()
end

---------------------------------------------------------------------

function move_cursor_to_time_selection_midpoint()
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        return nil -- no active time selection
    end

    local midpoint = (start_time + end_time) / 2
    SetEditCurPos(midpoint, true, true) -- move cursor, seek playback if playing
    return midpoint
end

---------------------------------------------------------------------

main()
