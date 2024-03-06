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

local main, solo, bus_check, rt_check, mixer, track_check
local media_razor_group, add_spacer, create_prefixes, get_color_table, get_path

---------------------------------------------------------------------

function main()
    if track_check() == 0 then
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
    Main_OnCommand(42670,0) -- Remove spacer (if present)
    Main_OnCommand(40421, 0)           -- Item: Select all items in track
    local delete_items = NamedCommandLookup("_SWS_DELALLITEMS")
    Main_OnCommand(delete_items, 0)
    local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
    Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
    solo()
    Main_OnCommand(select_children, 0)
    mixer()
    Main_OnCommand(unselect_children, 0)
    local tracks_per_group = media_razor_group(duplicated)
    add_spacer(tracks_per_group)
    create_prefixes()
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

function bus_check(track)
    _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, "^@")
end

---------------------------------------------------------------------

function rt_check(track)
    _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, "^RoomTone")
end

---------------------------------------------------------------------

function mixer()
    local colors = get_color_table()
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if bus_check(track) then
            SetTrackColor(track, colors.aux)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if rt_check(track) then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if IsTrackSelected(track) or bus_check(track) or rt_check(track) then
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

function add_spacer(num)
    local track = GetTrack(0, num)
    SetMediaTrackInfo_Value(track, "I_SPACER", 1)
end

---------------------------------------------------------------------

function create_prefixes()
    -- get table of parent tracks by iterating through and checking status
    local parents = {}
    local num_of_tracks = CountTracks(0)
    local j = 1
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0,i)
        local parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if parent == 1 then
            parents[j] = track
            j = j + 1
        end
    end

    -- for 1st prefix D: (removing anything existing before & including ":")
    local _, name = GetSetMediaTrackInfo_String(parents[1], "P_NAME", "", 0)
    local mod_name = string.match(name, ":(.*)")
    if mod_name == nil then mod_name = name end
    GetSetMediaTrackInfo_String(parents[1], "P_NAME", "D:" .. mod_name, 1)

    -- for rest, prefix "Si:" where i = number starting at 1
    for i = 2, #parents, 1 do
        local _, name = GetSetMediaTrackInfo_String(parents[i], "P_NAME", "", 0)
        local mod_name = string.match(name, ":(.*)")
        if mod_name == nil then mod_name = name end
        GetSetMediaTrackInfo_String(parents[i], "P_NAME", "S" .. i-1 .. ":" .. mod_name, 1)
    end
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical","")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1,1);
    local elements = {...}
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

main()
