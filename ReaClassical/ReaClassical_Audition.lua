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

local main, solo, trackname_check, mixer, on_stop
local get_color_table, get_path

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
            local select_children = NamedCommandLookup("_SWS_SELCHILDREN2") -- SWS: Select children of selected folder track(s)
            Main_OnCommand(select_children, 0)
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
        DeleteProjectMarker(NULL, 1016, false)
        BR_GetMouseCursorContext()
        local hover_item = BR_GetMouseCursorContext_Item()
        if hover_item ~= nil then
            SetMediaItemSelected(hover_item, 1)
            reaper.UpdateArrange()
        end
        local item_one = GetSelectedMediaItem(0, 0)
        local item_two = GetSelectedMediaItem(0, 1)
        if not item_one and not item_two then
            ShowMessageBox("Please select at least one of the items involved in the crossfade", "Audition", 0)
            return
        elseif item_one and not item_two then
            local color = GetMediaItemInfo_Value(item_one, "I_CUSTOMCOLOR")
            if color == 20967993 then
                item_two = item_one
                local prev_item = NamedCommandLookup("_SWS_SELPREVITEM")
                Main_OnCommand(prev_item, 0)
                item_one = GetSelectedMediaItem(0, 0)
            else
                local next_item = NamedCommandLookup("_SWS_SELNEXTITEM")
                Main_OnCommand(next_item, 0)
                item_two = GetSelectedMediaItem(0, 0)
            end
        end
        local item_one_muted = GetMediaItemInfo_Value(item_one, "B_MUTE")
        local item_two_muted = GetMediaItemInfo_Value(item_two, "B_MUTE")

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
        local colors = get_color_table()
        if item_hover == item_one then
            local item_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
            SetMediaItemSelected(item_hover, true)
            Main_OnCommand(40034, 0)     -- Item Grouping: Select all items in group(s)
            if item_one_muted == 0 then
                Main_OnCommand(41559, 0) -- Item properties: Solo
            end
            AddProjectMarker2(0, false, one_pos + item_length, 0, "!1016", 1016, colors.audition)
            SetEditCurPos(mouse_pos, false, false)
            OnPlayButton() -- play until end of item_hover (one_pos + item_length)
        elseif item_hover == item_two then
            SetMediaItemSelected(item_hover, true)
            Main_OnCommand(40034, 0)     -- Item Grouping: Select all items in group(s)
            if item_two_muted == 0 then
                Main_OnCommand(41559, 0) -- Item properties: Solo
            end
            SetEditCurPos(two_pos, false, false)
            AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1016, colors.audition)
            OnPlayButton() -- play until mouse cursor
        elseif not item_hover and mouse_pos < two_pos then
            AddProjectMarker2(0, false, mouse_pos + total_time, 0, "!1016", 1016,
                colors.audition)
            SetEditCurPos(mouse_pos, false, false)
            OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
        else
            local mouse_to_item_one = mouse_pos - end_of_one
            local total_time = 2 * mouse_to_item_one + overlap
            AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1016,
                colors.audition)
            AddProjectMarker2(0, false, mouse_pos - total_time, 0, "START", 1111,
                colors.audition)
            GoToMarker(0, 1111, false)
            OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
            DeleteProjectMarker(NULL, 1111, false)
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
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)

        if (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone") or trackname_check(track, "^REF")) then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")  or trackname_check(track, "^REF") or trackname_check(track, "^RCMASTER")) then
            if IsTrackSelected(track) and parent ~= 1 then
                SetMediaTrackInfo_Value(track, "I_SOLO", 2)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                 SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        local muted = GetMediaTrackInfo_Value(track, "B_MUTE")

        if (trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER")) and muted == 0 then
            local receives = GetTrackNumSends(track, -1)
            for i = 0, receives - 1, 1 do -- loop through receives
                local origin = GetTrackSendInfo_Value(track, -1, i, "P_SRCTRACK")
                if origin == selected_track then
                    SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                    SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                    break
                end
            end
        end

        if trackname_check(track, "^RoomTone") then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            -- elseif muted == 0 then
            --     SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            --     SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if trackname_check(track, "^REF") then
            if IsTrackSelected(track) then
                Main_OnCommand(40340,0) -- unsolo all tracks
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 1)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if trackname_check(track, "^RCMASTER") then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function mixer()
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local mastering
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        mastering = tonumber(table[6])
    end

    local colors = get_color_table()
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if trackname_check(track, "^M:") then
            SetTrackColor(track, colors.mixer)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^@") then
            SetTrackColor(track, colors.aux)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^#") then
            SetTrackColor(track, colors.submix)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^RoomTone") then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "^REF") then
            SetTrackColor(track, colors.ref)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "RCMASTER") then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER") or trackname_check(track, "^RoomTone")  or trackname_check(track, "^REF")  then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end

        if trackname_check(track, "^S%d+:") then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 0 or 1)
        end
        if trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RCMASTER") then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 1 or 0)
        end
        if mastering == 1 and i == 0 then
            Main_OnCommand(40727,0) -- minimize all tracks
            SetTrackSelected(track, 1)
            Main_OnCommand(40723,0) -- expand and minimize others
            SetTrackSelected(track, 0)
        end
    end
end

---------------------------------------------------------------------

function on_stop()
    if GetPlayState() == 0 then
        DeleteProjectMarker(NULL, 1016, false)
        Main_OnCommand(41185, 0) -- Item properties: Unsolo all
        return
    else
        defer(on_stop)
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

main()
