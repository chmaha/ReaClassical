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

function M.find_folder_track()
    local t = GetTrack(0, 0)
    if t and GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
    return nil
end

function M.split_path(path)
    local slash = package.config:sub(1, 1)
    local dir, filename = path:match("^(.+)[/\\]([^/\\]+)$")
    return dir or ".", filename or path, slash
end

function M.find_file_ci(dir, slash, target_name)
    local target_lower = target_name:lower()
    local i = 0
    while true do
        local f = EnumerateFiles(dir, i)
        if not f then return nil end
        if f:lower() == target_lower then return dir .. slash .. f end
        i = i + 1
    end
end

local function stream_kind(rec)
    local sub = rec:sub(31, 38)
    if sub == "PQ DESCR" then return "pqdescr" end
    if sub:sub(1, 6) == "CDTEXT" then return "cdtext" end
    return nil
end

local function filename_from_ddpms(dir, slash, wanted_kind)
    local path = M.find_file_ci(dir, slash, "DDPMS")
    if not path then return nil end
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("a")
    f:close()
    if #data == 0 or #data % 128 ~= 0 then return nil end

    for i = 0, #data // 128 - 1 do
        local rec = data:sub(i * 128 + 1, i * 128 + 128)
        if rec:sub(1, 4) == "VVVM" and rec:sub(5, 5) == "S" and stream_kind(rec) == wanted_kind then
            local filename = rec:sub(75, 128):match("^%s*(.-)%s*$")
            if filename ~= "" then return filename end
        end
    end
    return nil
end

function M.pqdescr_filename(dir, slash)
    local from_ddpms = filename_from_ddpms(dir, slash, "pqdescr")
    if from_ddpms then
        local path = M.find_file_ci(dir, slash, from_ddpms)
        if path then return path end
    end
    return M.find_file_ci(dir, slash, "PQDESCR") or M.find_file_ci(dir, slash, "PQDESC")
end

function M.cdtext_filename(dir, slash)
    local from_ddpms = filename_from_ddpms(dir, slash, "cdtext")
    if from_ddpms then
        local path = M.find_file_ci(dir, slash, from_ddpms)
        if path then return path end
    end
    return M.find_file_ci(dir, slash, "CDTEXT.BIN")
end

local function mmssff_to_sec(s)
    local mm, ss, ff = s:match("^(%d%d)(%d%d)(%d%d)$")
    if not mm then return nil end
    return tonumber(mm) * 60 + tonumber(ss) + tonumber(ff) / 75
end

function M.parse_pqdescr(dir, slash)
    local path = M.pqdescr_filename(dir, slash)
    if not path then return nil, "PQDESCR not found in " .. dir end
    local f = io.open(path, "rb")
    if not f then return nil, "Could not open " .. path end
    local data = f:read("a")
    f:close()

    if #data == 0 or #data % 64 ~= 0 then
        return nil, "PQDESCR has an unexpected size (" .. #data .. " bytes)."
    end

    local catalog = ""
    local pregap_sec, track_start_sec, track_isrc = {}, {}, {}
    local album_end = nil
    local max_track_num = 0

    for i = 0, #data // 64 - 1 do
        local rec = data:sub(i * 64 + 1, i * 64 + 64)
        if rec:sub(1, 4) == "VVVS" then
            local track_str = rec:sub(5, 6)
            local index_str = rec:sub(7, 8)
            local pos_sec = mmssff_to_sec(rec:sub(11, 16))
            local isrc = rec:sub(21, 32):match("^%s*(.-)%s*$")
            local upc = rec:sub(33, 45):match("^%s*(.-)%s*$")

            if track_str == "AA" then
                album_end = pos_sec
                if upc ~= "" then catalog = upc end
            elseif track_str == "00" and index_str == "00" then
                if upc ~= "" then catalog = upc end
            else
                local num = tonumber(track_str)
                if num then
                    if num > max_track_num then max_track_num = num end
                    if index_str == "00" then
                        pregap_sec[num] = pos_sec
                        if isrc ~= "" then track_isrc[num] = isrc end
                    elseif index_str == "01" then
                        track_start_sec[num] = pos_sec
                        if isrc ~= "" then track_isrc[num] = isrc end
                    end
                end
            end
        end
    end

    if max_track_num == 0 or not album_end then
        return nil, "PQDESCR didn't contain any recognizable track/lead-out records."
    end

    local tracks = {}
    for num = 1, max_track_num do
        if not track_start_sec[num] then
            return nil, "PQDESCR is missing track " .. num .. "'s start position."
        end
        tracks[num] = {
            num = num,
            start_sec = track_start_sec[num],
            end_sec = track_start_sec[num + 1] or album_end,
            pregap_start_sec = pregap_sec[num],
            isrc = track_isrc[num] or "",
        }
    end

    return catalog, tracks, album_end
end

local PACK_TYPES = {
    title      = 0x80,
    performer  = 0x81,
    songwriter = 0x82,
    composer   = 0x83,
    arranger   = 0x84,
    message    = 0x85,
    genre      = 0x87,
}

local function split_nul(s)
    local out = {}
    local start = 1
    for i = 1, #s do
        if s:byte(i) == 0 then
            out[#out + 1] = s:sub(start, i - 1)
            start = i + 1
        end
    end
    if start <= #s then out[#out + 1] = s:sub(start) end
    return out
end

function M.parse_cdtext(dir, slash, num_tracks)
    local path = M.cdtext_filename(dir, slash)
    if not path then
        local album_meta = { genre = "Classical" }
        local track_meta = {}
        for i = 1, num_tracks do track_meta[i] = { title = tostring(i) } end
        return album_meta, track_meta, false
    end
    local f = io.open(path, "rb")
    if not f then return nil, "Could not open " .. path end
    local data = f:read("a")
    f:close()

    if #data == 0 then
        return nil, "CDTEXT.BIN has an unexpected size (0 bytes)."
    end
    local full_len = #data - (#data % 18)
    if data:sub(full_len + 1):match("[^\0]") then
        return nil, "CDTEXT.BIN has an unexpected size (" .. #data .. " bytes)."
    end
    data = data:sub(1, full_len)

    local payload_by_type = {}
    for i = 0, #data // 18 - 1 do
        local pack = data:sub(i * 18 + 1, i * 18 + 18)
        local pack_type = pack:byte(1)
        payload_by_type[pack_type] = (payload_by_type[pack_type] or "") .. pack:sub(5, 16)
    end

    local album_meta = { genre = "Classical" }
    local track_meta = {}
    for i = 1, num_tracks do track_meta[i] = {} end

    for key, pack_type in pairs(PACK_TYPES) do
        local stream = payload_by_type[pack_type]
        if stream and key ~= "genre" then
            local fields = split_nul(stream)
            album_meta[key] = fields[1] or ""
            for i = 1, num_tracks do
                track_meta[i][key] = fields[i + 1] or ""
            end
        end
    end

    local genre_stream = payload_by_type[PACK_TYPES.genre]
    if genre_stream and #genre_stream > 2 then
        local fields = split_nul(genre_stream:sub(3))
        if fields[1] and fields[1] ~= "" then album_meta.genre = fields[1] end
    end

    return album_meta, track_meta, true
end

local BYTES_PER_FRAME = 4
local SAMPLE_RATE = 44100

local SILENCE_PEAK_THRESHOLD = 200

function M.pregap_is_silent(dat_path, start_sec, end_sec)
    local start_byte = math.floor(start_sec * SAMPLE_RATE) * BYTES_PER_FRAME
    local end_byte = math.floor(end_sec * SAMPLE_RATE) * BYTES_PER_FRAME
    if end_byte <= start_byte then return true end

    local f = io.open(dat_path, "rb")
    if not f then return true end
    f:seek("set", start_byte)
    local chunk = f:read(end_byte - start_byte)
    f:close()
    if not chunk then return true end

    for i = 1, #chunk - 1, 2 do
        local lo, hi = chunk:byte(i, i + 1)
        local sample = lo + hi * 256
        if sample >= 32768 then sample = sample - 65536 end
        if math.abs(sample) >= SILENCE_PEAK_THRESHOLD then return false end
    end
    return true
end

return M
