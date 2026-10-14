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
local enum_project_markers = require("ReaClassical_Marker_Enum")

local main

local RESERVED_IDS = { [996] = true, [997] = true, [998] = true, [999] = true, [1000] = true, [1001] = true }

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

    PreventUIRefresh(1)
    Undo_BeginBlock()
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then break end

        local num_markers = GetNumRegionsOrMarkers(project)
        local to_delete = {}
        for idx = 0, num_markers - 1 do
            local retval, isrgn, _, _, _, markrgnindexnumber = enum_project_markers(project, idx)
            if retval and not isrgn and not RESERVED_IDS[markrgnindexnumber] then
                to_delete[#to_delete + 1] = markrgnindexnumber
            end
        end

        for _, id in ipairs(to_delete) do
            DeleteProjectMarker(project, id, false)
        end

        i = i + 1
    end
    Undo_EndBlock("Delete All Generic Markers", -1)
    PreventUIRefresh(-1)
    say("All generic markers deleted")
end

main()
