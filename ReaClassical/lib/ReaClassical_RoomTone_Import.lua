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

local enum_project_markers = require("ReaClassical_Marker_Enum")

local M = {}

function M.ensure_item(rt_track)
    if not rt_track then return nil end
    if CountTrackMediaItems(rt_track) > 0 then
        return GetTrackMediaItem(rt_track, 0)
    end

    local media_path = GetProjectPathEx(0)
    if not media_path or media_path == "" then return nil end

    local src = PCM_Source_CreateFromFile(media_path .. "/roomtone.wav")
    if not src then return nil end

    local item = AddMediaItemToTrack(rt_track)
    local take = AddTakeToMediaItem(item)
    SetMediaItemTake_Source(take, src)
    SetMediaItemInfo_Value(item, "D_POSITION", 0)
    SetMediaItemInfo_Value(item, "D_LENGTH", GetMediaSourceLength(src))
    GetSetMediaItemTakeInfo_String(take, "P_NAME", "roomtone.wav", true)
    return item
end

function M.resize_to(rt_item, target_end)
    if not rt_item or not target_end or target_end <= 0 then return 0 end
    local take = GetActiveTake(rt_item)
    if not take then return 0 end
    local src = GetMediaItemTake_Source(take)
    if not src then return 0 end

    local item_start = GetMediaItemInfo_Value(rt_item, "D_POSITION")
    local desired_len = target_end - item_start
    if desired_len <= 0 then return 0 end

    local src_len = GetMediaSourceLength(src)
    SetMediaItemInfo_Value(rt_item, "D_LENGTH", math.min(desired_len, src_len))

    return math.max(0, desired_len - src_len)
end

function M.find_end_marker_pos(proj)
    proj = proj or 0
    local num_markers = GetNumRegionsOrMarkers(proj)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, _, name = enum_project_markers(proj, i)
        if retval and not isrgn and name == "=END" then
            return pos
        end
    end
    return nil
end

function M.find_first_folder_end(proj)
    proj = proj or 0
    local track = GetTrack(proj, 0)
    if not track then return nil end
    local count = CountTrackMediaItems(track)
    if count == 0 then return nil end
    local last_item = GetTrackMediaItem(track, count - 1)
    local pos = GetMediaItemInfo_Value(last_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(last_item, "D_LENGTH")
    return pos + len
end

return M
