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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, folder_check

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    if folder_check() > 0 then
        ShowMessageBox("You can either import your media on one regular track for horizontal editing \z
                        or on multiple regular tracks for a vertical workflow.\n\z
                        The function will automatically create the required folder group(s).\z
                    \nTo explode multi-channel after editing has started, \z
                    please use on an empty project tab and copy across.", "Error: Folders detected!", 0)
        return
    end
    if CountSelectedMediaItems(0) == 0 then
        ShowMessageBox("Please select one or more multi-channel media items before running the script.", "Error", 0)
        return
    end

    SetProjExtState(0, "ReaClassical", "RCProject", "y")
    local num = CountSelectedMediaItems(0, 0)

    local takes = {}
    local items = {}
    --local track_number
    for i = 0, num - 1 do
        local item = GetSelectedMediaItem(0, i)
        items[#items + 1] = item
        local take = GetActiveTake(item)
        takes[#takes + 1] = take
    end

    -- Item: Explode multichannel audio or MIDI to new one-channel items
    Main_OnCommand(40894, 0)

    local int = ShowMessageBox("Do you want to treat the first two iso tracks as interleaved stereo?",
        "Multi-channel Explode", 4)
    if int == 6 then
        local prev_track_number
        for _, item in pairs(items) do
            local item_track = GetMediaItem_Track(item)
            local track_number = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER")
            if track_number == prev_track_number then goto continue end
            local second_track = GetTrack(0, track_number)
            local third_track = GetTrack(0, track_number+1)
            DeleteTrack(second_track)
            DeleteTrack(third_track)
            prev_track_number = track_number
            ::continue::
        end

        for _, take in pairs(takes) do
            SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 67)
        end

        for _, item in pairs(items) do
            SetMediaItemInfo_Value(item, "B_MUTE_ACTUAL", 0)
        end
    else
        for _, item in pairs(items) do
            local item_track = GetMediaItemTrack(item)
            DeleteTrackMediaItem(item_track, item)
        end
    end
    Main_OnCommand(40769, 0) -- unselect all items

    if folder_check() == 1 then -- run F7
        local group = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(group, 0)
    else -- run F8
        local sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(sync, 0)
    end

    Undo_EndBlock("Explode multi-channel audio", 0)
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
