--[[
@noindex
This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.
Copyright (C) 2022–2024 chmaha
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
    Main_OnCommand(40296, 0) -- Track: Select all tracks
    folders = folder_check()
    local zoom = NamedCommandLookup("_SWS_VZOOMFIT")
    Main_OnCommand(zoom, 0) -- SWS: Vertical zoom to selected tracks
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
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

main()
