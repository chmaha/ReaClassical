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
local main, sync_based_on_workflow

---------------------------------------------------------------------

local _, RCProject = GetProjExtState(0, "ReaClassical", "RCProject")
if RCProject ~= "y" then
  MB("This function can only run on a ReaClassical project. Create one in an empty project via F7 or F8.",
    "ReaClassical", 0)
  return
end

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
  PreventUIRefresh(1)
  Main_OnCommand(42022, 0) -- Global automation override: All automation in latch preview mode
  local message
  local _, automation = GetProjExtState(0, "ReaClassical", "AutomationModeSet")
  local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
  if automation ~= "1" then
    if mastering ~= "1" then
      SetProjExtState(0, "ReaClassical", "MasteringModeSet", 1)
    end

    sync_based_on_workflow(workflow)

    PreventUIRefresh(-1)
    message = "You are now in \"latch preview\" automation mode (\"blue button\" mode)."
        .. "\n1. Set mixer controls (volume, pan, any FX parameters)"
        .. "\n2. Press I to place envelope points at the edit cursor location or inside a time selection if present."
        .. "\n3. Press Ctrl+I again to return to global read mode (\"green button\" mode)."
        .. "\n\nTo exit both automation and mastering modes press Ctrl+M."
    SetProjExtState(0, "ReaClassical", "AutomationModeSet", "1")
    MB(message, "Automation Mode", 0)
  else
    SetProjExtState(0, "ReaClassical", "AutomationModeSet", "0")
    Main_OnCommand(40879, 0) -- Global automation override: All automation in latch preview mode
  end
end

---------------------------------------------------------------------

function sync_based_on_workflow(workflow)
  if workflow == "Vertical" then
    local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
    Main_OnCommand(F8_sync, 0)
  elseif workflow == "Horizontal" then
    local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
    Main_OnCommand(F7_sync, 0)
  end
end

-----------------------------------------------------------------------

main()
