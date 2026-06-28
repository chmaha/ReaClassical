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

-- When debug=on is set via the Terminal, install a global osara_outputMessage
-- shim that prints to the console. This makes every OSARA check in every
-- ReaClassical script (e.g. "if osara_outputMessage then") behave as if OSARA
-- is installed, so headless/blind code paths can be tested on Linux or any
-- platform without a real screen reader. Ordinary users without OSARA and
-- without debug mode are unaffected: the shim is never installed.
if not osara_outputMessage and GetExtState("ReaClassical", "DebugAnnounce") == "on" then
    osara_outputMessage = function(msg) ShowConsoleMsg(tostring(msg) .. "\n") end
end

-- Shared announcement function for every non-ImGui ReaClassical script.
local function say(msg)
    if osara_outputMessage then
        osara_outputMessage(tostring(msg))
    end
end

---------------------------------------------------------------------

return say
