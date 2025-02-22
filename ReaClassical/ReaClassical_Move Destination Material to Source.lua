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
local main, duplicate_first_folder, sync_based_on_workflow
local delete_first_group_items, solo, trackname_check
local get_path, get_color_table, set_first_folder_items_color

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    -- PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "Vertical" then
        MB("This function requires a vertical ReaClassical project. " ..
            "Please create one or convert your existing ReaClassical project using F8.", "ReaClassical Error", 0)
        return
    end

    set_first_folder_items_color()
    local first_track = duplicate_first_folder()
    delete_first_group_items()
    sync_based_on_workflow(workflow)
    SetOnlyTrackSelected(first_track)
    solo()
    Main_OnCommand(40289, 0) -- unselect all items

    Undo_EndBlock('Move Destination Material to Source', 0)
    -- PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function duplicate_first_folder()
    local first_track = GetTrack(0, 0)
    if not first_track then return end
    SetOnlyTrackSelected(first_track)

    Main_OnCommand(40062, 0) -- Track: Duplicate tracks
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

function delete_first_group_items()
    local num_tracks = CountTracks(0)
    if num_tracks == 0 then return end

    local first_track = GetTrack(0, 0)
    if not first_track then return end

    local track_count = 1
    for i = 1, num_tracks - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        track_count = track_count + 1
        if depth < 0 then break end
    end

    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local num_items = CountTrackMediaItems(track)
            for j = num_items - 1, 0, -1 do
                local item = GetTrackMediaItem(track, j)
                DeleteTrackMediaItem(track, item)
            end
        end
    end
end

---------------------------------------------------------------------

function solo()
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)

        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", 0)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", 0)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", 0)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", 0)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", 0)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", 0)

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^REF")

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

        if (trackname_check(track, "^RoomTone") or rt_state == "y") and muted == 0 then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 1)
        end
    end
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

function set_first_folder_items_color()
    local colors = get_color_table()

    local track_count = CountTracks(0)
    if track_count == 0 then return end

    local first_folder = nil
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then
            first_folder = track
            break
        end
    end

    if not first_folder then return end

    local track_idx = GetMediaTrackInfo_Value(first_folder, "IP_TRACKNUMBER") - 1
    for i = track_idx, track_count - 1 do
        local track = GetTrack(0, i)

        local num_items = CountTrackMediaItems(track)
        for j = 0, num_items - 1 do
            local item = GetTrackMediaItem(track, j)
            SetMediaItemSelected(item, true)
            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", colors.edited_material)
        end
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") < 0 then break end
    end
end

---------------------------------------------------------------------

main()
