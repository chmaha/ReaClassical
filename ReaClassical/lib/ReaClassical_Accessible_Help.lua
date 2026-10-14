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

local say = require("ReaClassical_Announce")

local M = {}

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ESC   = 27

local active = false
local idx = 1
local list = {}
local resume_text = nil

function M.is_active()
    return active
end

local function announce_current()
    local entry = list[idx]
    say(string.format("%s: %s", entry.desc, entry.key))
end

function M.enter(shortcuts, resume)
    if not shortcuts or #shortcuts == 0 then return end
    active = true
    idx = 1
    list = shortcuts
    resume_text = resume
    say(string.format("Help: %d shortcut%s. Up or down to browse, H or Escape to close.",
        #list, #list == 1 and "" or "s"))
    announce_current()
end

function M.exit()
    active = false
    if type(resume_text) == "function" then
        resume_text()
    elseif resume_text then
        say(resume_text)
    end
end

function M.handle_key(char)
    if not active then return false end

    if char == KEY_UP then
        idx = idx > 1 and idx - 1 or #list
        announce_current()
        return true
    elseif char == KEY_DOWN then
        idx = idx < #list and idx + 1 or 1
        announce_current()
        return true
    elseif char == KEY_ESC or char == 72 or char == 104 then
        M.exit()
        return true
    end

    active = false
    return false
end

return M
