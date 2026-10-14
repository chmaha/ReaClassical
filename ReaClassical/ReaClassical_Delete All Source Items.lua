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
local main, clear_source_folder, clear_source_folders

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "Vertical" then
        MB("This function requires a vertical ReaClassical project. " ..
            "Please create one or convert your existing ReaClassical project using Mission Control.", "ReaClassical Error", 0)
        return
    end

    local response = MB(
        "This will delete all items from every source folder." ..
        "\n\nAre you sure you want to continue?",
        "Delete All Source Items", 4)
    if response ~= 6 then return end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    local cleared = clear_source_folders()

    PreventUIRefresh(-1)
    Undo_EndBlock('Delete All Source Items', -1)
    UpdateArrange()
    UpdateTimeline()

    if cleared then
        say("All source items deleted")
    else
        say("No source items found")
    end
end

function clear_source_folder(parent_track)
    local cleared = false

    local function clear_items(track)
        for k = CountTrackMediaItems(track) - 1, 0, -1 do
            DeleteTrackMediaItem(track, GetTrackMediaItem(track, k))
            cleared = true
        end
    end

    clear_items(parent_track)

    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local track = GetTrack(0, idx)
        if not track then break end
        clear_items(track)
        depth = depth + GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth <= 0 then break end
        idx = idx + 1
    end

    return cleared
end

function clear_source_folders()
    local cleared_any = false
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        local _, is_source = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", false)
        if folder_depth == 1 and is_source == "y" then
            if clear_source_folder(track) then cleared_any = true end
        end
    end
    return cleared_any
end

main()
