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

local main, solo, trackname_check, mixer, track_check
local load_prefs, save_prefs, get_color_table
local check_parent_track
local get_selected_media_item_at, count_selected_media_items
local clear_all_rec_armed_except_live, get_item_guid
local select_children_of_selected_folders, reset_playback_rate
local unselect_folder_children, set_rec_arm_for_selected_tracks
local find_mixer_track_for_track, is_mixer_disabled
local avoid_take_lanes, find_recording_folder, get_record_takes_horizontally
local spoken_folder_label, selected_tracks_have_input

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")
local spare_track = require("ReaClassical_Spare_Track")

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
local use_only_take_num = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[7] then ref_is_guide = tonumber(table[7]) or 0 end
    if table[14] then use_only_take_num = tonumber(table[14]) or 0 end
end

function main()
    if GetExtState("ReaClassical", "MixerMode") == "1" and APIExists("AddRemoveReaScript") then
        if GetPlayState() ~= 0 then
            SetExtState("ReaClassical", "MixerModeForceMain", "1", false)
        end
        local cid = AddRemoveReaScript(true, 0,
            script_path .. "ReaClassical_Accessible Mixer Mode.lua", true)
        if cid ~= 0 then Main_OnCommand(cid, 0) end
    end

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
    if track_check() == 0 then
        MB("Please add at least one folder before running", "Classical Take Record", 0)
        return
    end

    if APIExists("clara_outputMessage") then
        local _, ts = GetProjExtState(0, "ReaClassical", "rec_daemon_heartbeat")
        local daemon_running = (os.time() - (tonumber(ts) or 0)) < 5
        if not daemon_running and APIExists("AddRemoveReaScript") then
            local daemon_cid = AddRemoveReaScript(true, 0,
                script_path .. "lib/ReaClassical_Record Panel Daemon.lua", true)
            if daemon_cid ~= 0 then
                SetProjExtState(0, "ReaClassical", "rec_daemon_stop", "")
                Main_OnCommand(daemon_cid, 0)
                local panel_id = NamedCommandLookup("_RSbd41ad183cae7b18bccb86b087f719e945278160")
                if panel_id ~= 0 then SetToggleCommandState(1, panel_id, 1) end
            end
        end
    end

    PreventUIRefresh(1)

    if GetPlayState() ~= 0 then
        local recording_folder = find_recording_folder()
        if not recording_folder then
            Main_OnCommand(40667, 0)
            PreventUIRefresh(-1)
            say("Recording Stopped")
            return
        end

        Main_OnCommand(40297, 0)
        SetTrackSelected(recording_folder, true)

        Undo_BeginBlock()

        Main_OnCommand(40667, 0)
        local _, session_name = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        session_name = (session_name ~= "" and session_name .. "_") or ""
        local _, take_num_str = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        local take_number = tonumber(take_num_str)
        if take_number then
            local padded_number = string.format("%03d", take_number)
            local take_prefix = (session_name == "") and "" or "T"
            local num_of_selected_items = count_selected_media_items()
            for i = 0, num_of_selected_items - 1 do
                local item = get_selected_media_item_at(i)
                local take = GetActiveTake(item)
                if take then
                    if use_only_take_num == 0 then
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", session_name .. take_prefix .. padded_number, true)
                    else
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", padded_number, true)
                    end
                end
            end
        end

        Main_OnCommand(40032, 0)
        local recorded_item = get_selected_media_item_at(0)
        local recorded_item_guid = get_item_guid(recorded_item)
        SetProjExtState(0, "ReaClassical", "LastRecordedItem", recorded_item_guid)

        local recorded_guids = {}
        local num_selected = count_selected_media_items()
        for i = 0, num_selected - 1 do
            local sel_item = get_selected_media_item_at(i)
            local guid = get_item_guid(sel_item)
            if guid ~= "" then
                recorded_guids[#recorded_guids + 1] = guid
            end
        end
        SetProjExtState(0, "ReaClassical", "LastRecordedItemGUIDs", table.concat(recorded_guids, ","))
        Main_OnCommand(40289, 0)

        if workflow == "Vertical" and not get_record_takes_horizontally() then
            select_children_of_selected_folders()
            local ret, cursor_pos = load_prefs()
            if ret == 1 then
                SetEditCurPos(cursor_pos, true, false)
                SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", "")
            end
            set_rec_arm_for_selected_tracks(0)

            local num_tracks = CountTracks(0)
            local selected_track = GetSelectedTrack(0, 0)
            local current_num = selected_track and GetMediaTrackInfo_Value(selected_track, 'IP_TRACKNUMBER') or 0
            local bool = false
            for i = current_num, num_tracks - 1, 1 do
                local track = GetTrack(0, i)
                if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                    Main_OnCommand(40297, 0)
                    SetTrackSelected(track, true)
                    select_children_of_selected_folders()
                    solo()
                    set_rec_arm_for_selected_tracks(1)
                    mixer()
                    unselect_folder_children()
                    Main_OnCommand(40913, 0)
                    bool = true
                    TrackList_AdjustWindows(false)
                    break
                end
            end
            if bool == false then
                local duplicate = NamedCommandLookup("_RS2c6e13d20ab617b8de2c95a625d6df2fde4265ff")
                Main_OnCommand(duplicate, 0)
                select_children_of_selected_folders()
                set_rec_arm_for_selected_tracks(1)
                solo()
                unselect_folder_children()
                Main_OnCommand(40913, 0)
            end
        elseif workflow == "Vertical" then
            select_children_of_selected_folders()
            solo()
            mixer()
            unselect_folder_children()
        end

        local stop_msg = take_number and ("Stopped recording take " .. take_number) or "Recording Stopped"
        if workflow == "Vertical" then
            local armed_track = GetSelectedTrack(0, 0)
            local label = armed_track and spoken_folder_label(workflow, armed_track)
            if label then
                stop_msg = stop_msg .. ". " .. label .. " folder armed"
            end
        end

        PreventUIRefresh(-1)
        Undo_EndBlock('Classical Take Record Stop', 0)
        UpdateArrange()
        UpdateTimeline()
        say(stop_msg)
        return
    end

    local first_selected = GetSelectedTrack(0, 0)
    if not first_selected then
        local target_index = (workflow == "Vertical") and 2 or 1
        local folder_count = 0
        local num_tracks = CountTracks(0)
        for i = 0, num_tracks - 1 do
            local track = GetTrack(0, i)
            if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                folder_count = folder_count + 1
                if folder_count == target_index then
                    SetOnlyTrackSelected(track)
                    first_selected = track
                    break
                end
            end
        end
        if not first_selected then
            MB("No folder found in the project.", "Classical Take Record", 0)
            return
        end
    end
    if not check_parent_track(first_selected) then
        local parent_track = GetParentTrack(first_selected)
        if not parent_track then
            MB("Classical Take Record only works with folders", "Error", 0)
            return
        else
            SetOnlyTrackSelected(parent_track)
        end
    end

    local rec_arm = GetMediaTrackInfo_Value(first_selected, "I_RECARM")

    Undo_BeginBlock()

    local record_panel = NamedCommandLookup("_RSbd41ad183cae7b18bccb86b087f719e945278160")
    local state = GetToggleCommandState(record_panel)
    if state ~= 1 then
        Main_OnCommand(record_panel, 0)
    end

    local first_selected_track = GetSelectedTrack(0, 0)
    Main_OnCommand(40297, 0)
    SetTrackSelected(first_selected_track, true)

    select_children_of_selected_folders()
    mixer()
    local selected = solo()
    if not selected then
        MB("Please select a folder or track before running", "Classical Take Record", 0)
        return
    end

    if not selected_tracks_have_input() then
        PreventUIRefresh(-1)
        Undo_EndBlock('Classical Take Record', 0)
        UpdateArrange()
        UpdateTimeline()
        if APIExists("clara_outputMessage") then
            say("No inputs set -- please assign inputs before recording")
        else
            MB("Please assign inputs before recording via Mission Control", "Classical Take Record", 0)
        end
        return
    end

    clear_all_rec_armed_except_live(workflow)
    set_rec_arm_for_selected_tracks(1)
    unselect_folder_children()

    local _, allow_overlap = GetProjExtState(0, "ReaClassical", "AllowOverlappingTakes")
    if allow_overlap ~= "1" then
        avoid_take_lanes()
    end

    if rec_arm ~= 1 then
        TrackList_AdjustWindows(false)
        PreventUIRefresh(-1)
        Undo_EndBlock('Classical Take Record', 0)
        UpdateArrange()
        UpdateTimeline()
        local _, take_num = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        say(take_num ~= "" and ("Armed for take " .. take_num) or "Folder armed")
        return
    end

    local cursor_pos = GetCursorPosition()
    save_prefs(cursor_pos)

    if allow_overlap ~= "1" then
        avoid_take_lanes()
    end

    PreventUIRefresh(-1)
    Main_OnCommand(40527, 0)
    Main_OnCommand(1013, 0)
    Undo_EndBlock('Classical Take Record', 0)

    local _, take_num = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
    if take_num ~= "" then say("Recording take " .. take_num) end

    UpdateArrange()
    UpdateTimeline()
end

function spoken_folder_label(workflow, track)
    if workflow ~= "Vertical" then return nil end
    local _, folder_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local prefix = folder_name:match("^([^:]+):") or folder_name

    local spoken_prefix = prefix
        :gsub("^D$", "Destination")
        :gsub("^S(%d+)$", "Source %1")

    return spoken_prefix ~= "" and spoken_prefix or "Unnamed folder"
end

function solo()
    local track = GetSelectedTrack(0, 0)
    if not track then
        return false
    end

    local cache = track_scan.build()
    local set_track_value = track_write.set_track_value

    for i = 0, CountTracks(0) - 1, 1 do
        track = GetTrack(0, i)
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

        if IsTrackSelected(track) == false and not mixer_state and not aux_state and not submix_state
            and not rt_state and not live_state and not listenback_state and not rcmaster_state
            and not playback_state then
            set_track_value(track, "I_SOLO", 0)
            set_track_value(track, "B_MUTE", 1)
        elseif IsTrackSelected(track) then
            set_track_value(track, "B_MUTE", 0)
        end
        if live_state then
            set_track_value(track, "I_SOLO", 0)
            set_track_value(track, "B_MUTE", 1)
        end
        if ref_state and ref_is_guide == 1 then
            set_track_value(track, "B_MUTE", 0)
            set_track_value(track, "I_SOLO", 1)
        end
    end
    return true
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
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
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

        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        local parent_folder_visible = true

        if wf == "Vertical" then
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

    spare_track.apply_state()
end

function track_check()
    return CountTracks(0)
end

function load_prefs()
    return GetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos")
end

function save_prefs(cursor_position)
    SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", cursor_position)
end

function get_color_table()
    return require("ReaClassical_Colors_Table")
end

function check_parent_track(track)
    if not track or GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        return false
    end
    return true
end

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            selected_count = selected_count + 1
        end
    end

    return selected_count
end

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

function clear_all_rec_armed_except_live(workflow)
    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local _, live_flag = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, lb_flag = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)

        if live_flag == "y" and workflow == "Horizontal" then
            SetMediaTrackInfo_Value(track, "I_RECARM", 1)
        elseif lb_flag == "y" then
            SetMediaTrackInfo_Value(track, "I_RECARM", 1)
            SetMediaTrackInfo_Value(track, "I_RECMODE", 2)
        else
            SetMediaTrackInfo_Value(track, "I_RECARM", 0)
        end
    end
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

function find_mixer_track_for_track(track)
    local num_sends = GetTrackNumSends(track, 0)

    for i = 0, num_sends - 1 do
        local dest_track = GetTrackSendInfo_Value(track, 0, i, "P_DESTTRACK")
        if dest_track then
            local _, mixer_state = GetSetMediaTrackInfo_String(dest_track, "P_EXT:mixer", "", false)
            if mixer_state == "y" then
                return dest_track
            end
        end
    end

    return nil
end

function is_mixer_disabled(mixer_track)
    if not mixer_track then
        return false
    end

    local _, disabled_state = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:input_disabled", "", false)
    return (disabled_state == "y")
end

function set_rec_arm_for_selected_tracks(state)
    if state == 1 then
        CSurf_OnPlayRateChange(1.0)
    end
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local _, lb_flag = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)

        if lb_flag == "y" then
            SetMediaTrackInfo_Value(track, "I_RECARM", 1)
        elseif IsTrackSelected(track) then
            local mixer_track = find_mixer_track_for_track(track)

            if state == 1 and is_mixer_disabled(mixer_track) then
                SetMediaTrackInfo_Value(track, "I_RECARM", 0)
            else
                SetMediaTrackInfo_Value(track, "I_RECARM", state)
            end
        end
    end

    UpdateArrange()
end

function get_item_guid(item)
    if not item then
        return ""
    end

    local retval, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
    if retval then
        return guid
    else
        return ""
    end
end

function get_record_takes_horizontally()
    local _, val = GetProjExtState(0, "ReaClassical", "RecordTakesHorizontally")
    return (val == "1")
end

function avoid_take_lanes()
    local cursor_pos = GetCursorPosition()
    local num_tracks = CountTracks(0)
    local latest_end = nil

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
            local item_count = CountTrackMediaItems(track)
            local track_latest_end = nil
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                local item_end = GetMediaItemInfo_Value(item, "D_POSITION")
                    + GetMediaItemInfo_Value(item, "D_LENGTH")
                if not track_latest_end or item_end > track_latest_end then
                    track_latest_end = item_end
                end
            end

            if track_latest_end and cursor_pos <= track_latest_end then
                if not latest_end or track_latest_end > latest_end then
                    latest_end = track_latest_end
                end
            end
        end
    end

    if latest_end then
        SetEditCurPos(latest_end + 1.0, false, false)
    end
end

function find_recording_folder()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
            if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                return track
            end
            for j = i - 1, 0, -1 do
                local parent = GetTrack(0, j)
                if GetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH") == 1 then
                    return parent
                end
            end
        end
    end

    return nil
end

function selected_tracks_have_input()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if IsTrackSelected(track) then
            local rec_input = math.floor(GetMediaTrackInfo_Value(track, "I_RECINPUT"))
            if rec_input ~= -1 and rec_input ~= 4096 then
                return true
            end
        end
    end
    return false
end

function reset_playback_rate()
    CSurf_OnPlayRateChange(1.0)
end

main()
