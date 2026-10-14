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

local projects = {}
local current_proj = EnumProjects(-1)
local current_idx = nil

local i = 0
while true do
    local proj, fn = EnumProjects(i)
    if not proj then break end
    projects[#projects + 1] = fn
    if proj == current_proj then current_idx = #projects end
    i = i + 1
end

Main_OnCommand(40861, 0)

if #projects == 0 then return end

local next_idx = current_idx and (current_idx % #projects) + 1 or 1
local fn = projects[next_idx]
local name = fn:match("([^\\/]+)$") or fn

if name == "" then
    say("Project Tab: Untitled project")
else
    say("Project Tab: " .. (name:gsub("%.[Rr][Pp][Pp]$", "")))
end
