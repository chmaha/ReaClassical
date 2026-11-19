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

local main, add_project_marker, clear_destination_project, file_exists, copy_file

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

local SOURCE_MARKER_ID = 1000
local DEST_MARKER_ID = 1001
local separator = package.config:sub(1, 1)

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

    local source_proj, source_path = EnumProjects(-1)
    if source_path == "" then
        MB("Please save the project first. It becomes the source project and "
            .. "the destination project is saved alongside it.", "Set Up Dual Tab Workflow", 0)
        return
    end

    local dir, stem = source_path:match("^(.*)[\\/]([^\\/]+)%.[Rr][Pp][Pp]$")
    if not dir then
        MB("Could not determine the project folder.", "Set Up Dual Tab Workflow", 0)
        return
    end

    local ok, dest_name = GetUserInputs("Set Up Dual Tab Workflow", 1,
        "Destination project name:,extrawidth=150", stem .. "_destination")
    if not ok then return end
    dest_name = dest_name:gsub("%.[Rr][Pp][Pp]$", ""):gsub("[\\/:*?\"<>|]", "_")
    if dest_name == "" or dest_name == stem then
        MB("Please choose a name different from the source project.", "Set Up Dual Tab Workflow", 0)
        return
    end

    local dest_path = dir .. separator .. dest_name .. ".RPP"
    if file_exists(dest_path) then
        local overwrite = MB(dest_name .. ".RPP already exists. Overwrite it?", "Set Up Dual Tab Workflow", 4)
        if overwrite ~= 6 then return end
    end

    local i = 0
    while true do
        local project = EnumProjects(i)
        if not project then break end
        DeleteProjectMarker(project, SOURCE_MARKER_ID, false)
        DeleteProjectMarker(project, DEST_MARKER_ID, false)
        i = i + 1
    end

    add_project_marker(source_proj, GetCursorPositionEx(source_proj), "SOURCE PROJECT", SOURCE_MARKER_ID,
        ColorToNative(105, 79, 183) | 0x1000000)
    Main_SaveProject(source_proj, false)
    if not copy_file(source_path, dest_path) then
        MB("Could not write " .. dest_path, "Set Up Dual Tab Workflow", 0)
        return
    end

    Main_OnCommand(40859, 0)
    Main_openProject("noprompt:" .. dest_path)
    local dest_proj = EnumProjects(-1)

    PreventUIRefresh(1)
    clear_destination_project(dest_proj)
    add_project_marker(dest_proj, 0, "DEST PROJECT", DEST_MARKER_ID, ColorToNative(183, 79, 105) | 0x1000000)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()

    Main_SaveProject(dest_proj, false)
    say("Dual tab workflow ready. Destination project " .. dest_name .. " created")
end

function add_project_marker(proj, pos, name, id, color)
    AddProjectMarker2(proj, false, pos, 0, name, id, color)
end

function clear_destination_project(proj)
    for t = 0, CountTracks(proj) - 1 do
        local track = GetTrack(proj, t)
        for j = CountTrackMediaItems(track) - 1, 0, -1 do
            DeleteTrackMediaItem(track, GetTrackMediaItem(track, j))
        end
    end

    local _, num_markers, num_regions = CountProjectMarkers(proj)
    for idx = num_markers + num_regions - 1, 0, -1 do
        DeleteProjectMarkerByIndex(proj, idx)
    end

    SetProjExtState(proj, "ReaClassical", "LastRecordedItemGUIDs", "")
    SetProjExtState(proj, "ReaClassical", "LastRecordedItem", "")
end

function copy_file(from, to)
    local src = io.open(from, "rb")
    if not src then return false end
    local data = src:read("a")
    src:close()
    local dst = io.open(to, "wb")
    if not dst then return false end
    dst:write(data)
    dst:close()
    return true
end

function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

main()
