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

local TAG_KEYS = {
    "mixer", "aux", "submix", "roomtone", "live",
    "rcref", "listenback", "rcmaster", "playback",
}

local function build()
    local num_tracks = CountTracks(0)
    local tags = {}
    local is_special = {}
    local parent = {}
    local folders = {}

    local depth_sum = 0
    local current_parent = nil

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)

        local track_tags = {}
        local special = false
        for _, key in ipairs(TAG_KEYS) do
            local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
            local flag = val == "y"
            track_tags[key] = flag
            if flag then special = true end
        end
        tags[track] = track_tags
        is_special[track] = special

        local d = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if depth_sum == 0 then
            if d == 1 and not special then
                current_parent = track
                folders[#folders + 1] = { track = track, idx = i }
                parent[track] = track
            else
                current_parent = nil
                parent[track] = nil
            end
        else
            parent[track] = current_parent
        end

        depth_sum = depth_sum + d
        if depth_sum < 0 then depth_sum = 0 end
    end

    return {
        tags = tags,
        is_special = is_special,
        parent = parent,
        folders = folders,
    }
end

return { build = build }
