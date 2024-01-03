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
    local track_count = CountTracks(0)
    folders = folder_check()
    if folders == 0 then
        ShowMessageBox("Please use either the 'Create folder' or 'Create Source Groups' script first!",
            "Add Aux/Submix track", 0)
        return
    end
    Undo_BeginBlock()
    Main_OnCommand(40702, 0) -- Add track to end of tracklist
    track = GetSelectedTrack(0, 0)
    native_color = ColorToNative(76, 145, 101)
    SetTrackColor(track, native_color)
    GetSetMediaTrackInfo_String(track, "P_NAME", "@", true) -- Add @ as track name
    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
    Main_OnCommand(40297, 0)
    local home = NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
    Main_OnCommand(home, 0)
    Undo_EndBlock("Add Aux/Submix track", 0)
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
