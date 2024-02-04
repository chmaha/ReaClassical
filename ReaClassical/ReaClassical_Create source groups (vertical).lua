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
    PreventUIRefresh(1)
    Undo_BeginBlock()

    if CountTracks(0) == 0 then
        boolean, num = GetUserInputs("Create Destination & Source Groups", 1, "How many tracks per group?", 10)
        num = tonumber(num)
        if boolean == true and num > 1 then
            create_destination_group()
        elseif boolean == true and num < 2 then
            ShowMessageBox("You need 2 or more tracks to make a source group!", "Create Source Groups", 0)
        end
        if folder_check() == 1 then
            create_source_groups()
        end
    elseif folder_check() > 1 then
        sync_routing_and_fx()
    elseif folder_check() == 1 then
        create_source_groups()
    else
        ShowMessageBox(
            "In order to use this script either:\n1. Run on an empty project\n2. Run with one existing folder\n3. Run on multiple existing folders to sync routing/fx",
            "Create Source Groups", 0)
    end
    Undo_EndBlock('Create Source Groups', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function create_destination_group()
    for i = 1, num, 1 do
        InsertTrackAtIndex(0, true)
    end
    for i = 0, num - 1, 1 do
        local track = GetTrack(0, i)
        SetTrackSelected(track, 1)
    end
    local make_folder = NamedCommandLookup("_SWS_MAKEFOLDER")
    Main_OnCommand(make_folder, 0) -- make folder from tracks
    for i = 0, num - 1, 1 do
        local track = GetTrack(0, i)
        SetTrackSelected(track, 0)
    end
end

---------------------------------------------------------------------

function solo()
    local track = GetSelectedTrack(0, 0)
    SetMediaTrackInfo_Value(track, "I_SOLO", 2)

    for i = 0, CountTracks(0) - 1, 1 do
        track = GetTrack(0, i)
        if IsTrackSelected(track) == false then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            i = i + 1
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
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if bus_check(track) then
            native_color = ColorToNative(76, 145, 101)
            SetTrackColor(track, native_color)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if rt_check(track) then
            native_color = ColorToNative(20, 120, 230)
            SetTrackColor(track, native_color)
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

function sync_routing_and_fx()
    local ans = ShowMessageBox(
        "This will (re)create track groups and sync your source group routing and fx \nto match that of the destination group. Continue?",
        "Sync Source & Destination", 4)

    if ans == 6 then
        remove_track_groups()
        local ret = link_controls()
        if not ret then return end
      

        local first_track = GetTrack(0, 0)
        SetOnlyTrackSelected(first_track)
        local collapse = NamedCommandLookup("_SWS_COLLAPSE")
        Main_OnCommand(collapse, 0) -- collapse folder

        for i = 1, folder_check() - 1, 1 do
            local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
            Main_OnCommand(select_children, 0)            --SWS_SELCHILDREN2
            local copy_folder_routing = NamedCommandLookup("_S&M_COPYSNDRCV2")
            Main_OnCommand(copy_folder_routing, 0)        -- copy folder track routinga
            Main_OnCommand(42579, 0)                      -- Track: Remove selected tracks from all track media/razor editing groups
            local copy = NamedCommandLookup("_S&M_COPYSNDRCV1") -- SWS/S&M: Copy selected tracks (with routing)
            Main_OnCommand(copy, 0)
            local paste = NamedCommandLookup("_SWS_AWPASTE")
            Main_OnCommand(paste, 0) -- SWS_AWPASTE
            Main_OnCommand(40421, 0) -- Item: Select all items in track
            local delete_items = NamedCommandLookup("_SWS_DELALLITEMS")
            Main_OnCommand(delete_items, 0)
            local paste_folder_routing = NamedCommandLookup("_S&M_PASTSNDRCV2")
            Main_OnCommand(paste_folder_routing, 0) -- paste folder track routing
            local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
            Main_OnCommand(unselect_children, 0) -- unselect children
            Main_OnCommand(40042, 0)          --move edit cursor to start
            local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
            Main_OnCommand(next_folder, 0)    --select next folder

            --Account for empty folders
            local length = GetProjectLength(0)
            local old_tr = GetSelectedTrack(0, 0)
            local new_item = AddMediaItemToTrack(old_tr)
            SetMediaItemPosition(new_item, length + 1, false)

            select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
            Main_OnCommand(select_children, 0) --SWS_SELCHILDREN2
            Main_OnCommand(40421, 0)     --select all items on track

            local selected_tracks = CountSelectedTracks(0)
            for i = 1, selected_tracks, 1 do
                Main_OnCommand(40117, 0) -- Move items up to previous folder
            end
            Main_OnCommand(40005, 0) --delete selected tracks
            local select_only = NamedCommandLookup("_SWS_SELTRKWITEM")
            Main_OnCommand(select_only, 0) --SWS: Select only track(s) with selected item(s)
            local dup_tr = GetSelectedTrack(0, 0)
            local tr_items = CountTrackMediaItems(dup_tr)
            local last_item = GetTrackMediaItem(dup_tr, tr_items - 1)
            DeleteTrackMediaItem(dup_tr, last_item)
            Main_OnCommand(40289, 0) -- Unselect all items
        end
        media_razor_group()
        local first_track = GetTrack(0, 0)
        SetOnlyTrackSelected(first_track)
        solo()
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        mixer()
        local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
        Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
    end
end

---------------------------------------------------------------------

function create_source_groups()
    remove_track_groups()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    i = 0
    while i < 6 do
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0)              -- SWS: Select children of selected folder track(s)
        Main_OnCommand(42579, 0)                        -- Track: Remove selected tracks from all track media/razor editing groups
        local copy = NamedCommandLookup("_S&M_COPYSNDRCV1") -- SWS/S&M: Copy selected tracks (with routing)
        Main_OnCommand(copy, 0)
        local paste = NamedCommandLookup("_SWS_AWPASTE")
        Main_OnCommand(paste, 0) -- SWS_AWPASTE
        Main_OnCommand(40421, 0) -- Item: Select all items in track
        local delete_items = NamedCommandLookup("_SWS_DELALLITEMS")
        Main_OnCommand(delete_items, 0)
        i = i + 1
    end
    link_controls()
    media_razor_group()
end

function media_razor_group()
    local select_all_folders = NamedCommandLookup("_SWS_SELALLPARENTS")
    Main_OnCommand(select_all_folders, 0) -- select all folders
    local num_of_folders = CountSelectedTracks(0)
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    if num_of_folders > 1 then
        for i = 1, num_of_folders, 1 do
            local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
            Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
            Main_OnCommand(42578, 0)     -- Track: Create new track media/razor editing group from selected tracks
            local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
            Main_OnCommand(next_folder, 0) -- select next folder
        end
    else
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
        Main_OnCommand(42578, 0)       -- Track: Create new track media/razor editing group from selected tracks
    end
    Main_OnCommand(40296, 0)           -- Track: Select all tracks
    local collapse = NamedCommandLookup("_SWS_COLLAPSE")
    Main_OnCommand(collapse, 0)        -- collapse folder
    Main_OnCommand(40297, 0)           -- Track: Unselect (clear selection of) all tracks
    Main_OnCommand(40939, 0)           -- Track: Select track 01
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)

    solo()
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    mixer()
    local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
    Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)

    Main_OnCommand(40297, 0)           -- Track: Unselect (clear selection of) all tracks
    Main_OnCommand(40939, 0)           -- select track 01
end

---------------------------------------------------------------------

function remove_track_groups()
    Main_OnCommand(40296, 0) -- select all tracks
    local remove_grouping = NamedCommandLookup("_S&M_REMOVE_TR_GRP")
    Main_OnCommand(remove_grouping, 0)
    Main_OnCommand(40297, 0) -- unselect all tracks
end

---------------------------------------------------------------------

function link_controls()
    local select_all_folders = NamedCommandLookup("_SWS_SELALLPARENTS")
    Main_OnCommand(select_all_folders, 0) -- select all folders
    local num_of_folders = CountSelectedTracks(0)
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    local folder_tracks = CountSelectedTracks(0)
    local i = 0
    while i < num_of_folders do
        local j = 0
        while j < folder_tracks do
            local track = GetSelectedTrack(0, j)
            if not bus_check(track) then
                GetSetTrackGroupMembership(track, "VOLUME_LEAD", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "VOLUME_FOLLOW", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "PAN_LEAD", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "PAN_FOLLOW", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "POLARITY_LEAD", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "POLARITY_FOLLOW", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "AUTOMODE_LEAD", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "AUTOMODE_FOLLOW", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "MUTE_LEAD", 2 ^ j, 2 ^ j)
                GetSetTrackGroupMembership(track, "MUTE_FOLLOW", 2 ^ j, 2 ^ j)
            end
            j = j + 1
        end
        local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
        Main_OnCommand(next_folder, 0) -- select next folder
        Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        local ret = folder_size_check(folder_tracks)
        if not ret then
            remove_track_groups()
            media_razor_group()
            ShowMessageBox("Error: The script can only be run on folders with identical track counts!",
                "Sync Routing, Grouping and FX", 0)
            return false
        end
        i = i + 1
    end
    return true
end

---------------------------------------------------------------------

function folder_size_check(folder_tracks)
    return CountSelectedTracks(0) == folder_tracks
end

---------------------------------------------------------------------

main()
