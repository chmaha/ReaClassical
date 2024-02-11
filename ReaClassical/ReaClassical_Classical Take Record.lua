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

---------------------------------------------------------------------

function main()
    if track_check() == 0 then
        ShowMessageBox("Please add at least one track or folder before running", "Classical Take Record", 0)
        return
    end
    local selected = GetSelectedTrack(0,0)
    is_parent = GetMediaTrackInfo_Value(selected, "I_FOLDERDEPTH")
    if is_parent ~= 1 then
        ShowMessageBox("Please select a parent track before running", "Classical Take Record", 0)
        return
    end
    local take_record_toggle = NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")
    Undo_BeginBlock()
    if GetPlayState() == 0 then
        SetToggleCommandState(1, take_record_toggle, 1)
        RefreshToolbar2(1, take_record_toggle)
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        mixer()
        local selected = solo()
        if not selected then
            ShowMessageBox("Please select a folder or track before running", "Classical Take Record", 0)
            SetToggleCommandState(1, take_record_toggle, 0)
            return
        end
        Main_OnCommand(40491, 0)         -- Track: Unarm all tracks for recording
        local arm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
        Main_OnCommand(arm, 0)           -- Xenakios/SWS: Set selected tracks record armed
        local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
        Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
        local cursor_pos = GetCursorPosition()
        save_prefs(cursor_pos)
        Main_OnCommand(1013, 0) -- Transport: Record
        Undo_EndBlock('Classical Take Record', 0)
    else
        SetToggleCommandState(1, take_record_toggle, 0)
        RefreshToolbar2(1, take_record_toggle)
        Main_OnCommand(40667, 0)       -- Transport: Stop (save all recorded media)
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        Main_OnCommand(40289, 0)       -- Unselect all items
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
                Main_OnCommand(40913, 0)     -- adjust scroll to selected tracks
                bool = true
                TrackList_AdjustWindows(false)
                break
            end
        end
        if bool == false then
            local duplicate = NamedCommandLookup("_RS2c6e13d20ab617b8de2c95a625d6df2fde4265ff")
            Main_OnCommand(duplicate, 0)
            local arm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
            Main_OnCommand(arm, 0)         -- Xenakios/SWS: Set selected tracks record armed
            local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
            Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
            Main_OnCommand(40913, 0)       -- adjust scroll to selected tracks
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
        if IsTrackSelected(track) == false then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
    return true
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

main()
