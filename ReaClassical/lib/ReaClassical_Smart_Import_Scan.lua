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

function M.get_project_media_path()
    return GetProjectPathEx(0)
end

function M.scan_media_folder_recursive(path, files)
    if not path then return {} end
    files = files or {}
    local i, j = 0, 0

    while true do
        local file = EnumerateFiles(path, i)
        if not file then break end
        if file:lower() ~= "roomtone.wav" and (file:lower():match("%.wav$")
        or file:lower():match("%.flac$")
        or file:lower():match("%.aif")) then
            table.insert(files, path .. "/" .. file)
        end
        i = i + 1
    end

    while true do
        local sub = EnumerateSubdirectories(path, j)
        if not sub then break end
        M.scan_media_folder_recursive(path .. "/" .. sub, files)
        j = j + 1
    end

    return files
end

function M.get_used_source_files()
    local used = {}
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local _, sd_edit = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
        if sd_edit ~= "y" then
            local take = GetActiveTake(item)
            if take then
                local source = GetMediaItemTake_Source(take)
                if source then
                    local filepath = GetMediaSourceFileName(source)
                    if filepath and filepath ~= "" then
                        used[filepath:gsub("\\", "/")] = true
                    end
                end
            end
        end
    end
    return used
end

function M.parse_canonical_filename(filepath)
    local filename = filepath:match("([^/\\]+)$")
    if not filename then return nil end

    local name_no_ext = filename:match("(.+)%.[^.]+$")
    if not name_no_ext then return nil end

    local take_str = name_no_ext:match("_T(%d+)$") or name_no_ext:match("_(%d+)$")
    if not take_str then return nil end

    local name_without_take = name_no_ext:gsub("_T%d+$", ""):gsub("_%d+$", "")

    local parts = {}
    for part in name_without_take:gmatch("[^_]+") do
        table.insert(parts, part)
    end

    if #parts == 0 then return nil end

    local track_name, session_name

    if #parts == 1 then
        track_name   = parts[1]
        session_name = "default"
    elseif #parts == 2 then
        if parts[1]:match("^D$") or parts[1]:match("^S%d+$") then
            track_name   = parts[2]
            session_name = "default"
        else
            session_name = parts[1]
            track_name   = parts[2]
        end
    else
        local potential_prefix = parts[#parts - 1]
        if potential_prefix:match("^D$") or potential_prefix:match("^S%d+$") then
            track_name = parts[#parts]
            table.remove(parts, #parts)
            table.remove(parts, #parts)
            session_name = table.concat(parts, "_")
        else
            track_name = parts[#parts]
            table.remove(parts, #parts)
            session_name = table.concat(parts, "_")
        end
    end

    return {
        filename           = filename,
        session_name       = session_name,
        track_name         = track_name:lower(),
        track_name_display = track_name,
        take_num           = tonumber(take_str),
    }
end

function M.get_tracks(workflow)
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        local _, name = GetTrackName(tr)
        name = name:gsub("^%s*(.-)%s*$", "%1")

        local base_name = name
        if workflow == "Vertical" then
            local stripped = name:match("^[DS]%d*:%s*(.+)$")
            if stripped then base_name = stripped end
        end

        table.insert(tracks, {
            track            = tr,
            display_name     = name,
            base_name        = base_name:lower(),
            is_folder_parent = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1,
        })
    end
    return tracks
end

function M.find_track_by_name(tracks, track_name)
    track_name = track_name:lower()
    for _, track_obj in ipairs(tracks) do
        if track_obj.base_name == track_name then return track_obj end
    end
    return nil
end

function M.count_blank_mixer_tracks()
    local count = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            local _, name = GetTrackName(track)
            local stripped = name:gsub("^M:?", ""):gsub("^%s*(.-)%s*$", "%1")
            if stripped == "" then count = count + 1 end
        end
    end
    return count
end

function M.count_source_folders()
    local count = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            local _, name = GetTrackName(track)
            if name:match("^S%d+:") then count = count + 1 end
        end
    end
    return count
end

function M.total_existing_folders()
    return 1 + M.count_source_folders()
end

function M.folder_label_for_index(idx)
    if idx == 1 then return "D:" end
    return "S" .. (idx - 1) .. ":"
end

function M.spoken_folder_label_for_index(idx)
    if idx == 1 then return "Destination" end
    return "Source Folder " .. (idx - 1)
end

function M.get_start_folder_idx_from_selection()
    local track = GetSelectedTrack(0, 0)
    if not track then return 2 end

    while track and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 do
        track = GetParentTrack(track)
    end
    if not track then return 2 end

    local idx = 0
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        if GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
            idx = idx + 1
            if tr == track then return idx end
        end
    end
    return 2
end

function M.get_project_end_position()
    local max_end = 0
    for i = 0, CountMediaItems(0) - 1 do
        local item     = GetMediaItem(0, i)
        local item_end = GetMediaItemInfo_Value(item, "D_POSITION")
                       + GetMediaItemInfo_Value(item, "D_LENGTH")
        if item_end > max_end then max_end = item_end end
    end
    return max_end
end

function M.parse_take_range(str)
    if not str then return nil end
    str = str:gsub("%s+", "")
    if str == "" then return nil end

    local set = {}
    local any = false
    for segment in str:gmatch("[^,]+") do
        local a, b = segment:match("^(%d+)-(%d+)$")
        if a then
            a, b = tonumber(a), tonumber(b)
            if a > b then a, b = b, a end
            for n = a, b do set[n] = true end
            any = true
        else
            local n = segment:match("^(%d+)$")
            if n then
                set[tonumber(n)] = true
                any = true
            end
        end
    end

    return any and set or nil
end

function M.filter_sessions_for_import(sessions, session_names, session_filter, take_set)
    local filtered, filtered_names = {}, {}
    local total_takes, max_takes = 0, 0
    local sf = (session_filter and session_filter ~= "") and session_filter:lower() or nil

    for _, session_name in ipairs(session_names) do
        if not sf or session_name:lower():find(sf, 1, true) then
            local session_data = sessions[session_name]
            local out = {}
            local n = 0
            for take_num, take_data in pairs(session_data) do
                if not take_set or take_set[take_num] then
                    out[take_num] = take_data
                    n = n + 1
                end
            end
            if n > 0 then
                filtered[session_name] = out
                table.insert(filtered_names, session_name)
                total_takes = total_takes + n
                if n > max_takes then max_takes = n end
            end
        end
    end

    table.sort(filtered_names, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a < b
    end)

    return filtered, filtered_names, total_takes, max_takes
end

return M
