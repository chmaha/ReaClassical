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

function M.play_segment(start_pos, stop_pos)
    local my_token = string.format("%.6f_%d", time_precise(), math.random(1, 1000000000))
    SetExtState("ReaClassical", "AuditionToken", my_token, false)

    if GetPlayState() & 1 == 1 then
        OnStopButton()
    end
    SetEditCurPos(start_pos, false, false)
    OnPlayButton()

    if not stop_pos then return end

    local function check_stop()
        local current_token = GetExtState("ReaClassical", "AuditionToken")
        if current_token ~= my_token then
            return
        end
        if GetPlayState() & 1 == 0 then
            return
        end
        if GetPlayPosition() >= stop_pos then
            OnStopButton()
            return
        end
        defer(check_stop)
    end

    defer(check_stop)
end

return M
