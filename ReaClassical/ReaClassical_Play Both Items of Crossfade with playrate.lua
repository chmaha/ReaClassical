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
local main

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
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end
    -- check if left or right item is muted
    DeleteProjectMarker(nil, 1016, false)
    local in_bounds = GetToggleCommandStateEx(32065, 43664)
    if in_bounds ~= 1 then CrossfadeEditor_OnCommand(43664) end
    local left_mute = GetToggleCommandStateEx(32065, 43633)
    local right_mute = GetToggleCommandStateEx(32065, 43634)
    if left_mute == 1 then CrossfadeEditor_OnCommand(43633) end
    if right_mute == 1 then CrossfadeEditor_OnCommand(43634) end

    -- prevent action 43491 from not playing if mouse cursor doesn't move
    CrossfadeEditor_OnCommand(43483) -- decrease preview momentarily

    CSurf_OnPlayRateChange(audition_speed)
    CrossfadeEditor_OnCommand(43491) -- set pre/post and play both items
end

---------------------------------------------------------------------

main()
