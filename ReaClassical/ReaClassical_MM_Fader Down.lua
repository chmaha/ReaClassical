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
local groups = require("ReaClassical_MM_Groups")

local FADER_STEP = 1

local track = mm.get_current_target()
if not track then
    say("No special tracks found")
    return
end

local targets, grouped, group_name = groups.get_action_targets(track, "fader")
local anchor_db
for _, t in ipairs(targets) do
    local db = mm.linear_to_db(GetMediaTrackInfo_Value(t, "D_VOL")) - FADER_STEP
    SetMediaTrackInfo_Value(t, "D_VOL", mm.db_to_linear(db))
    if t == track then anchor_db = db end
end
say(string.format("Fader %.1f dB", anchor_db) .. (grouped and (", " .. group_name .. " group") or ""))
