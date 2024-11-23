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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, solo, trackname_check, mixer, track_check
local load_prefs, save_prefs, get_color_table, get_path
local extract_take_number, check_parent_track

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
mastering = (mastering ~= "" and tonumber(mastering)) or 0
local ref_is_guide = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[7] then ref_is_guide = tonumber(table[7]) or 0 end
end

---------------------------------------------------------------------

function main()
    if track_check() == 0 then
        MB("Please add at least one folder before running", "Classical Take Record", 0)
        return
    end

    local _, rec_wildcards = get_config_var_string("recfile_wildcards")

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")

    local first_selected = GetSelectedTrack(0, 0)
    if not check_parent_track(first_selected) then return end

    Undo_BeginBlock()
    local rec_arm = GetMediaTrackInfo_Value(first_selected, "I_RECARM")

    Main_OnCommand(40339, 0) --unmute all tracks

    if GetPlayState() == 0 then
        local take_counter = NamedCommandLookup("_RSac9d8eec87fd6c1d70abfe3dcc57849e2aac0bdc")
        local state = GetToggleCommandState(take_counter)
        if state ~= 1 then
            Main_OnCommand(take_counter,0)
        end
        local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
        Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
        mixer()
        local selected = solo()
        if not selected then
            MB("Please select a folder or track before running", "Classical Take Record", 0)
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

        Main_OnCommand(1013, 0) -- Transport: Record
        Undo_EndBlock('Classical Take Record', 0)
    else
        Main_OnCommand(40667, 0) -- Transport: Stop (save all recorded media)
        local _, session_name = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        session_name = (session_name ~= "" and session_name .. "_") or ""
        local take_number = extract_take_number(rec_wildcards)
        if take_number then
            --for each selected item rename take
            local padded_number = string.format("%03d", take_number)
            local num_of_selected_items = CountSelectedMediaItems(0)
            for i = 0, num_of_selected_items - 1 do
                local item = GetSelectedMediaItem(0, i)
                local track = GetMediaItem_Track(item)
                local _, trackname = GetTrackName(track)
                local take = GetActiveTake(item)
                GetSetMediaItemTakeInfo_String(take, "P_NAME", session_name .. trackname .. "_T" .. padded_number, true)
            end
        end

        Main_OnCommand(40289, 0) -- Unselect all items

        if workflow == "Vertical" then
            local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
            Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
            local ret, cursor_pos = load_prefs()
            if ret then
                SetEditCurPos(cursor_pos, true, false)
                SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", "")
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
                    Main_OnCommand(40297, 0)           -- deselect all tracks
                    SetTrackSelected(track, true)
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
                Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
                local arm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
                Main_OnCommand(arm, 0)             -- Xenakios/SWS: Set selected tracks record armed
                solo()
                local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
                Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
                Main_OnCommand(40913, 0)             -- adjust scroll to selected tracks
            end
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
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", 0)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", 0)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", 0)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", 0)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", 0)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", 0)

        if IsTrackSelected(track) == false and mixer_state ~= "y" and aux_state ~= "y" and submix_state ~= "y"
            and rt_state ~= "y" and rcmaster_state ~= "y" then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
        end
        if ref_state == "y" and ref_is_guide == 1 then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 1)
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
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", 0)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", 0)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", 0)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", 0)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", 0)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", 0)

        if mixer_state == "y" then
            SetTrackColor(track, colors.mixer)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if aux_state == "y" then
            SetTrackColor(track, colors.aux)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if submix_state == "y" then
            SetTrackColor(track, colors.submix)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if rt_state == "y" then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if ref_state == "y" then
            SetTrackColor(track, colors.ref)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if rcmaster_state == "y" then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rcmaster_state == "y"
            or rt_state == "y" or ref_state == "y" then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end

        local _, source_track = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", 0)
        if trackname_check(track, "^S%d+:") or source_track == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 0 or 1)
        end
        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 1 or 0)
        end
        if mastering == 1 and i == 0 then
            Main_OnCommand(40727, 0) -- minimize all tracks
            SetTrackSelected(track, 1)
            Main_OnCommand(40723, 0) -- expand and minimize others
            SetTrackSelected(track, 0)
        end
    end
end

---------------------------------------------------------------------

function track_check()
    return CountTracks(0)
end

---------------------------------------------------------------------

function load_prefs()
    return GetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos")
end

---------------------------------------------------------------------

function save_prefs(cursor_position)
    SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", cursor_position)
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

function check_parent_track(track)
    if not track or GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        MB("Please select a parent track before running", "Classical Take Record", 0)
        return false
    end
    return true
end

---------------------------------------------------------------------

function extract_take_number(rec_wildcards)
    local number = rec_wildcards:match("T(%d+)$")
    return number and tonumber(number) or nil
end

---------------------------------------------------------------------

main()
