--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local main, solo, trackname_check, select_children_of_selected_folders
local unselect_folder_children, delete_items

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    if workflow == "Horizontal" then
        local convert_response = MB("Are you sure you'd like to convert to a vertical workflow?"
        , "Vertical Workflow", 4)
        if convert_response ~= 6 then return end
    end

    local num_of_tracks = CountTracks(0)
    if num_of_tracks == 0 then
        MB("Please add at least one track or folder before running", "Duplicate folder (no items)", 0)
        return
    end
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local is_parent
    local count = 0
    local num_of_selected = CountSelectedTracks(0)
    for i = 0, num_of_selected - 1, 1 do
        local track = GetSelectedTrack(0, i)
        if track then
            is_parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if is_parent == 1 then
                count = count + 1
            end
        end
    end

    if count ~= 1 then
        MB("Please select one parent track before running", "Duplicate folder (no items)", 0)
        return
    end

    Main_OnCommand(40340, 0)
    Main_OnCommand(40062, 0) -- Duplicate track
    select_children_of_selected_folders()
    Main_OnCommand(40421, 0) -- Item: Select all items in track
    delete_items()
    unselect_folder_children()

    local sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
    Main_OnCommand(sync, 0)
    solo()
    PreventUIRefresh(-1)
    Main_OnCommand(40913, 0) -- adjust scroll to selected tracks
    UpdateArrange()
    UpdateTimeline()
    TrackList_AdjustWindows(false)

    -- Prepare Takes
    SetProjExtState(0, "ReaClassical", "prepare_silent", "y")
    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)
    SetProjExtState(0, "ReaClassical", "prepare_silent", "")

    Undo_EndBlock('Duplicate folder (No items)', 0)
end

---------------------------------------------------------------------

function solo()
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

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^LIVE") or trackname_check(track, "^REF")

        if special_states or special_names then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end


        if IsTrackSelected(track) == true then
            -- SetMediaTrackInfo_Value(track, "I_SOLO", 2)
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        elseif not (special_states or special_names)
            and IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        elseif not (special_states or special_names) then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end

        local muted = GetMediaTrackInfo_Value(track, "B_MUTE")

        local states_for_receives = mixer_state == "y" or aux_state == "y"
            or submix_state == "y" or rcmaster_state == "y"
        local names_for_receives = trackname_check(track, "^M:") or trackname_check(track, "^@")
            or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER")

        if (states_for_receives or names_for_receives) and muted == 0 then
            local receives = GetTrackNumSends(track, -1)
            for j = 0, receives - 1, 1 do -- loop through receives
                local origin = GetTrackSendInfo_Value(track, -1, j, "P_SRCTRACK")
                if origin == selected_track or parent == 1 then
                    SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                    SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                    break
                end
            end
        end
    end
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
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

function delete_items()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            -- Delete items from this track until none remain
            while CountTrackMediaItems(track) > 0 do
                local item = GetTrackMediaItem(track, 0)
                DeleteTrackMediaItem(track, item)
            end
        end
    end
end

---------------------------------------------------------------------

main()
