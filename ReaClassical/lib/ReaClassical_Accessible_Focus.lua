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

local M = {}

function M.refocus_existing(title)
    if APIExists("clara_findWindow") then
        local hwnd = reaper.clara_findWindow(title)
        if not hwnd then return false end
        reaper.clara_setFocus(hwnd)
        return true
    end
    if not APIExists("JS_Window_SetFocus") then return false end
    local hwnd = reaper.JS_Window_Find(title, true)
    if not hwnd then return false end
    reaper.JS_Window_SetFocus(hwnd)
    return true
end

return M
