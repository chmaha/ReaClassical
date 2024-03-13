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

local main, create_destination_group, solo, bus_check, rt_check
local mixer, folder_check, sync_routing_and_fx, create_source_groups
local media_razor_group, remove_track_groups, link_controls, get_color_table
local folder_size_check, remove_spacers, add_spacer, create_prefixes, get_path

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()

    local num_of_tracks = CountTracks(0)
    
    if num_of_tracks == 0 then
        local boolean, num = GetUserInputs("Create Destination & Source Groups", 1, "How many tracks per group?", 10)
        num = tonumber(num)
        if boolean == true and num > 1 then
            create_destination_group(num)
        elseif boolean == true and num < 2 then
            ShowMessageBox("You need 2 or more tracks to make a source group!", "Create Source Groups", 0)
        end
        if folder_check() == 1 then
            create_source_groups(num_of_tracks)
            create_prefixes()
        end
    elseif folder_check() > 1 then
        sync_routing_and_fx(num_of_tracks)
        create_prefixes()
    elseif folder_check() == 1 then
        create_source_groups(num_of_tracks)
        create_prefixes()
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

function create_destination_group(num)
    for _ = 1, num, 1 do
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

function sync_routing_and_fx(num_of_tracks)
    local ans = ShowMessageBox(
        "This will (re)create track groups and sync your source group routing and fx \nto match that of the destination group. Continue?",
        "Sync Source & Destination", 4)

    if ans == 6 then
        remove_track_groups()
        local ret = link_controls()
        if not ret then return end

        remove_spacers(num_of_tracks)

        local first_track = GetTrack(0, 0)
        SetOnlyTrackSelected(first_track)
        local collapse = NamedCommandLookup("_SWS_COLLAPSE")
        Main_OnCommand(collapse, 0) -- collapse folder

        local num_of_folders = folder_check()
        for _ = 1, num_of_folders - 1, 1 do
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
            for _ = 1, selected_tracks, 1 do
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
        tracks_per_group = media_razor_group()
        add_spacer(tracks_per_group)
        add_spacer(num_of_folders*tracks_per_group)
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

function create_source_groups(num_of_tracks)
    remove_track_groups()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local i = 0
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
    tracks_per_group = media_razor_group()
    remove_spacers(num_of_tracks)
    add_spacer(tracks_per_group)
end

---------------------------------------------------------------------

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
    local tracks_per_group = CountSelectedTracks(0)
    mixer()
    local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
    Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)

    Main_OnCommand(40297, 0)           -- Track: Unselect (clear selection of) all tracks
    Main_OnCommand(40939, 0)           -- select track 01
    return tracks_per_group
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

function add_spacer(num)
    local track = GetTrack(0, num)
    if track then
        SetMediaTrackInfo_Value(track, "I_SPACER", 1)
    end
end

---------------------------------------------------------------------

function remove_spacers(num_of_tracks)
    for i = 0, num_of_tracks -1, 1 do
        local track = GetTrack(0,i)
        SetMediaTrackInfo_Value(track, "I_SPACER", 0)
    end
end

---------------------------------------------------------------------

function create_prefixes()
    -- get table of parent tracks by iterating through and checking status
    local table = {}
    local num_of_tracks = CountTracks(0)
    local j = 0
    local k = 1
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0,i)
        local parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if parent == 1 then
            j = j + 1
            k = 1
            table[j] = {}
            table[j]["parent"] = track
        else
            if not bus_check(track) and not rt_check(track) then
                table[j][k] = track
                k = k + 1
            end
        end
    end
    -- for 1st prefix D: (remove anything existing before & including :)
    for _,v in pairs(table[1]) do
        local _, name = GetSetMediaTrackInfo_String(v, "P_NAME", "", 0)
        local mod_name = string.match(name, ":(.*)")
        if mod_name == nil then mod_name = name end
        GetSetMediaTrackInfo_String(v, "P_NAME", "D:" .. mod_name, 1)
    end
    -- for rest, prefix Si: where i = number starting at 1
    for i = 2, #table, 1 do
        for _,v in pairs(table[i]) do
            local _, name = GetSetMediaTrackInfo_String(v, "P_NAME", "", 0)
            local mod_name = string.match(name, ":(.*)")
            if mod_name == nil then mod_name = name end
            GetSetMediaTrackInfo_String(v, "P_NAME", "S" .. i-1 .. ":" .. mod_name, 1)
        end
    end
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

main()
