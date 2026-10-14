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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local sdcu = require("ReaClassical_SD_Crossfade_Utils")

local M = {}

function M.is_folder_track(track)
    if not track then return false end
    return GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
end

function M.get_parent_folder(track)
    if not track then return nil end
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = track_idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
    end
    return nil
end

function M.get_folder_children(parent_track)
    local children = {}
    if not parent_track then return children end
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end
        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        table.insert(children, tr)
        depth = depth + folder_depth
        if depth <= 0 then break end
        idx = idx + 1
    end
    return children
end

local function last_item_at_or_before(tr, n, target)
    local lo, hi, found = 0, n - 1, -1
    while lo <= hi do
        local mid_idx = (lo + hi) // 2
        local item = GetTrackMediaItem(tr, mid_idx)
        if GetMediaItemInfo_Value(item, "D_POSITION") <= target then
            found = mid_idx
            lo = mid_idx + 1
        else
            hi = mid_idx - 1
        end
    end
    return found
end

function M.get_item_peers(ref_item)
    local track = GetMediaItemTrack(ref_item)
    local folder_track = M.is_folder_track(track) and track or M.get_parent_folder(track)
    if not folder_track then return { ref_item } end

    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001

    local tracks = { folder_track }
    for _, ch in ipairs(M.get_folder_children(folder_track)) do tracks[#tracks + 1] = ch end

    local result = {}
    for _, tr in ipairs(tracks) do
        local n = CountTrackMediaItems(tr)
        if n > 0 then
            local idx = last_item_at_or_before(tr, n, mid)
            for _, i in ipairs({ idx - 1, idx, idx + 1 }) do
                if i >= 0 and i < n then
                    local item = GetTrackMediaItem(tr, i)
                    local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
                    local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
                    if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                        result[#result + 1] = item
                    end
                end
            end
        end
    end
    return result
end

function M.get_adjacent_on_track(item)
    local track = GetMediaItemTrack(item)
    local n = CountTrackMediaItems(track)
    for i = 0, n - 1 do
        if GetTrackMediaItem(track, i) == item then
            local prev = i > 0 and GetTrackMediaItem(track, i - 1) or nil
            local nxt  = i < n - 1 and GetTrackMediaItem(track, i + 1) or nil
            return prev, nxt
        end
    end
    return nil, nil
end

function M.left_edge_crossfaded(item)
    local prev = M.get_adjacent_on_track(item)
    if not prev then return false end
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local prev_end = GetMediaItemInfo_Value(prev, "D_POSITION") + GetMediaItemInfo_Value(prev, "D_LENGTH")
    return pos < prev_end - 0.0001
end

function M.right_edge_crossfaded(item)
    local _, nxt = M.get_adjacent_on_track(item)
    if not nxt then return false end
    local end_pos = GetMediaItemInfo_Value(item, "D_POSITION") + GetMediaItemInfo_Value(item, "D_LENGTH")
    local nxt_pos = GetMediaItemInfo_Value(nxt, "D_POSITION")
    return end_pos > nxt_pos + 0.0001
end

function M.edge_crossfade_state(item)
    local prev, nxt = M.get_adjacent_on_track(item)
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local len = GetMediaItemInfo_Value(item, "D_LENGTH")

    local left = false
    if prev then
        local prev_end = GetMediaItemInfo_Value(prev, "D_POSITION") + GetMediaItemInfo_Value(prev, "D_LENGTH")
        left = pos < prev_end - 0.0001
    end

    local right = false
    if nxt then
        local nxt_pos = GetMediaItemInfo_Value(nxt, "D_POSITION")
        right = (pos + len) > nxt_pos + 0.0001
    end

    return left, right
end

function M.next_fade_shape(current)
    return (math.floor(current) + 1) % 7
end

function M.shape_name(s)
    local names = {
        [0] = "Linear",
        "Equal Power",
        "Inverse Power",
        "High Blend",
        "Low Blend",
        "S-Curve",
        "S-Curve Steep",
    }
    local n = math.floor(s)
    return names[n] or ("Shape " .. n)
end

function M.humanize_item_name(name)
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        return prefix .. " take " .. tonumber(take_num)
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        return "Take " .. tonumber(only_num)
    end
    return name
end

function M.item_label(item, rank_info)
    local name = ""
    local take = GetActiveTake(item)
    if take then
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        name = take_name
    end
    local label = M.humanize_item_name(rank_info.strip_rank_prefix(name))
    if label == "" then label = "no name" end
    return label .. rank_info.rank_announce_suffix(item)
end

local MIN_ITEM_LEN = 0.001

local function grow_room(items, is_right_edge)
    local room = math.huge
    for _, item in ipairs(items) do
        room = math.min(room, sdcu.get_extend_room(item, is_right_edge))
        local prev, nxt = M.get_adjacent_on_track(item)
        local neighbor
        if is_right_edge then
            neighbor = nxt
        else
            neighbor = prev
        end
        if neighbor then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local n_pos = GetMediaItemInfo_Value(neighbor, "D_POSITION")
            local n_len = GetMediaItemInfo_Value(neighbor, "D_LENGTH")
            local gap = is_right_edge
                and (n_pos - (pos + len))
                or  (pos - (n_pos + n_len))
            room = math.min(room, math.max(0, gap))
        end
    end
    return room
end

local function shrink_room(items)
    local room = math.huge
    for _, item in ipairs(items) do
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        room = math.min(room, math.max(0, len - MIN_ITEM_LEN))
    end
    return room
end

function M.resize_edge(items, is_right_edge, grow, requested_amt)
    local room = grow and grow_room(items, is_right_edge) or shrink_room(items)
    local amt = math.max(0, math.min(requested_amt, room))
    if amt <= 0 then return 0 end

    for _, item in ipairs(items) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local delta
        if is_right_edge then
            delta = grow and amt or -amt
        else
            delta = grow and -amt or amt
        end
        local new_edge_pos = is_right_edge and (pos + len + delta) or (pos + delta)
        sdcu.set_item_edge(item, is_right_edge, new_edge_pos)
    end
    return amt
end

return M
