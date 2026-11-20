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

local M = {}

M.OFFSET = 2
local DOWN_RANK_CMD = 43177
local STATE_KEY = "LastBlemish"

function M.mark()
    local play_state = GetPlayState()
    local active = (play_state & 1) == 1 or (play_state & 4) == 4
    local pos = active and math.max(GetPlayPosition() - M.OFFSET, 0) or GetCursorPosition()
    Undo_BeginBlock()
    Main_OnCommand(DOWN_RANK_CMD, 0)
    Undo_EndBlock("Mark Blemish", -1)
    SetExtState("ReaClassical", STATE_KEY, string.format("%.6f|%.6f", time_precise(), pos), false)
    return pos
end

function M.last()
    local state = GetExtState("ReaClassical", STATE_KEY)
    local stamp, pos = state:match("^([%d%.]+)|([%d%.]+)$")
    if not stamp then return nil end
    return tonumber(stamp), tonumber(pos)
end

function M.describe(pos)
    return "Blemish marked at " .. format_timestr_pos(pos, "", 0)
end

return M
