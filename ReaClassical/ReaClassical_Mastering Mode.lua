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
local main, sync_based_on_workflow

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, RCProject = GetProjExtState(0, "ReaClassical", "RCProject")
if RCProject ~= "y" then
  MB("This function can only run on a ReaClassical project. Create one in an empty project via F7 or F8.",
    "ReaClassical", 0)
  return
end

function main()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  local message
  local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
  if mastering ~= "1" then
    local save_view = NamedCommandLookup("_SWS_SAVEVIEW")
    Main_OnCommand(save_view, 0)
    SetProjExtState(0, "ReaClassical", "MasteringModeSet", 1)
    sync_based_on_workflow(workflow)
    local restore_mastering_view = NamedCommandLookup("_WOL_RESTOREVIEWS5")
    Main_OnCommand(restore_mastering_view, 0)
    message = "You are now in \"Mastering\" Mode. To leave, press Ctrl+M again.\n" ..
        "Any source groups are hidden and mixer tracks are now shown in the TCP for automation purposes.\n" ..
        "Automation Mode can be engaged and disengaged via the Ctrl+I toggle."
    SetProjExtState(0, "ReaClassical", "MasteringModeSet", "1")
    MB(message, "Mastering Mode", 0)
  else
    SetProjExtState(0, "ReaClassical", "MasteringModeSet", 0)
    SetProjExtState(0, "ReaClassical", "AutomationModeSet", 0)
    Main_OnCommand(40879, 0) -- Global automation override: All automation in latch preview mode
    local save_mastering_view = NamedCommandLookup("_WOL_SAVEVIEWS5")
    Main_OnCommand(save_mastering_view, 0)
    sync_based_on_workflow(workflow)
    local restore_view = NamedCommandLookup("_SWS_RESTOREVIEW")
    Main_OnCommand(restore_view, 0)
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
