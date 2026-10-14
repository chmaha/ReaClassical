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

local album_meta_store = require("ReaClassical_Album_Metadata")
local enum_project_markers = require("ReaClassical_Marker_Enum")

local M = {}

function M.find_folder_track()
    local t = GetTrack(0, 0)
    if t and GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
    return nil
end

local function parse_album(name)
    local d = { genre = "Classical", language = "English" }
    local first = true
    for part in name:gmatch("[^|]+") do
        if first then
            d.title = part:gsub("^@", "")
            first = false
        else
            local k, v = part:match("^(%w+)=(.+)$")
            if k then d[k:lower()] = v end
        end
    end
    d.title = d.title or ""
    return d
end

local function parse_track(name)
    local d = {}
    local first = true
    for part in name:gmatch("[^|]+") do
        if first then
            d.title = part:gsub("^!", "")
            first = false
        else
            local k, v = part:match("^(%w+)=(.+)$")
            if k then
                k = k:lower()
                if k == "offset" then d._offset = v else d[k] = v end
            end
        end
    end
    return d
end

function M.load_metadata()
    local folder_track = M.find_folder_track()
    if not folder_track then return nil end

    local album_data = { genre = "Classical", language = "English", title = "" }
    local raw = {}
    for i = 0, CountTrackMediaItems(folder_track) - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            name = name or ""
            if not name:match("^@") and name ~= "" then
                raw[#raw + 1] = { name = name, pos = GetMediaItemInfo_Value(item, "D_POSITION") }
            end
        end
    end
    table.sort(raw, function(a, b) return a.pos < b.pos end)

    local tracks = {}
    for _, r in ipairs(raw) do
        tracks[#tracks + 1] = parse_track(r.name)
    end

    local album_str = album_meta_store.get_album_metadata_str(folder_track)
    if album_str then album_data = parse_album(album_str) end

    return album_data, tracks
end

function M.get_cd_layout()
    local num_m = GetNumRegionsOrMarkers(0)
    local total = num_m

    local track_positions = {}
    local pregap_positions = {}
    local end_pos = nil
    local has_zero_marker = false
    local has_album_marker = false

    for i = 0, total - 1 do
        local _, isrgn, pos, _, name = enum_project_markers(0, i)
        if not isrgn then
            if pos < 0.001 then has_zero_marker = true end
            if name == "!" then
                pregap_positions[#pregap_positions + 1] = pos
            elseif name == "=END" then
                end_pos = pos
            elseif name:sub(1, 1) == "#" then
                track_positions[#track_positions + 1] = pos
            elseif name:sub(1, 1) == "@" then
                has_album_marker = true
            end
        end
    end

    if not has_zero_marker or #track_positions == 0 or not has_album_marker or not end_pos then
        return nil
    end

    table.sort(track_positions)
    table.sort(pregap_positions)

    local tracks = {}
    for i, pos in ipairs(track_positions) do
        tracks[i] = { num = i, start_pos = pos, end_pos = track_positions[i + 1] or end_pos }
    end

    for i, t in ipairs(tracks) do
        local prev_end = (i > 1) and tracks[i - 1].end_pos or 0
        for _, pg in ipairs(pregap_positions) do
            if pg >= prev_end - 0.01 and pg < t.start_pos - 0.01 then
                t.pregap_start = pg
                break
            end
        end
    end

    return tracks, end_pos
end

function M.get_boundaries(tracks, last_item_end)
    local list = { tracks[1].start_pos }
    for i = 1, #tracks - 1 do
        list[#list + 1] = tracks[i].end_pos
    end
    list[#list + 1] = last_item_end
    return list
end

function M.track_index_at(tracks, pos)
    for i, t in ipairs(tracks) do
        local span_start = t.pregap_start or t.start_pos
        if pos < span_start then return math.max(1, i - 1) end
        if pos < t.end_pos then return i end
    end
    return #tracks
end

local END_PAD_NOTE = "ReaClassical CD Player end-of-disc padding -- safe to delete"

function M.remove_stale_end_pad()
    for i = CountMediaItems(0) - 1, 0, -1 do
        local item = GetMediaItem(0, i)
        local _, notes = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
        if notes == END_PAD_NOTE then
            DeleteTrackMediaItem(GetMediaItemTrack(item), item)
        end
    end
end

function M.get_last_item_end()
    local max_end = 0
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local _, notes = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
        if notes ~= END_PAD_NOTE then
            local e = GetMediaItemInfo_Value(item, "D_POSITION") + GetMediaItemInfo_Value(item, "D_LENGTH")
            if e > max_end then max_end = e end
        end
    end
    return max_end
end

function M.ensure_end_pad(end_pos)
    local max_end = M.get_last_item_end()
    if end_pos <= max_end + 0.001 then return nil end

    local folder_track = M.find_folder_track()
    if not folder_track then return nil end

    local item = AddMediaItemToTrack(folder_track)
    SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, end_pos - 0.02))
    SetMediaItemInfo_Value(item, "D_LENGTH", 0.02)
    GetSetMediaItemInfo_String(item, "P_NOTES", END_PAD_NOTE, true)
    return item
end

function M.remove_end_pad(item)
    if item then DeleteTrackMediaItem(GetMediaItemTrack(item), item) end
end

function M.is_stopped()
    local ps = GetPlayState()
    return (ps & 1) == 0 and (ps & 2) == 0
end

function M.seek(pos)
    SetEditCurPos(pos, false, true)
end

function M.is_playing()
    return (GetPlayState() & 1) == 1
end

function M.is_paused()
    return (GetPlayState() & 2) == 2
end

function M.current_pos()
    if M.is_playing() then return GetPlayPosition() end
    return GetCursorPosition()
end

function M.format_time(sec, negative)
    sec = math.max(0, sec)
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60)
    return (negative and "-" or "") .. string.format("%d:%02d", m, s)
end

function M.track_title(track_meta, idx)
    local m = track_meta and track_meta[idx]
    if m and m.title and m.title ~= "" then return m.title end
    return "Track " .. idx
end

function M.load()
    local layout, album_end = M.get_cd_layout()
    if not layout then return nil end
    local album_meta, track_meta = M.load_metadata()
    return layout, album_end, album_meta, track_meta
end

return M
