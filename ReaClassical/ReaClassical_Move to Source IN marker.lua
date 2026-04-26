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

---------------------------------------------------------------------

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

    if marker_count == 0 then return end

    if workflow == "horizontal" then
        exclusive_select_folder_parent(nil)
    else
        exclusive_select_folder_parent(folder_prefix)
    end

    GoToMarker(0, 998, false)
    solo()
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
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

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

main()