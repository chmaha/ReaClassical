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
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local humanize_timestr = require("ReaClassical_Time_Naming")

local main

---------------------------------------------------------------------

function main()
    local state = GetPlayState()
    local pos = state ~= 0 and GetPlayPosition() or GetCursorPosition()
    local timestr = humanize_timestr(format_timestr_pos(pos, "", -1))

    if state == 0 then
        say(timestr)
    else
        local label
        if state & 4 == 4 and state & 2 == 2 then
            label = "recording paused"
        elseif state & 4 == 4 then
            label = "recording"
        elseif state & 2 == 2 then
            label = "paused"
        else
            label = "playing"
        end
        say(timestr .. ", " .. label)
    end
end

---------------------------------------------------------------------

main()
