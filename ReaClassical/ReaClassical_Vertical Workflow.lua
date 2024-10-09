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
local mixer, folder_check, create_source_groups
local media_razor_group, remove_track_groups, get_color_table
local remove_spacers, add_spacer, copy_track_names, get_path
local add_rcmaster, route_to_track, special_check, remove_connections
local create_single_mixer, route_tracks, create_track_table
local process_name, reset_spacers, sync, show_track_name_dialog
local save_track_settings, reset_track_settings, write_to_mixer
local check_mixer_order, rearrange_tracks, reset_mixer_order

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

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
    local rcmaster_exists
    local focus = NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    Main_OnCommand(focus, 0)
    remove_track_groups()
    local show = NamedCommandLookup("_SWS_FOLDSMALL")

    PreventUIRefresh(1)
    if num_of_tracks == 0 then
        local is_empty = true
        SetProjExtState(0, "ReaClassical", "Workflow", "")
        local boolean, num = GetUserInputs("Vertical Workflow", 1, "How many tracks per group?", 10)
        num = tonumber(num)
        local rcmaster
        if boolean == true and num > 1 then
            rcmaster = create_destination_group(num)
            rcmaster_exists = true
        elseif boolean == true and num < 2 then
            ShowMessageBox("You need 2 or more tracks to make a source group!", "Vertical Workflow", 0)
            return
        else
            return
        end
        if folder_check() == 1 then
            create_source_groups()
            local end_of_sources = num * 7
            create_single_mixer(num, end_of_sources)
            local table, rcmaster_index, tracks_per_group, _, mixer_table = create_track_table(is_empty)
            route_tracks(rcmaster, table, end_of_sources)
            media_razor_group()
            reset_spacers(end_of_sources, tracks_per_group, rcmaster_index)
            Main_OnCommand(40939, 0) -- select track 01
            solo()
            mixer()
            Main_OnCommand(show, 0) -- show children of destination
            SetProjExtState(0, "ReaClassical", "Workflow", "Vertical")
            local success = show_track_name_dialog(mixer_table)
            if success then
                local response = MB("Would you like to automatically assign recording inputs based on track naming?",
                    "Vertical Workflow", 4)
                if response == 6 then
                    local auto_set = NamedCommandLookup("_RS4e19e645166b5e512fa7b405aaa8ac97ca6843b4")
                    Main_OnCommand(auto_set, 0)
                end
            end
            copy_track_names(table, mixer_table)
        end
    elseif folder_check() > 1 then
        local is_empty = false
        rcmaster_exists = special_check()

        if not rcmaster_exists then
            add_rcmaster(num_of_tracks)
        end

        local table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks, groups_equal = create_track_table(
            is_empty)
        if not groups_equal then
            ShowMessageBox("Please ensure that all folders have the same number of tracks before running.",
                "Vertical Workflow", 0)
            return
        end
        local rcmaster = GetTrack(0, rcmaster_index)
        local end_of_sources = tracks_per_group * folder_count
        local track_names = copy_track_names(table, mixer_tracks)

        if #mixer_tracks == 0 then
            -- build table of track settings, sends & FX for dest folder
            local controls, sends = save_track_settings(tracks_per_group)
            -- reset track settings for all dest/source folders
            reset_track_settings(end_of_sources)
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            -- write settings to mixer tracks
            write_to_mixer(end_of_sources, tracks_per_group, controls, sends)
        end

        if #mixer_tracks ~= tracks_per_group then
            for _, track in pairs(mixer_tracks) do
                DeleteTrack(track)
            end
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, _, _ = create_track_table(is_empty)
        end

        local success, is_sequential, current_order = check_mixer_order(mixer_tracks)
        if not success then
            local response = ShowMessageBox(
            "You’re using a version of ReaClassical that supports track rearrangement through the mixer panel.\
            \nAre you ready to upgrade the project to enable this feature? Press Cancel if you’ve recently dragged\
            a mixer track as you will need to reset its position before proceeding.", "Vertical Workflow",
                1)
            if response == 1 then
                reset_mixer_order(mixer_tracks)
                create_track_table(true)
            end
        elseif not is_sequential then
            rearrange_tracks(table, current_order)
            reset_mixer_order(mixer_tracks)
        end

        route_tracks(rcmaster, table, end_of_sources)
        media_razor_group()
        reset_spacers(end_of_sources, tracks_per_group, rcmaster_index)
        sync(tracks_per_group, end_of_sources)
        mixer()
        SetProjExtState(0, "ReaClassical", "Workflow", "Vertical")
    elseif folder_check() == 1 then
        local is_empty = true
        rcmaster_exists = special_check()

        if not rcmaster_exists then
            add_rcmaster(num_of_tracks)
        end

        create_source_groups()
        local table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks = create_track_table(is_empty)
        local end_of_sources = tracks_per_group * folder_count
        local track_names = copy_track_names(table, mixer_tracks)

        if #mixer_tracks == 0 then
            -- build table of track settings, sends & FX for dest folder
            local controls, sends = save_track_settings(tracks_per_group)
            -- reset track settings for all dest/source folders
            reset_track_settings(end_of_sources)
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            -- write settings to mixer tracks
            write_to_mixer(end_of_sources, tracks_per_group, controls, sends)
        end

        if #mixer_tracks ~= tracks_per_group then
            for _, track in pairs(mixer_tracks) do
                DeleteTrack(track)
            end
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, _, _ = create_track_table(is_empty)
        end

        local success, is_sequential, current_order = check_mixer_order(mixer_tracks)
        if not success then
            local response = ShowMessageBox(
           "You’re using a version of ReaClassical that supports track rearrangement through the mixer panel.\
            \nAre you ready to upgrade the project to enable this feature? Press Cancel if you’ve recently dragged\
            a mixer track as you will need to reset its position before proceeding.", "Vertical Workflow",
                1)
            if response == 1 then
                reset_mixer_order(mixer_tracks)
                create_track_table(true)
            end
        elseif not is_sequential then
            rearrange_tracks(table, current_order)
            reset_mixer_order(mixer_tracks)
        end

        local rcmaster = GetTrack(0, rcmaster_index)
        route_tracks(rcmaster, table, end_of_sources)
        media_razor_group()
        reset_spacers(end_of_sources, tracks_per_group, rcmaster_index)
        sync(tracks_per_group, end_of_sources)
        Main_OnCommand(40939, 0) -- select track 01
        solo()
        mixer()
        Main_OnCommand(show, 0) -- show children of destination
        SetProjExtState(0, "ReaClassical", "Workflow", "Vertical")
    else
        ShowMessageBox(
            "In order to use this function either:\n1. Run on an empty project\n2. Run with one existing folder\n3. Run on multiple existing folders to sync routing/fx",
            "Vertical Workflow", 0)
        return
    end

    PreventUIRefresh(-1)

    if num_pre_selected > 0 then
        Main_OnCommand(40297, 0) --unselect_all
        for _, track in ipairs(pre_selected) do
            if pcall(IsTrackSelected, track) then SetTrackSelected(track, 1) end
        end
    end

    if not rcmaster_exists then
        ShowMessageBox("Your Project has been upgraded"
            .. " to use a single mixer set routed to RCMASTER bus. "
            .. "You can now move the parent fader without affecting the volume of child tracks.\n"
            .. "All groups are routed to the single mixer set visible in the mixer panel "
            .. "and all volume, panning, fx etc should be controlled there.\n"
            .. "If you delete any of these special busses by accident, simply run F8 again."
            , "Vertical Workflow", 0)
    end

    Undo_EndBlock('Vertical Workflow', 0)
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
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)

        if (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone") or trackname_check(track, "^REF")) then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end


        if IsTrackSelected(track) == true then
            SetMediaTrackInfo_Value(track, "I_SOLO", 2)
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        elseif not (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone") or trackname_check(track, "^REF") or trackname_check(track, "^RCMASTER")) and IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        elseif not (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone") or trackname_check(track, "^REF") or trackname_check(track, "^RCMASTER")) then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end

        local muted = GetMediaTrackInfo_Value(track, "B_MUTE")

        if (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER")) and muted == 0 then
            local receives = GetTrackNumSends(track, -1)
            for i = 0, receives - 1, 1 do -- loop through receives
                local origin = GetTrackSendInfo_Value(track, -1, i, "P_SRCTRACK")
                if origin == selected_track or parent == 1 then
                    SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                    SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                    break
                end
            end
        end

        if trackname_check(track, "^RoomTone") and muted == 0 then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 1)
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
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local mastering = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[6] then mastering = tonumber(table[6]) end
    end

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
        if trackname_check(track, "^#") then
            SetTrackColor(track, colors.submix)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^RoomTone") then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "^REF") then
            SetTrackColor(track, colors.ref)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "RCMASTER") then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end

        if trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER") or trackname_check(track, "^RoomTone") or trackname_check(track, "^REF") then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end

        if trackname_check(track, "^S%d+:") then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 0 or 1)
        end
        if trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER") then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 1 or 0)
        end
        if mastering == 1 and i == 0 then
            Main_OnCommand(40727, 0) -- minimize all tracks
            SetTrackSelected(track, 1)
            Main_OnCommand(40723, 0) -- expand and minimize others
            SetTrackSelected(track, 0)
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
        for _ = 1, num_of_folders, 1 do
            local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
            Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
            Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
            local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
            Main_OnCommand(next_folder, 0)     -- select next folder
        end
    else
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS_SELCHILDREN2
        Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
    end
    Main_OnCommand(40297, 0)               -- Track: Unselect (clear selection of) all tracks
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

    for _, track in ipairs(mixer_table) do
        local mod_name = process_name(track)
        table.insert(track_names, mod_name)
    end

    local parent = track_table[1].parent
    GetSetMediaTrackInfo_String(parent, "P_NAME", "D:" .. track_names[1], 1)

    for i = 1, #track_table[1].tracks do
        local track = track_table[1].tracks[i]
        GetSetMediaTrackInfo_String(track, "P_NAME", "D:" .. (track_names[i + 1] or ""), 1)
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
    GetSetMediaTrackInfo_String(rcmaster, "P_EXT:rcmaster", "y", 1)
    GetSetMediaTrackInfo_String(rcmaster, "P_NAME", "RCMASTER", 1)
    -- SetMediaTrackInfo_Value(rcmaster, "I_SPACER", 1)
    local colors = get_color_table()
    SetTrackColor(rcmaster, colors.rcmaster)
    SetMediaTrackInfo_Value(rcmaster, "B_SHOWINTCP", 0)

    return rcmaster
end

---------------------------------------------------------------------

function route_to_track(track, destination)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
    if not name:match("^RCMASTER") then
        SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
        CreateTrackSend(track, destination)
    end
end

---------------------------------------------------------------------

function special_check()
    local rcmaster_exists = false
    local num_of_tracks = CountTracks(0)
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if name:match("^RCMASTER") then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "y", 1)
            rcmaster_exists = true
            break
        end
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", 0)
        if rcmaster_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_NAME", "RCMASTER", 1)
            rcmaster_exists = true
            break
        end
    end

    return rcmaster_exists
end

---------------------------------------------------------------------

function remove_connections(track)
    SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
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
        GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", 1)
        GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", j, 1)
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
        if name:sub(-1) ~= '-' then
            if name:match("^@") or name:match("^#") or name:match("^RoomTone") or name:match("^M:") then
                route_to_track(track, rcmaster)
            end
        end
    end

    --rcmaster to master
    SetMediaTrackInfo_Value(rcmaster, "B_MAINSEND", 1)

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

function create_track_table(is_empty)
    local track_table = {}
    local num_of_tracks = CountTracks(0)
    local rcmaster_index
    local j = 0
    local k = 1
    local prev_k = 1
    local groups_equal = true
    local mixer_tracks = {}
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", 0)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", 0)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", 0)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", 0)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", 0)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", 0)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if parent == 1 then
            if j > 1 and k ~= prev_k then
                groups_equal = false
            end
            j = j + 1
            prev_k = k
            k = 1
            track_table[j] = { parent = track, tracks = {} }
            if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", k, 1) end
        elseif trackname_check(track, "^M:") or mixer_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", 1)
            local mod_name = string.match(name, "M?:?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. mod_name, 1)
            table.insert(mixer_tracks, track)
        elseif trackname_check(track, "^@") or aux_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:aux", "y", 1)
            local mod_name = string.match(name, "@?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "@" .. mod_name, 1)
        elseif trackname_check(track, "^#") or submix_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:submix", "y", 1)
            local mod_name = string.match(name, "#?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "#" .. mod_name, 1)
        elseif trackname_check(track, "^RoomTone") or rt_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "y", 1)
            GetSetMediaTrackInfo_String(track, "P_NAME", "RoomTone", 1)
        elseif trackname_check(track, "^REF") or ref_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "y", 1)
            GetSetMediaTrackInfo_String(track, "P_NAME", "REF", 1)
        elseif trackname_check(track, "^RCMASTER") or rcmaster_state == "y" then
            rcmaster_index = i
        else
            if j > 0 then
                table.insert(track_table[j].tracks, track)
                if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", k + 1, 1) end
            else
                groups_equal = false
            end
            k = k + 1
        end
    end
    -- extra test for final group without further parent logic
    if j > 1 and k ~= prev_k then
        groups_equal = false
    end

    return track_table, rcmaster_index, k, j, mixer_tracks, groups_equal
end

---------------------------------------------------------------------

function process_name(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
    local mod_name = name:match("^%s*M?:?%s*(.-)%s*%-?$")
    if mod_name == nil then mod_name = name end
    return mod_name
end

---------------------------------------------------------------------

function reset_spacers(end_of_sources, tracks_per_group, rcmaster_index)
    remove_spacers(rcmaster_index)
    add_spacer(tracks_per_group)
    -- add_spacer(end_of_sources + tracks_per_group)
    -- add_spacer(rcmaster_index)
    -- add_spacer(rcmaster_index + 1)
end

---------------------------------------------------------------------

function save_track_settings(tracks_per_group)
    local controls = {}
    local sends = {}
    local parmnames = { "B_PHASE", "D_VOL", "D_PAN" }
    for i = 0, tracks_per_group - 1 do
        local track = GetTrack(0, i)

        --controls
        local values = {}
        for _, parmname in ipairs(parmnames) do
            local val = GetMediaTrackInfo_Value(track, parmname)
            values[parmname] = val
        end
        table.insert(controls, { track = track, values = values })

        -- sends
        local num_of_sends = GetTrackNumSends(track, 0)
        local track_sends = {}
        for j = 0, num_of_sends - 1 do
            local dest = GetTrackSendInfo_Value(track, 0, j, "P_DESTTRACK")
            local _, name = GetSetMediaTrackInfo_String(dest, "P_NAME", "", 0)
            if name == name:match("^@") or name == name:match("^#") then
                table.insert(track_sends, dest)
            end
        end

        table.insert(sends, track_sends)
    end

    return controls, sends
end

---------------------------------------------------------------------

function reset_track_settings(end_of_sources)
    for i = 0, end_of_sources - 1, 1 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        SetMediaTrackInfo_Value(track, "B_PHASE", 0)
        SetMediaTrackInfo_Value(track, "D_VOL", 1)
        SetMediaTrackInfo_Value(track, "D_PAN", 0)

        local num_of_sends = GetTrackNumSends(track, 0)
        for j = 0, num_of_sends - 1 do
            RemoveTrackSend(track, 0, j)
        end
    end
end

---------------------------------------------------------------------

function write_to_mixer(end_of_sources, tracks_per_group, controls, sends)
    local end_of_mixers = end_of_sources + tracks_per_group - 1
    local j = 1
    local k = 1

    for i = end_of_sources, end_of_mixers do
        local track = GetTrack(0, i)

        --controls
        SetMediaTrackInfo_Value(track, "B_PHASE", controls[j].values["B_PHASE"])
        SetMediaTrackInfo_Value(track, "D_VOL", controls[j].values["D_VOL"])
        SetMediaTrackInfo_Value(track, "D_PAN", controls[j].values["D_PAN"])
        j = j + 1

        -- sends
        for _, dest_track in ipairs(sends[k]) do
            CreateTrackSend(track, dest_track)
        end
        k = k + 1
    end

    -- move fx from first group to mixer tracks
    for i = 0, tracks_per_group - 1 do
        local src_track = GetTrack(0, i)
        local dest_index = end_of_sources + i
        local dest_track = GetTrack(0, dest_index)
        local num_of_fx = TrackFX_GetCount(src_track)
        for j = 0, num_of_fx - 1 do
            TrackFX_CopyToTrack(src_track, 0, dest_track, j, true)
        end
    end

    -- delele from all sources
    for i = 0, end_of_sources - 1 do
        local src_track = GetTrack(0, i)
        local num_of_fx = TrackFX_GetCount(src_track)
        for j = 0, num_of_fx - 1 do
            TrackFX_Delete(src_track, 0)
        end
    end
end

---------------------------------------------------------------------

function sync(tracks_per_group, end_of_sources)
    local rec_inputs = {}
    local locks = {}

    -- get inputs and locks
    for i = 0, tracks_per_group - 1 do
        local track = GetTrack(0, i)

        -- inputs
        local track_rec_input = GetMediaTrackInfo_Value(track, "I_RECINPUT")
        rec_inputs[i + 1] = track_rec_input

        -- lock state
        local _, locked = GetTrackStateChunk(track, "", 0)
        local is_locked = string.match(locked, "%s*LOCK%s+1")
        locks[i + 1] = is_locked
    end

    -- set inputs and locks
    local j = 1
    for i = 0, end_of_sources - 1 do
        local track = GetTrack(0, i)
        j = j % tracks_per_group
        if j == 0 then j = tracks_per_group end
        SetMediaTrackInfo_Value(track, "I_RECINPUT", rec_inputs[j])
        local _, locked = GetTrackStateChunk(track, "", 0)
        local str
        if locks[j] then
            str = locked:gsub("<TRACK", "<TRACK\nLOCK 1")
        else
            str = locked:gsub("\nLOCK 1", "")
        end
        SetTrackStateChunk(track, str, 0)
        j = j + 1
    end
end

---------------------------------------------------------------------

function show_track_name_dialog(mixer_track_table)
    local max_inputs_per_dialog = 8
    local success = true
    local track_names = {}

    -- Loop to handle all tracks in chunks
    for start_track = 1, #mixer_track_table, max_inputs_per_dialog do
        local end_track = math.min(start_track + max_inputs_per_dialog - 1, #mixer_track_table)
        local input_string = ""

        for i = start_track, end_track do
            input_string = input_string .. "Track " .. i .. " :,"
        end

        local ret, input = GetUserInputs("Enter Track Names " .. start_track .. "-" .. end_track,
            end_track - start_track + 1,
            input_string .. ",extrawidth=100", "")
        if not ret then
            return false
        end

        local inputs_track_table = {}
        for input_value in string.gmatch(input, "[^,]+") do
            table.insert(inputs_track_table, input_value:match("^%s*(.-)%s*$"))
        end

        for i = 1, #inputs_track_table do
            track_names[start_track + i - 1] = inputs_track_table[i]
        end
    end

    for i, track in ipairs(mixer_track_table) do
        if track then
            local ret = GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. (track_names[i] or ""), true)
            if not ret then
                success = false
            end
        else
            success = false
        end
    end

    return success
end

---------------------------------------------------------------------

function check_mixer_order(mixer_table)
    local current_order = {}
    local is_sequential = true
    local success = true

    for i, mixer_track in ipairs(mixer_table) do
        local _, mix_order_str = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:mix_order", "", 0)
        local mix_order = tonumber(mix_order_str)
        if mix_order then
            table.insert(current_order, mix_order)
        else
            success = false
        end

        if mix_order ~= i then
            is_sequential = false
        end
    end

    return success, is_sequential, current_order
end

---------------------------------------------------------------------

function rearrange_tracks(track_table, current_order)
    for i, group in ipairs(track_table) do
        local parent_track = group.parent
        local items_to_move = {}

        items_to_move[parent_track] = {}
        local parent_item_count = GetTrackNumMediaItems(parent_track)
        for j = 0, parent_item_count - 1 do
            local item = GetTrackMediaItem(parent_track, j)
            local mix_order = 1
            items_to_move[mix_order] = items_to_move[mix_order] or {}
            table.insert(items_to_move[mix_order], item)
        end

        for _, child in ipairs(group.tracks) do
            local _, mix_order = GetSetMediaTrackInfo_String(child, "P_EXT:mix_order", "", 0)
            mix_order = tonumber(mix_order) or 1

            items_to_move[child] = {}
            local item_count = GetTrackNumMediaItems(child)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(child, j)
                items_to_move[mix_order] = items_to_move[mix_order] or {}
                table.insert(items_to_move[mix_order], item)
            end
        end

        local updated_group_tracks = {}
        local is_empty = false
        local updated_track_table = create_track_table(is_empty)

        for j, updated_group in ipairs(updated_track_table) do
            if j == i then
                local _, mix_order = GetSetMediaTrackInfo_String(updated_group.parent, "P_EXT:mix_order",
                    current_order[1], 1)
                table.insert(updated_group_tracks, { track = updated_group.parent, order = tonumber(mix_order) or 1 })
                for k, child in ipairs(updated_group.tracks) do
                    local _, mix_order = GetSetMediaTrackInfo_String(child, "P_EXT:mix_order", current_order[k + 1], 1)
                    table.insert(updated_group_tracks, { track = child, order = tonumber(mix_order) or 1 })
                end
                break
            end
        end

        for _, revised_track_info in ipairs(updated_group_tracks) do
            local revised_mix_order = revised_track_info.order
            local items = items_to_move[revised_mix_order] or {}
            for _, item in ipairs(items) do
                MoveMediaItemToTrack(item, revised_track_info.track)
            end
        end
        for i, track_info in ipairs(updated_group_tracks) do
            GetSetMediaTrackInfo_String(track_info.track, "P_EXT:mix_order", tostring(i), 1)
        end
    end
end

---------------------------------------------------------------------

function reset_mixer_order(mixer_table)
    for i, mixer_track in ipairs(mixer_table) do
        GetSetMediaTrackInfo_String(mixer_track, "P_EXT:mix_order", i, 1)
    end
end

---------------------------------------------------------------------

main()
