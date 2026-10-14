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
local pan_from_name = require("ReaClassical_Pan_From_Name")

local list = mm.get_special_tracks_list()
if #list == 0 then
    say("No special tracks found")
    return
end

Undo_BeginBlock()
for _, t in ipairs(list) do
    pan_from_name.apply_pan_from_name(t, mm.get_label(t))
end
Undo_EndBlock("Reset Pan From Name (All Tracks)", -1)
say("Pan reset from track names")
