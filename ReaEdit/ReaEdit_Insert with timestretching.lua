--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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

local main, copy_source, split_at_dest_in, find_reference_track
local create_crossfades, adaptive_delete
local return_xfade_length, get_first_last_items, markers
local mark_as_edit, move_to_project_tab, save_source_details
local count_selected_media_items, get_selected_media_item_at
local select_item_under_cursor_on_selected_track, fix_marker_pair
local get_item_guid
local nudge_xfades_inside_dest_markers
local reposition_dest_in, reposition_dest_out
local save_ripple_state, restore_ripple_state
local get_items_at_midpoint, select_midpoint_peers
local sanitize_marker_zones, drop_stacked_items_at_cursor

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local function say(msg)
    if APIExists("osara_outputMessage") then osara_outputMessage(tostring(msg)) end
end
local sd_xfade = require("ReaEdit_SD_Crossfade_Utils")
local enum_project_markers = require("ReaEdit_Marker_Enum")

function main()
    if CountTracks(0) == 0 then return end
    PreventUIRefresh(1)
    Undo_BeginBlock()

    local initial_proj = EnumProjects(-1)

    Main_OnCommand(41121, 0)
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0)
    end

    local proj_marker_count, source_proj, dest_proj, _, _, dest_count, _, _, source_count = markers()

    move_to_project_tab(source_proj)
    local source_ripple = save_ripple_state()
    move_to_project_tab(dest_proj)
    local dest_ripple = save_ripple_state()

    local function restore_all_ripple()
        move_to_project_tab(dest_proj)
        restore_ripple_state(dest_ripple)
        move_to_project_tab(source_proj)
        restore_ripple_state(source_ripple)
        move_to_project_tab(initial_proj)
    end

    local function abort_edit()
        restore_all_ripple()
        Undo_EndBlock('S-D edit with timestretching', 0)
        PreventUIRefresh(-1)
    end

    if proj_marker_count == 1 then
        MB("Only one S-D project marker was found."
            .. "\nUse zero for regular single project S-D editing"
            .. "\nor use two for multi-tab S-D editing.", "Source-Destination Edit", 0)
        abort_edit()
        return
    end

    if proj_marker_count == -1 then
        MB(
            "Source or destination markers should be paired with the " ..
            "corresponding source or destination project marker.",
            "Multi-tab Source-Destination Edit", 0)
        abort_edit()
        return
    end

    local sliver_note = ""
    if dest_count + source_count == 4 then
        local selected_items = {}
        move_to_project_tab(source_proj)
        fix_marker_pair(998, 999)
        local xfade_len = return_xfade_length()
        local total_selected, parent_selected = copy_source(xfade_len)
        if total_selected == 0 then
            Main_OnCommand(40020, 0)
            MB("Please make sure there is material to copy between your source markers.",
                "4-point with timestretching", 0)
            abort_edit()
            return
        end
        Main_OnCommand(40020, 0)
        move_to_project_tab(dest_proj)
        fix_marker_pair(996, 997)
        GoToMarker(0, 996, false)
        Main_OnCommand(40296, 0)
        sliver_note = sanitize_marker_zones({
            { id = 996, label = "DEST-IN" },
            { id = 997, label = "DEST-OUT" },
        })
        nudge_xfades_inside_dest_markers()
        split_at_dest_in()
        Main_OnCommand(40625, 0)
        GoToMarker(0, 997, false)
        Main_OnCommand(40626, 0)
        Main_OnCommand(40718, 0)
        select_midpoint_peers()
        Main_OnCommand(40630, 0)
        Main_OnCommand(40309, 0)
        adaptive_delete()
        Main_OnCommand(40289, 0)

        local state = GetToggleCommandState(1156)
        if state == 1 then
            Main_OnCommand(1156, 0)
        end
        if parent_selected > 1 then
            SetEditCurPos(GetCursorPosition() - xfade_len * 15, false, false)
        end
        Main_OnCommand(42398, 0)
        GoToMarker(0, 996, false)
        if parent_selected > 1 then
            SetEditCurPos(GetCursorPosition() - xfade_len * 15, false, false)
        end
        Main_OnCommand(40625, 0)

        for i = 0, total_selected - 1, 1 do
            selected_items[i] = get_selected_media_item_at(i)
        end
        Main_OnCommand(40289, 0)
        local first_item = selected_items[0]

        local item_color = first_item and GetMediaItemInfo_Value(first_item, "I_CUSTOMCOLOR") or 0

        for _, v in pairs(selected_items) do
            SetMediaItemSelected(v, true)
            SetMediaItemInfo_Value(v, "C_LOCK", 0)
        end
        if parent_selected == 1 then
            Main_OnCommand(41206, 0)
        else
            Main_OnCommand(40362, 0)
            GoToMarker(0, 996, false)
            Main_OnCommand(40511, 0)
            Main_OnCommand(40625, 0)
            Main_OnCommand(41206, 0)
        end
        Main_OnCommand(40032, 0)
        mark_as_edit()
        local num_of_selected = count_selected_media_items()
        for i = 0, num_of_selected - 1, 1 do
            local item = get_selected_media_item_at(i)
            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", item_color)
        end

        state = GetToggleCommandState(1156)
        if state == 0 then
            Main_OnCommand(1156, 0)
        end

        Main_OnCommand(40020, 0)
        local first_pasted_item = get_selected_media_item_at(0)
        local shortened_in, shortened_out, applied_in, applied_out = create_crossfades(xfade_len)
        Main_OnCommand(40289, 0)
        if first_pasted_item then SetMediaItemSelected(first_pasted_item, true) end
        restore_all_ripple()

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
        if warning and not APIExists("osara_outputMessage") then
            MB(warning, "Insert with timestretching", 0)
        end
        local completion = "Edit completed with timestretching"
        if warning then completion = completion .. ". " .. warning end
        say(completion)
    else
        MB("Please add 4 markers: DEST-IN, DEST-OUT, SOURCE-IN and SOURCE-OUT",
            "Insert with timestretching", 0)
        restore_all_ripple()
    end

    Undo_EndBlock('S-D edit with timestretching', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()

    if sliver_note ~= "" then
        MB(sliver_note, "Insert with timestretching", 0)
    end
end

function copy_source(xfade_len)
    SetCursorContext(1, nil)
    Main_OnCommand(40311, 0)
    Main_OnCommand(40289, 0)
    GoToMarker(0, 998, false)
    Main_OnCommand(40625, 0)
    GoToMarker(0, 999, false)
    Main_OnCommand(40626, 0)
    local range_start, range_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local ref_track = find_reference_track(range_start, range_end)
    if ref_track then
        SetOnlyTrackSelected(ref_track)
    else
        Main_OnCommand(40297, 0)
    end
    Main_OnCommand(40718, 0)
    GoToMarker(0, 998, false)
    drop_stacked_items_at_cursor(true)
    GoToMarker(0, 999, false)
    drop_stacked_items_at_cursor(false)
    save_source_details()
    local parent_track_selected_items = count_selected_media_items()
    select_midpoint_peers()
    if parent_track_selected_items > 1 then
        local loop_start, loop_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
        local new_loop_start = loop_start - (xfade_len * 15)
        GetSet_LoopTimeRange(true, false, new_loop_start, loop_end, false)
    end
    local total_selected_items = count_selected_media_items()
    Main_OnCommand(41383, 0)
    Main_OnCommand(40289, 0)
    return total_selected_items, parent_track_selected_items
end

function find_reference_track(range_start, range_end)
    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        for i = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, i)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            if pos < range_end and pos + len > range_start then return track end
        end
    end
    return nil
end

function get_items_at_midpoint(ref_item)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    for t = 0, CountTracks(0) - 1 do
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
                local peers = get_items_at_midpoint(second_item)
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

function create_crossfades(xfade_len)
    local first_sel_item, last_sel_item = get_first_last_items()

    Main_OnCommand(40289, 0)
    SetMediaItemSelected(first_sel_item, true)
    select_midpoint_peers()
    local in_items = {}
    for i = 0, count_selected_media_items() - 1 do
        in_items[#in_items + 1] = get_selected_media_item_at(i)
    end
    local in_neighbors = sd_xfade.get_adjacent_neighbors(in_items, "left")
    local applied_in, shortened_in = sd_xfade.create_crossfade(in_items, in_neighbors, "left", xfade_len)
    reposition_dest_in(in_items[1], applied_in)

    Main_OnCommand(40289, 0)
    SetMediaItemSelected(last_sel_item, true)
    select_midpoint_peers()
    local out_items = {}
    for i = 0, count_selected_media_items() - 1 do
        out_items[#out_items + 1] = get_selected_media_item_at(i)
    end
    local out_neighbors = sd_xfade.get_adjacent_neighbors(out_items, "right")
    local applied_out, shortened_out = sd_xfade.create_crossfade(out_items, out_neighbors, "right", xfade_len)
    reposition_dest_out(out_items[1])

    Main_OnCommand(40912, 0)
    Main_OnCommand(40289, 0)
    return shortened_in, shortened_out, applied_in, applied_out
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
    local _, input = GetProjExtState(0, "ReaEdit", "Preferences")
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

    while true do
        local proj = EnumProjects(num)
        if proj == nil then break end
        local num_markers = GetNumRegionsOrMarkers(proj)
        for i = 0, num_markers - 1, 1 do
            local _, _, pos, _, label, _ = enum_project_markers(proj, i)

            if label == "DEST-IN" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[1] = pos
            elseif label == "DEST-OUT" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[2] = pos
            elseif label == "SOURCE-IN" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[3] = pos
            elseif label == "SOURCE-OUT" then
                sd_markers[label].count = 1; sd_markers[label].proj = proj; pos_table[4] = pos
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
        source_in, source_out, source_count, pos_table
end

function mark_as_edit()
    local first_sel_item = get_selected_media_item_at(0)
    local _, src_guid = GetProjExtState(0, "ReaEdit", "temp_src_guid")
    GetSetMediaItemInfo_String(first_sel_item, "P_EXT:src_guid", src_guid, true)
    SetProjExtState(0, "ReaEdit", "temp_src_guid", "")
    local selected_items = count_selected_media_items()
    for i = 0, selected_items - 1, 1 do
        local item = get_selected_media_item_at(i)
        GetSetMediaItemInfo_String(item, "P_EXT:SD", "y", true)
    end
end

function move_to_project_tab(proj_type)
    SelectProjectInstance(proj_type)
end

function sanitize_marker_zones(zones)
    local xfade_len = return_xfade_length()
    local margin = xfade_len + 0.05
    local tracks = sd_xfade.all_tracks()
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
    local tracks = sd_xfade.all_tracks()
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

function save_source_details()
    local item = get_selected_media_item_at(0)
    if not item then return end
    local guid = get_item_guid(item)
    if not guid or guid == "" then return end
    SetProjExtState(0, "ReaEdit", "temp_src_guid", guid)
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

function get_item_guid(item)
    if not item then return "" end
    local retval, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
    if retval then return guid else return "" end
end

function nudge_xfades_inside_dest_markers()
    local xfade_len = return_xfade_length()
    local epsilon = 0.0001
    local dest_in_pos, dest_out_pos = nil, nil
    local num_markers = GetNumRegionsOrMarkers(0)
    for i = 0, num_markers - 1 do
        local _, _, pos, _, _, id = enum_project_markers(0, i)
        if id == 996 then dest_in_pos = pos end
        if id == 997 then dest_out_pos = pos end
    end
    if not dest_in_pos or not dest_out_pos then return end

    local in_zone_left   = dest_in_pos - xfade_len
    local in_zone_right  = dest_in_pos
    local out_zone_left  = dest_out_pos
    local out_zone_right = dest_out_pos + xfade_len

    local ref_track
    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        if CountTrackMediaItems(track) > 0 then ref_track = track; break end
    end
    if not ref_track then return end

    local function find_overlap_in_zone(zone_left, zone_right)
        local n = CountTrackMediaItems(ref_track)
        for i = 0, n - 2 do
            local item_a  = GetTrackMediaItem(ref_track, i)
            local item_b  = GetTrackMediaItem(ref_track, i + 1)
            local a_start = GetMediaItemInfo_Value(item_a, "D_POSITION")
            local a_end   = a_start + GetMediaItemInfo_Value(item_a, "D_LENGTH")
            local b_start = GetMediaItemInfo_Value(item_b, "D_POSITION")
            if a_end > b_start then
                if b_start < zone_right and a_end > zone_left then
                    return item_a, item_b, a_end - b_start
                end
            end
        end
        return nil, nil, nil
    end

    local function move_xfade_boundaries(ref_a, ref_b, new_a_end, new_b_start)
        local peers_a = get_items_at_midpoint(ref_a)
        local peers_b = get_items_at_midpoint(ref_b)
        for _, item in ipairs(peers_a) do
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_LENGTH", new_a_end - ipos)
        end
        for _, item in ipairs(peers_b) do
            local old_end = GetMediaItemInfo_Value(item, "D_POSITION")
                + GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_POSITION", new_b_start)
            SetMediaItemInfo_Value(item, "D_LENGTH", old_end - new_b_start)
        end
    end

    local a, b, _ = find_overlap_in_zone(in_zone_left, in_zone_right)
    if a and b then
        local new_b_start = dest_in_pos + epsilon
        local new_a_end   = new_b_start + xfade_len
        move_xfade_boundaries(a, b, new_a_end, new_b_start)
    end

    local c, d, _ = find_overlap_in_zone(out_zone_left, out_zone_right)
    if c and d then
        local new_c_end   = dest_out_pos - epsilon
        local new_d_start = new_c_end - xfade_len
        move_xfade_boundaries(c, d, new_c_end, new_d_start)
    end
end

function reposition_dest_out(item)
    local num_markers = GetNumRegionsOrMarkers(0)
    local dest_out_name, dest_out_color = nil, 0
    for i = 0, num_markers - 1 do
        local _, _, _, _, name, id, color = enum_project_markers(0, i)
        if id == 997 then
            dest_out_name = name; dest_out_color = color; break
        end
    end
    if not dest_out_name then return end
    if not item then return end
    local pos = GetMediaItemInfo_Value(item, "D_POSITION") + GetMediaItemInfo_Value(item, "D_LENGTH")
    DeleteProjectMarker(0, 997, false)
    AddProjectMarker2(0, false, pos, 0, dest_out_name, 997, dest_out_color)
end

function reposition_dest_in(item, applied_len)
    local num_markers = GetNumRegionsOrMarkers(0)
    local dest_in_name, dest_in_color = nil, 0
    for i = 0, num_markers - 1 do
        local _, _, _, _, name, id, color = enum_project_markers(0, i)
        if id == 996 then
            dest_in_name = name; dest_in_color = color; break
        end
    end
    if not dest_in_name then return end
    if not item then return end
    local pos = GetMediaItemInfo_Value(item, "D_POSITION") + applied_len
    DeleteProjectMarker(0, 996, false)
    AddProjectMarker2(0, false, pos, 0, dest_in_name, 996, dest_in_color)
end

function select_midpoint_peers()
    local seed_items = {}
    local num_sel = CountSelectedMediaItems(0)
    for i = 0, num_sel - 1 do
        seed_items[#seed_items + 1] = GetSelectedMediaItem(0, i)
    end
    for _, ref_item in ipairs(seed_items) do
        for _, item in ipairs(get_items_at_midpoint(ref_item)) do
            SetMediaItemSelected(item, true)
        end
    end
end

main()
