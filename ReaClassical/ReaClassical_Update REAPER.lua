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
local main, checkTestedVersion, get_path

---------------------------------------------------------------------

function main()
    local update_utility = NamedCommandLookup("_RS852f0872789b997921f7f9d40e6f997553bd5147")
    local ret, tested_ver = checkTestedVersion()
    if ret == "NO_VER" then
        MB("No version number found in ver.txt", "Error", 0)
    elseif ret == "AT_TESTED" then
        local result = MB("You are already at tested REAPER version " .. tested_ver .. ".\nDo you want to continue?",
            "REAPER Version Check", 4)
        if result == 7 then return end -- user answers "no"
    elseif ret == "EXCEEDED" then
        MB("You are running a version of REAPER that has not yet been tested\n" ..
            "Please downgrade to version " .. tested_ver .. " by clicking on the clock icon for old versions.",
            "REAPER Version Check", 0)
    elseif ret == "UPGRADE" then
        MB("You can upgrade to REAPER " .. tested_ver .. ".", "REAPER Version Check", 0)
    end

    Main_OnCommand(update_utility, 0)
end

---------------------------------------------------------------------

function checkTestedVersion()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "tested_reaper_ver.txt")
    local location = resource_path .. relative_path
    local file = io.open(location, "r")

    if not file then
        MB("Cannot find tested_reaper_ver.txt", "Error", 0)
        return
    end

    local content = file:read("*all")
    file:close()

    local versionStr = content:match("====%s*(%d+%.%d+)%s*====")
    if not versionStr then
        return "NO_VER"
    end

    local tested_ver = tonumber(versionStr)
    local current_ver = GetAppVersion():match("(%d+%.%d+)") -- Get major.minor
    current_ver = tonumber(current_ver)

    if current_ver == tested_ver then
        return "AT_TESTED", tested_ver
    elseif current_ver > tested_ver then
        return "EXCEEDED", tested_ver
    else
        return "UPGRADE", tested_ver
    end
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

main()
