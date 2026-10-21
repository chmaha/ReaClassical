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

-- Snapshot of the destination material an S-D style edit replaces, so that
-- Heal Edit can put it back. Flow in an edit script:
--   capture(...)  before the destination is split
--   stamp(item)   for every new S-D item (P_EXT:SD_id)
--   commit()      once crossfades are done
-- Item chunks live in project ExtState (SDSnap_<id>, SDSnap_<id>_<n>).

local enum_project_markers = require("ReaClassical_Marker_Enum")

local M = {}

local EXT = "ReaClassical"
local PREFIX = "SDSnap_"
local EPS = 0.0001

local pending = nil

local function escape(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return s
end

local function unescape(s)
    local map = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\" }
    return (s:gsub("\\(.)", function(c) return map[c] or c end))
end

local function item_bounds(item)
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    return pos, pos + GetMediaItemInfo_Value(item, "D_LENGTH")
end

local function get_sd_id(item)
    local _, sid = GetSetMediaItemInfo_String(item, "P_EXT:SD_id", "", false)
    return sid
end

local function window_counts(tracks, w_start, w_end)
    local counts = {}
    for ti, track in ipairs(tracks) do
        local n = 0
        for i = 0, CountTrackMediaItems(track) - 1 do
            local pos, item_end = item_bounds(GetTrackMediaItem(track, i))
            if pos >= w_start - EPS and item_end <= w_end + EPS then n = n + 1 end
        end
        counts[ti] = n
    end
    return table.concat(counts, ",")
end

-- Finds the post-edit window on the parent track from the stamped S-D items
-- and the neighbours the edit left either side of them.
local function post_window(tracks, id, meta)
    local parent = tracks[1]
    local n = CountTrackMediaItems(parent)
    local first, last, count
    count = 0
    for i = 0, n - 1 do
        if get_sd_id(GetTrackMediaItem(parent, i)) == id then
            first = first or i
            last = i
            count = count + 1
        end
    end
    if not first then return nil end

    local w_start
    if meta.l_off then
        if first == 0 then return nil end
        local prev_pos = item_bounds(GetTrackMediaItem(parent, first - 1))
        w_start = prev_pos - meta.l_off
    else
        w_start = meta.w_start
    end

    local w_end
    if meta.r_off then
        if last >= n - 1 then return nil end
        local _, next_end = item_bounds(GetTrackMediaItem(parent, last + 1))
        w_end = next_end + meta.r_off
    else
        local _, last_end = item_bounds(GetTrackMediaItem(parent, last))
        w_end = last_end
    end

    if w_end < w_start then return nil end
    return w_start, w_end, count
end

local function serialize_meta(p, counts)
    local function opt(v) return v and string.format("%.9f", v) or "-" end
    return table.concat({
        "1",
        tostring(#p.tracks),
        tostring(#p.captured),
        opt(p.l_off),
        opt(p.r_off),
        string.format("%.9f", p.w_start),
        string.format("%.9f", p.pre_len),
        counts,
    }, ";")
end

local function parse_meta(str)
    local f = {}
    for field in (str .. ";"):gmatch("([^;]*);") do f[#f + 1] = field end
    if f[1] ~= "1" or #f < 8 then return nil end
    return {
        n_tracks = tonumber(f[2]),
        n_items = tonumber(f[3]),
        l_off = tonumber(f[4]),
        r_off = tonumber(f[5]),
        w_start = tonumber(f[6]),
        pre_len = tonumber(f[7]),
        counts = f[8],
    }
end

function M.marker_pos(marker_id)
    local i = 0
    while true do
        local retval, isrgn, pos, _, _, num = enum_project_markers(0, i)
        if not retval then return nil end
        if not isrgn and num == marker_id then return pos end
        i = i + 1
    end
end

function M.capture(tracks, t_left, t_right)
    pending = nil
    if not tracks or #tracks == 0 or not t_left then return end
    t_right = t_right or t_left

    local w_start, w_end = t_left, t_right
    local captured
    for _ = 1, 10 do
        captured = {}
        local new_start, new_end = w_start, w_end
        for ti, track in ipairs(tracks) do
            for i = 0, CountTrackMediaItems(track) - 1 do
                local item = GetTrackMediaItem(track, i)
                local pos, item_end = item_bounds(item)
                if pos < w_end - EPS and item_end > w_start + EPS then
                    local _, chunk = GetItemStateChunk(item, "", false)
                    captured[#captured + 1] = { track_idx = ti, pos = pos, chunk = chunk }
                    new_start = math.min(new_start, pos)
                    new_end = math.max(new_end, item_end)
                end
            end
        end
        if math.abs(new_start - w_start) < EPS and math.abs(new_end - w_end) < EPS then
            w_start, w_end = new_start, new_end
            break
        end
        w_start, w_end = new_start, new_end
    end

    local parent = tracks[1]
    local l_off, r_off
    local left_anchor_pos, right_anchor_end
    for i = 0, CountTrackMediaItems(parent) - 1 do
        local pos, item_end = item_bounds(GetTrackMediaItem(parent, i))
        if pos < t_left - EPS and (not left_anchor_pos or pos >= left_anchor_pos) then
            left_anchor_pos = pos
        end
        if not right_anchor_end and item_end > t_right + EPS then
            right_anchor_end = item_end
        end
    end
    if left_anchor_pos then l_off = left_anchor_pos - w_start end
    if right_anchor_end then r_off = w_end - right_anchor_end end

    pending = {
        id = genGuid(""):gsub("[{}%-]", ""),
        tracks = tracks,
        captured = captured,
        l_off = l_off,
        r_off = r_off,
        w_start = w_start,
        pre_len = w_end - w_start,
    }
end

function M.stamp(item)
    if not pending or not item then return end
    GetSetMediaItemInfo_String(item, "P_EXT:SD_id", pending.id, true)
end

function M.purge()
    local referenced = {}
    for i = 0, CountMediaItems(0) - 1 do
        local sid = get_sd_id(GetMediaItem(0, i))
        if sid ~= "" then referenced[sid] = true end
    end

    local values = {}
    local metas = {}
    local i = 0
    while true do
        local ok, key, val = EnumProjExtState(0, EXT, i)
        if not ok then break end
        if key:sub(1, #PREFIX) == PREFIX then
            values[#values + 1] = { key = key, val = val }
            local sid = key:match("^" .. PREFIX .. "(%x+)$")
            if sid then metas[sid] = true end
        end
        i = i + 1
    end

    -- a snapshot can itself hold items from an earlier, still healable edit
    local changed = true
    while changed do
        changed = false
        for sid in pairs(referenced) do
            for _, entry in ipairs(values) do
                if entry.key:sub(1, #PREFIX + #sid + 1) == PREFIX .. sid .. "_" then
                    for other in pairs(metas) do
                        if not referenced[other] and entry.val:find(other, 1, true) then
                            referenced[other] = true
                            changed = true
                        end
                    end
                end
            end
        end
    end

    for _, entry in ipairs(values) do
        local sid = entry.key:match("^" .. PREFIX .. "(%x+)")
        if sid and not referenced[sid] then
            SetProjExtState(0, EXT, entry.key, "")
        end
    end
end

function M.commit()
    local p = pending
    pending = nil
    if not p then return false end

    local w_start, w_end = post_window(p.tracks, p.id, p)
    if not w_start then return false end

    M.purge()

    SetProjExtState(0, EXT, PREFIX .. p.id,
        serialize_meta(p, window_counts(p.tracks, w_start, w_end)))
    for n, entry in ipairs(p.captured) do
        SetProjExtState(0, EXT, PREFIX .. p.id .. "_" .. n,
            string.format("%d\t%.9f\t%s", entry.track_idx, entry.pos - p.w_start,
                escape(entry.chunk)))
    end
    return true
end

-- Puts the replaced material back. Returns nil when the snapshot cannot be
-- used (caller falls back to the like-material heal), otherwise true and the
-- number of S-D items that were healed.
function M.restore(tracks, id)
    if not tracks or #tracks == 0 or not id or id == "" then return nil end
    local _, meta_str = GetProjExtState(0, EXT, PREFIX .. id)
    if meta_str == "" then return nil end
    local meta = parse_meta(meta_str)
    if not meta or meta.n_tracks ~= #tracks then return nil end

    local saved = {}
    for n = 1, meta.n_items do
        local _, val = GetProjExtState(0, EXT, PREFIX .. id .. "_" .. n)
        local ti, rel, chunk = val:match("^(%d+)\t([^\t]+)\t(.*)$")
        if not ti then return nil end
        saved[#saved + 1] = { track_idx = tonumber(ti), rel = tonumber(rel),
            chunk = unescape(chunk) }
    end

    local w_start, w_end, sd_count = post_window(tracks, id, meta)
    if not w_start then return nil end
    if window_counts(tracks, w_start, w_end) ~= meta.counts then return nil end

    local delta = meta.pre_len - (w_end - w_start)
    local to_delete, to_shift = {}, {}
    for _, track in ipairs(tracks) do
        for i = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, i)
            local pos, item_end = item_bounds(item)
            if pos >= w_start - EPS and item_end <= w_end + EPS then
                to_delete[#to_delete + 1] = item
            elseif pos >= w_end - EPS then
                to_shift[#to_shift + 1] = { item = item, pos = pos }
            end
        end
    end

    for _, item in ipairs(to_delete) do
        DeleteTrackMediaItem(GetMediaItem_Track(item), item)
    end
    if delta ~= 0 then
        for _, entry in ipairs(to_shift) do
            SetMediaItemInfo_Value(entry.item, "D_POSITION", entry.pos + delta)
        end
    end
    for _, entry in ipairs(saved) do
        local track = tracks[entry.track_idx]
        if track then
            local item = AddMediaItemToTrack(track)
            SetItemStateChunk(item, entry.chunk, false)
            SetMediaItemInfo_Value(item, "D_POSITION", w_start + entry.rel)
            SetMediaItemSelected(item, false)
        end
    end

    return true, sd_count
end

return M
