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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

local MODES = {
    { flag = "XFadeMode", file = "ReaClassical_XFM Mode Daemon.lua",           label = "Crossfade Mode" },
    { flag = "IEMMode",   file = "ReaClassical_Accessible Item Edit Mode.lua", label = "Item Edit Mode" },
    { flag = "MixerMode", file = "ReaClassical_Accessible Mixer Mode.lua",     label = "Mixer Mode" },
}

local exited_any = false

for _, mode in ipairs(MODES) do
    if GetExtState("ReaClassical", mode.flag) == "1" then
        local cid = AddRemoveReaScript(true, 0, script_path .. mode.file, false)
        if cid ~= 0 then
            Main_OnCommand(cid, 0)
            exited_any = true
        end
    end
end

if not exited_any then
    say("No mode active")
end
