--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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


for key in pairs(reaper) do _G[key] = reaper[key] end

---------------------------------------------------------------------

function main()
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    local track_number = math.floor(get_track_number())
    DeleteProjectMarker(NULL, 999, false)
    AddProjectMarker2(0, false, cur_pos, 0, track_number .. ":SOURCE-OUT", 999, ColorToNative(23, 223, 143) | 0x1000000)
end

---------------------------------------------------------------------

function folder_check()
    local folders = 0
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        end
    end
    return folders
end

---------------------------------------------------------------------

function get_track_number()
    local selected = GetSelectedTrack(0, 0)
    if folder_check() == 0 or selected == nil then
        return 1
    elseif GetMediaTrackInfo_Value(selected, "I_FOLDERDEPTH") == 1 then
        return GetMediaTrackInfo_Value(selected, "IP_TRACKNUMBER")
    else
        local folder = GetParentTrack(selected)
        return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
    end
end

---------------------------------------------------------------------

main()
