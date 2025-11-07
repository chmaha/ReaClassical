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
      MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
      return
  end
  local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

  if start_time == end_time then
    Main_OnCommand(41162, 0) -- Automation: Write current values for all writing envelopes from cursor to end of project
  else
    Main_OnCommand(41160, 0) -- Automation: Write current values for all writing envelopes to time selection
  end
  Main_OnCommand(42025, 0)   -- Automation: Clear all track envelope latches
end

---------------------------------------------------------------------

main()
