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

local main, solo
local select_children_of_selected_folders
local unselect_folder_children
local any_track_armed, get_folder_parent, arm_folder, get_folder_children

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[8] then ref_is_guide = tonumber(table[8]) or 0 end
end

---------------------------------------------------------------------

function any_track_armed()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------

function get_folder_parent(target_track)
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if tr == target_track then
            -- Check if this track is itself a folder parent
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if depth == 1 then
                return tr, i
            end
            -- Otherwise walk backwards to find the folder parent
            local nested = 0
            for j = i - 1, 0, -1 do
                local check = GetTrack(0, j)
                local d = GetMediaTrackInfo_Value(check, "I_FOLDERDEPTH")
                if d == -1 then
                    nested = nested + 1
                elseif d == 1 then
                    if nested > 0 then
                        nested = nested - 1
                    else
                        return check, j
                    end
                end
            end
            break
        end
    end
    return nil, nil
end

---------------------------------------------------------------------

function get_folder_children(parent_idx)
    local tracks = {}
    local parent = GetTrack(0, parent_idx)
    tracks[#tracks + 1] = parent

    local track_count = CountTracks(0)
    local j = parent_idx + 1
    local depth = 1
    while j < track_count and depth > 0 do
        local ch_tr = GetTrack(0, j)
        tracks[#tracks + 1] = ch_tr
        local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
        depth = depth + ch_depth
        j = j + 1
    end
    return tracks
end

---------------------------------------------------------------------

function arm_folder(parent_idx)
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording

    -- Arm all tracks in the folder
    local folder_tracks = get_folder_children(parent_idx)
    for _, track in ipairs(folder_tracks) do
        -- Skip special tracks (mixer, aux, submix, etc.)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y"
                or ref_state == "y" or rcmaster_state == "y") then
            SetMediaTrackInfo_Value(track, "I_RECARM", 1)
        end
    end
end

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    PreventUIRefresh(1)
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end

    local window = BR_GetMouseCursorContext()
    local mouse_item = BR_GetMouseCursorContext_Item()

    -- Check if any track is currently armed BEFORE changing selection
    local was_armed = any_track_armed()

    Main_OnCommand(41110, 0)

    local track = GetSelectedTrack(0, 0)
    if track then
        if window == "tcp" or (window == "arrange" and not mouse_item) then
            Main_OnCommand(40289, 0) -- Unselect all items
        end

        -- If a child track was clicked, find and select its folder parent instead
        local parent_track, parent_idx = get_folder_parent(track)
        if parent_track then
            SetOnlyTrackSelected(parent_track)
        else
            SetOnlyTrackSelected(track)
        end

        local has_folders = false
        for i = 0, CountTracks(0) - 1 do
            local check_track = GetTrack(0, i)
            local folder_depth = GetMediaTrackInfo_Value(check_track, "I_FOLDERDEPTH")
            if folder_depth == 1 then
                has_folders = true
                break
            end
        end

        if has_folders then
            if was_armed and parent_idx then
                -- Tracks were armed: un-arm all, then arm the whole folder
                solo()
                arm_folder(parent_idx)
            else
                -- No tracks armed: just solo the folder as before
                solo()
            end
        end

        select_children_of_selected_folders()
        unselect_folder_children()
        PreventUIRefresh(-1)
        Undo_EndBlock('Select Folder', 0)
        UpdateArrange()
        UpdateTimeline()
        TrackList_AdjustWindows(false)
    end
end

---------------------------------------------------------------------

function solo()
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
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

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or rcmaster_state == "y") then
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

        if live_state == "y" then
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

function unselect_folder_children()
    local num_tracks = CountTracks(0)
    local depth = 0
    local unselect_mode = false

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if IsTrackSelected(tr) and folder_change == 1 then
            -- We found a selected folder parent
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        -- Adjust folder depth
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

---------------------------------------------------------------------

main()