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

-- Play 3 seconds before the crossfade center and stop at the center.
-- Repeated presses restart from the top (set_action_options(3)).

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

set_action_options(3)

---------------------------------------------------------------------

local PRE = 3.0

local function play_segment(start_pos, stop_pos)
    SetEditCurPos(start_pos, false, false)
    OnPlayButton()
    local function check_stop()
        if GetPlayState() & 1 == 0 then return end
        if GetPlayPosition() >= stop_pos then
            OnStopButton()
            return
        end
        defer(check_stop)
    end
    defer(check_stop)
end

local function main()
    if not xfu.is_xfade_mode() then return end
    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end

    local start_pos = math.max(0, ctx.center - PRE)
    local stop_pos  = ctx.center
    play_segment(start_pos, stop_pos)
end

---------------------------------------------------------------------

main()
