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
local mm  = require("ReaClassical_MM_Utils")

local list = mm.get_special_tracks_list()
if #list == 0 then
    say("No special tracks found")
    return
end

local current = mm.get_current_target()
local idx = 1
for i, t in ipairs(list) do
    if t == current then idx = i break end
end
idx = idx > 1 and idx - 1 or #list

local target = list[idx]
mm.set_current_target(target)
say(mm.get_label(target) .. ", " .. mm.format_peak(target) .. mm.status_suffix(target))
