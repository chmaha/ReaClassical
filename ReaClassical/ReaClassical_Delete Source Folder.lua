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
local main, resolve_source_folder, folder_has_items, delete_folder

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"

local function folder_tracks(parent_track)
    local tracks = { parent_track }
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local track = GetTrack(0, idx)
        if not track then break end
        tracks[#tracks + 1] = track
        depth = depth + GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth <= 0 then break end
        idx = idx + 1
    end
    return tracks
end

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "Vertical" then
        MB("This function requires a vertical ReaClassical project. " ..
            "Please create one or convert your existing ReaClassical project using Mission Control.", "ReaClassical Error", 0)
        return
    end

    local folder = resolve_source_folder()
    if not folder then
        MB("Selected track (or its parent) is not a source folder.", "Delete Source Folder", 0)
        return
    end

    if folder_has_items(folder) then
        local response = MB(
            "This source folder contains items that will be permanently deleted." ..
            "\n\nAre you sure you want to continue?",
            "Delete Source Folder", 4)
        if response ~= 6 then return end
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    delete_folder(folder)

    PreventUIRefresh(-1)
    Undo_EndBlock('Delete Source Folder', -1)
    UpdateArrange()
    UpdateTimeline()
end

function resolve_source_folder()
    local sel_track = GetSelectedTrack(0, 0)
    if not sel_track then return nil end

    local parent_track = sel_track
    if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") ~= 1 then
        local idx = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
        while idx >= 0 do
            local t = GetTrack(0, idx)
            if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
                parent_track = t
                break
            end
            idx = idx - 1
        end
    end

    if GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH") ~= 1 then return nil end

    local _, is_source = GetSetMediaTrackInfo_String(parent_track, "P_EXT:Source", "", false)
    if is_source ~= "y" then return nil end

    return parent_track
end

function folder_has_items(parent_track)
    for _, track in ipairs(folder_tracks(parent_track)) do
        if CountTrackMediaItems(track) > 0 then return true end
    end
    return false
end

function delete_folder(parent_track)
    local tracks = folder_tracks(parent_track)
    for i = #tracks, 1, -1 do
        DeleteTrack(tracks[i])
    end
end

main()
