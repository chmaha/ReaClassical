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

M.samplerate_list = { 44100, 48000, 88200, 96000, 176400, 192000 }
M.samplerate_labels = { "44.1 kHz", "48 kHz", "88.2 kHz", "96 kHz", "176.4 kHz", "192 kHz" }
M.bitdepth_list = { 16, 24, 32 }
M.bitdepth_labels = { "16-bit", "24-bit", "32-bit float" }
M.dither_list = { "Triangular", "HP filtered", "Noise shaping", "Off" }

function M.load()
    local samplerate = tonumber(GetExtState("ReaClassical", "RenderSamplerate")) or 44100
    local bitdepth = tonumber(GetExtState("ReaClassical", "RenderBitDepth")) or 16
    local dither = GetExtState("ReaClassical", "RenderDither")
    if dither == "" then dither = "Triangular" end
    if bitdepth ~= 16 and dither ~= "Off" then
        dither = "Off"
        M.save_dither(dither)
    end
    return samplerate, bitdepth, dither
end

function M.save_samplerate(v) SetExtState("ReaClassical", "RenderSamplerate", tostring(v), true) end

function M.save_bitdepth(v) SetExtState("ReaClassical", "RenderBitDepth", tostring(v), true) end

function M.save_dither(v) SetExtState("ReaClassical", "RenderDither", v, true) end

function M.mp3_samplerate_for(samplerate)
    if samplerate % 44100 == 0 then return 44100 end
    if samplerate % 48000 == 0 then return 48000 end
    return 44100
end

function M.dither_value_for(bitdepth, dither_name)
    if bitdepth ~= 16 then return 16 end
    if dither_name == "HP filtered" then return 3 end
    if dither_name == "Noise shaping" then return 2 end
    if dither_name == "Off" then return 16 end
    return 1
end

local B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function M.base64_encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local b1, b2, b3 = data:byte(i, i + 2)
        b2 = b2 or 0
        local n = b1 * 65536 + b2 * 256 + (b3 or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64_CHARS:sub(c1 + 1, c1 + 1)
        out[#out + 1] = B64_CHARS:sub(c2 + 1, c2 + 1)
        out[#out + 1] = (i + 1 <= #data) and B64_CHARS:sub(c3 + 1, c3 + 1) or '='
        out[#out + 1] = (i + 2 <= #data) and B64_CHARS:sub(c4 + 1, c4 + 1) or '='
    end
    return table.concat(out)
end

function M.build_wav_format(bps)
    return M.base64_encode("evaw" .. string.char(bps % 256, 0, 0))
end

function M.build_flac_format(bps)
    local function le4(n)
        return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256,
            math.floor(n / 16777216) % 256)
    end
    return M.base64_encode("calf" .. le4(bps) .. le4(5))
end

return M
