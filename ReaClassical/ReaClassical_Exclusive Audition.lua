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

local main, solo, bus_check, rt_check, mixer, on_stop

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
    local fade_editor_state = GetToggleCommandState(fade_editor_toggle)
    if fade_editor_state ~= 1 then
        local track, _, pos = BR_TrackAtMouseCursor()
        if track then
            SetOnlyTrackSelected(track)
            solo()
            mixer()
            local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
            Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
            SetEditCurPos(pos, 0, 0)
            OnPlayButton()
            Undo_EndBlock('Audition', 0)
            PreventUIRefresh(-1)
            UpdateArrange()
            UpdateTimeline()
            TrackList_AdjustWindows(false)
        end
    else
        DeleteProjectMarker(NULL, 1000, false)
        local item_one = GetSelectedMediaItem(0, 0)
        local item_two = GetSelectedMediaItem(0, 1)
        local item_one_muted = GetMediaItemInfo_Value(item_one, "B_MUTE")
        local item_two_muted = GetMediaItemInfo_Value(item_two, "B_MUTE")
        if item_one == nil or item_two == nil then
            ShowMessageBox("Please select both items involved in the crossfade", "Crossfade Audition", 0)
            return
        end
        local one_pos = GetMediaItemInfo_Value(item_one, "D_POSITION")
        local one_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
        local two_pos = GetMediaItemInfo_Value(item_two, "D_POSITION")
        Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        BR_GetMouseCursorContext()
        local mouse_pos = BR_GetMouseCursorContext_Position()
        local item_hover = BR_GetMouseCursorContext_Item()
        local end_of_one = one_pos + one_length
        local overlap = end_of_one - two_pos
        local mouse_to_item_two = two_pos - mouse_pos
        local total_time = 2 * mouse_to_item_two + overlap
        if item_hover == item_one then
            local item_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
            SetMediaItemSelected(item_hover, true)
            Main_OnCommand(40034, 0)     -- Item Grouping: Select all items in group(s)
            if item_one_muted == 0 then
                Main_OnCommand(41559, 0) -- Item properties: Solo
            end
            AddProjectMarker2(0, false, one_pos + item_length, 0, "!1016", 1000, ColorToNative(10, 10, 10) | 0x1000000)
            SetEditCurPos(mouse_pos, false, false)
            OnPlayButton() -- play until end of item_hover (one_pos + item_length)
        elseif item_hover == item_two then
            SetMediaItemSelected(item_hover, true)
            Main_OnCommand(40034, 0)     -- Item Grouping: Select all items in group(s)
            if item_two_muted == 0 then
                Main_OnCommand(41559, 0) -- Item properties: Solo
            end
            SetEditCurPos(two_pos, false, false)
            AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1000, ColorToNative(10, 10, 10) | 0x1000000)
            OnPlayButton() -- play until mouse cursor
        elseif not item_hover and mouse_pos < two_pos then
            AddProjectMarker2(0, false, mouse_pos + total_time, 0, "!1016", 1000,
                ColorToNative(10, 10, 10) | 0x1000000)
            SetEditCurPos(mouse_pos, false, false)
            OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
        else
            local mouse_to_item_one = mouse_pos - end_of_one
            local total_time = 2 * mouse_to_item_one + overlap
            AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1000,
                ColorToNative(10, 10, 10) | 0x1000000)
            AddProjectMarker2(0, false, mouse_pos - total_time, 0, "START", 1001,
                ColorToNative(10, 10, 10) | 0x1000000)
            GoToMarker(0, 1001, false)
            OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
            DeleteProjectMarker(NULL, 1001, false)
        end
        SetMediaItemSelected(item_one, true)
        SetMediaItemSelected(item_two, true)
        SetEditCurPos(two_pos + (overlap / 2), false, false)
        on_stop()
        Undo_EndBlock('Audition', 0)
        PreventUIRefresh(-1)
        UpdateArrange()
        UpdateTimeline()
        TrackList_AdjustWindows(false)
    end
end

---------------------------------------------------------------------

function solo()
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if IsTrackSelected(track) == true then
            SetMediaTrackInfo_Value(track, "I_SOLO", 1)
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        elseif not (bus_check(track) or rt_check(track)) and IsTrackSelected(track) == false then
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end

        local solo = GetMediaTrackInfo_Value(track, "I_SOLO")
    
        if rt_check(track) and solo > 0 then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end

    if parent ~= 1 and not rt_check(selected_track) then
        local parent_track = GetParentTrack(selected_track)
        SetMediaTrackInfo_Value(parent_track, "B_MUTE", 0)
    end
end

---------------------------------------------------------------------

function bus_check(track)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, "^@")
end

---------------------------------------------------------------------

function rt_check(track)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, "^RoomTone")
end

---------------------------------------------------------------------

function mixer()
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if bus_check(track) then
            local native_color = ColorToNative(76, 145, 101)
            SetTrackColor(track, native_color)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if rt_check(track) then
            local native_color = ColorToNative(20, 120, 230)
            SetTrackColor(track, native_color)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if IsTrackSelected(track) or bus_check(track) or rt_check(track) then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end
    end
end

---------------------------------------------------------------------

function on_stop()
    if GetPlayState() == 0 then
        DeleteProjectMarker(NULL, 1000, false)
        Main_OnCommand(41185, 0) -- Item properties: Unsolo all
        return
    else
        defer(on_stop)
    end
end

---------------------------------------------------------------------

main()