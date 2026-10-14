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

local SPECIAL_KEYS = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }

local function is_special_track(track)
    for _, key in ipairs(SPECIAL_KEYS) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

function M.count_selected_parent_items()
    local count = 0
    local n = CountSelectedMediaItems(0)
    for i = 0, n - 1 do
        local item = GetSelectedMediaItem(0, i)
        local track = GetMediaItemTrack(item)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 and not is_special_track(track) then
            count = count + 1
        end
    end
    return count
end

return M
