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

local main, track_check

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0) 
    return
end

function main()
    local num_of_tracks = track_check()
    if num_of_tracks == 0 then
        ShowMessageBox("Please add at least one track or folder before running", "Duplicate folder (no items)", 0)
        return
    end
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local is_parent
    local count = 0
    local num_of_selected = CountSelectedTracks(0)
    for i = 0, num_of_selected - 1, 1 do
        local track = GetSelectedTrack(0,i)
        if track then
            is_parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if is_parent == 1 then
                count = count + 1
            end
        end
    end

    if count ~= 1 then
        ShowMessageBox("Please select one parent track before running", "Duplicate folder (no items)", 0)
        return
    end

    Main_OnCommand(40340, 0)
    Main_OnCommand(40062, 0)           -- Duplicate track
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
    Main_OnCommand(40421, 0)           -- Item: Select all items in track
    local delete_items = NamedCommandLookup("_SWS_DELALLITEMS")
    Main_OnCommand(delete_items, 0)
    local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
    Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
    local sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
    Main_OnCommand(sync,0)
    Undo_EndBlock('Duplicate folder (No items)', 0)
    PreventUIRefresh(-1)
    Main_OnCommand(40913, 0)             -- adjust scroll to selected tracks
    UpdateArrange()
    UpdateTimeline()
    TrackList_AdjustWindows(false)
end

---------------------------------------------------------------------

function track_check()
    return CountTracks(0)
end

---------------------------------------------------------------------

main()
