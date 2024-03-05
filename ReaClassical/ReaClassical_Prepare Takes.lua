--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, shift, horizontal_color, vertical_color_razor, horizontal_group
local vertical_group, horizontal, vertical, copy_track_items
local tracks_per_folder, clean_take_names, xfade_check, empty_items_check

local color_one = ColorToNative(18, 121, 177)|0x1000000
local color_two = ColorToNative(99, 180, 220)|0x1000000
local green = ColorToNative(65, 127, 99)|0x1000000

---------------------------------------------------------------------

function main()

    local num_of_project_items = CountMediaItems(0)
    if num_of_project_items == 0 then
        ShowMessageBox("Please add your takes before running...", "Prepare Takes", 0)
        return
    end
    local empty_count = empty_items_check(num_of_project_items)
    if empty_count > 0 then
        ShowMessageBox("Error: Empty items found. Delete them to continue.", "Prepare Takes", 0)
        return
    end

    PreventUIRefresh(1)
    Undo_BeginBlock()

    local response = ShowMessageBox("Would you like to remove item take names?", "Prepare Takes", 3)
    if response == 2 then return end
    if response == 6 then clean_take_names(num_of_project_items) end
    Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
    local total_tracks = CountTracks(0)
    local folders = 0
    local empty = false
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1.0 then
            folders = folders + 1
            local items = CountTrackMediaItems(track)
            if items == 0 then
                empty = true
            end
        end
    end

    local first_item = GetMediaItem(0, 0)
    local position = GetMediaItemInfo_Value(first_item, "D_POSITION")
    if position == 0.0 then
        shift()
    end

    if empty then
        local folder_size = tracks_per_folder()
        copy_track_items(folder_size, total_tracks)
    end

    if folders == 0 or folders == 1 then
        horizontal()
    else
        vertical()
    end

    Main_OnCommand(40042, 0) -- go to start of project
    Main_OnCommand(40939, 0) -- select track 01

    if empty then
        ShowMessageBox(
            "Some folder tracks are empty. If the folders are not completely empty, items from first child tracks were copied to folder tracks and muted to act as guide tracks."
            , "Guide Tracks Created", 0)
    end
    Undo_EndBlock('Prepare Takes', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function shift()
    Main_OnCommand(40182, 0)       -- select all items
    local nudge_right = NamedCommandLookup("_SWS_NUDGESAMPLERIGHT")
    Main_OnCommand(nudge_right, 0) -- shift items by 1 sample to the right
    Main_OnCommand(40289, 0)       -- unselect all items
end

---------------------------------------------------------------------

function horizontal_color(flip, edits)
    local color
    if flip then 
        color = color_two
    else 
        color = color_one
    end

    local num_of_items = CountSelectedMediaItems(0)
    if edits then
        for i=0, num_of_items-1, 1 do
            local item = GetSelectedMediaItem(0,i)
            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
        end
    else
        for i=0, num_of_items-1, 1 do
            local item = GetSelectedMediaItem(0,i)
            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_one)
        end
    end
end

---------------------------------------------------------------------

function vertical_color_razor()
    Main_OnCommand(40042, 0)           -- Transport: Go to start of project
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- Select child tracks
    Main_OnCommand(42579, 0)           -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40421, 0)           -- Item: Select all items in track
    --Main_OnCommand(40706, 0)           -- Item: Set to one random color
    local selected_items = CountSelectedMediaItems(0)
    for i=0, selected_items-1, 1 do
        local item = GetSelectedMediaItem(0,i)
        SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", green)
    end
    end

---------------------------------------------------------------------

function horizontal_group(string)
    if string == "horizontal" then
        Main_OnCommand(40296, 0)        -- Track: Select all tracks
    else
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- Select child tracks
    end

    Main_OnCommand(40417, 0)        -- Item navigation: Select and move to next item
    local selected = GetSelectedMediaItem(0, 0)
    local start = GetMediaItemInfo_Value(selected, "D_POSITION")
    local length = GetMediaItemInfo_Value(selected, "D_LENGTH")
    SetEditCurPos(start+(length/2), false, false) -- move to middle of item
    local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_under, 0) -- XENAKIOS_SELITEMSUNDEDCURSELTX
    Main_OnCommand(40032, 0)        -- Item grouping: Group items
end

---------------------------------------------------------------------

function vertical_group(length)
    local track = GetSelectedTrack(0, 0)
    local item = AddMediaItemToTrack(track)
    SetMediaItemPosition(item, length + 1, false)

    while IsMediaItemSelected(item) == false do
        Main_OnCommand(40417, 0)        -- Item navigation: Select and move to next item
        local selected = GetSelectedMediaItem(0, 0)
        local start = GetMediaItemInfo_Value(selected, "D_POSITION")
        local length = GetMediaItemInfo_Value(selected, "D_LENGTH")
        SetEditCurPos(start+(length/2), false, false) -- move to middle of item
        local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
        Main_OnCommand(select_under, 0) -- XENAKIOS_SELITEMSUNDEDCURSELTX
        Main_OnCommand(40032, 0)        -- Item grouping: Group items
    end
    DeleteTrackMediaItem(track, item)
end

---------------------------------------------------------------------

function horizontal()
    local edits = xfade_check()
    local length = GetProjectLength(0)
    local first_track = GetTrack(0, 0)
    local new_item = AddMediaItemToTrack(first_track)
    SetMediaItemPosition(new_item, length + 1, false)
    SetEditCurPos(0, false, false)

    local flip = false
    local workflow = "horizontal"
    while IsMediaItemSelected(new_item) == false do
        horizontal_group(workflow)
        horizontal_color(flip, edits)
        flip = not flip
    end

    DeleteTrackMediaItem(first_track, new_item)
    SelectAllMediaItems(0, false)
    Main_OnCommand(42579, 0) -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    SetEditCurPos(0, false, false)
end

---------------------------------------------------------------------

function vertical()
    local edits = xfade_check()
    local select_all_folders = NamedCommandLookup("_SWS_SELALLPARENTS")
    Main_OnCommand(select_all_folders, 0) -- select all folders
    local num_of_folders = CountSelectedTracks(0)
    local length = GetProjectLength(0)
    local first_track = GetTrack(0, 0)

    local new_item = AddMediaItemToTrack(first_track)
    SetMediaItemPosition(new_item, length + 1, false)

    SetOnlyTrackSelected(first_track)


    -- color destination items the same as horizontal workflow
    SetEditCurPos(0, false, false)
    local workflow = "vertical"
    local flip = false
    while IsMediaItemSelected(new_item) == false do
        horizontal_group(workflow)
        horizontal_color(flip, edits)
        flip = not flip
    end

    local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
    DeleteTrackMediaItem(first_track, new_item)

    Main_OnCommand(next_folder, 0) -- select next folder

    for _ = 2, num_of_folders, 1 do
        vertical_color_razor()
        vertical_group(length)
        Main_OnCommand(next_folder, 0) -- select next folder
    end
    SelectAllMediaItems(0, false)
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    SetEditCurPos(0, false, false)
end

---------------------------------------------------------------------

function copy_track_items(folder_size, total_tracks)
    local pos = 0;
    for i = 1, total_tracks - 1, folder_size do
        local track = GetTrack(0, i)
        local previous_track = GetTrack(0, i - 1)
        local count_items = CountTrackMediaItems(previous_track)
        if count_items > 0 then goto continue end -- guard clause for populated folder
        SetOnlyTrackSelected(track)
        local num_of_items = CountTrackMediaItems(track)
        if num_of_items == 0 then goto continue end -- guard clause for empty first child
        for j = 0, num_of_items - 1 do
            local item = GetTrackMediaItem(track, j)
            if j == 0 then
                pos = GetMediaItemInfo_Value(item, "D_POSITION")
            end
            SetMediaItemSelected(item, 1)
        end
        Main_OnCommand(40698, 0) -- Edit: Copy items
        local previous_track = GetTrack(0, i - 1)
        SetOnlyTrackSelected(previous_track)
        SetEditCurPos(pos, false, false)
        Main_OnCommand(42398, 0) -- Item: Paste items/tracks
        Main_OnCommand(40719, 0) -- Item properties: Mute
        Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
        ::continue::
    end
end

---------------------------------------------------------------------

function tracks_per_folder()
    local first_track = GetTrack(0, 0)
    SetOnlyTrackSelected(first_track)
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
    local selected_tracks = CountSelectedTracks(0)
    Main_OnCommand(40297, 0)           -- Track: Unselect (clear selection of) all tracks
    return selected_tracks
end

---------------------------------------------------------------------

function clean_take_names(num_of_project_items)
    for i = 0, num_of_project_items - 1 do
        local item = GetMediaItem(0, i)
        local take = GetActiveTake(item)
        if take then
            GetSetMediaItemTakeInfo_String(take, "P_NAME", "", true)
        end
    end
end

---------------------------------------------------------------------

function xfade_check()
    local first_track = GetTrack(0, 0)
    local num_of_items = CountTrackMediaItems(first_track)
    local xfade = false
    for i = 0, num_of_items - 2 do
        local item1 = GetTrackMediaItem(first_track, i)
        local item2 = GetTrackMediaItem(first_track, i + 1)
        local pos1 = GetMediaItemInfo_Value(item1, "D_POSITION")
        local pos2 = GetMediaItemInfo_Value(item2, "D_POSITION")
        local len1 = GetMediaItemInfo_Value(item1, "D_LENGTH")
        local end1 = pos1 + len1
        if end1 > pos2 then
            xfade = true
            break
        end
    end
    return xfade
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

main()
