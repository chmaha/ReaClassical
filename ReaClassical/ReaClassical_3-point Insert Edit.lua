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

local main, markers, select_matching_source_folder, copy_source, split_at_dest_in
local create_crossfades, clean_up, load_last_assembly_item
local ripple_lock_mode, return_xfade_length, get_item_guid
local get_first_last_items, mark_as_edit, select_midpoint_peers
local move_to_project_tab, save_source_details, adaptive_delete
local count_selected_media_items, get_selected_media_item_at
local move_destination_folder_to_top, move_destination_folder
local select_item_under_cursor_on_selected_track, fix_marker_pair
local save_last_assembly_item, save_view, restore_view
local get_item_by_guid, select_matching_dest_folder, add_marker
local folder_check, get_track_prefix, trim_left_item_to_dest_in
local save_ripple_state, restore_ripple_state
local get_folder_items_at_midpoint, select_all_folder_tracks
local find_folder_by_prefix
local sanitize_marker_zones, drop_stacked_items_at_cursor

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local sd_xfade = require("ReaClassical_SD_Crossfade_Utils")
local sd_snapshot = require("ReaClassical_SD_Snapshot")
local enum_project_markers = require("ReaClassical_Marker_Enum")

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    local initial_proj = EnumProjects(-1)

    Main_OnCommand(41121, 0)

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local moveable_dest = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[12] then moveable_dest = tonumber(table[12]) or 0 end
    end

    if moveable_dest == 1 then move_destination_folder_to_top() end

    local proj_marker_count, source_proj, dest_proj, dest_in, _, _, source_in,
    source_out, source_count, pos_table, src_track_number, dest_track_number = markers()

    local source_workflow = workflow
    local dest_workflow = workflow
    if source_proj then
        local _, sw = GetProjExtState(source_proj, "ReaClassical", "Workflow")
        if sw ~= "" then source_workflow = sw end
    end
    if dest_proj then
        local _, dw = GetProjExtState(dest_proj, "ReaClassical", "Workflow")
        if dw ~= "" then dest_workflow = dw end
    end

    move_to_project_tab(source_proj)
    local source_ripple = save_ripple_state()
    local initial_curpos, initial_selected_items, initial_selected_tracks = save_view()

    move_to_project_tab(dest_proj)
    local dest_ripple = save_ripple_state()

    local function restore_all_ripple()
        move_to_project_tab(dest_proj)
        restore_ripple_state(dest_ripple)
        move_to_project_tab(source_proj)
        restore_ripple_state(source_ripple)
        move_to_project_tab(initial_proj)
    end

    if proj_marker_count == 1 then
        MB("Only one S-D project marker was found."
            .. "\nUse zero for regular single project S-D editing"
            .. "\nor use two for multi-tab S-D editing.", "Source-Destination Edit", 0)
        if moveable_dest == 1 then move_destination_folder(src_track_number) end
        restore_all_ripple()
        return
    end

    if proj_marker_count == -1 then
        MB(
            "Source or destination markers should be paired with " ..
            "the corresponding source or destination project marker.",
            "Multi-tab Source-Destination Edit", 0)
        if moveable_dest == 1 then move_destination_folder(src_track_number) end
        restore_all_ripple()
        return
    end

    ripple_lock_mode()

    if dest_in == 1 and source_count == 2 then
        move_to_project_tab(dest_proj)
        local last_saved_item = load_last_assembly_item()
        if last_saved_item then
            local item_start = GetMediaItemInfo_Value(last_saved_item, "D_POSITION")
            local item_length = GetMediaItemInfo_Value(last_saved_item, "D_LENGTH")
            local item_right_edge = item_start + item_length
            local threshold = 0.0001
            if math.abs(item_right_edge - pos_table[1]) > threshold then
                local user_input = MB(
                    "The DEST-IN marker has been moved since the last assembly line edit.\n" ..
                    "Do you want to start a new edit sequence?\n" ..
                    "Answering \"No\" will move the DEST-IN marker back to the previous item edge.",
                    "Assembly Line / 3-point Insert Edit", 3)
                if user_input == 2 then
                    restore_all_ripple()
                    return
                elseif user_input == 7 then
                    local i = 0
                    while true do
                        local project, _ = EnumProjects(i)
                        if project == nil then break end
                        DeleteProjectMarker(project, 996, false)
                        i = i + 1
                    end
                    add_marker(item_right_edge, 0, dest_track_number, "DEST-IN", 996, 0, dest_workflow)
                end
            end
        end
        add_marker(pos_table[1], 0, dest_track_number, "DEST-OUT", 997, 0, dest_workflow)
    else
        MB(
            "Please add 3 valid source-destination markers: DEST-IN, SOURCE-IN and SOURCE-OUT"
            , "Assembly Line / 3-point Insert Edit", 0)
        if moveable_dest == 1 then move_destination_folder(src_track_number) end
        restore_all_ripple()
        return
    end

    local shortened_in, shortened_out, applied_in, applied_out
    local sliver_note = ""
    local _, _, _, _, _, new_dest_count, _, _, new_source_count, _, _, _ = markers()
    if new_dest_count + new_source_count == 4 then
        move_to_project_tab(source_proj)
        fix_marker_pair(998, 999)
        local _, is_selected = copy_source()
        if is_selected == false then
            clean_up(is_selected)
            restore_all_ripple()
            return
        end
        Main_OnCommand(40020, 0)
        move_to_project_tab(dest_proj)
        fix_marker_pair(996, 997)
        select_matching_dest_folder()
        sliver_note = sanitize_marker_zones({ { id = 996, label = "DEST-IN" } })
        sd_snapshot.capture(sd_xfade.folder_tracks(GetSelectedTrack(0, 0)),
            sd_snapshot.marker_pos(996))
        trim_left_item_to_dest_in()
        split_at_dest_in()
        Main_OnCommand(40625, 0)
        GoToMarker(0, 997, false)
        Main_OnCommand(40289, 0)
        Main_OnCommand(40626, 0)
        select_all_folder_tracks()
        Main_OnCommand(40630, 0)

        if dest_workflow == "Horizontal" then
            Main_OnCommand(40311, 0)
        else
            Main_OnCommand(40310, 0)
        end

        Main_OnCommand(40312, 0)
        select_matching_dest_folder()
        Main_OnCommand(42398, 0)
        for i = 0, CountSelectedMediaItems(0) - 1 do
            SetMediaItemInfo_Value(GetSelectedMediaItem(0, i), "C_LOCK", 0)
        end
        mark_as_edit()

        local new_last_item
        new_last_item, shortened_in, shortened_out, applied_in, applied_out = create_crossfades()
        sd_snapshot.commit()
        save_last_assembly_item(new_last_item)
        clean_up(is_selected)
        Main_OnCommand(40289, 0)

        local item_start = GetMediaItemInfo_Value(new_last_item, "D_POSITION")
        local item_length = GetMediaItemInfo_Value(new_last_item, "D_LENGTH")
        local end_of_new_item = item_start + item_length
        local dest_track = GetTrack(0, dest_track_number - 1)
        add_marker(end_of_new_item, 0, dest_track_number, "DEST-IN", 996, GetTrackColor(dest_track), dest_workflow)

        move_to_project_tab(source_proj)

        local _, curpos_str = GetProjExtState(0, "ReaClassical", "CURPOS")
        if curpos_str ~= "" then
            local curpos = tonumber(curpos_str)
            if curpos then
                SetEditCurPos(curpos, false, false)
                SetProjExtState(0, "ReaClassical", "CURPOS", "")
            end
        end

        if moveable_dest == 1 then move_destination_folder(src_track_number) end

        Main_OnCommand(40289, 0)
        restore_all_ripple()
    else
        if moveable_dest == 1 then move_destination_folder(src_track_number) end
        restore_all_ripple()
        return
    end

    restore_view(initial_curpos, initial_selected_items, initial_selected_tracks)

    Undo_EndBlock('Assembly Line / 3-point Insert Edit', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
    local warning = nil
    if shortened_in or shortened_out then
        local parts = {}
        if shortened_in then
            parts[#parts + 1] = string.format("%d ms at source-in", math.floor(applied_in * 1000 + 0.5))
        end
        if shortened_out then
            parts[#parts + 1] = string.format("%d ms at source-out", math.floor(applied_out * 1000 + 0.5))
        end
        warning = "Crossfade shortened to " .. table.concat(parts, " and ") .. " due to limited source material."
    end
    if warning and not (APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed) then
        MB(warning, "Assembly Line / 3-point Insert Edit", 0)
    end
    if sliver_note ~= "" then
        MB(sliver_note, "Assembly Line / 3-point Insert Edit", 0)
    end
    local completion = "Insert edit complete"
    if warning then completion = completion .. ". " .. warning end
    say(completion)
end

function markers()
    local marker_labels = { "DEST-IN", "DEST-OUT", "SOURCE-IN", "SOURCE-OUT" }
    local sd_markers = {}
    for _, label in ipairs(marker_labels) do
        sd_markers[label] = { count = 0, proj = nil }
    end

    local num = 0
    local source_proj, dest_proj
    local proj_marker_count = 0
    local pos_table = {}
    local active_proj = EnumProjects(-1)

    local _, src_stored = GetProjExtState(0, "ReaClassical", "SourceInTrackNum")
    local _, dest_stored = GetProjExtState(0, "ReaClassical", "DestInTrackNum")
    local src_track_number = tonumber(src_stored) or 1
    local dest_track_number = tonumber(dest_stored) or 1

    local raw_labels = {}

    while true do
        local proj = EnumProjects(num)
        if proj == nil then break end
        local num_markers = GetNumRegionsOrMarkers(proj)
        for i = 0, num_markers - 1, 1 do
            local _, _, pos, _, raw_label, _ = enum_project_markers(proj, i)
            local label = string.match(raw_label, ".+:(.+)") or raw_label

            if label == "DEST-IN" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[1] = pos
                raw_labels[996] = raw_label
            elseif label == "DEST-OUT" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[2] = pos
                raw_labels[997] = raw_label
            elseif label == "SOURCE-IN" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[3] = pos
                raw_labels[998] = raw_label
            elseif label == "SOURCE-OUT" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[4] = pos
                raw_labels[999] = raw_label
            elseif string.match(label, "SOURCE PROJECT") then
                source_proj = proj; proj_marker_count = proj_marker_count + 1
            elseif string.match(label, "DEST PROJECT") then
                dest_proj = proj; proj_marker_count = proj_marker_count + 1
            end
        end
        num = num + 1
    end

    if proj_marker_count == 0 then
        for _, marker in pairs(sd_markers) do
            if marker.proj ~= active_proj then marker.count = 0 end
        end
        local src_raw = raw_labels[998] or raw_labels[999]
        if src_raw then
            local prefix = src_raw:match("^(.-):")
            if prefix then
                local tr = find_folder_by_prefix(prefix)
                if tr then
                    src_track_number = math.floor(GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
                end
            end
        end
        local dest_raw = raw_labels[996] or raw_labels[997]
        if dest_raw then
            local prefix = dest_raw:match("^(.-):")
            if prefix then
                local tr = find_folder_by_prefix(prefix)
                if tr then
                    dest_track_number = math.floor(GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
                end
            end
        else
            local tr = find_folder_by_prefix("D")
            if tr then
                dest_track_number = math.floor(GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
            end
        end
    end

    local source_in    = sd_markers["SOURCE-IN"].count
    local source_out   = sd_markers["SOURCE-OUT"].count
    local dest_in      = sd_markers["DEST-IN"].count
    local dest_out     = sd_markers["DEST-OUT"].count

    local sin          = sd_markers["SOURCE-IN"].proj
    local sout         = sd_markers["SOURCE-OUT"].proj
    local din          = sd_markers["DEST-IN"].proj
    local dout         = sd_markers["DEST-OUT"].proj

    local source_count = source_in + source_out
    local dest_count   = dest_in + dest_out

    if (source_count == 2 and sin ~= sout) or (dest_count == 2 and din ~= dout) then
        proj_marker_count = -1
    end
    if source_proj and ((sin and sin ~= source_proj) or (sout and sout ~= source_proj)) then
        proj_marker_count = -1
    end
    if dest_proj and ((din and din ~= dest_proj) or (dout and dout ~= dest_proj)) then
        proj_marker_count = -1
    end

    return proj_marker_count, source_proj, dest_proj, dest_in, dest_out, dest_count,
        source_in, source_out, source_count, pos_table, src_track_number, dest_track_number
end

function find_folder_by_prefix(prefix)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            local _, name = GetTrackName(track)
            if name:match("^(.-):" ) == prefix then return track end
        end
    end
    return nil
end

function select_matching_source_folder()
    local nm = GetNumRegionsOrMarkers(0)
    for i = 0, nm - 1 do
        local _, _, _, _, raw_label, id = enum_project_markers(0, i)
        if id == 998 or id == 999 then
            local prefix = raw_label:match("^(.-):")
            if prefix then
                local track = find_folder_by_prefix(prefix)
                if track then SetOnlyTrackSelected(track); return end
            end
            break
        end
    end
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            SetOnlyTrackSelected(track); return
        end
    end
end

function select_matching_dest_folder()
    GoToMarker(0, 996, false)
    local nm = GetNumRegionsOrMarkers(0)
    for i = 0, nm - 1 do
        local _, _, _, _, raw_label, id = enum_project_markers(0, i)
        if id == 996 or id == 997 then
            local prefix = raw_label:match("^(.-):")
            if prefix then
                local track = find_folder_by_prefix(prefix)
                if track then SetOnlyTrackSelected(track); return end
            end
            break
        end
    end
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            SetOnlyTrackSelected(track); return
        end
    end
end

function copy_source()
    local is_selected = true
    SetCursorContext(1, nil)
    Main_OnCommand(40311, 0)
    Main_OnCommand(40289, 0)
    GoToMarker(0, 998, false)
    select_matching_source_folder()
    Main_OnCommand(40625, 0)
    GoToMarker(0, 999, false)
    Main_OnCommand(40626, 0)
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local sel_length = end_time - start_time
    Main_OnCommand(40718, 0)
    GoToMarker(0, 998, false)
    drop_stacked_items_at_cursor(true)
    GoToMarker(0, 999, false)
    drop_stacked_items_at_cursor(false)
    save_source_details()
    local selected_items = count_selected_media_items()
    if selected_items == 0 then is_selected = false end
    select_midpoint_peers()
    Main_OnCommand(41383, 0)
    Main_OnCommand(40289, 0)
    return sel_length, is_selected
end

function get_folder_items_at_midpoint(ref_item, folder_start, folder_end)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

function split_at_dest_in()
    Main_OnCommand(40927, 0)
    select_item_under_cursor_on_selected_track()
    local initial_selected_items = count_selected_media_items()
    if initial_selected_items == 2 then
        local second_item = get_selected_media_item_at(1)
        if second_item then
            local marker_pos = nil
            local i = 0
            while true do
                local retval, isrgn, pos, _, _, markrgnindexnumber = enum_project_markers(0, i)
                if not retval then break end
                if not isrgn and markrgnindexnumber == 996 then
                    marker_pos = pos; break
                end
                i = i + 1
            end

            if marker_pos then
                local num_tracks = CountTracks(0)
                local sel_track = GetSelectedTrack(0, 0)
                local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
                local folder_start, folder_end = nil, nil
                for t = track_num, num_tracks - 1 do
                    local track = GetTrack(0, t)
                    local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
                    if depth == 1 then
                        folder_start = t; folder_end = t
                        local x = t + 1
                        while x < num_tracks do
                            local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                            folder_end = x
                            if d < 0 then break end
                            x = x + 1
                        end
                        break
                    end
                end

                if folder_start then
                    local peers = get_folder_items_at_midpoint(second_item, folder_start, folder_end)
                    for _, item in ipairs(peers) do
                        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                        local item_end   = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")
                        if marker_pos > item_start and marker_pos < item_end then
                            local new_len = item_end - marker_pos
                            SetMediaItemInfo_Value(item, "D_POSITION", marker_pos)
                            SetMediaItemInfo_Value(item, "D_LENGTH", new_len)
                        end
                    end
                end
            end

            SetMediaItemSelected(second_item, false)
        end
    end
    local final_selected_items = count_selected_media_items()
    select_midpoint_peers()
    Main_OnCommand(40912, 0)
    if final_selected_items > 0 then
        Main_OnCommand(40186, 0)
    end
    Main_OnCommand(40289, 0)
end

function create_crossfades()
    local first_sel_item, last_sel_item = get_first_last_items()
    local xfade_len = return_xfade_length()

    Main_OnCommand(40289, 0)
    SetMediaItemSelected(first_sel_item, true)
    select_midpoint_peers()
    local in_items = {}
    for i = 0, count_selected_media_items() - 1 do
        in_items[#in_items + 1] = get_selected_media_item_at(i)
    end
    local in_neighbors = sd_xfade.get_adjacent_neighbors(in_items, "left")
    local applied_in, shortened_in = sd_xfade.create_crossfade(in_items, in_neighbors, "left", xfade_len)

    Main_OnCommand(40289, 0)
    SetMediaItemSelected(last_sel_item, true)
    select_midpoint_peers()
    local out_items = {}
    for i = 0, count_selected_media_items() - 1 do
        out_items[#out_items + 1] = get_selected_media_item_at(i)
    end
    local out_neighbors = sd_xfade.get_adjacent_neighbors(out_items, "right")
    local applied_out, shortened_out = sd_xfade.create_crossfade(out_items, out_neighbors, "right", xfade_len)

    Main_OnCommand(40912, 0)
    Main_OnCommand(40289, 0)
    return last_sel_item, shortened_in, shortened_out, applied_in, applied_out
end

function clean_up(is_selected)
    Main_OnCommand(40020, 0)
    if is_selected then
        local i = 0
        while true do
            local project = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 996, false)
            DeleteProjectMarker(project, 997, false)
            i = i + 1
        end
    else
        MB("Please make sure there is material to copy between your source markers...",
            "Source-Destination Edit", 0)
    end
end

function ripple_lock_mode()
    local _, original_ripple_lock_mode = get_config_var_string("ripplelockmode")
    original_ripple_lock_mode = tonumber(original_ripple_lock_mode)
    if original_ripple_lock_mode ~= 2 then
        SNM_SetIntConfigVar("ripplelockmode", 2)
    end
end

function save_ripple_state()
    if GetToggleCommandState(40311) == 1 then
        return "all"
    elseif GetToggleCommandState(40310) == 1 then
        return "per"
    else
        return "off"
    end
end

function restore_ripple_state(state)
    Main_OnCommand(40309, 0)
    if state == "all" then
        Main_OnCommand(40311, 0)
    elseif state == "per" then
        Main_OnCommand(40310, 0)
    end
end

function return_xfade_length()
    local xfade_len = 0.035
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[1] then xfade_len = table[1] / 1000 end
    end
    return xfade_len
end

function get_first_last_items()
    local num_of_items = count_selected_media_items()
    local first_sel_item
    local last_sel_item
    for i = 0, num_of_items - 1 do
        local item = get_selected_media_item_at(i)
        if not first_sel_item then first_sel_item = item end
        last_sel_item = item
    end
    return first_sel_item, last_sel_item
end

function mark_as_edit()
    local first_sel_item = get_selected_media_item_at(0)
    local _, src_guid = GetProjExtState(0, "ReaClassical", "temp_src_guid")
    GetSetMediaItemInfo_String(first_sel_item, "P_EXT:src_guid", src_guid, true)
    SetProjExtState(0, "ReaClassical", "temp_src_guid", "")
    local selected_items = count_selected_media_items()
    for i = 0, selected_items - 1, 1 do
        local item = get_selected_media_item_at(i)
        GetSetMediaItemInfo_String(item, "P_EXT:SD", "y", true)
        sd_snapshot.stamp(item)
    end
end

function move_to_project_tab(proj_type)
    SelectProjectInstance(proj_type)
end

function sanitize_marker_zones(zones)
    local xfade_len = return_xfade_length()
    local margin = xfade_len + 0.05
    local sel_track = GetSelectedTrack(0, 0)
    local tracks = sel_track and sd_xfade.folder_tracks(sel_track) or nil
    if not tracks then return "" end
    local positions = {}
    local num_markers = GetNumRegionsOrMarkers(0)
    for i = 0, num_markers - 1 do
        local _, _, pos, _, _, id = enum_project_markers(0, i)
        positions[id] = pos
    end
    local notes = {}
    for _, zone in ipairs(zones) do
        local pos = positions[zone.id]
        if pos then
            local removed = sd_xfade.remove_extra_overlaps(
                tracks, pos - margin, pos + margin)
            if removed > 0 then
                notes[#notes + 1] = string.format("%d near %s", removed, zone.label)
            end
        end
    end
    if #notes == 0 then return "" end
    return "Removed sliver edit(s): " .. table.concat(notes, ", ") .. "."
end

function drop_stacked_items_at_cursor(keep_first)
    local cursor = GetCursorPosition()
    local epsilon = 0.0001
    local sel_track = GetSelectedTrack(0, 0)
    local tracks = sel_track and sd_xfade.folder_tracks(sel_track) or nil
    if not tracks then return 0 end
    local track_set = {}
    for _, tr in ipairs(tracks) do track_set[tr] = true end
    local per_track = {}
    local num_sel = CountSelectedMediaItems(0)
    for i = 0, num_sel - 1 do
        local item = GetSelectedMediaItem(0, i)
        local tr = GetMediaItemTrack(item)
        if track_set[tr] then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            if pos <= cursor + epsilon and pos + len >= cursor - epsilon then
                per_track[tr] = per_track[tr] or {}
                table.insert(per_track[tr], { item = item, pos = pos })
            end
        end
    end
    local dropped = 0
    for _, entries in pairs(per_track) do
        if #entries >= 2 then
            table.sort(entries, function(a, b) return a.pos < b.pos end)
            local keeper = keep_first and entries[1].item or entries[#entries].item
            for _, entry in ipairs(entries) do
                if entry.item ~= keeper then
                    SetMediaItemSelected(entry.item, false)
                    dropped = dropped + 1
                end
            end
        end
    end
    return dropped
end

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then selected_count = selected_count + 1 end
    end
    return selected_count
end

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then return item end
            selected_count = selected_count + 1
        end
    end
    return nil
end

function move_destination_folder_to_top()
    local destination_folder = nil
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track; break
            end
        end
    end
    if not destination_folder then return end
    local destination_index = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    if destination_index > 0 then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(0, 0)
    end
end

function move_destination_folder(track_number)
    local destination_folder = nil
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track; break
            end
        end
    end
    if not destination_folder then return end
    local target_track = GetTrack(0, track_number - 1)
    if not target_track then return end
    local destination_index = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    local target_index = track_number - 1
    if destination_index ~= target_index then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(target_index, 0)
    end
end

function save_source_details()
    local item = get_selected_media_item_at(0)
    if not item then return end
    local guid = get_item_guid(item)
    if not guid or guid == "" then return end
    SetProjExtState(0, "ReaClassical", "temp_src_guid", guid)
end

function adaptive_delete()
    local sel_items = {}
    local item_count = count_selected_media_items()
    for i = 0, item_count - 1 do sel_items[#sel_items + 1] = get_selected_media_item_at(i) end

    local time_sel_start, time_sel_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local items_in_time_sel = {}

    if time_sel_end - time_sel_start > 0 then
        for _, item in ipairs(sel_items) do
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_sel = GetMediaItemInfo_Value(item, "B_UISEL") == 1
            if item_sel then
                local intersectmatches = 0
                if time_sel_start >= item_pos and time_sel_end <= item_pos + item_len then
                    intersectmatches =
                        intersectmatches + 1
                end
                if item_pos >= time_sel_start and item_pos + item_len <= time_sel_end then
                    intersectmatches =
                    intersectmatches + 1
                end
                if time_sel_start <= item_pos + item_len and time_sel_end >= item_pos + item_len then
                    intersectmatches =
                        intersectmatches + 1
                end
                if time_sel_end >= item_pos and time_sel_start < item_pos then intersectmatches = intersectmatches + 1 end
                if intersectmatches > 0 then table.insert(items_in_time_sel, item) end
            end
        end
    end

    if #items_in_time_sel > 0 then
        Main_OnCommand(40312, 0)
    else
        Main_OnCommand(40006, 0)
    end
end

function select_item_under_cursor_on_selected_track()
    Main_OnCommand(40289, 0)
    local curpos = GetCursorPosition()
    local item_count = CountMediaItems(0)
    for i = 0, item_count - 1 do
        local item = GetMediaItem(0, i)
        local track = GetMediaItem_Track(item)
        if IsTrackSelected(track) then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            if curpos >= item_pos and curpos <= item_pos + item_len then
                SetMediaItemInfo_Value(item, "B_UISEL", 1)
            end
        end
    end
end

function fix_marker_pair(id_in, id_out)
    local in_pos, out_pos, in_name, out_name
    local num_markers = GetNumRegionsOrMarkers(0)
    local total = num_markers
    for i = 0, total - 1 do
        local _, _, pos, _, name, id = enum_project_markers(0, i)
        if id == id_in then
            in_pos = pos; in_name = name
        elseif id == id_out then
            out_pos = pos; out_name = name
        end
    end
    if not in_pos or not out_pos then return end
    if out_pos < in_pos then
        DeleteProjectMarker(0, id_in, false)
        DeleteProjectMarker(0, id_out, false)
        AddProjectMarker2(0, false, out_pos, 0, in_name, id_in, 0)
        AddProjectMarker2(0, false, in_pos, 0, out_name, id_out, 0)
    end
end

function load_last_assembly_item()
    local _, item_guid = GetProjExtState(0, "ReaClassical", "LastAssemblyItem")
    return get_item_by_guid(0, item_guid)
end

function save_last_assembly_item(item)
    SetProjExtState(0, "ReaClassical", "LastAssemblyItem", get_item_guid(item))
end

function get_item_guid(item)
    if not item then return "" end
    local retval, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
    if retval then return guid else return "" end
end

function get_item_by_guid(project, guid)
    if not guid or guid == "" then return nil end
    project = project or 0
    local numItems = reaper.CountMediaItems(project)
    for i = 0, numItems - 1 do
        local item = reaper.GetMediaItem(project, i)
        local retval, itemGUID = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
        if retval and itemGUID == guid then return item end
    end
    return nil
end

function add_marker(pos, distance, track_number, label, num, color, workflow)
    DeleteProjectMarker(nil, num, false)
    local track = GetTrack(0, track_number - 1)
    local prefix = get_track_prefix(track)
    local marker_label
    if workflow == "Horizontal" then
        marker_label = label
    else
        marker_label = prefix .. ":" .. label
    end
    AddProjectMarker2(0, false, pos + distance, 0, marker_label, num, color)
    if label == "DEST-IN" then
        SetProjExtState(0, "ReaClassical", "DestInTrackNum", tostring(track_number))
    elseif label == "DEST-OUT" then
        SetProjExtState(0, "ReaClassical", "DestOutTrackNum", tostring(track_number))
    elseif label == "SOURCE-IN" then
        SetProjExtState(0, "ReaClassical", "SourceInTrackNum", tostring(track_number))
    elseif label == "SOURCE-OUT" then
        SetProjExtState(0, "ReaClassical", "SourceOutTrackNum", tostring(track_number))
    end
end

function folder_check()
    local folders = 0
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then folders = folders + 1 end
    end
    return folders
end

function get_track_prefix(track)
    if not track then track = GetSelectedTrack(0, 0) end
    if folder_check() == 0 or track == nil then return "1" end
    local folder
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        folder = track
    else
        folder = GetParentTrack(track)
    end
    if folder then
        local _, name = GetTrackName(folder)
        local prefix = name:match("^(.-):")
        if prefix then return prefix end
    end
    return tostring(math.floor(GetMediaTrackInfo_Value(folder or track, "IP_TRACKNUMBER")))
end

function save_view()
    Main_OnCommand(NamedCommandLookup("_SWS_SAVEVIEW"), 0)
    local cursor_pos = GetCursorPosition()
    local selected_items = {}
    local item_count = CountMediaItems(0)
    for i = 0, item_count - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then table.insert(selected_items, item) end
    end
    local selected_tracks = {}
    local track_count = CountSelectedTracks(0)
    for i = 0, track_count - 1 do
        table.insert(selected_tracks, GetSelectedTrack(0, i))
    end
    return cursor_pos, selected_items, selected_tracks
end

function restore_view(cursor_pos, selected_items, selected_tracks)
    Main_OnCommand(NamedCommandLookup("_SWS_RESTOREVIEW"), 0)
    SetEditCurPos(cursor_pos, false, false)
    if #selected_items > 0 then
        Main_OnCommand(40289, 0)
        for _, item in ipairs(selected_items) do
            if pcall(IsMediaItemSelected, item) then SetMediaItemSelected(item, true) end
        end
    end
    if #selected_tracks > 0 then
        Main_OnCommand(40297, 0)
        SetOnlyTrackSelected(selected_tracks[1])
        for _, track in ipairs(selected_tracks) do
            if pcall(IsTrackSelected, track) then SetTrackSelected(track, true) end
        end
    end
end

function trim_left_item_to_dest_in()
    local dest_in_pos = nil
    local num_markers = GetNumRegionsOrMarkers(0)
    for i = 0, num_markers - 1 do
        local _, _, pos, _, _, id = enum_project_markers(0, i)
        if id == 996 then
            dest_in_pos = pos; break
        end
    end
    if not dest_in_pos then return end

    local sel_track = GetSelectedTrack(0, 0)
    if not sel_track then return end
    local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local folder_start, folder_end = nil, nil
    for t = track_num, num_tracks - 1 do
        local track = GetTrack(0, t)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    if not folder_start then return end

    local ref_track = GetTrack(0, folder_start)
    local n = CountTrackMediaItems(ref_track)
    local left_item_start = nil
    for i = 0, n - 2 do
        local item_a  = GetTrackMediaItem(ref_track, i)
        local item_b  = GetTrackMediaItem(ref_track, i + 1)
        local a_start = GetMediaItemInfo_Value(item_a, "D_POSITION")
        local a_end   = a_start + GetMediaItemInfo_Value(item_a, "D_LENGTH")
        local b_start = GetMediaItemInfo_Value(item_b, "D_POSITION")
        if a_end > b_start and a_end > dest_in_pos and b_start <= dest_in_pos then
            left_item_start = a_start
            break
        end
    end
    if not left_item_start then return end

    local tolerance = 0.0001
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local nt = CountTrackMediaItems(track)
        for i = 0, nt - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            if math.abs(ipos - left_item_start) <= tolerance then
                SetMediaItemInfo_Value(item, "D_LENGTH", dest_in_pos - ipos)
                break
            end
        end
    end
end

function select_all_folder_tracks()
    local sel_track = GetSelectedTrack(0, 0)
    if not sel_track then return end
    local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local folder_start, folder_end = nil, nil
    local start_search = track_num
    if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
    for t = start_search, num_tracks - 1 do
        local tt = GetTrack(0, t)
        if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    if not folder_start then return end
    Main_OnCommand(40297, 0)
    for t = folder_start, folder_end do
        SetTrackSelected(GetTrack(0, t), true)
    end
end

function select_midpoint_peers(folder_start, folder_end)
    local num_sel = CountSelectedMediaItems(0)
    if num_sel == 0 then return end
    if not folder_start then
        local sel_track = GetSelectedTrack(0, 0)
        if not sel_track then return end
        local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
        local num_tracks = CountTracks(0)
        local start_search = track_num
        if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") ~= 1 then
            for t = track_num - 1, 0, -1 do
                local tt = GetTrack(0, t)
                if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                    start_search = t; break
                end
            end
        end
        for t = start_search, num_tracks - 1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                folder_start = t; folder_end = t
                local x = t + 1
                while x < num_tracks do
                    local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                    folder_end = x
                    if d < 0 then break end
                    x = x + 1
                end
                break
            end
        end
        if not folder_start then return end
    end
    local seed_items = {}
    for i = 0, num_sel - 1 do
        seed_items[#seed_items + 1] = GetSelectedMediaItem(0, i)
    end
    for _, ref_item in ipairs(seed_items) do
        local peers = get_folder_items_at_midpoint(ref_item, folder_start, folder_end)
        for _, peer in ipairs(peers) do
            SetMediaItemSelected(peer, true)
        end
    end
end

main()
