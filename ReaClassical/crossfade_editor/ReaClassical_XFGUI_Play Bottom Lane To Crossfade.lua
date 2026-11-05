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
local get_out_of_bounds_cmd, set_out_of_bounds

local stop_token

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

    stop_token = tostring(time_precise())
    SetExtState("ReaClassical", "XFGUI_StopToken", stop_token, false)
    set_out_of_bounds()
    local left_mute = GetToggleCommandStateEx(32065, 43633)
    local right_mute = GetToggleCommandStateEx(32065, 43634)
    if left_mute == 1 then CrossfadeEditor_OnCommand(43633) end
    if right_mute == 0 then CrossfadeEditor_OnCommand(43634) end
    local midpoint = move_cursor_to_time_selection_midpoint()
    if not midpoint then
        set_out_of_bounds()
        CrossfadeEditor_OnCommand(43483)
        CSurf_OnPlayRateChange(1)
        CrossfadeEditor_OnCommand(43491)
        midpoint = move_cursor_to_time_selection_midpoint()
        if not midpoint then return end
    end
    CSurf_OnPlayRateChange(1)
    CrossfadeEditor_OnCommand(43483)
    CrossfadeEditor_OnCommand(43491)
    defer(function() stop_at_midpoint(midpoint) end)
end

function move_cursor_to_time_selection_midpoint()
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        return nil
    end
    local midpoint = (start_time + end_time) / 2
    SetEditCurPos(midpoint, true, false)
    return midpoint
end

function stop_at_midpoint(midpoint)
    if GetExtState("ReaClassical", "XFGUI_StopToken") ~= stop_token then return end
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

function get_out_of_bounds_cmd()
    local section = SectionFromUniqueID(32065)
    local i = 0
    while true do
        local cmd, name = kbd_enumerateActions(section, i)
        if not cmd or cmd == 0 then return nil end
        if name == "Preview: Play out of bounds audio only" then return cmd end
        i = i + 1
    end
end

function set_out_of_bounds()
    local cmd = get_out_of_bounds_cmd()
    if not cmd then return end
    if GetToggleCommandStateEx(32065, cmd) ~= 1 then CrossfadeEditor_OnCommand(cmd) end
end

main()
