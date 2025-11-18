--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local main, lock_items, unlock_items, find_second_folder_track

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local lock_toggle = NamedCommandLookup("_RS63db9a9d1dae64f15f6ca0b179bb5ea0bc4d06f6")
    local state = GetToggleCommandState(lock_toggle)
    SetCursorContext(1, nil)
    if state == 0 or state == -1 then
        SetToggleCommandState(1, lock_toggle, 1)
        Main_OnCommand(40311, 0) -- Set ripple editing all tracks
        lock_items()
    else
        SetToggleCommandState(1, lock_toggle, 0)
        unlock_items()
        Main_OnCommand(40310, 0) -- Set ripple editing per-track
    end

    Undo_EndBlock('Lock Toggle', 0)
    PreventUIRefresh(-1)
    UpdateTimeline()
end

---------------------------------------------------------------------

function lock_items()
    local second_folder_track = find_second_folder_track()

    if second_folder_track == nil then
        return
    end

    local total_tracks = CountTracks(0)

    for track_idx = second_folder_track, total_tracks - 1 do
        local track = GetTrack(0, track_idx)

        local num_items = CountTrackMediaItems(track)

        for item_idx = 0, num_items - 1 do
            local item = GetTrackMediaItem(track, item_idx)
            SetMediaItemInfo_Value(item, "C_LOCK", 1)
        end
    end
end

---------------------------------------------------------------------

function find_second_folder_track()
    local total_tracks = CountTracks(0)
    local folder_count = 0

    for track_idx = 0, total_tracks - 1 do
        local track = GetTrack(0, track_idx)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if folder_depth == 1 then
            folder_count = folder_count + 1

            if folder_count == 2 then
                return track_idx
            end
        end
    end

    return nil
end

---------------------------------------------------------------------

function unlock_items()
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 0)
    end
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    UpdateArrange()
end

---------------------------------------------------------------------

main()
