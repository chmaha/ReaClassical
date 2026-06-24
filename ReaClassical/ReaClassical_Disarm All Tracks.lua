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
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")

-- Disarms every track in the project except the listenback (cue/foldback
-- monitoring) track, which stays armed -- mirrors how
-- clear_all_rec_armed_except_live treats it in Classical Take Record.
local function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()

    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local _, lb_flag = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        if lb_flag ~= "y" then
            SetMediaTrackInfo_Value(track, "I_RECARM", 0)
        end
    end

    TrackList_AdjustWindows(false)
    PreventUIRefresh(-1)
    Undo_EndBlock("Disarm All Tracks", 0)
    UpdateArrange()
    UpdateTimeline()

    say("All tracks disarmed")
end

main()
