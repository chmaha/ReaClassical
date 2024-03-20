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

local main, track_check, folder_check, remove_track_groups
local media_razor_group, add_rcmaster, get_color_table, get_path
local route_to_track, rcmaster_check, remove_rcmaster_connections

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local boolean, num
    if track_check() == 0 then
        boolean, num = GetUserInputs("Create Folder", 1, "How many tracks?", 10)
        num = tonumber(num)
        if boolean == true and num > 0 then
            for _ = 1, tonumber(num), 1 do
                InsertTrackAtIndex(0, true)
            end

            local rcmaster = add_rcmaster(num)

            for i = 0, tonumber(num) - 1, 1 do
                local track = GetTrack(0, i)
                SetTrackSelected(track, 1)
                route_to_track(track, rcmaster)
            end

            local folder = NamedCommandLookup("_SWS_MAKEFOLDER")
            Main_OnCommand(folder, 0)
            for i = 0, tonumber(num) - 1, 1 do
                local track = GetTrack(0, i)
                SetTrackSelected(track, 0)
            end
            media_razor_group()
        else
            ShowMessageBox("You can't have zero tracks in a folder!", "Create Folder", 0)
        end
    elseif folder_check() == 1 then
        local new, num_of_tracks, rcmaster = rcmaster_check()
        if not new then
            local rcmaster = add_rcmaster(num_of_tracks)
            for i = 0, num_of_tracks - 1, 1 do
                local track = GetTrack(0, i)
                route_to_track(track, rcmaster)
            end
        else
            remove_rcmaster_connections(rcmaster)
            for i = 0, num_of_tracks - 1, 1 do
                local track = GetTrack(0, i)
                route_to_track(track, rcmaster)
            end
        end
        remove_track_groups()
        media_razor_group()
        ShowMessageBox("Tracks re-grouped for media and razor editing", "Create Folder", 0)
    else
        ShowMessageBox(
            "This function can be used on an empty project to create a folder group\nor on a single folder to re-group for media/razor editing",
            "Create Folder", 0)
    end
    Undo_EndBlock("Create Folder", -1)
end

---------------------------------------------------------------------

function track_check()
    return CountTracks(0)
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

function remove_track_groups()
    Main_OnCommand(40296, 0) -- select all tracks
    local remove_grouping = NamedCommandLookup("_S&M_REMOVE_TR_GRP")
    Main_OnCommand(remove_grouping, 0)
    Main_OnCommand(40297, 0) -- unselect all tracks
end

---------------------------------------------------------------------

function media_razor_group()
    local select_all_folders = NamedCommandLookup("_SWS_SELALLPARENTS")
    Main_OnCommand(select_all_folders, 0) -- select all folders
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
    Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40939, 0)           -- Track: Select track 01
end

---------------------------------------------------------------------

function add_rcmaster(num)
    InsertTrackAtIndex(num, true) -- add RCMASTER
    local rcmaster = GetTrack(0, num)
    GetSetMediaTrackInfo_String(rcmaster, "P_NAME", "RCMASTER", 1)
    SetMediaTrackInfo_Value(rcmaster, "I_SPACER", 1)
    local colors = get_color_table()
    SetTrackColor(rcmaster, colors.rcmaster)
    SetMediaTrackInfo_Value(rcmaster, "B_SHOWINTCP", 0)

    return rcmaster
end

---------------------------------------------------------------------

function route_to_track(track, rcmaster)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
    if name ~= "RCMASTER" then
        SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
        CreateTrackSend(track, rcmaster)
    end
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

function rcmaster_check()
    local bool = false
    local track
    local num_of_tracks = CountTracks(0)
    for i = 0, num_of_tracks - 1, 1 do
        track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if name == "RCMASTER" then
            bool = true
            break
        end
    end

    return bool, num_of_tracks, track
end

---------------------------------------------------------------------

function remove_rcmaster_connections(rcmaster)
    local num_of_receives = GetTrackNumSends(rcmaster, -1)
    for i = 0, num_of_receives - 1, 1 do
        RemoveTrackSend(rcmaster, -1, 0)
    end
end

main()
