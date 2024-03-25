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

local main, create_destination_group, solo, trackname_check
local mixer, folder_check, groupings_mcp, create_source_groups
local media_razor_group, remove_track_groups, get_color_table
local remove_spacers, add_spacer, copy_track_names, get_path
local add_rcmaster, route_to_track, special_check, remove_connections
local create_single_mixer, route_tracks, create_track_table
local process_dest, reset_spacers

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()

    local num_pre_selected = CountSelectedTracks(0)
    local pre_selected = {}
    if num_pre_selected > 0 then
        for i = 0, num_pre_selected - 1, 1 do
            local track = GetSelectedTrack(0, i)
            table.insert(pre_selected, track)
        end
    end

    local num_of_tracks = CountTracks(0)
    local rcmaster_exists = false
    local focus = NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    Main_OnCommand(focus, 0)
    remove_track_groups()


    PreventUIRefresh(1)
    if num_of_tracks == 0 then
        local boolean, num = GetUserInputs("Create Destination & Source Groups", 1, "How many tracks per group?", 10)
        num = tonumber(num)
        local rcmaster
        if boolean == true and num > 1 then
            rcmaster = create_destination_group(num)
            rcmaster_exists = true
        elseif boolean == true and num < 2 then
            ShowMessageBox("You need 2 or more tracks to make a source group!", "Create Source Groups", 0)
        end
        if folder_check() == 1 then
            create_source_groups()
            create_single_mixer(num, num * 7, track_names)
            local table, rcmaster_index, tracks_per_group, _, mixer_table = create_track_table()
            copy_track_names(table, mixer_table)
            route_tracks(rcmaster, table, num)
            groupings_mcp()
            reset_spacers(num * 7, tracks_per_group, rcmaster_index)
        end
    elseif folder_check() > 1 then
        rcmaster_exists = special_check()

        if not rcmaster_exists then
            add_rcmaster(num_of_tracks)
        end

        local table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks = create_track_table()
        local rcmaster = GetTrack(0, rcmaster_index)
        local end_of_sources = tracks_per_group * folder_count
        local track_names = copy_track_names(table, mixer_tracks)

        if #mixer_tracks ~= tracks_per_group then
            for _, track in pairs(mixer_tracks) do
                DeleteTrack(track)
            end
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks = create_track_table()
        end

        route_tracks(rcmaster, table, end_of_sources)
        groupings_mcp()
        reset_spacers(end_of_sources, tracks_per_group, rcmaster_index)
    elseif folder_check() == 1 then
        rcmaster_exists = special_check()

        if not rcmaster_exists then
            add_rcmaster(num_of_tracks)
        end

        create_source_groups()
        local table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks = create_track_table()
        local end_of_sources = tracks_per_group * folder_count
        local track_names = copy_track_names(table, mixer_tracks)

        if #mixer_tracks ~= tracks_per_group then
            for _, track in pairs(mixer_tracks) do
                DeleteTrack(track)
            end
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks = create_track_table()
        end
        local rcmaster = GetTrack(0, rcmaster_index)
        route_tracks(rcmaster, table, end_of_sources)
        groupings_mcp()
        reset_spacers(end_of_sources, tracks_per_group, rcmaster_index)
    else
        ShowMessageBox(
            "In order to use this script either:\n1. Run on an empty project\n2. Run with one existing folder\n3. Run on multiple existing folders to sync routing/fx",
            "Create Source Groups", 0)
    end

    PreventUIRefresh(-1)

    if num_pre_selected > 0 then
        Main_OnCommand(40297, 0) --unselect_all
        for _, track in ipairs(pre_selected) do
            SetTrackSelected(track, 1)
        end
    end

    if not rcmaster_exists then
        ShowMessageBox("Your Project has been upgraded"
            .. " to use a single mixer set routed to RCMASTER bus. "
            .. "You can now move the parent fader without affecting the volume of child tracks.\n"
            .. "All groups are routed to the single mixer set visible in the mixer panel "
            .. "and all volume, panning, fx etc should be controlled there.\n"
            .. "If you delete any of these special busses by accident, simply run F8 again."
            , "Sync Vertical Workflow", 0)
    end

    Undo_EndBlock('Create Source Groups', 0)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function create_destination_group(num)
    for _ = 1, num, 1 do
        InsertTrackAtIndex(0, true)
    end

    local rcmaster = add_rcmaster(num)

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

    return rcmaster
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

function groupings_mcp()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local tracks_per_group = media_razor_group()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    solo()
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0)   -- SWS: Select children of selected folder track(s)
    local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
    Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
end

---------------------------------------------------------------------

function create_source_groups()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local collapse = NamedCommandLookup("_SWS_COLLAPSE")
    Main_OnCommand(collapse, 0)        -- collapse folder
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    local tracks_per_folder = CountSelectedTracks(0)

    for _ = 1, 6, 1 do
        Main_OnCommand(40297, 0)
        for _ = 1, tracks_per_folder, 1 do
            InsertTrackAtIndex(tracks_per_folder, true)
        end
        for i = tracks_per_folder, tracks_per_folder * 2 - 1, 1 do
            local track = GetTrack(0, i)
            SetTrackSelected(track, 1)
        end
        local make_folder = NamedCommandLookup("_SWS_MAKEFOLDER")
        Main_OnCommand(make_folder, 0) -- make folder from tracks
        local collapse = NamedCommandLookup("_SWS_COLLAPSE")
        Main_OnCommand(collapse, 0)    -- collapse folder
    end
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
            Main_OnCommand(42578, 0)           -- Track: Create rcmaster_exists track media/razor editing group from selected tracks
            local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
            Main_OnCommand(next_folder, 0)     -- select next folder
        end
    else
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
        Main_OnCommand(42578, 0)           -- Track: Create rcmaster_exists track media/razor editing group from selected tracks
    end
    Main_OnCommand(40296, 0)               -- Track: Select all tracks
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

    Main_OnCommand(40297, 0)             -- Track: Unselect (clear selection of) all tracks
    Main_OnCommand(40939, 0)             -- select track 01
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

function add_spacer(num)
    local track = GetTrack(0, num)
    if track then
        SetMediaTrackInfo_Value(track, "I_SPACER", 1)
    end
end

---------------------------------------------------------------------

function remove_spacers(num_of_tracks)
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_SPACER", 0)
    end
end

---------------------------------------------------------------------

function copy_track_names(track_table, mixer_table)
    local track_names = {}

    -- for 1st prefix D: (remove anything existing before & including :)
    local parent = track_table[1].parent
    local mod_name = process_dest(parent)
    table.insert(track_names, mod_name)

    for _, track in ipairs(track_table[1].tracks) do
        local mod_name = process_dest(track)
        table.insert(track_names, mod_name)
    end

    -- for rest, prefix Si: where i = number starting at 1
    for i = 2, #track_table, 1 do
        local parent = track_table[i].parent
        local mod_name = track_names[1]
        GetSetMediaTrackInfo_String(parent, "P_NAME", "S" .. i - 1 .. ":" .. mod_name, 1)

        local num_of_names = #track_names
        local j = 1
        for _, track in ipairs(track_table[i].tracks) do
            local track_index = j % num_of_names + 1
            if track_index == 1 then track_index = 2 end
            local mod_name = track_names[track_index]
            GetSetMediaTrackInfo_String(track, "P_NAME", "S" .. (i - 1) .. ":" .. mod_name, 1)
            j = j + 1
        end
    end

    local i = 1
    for _, track in ipairs(mixer_table) do
        if track_names[i] ~= nil then
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. track_names[i], 1)
        else
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:", 1)
        end
        i = i + 1
    end

    return track_names
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

function route_to_track(track, destination)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
    if name ~= "RCMASTER" then
        SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
        CreateTrackSend(track, destination)
    end
end

---------------------------------------------------------------------

function special_check()
    local bool = false
    local num_of_tracks = CountTracks(0)
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if name == "RCMASTER" then
            bool = true
            break
        end
    end

    return bool
end

---------------------------------------------------------------------

function remove_connections(track)
    local num_of_receives = GetTrackNumSends(track, -1)
    for i = 0, num_of_receives - 1, 1 do
        RemoveTrackSend(track, -1, 0)
    end
end

---------------------------------------------------------------------

function create_single_mixer(tracks_per_group, end_of_sources, track_names)
    for _ = 1, tracks_per_group, 1 do
        InsertTrackAtIndex(end_of_sources, true)
    end
    local j = 1
    for i = end_of_sources, end_of_sources + tracks_per_group - 1, 1 do
        local track = GetTrack(0, i)
        if track_names then
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. track_names[j], 1)
        else
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:", 1)
        end
        j = j + 1
    end
end

---------------------------------------------------------------------

function route_tracks(rcmaster, track_table, end_of_sources)
    local num_of_tracks = CountTracks(0)
    local first_mixer = GetTrack(0, end_of_sources)

    -- delete existing mixer receives
    remove_connections(rcmaster)
    for i = end_of_sources, end_of_sources + #track_table[1].tracks, 1 do
        local mixer_track = GetTrack(0, i)
        remove_connections(mixer_track)
    end
    --routing to rcmaster
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if name:match("^@") or name:match("^RoomTone") or name:match("^M:") then
            route_to_track(track, rcmaster)
        end
    end

    -- parents to first mixer track
    for _, entry in ipairs(track_table) do
        local parent = entry.parent
        route_to_track(parent, first_mixer)
    end
    -- children to corresponding mixer tracks
    for i = 1, #track_table, 1 do
        local j = 1
        for _, track in ipairs(track_table[i].tracks) do
            local track_index = end_of_sources + j
            local mixer_track = GetTrack(0, track_index)
            route_to_track(track, mixer_track)
            j = j + 1
        end
    end
end

---------------------------------------------------------------------

function create_track_table()
    local track_table = {}
    local num_of_tracks = CountTracks(0)
    local rcmaster_index
    local j = 0
    local k = 1
    local mixer_tracks = {}
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if parent == 1 then
            j = j + 1
            k = 1
            track_table[j] = { parent = track, tracks = {} }
        elseif trackname_check(track, "^M:") then
            table.insert(mixer_tracks, track)
        elseif trackname_check(track, "^RCMASTER") then
            rcmaster_index = i
        elseif not (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^RoomTone")) then
            table.insert(track_table[j].tracks, track)
            k = k + 1
        end
    end

    return track_table, rcmaster_index, k, j, mixer_tracks
end

---------------------------------------------------------------------

function process_dest(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
    local mod_name = string.match(name, ":(.*)")
    if mod_name == nil then mod_name = name end
    GetSetMediaTrackInfo_String(track, "P_NAME", "D:" .. mod_name, 1)
    return mod_name
end

---------------------------------------------------------------------

function reset_spacers(end_of_sources, tracks_per_group, rcmaster_index)
    remove_spacers(end_of_sources)
    add_spacer(tracks_per_group)
    add_spacer(end_of_sources + tracks_per_group)
    add_spacer(rcmaster_index)
end

---------------------------------------------------------------------

main()
