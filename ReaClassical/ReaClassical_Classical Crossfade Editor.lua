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

local main, select_check, lock_previous_items, fadeStart
local fadeEnd, zoom, view, unlock_items, save_color
local paint, load_color, move_back_cursor, folder_check, correct_item_positions
local check_next_item_overlap, trackname_check, get_color_table, get_path, get_reaper_version
local get_selected_media_item_at, count_selected_media_items
---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local sdmousehover = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[8] then sdmousehover = tonumber(table[8]) or 0 end
end

local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
local state = GetToggleCommandState(fade_editor_toggle)

function main()
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    PreventUIRefresh(1)
    local reaper_ver = get_reaper_version()
    if reaper_ver >= 7.40 then
        local reaper_xfade_toggle = GetToggleCommandState(41827)
        if reaper_xfade_toggle == 0 or reaper_xfade_toggle == -1 then
            if sdmousehover == 1 then
                BR_GetMouseCursorContext()
                local hover_item = BR_GetMouseCursorContext_Item()
                if hover_item ~= nil then
                    Main_OnCommand(40289, 0) -- Item: Unselect all items
                    SetMediaItemSelected(hover_item, 1)
                end
            end
            local _, item1 = select_check()
            if item1 and check_next_item_overlap(item1) then
                Main_OnCommand(41827, 0)
            else
                if sdmousehover == 1 then
                    MB("Please hover over the right item of a crossfaded pair", "Crossfade Editor", 0)
                else
                    MB("Please select the right item of a crossfaded pair", "Crossfade Editor", 0)
                end
            end
        local lock_fade = GetToggleCommandStateEx(32065, 43592)
        if lock_fade == 0 then CrossfadeEditor_OnCommand(43592) end -- set fade lock
        elseif reaper_xfade_toggle == 1 then
            Main_OnCommand(41827, 0)
        end
    else
        local group_state = GetToggleCommandState(1156)
        if group_state ~= 1 then
            Main_OnCommand(1156, 0) -- Enable item grouping
        end
        if state == -1 or state == 0 then
            if sdmousehover == 1 then
                BR_GetMouseCursorContext()
                local hover_item = BR_GetMouseCursorContext_Item()
                if hover_item ~= nil then
                    Main_OnCommand(40289, 0) -- Item: Unselect all items
                    SetMediaItemSelected(hover_item, 1)
                end
            end
            local selected_item, item1 = select_check()
            if item1 and check_next_item_overlap(item1) then
                local orig_item_guid = BR_GetMediaItemGUID(selected_item)
                SetProjExtState(0, "ReaClassical", "OrigSelectedItem", orig_item_guid)
                fadeStart(item1, workflow)
            else
                if sdmousehover == 1 then
                    MB("Please hover over the right item of a crossfaded pair on track 1", "Crossfade Editor", 0)
                else
                    MB("Please select the right item of a crossfaded pair on track 1", "Crossfade Editor", 0)
                end
            end
        else
            fadeEnd()
        end
    end
    PreventUIRefresh(-1)
    Undo_EndBlock('Classical Crossfade Editor', 0)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function select_check()
    local selected_item = get_selected_media_item_at(0)

    if not selected_item then
        return false
    end

    local track = GetMediaItemTrack(selected_item)
    local track_num = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

    if track_num ~= 1 then
        return false
    end

    local current_item_index = GetMediaItemInfo_Value(selected_item, "IP_ITEMNUMBER")
    local prev_item = GetTrackMediaItem(track, current_item_index - 1)

    return prev_item and selected_item, prev_item or false
end

---------------------------------------------------------------------

function lock_previous_items(item)
    local tracks_per_group = folder_check()
    local first_item_pos = GetMediaItemInfo_Value(item, "D_POSITION")

    local track_1 = GetTrack(0, 0)
    local top_item_count = CountTrackMediaItems(track_1)

    local locked_group_ids = {} -- Store group IDs of locked items

    -- Iterate through all items in track 1 and lock those before the specified item
    for i = 0, top_item_count - 1 do
        local track_1_item = GetTrackMediaItem(track_1, i)
        if track_1_item then
            local track_1_item_pos = GetMediaItemInfo_Value(track_1_item, "D_POSITION") -- Get the item's position

            -- Lock the item and store its group ID if it's before the specified item
            if track_1_item_pos < first_item_pos then
                SetMediaItemInfo_Value(track_1_item, "C_LOCK", 1)
                local item_group_id = GetMediaItemInfo_Value(track_1_item, "I_GROUPID")
                table.insert(locked_group_ids, item_group_id)
            end
        end
    end

    local parent_item_start = GetMediaItemInfo_Value(item, "D_POSITION")

    -- Check items in lower tracks
    for t = 1, tracks_per_group - 1 do
        local track = GetTrack(0, t)
        if track then
            local lower_item_count = CountTrackMediaItems(track)

            for i = 0, lower_item_count - 1 do
                local track_item = GetTrackMediaItem(track, i)
                if track_item then
                    local track_item_start = GetMediaItemInfo_Value(track_item, "D_POSITION")
                    local track_item_group_id = GetMediaItemInfo_Value(track_item, "I_GROUPID")

                    -- Check for Group ID match
                    for _, group_id in ipairs(locked_group_ids) do
                        if track_item_group_id == group_id and (track_item_start < parent_item_start - 0.00001) then
                            SetMediaItemInfo_Value(track_item, "C_LOCK", 1)
                            break
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------

function fadeStart(item1, workflow)
    local cur_pos = GetCursorPosition()
    SetProjExtState(0, "ReaClassical", "ArrangeCurPos", cur_pos)
    SetToggleCommandState(1, fade_editor_toggle, 1)
    local item1_start = GetMediaItemInfo_Value(item1, "D_POSITION")
    local item1_length = GetMediaItemInfo_Value(item1, "D_LENGTH")
    local item1_right_edge = item1_start + item1_length
    SetProjExtState(0, "ReaClassical", "FirstItemPos", item1_start)
    local item1_take = GetActiveTake(item1)
    local item1_take_offset = GetMediaItemTakeInfo_Value(item1_take, "D_STARTOFFS")
    SetProjExtState(0, "ReaClassical", "FirstItemOffset", item1_take_offset)
    local item1_guid = BR_GetMediaItemGUID(item1)
    SetProjExtState(0, "ReaClassical", "FirstItemGUID", item1_guid)
    save_color("1", item1)
    local colors = get_color_table()
    paint(item1, colors.xfade_red)

    if workflow == "Horizontal" then
        Main_OnCommand(40311, 0) -- Set ripple-all-tracks
    else
        Main_OnCommand(40310, 0) -- Set ripple-per-track
    end


    Main_OnCommand(40289, 0) -- Item: Unselect all items
    local start_time, end_time = GetSet_ArrangeView2(0, false, 0, 0, 0, false)
    SetProjExtState(0, "ReaClassical", "arrangestarttime", start_time)
    SetProjExtState(0, "ReaClassical", "arrangeendtime", end_time)
    local select_1 = NamedCommandLookup("_SWS_SEL1") -- SWS: Select only track 1
    Main_OnCommand(select_1, 0)
    SetEditCurPos(item1_right_edge, false, false)
    view()
    zoom()
    SetMediaItemSelected(item1, true)
    local select_next = NamedCommandLookup("_SWS_SELNEXTITEM2") -- SWS: Select next item, keeping current selection
    Main_OnCommand(select_next, 0)
    local item2 = get_selected_media_item_at(1)
    local item2_guid = BR_GetMediaItemGUID(item2)
    SetProjExtState(0, "ReaClassical", "SecondItemGUID", item2_guid)
    if item2 then
        save_color("2", item2)
        paint(item2, colors.xfade_green)
        -- group_parent_and_children()
    end
    lock_previous_items(item1)
    SetMediaItemSelected(item1, false)
end

---------------------------------------------------------------------

function fadeEnd()
    SetToggleCommandState(1, fade_editor_toggle, 0)

    local _, item1_guid = GetProjExtState(0, "ReaClassical", "FirstItemGUID")
    local _, item2_guid = GetProjExtState(0, "ReaClassical", "SecondItemGUID")
    local item1 = BR_GetMediaItemByGUID(0, item1_guid)
    local item2 = BR_GetMediaItemByGUID(0, item2_guid)

    local first_color = load_color("1")
    paint(item1, first_color)
    if item2 then
        local second_color = load_color("2")
        paint(item2, second_color)
    end

    correct_item_positions(item1)
    unlock_items()
    move_back_cursor()

    Main_OnCommand(40289, 0) -- Item: Unselect all items
    local _, orig_item_guid = GetProjExtState(0, "ReaClassical", "OrigSelectedItem")
    local orig_selected_item = BR_GetMediaItemByGUID(0, orig_item_guid)
    if orig_selected_item then
        SetMediaItemSelected(orig_selected_item, true)
    end

    view()
    local _, start_time = GetProjExtState(0, "ReaClassical", "arrangestarttime")
    local _, end_time = GetProjExtState(0, "ReaClassical", "arrangeendtime")
    GetSet_ArrangeView2(0, true, 0, 0, start_time, end_time)
    Main_OnCommand(40310, 0) -- Set ripple editing per-track

    SetProjExtState(0, "ReaClassical", "FirstItemPos", "")
    SetProjExtState(0, "ReaClassical", "FirstItemOffset", "")
    SetProjExtState(0, "ReaClassical", "arrangestarttime", "")
    SetProjExtState(0, "ReaClassical", "arrangeendtime", "")
    SetProjExtState(0, "ReaClassical", "item1" .. "color", "")
    SetProjExtState(0, "ReaClassical", "item2" .. "color", "")
    SetProjExtState(0, "ReaClassical", "FirstItemGUID", "")
    SetProjExtState(0, "ReaClassical", "SecondItemGUID", "")
    SetProjExtState(0, "ReaClassical", "ArrangeCurpos", "")
    SetProjExtState(0, "ReaClassical", "OrigSelectedItem", "")
end

---------------------------------------------------------------------

function zoom()
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    SetEditCurPos(cur_pos - 3, false, false)
    Main_OnCommand(40625, 0)             -- Time selection: Set start point
    SetEditCurPos(cur_pos + 3, false, false)
    Main_OnCommand(40626, 0)             -- Time selection: Set end point
    local zoom_to_selection = NamedCommandLookup("_SWS_ZOOMSIT")
    Main_OnCommand(zoom_to_selection, 0) -- SWS: Zoom to selected items or time selection
    SetEditCurPos(cur_pos, false, false)
    Main_OnCommand(1012, 0)              -- View: Zoom in horizontal
    Main_OnCommand(40635, 0)             -- Time selection: Remove (unselect) time selection
end

---------------------------------------------------------------------

function view()
    local track1 = NamedCommandLookup("_SWS_SEL1")
    local tog_state = GetToggleCommandState(fade_editor_toggle)
    local win_state = GetToggleCommandState(41827)
    local overlap_state = GetToggleCommandState(40507)
    Main_OnCommand(track1, 0) -- select only track 1

    local max_height = GetToggleCommandState(40113)
    if max_height ~= tog_state then
        Main_OnCommand(40113, 0) -- View: Toggle track zoom to maximum height
    end

    if overlap_state ~= tog_state then
        Main_OnCommand(40507, 0) -- Options: Offset overlapping media items vertically
    end

    if tog_state ~= win_state then
        Main_OnCommand(41827, 0) -- View: Show crossfade editor window
    end

    local scroll_home = NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
    Main_OnCommand(scroll_home, 0) -- XENAKIOS_TVPAGEHOME
end

---------------------------------------------------------------------

function unlock_items()
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 0)
    end
end

---------------------------------------------------------------------

function save_color(num, item)
    local color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
    SetProjExtState(0, "ReaClassical", "item" .. num .. "color", color) -- save to project file
end

---------------------------------------------------------------------

function paint(item, color)
    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
end

---------------------------------------------------------------------

function load_color(num)
    local _, color = GetProjExtState(0, "ReaClassical", "item" .. num .. "color")
    return color
end

---------------------------------------------------------------------

function move_back_cursor()
    local _, cur_pos = GetProjExtState(0, "ReaClassical", "ArrangeCurPos")
    SetEditCurPos(cur_pos, false, false)
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
    return tracks_per_group
end

---------------------------------------------------------------------

function correct_item_positions(item1)
    local _, item1_orig_pos = GetProjExtState(0, "ReaClassical", "FirstItemPos")
    local _, item1_orig_offset = GetProjExtState(0, "ReaClassical", "FirstItemOffset")
    local item1_take = GetActiveTake(item1)
    local item1_new_offset = GetMediaItemTakeInfo_Value(item1_take, "D_STARTOFFS")
    local offset_amount = item1_new_offset - item1_orig_offset
    if item1_orig_pos ~= "" then
        local item1_new_pos = GetMediaItemInfo_Value(item1, "D_POSITION")
        local move_amount = item1_new_pos - item1_orig_pos
        local item_count = CountMediaItems(0)
        if move_amount > 0 then
            for i = 0, item_count - 1 do
                local item = GetMediaItem(0, i)
                local item_start_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_locked = GetMediaItemInfo_Value(item, "C_LOCK") -- Get the lock state

                if item_locked == 0 then
                    local corrected_pos = item_start_pos - move_amount
                    SetMediaItemInfo_Value(item, "D_POSITION", corrected_pos)
                end
            end
        elseif move_amount < 0 then
            for i = item_count - 1, 0, -1 do
                local item = GetMediaItem(0, i)
                local item_start_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_locked = GetMediaItemInfo_Value(item, "C_LOCK") -- Get the lock state

                if item_locked == 0 then
                    local corrected_pos = item_start_pos - move_amount
                    SetMediaItemInfo_Value(item, "D_POSITION", corrected_pos)
                end
            end
        end
        MoveEditCursor(-move_amount, false)
    end
    if item1_orig_offset ~= "" and math.abs(offset_amount) > 1e-10 then
        Main_OnCommand(40289, 0)                       -- unselect all items
        SetMediaItemSelected(item1, true)
        Main_OnCommand(40034, 0)                       -- Item Grouping: Select all items in group(s)
        local num_items = count_selected_media_items() -- Get the number of selected items
        for i = 0, num_items - 1 do
            local item = get_selected_media_item_at(i) -- Get the selected media item
            local take = GetActiveTake(item)
            if take then
                local item_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")          -- Get the active take
                SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", item_offset - offset_amount) -- Set the offset
            end
        end
        Main_OnCommand(40289, 0) -- unselect all items
        SetMediaItemSelected(item1, true)
    end
    if math.abs(offset_amount) > 1e-10 then
        MB(
            "WARNING: The left item of the crossfade was accidentally slip-edited.\n" ..
            "The item's position and offset have been reset to original values " ..
            "but the current crossfade may need attention.",
            "Crossfade Editor", 0)
    end
end

---------------------------------------------------------------------

function check_next_item_overlap(current_item)
    local track = GetMediaItemTrack(current_item)
    if not track then
        return false
    end
    local current_item_index = GetMediaItemInfo_Value(current_item, "IP_ITEMNUMBER")

    local next_item = GetTrackMediaItem(track, current_item_index + 1)

    if not next_item then
        return false
    end

    -- Get the positions and lengths of the items
    local current_item_position = GetMediaItemInfo_Value(current_item, "D_POSITION")
    local current_item_length = GetMediaItemInfo_Value(current_item, "D_LENGTH")
    local current_item_end = current_item_position + current_item_length
    local next_item_position = GetMediaItemInfo_Value(next_item, "D_POSITION")

    -- Check for overlap: next item must start before the current item's end
    if next_item_position >= current_item_end then
        return false
    end
    return true
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

function get_reaper_version()
    local version_str = GetAppVersion()
    local version = version_str:match("^(%d+%.%d+)")
    return tonumber(version)
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
