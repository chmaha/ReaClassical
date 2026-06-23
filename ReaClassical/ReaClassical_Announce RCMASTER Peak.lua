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

local main, get_rcmaster_track, format_peak

---------------------------------------------------------------------

function get_rcmaster_track()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if rcmaster_state == "y" or name:find("^RCMASTER") ~= nil then
            return track
        end
    end
    return nil
end

---------------------------------------------------------------------

function format_peak(track)
    -- Matches ReaClassical_Meterbridge.lua's numeric display: peak hold,
    -- not cleared (clearing would also reset the visible meter's hold line).
    local peak = -150.0
    local num_chans = math.min(GetMediaTrackInfo_Value(track, "I_NCHAN"), 2)
    for ch = 0, num_chans - 1 do
        local val = Track_GetPeakHoldDB(track, ch, false) * 100
        if val > peak then peak = val end
    end
    if peak <= -150.0 then return "silence" end
    return string.format("%.1f dB", peak)
end

---------------------------------------------------------------------

function main()
    local rcmaster = get_rcmaster_track()
    if not rcmaster then
        say("No RCMASTER track found.")
        return
    end

    say(format_peak(rcmaster))
end

---------------------------------------------------------------------

main()
