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
local main, duplicate_first_folder, sync_based_on_workflow, prepare_takes
local shift, vertical_razor, horizontal_group
local vertical_group, horizontal, vertical, get_path
local empty_items_check, folder_check, trackname_check, solo, get_color_table
local get_selected_media_item_at, count_selected_media_items
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
    prepare_takes()
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

function prepare_takes()
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    local start_time, end_time = GetSet_ArrangeView2(0, false, 0, 0, 0, false)
    local num_of_project_items = CountMediaItems(0)
    if num_of_project_items == 0 then
        MB("Please add your takes before running...", "Prepare Takes", 0)
        return
    end
    local empty_count = empty_items_check(num_of_project_items)
    if empty_count > 0 then
        MB("Error: Empty items found. Delete them to continue.", "Prepare Takes", 0)
        return
    end

    for track_idx = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, track_idx)
        for item_idx = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, item_idx)
            SetMediaItemInfo_Value(item, "I_GROUPID", 0)
        end
    end

    Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
    local folders = folder_check()

    local first_item = GetMediaItem(0, 0)
    local position = GetMediaItemInfo_Value(first_item, "D_POSITION")
    if position == 0.0 then
        shift()
    end

    if folders == 0 or folders == 1 then
        horizontal()
    else
        vertical()
    end

    GetSet_ArrangeView2(0, true, 0, 0, start_time, end_time)
    SetEditCurPos(cur_pos, 0, 0)

    local scroll_up = NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
    Main_OnCommand(scroll_up, 0)
end

---------------------------------------------------------------------

function shift()
    Main_OnCommand(40182, 0)       -- select all items
    local nudge_right = NamedCommandLookup("_SWS_NUDGESAMPLERIGHT")
    Main_OnCommand(nudge_right, 0) -- shift items by 1 sample to the right
    Main_OnCommand(40289, 0)       -- unselect all items
end

---------------------------------------------------------------------

function vertical_razor()
    Main_OnCommand(40042, 0)           -- Transport: Go to start of project
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- Select child tracks
    Main_OnCommand(42579, 0)           -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40421, 0)           -- Item: Select all items in track
end

---------------------------------------------------------------------

function horizontal_group(string, group)
    if string == "horizontal" then
        Main_OnCommand(40296, 0) -- Track: Select all tracks
    else
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- Select child tracks
    end

    local selected = get_selected_media_item_at(0)
    local start = GetMediaItemInfo_Value(selected, "D_POSITION")
    local length = GetMediaItemInfo_Value(selected, "D_LENGTH")
    SetEditCurPos(start + (length / 2), false, false) -- move to middle of item
    local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_under, 0)                   -- XENAKIOS_SELITEMSUNDEDCURSELTX

    local num_selected_items = count_selected_media_items()
    for i = 0, num_selected_items - 1 do
        local item = get_selected_media_item_at(i)
        if item then
            SetMediaItemInfo_Value(item, "I_GROUPID", group)
        end
    end
end

---------------------------------------------------------------------

function vertical_group(length, group)
    local track = GetSelectedTrack(0, 0)
    local item = AddMediaItemToTrack(track)
    SetMediaItemPosition(item, length + 1, false)

    Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    repeat
        local selected = get_selected_media_item_at(0)
        local start = GetMediaItemInfo_Value(selected, "D_POSITION")
        local item_length = GetMediaItemInfo_Value(selected, "D_LENGTH")
        SetEditCurPos(start + (item_length / 2), false, false) -- move to middle of item
        local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
        Main_OnCommand(select_under, 0)                        -- XENAKIOS_SELITEMSUNDEDCURSELTX

        local num_selected_items = count_selected_media_items()
        for i = 0, num_selected_items - 1 do
            local selected_item = get_selected_media_item_at(i)
            if selected_item then
                SetMediaItemInfo_Value(selected_item, "I_GROUPID", group)
            end
        end
        group = group + 1
        Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    until IsMediaItemSelected(item) == true

    DeleteTrackMediaItem(track, item)
    return group
end

---------------------------------------------------------------------

function horizontal()
    local length = GetProjectLength(0)
    local first_track = GetTrack(0, 0)
    local new_item = AddMediaItemToTrack(first_track)
    SetMediaItemPosition(new_item, length + 1, false)

    if first_track then
        SetOnlyTrackSelected(first_track) -- Select only the first track
    end
    SetEditCurPos(0, false, false)

    local workflow = "horizontal"
    local group = 1
    Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    repeat
        horizontal_group(workflow, group)
        group = group + 1
        Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    until IsMediaItemSelected(new_item) == true

    DeleteTrackMediaItem(first_track, new_item)
    SelectAllMediaItems(0, false)
    Main_OnCommand(42579, 0) -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    SetEditCurPos(0, false, false)
end

---------------------------------------------------------------------

function vertical()
    local select_all_folders = NamedCommandLookup("_SWS_SELALLPARENTS")
    Main_OnCommand(select_all_folders, 0) -- select all folders
    local num_of_folders = CountSelectedTracks(0)
    local length = GetProjectLength(0)
    local first_track = GetTrack(0, 0)

    local new_item = AddMediaItemToTrack(first_track)
    SetMediaItemPosition(new_item, length + 1, false)
    local group = 1
    SetOnlyTrackSelected(first_track)
    SetEditCurPos(0, false, false)
    local workflow = "vertical"
    Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    repeat
        horizontal_group(workflow, group)
        group = group + 1
        Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    until IsMediaItemSelected(new_item) == true

    DeleteTrackMediaItem(first_track, new_item)
    local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
    local start = 2
    Main_OnCommand(next_folder, 0) -- select next folder

    for i = start, num_of_folders, 1 do
        vertical_razor()
        local colors = get_color_table()
        if i == start then
            local selected_items = count_selected_media_items()
            for j = 0, selected_items - 1 do
                local item = get_selected_media_item_at(j)
                if item then
                    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", colors.edited_material)
                end
            end
        end
        local next_group = vertical_group(length, group)
        Main_OnCommand(next_folder, 0) -- select next folder
        group = next_group
    end
    SelectAllMediaItems(0, false)
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    SetEditCurPos(0, false, false)
end

---------------------------------------------------------------------

function empty_items_check(num_of_items)
    local count = 0
    for i = 0, num_of_items - 1, 1 do
        local current_item = GetMediaItem(0, i)
        local take = GetActiveTake(current_item)
        if not take then
            count = count + 1
        end
    end
    return count
end

---------------------------------------------------------------------

function folder_check()
    local folders = 0
    local tracks_per_group = 1
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^REF")

        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        elseif folders == 1 and not (special_states or special_names) then
            tracks_per_group = tracks_per_group + 1
        end
    end
    return folders, tracks_per_group, total_tracks
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
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

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
    end
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

---------------------------------------------------------------------

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


---------------------------------------------------------------------

main()
