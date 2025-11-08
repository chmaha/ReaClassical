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

local main, shift, color, vertical_razor, group_items
local vertical_group, horizontal, vertical, get_color_table
local xfade_check, empty_items_check, get_path, folder_check
local trackname_check, get_selected_media_item_at, count_selected_media_items
local delete_empty_items, pastel_color, color_tracks_from_first_item
local color_group_items, color_folder_children
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
        delete_empty_items(num_of_project_items)
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

    local edits = false
    if folders == 0 or folders == 1 then
        edits = horizontal()
    else
        vertical()
    end
    PreventUIRefresh(-1)
    color(edits)
    -- color_tracks_from_first_item()
    PreventUIRefresh(1)

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

    local _, silent = GetProjExtState(0, "ReaClassical", "prepare_silent")
    if silent ~= "y" then
        MB("Project takes have been prepared! " ..
            "You can run again if you import or record more material..."
            , "ReaClassical", 0)
    end

    SetProjExtState(0, "ReaClassical", "PreparedTakes", "y")
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

function color(edits)
    local colors = get_color_table()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")

    if workflow == "Horizontal" and not edits then
        local dest_blue = colors.dest_items
        local color_index = 0

        local num_items = CountMediaItems(0)

        -- Step 1: Collect items by group ID
        local groups = {}
        for i = 0, num_items - 1 do
            local item = GetMediaItem(0, i)
            local group_id = GetMediaItemInfo_Value(item, "I_GROUPID") or 0
            if not groups[group_id] then groups[group_id] = {} end
            table.insert(groups[group_id], item)
        end

        -- Step 2: Sort group IDs
        local sorted_group_ids = {}
        for gid in pairs(groups) do table.insert(sorted_group_ids, gid) end
        table.sort(sorted_group_ids)

        -- Step 3: Color each group
        local first_group = true
        for _, gid in ipairs(sorted_group_ids) do
            local group_items = groups[gid]

            -- Skip group if any item is ranked = "y"
            local skip_group = false
            for _, item in ipairs(group_items) do
                local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:ranked", "", false)
                if ranked == "y" then
                    skip_group = true
                    break
                end
            end
            if skip_group then
                color_index = color_index + 1
                goto continue_group
            end

            -- Determine group color
            local group_color = nil
            for _, item in ipairs(group_items) do
                local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                if src_guid ~= "" then
                    local src_item = BR_GetMediaItemByGUID(0, src_guid)
                    if src_item then
                        group_color = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                        break
                    end
                end
            end

            if not group_color then
                if first_group then
                    group_color = dest_blue
                    first_group = false
                else
                    group_color = pastel_color(color_index)
                    color_index = color_index + 1
                end
            end

            -- Apply color to all items in group
            for _, item in ipairs(group_items) do
                color_group_items(item, group_color)
                local color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
                GetSetMediaItemInfo_String(item, "P_EXT:saved_color", color, true)
            end

            -- Color the track of first item
            local first_track = GetMediaItem_Track(group_items[1])
            if first_track then
                SetMediaTrackInfo_Value(first_track, "I_CUSTOMCOLOR", colors.dest_items)
                color_folder_children(first_track, colors.dest_items)
            end

            ::continue_group::
        end
    elseif workflow == "Vertical" then
        local num_tracks = CountTracks(0)
        local first_folder_done = false
        local index_for_folder_pastel = 0

        local pastel_folders = {}
        local dest_folders = {}

        -- First pass: categorize folders
        for t = 0, num_tracks - 1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            local _, dest = GetSetMediaTrackInfo_String(track, "P_EXT:dest_copy", "y", false)
            local is_folder = depth == 1
            local should_color_dest = false

            if is_folder then
                if not first_folder_done then
                    should_color_dest = true
                    first_folder_done = true
                elseif dest == "y" then
                    should_color_dest = true
                end

                if should_color_dest then
                    table.insert(dest_folders, track)
                else
                    table.insert(pastel_folders, track)
                end
            end
        end

        -- Second pass: pastel folders
        for _, track in ipairs(pastel_folders) do
            local num_items = CountTrackMediaItems(track)
            local folder_color = pastel_color(index_for_folder_pastel)
            SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", folder_color)
            index_for_folder_pastel = index_for_folder_pastel + 1
            color_folder_children(track, folder_color)

            -- Color items if not ranked = "y"
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)
                local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:ranked", "", false)
                if ranked ~= "y" then
                    local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                    local color_val = folder_color
                    if src_guid ~= "" then
                        local src_item = BR_GetMediaItemByGUID(0, src_guid)
                        if src_item then
                            color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                        end
                    end
                    color_group_items(item, color_val)
                end
            end
        end

        -- Third pass: dest folders
        for _, track in ipairs(dest_folders) do
            local num_items = CountTrackMediaItems(track)
            local folder_color = colors.dest_items
            SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", folder_color)
            color_folder_children(track, folder_color)

            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)
                local _, ranked = GetSetMediaItemInfo_String(item, "P_EXT:ranked", "", false)
                if ranked ~= "y" then
                    local _, src_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)
                    local color_val = folder_color
                    if src_guid ~= "" then
                        local src_item = BR_GetMediaItemByGUID(0, src_guid)
                        if src_item then
                            color_val = GetMediaItemInfo_Value(src_item, "I_CUSTOMCOLOR")
                        end
                    end
                    color_group_items(item, color_val)
                end
            end
        end
    end
end

---------------------------------------------------------------------

function vertical_razor()
    Main_OnCommand(40042, 0)           -- Transport: Go to start of project
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- Select child tracks
    Main_OnCommand(42579, 0)           -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0)           -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40421, 0)           -- Item: Select all items in trac
end

---------------------------------------------------------------------

function group_items(string, group)
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
    local edits = xfade_check()
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
        group_items(workflow, group)
        group = group + 1
        Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    until IsMediaItemSelected(new_item) == true

    DeleteTrackMediaItem(first_track, new_item)
    SelectAllMediaItems(0, false)
    Main_OnCommand(42579, 0) -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    SetEditCurPos(0, false, false)
    return edits
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
        group_items(workflow, group)
        group = group + 1
        Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    until IsMediaItemSelected(new_item) == true

    DeleteTrackMediaItem(first_track, new_item)
    local next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER")
    local start = 2
    Main_OnCommand(next_folder, 0) -- select next folder

    for _ = start, num_of_folders, 1 do
        local track = GetSelectedTrack(0, 0)
        local _, dest = GetSetMediaTrackInfo_String(track, "P_EXT:dest_copy", "y", false)
        vertical_razor()
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
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^LIVE") or trackname_check(track, "^REF")

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

function delete_empty_items(num_of_project_items)
    for i = num_of_project_items - 1, 0, -1 do
        local item = GetMediaItem(0, i)
        local take = GetActiveTake(item)

        if not take then
            DeleteTrackMediaItem(GetMediaItemTrack(item), item)
        end
    end
end

---------------------------------------------------------------------

function pastel_color(index)
    local golden_ratio_conjugate = 0.61803398875
    local hue                    = (index * golden_ratio_conjugate) % 1.0

    -- Subtle variation in saturation/lightness
    local saturation             = 0.45 + 0.15 * math.sin(index * 1.7)
    local lightness              = 0.70 + 0.1 * math.cos(index * 1.1)

    local function h2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    local q = lightness < 0.5 and (lightness * (1 + saturation))
        or (lightness + saturation - lightness * saturation)
    local p = 2 * lightness - q

    local r = h2rgb(p, q, hue + 1 / 3)
    local g = h2rgb(p, q, hue)
    local b = h2rgb(p, q, hue - 1 / 3)

    local color_int = ColorToNative(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )

    return color_int | 0x1000000
end

---------------------------------------------------------------------

function color_tracks_from_first_item()
    local num_tracks = CountTracks(0)

    for t = 0, num_tracks - 1 do
        local track = GetTrack(0, t)
        local num_items = CountTrackMediaItems(track)

        if num_items > 0 then
            local first_item = GetTrackMediaItem(track, 0)
            local item_color = GetMediaItemInfo_Value(first_item, "I_CUSTOMCOLOR")

            -- Apply the item color to the track if it has a color
            if item_color ~= 0 then
                SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", item_color)
            end
        end
    end
end

---------------------------------------------------------------------

function color_group_items(item, color_val)
    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_val)
    local group = GetMediaItemInfo_Value(item, "I_GROUPID")
    if group > 0 then
        local total = CountMediaItems(0)
        for j = 0, total - 1 do
            local other = GetMediaItem(0, j)
            if GetMediaItemInfo_Value(other, "I_GROUPID") == group then
                SetMediaItemInfo_Value(other, "I_CUSTOMCOLOR", color_val)
            end
        end
    end
end

---------------------------------------------------------------------

function color_folder_children(parent_track, folder_color)
    if not parent_track or not folder_color then return end

    -- get parent index
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)

    -- start from next track
    local idx = parent_idx + 1
    local depth = 1

    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end

        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        -- color current track if still inside folder
        if depth > 0 then
            SetMediaTrackInfo_Value(tr, "I_CUSTOMCOLOR", folder_color)
        end

        depth = depth + folder_depth -- update folder depth AFTER coloring

        if depth <= 0 then
            break -- folder closed
        end

        idx = idx + 1
    end
end

---------------------------------------------------------------------

main()
