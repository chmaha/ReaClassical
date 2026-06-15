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

local main, reset_track_peaks

---------------------------------------------------------------------

function main()
    for i = 0, CountTracks(0) - 1 do
        reset_track_peaks(GetTrack(0, i))
    end
    reset_track_peaks(GetMasterTrack(0))
end

---------------------------------------------------------------------

function reset_track_peaks(track)
    local nch = math.floor(GetMediaTrackInfo_Value(track, "I_NCHAN"))
    for ch = 0, nch - 1 do
        Track_GetPeakHoldDB(track, ch, true)
    end
end

---------------------------------------------------------------------

main()
