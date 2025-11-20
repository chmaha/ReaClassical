--[[
@noindex

This file is a part of "ReaClassical Core" package.
See "ReaClassicalCore.lua" for more information.

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

local main, folder_check, get_track_number, other_source_marker_check

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    local _, input = GetProjExtState(0, "ReaClassical Core", "Preferences")
    local sdmousehover = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[8] then sdmousehover = tonumber(table[8]) or 0 end
    end

    local selected_track = GetSelectedTrack(0, 0)

    local cur_pos, track
    if sdmousehover == 1 then
        cur_pos = BR_PositionAtMouseCursor(false)
        local screen_x, screen_y = GetMousePosition()
        track = GetTrackFromPoint(screen_x, screen_y)
    else
        cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    end

    if cur_pos ~= -1 then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then
                break
            else
                DeleteProjectMarker(project, 999, false)
            end
            i = i + 1
        end

        local track_number = math.floor(get_track_number(track))
        local other_source_marker = other_source_marker_check()

        local color_track = track or selected_track
        local marker_color = color_track and GetTrackColor(color_track) or 0
        AddProjectMarker2(0, false, cur_pos, 0, track_number .. ":SOURCE-OUT", 999, marker_color)

        if other_source_marker ~= track_number then
            MB("Warning: Source OUT marker group does not match Source IN!", "Add Source Marker OUT", 0)
        end
    end
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

function get_track_number(track)
    if not track then track = GetSelectedTrack(0, 0) end
    if folder_check() == 0 or track == nil then
        return 1
    elseif GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        return GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    else
        local folder = GetParentTrack(track)
        return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
    end
end

---------------------------------------------------------------------

function other_source_marker_check()
    local proj = EnumProjects(-1) -- Get the active project
    if not proj then return nil end

    local _, num_markers, num_regions = CountProjectMarkers(proj)

    for i = 0, num_markers + num_regions - 1 do
        local _, _, _, _, raw_label, _ = EnumProjectMarkers2(proj, i)
        local number, label = raw_label:match("(%d+):(.+)") -- Extract number and label

        if label and (label == "SOURCE-IN" or label == "SOURCE-OUT") then
            return tonumber(number) -- Convert track number to a number and return
        end
    end

    return nil -- Return nil if no marker is found
end

---------------------------------------------------------------------

main()
