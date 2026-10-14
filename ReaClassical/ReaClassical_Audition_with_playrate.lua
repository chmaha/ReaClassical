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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")
local spare_track = require("ReaClassical_Spare_Track")

local main, solo, trackname_check, mixer
local get_color_table
local unselect_folder_children
local select_children_of_selected_folders

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
local audition_speed = 0.75
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[7] then ref_is_guide = tonumber(table[7]) or 0 end
    if table[9] then audition_speed = tonumber(table[9]) or 0.75 end
end

function main()
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
    PreventUIRefresh(1)
    CSurf_OnPlayRateChange(audition_speed)
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0)
    end
    local pos = BR_PositionAtMouseCursor(false)
    local screen_x, screen_y = GetMousePosition()
    local track = GetTrackFromPoint(screen_x, screen_y)
    if track then
        local cache = track_scan.build()
        SetOnlyTrackSelected(track)
        solo(cache)
        select_children_of_selected_folders()
        mixer(cache)
        unselect_folder_children()
        SetEditCurPos(pos, 0, 0)
        OnPlayButton()
        PreventUIRefresh(-1)
        Undo_EndBlock('Audition', 0)
        UpdateArrange()
        UpdateTimeline()
        TrackList_AdjustWindows(false)
    end
end

function solo(cache)
    local set_track_value = track_write.set_track_value
    local set_send_value = track_write.set_send_value

    Main_OnCommand(40491, 0)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if cache.tags[track].listenback then
            set_track_value(track, "I_RECARM", 1)
        end
    end
    local selected_track = GetSelectedTrack(0, 0)
    local parent = selected_track and GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH") or 0

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local t = cache.tags[track]
        local mixer_state = t.mixer
        local aux_state = t.aux
        local submix_state = t.submix
        local rt_state = t.roomtone
        local ref_state = t.rcref
        local listenback_state = t.listenback
        local rcmaster_state = t.rcmaster
        local playback_state = t.playback

        if mixer_state or aux_state or submix_state or rt_state
            or ref_state or listenback_state or playback_state then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                set_send_value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state or aux_state or submix_state or rt_state
                or ref_state or listenback_state or rcmaster_state or playback_state) then
            if IsTrackSelected(track) and parent ~= 1 then
                set_track_value(track, "I_SOLO", 2)
                set_track_value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                set_track_value(track, "I_SOLO", 0)
                set_track_value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                set_track_value(track, "B_MUTE", 1)
                set_track_value(track, "I_SOLO", 0)
            else
                set_track_value(track, "B_MUTE", 0)
                set_track_value(track, "I_SOLO", 0)
            end
        end

        if rt_state then
            if IsTrackSelected(track) then
                set_track_value(track, "B_MUTE", 0)
                set_track_value(track, "I_SOLO", 0)
            end
        end

        if ref_state then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0)
                mute_state = 0
                solo_state = 1
            elseif ref_is_guide == 1 then
                mute_state = 0
                solo_state = 0
            end

            set_track_value(track, "B_MUTE", mute_state)
            set_track_value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state then
            set_track_value(track, "B_MUTE", 0)
            set_track_value(track, "I_SOLO", 0)
        end
    end
end

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

function mixer(cache)
    local colors = get_color_table()

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

    spare_track.apply_state()
end

function get_color_table()
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
    return require("ReaClassical_Colors_Table")
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

main()
