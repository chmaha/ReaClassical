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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local parent_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local humanize_track_name = require("ReaClassical_Track_Naming")
local pan_from_name = require("ReaClassical_Pan_From_Name")
local mixer_core = require("ReaClassical_Mixer_Core")
local spare_track = require("ReaClassical_Spare_Track")

local M = {}

local workflow = ""

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local rec_input_description, rec_input_label

function M.try_project_setup(cmd)
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf
    if cmd == "convert=h" then
        if workflow == "Horizontal" then
            say("The project already uses a Horizontal workflow")
            return true
        end
        mixer_core.consolidate_folders_to_first()
        DeleteProjectMarker(nil, 996, false)
        DeleteProjectMarker(nil, 997, false)
        DeleteProjectMarker(nil, 998, false)
        DeleteProjectMarker(nil, 999, false)
        _G.RC_SCRIPT_ARGS = {}
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
        _G.RC_SCRIPT_ARGS = nil
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        if CountMediaItems(0) > 0 then
            _G.RC_SCRIPT_ARGS = { silent = true }
            dofile(parent_path .. "ReaClassical_Auto-color project.lua")
            _G.RC_SCRIPT_ARGS = nil
        end
        say("Conversion to Horizontal workflow complete")
        return true
    end

    if cmd == "convert=v" then
        if workflow == "Vertical" then
            say("The project already uses a Vertical workflow")
            return true
        end
        DeleteProjectMarker(nil, 996, false)
        DeleteProjectMarker(nil, 997, false)
        DeleteProjectMarker(nil, 998, false)
        DeleteProjectMarker(nil, 999, false)
        _G.RC_SCRIPT_ARGS = {}
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        _G.RC_SCRIPT_ARGS = nil
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        if CountMediaItems(0) > 0 then
            _G.RC_SCRIPT_ARGS = { silent = true }
            dofile(parent_path .. "ReaClassical_Auto-color project.lua")
            _G.RC_SCRIPT_ARGS = nil
        end
        say("Conversion to Vertical workflow complete")
        return true
    end

    return false
end

local function get_folder_position_track(folder, position)
    if position == 1 then
        return folder.parent
    end
    return folder.tracks[position - 1]
end

local function auto_assign_inputs(start_input)
    local mixer_tracks = mixer_core.get_mixer_tracks()
    local track_table = mixer_core.get_track_table()
    if not track_table[1] then
        say("No folders found")
        return
    end

    local max_inputs = GetNumAudioInputs()
    local input_channel = start_input - 1

    for i = 1, #mixer_tracks do
        local mixer_track = mixer_tracks[i]
        local d_track = get_folder_position_track(track_table[1], i)
        if d_track then
            local _, raw_name = GetSetMediaTrackInfo_String(mixer_track, "P_NAME", "", false)
            local track_name = raw_name:match("^M:(.*)") or raw_name
            local lower_name = track_name:lower()

            local is_pair = false
            for _, word in ipairs(pan_from_name.pair_words) do
                if lower_name:match("%s" .. word .. "$") or lower_name:match(word .. "$") then
                    is_pair = true
                    break
                end
            end

            pan_from_name.apply_pan_from_name(mixer_track, track_name)

            if input_channel < max_inputs then
                if is_pair and (input_channel + 1 < max_inputs) then
                    SetMediaTrackInfo_Value(d_track, "I_RECINPUT", 1024 + input_channel)
                    input_channel = input_channel + 2
                else
                    SetMediaTrackInfo_Value(d_track, "I_RECINPUT", input_channel)
                    input_channel = input_channel + 1
                end
            else
                SetMediaTrackInfo_Value(d_track, "I_RECINPUT", -1)
            end
        end
    end

    if workflow == "Vertical" then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    end

    say("Inputs auto-assigned starting at input " .. start_input)
end

local function hw_input_exists(start_ch, is_stereo)
    local max_inputs = GetNumAudioInputs()
    if start_ch < 1 or start_ch > max_inputs then return false end
    if is_stereo and start_ch + 1 > max_inputs then return false end
    return true
end

local function position_name(position)
    local track = mixer_core.get_mixer_tracks()[position]
    if not track then return "Track " .. position .. " of the folder" end
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local rest = name:match("^M:(.*)$")
    if rest and rest ~= "" then return rest end
    return "Track " .. position .. " of the folder"
end

function M.try_input_config(cmd)
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf
    local mono_pos, mono_input = cmd:match("^(%d+)=mono,(%d+)$")
    if mono_pos then
        local n = tonumber(mono_pos)
        local mixer_tracks = mixer_core.get_mixer_tracks()
        if not mixer_tracks[n] then
            say("There are only " .. #mixer_tracks .. " tracks per folder")
            return true
        end
        local input_num = tonumber(mono_input)
        if not hw_input_exists(input_num, false) then
            say("Hardware input " .. input_num .. " does not exist")
            return true
        end
        local input_ch = input_num - 1
        local track_table = mixer_core.get_track_table()
        for _, folder in ipairs(track_table) do
            local track = get_folder_position_track(folder, n)
            if track then
                SetMediaTrackInfo_Value(track, "I_RECINPUT", input_ch)
            end
        end
        say(position_name(n) .. " set to mono, input " .. input_num)
        return true
    end

    local stereo_pos, stereo_input = cmd:match("^(%d+)=stereo,(%d+)$")
    if stereo_pos then
        local n = tonumber(stereo_pos)
        local mixer_tracks = mixer_core.get_mixer_tracks()
        if not mixer_tracks[n] then
            say("There are only " .. #mixer_tracks .. " tracks per folder")
            return true
        end
        local start_ch = tonumber(stereo_input)
        if not hw_input_exists(start_ch, true) then
            say("Hardware inputs " .. start_ch .. "/" .. (start_ch + 1) .. " do not exist")
            return true
        end
        local track_table = mixer_core.get_track_table()
        for _, folder in ipairs(track_table) do
            local track = get_folder_position_track(folder, n)
            if track then
                SetMediaTrackInfo_Value(track, "I_RECINPUT", 1024 + (start_ch - 1))
            end
        end
        say(position_name(n) .. " set to stereo, input " .. start_ch .. "/" .. (start_ch + 1))
        return true
    end

    local rd_pos, rd_val = cmd:match("^(%d+)=([yn])$")
    if rd_pos then
        local mixer_tracks = mixer_core.get_mixer_tracks()
        local track = mixer_tracks[tonumber(rd_pos)]
        if track then
            GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", rd_val == "n" and "y" or "", true)
            say(position_name(tonumber(rd_pos)) .. " record " .. (rd_val == "y" and "enabled" or "disabled"))
        else
            say("No mixer track at position " .. rd_pos)
        end
        return true
    end

    local rd_all = cmd:match("^%*=([yn])$")
    if rd_all then
        for _, track in ipairs(mixer_core.get_mixer_tracks()) do
            GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", rd_all == "n" and "y" or "", true)
        end
        say("Record " .. (rd_all == "y" and "enabled" or "disabled") .. " for all tracks")
        return true
    end

    local rd_query_str = cmd:match("^([%d,%-%*%s]+)input%?$")
    if rd_query_str then
        local tracks, err = mixer_core.resolve_target_list((rd_query_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        for _, track in ipairs(tracks) do
            local prefix = mixer_core.label_prefix(mixer_core.query_label(track, #tracks), " ")
            local _, disabled = GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", "", false)
            local source = mixer_core.get_source_for_mixer(track) or track
            say(prefix .. rec_input_description(source)
                .. ", record: " .. (disabled == "y" and "disabled" or "enabled"))
        end
        return true
    end

    if cmd == "ai" then
        auto_assign_inputs(1)
        return true
    end

    local ai_start = cmd:match("^ai=(%d+)$")
    if ai_start then
        auto_assign_inputs(tonumber(ai_start))
        return true
    end

    return false
end

local function resolve_fx_index(track, selector)
    local fx_count = TrackFX_GetCount(track)
    local n = tonumber(selector)
    if n then
        if n >= 1 and n <= fx_count then return n - 1 end
        return nil, "No FX at position " .. selector
    end
    local lower = selector:lower()
    for i = 0, fx_count - 1 do
        local _, fx_name = TrackFX_GetFXName(track, i, "")
        if fx_name:lower():find(lower, 1, true) then
            return i
        end
    end
    return nil, "FX not found: " .. selector
end
local function move_mixer_track(n, direction)
    local mixer_tracks = mixer_core.get_mixer_tracks()
    local target = (direction == "down") and (n + 1) or (n - 1)
    if target < 1 or target > #mixer_tracks then
        return false
    end

    local from_track = mixer_tracks[n]

    local before_track
    if target < n then
        before_track = mixer_tracks[target]
    elseif target < #mixer_tracks then
        before_track = mixer_tracks[target + 1]
    else
        before_track = nil
    end

    Main_OnCommand(40297, 0)
    SetTrackSelected(from_track, true)

    local before_idx
    if before_track then
        before_idx = GetMediaTrackInfo_Value(before_track, "IP_TRACKNUMBER") - 1
    else
        before_idx = CountTracks(0)
    end
    ReorderSelectedTracks(before_idx, 0)

    local _, _, folder_count = mixer_core.get_track_table()
    if folder_count > 1 then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    else
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
    end
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    return true
end

function M.try_reorder(cmd)
    local positions_str, count_str = cmd:match("^mv([%d,%-%s]+)u(%d*)$")
    local direction = "up"
    if not positions_str then
        positions_str, count_str = cmd:match("^mv([%d,%-%s]+)d(%d*)$")
        direction = "down"
    end
    if not positions_str then return false end

    local mixer_tracks = mixer_core.get_mixer_tracks()
    local positions = mixer_core.expand_index_list(positions_str, #mixer_tracks)
    if #positions == 0 then return false end
    table.sort(positions)

    for i = 2, #positions do
        if positions[i] ~= positions[i - 1] + 1 then
            say("Only a contiguous block of tracks can be moved together")
            return true
        end
    end

    local count = tonumber(count_str) or 1
    if count < 1 then count = 1 end

    local names = {}
    for _, p in ipairs(positions) do
        local track = mixer_tracks[p]
        local _, name = track and GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        table.insert(names, humanize_track_name(name))
    end

    local p1, pk = positions[1], positions[#positions]
    local moved = 0

    for _ = 1, count do
        if direction == "up" then
            if p1 - 1 < 1 then break end
            for n = p1, pk do move_mixer_track(n, "up") end
            p1, pk = p1 - 1, pk - 1
        else
            if pk + 1 > #mixer_tracks then break end
            for n = pk, p1, -1 do move_mixer_track(n, "down") end
            p1, pk = p1 + 1, pk + 1
        end
        moved = moved + 1
    end

    if moved == 0 then
        say("Cannot move " .. table.concat(names, ", ") .. " " .. direction)
    else
        local pos_str = (p1 == pk) and tostring(p1) or (p1 .. "-" .. pk)
        say(table.concat(names, ", ") .. " moved to position " .. pos_str)
    end
    return true
end

local function add_mixer_track(name)
    local track_table, _, folder_count, tracks_per_group = mixer_core.get_track_table()
    if folder_count == 0 or not track_table[1] then
        say("No folders found")
        return
    end

    if spare_track.activate() then
        local mixer_tracks = mixer_core.get_mixer_tracks()
        local new_position = #mixer_tracks
        local final_name = name or ("Track " .. new_position)
        mixer_core.rename_mixer_position(mixer_tracks, new_position, final_name)
        if folder_count > 1 then
            dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        else
            dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
        end
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        say("Track added: " .. final_name)
        return
    end

    local mixer_insert_idx = (folder_count + 1) * tracks_per_group
    InsertTrackAtIndex(mixer_insert_idx, true)
    local new_mixer_track = GetTrack(0, mixer_insert_idx)
    SetMediaTrackInfo_Value(new_mixer_track, "I_FOLDERDEPTH", 0)
    SetMediaTrackInfo_Value(new_mixer_track, "I_RECINPUT", -1)
    GetSetMediaTrackInfo_String(new_mixer_track, "P_EXT:mixer", "y", true)
    GetSetMediaTrackInfo_String(new_mixer_track, "P_EXT:mix_order", tostring(tracks_per_group + 1), true)
    if APIExists("clara_outputMessage") then
        SetMediaTrackInfo_Value(new_mixer_track, "B_SHOWINTCP", 1)
    end

    local folder_colors = {}
    for f = 0, folder_count - 1 do
        local folder = track_table[f + 1]
        local folder_color = GetTrackColor(folder.parent)
        if folder_color == 0 and folder.tracks[1] then
            folder_color = GetTrackColor(folder.tracks[1])
        end
        folder_colors[f] = folder_color
    end

    for f = folder_count - 1, 0, -1 do
        local insert_idx = (f + 1) * tracks_per_group
        local last_child_idx = insert_idx - 1
        InsertTrackAtIndex(insert_idx, true)
        local new_track = GetTrack(0, insert_idx)
        SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", -1)
        SetMediaTrackInfo_Value(new_track, "I_RECINPUT", -1)
        local last_child = GetTrack(0, last_child_idx)
        SetMediaTrackInfo_Value(last_child, "I_FOLDERDEPTH", 0)
        if folder_colors[f] ~= 0 then
            SetTrackColor(new_track, folder_colors[f])
        end
        if f == 0 then
            GetSetMediaTrackInfo_String(new_track, "P_EXT:Destination", "y", true)
        else
            GetSetMediaTrackInfo_String(new_track, "P_EXT:Source", "y", true)
        end
    end

    local mixer_tracks = mixer_core.get_mixer_tracks()
    local new_position = #mixer_tracks
    local final_name = name or ("Track " .. new_position)
    mixer_core.rename_mixer_position(mixer_tracks, new_position, final_name)

    if folder_count > 1 then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    else
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
    end
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    say("Track added: " .. final_name)
end

local function remove_mixer_track(n)
    local _, _, folder_count, tracks_per_group = mixer_core.get_track_table()
    local child_count = tracks_per_group - 1
    local track_idx = n - 1

    if folder_count == 0 then
        say("No folders found")
        return
    end
    if track_idx <= 0 or track_idx > child_count then
        say("Cannot remove mixer track " .. n)
        return
    end
    if tracks_per_group == 2 then
        if spare_track.has_spares() then
            say("Already a single-track project")
            return
        end
        local removed = mixer_core.get_mixer_tracks()[n]
        local _, removed_name = GetSetMediaTrackInfo_String(removed, "P_NAME", "", false)
        removed_name = humanize_track_name(removed_name)
        spare_track.retire_second_track(true)
        if folder_count > 1 then
            dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        else
            dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
        end
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        say("Track removed: " .. removed_name .. ". Now a single-track project")
        return
    end

    local removed_track = mixer_core.get_mixer_tracks()[n]
    local _, removed_name = GetSetMediaTrackInfo_String(removed_track, "P_NAME", "", false)
    removed_name = humanize_track_name(removed_name)

    if track_idx == child_count then
        move_mixer_track(n, "up")
        track_idx = track_idx - 1
        n = n - 1
    end

    local similar_tracks = {}
    for i = track_idx + (folder_count - 1) * tracks_per_group, track_idx, -tracks_per_group do
        table.insert(similar_tracks, i)
    end
    for _, idx in ipairs(similar_tracks) do
        DeleteTrack(GetTrack(0, idx))
    end

    local mixer_location = (folder_count * (tracks_per_group - 1)) + track_idx
    DeleteTrack(GetTrack(0, mixer_location))

    if folder_count > 1 then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    else
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
    end
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    say("Track removed: " .. removed_name)
end

function M.try_add_remove(cmd)
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf
    local add_name = cmd:match("^add=(.+)$")
    if cmd == "add" or add_name then
        add_mixer_track(add_name and trim(add_name) or nil)
        return true
    end

    local rm_n = cmd:match("^rm(%d+)$")
    if rm_n then
        remove_mixer_track(tonumber(rm_n))
        return true
    end

    local aux_name = cmd:match("^add@=(.+)$")
    if cmd == "add@" or aux_name then
        dofile(script_path .. "ReaClassical_Add Aux.lua")
        local list = mixer_core.get_special_tracks_by_type("aux")
        local info = list[#list]
        if info then
            if aux_name then
                GetSetMediaTrackInfo_String(info.track, "P_NAME", "@" .. trim(aux_name), true)
            end
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            say("Aux added: " .. humanize_track_name(name))
        end
        return true
    end

    local sub_name = cmd:match("^add#=(.+)$")
    if cmd == "add#" or sub_name then
        dofile(script_path .. "ReaClassical_Add Submix.lua")
        local list = mixer_core.get_special_tracks_by_type("submix")
        local info = list[#list]
        if info then
            if sub_name then
                GetSetMediaTrackInfo_String(info.track, "P_NAME", "#" .. trim(sub_name), true)
            end
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            say("Submix added: " .. humanize_track_name(name))
        end
        return true
    end

    local rm_aux = cmd:match("^rm@(%d*)$")
    if rm_aux then
        local info, err = mixer_core.resolve_special_index(mixer_core.get_special_tracks_by_type("aux"), rm_aux, "aux", "@")
        if info then
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            DeleteTrack(info.track)
            say("Aux removed: " .. humanize_track_name(name))
        else
            say(err)
        end
        return true
    end

    local rm_sub = cmd:match("^rm#(%d*)$")
    if rm_sub then
        local info, err = mixer_core.resolve_special_index(mixer_core.get_special_tracks_by_type("submix"), rm_sub, "submix", "#")
        if info then
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            DeleteTrack(info.track)
            say("Submix removed: " .. humanize_track_name(name))
        else
            say(err)
        end
        return true
    end

    local lb_input = cmd:match("^addlb=(%d+)$")
    if lb_input then
        local existing = mixer_core.get_special_tracks_by_type("listenback")
        if #existing > 0 then
            SetMediaTrackInfo_Value(existing[1].track, "I_RECINPUT", tonumber(lb_input) - 1)
            say("Listenback input set to " .. lb_input)
            return true
        end

        local insert_idx = CountTracks(0)
        InsertTrackAtIndex(insert_idx, false)
        local lb_track = GetTrack(0, insert_idx)

        GetSetMediaTrackInfo_String(lb_track, "P_EXT:listenback", "y", true)
        GetSetMediaTrackInfo_String(lb_track, "P_NAME", "LISTENBACK", true)
        SetMediaTrackInfo_Value(lb_track, "I_RECINPUT", tonumber(lb_input) - 1)
        SetMediaTrackInfo_Value(lb_track, "I_RECMON", 1)
        SetMediaTrackInfo_Value(lb_track, "I_RECARM", 1)
        SetMediaTrackInfo_Value(lb_track, "I_RECMODE", 2)
        SetMediaTrackInfo_Value(lb_track, "B_MAINSEND", 1)
        SetMediaTrackInfo_Value(lb_track, "B_SHOWINTCP", 0)
        SetMediaTrackInfo_Value(lb_track, "B_SHOWINMIXER", 1)
        SetMediaTrackInfo_Value(lb_track, "D_VOL", 1.0)

        local fx_idx = TrackFX_AddByName(lb_track, "ListenbackMicMonitor", false, -1)
        if fx_idx < 0 then
            TrackFX_AddByName(lb_track, "JS:ListenbackMicMonitor", false, -1)
        end

        say("Listenback track added, input " .. lb_input)
        return true
    end

    if cmd == "rmlb" then
        local lb_list = mixer_core.get_special_tracks_by_type("listenback")
        if #lb_list == 0 then
            say("No listenback track found")
            return true
        end
        DeleteTrack(lb_list[1].track)
        say("Listenback track removed")
        return true
    end

    local rm_ref = cmd:match("^rmref(%d*)$")
    if rm_ref then
        local info, err = mixer_core.resolve_special_index(mixer_core.get_special_tracks_by_type("reference"), rm_ref, "REF", "")
        if info then
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            DeleteTrack(info.track)
            say("Reference track removed: " .. humanize_track_name(name))
        else
            say(err)
        end
        return true
    end

    if cmd == "addrt" then
        dofile(script_path .. "ReaClassical_Add RoomTone Track.lua")
        return true
    end

    if cmd == "rmrt" then
        local rt_list = mixer_core.get_special_tracks_by_type("roomtone")
        if #rt_list == 0 then
            say("No RoomTone track found")
            return true
        end
        DeleteTrack(rt_list[1].track)
        say("RoomTone track removed")
        return true
    end

    if cmd == "addlive" then
        local live_list = mixer_core.get_special_tracks_by_type("live")
        if #live_list > 0 then
            say("A LIVE track already exists. Use rmlive to remove it first.")
            return true
        end
        local rcmaster, rcmaster_index
        for i = 0, CountTracks(0) - 1 do
            local t = GetTrack(0, i)
            local _, rcm_state = GetSetMediaTrackInfo_String(t, "P_EXT:rcmaster", "", false)
            if mixer_core.trackname_check(t, "^RCMASTER") or rcm_state == "y" then
                rcmaster = t
                rcmaster_index = i
                break
            end
        end
        if not rcmaster then
            say("Error: no RCMASTER track found")
            return true
        end
        Undo_BeginBlock()
        InsertTrackAtIndex(rcmaster_index + 1, true)
        local live_track = GetTrack(0, rcmaster_index + 1)
        GetSetMediaTrackInfo_String(live_track, "P_NAME", "LIVE", true)
        CreateTrackSend(rcmaster, live_track)
        SetMediaTrackInfo_Value(live_track, "B_MAINSEND", 1)
        GetSetMediaTrackInfo_String(live_track, "P_EXT:live", "y", true)
        SetMediaTrackInfo_Value(live_track, "I_RECMODE", 3)
        SetMediaTrackInfo_Value(live_track, "I_RECINPUT", -1)
        SetMediaTrackInfo_Value(live_track, "I_RECMODE_FLAGS", 2)
        SetTrackColor(live_track, require("ReaClassical_Colors_Table").live)
        if workflow == "Vertical" then
            dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        else
            dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
        end
        Undo_EndBlock("Add Live Bounce Track", 0)
        say("Live bounce track added")
        return true
    end

    if cmd == "rmlive" then
        local live_list = mixer_core.get_special_tracks_by_type("live")
        if #live_list == 0 then
            say("No LIVE track found")
            return true
        end
        DeleteTrack(live_list[1].track)
        say("LIVE track removed")
        return true
    end

    local addpb_n = cmd:match("^addpb=(%d+)$")
    if addpb_n then
        local hw_first = tonumber(addpb_n)
        local pb_list = mixer_core.get_special_tracks_by_type("playback")
        if #pb_list > 0 then
            local pb_track = pb_list[1].track
            if GetTrackNumSends(pb_track, 1) > 0 then
                SetTrackSendInfo_Value(pb_track, 1, 0, "I_DSTCHAN", hw_first - 1)
                say("Playback hardware output set to " .. hw_first .. "/" .. (hw_first + 1))
            else
                say("Playback track has no hardware output")
            end
            return true
        end
        local rcmaster, rcmaster_index
        for i = 0, CountTracks(0) - 1 do
            local t = GetTrack(0, i)
            local _, rcm_state = GetSetMediaTrackInfo_String(t, "P_EXT:rcmaster", "", false)
            if mixer_core.trackname_check(t, "^RCMASTER") or rcm_state == "y" then
                rcmaster = t
                rcmaster_index = i
                break
            end
        end
        if not rcmaster then
            say("Error: no RCMASTER track found")
            return true
        end
        Undo_BeginBlock()
        InsertTrackAtIndex(rcmaster_index + 1, true)
        local pb_track = GetTrack(0, rcmaster_index + 1)
        GetSetMediaTrackInfo_String(pb_track, "P_NAME", "PLAYBACK", true)
        GetSetMediaTrackInfo_String(pb_track, "P_EXT:playback", "y", true)
        CreateTrackSend(rcmaster, pb_track)
        SetMediaTrackInfo_Value(pb_track, "B_MAINSEND", 0)
        local hw_idx = GetTrackNumSends(pb_track, 1)
        CreateTrackSend(pb_track, nil)
        SetTrackSendInfo_Value(pb_track, 1, hw_idx, "I_DSTCHAN", hw_first - 1)
        SetTrackSendInfo_Value(pb_track, 1, hw_idx, "I_SRCCHAN", 0)
        SetMediaTrackInfo_Value(pb_track, "B_MUTE", 1)
        SetTrackColor(pb_track, require("ReaClassical_Colors_Table").playback)
        SetMediaTrackInfo_Value(pb_track, "B_SHOWINTCP", 0)
        SetMediaTrackInfo_Value(pb_track, "B_SHOWINMIXER", 1)
        if workflow == "Vertical" then
            dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        else
            dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
        end
        Undo_EndBlock("Add Playback Track", 0)
        say("Playback track added (hardware output " .. hw_first .. "/" .. (hw_first + 1) .. ")")
        return true
    end

    if cmd == "rmpb" then
        local pb_list = mixer_core.get_special_tracks_by_type("playback")
        if #pb_list == 0 then
            say("No PLAYBACK track found")
            return true
        end
        DeleteTrack(pb_list[1].track)
        say("Playback track removed")
        return true
    end

    return false
end

local function is_target(str)
    return str == "rcm" or str:match("^%d+$") ~= nil or str:match("^[%#@]%d*$") ~= nil
        or str:match("^ref%d*$") ~= nil or str == "rt" or str == "live" or str == "lb" or str == "pb"
end
function M.try_routing_fx(cmd)
    local word_target, word_rest = mixer_core.split_word_target(cmd)

    if cmd == "*/*#" or cmd == "*/*@" then
        local kind = (cmd == "*/*#") and "submix" or "aux"
        local targets = mixer_core.get_special_tracks_by_type(kind)
        for _, mixer_track in ipairs(mixer_core.get_mixer_tracks()) do
            for _, info in ipairs(targets) do
                mixer_core.remove_send_to(mixer_track, info.track)
            end
        end
        say("All sends to " .. kind .. "es removed")
        return true
    end

    local is_ref_list = word_target and word_target:match("^ref")
    local list_target = (is_ref_list and word_rest == "-rcm" and word_target)
        or cmd:match("^([%d,%-%*%s]+)-rcm$")
    local list_connect = true
    if not list_target then
        list_target = (is_ref_list and word_rest == "/rcm" and word_target)
            or cmd:match("^([%d,%-%*%s]+)/rcm$")
        list_connect = false
    end
    if list_target then
        local tracks, err = mixer_core.resolve_target_list((list_target:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or ("Unknown target: " .. list_target))
            return true
        end
        for _, track in ipairs(tracks) do
            mixer_core.set_rcm_connection(track, list_connect)
        end
        say((list_connect and "Connected to RCM: " or "Disconnected from RCM: ") .. mixer_core.track_names_str(tracks))
        return true
    end

    local query_target = (word_target and word_rest == "-rcm?" and word_target)
        or cmd:match("^([%#@]?%d*)-rcm%?$")
    if query_target then
        local track, err = mixer_core.resolve_target(query_target)
        if not track then
            say(err or ("Unknown target: " .. query_target))
            return true
        end
        local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
        say("RCM connection: " .. (state == "y" and "disconnected" or "connected"))
        return true
    end

    local rcm_target = (word_target and word_rest == "-rcm" and word_target)
        or cmd:match("^([%#@]?%d*)-rcm$")
    local connect = true
    if not rcm_target then
        rcm_target = (word_target and word_rest == "/rcm" and word_target)
            or cmd:match("^([%#@]?%d*)/rcm$")
        connect = false
    end
    if rcm_target then
        local track, err = mixer_core.resolve_target(rcm_target)
        if not track then
            say(err or ("Unknown target: " .. rcm_target))
            return true
        end
        mixer_core.set_rcm_connection(track, connect)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        say((connect and "Connected to RCM: " or "Disconnected from RCM: ") .. humanize_track_name(name))
        return true
    end

    local out_target, out_val
    if word_target then
        out_val = word_rest:match("^=out,(.+)$")
        if out_val then out_target = word_target end
    end
    if not out_target then
        out_target, out_val = cmd:match("^([%#@]?%d*)=out,(.+)$")
    end
    if out_target then
        local track, err = mixer_core.resolve_target(out_target)
        if not track then
            say(err or ("Unknown target: " .. out_target))
            return true
        end
        local ch = tonumber(out_val)
        if not ch or ch < 1 then
            say("Please enter a valid channel number")
            return true
        end
        local is_mixer = out_target:match("^%d+$") ~= nil
        local mono = is_mixer and not mixer_core.mixer_track_is_stereo(track)
        local width = mono and 1 or mixer_core.track_channel_width(track)
        mixer_core.set_hw_output(track, ch - 1, mono)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local label = (width > 1) and string.format("%d and %d", ch, ch + width - 1) or tostring(ch)
        say("Hardware output set to " .. label .. ": " .. humanize_track_name(name))
        return true
    end

    local rmout_target
    if word_target and word_rest == "rmout" then
        rmout_target = word_target
    end
    if not rmout_target then
        rmout_target = cmd:match("^([%#@]?%d*)rmout$")
    end
    if rmout_target then
        local track, err = mixer_core.resolve_target(rmout_target)
        if not track then
            say(err or ("Unknown target: " .. rmout_target))
            return true
        end
        mixer_core.set_hw_output(track, nil, false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        say("Hardware output cleared: " .. humanize_track_name(name))
        return true
    end

    if cmd == "aho" or cmd:match("^aho=%d+$") then
        local start_ch = tonumber(cmd:match("^aho=(%d+)$")) or 1
        local used = {}
        local max_hw = GetNumAudioOutputs()
        local assigned_count = 0
        for _, track in ipairs(mixer_core.get_mixer_tracks()) do
            local _, disabled_state = GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", "", false)
            if disabled_state ~= "y" then
                local mono = not mixer_core.mixer_track_is_stereo(track)
                local width = mono and 1 or 2
                local assigned = false
                for ch = start_ch - 1, max_hw - width, width do
                    local free = true
                    for c = ch, ch + width - 1 do
                        if used[c] then free = false; break end
                    end
                    if free then
                        mixer_core.set_hw_output(track, ch, mono)
                        for c = ch, ch + width - 1 do used[c] = true end
                        assigned = true
                        assigned_count = assigned_count + 1
                        break
                    end
                end
                if not assigned then
                    mixer_core.set_hw_output(track, nil, false)
                end
            end
        end
        say("Auto-assigned hardware outputs for " .. assigned_count .. " track" .. (assigned_count == 1 and "" or "s"))
        return true
    end

    if cmd == "clearhw" then
        for _, track in ipairs(mixer_core.get_mixer_tracks()) do
            mixer_core.set_hw_output(track, nil, false)
        end
        for _, kind in ipairs({ "aux", "submix", "roomtone", "reference", "rcmaster", "live", "listenback", "playback" }) do
            for _, info in ipairs(mixer_core.get_special_tracks_by_type(kind)) do
                mixer_core.set_hw_output(info.track, nil, false)
            end
        end
        say("All hardware output assignments cleared")
        return true
    end

    local fx_target, fx_name, fx_pos
    if word_target then
        fx_name, fx_pos = word_rest:match("^fx=([^,]+),(%d+)$")
        if not fx_name then fx_name = word_rest:match("^fx=(.+)$") end
        if fx_name then fx_target = word_target end
    end
    if not fx_target then
        fx_target, fx_name, fx_pos = cmd:match("^([%#@]?%d*)fx=([^,]+),(%d+)$")
    end
    if not fx_target then
        fx_target, fx_name = cmd:match("^([%#@]?%d*)fx=(.+)$")
    end
    if fx_target then
        local track, err = mixer_core.resolve_target(fx_target)
        if not track then
            say(err or ("Unknown target: " .. fx_target))
            return true
        end
        local idx = TrackFX_AddByName(track, trim(fx_name), false, -1)
        if idx < 0 then
            say("FX not found: " .. fx_name)
        else
            if fx_pos then
                TrackFX_CopyToTrack(track, idx, track, tonumber(fx_pos) - 1, true)
            end
            say("FX added: " .. trim(fx_name))
        end
        return true
    end

    local rmfx_target, rmfx_sel
    if word_target then
        rmfx_sel = word_rest:match("^rmfx=(.+)$")
        if rmfx_sel then rmfx_target = word_target end
    end
    if not rmfx_target then
        rmfx_target, rmfx_sel = cmd:match("^([%#@]?%d*)rmfx=(.+)$")
    end
    if rmfx_target then
        local track, err = mixer_core.resolve_target(rmfx_target)
        if not track then
            say(err or ("Unknown target: " .. rmfx_target))
            return true
        end
        local idx, fx_err = resolve_fx_index(track, rmfx_sel)
        if not idx then
            say(fx_err)
            return true
        end
        local _, removed_name = TrackFX_GetFXName(track, idx, "")
        TrackFX_Delete(track, idx)
        say("FX removed: " .. removed_name)
        return true
    end

    local mvfx_target, mvfx_sel, mvfx_pos
    if word_target then
        mvfx_sel, mvfx_pos = word_rest:match("^mvfx=([^,]+),(%d+)$")
        if mvfx_sel then mvfx_target = word_target end
    end
    if not mvfx_target then
        mvfx_target, mvfx_sel, mvfx_pos = cmd:match("^([%#@]?%d*)mvfx=([^,]+),(%d+)$")
    end
    if mvfx_target then
        local track, err = mixer_core.resolve_target(mvfx_target)
        if not track then
            say(err or ("Unknown target: " .. mvfx_target))
            return true
        end
        local idx, fx_err = resolve_fx_index(track, mvfx_sel)
        if not idx then
            say(fx_err)
            return true
        end
        local new_idx = mixer_core.clamp(tonumber(mvfx_pos) - 1, 0, TrackFX_GetCount(track) - 1)
        local _, fx_name = TrackFX_GetFXName(track, idx, "")
        TrackFX_CopyToTrack(track, idx, track, new_idx, true)
        say(fx_name .. " moved to position " .. (new_idx + 1))
        return true
    end

    local fxen_target, fxen_sel, fxen_state
    if word_target then
        fxen_sel = word_rest:match("^fxon=(.+)$")
        if fxen_sel then
            fxen_target, fxen_state = word_target, true
        else
            fxen_sel = word_rest:match("^fxoff=(.+)$")
            if fxen_sel then fxen_target, fxen_state = word_target, false end
        end
    end
    if not fxen_target then
        fxen_target, fxen_sel = cmd:match("^([%#@]?%d*)fxon=(.+)$")
        if fxen_target then fxen_state = true end
    end
    if not fxen_target then
        fxen_target, fxen_sel = cmd:match("^([%#@]?%d*)fxoff=(.+)$")
        if fxen_target then fxen_state = false end
    end
    if fxen_target then
        local track, err = mixer_core.resolve_target(fxen_target)
        if not track then
            say(err or ("Unknown target: " .. fxen_target))
            return true
        end
        local idx, fx_err = resolve_fx_index(track, fxen_sel)
        if not idx then
            say(fx_err)
            return true
        end
        TrackFX_SetEnabled(track, idx, fxen_state)
        local _, fx_name = TrackFX_GetFXName(track, idx, "")
        say(fx_name .. ": " .. (fxen_state and "on" or "off"))
        return true
    end

    local fxall_target, fxall_state
    if word_target then
        if word_rest == "fxon" then
            fxall_target, fxall_state = word_target, true
        elseif word_rest == "fxoff" then
            fxall_target, fxall_state = word_target, false
        end
    end
    if not fxall_target then
        local t = cmd:match("^([%#@]?%d*)fxon$")
        if t then fxall_target, fxall_state = t, true end
    end
    if not fxall_target then
        local t = cmd:match("^([%#@]?%d*)fxoff$")
        if t then fxall_target, fxall_state = t, false end
    end
    if fxall_target then
        local track, err = mixer_core.resolve_target(fxall_target)
        if not track then
            say(err or ("Unknown target: " .. fxall_target))
            return true
        end
        SetMediaTrackInfo_Value(track, "I_FXEN", fxall_state and 1 or 0)
        say("All FX: " .. (fxall_state and "on" or "off"))
        return true
    end

    local a, b = cmd:match("^([^%-/]+)-([^%-/]+)$")
    if a and is_target(a) and is_target(b) then
        local track_a, err_a = mixer_core.resolve_target(a)
        local track_b, err_b = mixer_core.resolve_target(b)
        if track_a and track_b then
            CreateTrackSend(track_a, track_b)
            local _, name_a = GetSetMediaTrackInfo_String(track_a, "P_NAME", "", false)
            local _, name_b = GetSetMediaTrackInfo_String(track_b, "P_NAME", "", false)
            say("Send created: " .. humanize_track_name(name_a) .. " to " .. humanize_track_name(name_b))
        else
            say(err_a or err_b or "Unknown target")
        end
        return true
    end

    local ra, rb = cmd:match("^([^%-/]+)/([^%-/]+)$")
    if ra and is_target(ra) and is_target(rb) then
        local track_a, err_a = mixer_core.resolve_target(ra)
        local track_b, err_b = mixer_core.resolve_target(rb)
        if track_a and track_b then
            mixer_core.remove_send_to(track_a, track_b)
            local _, name_a = GetSetMediaTrackInfo_String(track_a, "P_NAME", "", false)
            local _, name_b = GetSetMediaTrackInfo_String(track_b, "P_NAME", "", false)
            say("Send removed: " .. humanize_track_name(name_a) .. " to " .. humanize_track_name(name_b))
        else
            say(err_a or err_b or "Unknown target")
        end
        return true
    end

    return false
end

function rec_input_label(tr)
    local rec_input = math.floor(GetMediaTrackInfo_Value(tr, "I_RECINPUT"))

    if rec_input == -1 or rec_input == 4096 then
        return "-"
    end

    if (rec_input & 4096) ~= 0 and rec_input > 4096 then
        return "MIDI"
    end

    local start_channel = rec_input & 1023
    local is_stereo = (rec_input & 1024) ~= 0
    local is_multichannel = (rec_input & 2048) ~= 0
    local first_input = start_channel + 1

    local hw_name1 = GetInputChannelName(start_channel)

    if is_stereo then
        local hw_name2 = GetInputChannelName(start_channel + 1)
        if hw_name1 and hw_name1 ~= "" and hw_name2 and hw_name2 ~= "" then
            local base1 = hw_name1:match("^(.+)%s+%d+$") or hw_name1
            local base2 = hw_name2:match("^(.+)%s+%d+$") or hw_name2
            if base1 == base2 then
                return string.format("%s+%s", hw_name1, hw_name2)
            else
                return string.format("%s/%s", hw_name1, hw_name2)
            end
        end
        return string.format("%d-%d", first_input, first_input + 1)
    elseif is_multichannel then
        local num_channels = math.floor(GetMediaTrackInfo_Value(tr, "I_NCHAN"))
        if hw_name1 and hw_name1 ~= "" then
            return string.format("%s+%d", hw_name1, num_channels - 1)
        end
        return string.format("%d-%d", first_input, first_input + num_channels - 1)
    else
        if hw_name1 and hw_name1 ~= "" then
            return hw_name1
        end
        return string.format("%d", first_input)
    end
end

function rec_input_description(tr)
    local rec_input = math.floor(GetMediaTrackInfo_Value(tr, "I_RECINPUT"))

    if rec_input == -1 or rec_input == 4096 then
        return "none"
    end

    if (rec_input & 4096) ~= 0 and rec_input > 4096 then
        return "MIDI"
    end

    local is_stereo = (rec_input & 1024) ~= 0
    return rec_input_label(tr) .. " (" .. (is_stereo and "stereo" or "mono") .. ")"
end

return M
