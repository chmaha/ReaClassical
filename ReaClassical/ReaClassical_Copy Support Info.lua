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

local function reaclassical_version()
    if not APIExists("ReaPack_GetOwner") then return "n/a (ReaPack API not found)" end
    local path = ({ get_action_context() })[2]
    if not path or path == "" then return "n/a" end
    local entry = ReaPack_GetOwner(path)
    if not entry then return "n/a (not installed via ReaPack)" end
    local ok, _, _, _, _, _, version = ReaPack_GetEntryInfo(entry)
    ReaPack_FreeEntry(entry)
    return (ok and version and version ~= "") and version or "n/a"
end

local EXPECTED_INSTALL_TOKEN = "f00f66c310c4c81d271f787519e90494feef82e2304b5499b7ffa84f01edf883"

local function install_code(path)
    local f = io.open(path, "r")
    local first = f and f:read("l")
    if f then f:close() end
    math.randomseed(math.floor(time_precise() * 1000000))
    local mid = "+"
    if first ~= EXPECTED_INSTALL_TOKEN then
        local others = "-_.~!#%@=*"
        local i = math.random(1, #others)
        mid = others:sub(i, i)
    end
    return string.format("%06x%s%06x", math.random(0, 0xffffff), mid, math.random(0, 0xffffff))
end

local function main()
    local lines = {
        "ReaClassical " .. reaclassical_version(),
        "REAPER " .. GetAppVersion(),
        "Install code: " .. install_code(GetResourcePath() .. package.config:sub(1, 1) .. "rc_portable"),
    }
    local text = table.concat(lines, "\n")
    local copied = APIExists("CF_SetClipboard")
    if copied then CF_SetClipboard(text) end
    MB(text .. "\n\n" .. (copied and "Copied to the clipboard. Paste it into your support request."
        or "Please copy this into your support request (copying to the clipboard needs the SWS extension)."),
        "ReaClassical Support Info", 0)
end

main()
