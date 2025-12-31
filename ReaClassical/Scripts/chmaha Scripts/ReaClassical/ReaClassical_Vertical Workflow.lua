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

local main, create_destination_group, solo, trackname_check
local mixer, folder_check, create_source_groups
local media_razor_group, remove_track_groups, get_color_table
local remove_spacers, add_spacer, copy_track_names, get_path
local add_rcmaster, route_to_track, special_check, remove_connections
local create_single_mixer, route_tracks, create_track_table
local process_name, reset_spacers, sync, show_track_name_dialog
local save_track_settings, reset_track_settings, write_to_mixer
local check_mixer_order, rearrange_tracks, reset_mixer_order
local copy_track_names_from_dest, process_dest, move_items_to_first_source_group
local check_hidden_track_items, move_destination_folder_to_top
local get_whole_number_input, set_recording_to_primary_and_secondary
local reorder_special_tracks, select_children_of_selected_folders
local select_next_folder, collapse_folder, fold_small, make_folder
local select_all_parents

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    PreventUIRefresh(1)
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end
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
    SetCursorContext(1, nil)
    remove_track_groups()
    if num_of_tracks == 0 then
        local is_empty = true
        SetProjExtState(0, "ReaClassical", "RCProject", "y")
        local creation_date = os.date("%Y-%m-%d %H:%M:%S", os.time())
        SetProjExtState(0, "ReaClassical", "CreationDate", creation_date)
        SetProjExtState(0, "ReaClassical", "Workflow", "")
        local num = get_whole_number_input()
        if not num then return end
        local rcmaster
        if num >= 2 then
            rcmaster = create_destination_group(num)
            rcmaster_exists = true
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
            reset_spacers(tracks_per_group, rcmaster_index)
            Main_OnCommand(40939, 0) -- select track 01
            solo()
            mixer()
            fold_small()
            SetProjExtState(0, "ReaClassical", "Workflow", "Vertical")
            copy_track_names(table, mixer_table)
            local mission_control = NamedCommandLookup("_RScaa05755eb1dca4cec87c8ba9fe0ddf6570ce73c")
            Main_OnCommand(mission_control,0)
            set_recording_to_primary_and_secondary(end_of_sources)
        end
    elseif folder_check() > 1 then
        local _, RCProject = GetProjExtState(0, "ReaClassical", "RCProject")
        if RCProject ~= "y" then
            local _, _, _, _, mixer_tracks = create_track_table(is_empty)
            if #mixer_tracks == 0 then
                MB("This function can only run on a ReaClassical project. Create a new empty project and press F7.",
                    "Vertical Workflow", 0)
                return
            else
                SetProjExtState(0, "ReaClassical", "RCProject", "y")
            end
        end
        reorder_special_tracks()
        local is_empty = false
        rcmaster_exists = special_check()

        if not rcmaster_exists then
            add_rcmaster(num_of_tracks)
        end

        move_destination_folder_to_top()

        local table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks, groups_equal = create_track_table(
            is_empty)
        if not groups_equal then
            MB("Please ensure that all folders have the same number of tracks before running.",
                "Vertical Workflow", 0)
            return
        end
        local rcmaster = GetTrack(0, rcmaster_index)
        local end_of_sources = tracks_per_group * folder_count

        if #mixer_tracks ~= tracks_per_group then
            for _, track in pairs(mixer_tracks) do
                DeleteTrack(track)
            end
            table, _, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            local track_names = copy_track_names_from_dest(table, mixer_tracks)
            -- build table of track settings, sends & FX for dest folder
            local controls, sends = save_track_settings(tracks_per_group)
            -- reset track settings for all dest/source folders
            reset_track_settings(tracks_per_group)
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            -- write settings to mixer tracks
            write_to_mixer(end_of_sources, tracks_per_group, controls, sends)
        end

        copy_track_names(table, mixer_tracks)

        local success, is_sequential, current_order = check_mixer_order(mixer_tracks)
        if not success then
            local upgrade_response = MB(
                "You’re using a version of ReaClassical that supports track rearrangement through the mixer panel.\n" ..
                "Are you ready to upgrade the project to enable this feature? " ..
                "Press Cancel if you’ve recently dragged a mixer track " ..
                "as you will need to reset its position before proceeding.",
                "Vertical Workflow", 1)
            if upgrade_response == 1 then
                reset_mixer_order(mixer_tracks)
                create_track_table(true)
            end
        elseif not is_sequential then
            rearrange_tracks(table, current_order)
            reset_mixer_order(mixer_tracks)
        end
        route_tracks(rcmaster, table, end_of_sources)
        media_razor_group()
        reset_spacers(tracks_per_group, rcmaster_index)
        sync(tracks_per_group, end_of_sources)
        mixer()
        set_recording_to_primary_and_secondary(end_of_sources)
        SetProjExtState(0, "ReaClassical", "Workflow", "Vertical")
    elseif folder_check() == 1 then
        local _, RCProject = GetProjExtState(0, "ReaClassical", "RCProject")
        if RCProject ~= "y" then
            local _, _, _, _, mixer_tracks = create_track_table(is_empty)
            if #mixer_tracks == 0 then
                MB("This function can only run on a ReaClassical project. Create a new empty project and press F7.",
                    "Vertical Workflow", 0)
                return
            else
                SetProjExtState(0, "ReaClassical", "RCProject", "y")
            end
        end
        reorder_special_tracks()
        local is_empty = true
        rcmaster_exists = special_check()

        if not rcmaster_exists then
            add_rcmaster(num_of_tracks)
        end

        create_source_groups()
        local table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks = create_track_table(is_empty)
        local end_of_sources = tracks_per_group * folder_count

        if #mixer_tracks ~= tracks_per_group then
            for _, track in pairs(mixer_tracks) do
                DeleteTrack(track)
            end
            table, _, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            local track_names = copy_track_names_from_dest(table, mixer_tracks)
            -- build table of track settings, sends & FX for dest folder
            local controls, sends = save_track_settings(tracks_per_group)
            -- reset track settings for all dest/source folders
            reset_track_settings(tracks_per_group)
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            table, rcmaster_index, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            -- write settings to mixer tracks
            write_to_mixer(end_of_sources, tracks_per_group, controls, sends)
        end

        copy_track_names(table, mixer_tracks)

        local success, is_sequential, current_order = check_mixer_order(mixer_tracks)
        if not success then
            local upgrade_response = MB(
                "You’re using a version of ReaClassical that supports track rearrangement through the mixer panel.\n" ..
                "Are you ready to upgrade the project to enable this feature? " ..
                "Press Cancel if you’ve recently dragged a mixer track " ..
                "as you will need to reset its position before proceeding.",
                "Vertical Workflow", 1)
            if upgrade_response == 1 then
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
        reset_spacers(tracks_per_group, rcmaster_index)
        sync(tracks_per_group, end_of_sources)
        Main_OnCommand(40939, 0) -- select track 01
        solo()
        mixer()
        fold_small()
        move_items_to_first_source_group(tracks_per_group)
        set_recording_to_primary_and_secondary(end_of_sources)
        SetProjExtState(0, "ReaClassical", "Workflow", "Vertical")
    else
        MB(
            "In order to use this function either:\n" ..
            "1. Run on an empty project\n" ..
            "2. Run with one existing folder\n" ..
            "3. Run on multiple existing folders to sync routing/fx",
            "Vertical Workflow", 0
        )
        return
    end

    if check_hidden_track_items(num_of_tracks) then
        MB("Warning: Items have been pasted or recorded on hidden tracks! " ..
            "Open the Track Manager via the View menu, enable the hidden tracks on TCP then delete any items",
            "Vertical Workflow", 0)
    end

    if num_pre_selected > 0 then
        Main_OnCommand(40297, 0) --unselect_all
        SetOnlyTrackSelected(pre_selected[1])
        for _, track in ipairs(pre_selected) do
            if pcall(IsTrackSelected, track) then SetTrackSelected(track, 1) end
        end
    end

    if not rcmaster_exists then
        MB("Your project has been upgraded"
            .. " to use a single mixer set routed to RCMASTER bus. "
            .. "You can now move the parent fader without affecting the volume of child tracks.\n"
            .. "All groups are routed to the single mixer set visible in the mixer panel "
            .. "and all volume, panning, fx etc should be controlled there.\n"
            .. "If you delete any of these special busses by accident, simply run F8 again."
            , "Vertical Workflow", 0)
    end

    PreventUIRefresh(-1)
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
    make_folder()
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

        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^LIVE") or trackname_check(track, "^REF")

        if special_states or special_names then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end


        if IsTrackSelected(track) == true then
            -- SetMediaTrackInfo_Value(track, "I_SOLO", 2)
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        elseif not (special_states or special_names)
            and IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        elseif not (special_states or special_names) then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end

        local muted = GetMediaTrackInfo_Value(track, "B_MUTE")

        local states_for_receives = mixer_state == "y" or aux_state == "y"
            or submix_state == "y" or rcmaster_state == "y"
        local names_for_receives = trackname_check(track, "^M:") or trackname_check(track, "^@")
            or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER")

        if (states_for_receives or names_for_receives) and muted == 0 then
            local receives = GetTrackNumSends(track, -1)
            for j = 0, receives - 1, 1 do -- loop through receives
                local origin = GetTrackSendInfo_Value(track, -1, j, "P_SRCTRACK")
                if origin == selected_track or parent == 1 then
                    SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                    SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                    break
                end
            end
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
    local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
    mastering = (mastering ~= "" and tonumber(mastering)) or 0

    local colors = get_color_table()
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)

        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if trackname_check(track, "^M:") or mixer_state == "y" then
            SetTrackColor(track, colors.mixer)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end

        if trackname_check(track, "^@") or aux_state == "y" then
            SetTrackColor(track, colors.aux)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^#") or submix_state == "y" then
            SetTrackColor(track, colors.submix)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^RoomTone") or rt_state == "y" then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "^LIVE") or live_state == "y" then
            SetTrackColor(track, colors.live)
            SetMediaTrackInfo_Value(track, "I_RECMODE", 3)
            SetMediaTrackInfo_Value(track, "I_RECINPUT", -1)
            SetMediaTrackInfo_Value(track, "I_RECMODE_FLAGS", 2)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "^REF") or ref_state == "y" then
            SetTrackColor(track, colors.ref)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "RCMASTER") or rcmaster_state == "y" then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^LIVE") or trackname_check(track, "^REF")

        if special_states or special_names then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end

        local _, source_track = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", false)
        if trackname_check(track, "^S%d+:") or source_track == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 0 or 1)
        end

        local states_for_mastering = mixer_state == "y" or aux_state == "y"
            or submix_state == "y" or rcmaster_state == "y"
        local names_for_mastering = trackname_check(track, "^M:") or trackname_check(track, "^@")
            or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER")

        if states_for_mastering or names_for_mastering then
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
    collapse_folder()
    select_children_of_selected_folders()
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
        make_folder()
        collapse_folder()
    end
end

---------------------------------------------------------------------

function media_razor_group()
    select_all_parents()
    local num_of_folders = CountSelectedTracks(0)
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    if num_of_folders > 1 then
        for _ = 1, num_of_folders, 1 do
            select_children_of_selected_folders()
            Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
            select_next_folder()
        end
    else
        select_children_of_selected_folders()
        Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
    end
    Main_OnCommand(40297, 0)     -- Track: Unselect (clear selection of) all tracks
end

---------------------------------------------------------------------

function remove_track_groups()
    Main_OnCommand(40296, 0) -- select all tracks

    local function remove_track_grouping(track)
        local changed = false
        local _, chunk = GetTrackStateChunk(track, "", false)

        -- Remove GROUP_FLAGS and GROUP_FLAGS_HIGH lines entirely
        local new_chunk, subs = chunk:gsub("\nGROUP_FLAGS[^\n]*", "")
        if subs > 0 then changed = true end
        new_chunk, subs = new_chunk:gsub("\nGROUP_FLAGS_HIGH[^\n]*", "")
        if subs > 0 then changed = true end

        if changed then
            SetTrackStateChunk(track, new_chunk, false)
        end

        return changed
    end

    for i = -1, CountTracks(0) - 1 do
        local track = (i == -1) and GetMasterTrack(0) or GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            remove_track_grouping(track)
        end
    end

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
        local mixer_mod_name = process_name(track)
        table.insert(track_names, mixer_mod_name)
    end

    local dest_parent = track_table[1].parent
    GetSetMediaTrackInfo_String(dest_parent, "P_NAME", "D:" .. track_names[1], true)
    GetSetMediaTrackInfo_String(dest_parent, "P_EXT:Destination", "y", true)
    GetSetMediaTrackInfo_String(dest_parent, "P_EXT:Source", "", true)

    for i = 1, #track_table[1].tracks do
        local dest_track = track_table[1].tracks[i]
        GetSetMediaTrackInfo_String(dest_track, "P_NAME", "D:" .. (track_names[i + 1] or ""), true)
        GetSetMediaTrackInfo_String(dest_track, "P_EXT:Destination", "y", true)
        GetSetMediaTrackInfo_String(dest_track, "P_EXT:Source", "", true)
    end

    -- for rest, prefix Si: where i = number starting at 1
    for i = 2, #track_table, 1 do
        local source_parent = track_table[i].parent
        local parent_mod_name = track_names[1]
        GetSetMediaTrackInfo_String(source_parent, "P_NAME", "S" .. i - 1 .. ":" .. parent_mod_name, true)
        GetSetMediaTrackInfo_String(source_parent, "P_EXT:Source", "y", true)
        GetSetMediaTrackInfo_String(source_parent, "P_EXT:Destination", "", true)

        local num_of_names = #track_names
        local j = 1
        for _, source_track in ipairs(track_table[i].tracks) do
            local track_index = j % num_of_names + 1
            if track_index == 1 then track_index = 2 end
            local source_mod_name = track_names[track_index]
            GetSetMediaTrackInfo_String(source_track, "P_NAME", "S" .. (i - 1) .. ":" .. source_mod_name, true)
            GetSetMediaTrackInfo_String(source_track, "P_EXT:Source", "y", true)
            GetSetMediaTrackInfo_String(source_track, "P_EXT:Destination", "", true)
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
    GetSetMediaTrackInfo_String(rcmaster, "P_EXT:rcmaster", "y", true)
    GetSetMediaTrackInfo_String(rcmaster, "P_NAME", "RCMASTER", true)
    -- SetMediaTrackInfo_Value(rcmaster, "I_SPACER", 1)
    local colors = get_color_table()
    SetTrackColor(rcmaster, colors.rcmaster)
    SetMediaTrackInfo_Value(rcmaster, "B_SHOWINTCP", 0)

    return rcmaster
end

---------------------------------------------------------------------

function route_to_track(track, destination)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
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
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if name:match("^RCMASTER") then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "y", true)
            rcmaster_exists = true
            break
        end
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        if rcmaster_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_NAME", "RCMASTER", true)
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
    for _ = 0, num_of_receives - 1, 1 do
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
        GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", true)
        GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", j, true)
        if track_names then
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. track_names[j], true)
        else
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:", true)
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
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if name:sub(-1) ~= '-' then
            if name:match("^@") or name:match("^#") or name:match("^RoomTone") or name:match("^M:") then
                route_to_track(track, rcmaster)
            end
        end
        -- route rcmaster to live bounce if present
        if name:match("^LIVE") then
            remove_connections(track)
            CreateTrackSend(rcmaster, track)
            SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
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
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if parent == 1 then
            if j > 1 and k ~= prev_k then
                groups_equal = false
            end
            j = j + 1
            prev_k = k
            k = 1
            track_table[j] = { parent = track, tracks = {} }
            if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", k, true) end
        elseif trackname_check(track, "^M:") or mixer_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", true)
            local mod_name = string.match(name, "^M:(.*)") or name
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. mod_name, true)
            table.insert(mixer_tracks, track)
        elseif trackname_check(track, "^@") or aux_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:aux", "y", true)
            local mod_name = string.match(name, "@?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "@" .. mod_name, true)
        elseif trackname_check(track, "^#") or submix_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:submix", "y", true)
            local mod_name = string.match(name, "#?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "#" .. mod_name, true)
        elseif trackname_check(track, "^RoomTone") or rt_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "RoomTone", true)
        elseif trackname_check(track, "^LIVE") or live_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:live", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "LIVE", true)
        elseif trackname_check(track, "^REF") or ref_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "y", true)
            local mod_name = name:match("^REF:?(.*)") or name
            if name ~= "REF" then
                GetSetMediaTrackInfo_String(track, "P_NAME", "REF:" .. mod_name, true)
            end
        elseif trackname_check(track, "^RCMASTER") or rcmaster_state == "y" then
            rcmaster_index = i
        else
            if j > 0 then
                table.insert(track_table[j].tracks, track)
                if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", k + 1, true) end
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
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local mod_name = name:match("^%s*M?:?%s*(.-)%s*%-?$")
    if mod_name == nil then mod_name = name end
    return mod_name
end

---------------------------------------------------------------------

function reset_spacers(tracks_per_group, rcmaster_index)
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
            local _, name = GetSetMediaTrackInfo_String(dest, "P_NAME", "", false)
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
        for n = 0, num_of_fx - 1 do
            TrackFX_CopyToTrack(src_track, 0, dest_track, n, true)
        end
    end

    -- delele from all sources
    for i = 0, end_of_sources - 1 do
        local src_track = GetTrack(0, i)
        local num_of_fx = TrackFX_GetCount(src_track)
        for _ = 0, num_of_fx - 1 do
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
        local _, mix_order_str = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:mix_order", "", false)
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
    local items_to_move = {}

    for i, group in ipairs(track_table) do
        local parent_track = group.parent
        local mix_order = 1
        items_to_move[mix_order] = items_to_move[mix_order] or {}

        items_to_move[mix_order].rec_input = GetMediaTrackInfo_Value(parent_track, "I_RECINPUT")
        items_to_move[mix_order].items = {}

        local parent_item_count = GetTrackNumMediaItems(parent_track)
        for j = 0, parent_item_count - 1 do
            local item = GetTrackMediaItem(parent_track, j)
            table.insert(items_to_move[mix_order].items, item)
        end

        for _, child in ipairs(group.tracks) do
            local _, child_mix_order = GetSetMediaTrackInfo_String(child, "P_EXT:mix_order", "", false)
            child_mix_order = tonumber(child_mix_order) or 1

            items_to_move[child_mix_order] = items_to_move[child_mix_order] or {}
            items_to_move[child_mix_order].rec_input = GetMediaTrackInfo_Value(child, "I_RECINPUT")
            items_to_move[child_mix_order].items = {}

            local item_count = GetTrackNumMediaItems(child)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(child, j)
                table.insert(items_to_move[child_mix_order].items, item)
            end
        end

        local updated_group_tracks = {}
        local is_empty = false
        local updated_track_table = create_track_table(is_empty)

        for j, updated_group in ipairs(updated_track_table) do
            if j == i then
                local _, parent_mix_order = GetSetMediaTrackInfo_String(updated_group.parent, "P_EXT:mix_order",
                    current_order[1], 1)
                table.insert(updated_group_tracks,
                    { track = updated_group.parent, order = tonumber(parent_mix_order) or 1 })
                for k, child in ipairs(updated_group.tracks) do
                    local _, child_mix_order = GetSetMediaTrackInfo_String(child, "P_EXT:mix_order", current_order
                        [k + 1], 1)
                    table.insert(updated_group_tracks, { track = child, order = tonumber(child_mix_order) or 1 })
                end
                break
            end
        end

        for _, revised_track_info in ipairs(updated_group_tracks) do
            local revised_mix_order = revised_track_info.order

            local track_data = items_to_move[revised_mix_order] or {}
            local items = track_data.items or {}
            local rec_input = track_data.rec_input or 0

            for _, item in ipairs(items) do
                MoveMediaItemToTrack(item, revised_track_info.track)
            end

            SetMediaTrackInfo_Value(revised_track_info.track, "I_RECINPUT", rec_input)
        end

        for j, track_info in ipairs(updated_group_tracks) do
            GetSetMediaTrackInfo_String(track_info.track, "P_EXT:mix_order", tostring(j), true)
        end
    end
end

---------------------------------------------------------------------

function reset_mixer_order(mixer_table)
    for i, mixer_track in ipairs(mixer_table) do
        GetSetMediaTrackInfo_String(mixer_track, "P_EXT:mix_order", i, true)
    end
end

---------------------------------------------------------------------

function copy_track_names_from_dest(track_table, mixer_table)
    local track_names = {}

    -- for 1st prefix D: (remove anything existing before & including :)
    local parent = track_table[1].parent
    local parent_mod_name = process_dest(parent)
    table.insert(track_names, parent_mod_name)

    for _, track in ipairs(track_table[1].tracks) do
        local child_mod_name = process_dest(track)
        table.insert(track_names, child_mod_name)
    end

    local i = 1
    for _, track in ipairs(mixer_table) do
        if track_names[i] ~= nil then
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. track_names[i], true)
        else
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:", true)
        end
        i = i + 1
    end

    return track_names
end

---------------------------------------------------------------------

function process_dest(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local mod_name = string.match(name, ":(.*)")
    if mod_name == nil then mod_name = name end
    -- GetSetMediaTrackInfo_String(track, "P_NAME", mod_name, true)
    return mod_name
end

---------------------------------------------------------------------

function move_items_to_first_source_group(tracks_per_group)
    for i = 0, tracks_per_group - 1 do
        local track1 = GetTrack(0, i)
        local track2 = GetTrack(0, i + tracks_per_group)
        if track1 and track2 then
            for j = GetTrackNumMediaItems(track1) - 1, 0, -1 do
                local item = GetTrackMediaItem(track1, j)
                MoveMediaItemToTrack(item, track2)
            end
        end
    end
end

---------------------------------------------------------------------

function check_hidden_track_items(track_count)
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
            local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
            local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
            local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

            if mixer_state ~= "" or aux_state ~= "" or submix_state ~= "" or rcmaster_state ~= "" then
                local item_count = CountTrackMediaItems(track)
                if item_count > 0 then
                    return true
                end
            end
        end
    end
    return false
end

---------------------------------------------------------------------

function move_destination_folder_to_top()
    local track_count = CountTracks(0)
    if track_count == 0 then return end

    -- Find the destination folder
    local destination_folder = nil
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, is_dest = GetSetMediaTrackInfo_String(track, "P_EXT:destination", "", false)
            if is_dest == "y" and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track
                break
            end
        end
    end
    if not destination_folder then return end

    -- Finally, move the destination folder itself to top
    local dest_idx = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    if dest_idx > 0 then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(0, 0)
    end
end

-----------------------------------------------------------------------

function get_whole_number_input()
    while true do
        local ok, num = GetUserInputs("Vertical Workflow", 1, "How many tracks?", "10")
        if not ok then return nil end -- User cancelled

        num = tonumber(num)

        if num and num == math.floor(num) and num > 1 then
            return num
        else
            MB("Please enter a valid number. You need 2 or more tracks to make a folder!", "Invalid Input", 0)
        end
    end
end

---------------------------------------------------------------------

function set_recording_to_primary_and_secondary(end_of_sources)
    Main_OnCommand(40297, 0) -- Unselect all tracks
    local track_count = CountTracks(0)
    local i = 0

    while i < end_of_sources do
        if i < track_count then -- make sure the track exists
            local track = GetTrack(0, i)
            SetTrackSelected(track, true)
        end
        i = i + 1
    end

    Main_OnCommand(41323, 0) -- set primary+secondary
    Main_OnCommand(40297, 0) -- Unselect all tracks
end

---------------------------------------------------------------------

function reorder_special_tracks()
    local num_tracks = CountTracks(0)
    if num_tracks == 0 then return end

    local rcmaster_track = nil
    local m_tracks, aux_tracks, submix_tracks, roomtone_tracks = {}, {}, {}, {}
    local live_tracks, ref_tracks = {}, {}

    -- Collect tracks by type
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if name:match("^RCMASTER") or rcmaster_state == "y" then
            rcmaster_track = track
        elseif live_state == "y" or name:match("^LIVE") then
            table.insert(live_tracks, track)
        elseif ref_state == "y" or name:match("^REF") then
            table.insert(ref_tracks, track)
        elseif mixer_state == "y" then
            table.insert(m_tracks, track)
        elseif aux_state == "y" or name:match("^@") then
            table.insert(aux_tracks, track)
        elseif submix_state == "y" or name:match("^#") then
            table.insert(submix_tracks, track)
        elseif rt_state == "y" or name:match("^RoomTone") then
            table.insert(roomtone_tracks, track)
        end
    end

    -- Helper: select and reorder tracks at current RCMASTER position
    local function select_and_reorder(tracks)
        if #tracks == 0 then return end
        Main_OnCommand(40297, 0) -- unselect all
        for _, t in ipairs(tracks) do SetTrackSelected(t, true) end
        local index = rcmaster_track and GetMediaTrackInfo_Value(rcmaster_track, "IP_TRACKNUMBER") - 1 or 0
        ReorderSelectedTracks(index, 0)
        Main_OnCommand(40297, 0)
    end

    -- Pre-RCMASTER order: M: → aux → submix → roomtone
    select_and_reorder(m_tracks)
    select_and_reorder(aux_tracks)
    select_and_reorder(submix_tracks)
    select_and_reorder(roomtone_tracks)

    -- LIVE tracks immediately after RCMASTER
    if rcmaster_track then
        Main_OnCommand(40297, 0)
        for _, t in ipairs(live_tracks) do SetTrackSelected(t, true) end
        local live_index = GetMediaTrackInfo_Value(rcmaster_track, "IP_TRACKNUMBER")
        ReorderSelectedTracks(live_index, 0)
        Main_OnCommand(40297, 0)
    else
        -- No RCMASTER: LIVE tracks after special tracks
        local start_index = #m_tracks + #aux_tracks + #submix_tracks + #roomtone_tracks
        Main_OnCommand(40297, 0)
        for _, t in ipairs(live_tracks) do SetTrackSelected(t, true) end
        ReorderSelectedTracks(start_index, 0)
        Main_OnCommand(40297, 0)
    end

    -- REF tracks at the end
    Main_OnCommand(40297, 0)
    for _, t in ipairs(ref_tracks) do SetTrackSelected(t, true) end
    ReorderSelectedTracks(CountTracks(0), 0)
    Main_OnCommand(40297, 0)
end

---------------------------------------------------------------------

function select_children_of_selected_folders()
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) then
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if depth == 1 then -- folder parent
                local j = i + 1
                while j < track_count do
                    local ch_tr = GetTrack(0, j)
                    SetTrackSelected(ch_tr, true) -- select child track

                    local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
                    if ch_depth == -1 then
                        break -- end of folder children
                    end

                    j = j + 1
                end
            end
        end
    end
end

---------------------------------------------------------------------

function select_next_folder()
    local num_tracks = CountTracks(0)
    local depth = 0
    local target_depth = -1

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if target_depth ~= -1 then
            -- We're in search mode for the next folder at the same depth
            if depth == target_depth and folder_change == 1 then
                Main_OnCommand(40297, 0) -- Unselect all
                SetTrackSelected(tr, true)
                return
            elseif depth < target_depth then
                -- Gone out of that folder level, stop searching
                target_depth = -1
            end
        else
            -- Look for the selected folder
            if IsTrackSelected(tr) and folder_change == 1 then
                target_depth = depth
            end
        end

        -- Update depth for next iteration
        depth = depth + folder_change
    end
end

---------------------------------------------------------------------

function collapse_folder()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            local folderDepth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if folderDepth == 1 then -- folder start
                SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
            end
        end
    end
end

---------------------------------------------------------------------

function fold_small()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            local folderDepth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if folderDepth == 1 then -- folder start
                SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 1)
            end
        end
    end
end

---------------------------------------------------------------------

function make_folder()
    local numTracks = CountTracks(0)
    local i = 0

    while i < numTracks - 1 do
        local tr = GetTrack(0, i)
        local nextTr = GetTrack(0, i + 1)

        if GetMediaTrackInfo_Value(tr, "I_SELECTED") == 1
            and GetMediaTrackInfo_Value(nextTr, "I_SELECTED") == 1 then
            -- Set first track as folder start
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") + 1
            SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth)

            -- Move through consecutive selected tracks
            repeat
                i = i + 1
                tr = nextTr
                if i + 1 < numTracks then
                    nextTr = GetTrack(0, i + 1)
                else
                    nextTr = nil
                end
            until not nextTr or GetMediaTrackInfo_Value(nextTr, "I_SELECTED") ~= 1

            -- Set last track as folder end
            depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") - 1
            SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth)
        else
            i = i + 1
        end
    end
end

---------------------------------------------------------------------

function select_all_parents()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folderdepth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if folderdepth == 1 then
            SetMediaTrackInfo_Value(tr, "I_SELECTED", 1)
        else
            SetMediaTrackInfo_Value(tr, "I_SELECTED", 0)
        end
    end
end

---------------------------------------------------------------------

main()
