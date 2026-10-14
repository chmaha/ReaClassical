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

function M.is_xfade_mode()
    return GetExtState("ReaEdit", "XFadeMode") == "1"
end

function M.get_selection()
    local s = GetExtState("ReaEdit", "XFadeSelection")
    if s == "" then return "both" end
    return s
end

function M.set_selection(sel)
    SetExtState("ReaEdit", "XFadeSelection", sel, false)
end

local function pref(n, default)
    local _, stored = GetProjExtState(0, "ReaEdit", "Preferences")
    local i = 0
    for entry in tostring(stored):gmatch("([^,]*)") do
        i = i + 1
        if i == n then return tonumber(entry) or default end
    end
    return default
end

function M.crossfade_length()
    return pref(1, 35) / 1000
end

function M.nudge_amount()
    return pref(2, 5) / 1000
end

function M.modifier_factor()
    return pref(3, 5)
end

function M.all_tracks()
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        tracks[#tracks + 1] = GetTrack(0, i)
    end
    return tracks
end

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

function M.get_previous_on_track(item)
    local track = GetMediaItemTrack(item)
    local n = CountTrackMediaItems(track)
    for i = 0, n - 1 do
        if GetTrackMediaItem(track, i) == item then
            return i > 0 and GetTrackMediaItem(track, i - 1) or nil
        end
    end
    return nil
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

function M.get_items_at_midpoint(midpoint)
    local tol = 0.0001
    local result = {}
    for _, track in ipairs(M.all_tracks()) do
        local n = CountTrackMediaItems(track)
        if n > 0 then
            local idx = last_item_at_or_before(track, n, midpoint)
            for _, i in ipairs({ idx - 1, idx, idx + 1 }) do
                if i >= 0 and i < n then
                    local item = GetTrackMediaItem(track, i)
                    local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
                    local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
                    if midpoint >= (ipos - tol) and midpoint <= (ipos + ilen + tol) then
                        result[#result + 1] = item
                    end
                end
            end
        end
    end
    return result
end

function M.set_xfade_state(ref_track, center)
    local idx = math.floor(GetMediaTrackInfo_Value(ref_track, "IP_TRACKNUMBER") - 1)
    SetExtState("ReaEdit", "XFadeTrackIdx", tostring(idx),    false)
    SetExtState("ReaEdit", "XFadeCenter",    tostring(center), false)
end

function M.get_xfade_context()
    local idx    = tonumber(GetExtState("ReaEdit", "XFadeTrackIdx"))
    local center = tonumber(GetExtState("ReaEdit", "XFadeCenter"))
    if not idx or not center then return nil end

    local ref_track = GetTrack(0, idx)
    if not ref_track then return nil end

    local xfades = M.find_crossfades(ref_track)
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
        ref_track = ref_track,
        item1 = best.item1,  item2 = best.item2,
        pos1  = pos1,  len1  = len1,  end1 = end1,
        pos2  = pos2,  len2  = len2,  end2 = pos2 + len2,
        overlap   = end1 - pos2,
        center    = (pos2 + end1) * 0.5,
        group1    = M.get_items_at_midpoint(mid1),
        group2    = M.get_items_at_midpoint(mid2),
        selection = M.get_selection()
    }
end

function M.select_items(items)
    Main_OnCommand(40289, 0)
    for _, it in ipairs(items) do
        SetMediaItemSelected(it, true)
    end
    UpdateArrange()
end

function M.focus_crossfade(ref_track, xf)
    M.set_xfade_state(ref_track, xf.center)
    M.set_selection("both")
    local mid1 = xf.pos1 + xf.len1 * 0.5
    local mid2 = xf.pos2 + xf.len2 * 0.5
    local all = {}
    for _, it in ipairs(M.get_items_at_midpoint(mid1)) do all[#all + 1] = it end
    for _, it in ipairs(M.get_items_at_midpoint(mid2)) do all[#all + 1] = it end
    M.select_items(all)
    SetEditCurPos(xf.center, true, false)
end

function M.ripple_all_from(ref_pos, amount, skip_set)
    skip_set = skip_set or {}
    local n = CountMediaItems(0)
    for i = 0, n - 1 do
        local item = GetMediaItem(0, i)
        if not skip_set[item] then
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            if p > ref_pos + 0.0001 then
                SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p + amount))
            end
        end
    end
    M.shift_automation_from(ref_pos, amount)
end

function M.shift_automation_from(ref_pos, amount)
    local n = CountTracks(0)
    for t = 0, n - 1 do
        local track = GetTrack(0, t)
        local num_envs = CountTrackEnvelopes(track)
        for e = 0, num_envs - 1 do
            local env = GetTrackEnvelope(track, e)

            local num_points = CountEnvelopePoints(env)
            local points_to_shift = {}
            for p = 0, num_points - 1 do
                local retval, time, value, shape, tension, selected = GetEnvelopePoint(env, p)
                if time > ref_pos + 0.0001 then
                    points_to_shift[#points_to_shift + 1] = {
                        time = time,
                        new_time = math.max(0, time + amount),
                        value = value,
                        shape = shape,
                        tension = tension,
                        selected = selected
                    }
                end
            end
            for i = #points_to_shift, 1, -1 do
                local pt = points_to_shift[i]
                DeleteEnvelopePointRange(env, pt.time - 0.0001, pt.time + 0.0001)
            end
            for _, pt in ipairs(points_to_shift) do
                InsertEnvelopePoint(env, pt.new_time, pt.value, pt.shape, pt.tension, pt.selected, true)
            end
            if #points_to_shift > 0 then
                Envelope_SortPoints(env)
            end

            local num_ai = CountAutomationItems(env)
            for ai = 0, num_ai - 1 do
                local ai_pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
                if ai_pos > ref_pos + 0.0001 then
                    GetSetAutomationItemInfo(env, ai, "D_POSITION", math.max(0, ai_pos + amount), true)
                end
            end
        end
    end
end

function M.update_xfade_fades(ctx)
    local end1    = GetMediaItemInfo_Value(ctx.item1, "D_POSITION")
                  + GetMediaItemInfo_Value(ctx.item1, "D_LENGTH")
    local pos2    = GetMediaItemInfo_Value(ctx.item2, "D_POSITION")
    local overlap = math.max(0, end1 - pos2)

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

local XFADE_MIN_GAP = 0.001

function M.check_item1_headroom(ctx, amt)
    if ctx.len1 - ctx.overlap - amt < XFADE_MIN_GAP then
        return false, "Cannot move: would consume left item"
    end
    return true
end

function M.check_item2_headroom(ctx, amt)
    if ctx.len2 - ctx.overlap - amt < XFADE_MIN_GAP then
        return false, "Cannot move: would consume right item"
    end
    return true
end

function M.check_min_overlap(ctx, amt)
    if ctx.overlap - amt < XFADE_MIN_GAP then
        return false, "Cannot reduce: crossfade would disconnect"
    end
    return true
end

function M.xfade_snap_key(item1)
    local _, guid = GetSetMediaItemInfo_String(item1, "GUID", "", false)
    return "XFSnap_" .. guid:gsub("[{}%-]", "")
end

function M.ensure_xfade_snapshot(ctx)
    local key = M.xfade_snap_key(ctx.item1)
    local _, existing = GetProjExtState(0, "ReaEdit", key)
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

    SetProjExtState(0, "ReaEdit", key, string.format(
        "%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%d,%d,%.9f,%.9f",
        pos1, len1, soffs1, overlap, len2, soffs2,
        fo_len, fi_len, math.floor(fo_shp), math.floor(fi_shp),
        vol1, vol2
    ))
end

function M.revert_xfade_snapshot()
    local ctx = M.get_xfade_context()
    if not ctx then return false, "No crossfade context" end

    local key = M.xfade_snap_key(ctx.item1)
    local _, data = GetProjExtState(0, "ReaEdit", key)
    if data == "" then return false, "No snapshot for this crossfade" end

    local f = {}
    for v in data:gmatch("([^,]+)") do f[#f + 1] = tonumber(v) end
    if #f < 11 then return false, "Snapshot data corrupt" end

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
        M.ripple_all_from(old_end2 - 0.0001, delta, skip)
    end

    M.set_xfade_state(ctx.ref_track, new_pos2 + overlap * 0.5)
    return true
end

function M.item_label(item)
    local name = ""
    local take = GetActiveTake(item)
    if take then
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        name = take_name or ""
    end
    name = name:match("^%s*(.-)%s*$")
    return name ~= "" and name or "no name"
end

return M
