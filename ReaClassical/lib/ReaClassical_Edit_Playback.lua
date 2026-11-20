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

local audition_playback = require("ReaClassical_Audition_Playback")

local M = {}

local DEFAULT_PRE_ROLL = 3.0
local PREF_INDEX = 17
local PRE_ROLL_INDEX = 19

local function pref_entries()
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
    local entries = {}
    for entry in saved:gmatch("([^,]+)") do entries[#entries + 1] = entry end
    return entries
end

function M.enabled()
    return tonumber(pref_entries()[PREF_INDEX]) == 1
end

function M.pre_roll()
    local value = tonumber(pref_entries()[PRE_ROLL_INDEX])
    if not value or value < 0 then return DEFAULT_PRE_ROLL end
    return value
end

function M.marker_pos(marker_id)
    local i = 0
    while true do
        local retval, isrgn, pos, _, _, idx = EnumProjectMarkers(i)
        if retval == 0 then return nil end
        if not isrgn and idx == marker_id then return pos end
        i = i + 1
    end
end

local function folder_tracks(track)
    if not track then return nil end
    local parent = track
    while GetParentTrack(parent) do parent = GetParentTrack(parent) end
    local tracks = { parent }
    if GetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH") ~= 1 then return tracks end
    local depth = 1
    local idx = GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")
    while depth > 0 and idx < CountTracks(0) do
        local child = GetTrack(0, idx)
        tracks[#tracks + 1] = child
        depth = depth + GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
        idx = idx + 1
    end
    return tracks
end

local function has_material_before(tracks, from_pos, to_pos)
    local epsilon = 0.001
    for _, track in ipairs(tracks) do
        for i = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, i)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
            if pos < to_pos - epsilon and item_end > from_pos then return true end
        end
    end
    return false
end

function M.play_from(edit_pos)
    if not edit_pos then return end
    local start_pos = math.max(edit_pos - M.pre_roll(), 0)
    local tracks = folder_tracks(GetSelectedTrack(0, 0))
    if start_pos < edit_pos and tracks and not has_material_before(tracks, start_pos, edit_pos) then
        start_pos = edit_pos
    end
    audition_playback.play_segment(start_pos, nil)
end

return M
