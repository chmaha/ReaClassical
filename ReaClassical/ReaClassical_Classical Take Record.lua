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

local main, solo, trackname_check, mixer, track_check
local load_prefs, save_prefs, get_color_table, get_path
local folder_check

---------------------------------------------------------------------

function main()
    if track_check() == 0 then
        ShowMessageBox("Please add at least one folder before running", "Classical Take Record", 0)
        return
    end
    
    local first_selected = GetSelectedTrack(0, 0)
    local is_parent = GetMediaTrackInfo_Value(first_selected, "I_FOLDERDEPTH")
    if is_parent ~= 1 then
        ShowMessageBox("Please select a parent track before running", "Classical Take Record", 0)
        return
    end
    Undo_BeginBlock()
    local take_record_toggle = NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")
    local rec_arm = GetMediaTrackInfo_Value(first_selected, "I_RECARM")

    Main_OnCommand(40339, 0) --unmute all tracks

    if GetPlayState() == 0 then
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        mixer()
        local selected = solo()
        if not selected then
            ShowMessageBox("Please select a folder or track before running", "Classical Take Record", 0)
            SetToggleCommandState(1, take_record_toggle, 0)
            return
        end
        ClearAllRecArmed()
        local arm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
        Main_OnCommand(arm, 0)               -- Xenakios/SWS: Set selected tracks record armed
        local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
        Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)

        if rec_arm ~= 1 then
            TrackList_AdjustWindows(false)
            return
        end

        local cursor_pos = GetCursorPosition()
        save_prefs(cursor_pos)
        SetToggleCommandState(1, take_record_toggle, 1)
        RefreshToolbar2(1, take_record_toggle)
        Main_OnCommand(1013, 0) -- Transport: Record
        Undo_EndBlock('Classical Take Record', 0)
    else
        SetToggleCommandState(1, take_record_toggle, 0)
        RefreshToolbar2(1, take_record_toggle)
        Main_OnCommand(40667, 0)           -- Transport: Stop (save all recorded media)
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        Main_OnCommand(40289, 0)           -- Unselect all items
        local ret, cursor_pos = load_prefs()
        if ret then
            SetEditCurPos(cursor_pos, true, false)
        end
        local unarm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECUNARMED")
        Main_OnCommand(unarm, 0) -- Xenakios/SWS: Set selected tracks record unarmed

        local num_tracks = CountTracks(0)
        local selected_track = GetSelectedTrack(0, 0)
        local current_num = GetMediaTrackInfo_Value(selected_track, 'IP_TRACKNUMBER')
        local bool = false
        for i = current_num, num_tracks - 1, 1 do
            local track = GetTrack(0, i)
            if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                Main_OnCommand(40297, 0) -- deselect all tracks
                SetTrackSelected(track, true)
                local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
                Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
                solo()
                local arm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
                Main_OnCommand(arm, 0) -- Xenakios/SWS: Set selected tracks record armed
                mixer()
                local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
                Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
                Main_OnCommand(40913, 0)             -- adjust scroll to selected tracks
                bool = true
                TrackList_AdjustWindows(false)
                break
            end
        end
        if bool == false then
            local duplicate = NamedCommandLookup("_RS2c6e13d20ab617b8de2c95a625d6df2fde4265ff")
            Main_OnCommand(duplicate, 0)
            local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
            Main_OnCommand(select_children, 0)   -- SWS: Select children of selected folder track(s)
            local arm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
            Main_OnCommand(arm, 0)               -- Xenakios/SWS: Set selected tracks record armed
            solo()
            local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
            Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
            Main_OnCommand(40913, 0)             -- adjust scroll to selected tracks
        end
        Undo_EndBlock('Classical Take Record Stop', 0)
    end
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function solo()
    local track = GetSelectedTrack(0, 0)
    if not track then
        return false
    end
    SetMediaTrackInfo_Value(track, "I_SOLO", 2)

    for i = 0, CountTracks(0) - 1, 1 do
        track = GetTrack(0, i)
        if IsTrackSelected(track) == false and not trackname_check(track, "^M:") and not trackname_check(track, "^@") and not trackname_check(track, "^RCMASTER") then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
        end
    end
    return true
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function mixer()
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
        if trackname_check(track, "^RoomTone") then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "RCMASTER") then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if trackname_check(track, "RCMASTER%+") then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if trackname_check(track, "^M:") or trackname_check(track, "^@") or trackname_check(track, "^RCMASTER") or trackname_check(track, "^RoomTone") then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end
    end
end

---------------------------------------------------------------------

function track_check()
    return CountTracks(0)
end

---------------------------------------------------------------------

function load_prefs()
    return GetProjExtState(0, "ReaClassical", "Classical Take Record Cursor Position")
end

---------------------------------------------------------------------

function save_prefs(input)
    SetProjExtState(0, "ReaClassical", "Classical Take Record Cursor Position", input)
end

-----------------------------------------------------------------------

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
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        end
    end
    return folders
end

---------------------------------------------------------------------

main()
