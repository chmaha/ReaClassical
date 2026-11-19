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

local audition_playback = require("ReaClassical_Audition_Playback")

local M = {}

local PRE_ROLL = 3.0
local PREF_INDEX = 17

function M.enabled()
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
    local entries = {}
    for entry in saved:gmatch("([^,]+)") do entries[#entries + 1] = entry end
    return tonumber(entries[PREF_INDEX]) == 1
end

function M.marker_pos(marker_id)
    local i = 0
    while true do
        local retval, isrgn, pos, _, _, idx = EnumProjectMarkers(i)
        if retval == 0 then return nil end
        if not isrgn and idx == marker_id then return pos end
        i = i + 1
    end
end

function M.play_from(edit_pos)
    if not edit_pos then return end
    audition_playback.play_segment(math.max(edit_pos - PRE_ROLL, 0), nil)
end

return M
