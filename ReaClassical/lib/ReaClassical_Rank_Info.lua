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

local M = {}

M.RANKS = {
    { name = "Excellent",     rgba = 0x39FF1499, prefix = "Excellent",     spoken = "excellent" },
    { name = "Very Good",     rgba = 0x32CD3299, prefix = "Very Good",     spoken = "very good" },
    { name = "Good",          rgba = 0x00AD8399, prefix = "Good",          spoken = "good" },
    { name = "OK",            rgba = 0xFFFFAA99, prefix = "OK",            spoken = "OK" },
    { name = "Below Average", rgba = 0xFFBF0099, prefix = "Below Average", spoken = "below average" },
    { name = "Poor",          rgba = 0xFF753899, prefix = "Poor",          spoken = "poor" },
    { name = "Unusable",      rgba = 0xDC143C99, prefix = "Unusable",      spoken = "unusable" },
    { name = "False Start",   rgba = 0x2A2A2AFF, prefix = "False Start",   spoken = "false start" },
    { name = "No Rank",       rgba = 0x00000000, prefix = "",              spoken = "" },
}

M.RANK_LETTERS = { e = 1, v = 2, g = 3, o = 4, b = 5, p = 6, u = 7, f = 8, n = 9 }

function M.strip_rank_prefix(name)
    for i = 1, 8 do
        local prefix = M.RANKS[i].prefix
        if name == prefix then return "" end
        name = name:gsub("%-" .. prefix .. "$", "")
        name = name:gsub("^" .. prefix .. "%-", "")
    end
    return name
end

function M.get_folder_range_for_item(ref_item)
    local track = GetMediaItem_Track(ref_item)
    local track_num = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local start_search = track_num
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
    local folder_start, folder_end = nil, nil
    for t = start_search, num_tracks - 1 do
        local tt = GetTrack(0, t)
        if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    return folder_start, folder_end
end

function M.get_items_at_midpoint(ref_item)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    local folder_start, folder_end = M.get_folder_range_for_item(ref_item)
    if not folder_start then return result end
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

local function rgba_to_native(rgba)
    local r = (rgba >> 24) & 0xFF
    local g = (rgba >> 16) & 0xFF
    local b = (rgba >> 8) & 0xFF
    return ColorToNative(r, g, b)
end

local function pastel_color(index)
    local golden_ratio_conjugate = 0.61803398875
    local hue        = (index * golden_ratio_conjugate) % 1.0
    local saturation = 0.45 + 0.15 * math.sin(index * 1.7)
    local lightness  = 0.70 + 0.1 * math.cos(index * 1.1)

    local function h2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    local q = lightness < 0.5 and (lightness * (1 + saturation))
        or (lightness + saturation - lightness * saturation)
    local p = 2 * lightness - q

    local r = h2rgb(p, q, hue + 1 / 3)
    local g = h2rgb(p, q, hue)
    local b = h2rgb(p, q, hue - 1 / 3)

    local color_int = ColorToNative(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )
    return color_int | 0x1000000
end

function M.get_item_color(item)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local colors = require("ReaClassical_Colors_Table")

    local color_to_use = nil
    local _, saved_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)

    if saved_guid ~= "" then
        local total_items = CountMediaItems(0)
        for i = 0, total_items - 1 do
            local test_item = GetMediaItem(0, i)
            local _, test_guid = GetSetMediaItemInfo_String(test_item, "GUID", "", false)
            if test_guid == saved_guid then
                color_to_use = GetMediaItemInfo_Value(test_item, "I_CUSTOMCOLOR")
                break
            end
        end
    end

    if workflow == "Horizontal" then
        local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
        if saved_color ~= "" then
            color_to_use = tonumber(saved_color)
        else
            color_to_use = colors.dest_items
        end
    elseif not color_to_use then
        local item_track = GetMediaItemTrack(item)
        local folder_tracks = {}
        local num_tracks = CountTracks(0)

        for t = 0, num_tracks - 1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth > 0 then table.insert(folder_tracks, track) end
        end

        local parent_folder = nil
        local track_idx = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER") - 1
        for t = track_idx, 0, -1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth > 0 then
                parent_folder = track; break
            end
        end

        local folder_index = 0
        if parent_folder then
            for i, track in ipairs(folder_tracks) do
                if track == parent_folder then
                    folder_index = i - 2
                    break
                end
            end
            if folder_index < 0 then
                color_to_use = colors.dest_items
            else
                color_to_use = pastel_color(folder_index)
            end
        else
            color_to_use = colors.dest_items
        end
    end

    return color_to_use
end

function M.get_ranking_color_pref()
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local pref = 0
    if input ~= "" then
        local fields = {}
        for entry in input:gmatch("([^,]+)") do fields[#fields + 1] = entry end
        if fields[6] then pref = tonumber(fields[6]) or 0 end
    end
    return pref
end

function M.get_current_rank(item)
    local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
    local rank_index = tonumber(rank_str)
    if not (rank_index and rank_index >= 1 and rank_index <= 8) then
        rank_str = ""
        rank_index = 9
    end
    return rank_str, rank_index, M.RANKS[rank_index]
end

function M.rank_announce_suffix(item)
    local _, _, rank = M.get_current_rank(item)
    if rank.spoken == "" then return "" end
    return " ranked " .. rank.spoken
end

function M.apply_rank(item, rank_str)
    rank_str = rank_str or ""
    local rank_index = tonumber(rank_str)
    local rank = (rank_index and M.RANKS[rank_index]) and M.RANKS[rank_index] or M.RANKS[9]

    local color_to_use
    if rank_str == "" or M.get_ranking_color_pref() == 1 then
        color_to_use = M.get_item_color(item)
    else
        GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)
        color_to_use = rgba_to_native(rank.rgba) | 0x1000000
    end

    for _, peer in ipairs(M.get_items_at_midpoint(item)) do
        SetMediaItemInfo_Value(peer, "I_CUSTOMCOLOR", color_to_use)

        local peer_take = GetActiveTake(peer)
        if peer_take then
            local _, peer_name = GetSetMediaItemTakeInfo_String(peer_take, "P_NAME", "", false)
            local peer_base = M.strip_rank_prefix(peer_name)
            local peer_final = peer_base
            if rank.prefix ~= "" then
                peer_final = peer_base ~= "" and (peer_base .. "-" .. rank.prefix) or rank.prefix
            end
            GetSetMediaItemTakeInfo_String(peer_take, "P_NAME", peer_final, true)
        end

        GetSetMediaItemInfo_String(peer, "P_EXT:item_rank", rank_str, true)
        GetSetMediaItemInfo_String(peer, "P_EXT:colorized", "", true)
    end

    UpdateArrange()
    return rank.name
end

return M
