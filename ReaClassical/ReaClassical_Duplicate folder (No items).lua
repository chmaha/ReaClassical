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

local main, solo, trackname_check, mixer, track_check
local media_razor_group, get_color_table, get_path

---------------------------------------------------------------------

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
    local duplicated = GetSelectedTrack(0,0)
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2

    Main_OnCommand(40421, 0)           -- Item: Select all items in track
    local delete_items = NamedCommandLookup("_SWS_DELALLITEMS")
    Main_OnCommand(delete_items, 0)
    local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
    Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
    solo()
    Main_OnCommand(select_children, 0)
    mixer()
    Main_OnCommand(unselect_children, 0)
    media_razor_group(duplicated)
    local sync = NamedCommandLookup("_RSd7bf4eb95ac7700edb48a275153ad1fc1ce3aff6")
    Main_OnCommand(sync,0)
    Undo_EndBlock('Duplicate folder (No items)', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
    TrackList_AdjustWindows(false)
end

---------------------------------------------------------------------

function solo()
    local track = GetSelectedTrack(0, 0)
    SetMediaTrackInfo_Value(track, "I_SOLO", 2)
    for i = 0, CountTracks(0) - 1, 1 do
        track = GetTrack(0, i)
        if IsTrackSelected(track) == false then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function mixer()
    local colors = get_color_table()
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if trackname_check(track, "^M:") then
            SetTrackColor(track, colors.mixer)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^@") then
            SetTrackColor(track, colors.aux)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^RoomTone") then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "^RCMASTER") then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^RCMASTER") or trackname_check(track, "^RoomTone") then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end
    end
end

---------------------------------------------------------------------

function track_check()
    return CountTracks(0)
end

---------------------------------------------------------------------

function media_razor_group(track)
    Main_OnCommand(40296, 0)              -- Select all tracks
    Main_OnCommand(42579, 0)              -- Track: Remove selected tracks from all track media/razor editing groups
    local select_all_folders = NamedCommandLookup("_SWS_SELALLPARENTS")
    Main_OnCommand(select_all_folders, 0) -- select all folders
    local num_of_folders = CountSelectedTracks(0)
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local tracks_per_group
    for _ = 1, num_of_folders, 1 do
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
        tracks_per_group = CountSelectedTracks(0)
        Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
        local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
        Main_OnCommand(next_folder, 0)     -- select next folder
    end
    Main_OnCommand(40297, 0) -- unselect all tracks
    SetTrackSelected(track, true)
    return tracks_per_group
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical","")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1,1);
    local elements = {...}
    return table.concat(elements, pathseparator)
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
