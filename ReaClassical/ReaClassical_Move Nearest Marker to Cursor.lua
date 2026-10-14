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

    local cursor = GetCursorPosition()
    local num = GetNumRegionsOrMarkers(0)
    local closest, closest_dist
    for i = 0, num - 1 do
        local marker = GetRegionOrMarker(0, i, "")
        if marker and GetRegionOrMarkerInfo_Value(0, marker, "B_ISREGION") == 0.0 then
            local pos = GetRegionOrMarkerInfo_Value(0, marker, "D_STARTPOS")
            local dist = math.abs(pos - cursor)
            if not closest or dist < closest_dist then
                closest, closest_dist = marker, dist
            end
        end
    end
    if closest then
        Undo_BeginBlock()
        SetRegionOrMarkerInfo_Value(0, closest, "D_STARTPOS", cursor)
        Undo_EndBlock("Move closest project marker to edit cursor", -1)
    end

    local after = snapshot_markers()

    for num, marker in pairs(before) do
        local moved = after[num]
        if moved and math.abs(moved.pos - marker.pos) > 1e-6 then
            local label = moved.name ~= "" and humanize_marker_label(moved.name) or ("Marker " .. num)
            say(label .. " moved @ " .. humanize_timestr(format_timestr_pos(moved.pos, "", -1)))
            return
        end
    end

    say("No marker to move")
end

main()
