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
local parent_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path

local M = {}

function M.handle_transport_key(char)
    if char == 32 then
        local shift_held = gfx.mouse_cap & 8 == 8
        dofile(parent_path .. (shift_held
            and "ReaClassical_Play Stop Moving Edit Cursor.lua"
            or  "ReaClassical_Play Stop.lua"))
        return true
    end
    local ctrl_held = gfx.mouse_cap & 4 == 4
    if ctrl_held and char == 61 then
        Main_OnCommand(40085, 0)
        return true
    elseif ctrl_held and char == 45 then
        Main_OnCommand(40084, 0)
        return true
    end
    return false
end

return M
