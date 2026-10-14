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

function M.trim(s)
    return s:match("^%s*(.-)%s*$")
end

function M.get_mixer_tracks()
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, spare_state = GetSetMediaTrackInfo_String(track, "P_EXT:spare", "", false)
        if state == "y" and spare_state ~= "y" then
            table.insert(tracks, track)
        end
    end
    return tracks
end

function M.get_mixer_base_name(mixer_track)
    local _, name = GetSetMediaTrackInfo_String(mixer_track, "P_NAME", "", false)
    return name:match("^M:(.*)$") or name
end

function M.rename_mixer_position(mixer_tracks, position, new_name, workflow)
    local mixer_track = mixer_tracks[position]
    if not mixer_track then return false end

    local _, rcm_disconnect = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:rcm_disconnect", "", false)

    local clean_name = M.trim(new_name):gsub("%-$", "")
    GetSetMediaTrackInfo_String(mixer_track, "P_NAME", "M:" .. clean_name, true)

    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then
            folder_number = folder_number + 1
            local track_index = i + (position - 1)
            local target_track = GetTrack(0, track_index)
            if target_track then
                GetSetMediaTrackInfo_String(target_track, "P_EXT:rcm_disconnect", rcm_disconnect, true)
                local prefix = ""
                if workflow == "Vertical" then
                    if folder_number == 1 then
                        prefix = "D:"
                    else
                        prefix = "S" .. (folder_number - 1) .. ":"
                    end
                end
                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. clean_name, true)
            end
        end
    end
    return true
end

function M.get_special_tracks()
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, playback_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y"
            or live_state == "y" or rcmaster_state == "y" or listenback_state == "y"
            or playback_state == "y" then
            local track_type = "other"
            if aux_state == "y" then
                track_type = "aux"
            elseif submix_state == "y" then
                track_type = "submix"
            elseif rt_state == "y" then
                track_type = "roomtone"
            elseif ref_state == "y" then
                track_type = "reference"
            elseif live_state == "y" then
                track_type = "live"
            elseif listenback_state == "y" then
                track_type = "listenback"
            elseif rcmaster_state == "y" then
                track_type = "rcmaster"
            elseif playback_state == "y" then
                track_type = "playback"
            end

            local display_name = ""
            if track_type == "aux" or track_type == "submix" then
                display_name = name:gsub("^[@#]:?", ""):gsub("%-$", "")
            elseif track_type == "reference" then
                display_name = name:gsub("^REF:?", ""):gsub("%-$", "")
            end

            table.insert(tracks, {
                track = track,
                name = display_name,
                full_name = name,
                type = track_type,
                index = i
            })
        end
    end

    local type_priority = {
        aux = 1, submix = 1, roomtone = 3, rcmaster = 4,
        live = 5, reference = 6, listenback = 7, playback = 8
    }
    table.sort(tracks, function(a, b)
        local pa = type_priority[a.type] or 99
        local pb = type_priority[b.type] or 99
        if pa ~= pb then return pa < pb end
        return a.index < b.index
    end)

    return tracks
end

function M.get_special_tracks_by_type(t)
    local result = {}
    for _, info in ipairs(M.get_special_tracks()) do
        if info.type == t then table.insert(result, info) end
    end
    return result
end

function M.resolve_special_index(list, num_str, type_label, num_prefix)
    if num_str ~= "" then
        local info = list[tonumber(num_str)]
        if info then return info end
        return nil, "No " .. type_label .. " track " .. num_prefix .. num_str
    end
    if #list == 0 then
        return nil, "No " .. type_label .. " track found"
    elseif #list == 1 then
        return list[1]
    end
    return nil, "Multiple " .. type_label .. " tracks in project"
end

function M.rename_special_track(track, prefix, new_name)
    GetSetMediaTrackInfo_String(track, "P_NAME", prefix .. M.trim(new_name), true)
end

return M
