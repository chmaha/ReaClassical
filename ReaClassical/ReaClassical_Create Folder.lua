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
    Undo_BeginBlock()
    if track_check() == 0 then
        local boolean, num = GetUserInputs("Create Folder", 1, "How many tracks?", 10)
        num = tonumber(num)
        if boolean == true and num > 0 then
            for i = 1, tonumber(num), 1 do
                InsertTrackAtIndex(0, true)
            end
            for i = 0, tonumber(num) - 1, 1 do
                local track = GetTrack(0, i)
                SetTrackSelected(track, 1)
            end
            local folder = NamedCommandLookup("_SWS_MAKEFOLDER")
            Main_OnCommand(folder, 0)
            for i = 0, tonumber(num) - 1, 1 do
                local track = GetTrack(0, i)
                SetTrackSelected(track, 0)
            end
            media_razor_group()
            link_controls()
        else
            ShowMessageBox("You can't have zero tracks in a folder!", "Create Folder", 0)
        end
    elseif folder_check() == 1 then
        remove_track_groups()
        media_razor_group()
        link_controls()
        ShowMessageBox("Tracks re-linked and re-grouped for media and razor editing", "Create Folder", 0)
    else
        ShowMessageBox("This function can be used on an empty project to create a folder group\nor on a single folder to re-group for media/razor editing", "Create Folder", 0)
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
    local num_of_folders = CountSelectedTracks(0)
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
    Main_OnCommand(42578, 0)         -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40939, 0)         -- Track: Select track 01
end

---------------------------------------------------------------------

function link_controls()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    local folder_tracks = CountSelectedTracks(0)
    local i = 0
    while i < folder_tracks do
        local track = GetSelectedTrack(0, i)
        GetSetTrackGroupMembership(track, "VOLUME_LEAD", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "VOLUME_FOLLOW", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "PAN_LEAD", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "PAN_FOLLOW", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "POLARITY_LEAD", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "POLARITY_FOLLOW", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "AUTOMODE_LEAD", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "AUTOMODE_FOLLOW", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "MUTE_LEAD", 2 ^ i, 2 ^ i)
        GetSetTrackGroupMembership(track, "MUTE_FOLLOW", 2 ^ i, 2 ^ i)
        i = i + 1
    end
    SetOnlyTrackSelected(first_track)
end

---------------------------------------------------------------------

main()
