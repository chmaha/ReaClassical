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

local function le_u32(s, i)
    local b1, b2, b3, b4 = s:byte(i, i + 3)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function chunk_skip(payload_len)
    return payload_len + (payload_len % 2)
end

local function decode_utf16le(bytes)
    if not bytes or #bytes % 2 ~= 0 then
        return nil, "XTOC chunk has an odd byte length -- not valid UTF-16."
    end
    local out = {}
    local i = 1
    while i <= #bytes do
        local lo, hi = bytes:byte(i, i + 1)
        local unit = lo + hi * 256
        i = i + 2
        local cp = unit
        if unit >= 0xD800 and unit <= 0xDBFF and i + 1 <= #bytes then
            local lo2, hi2 = bytes:byte(i, i + 1)
            local unit2 = lo2 + hi2 * 256
            if unit2 >= 0xDC00 and unit2 <= 0xDFFF then
                cp = ((unit - 0xD800) * 0x400) + (unit2 - 0xDC00) + 0x10000
                i = i + 2
            end
        end
        out[#out + 1] = utf8.char(cp)
    end
    local text = table.concat(out)
    if text:sub(1, 3) == "\239\187\191" then text = text:sub(4) end
    return text
end

local function trim(s)
    if not s then return nil end
    local v = s:match("^%s*(.-)%s*$")
    if v == "" then return nil end
    return v
end

local function child_text(block, tag)
    return trim(block:match("<" .. tag .. ">%s*(.-)%s*</" .. tag .. ">"))
end

local function index_time(track_block, index_id)
    for idx_block in track_block:gmatch('<Index ID="' .. index_id .. '">(.-)</Index>') do
        local t = child_text(idx_block, "Time")
        if t then return t end
    end
    return nil
end

local function msf_to_sec(s)
    local mm, ss, ff = s:match("^(%d%d):(%d%d):(%d%d)$")
    if not mm then return nil end
    return tonumber(mm) * 60 + tonumber(ss) + tonumber(ff) / 75
end

local function parse_xtoc(xml)
    local album_section = xml:match("^(.-)<Track ")
    if not album_section then
        return nil, nil, nil, "PMI XTOC has no <Track> elements."
    end

    local album = {
        title = child_text(album_section, "CDTextTitle") or child_text(album_section, "DiscTitle") or "",
        catalog = child_text(album_section, "UPCEANCode") or "",
        performer = child_text(album_section, "CDTextPerformer") or "",
        songwriter = child_text(album_section, "CDTextSongWriter") or "",
        composer = child_text(album_section, "CDTextComposer") or "",
        arranger = child_text(album_section, "CDTextArranger") or "",
        genre = child_text(album_section, "CDTextGenre") or "",
    }

    local tracks = {}
    local lead_out_sec = nil

    for id, block in xml:gmatch('<Track ID="([^"]+)">(.-)</Track>') do
        if id:upper() == "AA" then
            local t = index_time(block, "1")
            if t then lead_out_sec = msf_to_sec(t) end
        else
            local num = tonumber(id)
            if num then
                local start_str = index_time(block, "1")
                if not start_str then
                    return nil, nil, nil, 'PMI track "' .. id .. '" has no Index ID="1" (start) marker.'
                end
                local pregap_str = index_time(block, "0")
                tracks[#tracks + 1] = {
                    num = num,
                    title = child_text(block, "CDTextTitle") or "",
                    performer = child_text(block, "CDTextPerformer") or "",
                    songwriter = child_text(block, "CDTextSongWriter") or "",
                    composer = child_text(block, "CDTextComposer") or "",
                    arranger = child_text(block, "CDTextArranger") or "",
                    isrc = child_text(block, "ISRCCode") or "",
                    pregap_start_sec = pregap_str and msf_to_sec(pregap_str) or nil,
                    start_sec = msf_to_sec(start_str),
                }
            end
        end
    end

    if not lead_out_sec then
        return nil, nil, nil, 'PMI XTOC has no Track ID="AA" lead-out marker.'
    end
    if #tracks == 0 then
        return nil, nil, nil, "PMI XTOC has no numbered tracks."
    end

    table.sort(tracks, function(a, b) return a.num < b.num end)

    return album, tracks, lead_out_sec
end

function M.parse(path)
    local f = io.open(path, "rb")
    if not f then return nil, "Could not open " .. path end

    local header = f:read(12)
    if not header or #header < 12 or header:sub(1, 4) ~= "RIFF" or header:sub(9, 12) ~= "WAVE" then
        f:close()
        return nil, path .. ": not a valid RIFF/WAVE file -- not a .pmi pre-master."
    end

    local pos = 12
    local fmt_offset, fmt_len
    local data_offset, data_len
    local xtoc_xml

    while true do
        local chdr = f:read(8)
        if not chdr or #chdr < 8 then break end
        local id = chdr:sub(1, 4):lower()
        local len = le_u32(chdr, 5)
        local header_offset = pos
        pos = pos + 8

        if id == "fmt " then
            fmt_offset, fmt_len = header_offset, len
            f:seek("cur", chunk_skip(len))
            pos = pos + chunk_skip(len)
        elseif id == "data" then
            data_offset, data_len = header_offset, len
            f:seek("cur", chunk_skip(len))
            pos = pos + chunk_skip(len)
        elseif id == "xtoc" then
            local payload = f:read(len)
            local err
            xtoc_xml, err = decode_utf16le(payload)
            if not xtoc_xml then
                f:close()
                return nil, path .. ": " .. err
            end
            pos = pos + len
            if len % 2 == 1 then
                local _ = f:read(1)
                pos = pos + 1
            end
        else
            f:seek("cur", chunk_skip(len))
            pos = pos + chunk_skip(len)
        end
    end

    f:close()

    if not fmt_offset then return nil, path .. ": no fmt chunk found -- not a valid .pmi file." end
    if not data_offset then return nil, path .. ": no data chunk found -- not a valid .pmi file." end
    if not xtoc_xml then
        return nil, path .. ": no XTOC chunk found -- not a Pyramix .pmi pre-master, "
            .. "or its table of contents wasn't included in the export."
    end

    local album, tracks, lead_out_sec, err = parse_xtoc(xtoc_xml)
    if not album then return nil, path .. ": " .. err end

    return {
        title = album.title,
        catalog = album.catalog,
        performer = album.performer,
        songwriter = album.songwriter,
        composer = album.composer,
        arranger = album.arranger,
        genre = album.genre,
        tracks = tracks,
        lead_out_sec = lead_out_sec,
        fmt_offset = fmt_offset,
        fmt_len = fmt_len,
        data_offset = data_offset,
        data_len = data_len,
    }
end

local COPY_BUF = 4 * 1024 * 1024

local function copy_bytes(src, dest, offset, length)
    src:seek("set", offset)
    local remaining = length
    while remaining > 0 do
        local n = math.min(COPY_BUF, remaining)
        local chunk = src:read(n)
        if not chunk or #chunk == 0 then return false end
        dest:write(chunk)
        remaining = remaining - #chunk
    end
    return true
end

function M.extract_wav(pmi_path, disc, out_wav_path)
    local src = io.open(pmi_path, "rb")
    if not src then return false, "Could not open " .. pmi_path end
    local dest = io.open(out_wav_path, "wb")
    if not dest then
        src:close()
        return false, "Could not create " .. out_wav_path
    end

    local fmt_total = 8 + disc.fmt_len + (disc.fmt_len % 2)
    local data_total = 8 + disc.data_len + (disc.data_len % 2)
    local riff_size = 4 + fmt_total + data_total

    dest:write("RIFF")
    dest:write(string.pack("<I4", riff_size))
    dest:write("WAVE")

    local ok = copy_bytes(src, dest, disc.fmt_offset, fmt_total)
        and copy_bytes(src, dest, disc.data_offset, data_total)

    src:close()
    dest:close()

    if not ok then return false, "Failed to copy audio data from " .. pmi_path end
    return true
end

local BYTES_PER_FRAME = 4
local SAMPLE_RATE = 44100
local SILENCE_PEAK_THRESHOLD = 200

function M.pregap_is_silent(pmi_path, disc, start_sec, end_sec)
    local start_byte = math.floor(start_sec * SAMPLE_RATE) * BYTES_PER_FRAME
    local end_byte = math.floor(end_sec * SAMPLE_RATE) * BYTES_PER_FRAME
    if end_byte <= start_byte then return true end

    local f = io.open(pmi_path, "rb")
    if not f then return true end
    f:seek("set", disc.data_offset + 8 + start_byte)
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
