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

function M.is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

function M.get_folder_parent(track)
    if not track then return nil, nil end
    local idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        if not M.is_special_track(track) then
            return track, idx
        else
            return nil, nil
        end
    end
    for i = idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        local d = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
        if d == 1 then
            if not M.is_special_track(t) then
                return t, i
            else
                return nil, nil
            end
        end
    end
    return nil, nil
end

function M.get_folder_tracks(parent_track, parent_idx)
    local tracks = { { track = parent_track, idx = parent_idx } }
    local num_tracks = CountTracks(0)
    local j = parent_idx + 1
    local depth = 1
    while j < num_tracks and depth > 0 do
        local ch = GetTrack(0, j)
        local d = GetMediaTrackInfo_Value(ch, "I_FOLDERDEPTH")
        local _, spare_state = GetSetMediaTrackInfo_String(ch, "P_EXT:spare", "", false)
        if not M.is_special_track(ch) and spare_state ~= "y" then
            table.insert(tracks, { track = ch, idx = j })
        end
        depth = depth + d
        j = j + 1
    end
    return tracks
end

return M
