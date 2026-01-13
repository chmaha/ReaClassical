--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

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

local main, folder_check, get_track_number
local move_destination_folder_to_top, select_first_razor
---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    PreventUIRefresh(1)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    move_destination_folder_to_top()

    local sai_manager = NamedCommandLookup("_RS238a7e78cb257490252b3dde18274d00f9a1cf10")
    Main_OnCommand(sai_manager, 0)
    
    local value = GetExtState("ReaClassical_SAI_Manager", "set_pairs_at_cursor")
    local set_pairs_at_cursor = (value == "true")

    local razor_enabled = GetToggleCommandState(42618) == 1
    if not razor_enabled and not set_pairs_at_cursor then
        Main_OnCommand(42618, 0)
    end

    -- If set_pairs_at_cursor is enabled, just add SAI marker at edit cursor
    if set_pairs_at_cursor then
        local cursor_pos = GetCursorPosition()
        local selected_track = GetSelectedTrack(0, 0)
        
        if selected_track then
            local track_number = math.floor(get_track_number())

            SetOnlyTrackSelected(selected_track)
            local marker_color = GetTrackColor(selected_track)

            -- Find the closest marker BEFORE the cursor for this track (SAI or SAO)
            local marker_count = CountProjectMarkers(0)
            local last_marker_type = nil
            local closest_marker_pos = -1
            
            for i = 0, marker_count - 1 do
                local _, isrgn, pos, _, name = EnumProjectMarkers(i)
                if not isrgn and pos < cursor_pos then
                    local num, suffix = name:match("^(%d+):%s*(%S+)")
                    if num and tonumber(num) == track_number then
                        if suffix:match("^SAI") or suffix:match("^SAO") then
                            -- This marker is before cursor and closer than previous best
                            if pos > closest_marker_pos then
                                closest_marker_pos = pos
                                if suffix:match("^SAI") then
                                    last_marker_type = "SAI"
                                else
                                    last_marker_type = "SAO"
                                end
                            end
                        end
                    end
                end
            end
            
            -- Decide whether to add SAI or SAO based on the closest marker before cursor
            local marker_suffix = "SAI"
            if last_marker_type == "SAI" then
                marker_suffix = "SAO"
            end
            
            AddProjectMarker2(0, false, cursor_pos, 0, track_number .. ":" .. marker_suffix, -1, marker_color)
        end
        
        PreventUIRefresh(-1)
        Undo_EndBlock("Add " .. (marker_suffix or "SAI") .. " marker at edit cursor", 0)
        return
    end

    Main_OnCommand(40635, 0) -- remove time selection
    Main_OnCommand(42474, 0) -- set selection to razor edit

    local left_pos, right_pos
    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    if start_time ~= end_time then
        left_pos = start_time
        right_pos = end_time
        select_first_razor()
        local selected_track = GetSelectedTrack(0, 0)

        local track_number = math.floor(get_track_number())

        if selected_track then SetOnlyTrackSelected(selected_track) end

        local marker_color = selected_track and GetTrackColor(selected_track) or 0

        AddProjectMarker2(0, false, left_pos, 0, track_number .. ":SAI", -1, marker_color)
        AddProjectMarker2(0, false, right_pos, 0, track_number .. ":SAO", -1, marker_color)
    end

    Main_OnCommand(40635, 0) -- remove time selection
    Main_OnCommand(42406, 0) -- remove razor edit areas
    PreventUIRefresh(-1)
    Undo_EndBlock("Source Markers to Item Edge", 0)
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

function get_track_number()
    local selected = GetSelectedTrack(0, 0)
    if folder_check() == 0 or selected == nil then
        return 1
    elseif GetMediaTrackInfo_Value(selected, "I_FOLDERDEPTH") == 1 then
        return GetMediaTrackInfo_Value(selected, "IP_TRACKNUMBER")
    else
        local folder = GetParentTrack(selected)
        return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
    end
end

---------------------------------------------------------------------

function move_destination_folder_to_top()
    local destination_folder = nil
    local track_count = CountTracks(0)

    -- Find the first folder with a parent that has the "Destination" extstate set to "y"
    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track
                break
            end
        end
    end

    if not destination_folder then return end -- No matching folder found

    -- Move the folder to the top
    local destination_index = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    if destination_index > 0 then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(0, 0)
    end
end

---------------------------------------------------------------------

function select_first_razor()
    local trackCount = CountTracks(0)

    -- deselect all tracks
    Main_OnCommand(40297, 0) -- Unselect all tracks

    for i = 0, trackCount - 1 do
        local track = GetTrack(0, i)
        local ok, area = GetSetMediaTrackInfo_String(track, "P_RAZOREDITS", "", false)
        if ok and area ~= "" then
            -- select this track
            SetTrackSelected(track, true)
            return -- stop after the first one
        end
    end
end

---------------------------------------------------------------------

main()