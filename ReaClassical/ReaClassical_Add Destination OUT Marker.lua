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

local main, get_color_table, get_path

---------------------------------------------------------------------

function main()
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    DeleteProjectMarker(NULL, 997, false)
    local colors = get_color_table()
    AddProjectMarker2(0, false, cur_pos, 0, "DEST-OUT", 997, colors.dest_marker)
end

---------------------------------------------------------------------

function get_color_table()
local resource_path = GetResourcePath()
local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical","")
package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
return require("ReaClassical_Colors")
end

---------------------------------------------------------------------

function get_path(...)
local pathseparator = package.config:sub(1,1);
local elements = {...}
return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

main()
