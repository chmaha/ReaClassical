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

---------------------------------------------------------------------

function M.is_xfade_mode()
    return GetExtState("ReaClassical", "XFadeMode") == "1"
end

function M.get_selection()
    local s = GetExtState("ReaClassical", "XFadeSelection")
    if s == "" then return "both" end
    return s
end

function M.set_selection(sel)
    SetExtState("ReaClassical", "XFadeSelection", sel, false)
end

function M.nudge_amount()
    local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
    return (tonumber(stored) or 5) / 1000
end

---------------------------------------------------------------------

function M.is_folder_track(track)
    if not track then return false end
    return GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
end

function M.get_parent_folder(track)
    if not track then return nil end
    local idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
    end
    return nil
end

function M.get_folder_children(parent_track)
    local children = {}
    if not parent_track then return children end
    local pidx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num = CountTracks(0)
    local i = pidx + 1
    local depth = 1
    while i < num and depth > 0 do
        local tr = GetTrack(0, i)
        if not tr then break end
        local fd = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        children[#children + 1] = tr
        depth = depth + fd
        if depth <= 0 then break end
        i = i + 1
    end
    return children
end

function M.get_folder_tracks(parent_track)
    local ts = { parent_track }
    for _, ch in ipairs(M.get_folder_children(parent_track)) do
        ts[#ts + 1] = ch
    end
    return ts
end

---------------------------------------------------------------------

-- Find adjacent overlapping item pairs on a track (crossfades), sorted by position.
function M.find_crossfades(track)
    local xfades = {}
    local n = CountTrackMediaItems(track)
    for i = 0, n - 2 do
        local item1 = GetTrackMediaItem(track, i)
        local item2 = GetTrackMediaItem(track, i + 1)
        local pos1  = GetMediaItemInfo_Value(item1, "D_POSITION")
        local len1  = GetMediaItemInfo_Value(item1, "D_LENGTH")
        local pos2  = GetMediaItemInfo_Value(item2, "D_POSITION")
        local end1  = pos1 + len1
        if pos2 < end1 - 0.0001 then
            xfades[#xfades + 1] = {
                item1   = item1,  item2   = item2,
                pos1    = pos1,   len1    = len1,  end1 = end1,
                pos2    = pos2,   len2    = GetMediaItemInfo_Value(item2, "D_LENGTH"),
                overlap = end1 - pos2,
                center  = (pos2 + end1) * 0.5
            }
        end
    end
    return xfades
end

-- Items on every track in the folder whose span contains `midpoint`.
function M.get_items_at_midpoint(folder_track, midpoint)
    local tol = 0.0001
    local result = {}
    for _, track in ipairs(M.get_folder_tracks(folder_track)) do
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if midpoint >= (ipos - tol) and midpoint <= (ipos + ilen + tol) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

---------------------------------------------------------------------

function M.set_xfade_state(folder_track, center)
    local idx = math.floor(GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1)
    SetExtState("ReaClassical", "XFadeFolderIdx", tostring(idx),    false)
    SetExtState("ReaClassical", "XFadeCenter",    tostring(center), false)
end

-- Reconstruct full xfade context from stored state. Returns nil if invalid.
function M.get_xfade_context()
    local idx    = tonumber(GetExtState("ReaClassical", "XFadeFolderIdx"))
    local center = tonumber(GetExtState("ReaClassical", "XFadeCenter"))
    if not idx or not center then return nil end

    local folder_track = GetTrack(0, idx)
    if not folder_track then return nil end

    local xfades = M.find_crossfades(folder_track)
    local best, best_dist
    for _, xf in ipairs(xfades) do
        local d = math.abs(xf.center - center)
        if not best_dist or d < best_dist then
            best = xf; best_dist = d
        end
    end
    if not best or best_dist > 2.0 then return nil end

    local pos1 = GetMediaItemInfo_Value(best.item1, "D_POSITION")
    local len1 = GetMediaItemInfo_Value(best.item1, "D_LENGTH")
    local pos2 = GetMediaItemInfo_Value(best.item2, "D_POSITION")
    local len2 = GetMediaItemInfo_Value(best.item2, "D_LENGTH")
    local end1 = pos1 + len1
    local mid1 = pos1 + len1 * 0.5
    local mid2 = pos2 + len2 * 0.5

    return {
        folder_track = folder_track,
        item1 = best.item1,  item2 = best.item2,
        pos1  = pos1,  len1  = len1,  end1 = end1,
        pos2  = pos2,  len2  = len2,  end2 = pos2 + len2,
        overlap   = end1 - pos2,
        center    = (pos2 + end1) * 0.5,
        group1    = M.get_items_at_midpoint(folder_track, mid1),
        group2    = M.get_items_at_midpoint(folder_track, mid2),
        selection = M.get_selection()
    }
end

---------------------------------------------------------------------

-- Select exactly these items, deselect everything else.
function M.select_items(items)
    local sel_set = {}
    for _, it in ipairs(items) do sel_set[it] = true end
    local n = CountMediaItems(0)
    for i = 0, n - 1 do
        local item = GetMediaItem(0, i)
        SetMediaItemSelected(item, sel_set[item] == true)
    end
    UpdateArrange()
end

-- Move all items in the folder at positions > ref_pos by amount, skipping skip_set.
function M.ripple_folder_from(folder_track, ref_pos, amount, skip_set)
    skip_set = skip_set or {}
    local in_folder = {}
    in_folder[folder_track] = true
    for _, ch in ipairs(M.get_folder_children(folder_track)) do
        in_folder[ch] = true
    end
    local n = CountMediaItems(0)
    for i = 0, n - 1 do
        local item = GetMediaItem(0, i)
        if in_folder[GetMediaItemTrack(item)] and not skip_set[item] then
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            if p > ref_pos + 0.0001 then
                SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p + amount))
            end
        end
    end
end

-- Update fade-in/out lengths on both xfade items and their peers to match overlap.
function M.update_xfade_fades(ctx)
    local end1    = GetMediaItemInfo_Value(ctx.item1, "D_POSITION")
                  + GetMediaItemInfo_Value(ctx.item1, "D_LENGTH")
    local pos2    = GetMediaItemInfo_Value(ctx.item2, "D_POSITION")
    local overlap = math.max(0, end1 - pos2)

    -- Exclude item2 from group1 and item1 from group2: with large overlaps the
    -- midpoint of one item can fall inside the other's span, bleeding it into
    -- the wrong group and setting the wrong fade type on it.
    for _, item in ipairs(ctx.group1) do
        if item ~= ctx.item2 then
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN",      overlap)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", overlap)
        end
    end
    for _, item in ipairs(ctx.group2) do
        if item ~= ctx.item1 then
            SetMediaItemInfo_Value(item, "D_FADEINLEN",      overlap)
            SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", overlap)
        end
    end
end

function M.get_item_soffs(item)
    local take = GetActiveTake(item)
    if not take then return 0 end
    return GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
end

function M.set_item_soffs(item, value)
    local take = GetActiveTake(item)
    if take then SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", value) end
end

-- Cycle fade shape 0–6 (skips 7=Default).
function M.next_fade_shape(current)
    return (math.floor(current) + 1) % 7
end

-- OSARA-friendly shape name.
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

---------------------------------------------------------------------

---------------------------------------------------------------------
-- Boundary guards
---------------------------------------------------------------------

local XFADE_MIN_GAP = 0.001  -- 1 ms: smallest allowed non-overlap margin / overlap

-- Prevent item2 from eating into item1's pre-fade content, or item1 from
-- being consumed when overlap grows. Both reduce to the same arithmetic:
-- the available headroom in item1 = len1 - overlap must stay >= XFADE_MIN_GAP.
function M.check_item1_headroom(ctx, amt)
    if ctx.len1 - ctx.overlap - amt < XFADE_MIN_GAP then
        return false, "Cannot move: would consume left item"
    end
    return true
end

-- Prevent item1 from eating into item2's post-fade content, or item2 from
-- being consumed when overlap grows. Headroom in item2 = len2 - overlap.
function M.check_item2_headroom(ctx, amt)
    if ctx.len2 - ctx.overlap - amt < XFADE_MIN_GAP then
        return false, "Cannot move: would consume right item"
    end
    return true
end

-- Prevent the crossfade overlap from dropping to zero (items would disconnect).
function M.check_min_overlap(ctx, amt)
    if ctx.overlap - amt < XFADE_MIN_GAP then
        return false, "Cannot reduce: crossfade would disconnect"
    end
    return true
end

---------------------------------------------------------------------
-- Derive a ProjExtState key from item1's GUID (stable across position changes).
function M.xfade_snap_key(item1)
    local _, guid = GetSetMediaItemInfo_String(item1, "GUID", "", false)
    return "XFSnap_" .. guid:gsub("[{}%-]", "")
end

-- Save a snapshot of the current xfade state if one has not been saved yet for
-- this xfade (identified by item1's GUID). Called from every modifying XFM
-- action before any changes are made, so reverts always go back to the state
-- that existed before the user first touched this xfade in the session.
-- The snapshot key is cleared by the Mode Daemon on entry so stale cross-session
-- data never prevents a fresh capture.
function M.ensure_xfade_snapshot(ctx)
    local key = M.xfade_snap_key(ctx.item1)
    local _, existing = GetProjExtState(0, "ReaClassical", key)
    if existing ~= "" then return end

    local pos1      = GetMediaItemInfo_Value(ctx.item1, "D_POSITION")
    local soffs1    = M.get_item_soffs(ctx.item1)
    local soffs2    = M.get_item_soffs(ctx.item2)
    local len1      = GetMediaItemInfo_Value(ctx.item1, "D_LENGTH")
    local len2      = GetMediaItemInfo_Value(ctx.item2, "D_LENGTH")
    local overlap   = ctx.end1 - ctx.pos2
    local fo_len    = GetMediaItemInfo_Value(ctx.item1, "D_FADEOUTLEN")
    local fi_len    = GetMediaItemInfo_Value(ctx.item2, "D_FADEINLEN")
    local fo_shp    = GetMediaItemInfo_Value(ctx.item1, "C_FADEOUTSHAPE")
    local fi_shp    = GetMediaItemInfo_Value(ctx.item2, "C_FADEINSHAPE")
    local vol1      = GetMediaItemInfo_Value(ctx.item1, "D_VOL")
    local vol2      = GetMediaItemInfo_Value(ctx.item2, "D_VOL")

    SetProjExtState(0, "ReaClassical", key, string.format(
        "%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%d,%d,%.9f,%.9f",
        pos1, len1, soffs1, overlap, len2, soffs2,
        fo_len, fi_len, math.floor(fo_shp), math.floor(fi_shp),
        vol1, vol2
    ))
end

-- Restore the snapshotted state of the current xfade, rippling downstream
-- items by the change in item2's right edge. Returns (true) on success or
-- (false, reason_string) on failure.
function M.revert_xfade_snapshot()
    local ctx = M.get_xfade_context()
    if not ctx then return false, "No crossfade context" end

    local key = M.xfade_snap_key(ctx.item1)
    local _, data = GetProjExtState(0, "ReaClassical", key)
    if data == "" then return false, "No snapshot for this crossfade" end

    local f = {}
    for v in data:gmatch("([^,]+)") do f[#f + 1] = tonumber(v) end
    if #f < 11 then return false, "Snapshot data corrupt" end

    -- Format v1 = 11 fields (no pos1 prefix); format v2 = 12 fields (pos1 first).
    -- Read with an offset so both are handled transparently.
    local o     = (#f >= 12) and 1 or 0
    local len1    = f[1 + o]
    local soffs1  = f[2 + o]
    local overlap = f[3 + o]
    local len2    = f[4 + o]
    local soffs2  = f[5 + o]
    local fo_len  = f[6 + o]
    local fi_len  = f[7 + o]
    local fo_shp  = f[8 + o]
    local fi_shp  = f[9 + o]
    local vol1    = f[10 + o]
    local vol2    = f[11 + o]

    -- Ripple reference: item2's current right edge.
    local old_end2  = ctx.end2
    local new_end1  = ctx.pos1 + len1
    local new_pos2  = new_end1 - overlap
    local new_end2  = new_pos2 + len2
    local delta     = new_end2 - old_end2

    local skip = {}
    for _, it in ipairs(ctx.group1) do skip[it] = true end
    for _, it in ipairs(ctx.group2) do skip[it] = true end

    for _, item in ipairs(ctx.group1) do
        SetMediaItemInfo_Value(item, "D_LENGTH",          len1)
        M.set_item_soffs(item,                            soffs1)
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN",      fo_len)
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", fo_len)
        SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE",    fo_shp)
        SetMediaItemInfo_Value(item, "D_VOL",             vol1)
    end
    for _, item in ipairs(ctx.group2) do
        SetMediaItemInfo_Value(item, "D_POSITION",        math.max(0, new_pos2))
        SetMediaItemInfo_Value(item, "D_LENGTH",          len2)
        M.set_item_soffs(item,                            soffs2)
        SetMediaItemInfo_Value(item, "D_FADEINLEN",       fi_len)
        SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO",  fi_len)
        SetMediaItemInfo_Value(item, "C_FADEINSHAPE",     fi_shp)
        SetMediaItemInfo_Value(item, "D_VOL",             vol2)
    end

    if math.abs(delta) > 0.0001 then
        M.ripple_folder_from(ctx.folder_track, old_end2 - 0.0001, delta, skip)
    end

    M.set_xfade_state(ctx.folder_track, new_pos2 + overlap * 0.5)
    return true
end

---------------------------------------------------------------------

return M
