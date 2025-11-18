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

local main, set_all_tracks_to_same_height, scroll_to_first_track

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    PreventUIRefresh(1)
    Main_OnCommand(40111, 0) -- zoom in vertical a little to avoid toggle behavior
    set_all_tracks_to_same_height()
    scroll_to_first_track()
    PreventUIRefresh(-1)
end

---------------------------------------------------------------------

function set_all_tracks_to_same_height()
    local numTracks = CountTracks(0)

    local first_track = GetTrack(0, 0)
    SetMediaTrackInfo_Value(first_track, "I_HEIGHTOVERRIDE", 100)

    for i = 1, numTracks - 1 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", 40)
    end


    -- Refresh UI
    TrackList_AdjustWindows(false)
    UpdateArrange()
end

---------------------------------------------------------------------

function scroll_to_first_track()
    local track1 = GetTrack(0, 0)
    if not track1 then return end

    -- Save current selected tracks to restore later
    local saved_sel = {}
    local count_sel = CountSelectedTracks(0)
    for i = 0, count_sel - 1 do
        saved_sel[i + 1] = GetSelectedTrack(0, i)
    end

    -- Select only Track 1
    Main_OnCommand(40297, 0) -- Unselect all tracks
    SetTrackSelected(track1, true)

    -- Scroll Track 1 into view (vertically)
    Main_OnCommand(40913, 0) -- "Track: Vertical scroll selected tracks into view"

    -- Restore previous selection
    Main_OnCommand(40297, 0) -- Unselect all tracks
    for _, tr in ipairs(saved_sel) do
        SetTrackSelected(tr, true)
    end
end

---------------------------------------------------------------------

main()
