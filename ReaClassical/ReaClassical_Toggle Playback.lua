--[[

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

-- Toggles mute on the PLAYBACK track. The track is created muted by default;
-- this script unmutes it for monitoring, or mutes it again.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

---------------------------------------------------------------------

local pb_track = nil
for i = 0, CountTracks(0) - 1 do
    local t = GetTrack(0, i)
    local _, pb_state = GetSetMediaTrackInfo_String(t, "P_EXT:playback", "", false)
    if pb_state == "y" then
        pb_track = t
        break
    end
end

if not pb_track then
    MB("No PLAYBACK track found.", "ReaClassical", 0)
    return
end

local muted = GetMediaTrackInfo_Value(pb_track, "B_MUTE")
if muted == 1 then
    SetMediaTrackInfo_Value(pb_track, "B_MUTE", 0)
    say("Playback unmuted")
else
    SetMediaTrackInfo_Value(pb_track, "B_MUTE", 1)
    say("Playback muted")
end
