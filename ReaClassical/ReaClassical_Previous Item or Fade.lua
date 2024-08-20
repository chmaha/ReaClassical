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

local main, move_to_item, deselect, select_check, exit_check
local lock_previous_items, fadeStart, fadeEnd, zoom, view
local lock_items, unlock_items, save_color, paint, load_color
local move_cur_to_mid

local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")

---------------------------------------------------------------------

function main()
    local win_state = GetToggleCommandState(41827)

    if win_state ~= 1 then
        move_to_item()
        deselect()
    else
        local sel = fadeEnd()
        if sel == -1 then
            return
        end
        move_to_item()
        move_to_item()
        local check = select_check()
        move_cur_to_mid(check)
        lock_previous_items(check)
        fadeStart()
        UpdateArrange()
        UpdateTimeline()
    end
end

---------------------------------------------------------------------

function move_to_item()
    Main_OnCommand(41167, 0) -- Move cursor left to nearest item edge
    local item = GetSelectedMediaItem(0, 0)
    return item
end

---------------------------------------------------------------------

function deselect()
    Main_OnCommand(40289, 0) -- deselect all items
end

---------------------------------------------------------------------

function select_check()
    local item = GetSelectedMediaItem(0, 0)
    if item ~= nil then
        local item_position = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_position + item_length
    end
    return item
end

---------------------------------------------------------------------

function exit_check()
    local item = GetSelectedMediaItem(0, 0)
    if item then
        local color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
        return item
    else
        return -1
    end
end

---------------------------------------------------------------------

function lock_previous_items(item)
    local num = GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
    local first_track = GetTrack(0, 0)
    for i = 0, num do
        item = GetTrackMediaItem(first_track, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 1)
    end
end

---------------------------------------------------------------------

function fadeStart()
    SetToggleCommandState(1, fade_editor_toggle, 1)
    local item1 = GetSelectedMediaItem(0, 0)
    save_color("1", item1)
    paint(item1, 32648759)
    Main_OnCommand(40311, 0) -- Set ripple editing all tracks
    lock_items()
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    RefreshToolbar2(1, fade_editor_toggle)
    local start_time, end_time = GetSet_ArrangeView2(0, false, 0, 0, 0, 0)
    SetProjExtState(0, "Classical Crossfade Editor", "start_time", start_time)
    SetProjExtState(0, "Classical Crossfade Editor", "end_time", end_time)
    local select_1 = NamedCommandLookup("_SWS_SEL1") -- SWS: Select only track 1
    Main_OnCommand(select_1, 0)
    Main_OnCommand(40319, 0)                         -- move edit cursor to end of item
    view()
    zoom()
    SetMediaItemSelected(item1, true)
    local select_next = NamedCommandLookup("_SWS_SELNEXTITEM2") -- SWS: Select next item, keeping current selection (across tracks)
    Main_OnCommand(select_next, 0)
    local item2 = GetSelectedMediaItem(0, 1)
    save_color("2", item2)
    paint(item2, 20967993)
end

---------------------------------------------------------------------

function fadeEnd()
    local item = exit_check()
    if item == -1 then
        ShowMessageBox("Please select the left or right item of the crossfade pair to move to another crossfade",
            "Crossfade Editor", 0)
        return -1
    end
    local color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
    if color == 20967993 then -- if green
        local prev_item = NamedCommandLookup("_SWS_SELPREVITEM2")
        Main_OnCommand(prev_item, 0)
        item = GetSelectedMediaItem(0, 0)
    end
    local first_color = load_color("1", item)
    paint(item, first_color)
    local select_next_item = NamedCommandLookup("_SWS_SELNEXTITEM2")
    Main_OnCommand(select_next_item, 0)
    local item2 = GetSelectedMediaItem(0, 1)
    local second_color = load_color("2", item2)
    paint(item2, second_color)
    SetToggleCommandState(1, fade_editor_toggle, 0)
    RefreshToolbar2(1, fade_editor_toggle)
    unlock_items()
    move_cur_to_mid(item)
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    SetMediaItemSelected(item, 1)
    view()
    local _, start_time = GetProjExtState(0, "Classical Crossfade Editor", "start_time")
    local _, end_time = GetProjExtState(0, "Classical Crossfade Editor", "end_time")
    GetSet_ArrangeView2(0, true, 0, 0, start_time, end_time)
    Main_OnCommand(40310, 0) -- Set ripple editing per-track
    return 1
end

---------------------------------------------------------------------

function zoom()
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    SetEditCurPos(cur_pos - 3, false, false)
    Main_OnCommand(40625, 0) -- Time selection: Set start point
    SetEditCurPos(cur_pos + 3, false, false)
    Main_OnCommand(40626, 0) -- Time selection: Set end point
    local zoom = NamedCommandLookup("_SWS_ZOOMSIT")
    Main_OnCommand(zoom, 0)  -- SWS: Zoom to selected items or time selection
    SetEditCurPos(cur_pos, false, false)
    Main_OnCommand(1012, 0)  -- View: Zoom in horizontal
    Main_OnCommand(40635, 0) -- Time selection: Remove (unselect) time selection
end

---------------------------------------------------------------------

function view()
    local track1 = NamedCommandLookup("_SWS_SEL1")
    local tog_state = GetToggleCommandState(fade_editor_toggle)
    local overlap_state = GetToggleCommandState(40507)
    Main_OnCommand(track1, 0) -- select only track 1

    local max_height = GetToggleCommandState(40113)
    if max_height ~= tog_state then
        Main_OnCommand(40113, 0) -- View: Toggle track zoom to maximum height
    end

    if overlap_state ~= tog_state then
        Main_OnCommand(40507, 0) -- Options: Offset overlapping media items vertically
    end

    local scroll_home = NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
    Main_OnCommand(scroll_home, 0) -- XENAKIOS_TVPAGEHOME
end

---------------------------------------------------------------------

function lock_items()
    Main_OnCommand(40182, 0)           -- select all items
    Main_OnCommand(40939, 0)           -- select track 01
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- select children of track 1
    local unselect_items = NamedCommandLookup("_SWS_UNSELONTRACKS")
    Main_OnCommand(unselect_items, 0)  -- unselect items in first folder
    local total_items = CountSelectedMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetSelectedMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 1)
    end
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
    SetProjExtState(0, "Classical Crossfade Editor", "item" .. " " .. num .. " color", color) -- save to project file
end

---------------------------------------------------------------------

function paint(item, color)
    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
end

---------------------------------------------------------------------

function load_color(num, item)
    local _, color = GetProjExtState(0, "Classical Crossfade Editor", "item" .. " " .. num .. " color")
    return color
end

---------------------------------------------------------------------

function move_cur_to_mid(item)
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
    SetEditCurPos(pos + len / 2, false, false)
end

---------------------------------------------------------------------

main()
