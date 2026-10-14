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

local main, markers, exclusive_select_folder_parent, solo
local find_marker_pos, select_marker_exclusive

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")
local audition_playback = require("ReaClassical_Audition_Playback")
local enum_project_markers = require("ReaClassical_Marker_Enum")

local ROLL = 3.0

set_action_options(3)

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[7] then ref_is_guide = tonumber(table[7]) or 0 end
end

function main()
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

    local marker_count, folder_prefix = markers()
    if marker_count == 0 then
        say("No source out marker found")
        return
    end

    if workflow == "horizontal" then
        exclusive_select_folder_parent(nil)
    else
        exclusive_select_folder_parent(folder_prefix)
    end

    solo()

    local marker_pos = find_marker_pos(999, "SOURCE-OUT")
    if not marker_pos then return end
    select_marker_exclusive(999, "SOURCE-OUT")

    local start_pos = math.max(0, marker_pos - ROLL)
    audition_playback.play_segment(start_pos, marker_pos)
end

function markers()
    local marker_count = 0
    local folder_prefix = nil
    local num = 0

    while true do
        local proj = EnumProjects(num)
        if proj == nil then break end
        local num_markers = GetNumRegionsOrMarkers(proj)
        for i = 0, num_markers - 1 do
            local _, _, _, _, raw_label, _ = enum_project_markers(proj, i)
            local prefix = string.match(raw_label, "^(.+):SOURCE%-OUT$")
            if prefix then
                marker_count = 1
                folder_prefix = prefix ~= "" and prefix or nil
            elseif string.match(raw_label, "^SOURCE%-OUT$") then
                marker_count = 1
            end
        end
        num = num + 1
    end

    return marker_count, folder_prefix
end

function exclusive_select_folder_parent(prefix)
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        SetTrackSelected(track, false)
    end

    local target_track = nil

    if prefix == nil then
        if num_tracks > 0 then
            target_track = GetTrack(0, 0)
        end
    else
        for i = 0, num_tracks - 1 do
            local track = GetTrack(0, i)
            local _, track_name = GetTrackName(track)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth == 1 and string.match(track_name, "^" .. prefix) then
                target_track = track
                break
            end
        end
    end

    if target_track then
        SetTrackSelected(target_track, true)
    end
end

function solo()
    local cache = track_scan.build()
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

function select_marker_exclusive(marker_id, marker_type)
    if not APIExists("GetNumRegionsOrMarkers") then return end

    local proj = EnumProjects(-1)
    if not proj then return end

    local total = GetNumRegionsOrMarkers(proj)
    for i = 0, total - 1 do
        local marker = GetRegionOrMarker(proj, i, "")
        if GetRegionOrMarkerInfo_Value(proj, marker, "B_ISREGION") == 0 then
            local number = GetRegionOrMarkerInfo_Value(proj, marker, "I_NUMBER")
            local _, raw_label = GetSetRegionOrMarkerInfo_String(proj, marker, "P_NAME", "", false)
            local label = raw_label:match(":(.+)$") or raw_label
            local is_target = (number == marker_id and label == marker_type)
            SetRegionOrMarkerInfo_Value(proj, marker, "B_UISEL", is_target and 1 or 0)
        end
    end
end

function find_marker_pos(marker_id, marker_type)
    local proj = EnumProjects(-1)
    if not proj then return nil end

    local num_markers = GetNumRegionsOrMarkers(proj)
    for i = 0, num_markers - 1 do
        local _, isrgn, pos, _, raw_label, markrgnindexnumber = enum_project_markers(proj, i)
        if not isrgn and markrgnindexnumber == marker_id then
            local label = raw_label:match(":(.+)$") or raw_label
            if label == marker_type then
                return pos
            end
        end
    end

    return nil
end

main()
