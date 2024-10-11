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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end
local main

---------------------------------------------------------------------

function main()
  Main_OnCommand(42022, 0) -- Global automation override: All automation in latch preview mode
  local message
  local _, val = GetProjExtState(0, "ReaClassical", "AutomationModeSet")
  if val ~= "1" then
    message = "You are now in \"latch preview\" automation mode (blue button)."
        .. "\n1. Set mixer controls (volume, pan, any FX parameters)"
        .. "\n2. Press I to place envelope points at the edit cursor location or inside a time selection if present."
        .. "\n3. Re-run this function to return to global read mode (green button)."
    SetProjExtState(0, "ReaClassical", "AutomationModeSet", "1")
    MB(message, "Automation Mode", 0)
  else
    SetProjExtState(0, "ReaClassical", "AutomationModeSet", "0")
    Main_OnCommand(40879, 0) -- Global automation override: All automation in latch preview mode
  end
end

---------------------------------------------------------------------

main()
