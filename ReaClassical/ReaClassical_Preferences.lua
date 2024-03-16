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
    local pass
    local ret, input = display_prefs()
    if ret then pass = pref_check(input) end
    if pass == 1 then save_prefs(input) end
end

-----------------------------------------------------------------------

function display_prefs()
    local _, saved = load_prefs()
    local ret, input
    if saved ~= "" then
        ret, input = GetUserInputs('ReaClassical Project Preferences', 5,
            'S-D Crossfade length (ms),CD track offset (ms),INDEX0 length (s)  (>= 1),Album lead-out time (s),Prepare Takes: Random colors', saved)
    else
        ret, input = GetUserInputs('ReaClassical Project Preferences', 5,
            'S-D Crossfade length (ms),CD track offset (ms),INDEX0 length (s)  (>= 1),Album lead-out time (s),Prepare Takes:: Random colors',
            '35,200,3,7,0')
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
    local pass = 1
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if #table ~= 5 then
        ShowMessageBox('Empty preferences not allowed. Using previously saved values or defaults', "Warning", 0)
        pass = 0
    end
    return pass
end

-----------------------------------------------------------------------

main()
