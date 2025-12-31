--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local main

---------------------------------------------------------------------

function main()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
      modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
    return
  end
  
  local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
  local i = 0;
  while true do
    local project, _ = EnumProjects(i)
    if project == nil then
      break
    else
      DeleteProjectMarker(project, 1000, false)
    end
    i = i + 1
  end
  AddProjectMarker2(-1, false, cur_pos, 0, "SOURCE PROJECT", 1000, ColorToNative(105, 79, 183) | 0x1000000)
end

---------------------------------------------------------------------

main()
