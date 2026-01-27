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
    MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
    return
  end

  local i = 0
  while true do
    local project, _ = EnumProjects(i)
    if not project then break end

    local _, num_markers, num_regions = CountProjectMarkers(project)
    local total = num_markers + num_regions

    -- Loop backwards so indices remain valid when deleting
    for j = total - 1, 0, -1 do
      local ok, isrgn, _, _, name, _ = EnumProjectMarkers2(project, j)
      if ok and not isrgn and name then
        if name:match("^%d+:SAI") or name:match("^%d+:SAO") then
          DeleteProjectMarkerByIndex(project, j)
        end
      end
    end

    i = i + 1
  end
end

---------------------------------------------------------------------

main()
