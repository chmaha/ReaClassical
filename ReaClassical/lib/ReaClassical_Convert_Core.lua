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

local M = {}

package.path = package.path .. ";" .. (debug.getinfo(1, "S").source:match("@(.+[\\/])")) .. "?.lua;"
local spare_track = require("ReaClassical_Spare_Track")

local lib_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local root_path = lib_path:match("^(.+[\\/]).+[\\/]$") or lib_path

local function duplicate_project_in_new_tab()
    local _, proj_path = EnumProjects(-1, "")
    local isdirty = IsProjectDirty(0)
    if not proj_path or proj_path == "" or not proj_path:lower():match("%.rpp$") or isdirty == 1 then
        return -1
    end

    Main_OnCommand(40859, 0)

    Main_openProject(proj_path)

    local current_filename, ext = proj_path:match("([^\\/]-)%.([Rr][Pp][Pp])$")
    current_filename = current_filename or "Untitled"
    ext = ext or "RPP"

    local dir = proj_path:match("^(.*)[\\/][^\\/]-%.([Rr][Pp][Pp])$") or GetProjectPath("")

    local new_filename = current_filename .. "_converted." .. ext
    local new_filepath = dir .. "/" .. new_filename

    Main_SaveProjectEx(0, new_filepath, 8)
end

local function count_tracks_with_items()
    local count = 0
    for i = 0, CountTracks(0) - 1 do
        if CountTrackMediaItems(GetTrack(0, i)) > 0 then count = count + 1 end
    end
    return count
end

local function collect_markers()
    local markers = {}
    local i = 0
    while true do
        local retval, isrgn, pos, rgnend, name, idx, color = EnumProjectMarkers3(0, i)
        if retval == 0 then break end
        markers[#markers + 1] = { isrgn = isrgn, pos = pos, rgnend = rgnend, name = name, idx = idx, color = color }
        i = i + 1
    end
    return markers
end

local function track_extent(track)
    local first, last = math.huge, -math.huge
    for i = 0, CountTrackMediaItems(track) - 1 do
        local item = GetTrackMediaItem(track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos < first then first = pos end
        if item_end > last then last = item_end end
    end
    return first, last
end

function M.has_markers()
    return #collect_markers() > 0
end

function M.tracks_with_items()
    local tracks = {}
    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        if CountTrackMediaItems(track) > 0 then
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if name == "" then name = "Track " .. (t + 1) end
            tracks[#tracks + 1] = { index = t, name = name }
        end
    end
    return tracks
end

function M.default_marker_track(tracks)
    local markers = collect_markers()
    local best, best_count = 1, -1
    for n, entry in ipairs(tracks) do
        local first, last = track_extent(GetTrack(0, entry.index))
        local count = 0
        for _, m in ipairs(markers) do
            local m_end = m.isrgn and m.rgnend or m.pos
            if m.pos >= first - 0.001 and m_end <= last + 0.001 then count = count + 1 end
        end
        if count > best_count then best, best_count = n, count end
    end
    return best
end

local function shift_markers(markers, offset)
    if offset == 0 then return end
    for _, m in ipairs(markers) do
        local rgnend = m.isrgn and (m.rgnend + offset) or 0
        SetProjectMarker3(0, m.idx, m.isrgn, m.pos + offset, rgnend, m.name, m.color)
    end
end

local function lay_out_tracks_sequentially(marker_track_index, track_name)
    local _, gap_str = GetProjExtState(0, "ReaClassical", "ImportTakeGap")
    local gap = tonumber(gap_str)
    if not gap or gap < 0 then gap = 2 end
    local blocks = {}
    local cursor

    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        local count = CountTrackMediaItems(track)
        if count > 0 then
            local items = {}
            local first, last = math.huge, -math.huge
            for i = 0, count - 1 do
                local item = GetTrackMediaItem(track, i)
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
                items[#items + 1] = { item = item, pos = pos }
                if pos < first then first = pos end
                if item_end > last then last = item_end end
            end
            cursor = cursor or first
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            blocks[#blocks + 1] = { items = items, offset = cursor - first, start = cursor, name = name, index = t }
            cursor = cursor + (last - first) + gap
        end
    end

    if #blocks < 2 then return end
    local dest = nil
    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        if CountTrackMediaItems(track) > 0 then
            dest = track
            break
        end
    end

    local markers = collect_markers()
    for _, block in ipairs(blocks) do
        if block.index == marker_track_index then shift_markers(markers, block.offset) end
    end

    GetSetMediaTrackInfo_String(dest, "P_NAME", track_name or "", true)

    for _, block in ipairs(blocks) do
        for _, entry in ipairs(block.items) do
            SetMediaItemInfo_Value(entry.item, "D_POSITION", entry.pos + block.offset)
            if GetMediaItem_Track(entry.item) ~= dest then
                MoveMediaItemToTrack(entry.item, dest)
            end
        end
        if block.name ~= "" then
            AddProjectMarker(0, false, block.start, 0, block.name, -1)
        end
    end
end

local function flatten_all_folders()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
    end
end

local function make_all_tracks_one_folder()
    local num_tracks = CountTracks(0)
    if num_tracks < 2 then
        return
    end

    local first_track = GetTrack(0, 0)
    SetMediaTrackInfo_Value(first_track, "I_FOLDERDEPTH", 1)

    for i = 1, num_tracks - 2 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
    end

    local last_track = GetTrack(0, num_tracks - 1)
    SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", -1)
end

local function delete_empty_tracks()
    local num_tracks = CountTracks(0)

    for i = num_tracks - 1, 0, -1 do
        local track = GetTrack(0, i)
        local item_count = CountTrackMediaItems(track)
        if item_count == 0 then
            DeleteTrack(track)
        end
    end

    local remaining_tracks = CountTracks(0)
    if remaining_tracks == 1 then
        InsertTrackAtIndex(1, true)
        return true
    end
    return false
end

local function reset_all_routing()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)

        local send_count = GetTrackNumSends(track, 0)
        for s = send_count - 1, 0, -1 do
            RemoveTrackSend(track, 0, s)
        end

        local receive_count = GetTrackNumSends(track, -1)
        for r = receive_count - 1, 0, -1 do
            RemoveTrackSend(track, -1, r)
        end

        local hwout_count = GetTrackNumSends(track, 1)
        for h = hwout_count - 1, 0, -1 do
            RemoveTrackSend(track, 1, h)
        end

        SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
    end
end

local function add_rc_ext_state()
    SetProjExtState(0, "ReaClassical", "RCProject", "y")
    local creation_date = os.date("%Y-%m-%d %H:%M:%S", os.time())
    SetProjExtState(0, "ReaClassical", "CreationDate", creation_date)
end

local function tag_source_tracks()
    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        GetSetMediaTrackInfo_String(track, "P_EXT:Source", "y", true)
    end
end

function M.save_problem()
    local _, proj_path = EnumProjects(-1, "")
    if not proj_path or proj_path == "" or not proj_path:lower():match("%.rpp$") or IsProjectDirty(0) == 1 then
        return "Please save the project before converting."
    end
    return nil
end

function M.is_rc_project()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    return workflow ~= ""
end

M.count_tracks_with_items = count_tracks_with_items

M.INFO = "Conversion opens a copy of this project, saved with a \"_converted\" suffix, in a new tab. "
    .. "Your original project is left untouched. In the copy, folders are flattened, empty tracks "
    .. "removed, custom routing removed, and track FX moved to the ReaClassical mixer tracks. "
    .. "Recreate any custom routing and bus FX afterwards in Mission Control."

function M.run(sequential, marker_track_index)
    local project_name = GetProjectName(0):gsub("%.[Rr][Pp][Pp]$", "")
    PreventUIRefresh(1)
    if duplicate_project_in_new_tab() == -1 then
        PreventUIRefresh(-1)
        return false, "Please save the project before converting."
    end
    flatten_all_folders()
    if sequential then lay_out_tracks_sequentially(marker_track_index, project_name) end
    local single_track = delete_empty_tracks()
    reset_all_routing()
    make_all_tracks_one_folder()
    tag_source_tracks()
    add_rc_ext_state()
    dofile(root_path .. "lib/ReaClassical_Horizontal Workflow.lua")
    if single_track then spare_track.retire_second_track(false) end
    _G.RC_SCRIPT_ARGS = { silent = true }
    dofile(root_path .. "ReaClassical_Auto-color project.lua")
    _G.RC_SCRIPT_ARGS = nil
    Main_SaveProject(0, false)
    PreventUIRefresh(-1)
    return true, "Project converted."
end

return M
