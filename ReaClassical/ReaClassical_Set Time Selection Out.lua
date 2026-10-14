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

local main, format_spoken_time

function format_spoken_time(seconds)
    if seconds < 60 then
        return string.format("%.2f seconds", seconds)
    end
    local mins = math.floor(seconds / 60)
    local secs = seconds - mins * 60
    return string.format("%d minute%s %.2f seconds", mins, mins ~= 1 and "s" or "", secs)
end

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

    Main_OnCommand(40626, 0)

    local start_pos, end_pos = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local msg = "Out point set at " .. format_spoken_time(end_pos)
    if end_pos > start_pos then
        msg = msg .. ". Selection length " .. format_spoken_time(end_pos - start_pos)
    end
    say(msg)
end

main()
