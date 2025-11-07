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
local main, duplicate_first_folder, sync_based_on_workflow, solo
local trackname_check
---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "Vertical" then
        MB("This function requires a vertical ReaClassical project. " ..
            "Please create one or convert your existing ReaClassical project using F8.", "ReaClassical Error", 0)
        return
    end

    PreventUIRefresh(1)
    local first_track = duplicate_first_folder()
    sync_based_on_workflow(workflow)

    -- Prepare Takes
    SetProjExtState(0, "ReaClassical", "prepare_silent", "y")
    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)
    SetProjExtState(0, "ReaClassical", "prepare_silent", "")

    SetOnlyTrackSelected(first_track)
    solo()
    Main_OnCommand(40289, 0) -- unselect all items

    Undo_EndBlock('Copy Destination Material to Source', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function duplicate_first_folder()
    local first_track = GetTrack(0, 0)
    if not first_track then return end
    GetSetMediaTrackInfo_String(first_track, "P_EXT:dest_copy", "y", true)
    SetOnlyTrackSelected(first_track)

    Main_OnCommand(40062, 0) -- Track: Duplicate tracks
    GetSetMediaTrackInfo_String(first_track, "P_EXT:dest_copy", "", true)
    return first_track
end

---------------------------------------------------------------------

function sync_based_on_workflow(workflow)
    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    elseif workflow == "Horizontal" then
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
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

main()
