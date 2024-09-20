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

local main, display_prefs, load_prefs, save_prefs, pref_check

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local pass
    local ret, input = display_prefs()
    if ret then pass = pref_check(input) end
    if pass == true then save_prefs(input) end

    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    elseif workflow == "Horizontal" then
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end
end

-----------------------------------------------------------------------

function display_prefs()
    local _, saved = load_prefs()
    local ret, input
    if saved ~= "" then
        ret, input = GetUserInputs('ReaClassical Project Preferences', 7,
            'S-D Crossfade length (ms),CD track offset (ms),INDEX0 length (s)  (>= 1),Album lead-out time (s),Prepare Takes: Random colors,Mastering Mode,S-D Marker Check (ms)', saved)
    else
        ret, input = GetUserInputs('ReaClassical Project Preferences', 7,
            'S-D Crossfade length (ms),CD track offset (ms),INDEX0 length (s)  (>= 1),Album lead-out time (s),Prepare Takes: Random colors,Mastering Mode,S-D Marker Check (ms)',
            '35,200,3,7,0,0,500')
    end
    return ret, input
end

-----------------------------------------------------------------------

function load_prefs()
    return GetProjExtState(0, "ReaClassical", "Preferences")
end

-----------------------------------------------------------------------

function save_prefs(input)
    SetProjExtState(0, "ReaClassical", "Preferences", input)
end

-----------------------------------------------------------------------

function pref_check(input)
    local pass = true
    local valid_numbers = true
    local table = {}
    for entry in input:gmatch('([^,]+)') do
        if tonumber(entry) == nil or tonumber(entry) < 0 then valid_numbers = false end
        table[#table + 1] = entry 
    end

    -- separate check for binary options
    if tonumber(table[5]) > 1 or tonumber(table[6]) > 1 then valid_numbers = false end

    if #table ~= 7 or valid_numbers == false then
        ShowMessageBox('Invalid or empty preferences are not allowed. Using previously saved values or defaults', "Warning", 0)
        pass = false
    end
    return pass
end

-----------------------------------------------------------------------

main()
