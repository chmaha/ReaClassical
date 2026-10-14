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
local humanize_timestr = require("ReaClassical_Time_Naming")
local enum_project_markers = require("ReaClassical_Marker_Enum")

local function find_marker_number(target_pos)
    local num_markers = GetNumRegionsOrMarkers(0)
    local closest_num, closest_diff
    for i = 0, num_markers - 1 do
        local _, isrgn, pos, _, _, markrgnindexnumber = enum_project_markers(0, i)
        if not isrgn then
            local diff = math.abs(pos - target_pos)
            if not closest_diff or diff < closest_diff then
                closest_diff = diff
                closest_num = markrgnindexnumber
            end
        end
    end
    return closest_num
end

local function main()
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

    local pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    Main_OnCommand(40157, 0)
    local marker_num = find_marker_number(pos)
    local marker_label = marker_num and ("Marker " .. marker_num .. " added @ ") or "Marker added @ "
    say(marker_label .. humanize_timestr(format_timestr_pos(pos, "", -1)))
end

main()
