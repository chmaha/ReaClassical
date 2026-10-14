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

local function say(msg)
  if APIExists("osara_outputMessage") then osara_outputMessage(tostring(msg)) end
end

local main

function main()
  Undo_BeginBlock()
  local i = 0
  while true do
    local project, _ = EnumProjects(i)
    if project == nil then
      break
    else
      DeleteProjectMarker(project, 996, false)
      DeleteProjectMarker(project, 997, false)
      DeleteProjectMarker(project, 998, false)
      DeleteProjectMarker(project, 999, false)
    end
    i = i + 1
  end
  Undo_EndBlock("Delete All S-D Markers", -1)
  say("All S-D markers deleted")
end

main()
