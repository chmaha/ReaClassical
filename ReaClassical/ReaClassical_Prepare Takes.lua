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

local main, shift, horizontal_color, vertical_color_razor, horizontal_group
local vertical_group, horizontal, vertical, get_color_table
local xfade_check, empty_items_check, get_path, folder_check
local trackname_check

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end

    local num_pre_selected = CountSelectedTracks(0)
    local pre_selected = {}
    if num_pre_selected > 0 then
        for i = 0, num_pre_selected - 1, 1 do
            local track = GetSelectedTrack(0, i)
            table.insert(pre_selected, track)
        end
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

    PreventUIRefresh(1)
    Undo_BeginBlock()

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

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local colors = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[5] then colors = tonumber(table[5]) or 0 end
    end

    if folders == 0 or folders == 1 then
        horizontal(colors)
    else
        vertical(colors)
    end

    GetSet_ArrangeView2(0, true, 0, 0, start_time, end_time)
    SetEditCurPos(cur_pos, 0, 0)

    local scroll_up = NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
    Main_OnCommand(scroll_up, 0)

    if num_pre_selected > 0 then
        Main_OnCommand(40297, 0) --unselect_all
        SetOnlyTrackSelected(pre_selected[1])
        for _, track in ipairs(pre_selected) do
            if pcall(IsTrackSelected, track) then SetTrackSelected(track, 1) end
        end
    end

    MB("Project takes have been prepared! " ..
        "You can run again if you import or record more material..."
        , "ReaClassical", 0)

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

function horizontal_color(flip, edits, colors)
    if colors == 1 then
        Main_OnCommand(40706, 0) -- Item: Set to one random color
    else
        colors = get_color_table()
        local color
        if flip then
            color = colors.dest_items_two
        else
            color = colors.dest_items_one
        end

        local num_of_items = CountSelectedMediaItems(0)
        if edits then
            for i = 0, num_of_items - 1, 1 do
                local item = GetSelectedMediaItem(0, i)
                local current_color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
                if current_color == 0 or current_color == colors.dest_items_one
                    or current_color == colors.dest_items_two or current_color == colors.source_items then
                    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
                end
            end
        else
            for i = 0, num_of_items - 1, 1 do
                local item = GetSelectedMediaItem(0, i)
                local current_color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
                if current_color == 0 or current_color == colors.dest_items_one
                    or current_color == colors.dest_items_two or current_color == colors.source_items then
                    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", colors.dest_items_one)
                end
            end
        end
    end
end

---------------------------------------------------------------------

function vertical_color_razor(colors)
    Main_OnCommand(40042, 0)           -- Transport: Go to start of project
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- Select child tracks
    Main_OnCommand(42579, 0)           -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40421, 0)           -- Item: Select all items in track
    if colors == 1 then
        Main_OnCommand(40706, 0)       -- Item: Set to one random color
    else
        local color_table = get_color_table()
        local selected_items = CountSelectedMediaItems(0)
        for i = 0, selected_items - 1, 1 do
            local item = GetSelectedMediaItem(0, i)
            local current_color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
            if current_color == 0 or current_color == color_table.dest_items_one
                or current_color == color_table.dest_items_two or current_color == color_table.source_items then
                SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_table.source_items)
            end
        end
    end
end

---------------------------------------------------------------------

function horizontal_group(string, group)
    if string == "horizontal" then
        Main_OnCommand(40296, 0) -- Track: Select all tracks
    else
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- Select child tracks
    end

    local selected = GetSelectedMediaItem(0, 0)
    local start = GetMediaItemInfo_Value(selected, "D_POSITION")
    local length = GetMediaItemInfo_Value(selected, "D_LENGTH")
    SetEditCurPos(start + (length / 2), false, false) -- move to middle of item
    local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_under, 0)                   -- XENAKIOS_SELITEMSUNDEDCURSELTX

    local num_selected_items = CountSelectedMediaItems(0)
    for i = 0, num_selected_items - 1 do
        local item = GetSelectedMediaItem(0, i)
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
        local selected = GetSelectedMediaItem(0, 0)
        local start = GetMediaItemInfo_Value(selected, "D_POSITION")
        local item_length = GetMediaItemInfo_Value(selected, "D_LENGTH")
        SetEditCurPos(start + (item_length / 2), false, false) -- move to middle of item
        local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
        Main_OnCommand(select_under, 0)                        -- XENAKIOS_SELITEMSUNDEDCURSELTX

        local num_selected_items = CountSelectedMediaItems(0)
        for i = 0, num_selected_items - 1 do
            local selected_item = GetSelectedMediaItem(0, i)
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

function horizontal(colors)
    local edits = xfade_check()
    local length = GetProjectLength(0)
    local first_track = GetTrack(0, 0)
    local new_item = AddMediaItemToTrack(first_track)
    SetMediaItemPosition(new_item, length + 1, false)

    if first_track then
        SetOnlyTrackSelected(first_track) -- Select only the first track
    end
    SetEditCurPos(0, false, false)

    local flip = false
    local workflow = "horizontal"
    local group = 1
    Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    repeat
        horizontal_group(workflow, group)
        horizontal_color(flip, edits, colors)
        flip = not flip
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

function vertical(colors)
    local edits = xfade_check()
    local select_all_folders = NamedCommandLookup("_SWS_SELALLPARENTS")
    Main_OnCommand(select_all_folders, 0) -- select all folders
    local num_of_folders = CountSelectedTracks(0)
    local length = GetProjectLength(0)
    local first_track = GetTrack(0, 0)

    local new_item = AddMediaItemToTrack(first_track)
    SetMediaItemPosition(new_item, length + 1, false)
    local group = 1
    SetOnlyTrackSelected(first_track)
    if colors == 0 then
        -- color destination items the same as horizontal workflow
        SetEditCurPos(0, false, false)
        local workflow = "vertical"
        local flip = false
        Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
        repeat
            horizontal_group(workflow, group)
            horizontal_color(flip, edits, colors)
            flip = not flip
            group = group + 1
            Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
        until IsMediaItemSelected(new_item) == true
    end

    DeleteTrackMediaItem(first_track, new_item)
    local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
    local start = 1
    if colors == 0 then
        start = 2
        Main_OnCommand(next_folder, 0) -- select next folder
    end

    for _ = start, num_of_folders, 1 do
        vertical_color_razor(colors)
        local next_group = vertical_group(length, group)
        Main_OnCommand(next_folder, 0) -- select next folder
        group = next_group
    end
    SelectAllMediaItems(0, false)
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    SetEditCurPos(0, false, false)
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

main()
