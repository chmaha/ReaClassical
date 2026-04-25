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

local main, markers, exclusive_select_folder_parent, zoom

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    local marker_count, folder_prefix = markers()

    if marker_count == 0 then return end

    if workflow == "horizontal" then
        exclusive_select_folder_parent(nil)
    else
        exclusive_select_folder_parent(folder_prefix)
    end

    GoToMarker(0, 996, false)
    zoom()
end

---------------------------------------------------------------------

function markers()
    local marker_count = 0
    local folder_prefix = nil
    local num = 0

    while true do
        local proj = EnumProjects(num)
        if proj == nil then break end
        local _, num_markers, num_regions = CountProjectMarkers(proj)
        for i = 0, num_markers + num_regions - 1 do
            local _, _, _, _, raw_label, _ = EnumProjectMarkers2(proj, i)
            local prefix = string.match(raw_label, "^(.+):DEST%-IN$")
            if prefix then
                marker_count = 1
                folder_prefix = prefix ~= "" and prefix or nil
            elseif string.match(raw_label, "^DEST%-IN$") then
                marker_count = 1
            end
        end
        num = num + 1
    end

    return marker_count, folder_prefix
end

---------------------------------------------------------------------

function exclusive_select_folder_parent(prefix)
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        SetTrackSelected(track, false)
    end

    local target_track = nil

    if prefix == nil then
        if num_tracks > 0 then
            target_track = GetTrack(0, 0)
        end
    else
        for i = 0, num_tracks - 1 do
            local track = GetTrack(0, i)
            local _, track_name = GetTrackName(track)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth == 1 and string.match(track_name, "^" .. prefix) then
                target_track = track
                break
            end
        end
    end

    if target_track then
        SetTrackSelected(target_track, true)
    end
end

---------------------------------------------------------------------

function zoom()
    local cur_pos = (GetPlayState() == 0)
        and GetCursorPosition()
        or GetPlayPosition()

    local ts_start = math.max(0, cur_pos - 3)
    local ts_end   = cur_pos + 3

    SetEditCurPos(ts_start, false, false)
    Main_OnCommand(40625, 0) -- Time selection: Set start point
    SetEditCurPos(ts_end, false, false)
    Main_OnCommand(40626, 0) -- Time selection: Set end point
    GetSet_ArrangeView2(0, true, 0, 0, ts_start, ts_end)
    SetEditCurPos(cur_pos, false, false)
    Main_OnCommand(1012, 0)  -- View: Zoom in horizontal
    Main_OnCommand(40635, 0) -- Time selection: Remove
end

---------------------------------------------------------------------

main()