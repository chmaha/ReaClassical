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
local humanize_marker_label = require("ReaClassical_Marker_Naming")
local enum_project_markers = require("ReaClassical_Marker_Enum")

local main, snapshot_markers

function snapshot_markers()
    local snap = {}
    local num_markers = GetNumRegionsOrMarkers(0)
    for idx = 0, num_markers - 1 do
        local retval, isrgn, pos, _, name, num = enum_project_markers(0, idx)
        if retval and not isrgn then
            snap[num] = { pos = pos, name = name }
        end
    end
    return snap
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

    local before = snapshot_markers()
    Main_OnCommand(40613, 0)
    local after = snapshot_markers()

    for num, marker in pairs(before) do
        if not after[num] then
            local label = marker.name ~= "" and humanize_marker_label(marker.name) or ("Marker " .. num)
            say(label .. " deleted @ " .. humanize_timestr(format_timestr_pos(marker.pos, "", -1)))
            return
        end
    end

    say("No marker to delete")
end

main()
