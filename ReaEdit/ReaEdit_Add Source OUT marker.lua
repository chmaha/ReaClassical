--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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
local function say(msg)
    if APIExists("osara_outputMessage") then osara_outputMessage(tostring(msg)) end
end
local is_accessible = APIExists("osara_outputMessage")
local humanize_timestr = require("ReaEdit_Time_Naming")
local enum_project_markers = require("ReaEdit_Marker_Enum")

local main, find_marker_pos

local source_marker = ColorToNative(23, 223, 143) | 0x1000000

function main()
    PreventUIRefresh(1)
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()

    if cur_pos ~= -1 then
        local existing_in_pos
        if is_accessible then
            local proj = EnumProjects(-1)
            existing_in_pos = proj and find_marker_pos(proj, 998, "SOURCE-IN")
        end

        if existing_in_pos and cur_pos <= existing_in_pos then
            say("Source out must be after source in.")
        else
            Undo_BeginBlock()
            local i = 0
            while true do
                local project, _ = EnumProjects(i)
                if project == nil then
                    break
                else
                    DeleteProjectMarker(project, 999, false)
                end
                i = i + 1
            end

            AddProjectMarker2(0, false, cur_pos, 0, "SOURCE-OUT", 999, source_marker)
            Undo_EndBlock("Add Source Out Marker", -1)
            say("Added source out @ " .. humanize_timestr(format_timestr_pos(cur_pos, "", -1)))
        end
    end
    PreventUIRefresh(-1)
end

function find_marker_pos(proj, marker_id, marker_label)
    local num_markers = GetNumRegionsOrMarkers(proj)

    for i = 0, num_markers - 1 do
        local _, isrgn, pos, _, label, markrgnindexnumber = enum_project_markers(proj, i)
        if not isrgn and markrgnindexnumber == marker_id and label == marker_label then
            return pos
        end
    end

    return nil
end

main()
