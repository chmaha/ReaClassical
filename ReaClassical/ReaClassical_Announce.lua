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

---------------------------------------------------------------------

-- Shared announcement function for every non-ImGui ReaClassical script.
-- Speaks via OSARA when it's installed; otherwise stays silent unless
-- debug=y has been set in the Terminal (debug=y/debug?/debug=n), in which
-- case it prints to the console instead -- lets development/testing of
-- announcements happen on platforms without OSARA (e.g. Linux) without
-- spamming the console for ordinary end users who simply don't have
-- OSARA installed.
local function say(msg)
    if osara_outputMessage then
        osara_outputMessage(tostring(msg))
    elseif GetExtState("ReaClassical", "DebugAnnounce") == "y" then
        ShowConsoleMsg(tostring(msg) .. "\n")
    end
end

---------------------------------------------------------------------

return say
