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
local find_marker_pos, play_segment, select_marker_exclusive

---------------------------------------------------------------------

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

-- Auto-terminate any already-running instance instead of prompting the user
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
        say("No source in marker found")
        return
    end

    if workflow == "horizontal" then
        exclusive_select_folder_parent(nil)
    else
        exclusive_select_folder_parent(folder_prefix)
    end

    solo()

    local marker_pos = find_marker_pos(998, "SOURCE-IN")
    if not marker_pos then return end
    select_marker_exclusive(998, "SOURCE-IN")

    local stop_pos = marker_pos + 3.0
    play_segment(marker_pos, stop_pos)
end

---------------------------------------------------------------------

function markers()
    local marker_count = 0
    local folder_prefix = nil
    local num = 0

    while true do
        local proj = EnumProjects(num)
        if proj == nil then break end
        local _, num_markers, num_regions = CountProjectMarkers(proj)
        for i = 0, num_markers + num_regions - 1 do
            local _, _, _, _, raw_label, _ = EnumProjectMarkers2(proj, i)
            local prefix = string.match(raw_label, "^(.+):SOURCE%-IN$")
            if prefix then
                marker_count = 1
                folder_prefix = prefix ~= "" and prefix or nil
            elseif string.match(raw_label, "^SOURCE%-IN$") then
                marker_count = 1
            end
        end
        num = num + 1
    end

    return marker_count, folder_prefix
end

---------------------------------------------------------------------

function exclusive_select_folder_parent(prefix)
    local num_tracks = CountTracks(0)

    -- Deselect all tracks first
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        SetTrackSelected(track, false)
    end

    local target_track = nil

    if prefix == nil then
        -- Horizontal workflow: always select track 1 (index 0)
        if num_tracks > 0 then
            target_track = GetTrack(0, 0)
        end
    else
        -- Vertical workflow: find the folder parent whose name starts with the prefix
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

---------------------------------------------------------------------

function solo()
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
    -- Re-arm listenback tracks
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, lb_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        if lb_state == "y" then
            SetMediaTrackInfo_Value(track, "I_RECARM", 1)
        end
    end
    local selected_track = GetSelectedTrack(0, 0)
    local parent = selected_track and GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH") or 0

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
            or ref_state == "y" or listenback_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or listenback_state == "y" or rcmaster_state == "y") then
            if IsTrackSelected(track) and parent ~= 1 then
                SetMediaTrackInfo_Value(track, "I_SOLO", 2)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if rt_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if ref_state == "y" then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0) -- unsolo all tracks
                mute_state = 0
                solo_state = 1
            elseif ref_is_guide == 1 then
                mute_state = 0
                solo_state = 0
            end

            SetMediaTrackInfo_Value(track, "B_MUTE", mute_state)
            SetMediaTrackInfo_Value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

-- Selects the marker matching (marker_id, marker_type) and deselects every
-- other (non-region) marker, so it's ready for a follow-up Nudge Marker
-- Left/Right without having to click it in the ruler.
-- GetNumRegionsOrMarkers/GetRegionOrMarker/etc. are REAPER 7.62+ only -- on
-- older builds this is a silent no-op, since it's purely a convenience for
-- a follow-up Nudge Marker Left/Right and play_segment() doesn't need it.
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

---------------------------------------------------------------------

function find_marker_pos(marker_id, marker_type)
    local proj = EnumProjects(-1)
    if not proj then return nil end

    local _, num_markers, num_regions = CountProjectMarkers(proj)
    for i = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, _, raw_label, markrgnindexnumber = EnumProjectMarkers2(proj, i)
        if not isrgn and markrgnindexnumber == marker_id then
            -- Accept both "PREFIX:LABEL" and bare "LABEL" forms
            local label = raw_label:match(":(.+)$") or raw_label
            if label == marker_type then
                return pos
            end
        end
    end

    return nil
end

---------------------------------------------------------------------

function play_segment(start_pos, stop_pos)
    SetEditCurPos(start_pos, false, false)
    OnPlayButton()

    if not stop_pos then return end

    local function check_stop()
        if GetPlayState() & 1 == 0 then
            return -- playback already stopped (e.g. ran off the end)
        end
        if GetPlayPosition() >= stop_pos then
            OnStopButton()
            return
        end
        defer(check_stop)
    end

    defer(check_stop)
end

---------------------------------------------------------------------

main()
