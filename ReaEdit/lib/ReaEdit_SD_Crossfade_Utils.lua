--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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

local MIN_GAP = 0.001

function M.set_item_edge(item, is_right_edge, new_pos)
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
    if is_right_edge then
        SetMediaItemInfo_Value(item, "D_LENGTH", math.max(0, new_pos - pos))
    else
        local delta = new_pos - pos
        local take = GetActiveTake(item)
        if take then
            local rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
            local soffs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", soffs + delta * rate)
        end
        SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
        SetMediaItemInfo_Value(item, "D_LENGTH", math.max(0, len - delta))
    end
end

function M.get_extend_room(item, is_right_edge)
    local take = GetActiveTake(item)
    if not take then return 0 end
    local rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if rate == 0 then return 0 end
    local soffs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    if is_right_edge then
        local source = GetMediaItemTake_Source(take)
        if not source then return 0 end
        local src_len, length_is_qn = GetMediaSourceLength(source)
        if length_is_qn then return 0 end
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local used_end = soffs + len * rate
        return math.max(0, (src_len - used_end) / rate)
    else
        return math.max(0, soffs / rate)
    end
end

function M.get_adjacent_neighbors(items, edge)
    local neighbors = {}
    for idx, item in ipairs(items) do
        local track = GetMediaItemTrack(item)
        local n = CountTrackMediaItems(track)
        for j = 0, n - 1 do
            if GetTrackMediaItem(track, j) == item then
                if edge == "right" then
                    neighbors[idx] = (j < n - 1) and GetTrackMediaItem(track, j + 1) or nil
                else
                    neighbors[idx] = (j > 0) and GetTrackMediaItem(track, j - 1) or nil
                end
                break
            end
        end
    end
    return neighbors
end

function M.create_crossfade(items, neighbors, edge, requested_len)
    local is_right_edge = (edge == "right")

    local has_any_neighbor = false
    for i = 1, #items do
        if neighbors[i] then has_any_neighbor = true end
    end
    if not has_any_neighbor then return 0, false end

    local clamped = requested_len
    for i, item in ipairs(items) do
        clamped = math.min(clamped, M.get_extend_room(item, is_right_edge))
        local nb = neighbors[i]
        if nb then
            clamped = math.min(clamped, GetMediaItemInfo_Value(nb, "D_LENGTH") - MIN_GAP)
        end
    end
    clamped = math.max(0, clamped)

    for i, item in ipairs(items) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local new_edge_pos = is_right_edge and (pos + len + clamped) or (pos - clamped)
        M.set_item_edge(item, is_right_edge, new_edge_pos)

        if is_right_edge then
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN", clamped)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", clamped)
        else
            SetMediaItemInfo_Value(item, "D_FADEINLEN", clamped)
            SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", clamped)
        end

        local nb = neighbors[i]
        if nb then
            if is_right_edge then
                SetMediaItemInfo_Value(nb, "D_FADEINLEN", clamped)
                SetMediaItemInfo_Value(nb, "D_FADEINLEN_AUTO", clamped)
            else
                SetMediaItemInfo_Value(nb, "D_FADEOUTLEN", clamped)
                SetMediaItemInfo_Value(nb, "D_FADEOUTLEN_AUTO", clamped)
            end
        end
    end

    return clamped, clamped < requested_len - 0.0001
end

function M.all_tracks()
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        tracks[#tracks + 1] = GetTrack(0, i)
    end
    return tracks
end

function M.remove_extra_overlaps(tracks, t_left, t_right)
    local epsilon = 0.0001
    local removed = {}
    local pending = {}
    local by_track = {}

    if not tracks then return 0, removed end

    for _, track in ipairs(tracks) do
        local n = CountTrackMediaItems(track)
        local entries = {}
        by_track[track] = entries
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            if len <= epsilon then
                table.insert(removed, item)
                table.insert(pending, { track = track, item = item })
            elseif pos + len > t_left + epsilon and pos < t_right - epsilon then
                entries[#entries + 1] =
                    { item = item, pos = pos, end_pos = pos + len }
            end
        end
    end

    local function find_crowded_moment(entries)
        local events = {}
        for _, entry in ipairs(entries) do
            events[#events + 1] = { t = entry.pos, delta = 1, entry = entry }
            events[#events + 1] = { t = entry.end_pos, delta = -1, entry = entry }
        end
        table.sort(events, function(a, b)
            if a.t ~= b.t then return a.t < b.t end
            return a.delta < b.delta
        end)
        local live = {}
        local count = 0
        for _, ev in ipairs(events) do
            if ev.delta == 1 then
                count = count + 1
                live[ev.entry] = true
            else
                count = count - 1
                live[ev.entry] = nil
            end
            if count >= 3 then return live end
        end
        return nil
    end

    for _, entries in pairs(by_track) do
        while true do
            local live = find_crowded_moment(entries)
            if not live then break end
            local victim, victim_len, victim_pos
            for entry in pairs(live) do
                local len = entry.end_pos - entry.pos
                if not victim
                    or len < victim_len - epsilon
                    or (len < victim_len + epsilon and entry.pos > victim_pos) then
                    victim, victim_len, victim_pos = entry, len, entry.pos
                end
            end
            table.insert(removed, victim.item)
            table.insert(pending, { track = GetMediaItemTrack(victim.item), item = victim.item })
            for idx, entry in ipairs(entries) do
                if entry == victim then
                    table.remove(entries, idx)
                    break
                end
            end
        end
    end

    for _, entry in ipairs(pending) do
        DeleteTrackMediaItem(entry.track, entry.item)
    end

    return #removed, removed
end

return M
