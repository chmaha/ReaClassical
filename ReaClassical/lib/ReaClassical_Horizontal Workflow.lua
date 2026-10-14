--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

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

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local main, create_destination_group, solo, trackname_check
local mixer, folder_check, flatten_nested_folders, groupings_mcp, check_mixer_order
local media_razor_group, remove_track_groups, get_color_table
local remove_spacers, copy_track_names
local add_rcmaster, route_to_track, special_check, remove_connections
local create_single_mixer, route_tracks, create_track_table
local process_name, delete_non_rc_tracks, delete_empty_items
local save_track_settings, reset_track_settings, write_to_mixer
local rearrange_tracks, reset_mixer_order, copy_track_names_from_dest
local process_dest, check_hidden_track_items
local set_recording_to_primary_and_secondary, reorder_special_tracks
local select_children_of_selected_folders, unselect_folder_children
local select_next_folder, make_folder, select_all_parents
local color_folder_children

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")
local special_track_order = require("ReaClassical_Special_Track_Order")
local spare_track = require("ReaClassical_Spare_Track")

function main()
    Undo_BeginBlock()
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0)
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
    if num_of_tracks > 0 and folder_check() > 0 then
        flatten_nested_folders()
    end
    PreventUIRefresh(1)
    if num_of_tracks == 0 then
        local is_empty = true
        SetProjExtState(0, "ReaClassical", "RCProject", "y")
        local creation_date = os.date("%Y-%m-%d %H:%M:%S", os.time())
        SetProjExtState(0, "ReaClassical", "CreationDate", creation_date)
        SetProjExtState(0, "ReaClassical", "Workflow", "")
        local _, track_count_str = GetProjExtState(0, "ReaClassical", "TrackCount")
        local num = tonumber(track_count_str)
        if not num then return end
        local _, single_track = GetProjExtState(0, "ReaClassical", "SingleTrack")
        local rcmaster
        if num >= 2 then
            rcmaster = create_destination_group(num)
        else
            return
        end
        if folder_check() == 1 then
            create_single_mixer(num, num)
            local track_table, rcmaster_index, _, _, mixer_track_table = create_track_table(is_empty)
            route_tracks(rcmaster, track_table, num)
            groupings_mcp()
            remove_spacers(rcmaster_index)

            local colors = get_color_table()
            SetMediaTrackInfo_Value(track_table[1].parent, "I_CUSTOMCOLOR", colors.dest_items)
            color_folder_children(track_table[1].parent, colors.dest_items)

            if single_track == "1" then spare_track.retire_second_track(false) end

            SetProjExtState(0, "ReaClassical", "Workflow", "Horizontal")
            if not _G.RC_SCRIPT_ARGS
                and not gui_mode.accessible() then
                local mission_control = NamedCommandLookup("_RScaa05755eb1dca4cec87c8ba9fe0ddf6570ce73c")
                Main_OnCommand(mission_control, 0)
            end
            set_recording_to_primary_and_secondary(mixer_track_table)
        end
        SetProjExtState(0, "ReaClassical", "TrackCount", "")
        SetProjExtState(0, "ReaClassical", "SingleTrack", "")
    elseif folder_check() > 1 then
        return
    elseif folder_check() == 1 then
        local is_empty = false
        local _, RCProject = GetProjExtState(0, "ReaClassical", "RCProject")
        if RCProject ~= "y" then
            local _, _, _, _, mixer_tracks = create_track_table(is_empty)
            if #mixer_tracks == 0 then
                local modifier = "Ctrl"
                local system = GetOS()
                if string.find(system, "^OSX") or string.find(system, "^macOS") then
                    modifier = "Cmd"
                end
                MB("This function can only run on a ReaClassical project. "
                    .. "Create a new empty project and press " .. modifier .. "+N.",
                    "Horizontal Workflow", 0)
                return
            else
                SetProjExtState(0, "ReaClassical", "RCProject", "y")
            end
        end
        SetCursorContext(1, nil)
        remove_track_groups()
        delete_non_rc_tracks()
        delete_empty_items()
        for i = #pre_selected, 1, -1 do
            if not ValidatePtr(pre_selected[i], "MediaTrack*") then
                table.remove(pre_selected, i)
            end
        end
        num_pre_selected = #pre_selected
        rcmaster_exists = special_check()
        if not rcmaster_exists then
            add_rcmaster(num_of_tracks)
        end

        local track_table, rcmaster_index, tracks_per_group, folder_count, mixer_tracks = create_track_table(is_empty)
        local end_of_sources = tracks_per_group * folder_count

        if #mixer_tracks ~= tracks_per_group then
            for _, track in pairs(mixer_tracks) do
                DeleteTrack(track)
            end
            track_table, _, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            local track_names = copy_track_names_from_dest(track_table, mixer_tracks)
            local controls, sends = save_track_settings(tracks_per_group)
            reset_track_settings(tracks_per_group)
            create_single_mixer(tracks_per_group, end_of_sources, track_names)
            track_table, rcmaster_index, tracks_per_group, _, mixer_tracks = create_track_table(is_empty)
            write_to_mixer(end_of_sources, tracks_per_group, controls, sends)
        end

        reorder_special_tracks()
        copy_track_names(track_table, mixer_tracks)

        local success, is_sequential, current_order = check_mixer_order(mixer_tracks)
        if not success then
            local response = MB(
                "You’re using a version of ReaClassical that supports track rearrangement through the mixer panel.\n" ..
                "Are you ready to upgrade the project to enable this feature? " ..
                "Press Cancel if you’ve recently dragged a mixer track " ..
                "as you will need to reset its position before proceeding.",
                "Horizontal Workflow", 1)
            if response == 1 then
                reset_mixer_order(mixer_tracks)
                create_track_table(true)
            end
        elseif not is_sequential then
            rearrange_tracks(track_table, current_order)
            reset_mixer_order(mixer_tracks)
        end

        local rcmaster = GetTrack(0, rcmaster_index)
        route_tracks(rcmaster, track_table, end_of_sources)
        groupings_mcp()
        remove_spacers(rcmaster_index)
        set_recording_to_primary_and_secondary(mixer_tracks)
        SetProjExtState(0, "ReaClassical", "Workflow", "Horizontal")
    else
        MB(
            "In order to use this function either:\n1. Run on an empty project\n" ..
            "2. Run on the existing folder to sync routing/fx",
            "Horizontal Workflow", 0)
        return
    end

    spare_track.apply_state()

    PreventUIRefresh(-1)

    if check_hidden_track_items(num_of_tracks) then
        MB("Warning: Items have been pasted or recorded on hidden tracks! " ..
            "Open the Track Manager via the View menu, enable the hidden tracks on TCP then delete any items",
            "Horizontal Workflow", 0)
    end

    if num_pre_selected > 0 then
        PreventUIRefresh(1)
        Main_OnCommand(40297, 0)
        SetOnlyTrackSelected(pre_selected[1])
        for _, track in ipairs(pre_selected) do
            if pcall(IsTrackSelected, track) then SetTrackSelected(track, 1) end
        end
    end

    PreventUIRefresh(-1)

    if num_of_tracks == 0 then
        local first_track = GetTrack(0, 0)
        if first_track then SetTrackSelected(first_track, true) end
    end

    Undo_EndBlock('Horizontal Workflow', 0)
    UpdateArrange()
    UpdateTimeline()
end

function create_destination_group(num)
    for _ = 1, num, 1 do
        InsertTrackAtIndex(0, true)
        SetMediaTrackInfo_Value(GetTrack(0, 0), "I_RECINPUT", -1)
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

function solo()
    local set_track_value = track_write.set_track_value
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if IsTrackSelected(track) == false then
            set_track_value(track, "I_SOLO", 0)
        end
    end
end

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

function mixer()
    local colors = get_color_table()
    local cache = track_scan.build()

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local t = cache.tags[track]
        local mixer_state = t.mixer
        local aux_state = t.aux
        local submix_state = t.submix
        local rt_state = t.roomtone
        local live_state = t.live
        local ref_state = t.rcref
        local listenback_state = t.listenback
        local rcmaster_state = t.rcmaster
        local playback_state = t.playback
        local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)

        local is_special_track = aux_state or submix_state or rt_state or
            live_state or ref_state or rcmaster_state or listenback_state or playback_state

        local mission_control_tcp_visible = nil
        if is_special_track then
            local _, tcp_vis_str = GetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid)
            if tcp_vis_str ~= "" then
                mission_control_tcp_visible = (tcp_vis_str == "1")
            end
        elseif mixer_state then
            local _, tcp_vis_str = GetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. guid)
            if tcp_vis_str ~= "" then
                mission_control_tcp_visible = (tcp_vis_str == "1")
            end
        end

        if mixer_state then
            SetTrackColor(track, colors.mixer)
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end

        if aux_state then
            SetTrackColor(track, colors.aux)
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end

        if submix_state then
            SetTrackColor(track, colors.submix)
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end

        if rt_state then
            SetTrackColor(track, colors.roomtone)
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            end
        end

        if live_state then
            SetTrackColor(track, colors.live)
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            end
        end

        if ref_state then
            SetTrackColor(track, colors.ref)
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            end
        end

        if rcmaster_state then
            SetTrackColor(track, colors.rcmaster)
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end

        if playback_state then
            SetTrackColor(track, colors.playback)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end

        if mixer_state or aux_state or submix_state or rcmaster_state
            or rt_state or live_state or ref_state or listenback_state
            or playback_state then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end

        local _, source_track = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", false)
        if trackname_check(track, "^S%d+:") or source_track == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end

        local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
        local parent_folder_visible = true

        if workflow == "Vertical" then
            local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

            if folder_depth ~= 1 then
                local parent_track = cache.parent[track]
                if parent_track then
                    local _, parent_guid = GetSetMediaTrackInfo_String(parent_track, "GUID", "", false)
                    local _, folder_vis_str = GetProjExtState(0, "ReaClassical_MissionControl",
                        "folder_tcp_visible_" .. parent_guid)

                    if folder_vis_str ~= "" then
                        parent_folder_visible = (folder_vis_str == "1")
                    end
                end
            end

            if folder_depth == 1 then
                local _, folder_vis_str = GetProjExtState(0, "ReaClassical_MissionControl",
                    "folder_tcp_visible_" .. guid)

                if folder_vis_str ~= "" then
                    local should_show = (folder_vis_str == "1")
                    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", should_show and 1 or 0)
                end
            else
                if not parent_folder_visible and not is_special_track and not mixer_state then
                    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
                end
            end
        end
    end
end

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

function flatten_nested_folders()
    local total_tracks = CountTracks(0)
    local tracks, depths, new_depths = {}, {}, {}
    for i = 0, total_tracks - 1, 1 do
        tracks[i + 1] = GetTrack(0, i)
        depths[i + 1] = GetMediaTrackInfo_Value(tracks[i + 1], "I_FOLDERDEPTH")
        new_depths[i + 1] = depths[i + 1]
    end

    local stack = {}
    for i = 1, total_tracks, 1 do
        local depth = depths[i]
        if depth == 1 then
            if #stack == 0 then
                table.insert(stack, true)
            else
                table.insert(stack, false)
                new_depths[i] = 0
            end
        elseif depth < 0 then
            local closed_real = 0
            for _ = 1, -depth do
                if table.remove(stack) then
                    closed_real = closed_real + 1
                end
            end
            new_depths[i] = -closed_real
        end
    end

    for i = 1, total_tracks, 1 do
        if new_depths[i] ~= depths[i] then
            SetMediaTrackInfo_Value(tracks[i], "I_FOLDERDEPTH", new_depths[i])
        end
    end
end

function groupings_mcp()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    media_razor_group()
    SetOnlyTrackSelected(first_track)
    solo()
    select_children_of_selected_folders()
    unselect_folder_children()
end

local function enable_media_razor_groups()
    if not APIExists("kbd_getTextFromCmd") then return end
    local main_section = SectionFromUniqueID(0)

    local function enable_range(first, last)
        for cmd = first, last do
            local name = kbd_getTextFromCmd(cmd, main_section)
            if name and name:match("^Group: Enable group %d+$") then
                if GetToggleCommandState(cmd) ~= 1 then
                    Main_OnCommand(cmd, 0)
                end
            end
        end
    end
    enable_range(42511, 42574)
    enable_range(43278, 43341)
end

function media_razor_group()
    select_all_parents()
    local num_of_folders = CountSelectedTracks(0)
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    if num_of_folders > 1 then
        for _ = 1, num_of_folders, 1 do
            select_children_of_selected_folders()
            Main_OnCommand(42578, 0)
            select_next_folder()
        end
    else
        select_children_of_selected_folders()
        Main_OnCommand(42578, 0)
    end
    enable_media_razor_groups()
    Main_OnCommand(40296, 0)

    Main_OnCommand(40297, 0)
    Main_OnCommand(40939, 0)
    select_children_of_selected_folders()

    solo()
    select_children_of_selected_folders()
    local tracks_per_group = CountSelectedTracks(0)
    mixer()
    unselect_folder_children()

    Main_OnCommand(40297, 0)
    Main_OnCommand(40939, 0)
    return tracks_per_group
end

function remove_track_groups()
    Main_OnCommand(40296, 0)

    local function remove_track_grouping(track)
        local changed = false
        local _, chunk = GetTrackStateChunk(track, "", false)

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
    Main_OnCommand(40297, 0)
end

function remove_spacers(num_of_tracks)
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_SPACER", 0)
    end
end

function copy_track_names(track_table, mixer_track_table)
    local track_names = {}

    for _, track in ipairs(mixer_track_table) do
        local mod_name = process_name(track)
        table.insert(track_names, mod_name)
    end

    local parent = track_table[1].parent
    GetSetMediaTrackInfo_String(parent, "P_NAME", track_names[1], true)

    local i = 2
    for _, track in ipairs(track_table[1].tracks) do
        if track_names[i] ~= nil then
            GetSetMediaTrackInfo_String(track, "P_NAME", track_names[i], true)
        else
            GetSetMediaTrackInfo_String(track, "P_NAME", "", true)
        end
        i = i + 1
    end

    return track_names
end

function get_color_table()
    return require("ReaClassical_Colors_Table")
end

function color_folder_children(parent_track, folder_color)
    if not parent_track or not folder_color then return end
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end
        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        if depth > 0 then SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", folder_color) end
        depth = depth + folder_depth
        if depth <= 0 then break end
        idx = idx + 1
    end
end

function add_rcmaster(num)
    InsertTrackAtIndex(num, true)
    local rcmaster = GetTrack(0, num)
    SetMediaTrackInfo_Value(rcmaster, "I_RECINPUT", -1)
    GetSetMediaTrackInfo_String(rcmaster, "P_EXT:rcmaster", "y", true)
    GetSetMediaTrackInfo_String(rcmaster, "P_NAME", "RCMASTER", true)
    local colors = get_color_table()
    SetTrackColor(rcmaster, colors.rcmaster)
    SetMediaTrackInfo_Value(rcmaster, "B_SHOWINTCP", 0)

    return rcmaster
end

function route_to_track(track, destination)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if not name:match("^RCMASTER") then
        SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
        CreateTrackSend(track, destination)
    end
end

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

function remove_connections(track)
    SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
    local num_of_receives = GetTrackNumSends(track, -1)
    for _ = 0, num_of_receives - 1, 1 do
        RemoveTrackSend(track, -1, 0)
    end
end

function create_single_mixer(tracks_per_group, end_of_sources, track_names)
    for _ = 1, tracks_per_group, 1 do
        InsertTrackAtIndex(end_of_sources, true)
    end
    local j = 1
    local end_of_mixers = end_of_sources + tracks_per_group - 1
    for i = end_of_sources, end_of_mixers, 1 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_RECINPUT", -1)
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

function route_tracks(rcmaster, track_table, end_of_sources)
    local num_of_tracks = CountTracks(0)
    local first_mixer = GetTrack(0, end_of_sources)

    remove_connections(rcmaster)
    for i = end_of_sources, end_of_sources + #track_table[1].tracks, 1 do
        local mixer_track = GetTrack(0, i)
        remove_connections(mixer_track)
    end
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local _, rcm_disconnect = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect",
            "", false)
        if rcm_disconnect ~= "y" then
            if name:match("^@") or name:match("^#") or name:match("^RoomTone") or name:match("^M:") then
                route_to_track(track, rcmaster)
            end
        end
        if name:match("^LIVE") then
            remove_connections(track)
            CreateTrackSend(rcmaster, track)
            SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
        end
    end

    SetMediaTrackInfo_Value(rcmaster, "B_MAINSEND", 1)

    for _, entry in ipairs(track_table) do
        local parent = entry.parent
        route_to_track(parent, first_mixer)
    end
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
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, playback_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)
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
        elseif trackname_check(track, "^LISTENBACK") or listenback_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "LISTENBACK", true)
        elseif trackname_check(track, "^PLAYBACK") or playback_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:playback", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "PLAYBACK", true)
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
    if j > 1 and k ~= prev_k then
        groups_equal = false
    end
    return track_table, rcmaster_index, k, j, mixer_tracks, groups_equal
end

function process_name(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local mod_name = name:match("^%s*M?:?%s*(.-)%s*%-?$")
    if mod_name == nil then mod_name = name end
    return mod_name
end

function save_track_settings(tracks_per_group)
    local controls = {}
    local sends = {}
    local parmnames = { "B_PHASE", "D_VOL", "D_PAN" }
    for i = 0, tracks_per_group - 1 do
        local track = GetTrack(0, i)

        local values = {}
        for _, parmname in ipairs(parmnames) do
            local val = GetMediaTrackInfo_Value(track, parmname)
            values[parmname] = val
        end
        table.insert(controls, { track = track, values = values })

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

function reset_track_settings(tracks_per_group)
    for i = 0, tracks_per_group - 1 do
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

function write_to_mixer(end_of_sources, tracks_per_group, controls, sends)
    local end_of_mixers = end_of_sources + tracks_per_group - 1
    local j = 1
    local k = 1

    for i = end_of_sources, end_of_mixers do
        local track = GetTrack(0, i)

        SetMediaTrackInfo_Value(track, "B_PHASE", controls[j].values["B_PHASE"])
        SetMediaTrackInfo_Value(track, "D_VOL", controls[j].values["D_VOL"])
        SetMediaTrackInfo_Value(track, "D_PAN", controls[j].values["D_PAN"])
        j = j + 1

        for _, dest_track in ipairs(sends[k]) do
            CreateTrackSend(track, dest_track)
        end
        k = k + 1
    end

    for i = 0, tracks_per_group - 1 do
        local src_track = GetTrack(0, i)
        local dest_index = end_of_sources + i
        local dest_track = GetTrack(0, dest_index)
        local num_of_fx = TrackFX_GetCount(src_track)
        for n = 0, num_of_fx - 1 do
            TrackFX_CopyToTrack(src_track, 0, dest_track, n, true)
        end
    end
end

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
            reset_mixer_order(mixer_table)
            create_track_table(true)
            success = false
        end

        if mix_order ~= i then
            is_sequential = false
        end
    end

    return success, is_sequential, current_order
end

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

function reset_mixer_order(mixer_table)
    for i, mixer_track in ipairs(mixer_table) do
        GetSetMediaTrackInfo_String(mixer_track, "P_EXT:mix_order", i, true)
    end
end

function copy_track_names_from_dest(track_table, mixer_table)
    local track_names = {}

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

function process_dest(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local mod_name = string.match(name, ":(.*)")
    if mod_name == nil then mod_name = name end
    return mod_name
end

function check_hidden_track_items(track_count)
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
            local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
            local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
            local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
            local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
            local _, playback_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)

            if mixer_state ~= "" or aux_state ~= "" or submix_state ~= ""
                or rcmaster_state ~= "" or listenback_state ~= "" or playback_state ~= "" then
                local item_count = CountTrackMediaItems(track)
                if item_count > 0 then
                    return true
                end
            end
        end
    end
    return false
end

function set_recording_to_primary_and_secondary(mixer_track_table)
    Main_OnCommand(40297, 0)
    local track_count = CountTracks(0)
    local i = 0

    while i < #mixer_track_table do
        if i < track_count then
            local track = GetTrack(0, i)
            SetTrackSelected(track, true)
        end
        i = i + 1
    end

    Main_OnCommand(41323, 0)
    Main_OnCommand(40297, 0)
end

function reorder_special_tracks()
    special_track_order.reorder()
end

function select_children_of_selected_folders()
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) then
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if depth == 1 then
                local j = i + 1
                while j < track_count do
                    local ch_tr = GetTrack(0, j)
                    SetTrackSelected(ch_tr, true)

                    local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
                    if ch_depth == -1 then
                        break
                    end

                    j = j + 1
                end
            end
        end
    end
end

function unselect_folder_children()
    local num_tracks = CountTracks(0)
    local depth = 0
    local unselect_mode = false

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if IsTrackSelected(tr) and folder_change == 1 then
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        if folder_change > 0 then
            depth = depth + folder_change
        elseif folder_change < 0 then
            depth = depth + folder_change
            if depth <= 0 then
                unselect_mode = false
                depth = 0
            end
        end
    end
end

function select_next_folder()
    local num_tracks = CountTracks(0)
    local depth = 0
    local target_depth = -1

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if target_depth ~= -1 then
            if depth == target_depth and folder_change == 1 then
                Main_OnCommand(40297, 0)
                SetTrackSelected(tr, true)
                return
            elseif depth < target_depth then
                target_depth = -1
            end
        else
            if IsTrackSelected(tr) and folder_change == 1 then
                target_depth = depth
            end
        end

        depth = depth + folder_change
    end
end

function make_folder()
    local numTracks = CountTracks(0)
    local i = 0

    while i < numTracks - 1 do
        local tr = GetTrack(0, i)
        local nextTr = GetTrack(0, i + 1)

        if GetMediaTrackInfo_Value(tr, "I_SELECTED") == 1
            and GetMediaTrackInfo_Value(nextTr, "I_SELECTED") == 1 then
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") + 1
            SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth)

            repeat
                i = i + 1
                tr = nextTr
                if i + 1 < numTracks then
                    nextTr = GetTrack(0, i + 1)
                else
                    nextTr = nil
                end
            until not nextTr or GetMediaTrackInfo_Value(nextTr, "I_SELECTED") ~= 1

            depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") - 1
            SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth)
        else
            i = i + 1
        end
    end
end

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

function delete_non_rc_tracks()
    local rc_keys = {
        "mix_order", "mixer", "aux", "submix", "roomtone",
        "live", "rcref", "listenback", "rcmaster", "playback", "Destination", "Source"
    }

    local function is_rc_track(track)
        for _, key in ipairs(rc_keys) do
            local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
            if val ~= "" then return true end
        end
        return false
    end

    local to_delete = {}
    local named_with_items = {}

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if not is_rc_track(track) then
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            local item_count = CountTrackMediaItems(track)
            if item_count > 0 then
                table.insert(named_with_items, name ~= "" and name or "<unnamed>")
            end
            table.insert(to_delete, track)
        end
    end

    if #to_delete > 0 then
        Main_OnCommand(40297, 0)
        for _, track in ipairs(to_delete) do
            SetTrackSelected(track, true)
        end
        ReorderSelectedTracks(CountTracks(0), 0)
        Main_OnCommand(40297, 0)

        for i = #to_delete, 1, -1 do
            DeleteTrack(to_delete[i])
        end
    end

    if #named_with_items > 0 then
        MB("The following tracks contained items and were removed:\n" ..
            table.concat(named_with_items, "\n"), "ReaClassical", 0)
    end
end

function delete_empty_items()
    for i = CountMediaItems(0) - 1, 0, -1 do
        local item = GetMediaItem(0, i)
        if not GetActiveTake(item) then
            DeleteTrackMediaItem(GetMediaItemTrack(item), item)
        end
    end
end

main()
