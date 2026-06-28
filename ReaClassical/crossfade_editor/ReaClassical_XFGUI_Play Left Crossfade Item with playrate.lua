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
local main, move_cursor_to_time_selection_midpoint, stop_at_midpoint
---------------------------------------------------------------------

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local audition_speed = 0.75
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[9] then audition_speed = tonumber(table[9]) or 0.75 end
end

set_action_options(3)

function main()
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
    local in_bounds = GetToggleCommandStateEx(32065, 43664)
    if in_bounds ~= 1 then CrossfadeEditor_OnCommand(43664) end
    -- check if left or right item is muted
    local left_mute = GetToggleCommandStateEx(32065, 43633)
    local right_mute = GetToggleCommandStateEx(32065, 43634)
    if left_mute == 1 then CrossfadeEditor_OnCommand(43633) end
    if right_mute == 0 then CrossfadeEditor_OnCommand(43634) end
    local midpoint = move_cursor_to_time_selection_midpoint()
    if not midpoint then
        local in_bounds2 = GetToggleCommandStateEx(32065, 43664)
        if in_bounds2 ~= 1 then CrossfadeEditor_OnCommand(43664) end
        CrossfadeEditor_OnCommand(43483)
        CSurf_OnPlayRateChange(1)
        CrossfadeEditor_OnCommand(43491) -- this creates the time selection
        midpoint = move_cursor_to_time_selection_midpoint()
        if not midpoint then return end -- still no selection, give up silently
    end
    CSurf_OnPlayRateChange(audition_speed)
    -- prevent action 43491 from not playing if mouse cursor doesn't move
    CrossfadeEditor_OnCommand(43483) -- decrease preview momentarily
    CrossfadeEditor_OnCommand(43491) -- set pre/post and play both items
    defer(function() stop_at_midpoint(midpoint) end)
end

---------------------------------------------------------------------

function move_cursor_to_time_selection_midpoint()
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        return nil -- no active time selection
    end
    local midpoint = (start_time + end_time) / 2
    SetEditCurPos(midpoint, true, false)
    return midpoint
end

---------------------------------------------------------------------

function stop_at_midpoint(midpoint)
    if GetPlayState() == 0 then
        Main_OnCommand(41185, 0)
        return
    end
    if GetPlayPosition() >= midpoint then
        Main_OnCommand(1016, 0)
        Main_OnCommand(41185, 0)
        return
    end
    defer(function() stop_at_midpoint(midpoint) end)
end

---------------------------------------------------------------------

main()
