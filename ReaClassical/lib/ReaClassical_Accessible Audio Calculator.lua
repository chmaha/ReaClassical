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
local say = require("ReaClassical_Announce")
local ui_input = require("ReaClassical_Accessible_Input")

set_action_options(3)

local WINDOW_TITLE = "Audio Calculator"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_SPACE = 32

local STATE_LIST  = "list"
local STATE_COMBO = "combo"

local UNIT_NAMES        = { "GB", "MB", "TB", "Hours", "Minutes", "Seconds" }
local FORMAT_NAMES      = { "WAV", "MP3" }
local BITRATE_VALUES    = { 32, 64, 96, 128, 160, 192, 256, 320 }
local BITRATE_NAMES     = { "32 kbps", "64 kbps", "96 kbps", "128 kbps", "160 kbps", "192 kbps", "256 kbps", "320 kbps" }
local SAMPLE_RATE_VALUES = { 44100, 48000, 88200, 96000, 192000 }
local SAMPLE_RATE_NAMES  = { "44.1 kHz", "48 kHz", "88.2 kHz", "96 kHz", "192 kHz" }
local BIT_DEPTH_VALUES  = { 16, 24, 32 }
local BIT_DEPTH_NAMES   = { "16-bit", "24-bit", "32-bit float" }

local unit_idx       = 1
local input_value    = 1
local format_idx     = 1
local bitrate_idx    = 8
local samplerate_idx = 2
local bitdepth_idx   = 2
local num_tracks     = 2

local state       = STATE_LIST
local list_pos     = 1
local pending_idx  = 1
local last_char    = 0
local fields       = {}

local function format_duration(seconds)
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = math.floor(seconds % 60)
    return string.format("%dh %dm %ds", hours, minutes, seconds)
end

local function calculate()
    local data_rate
    if format_idx == 2 then
        data_rate = (BITRATE_VALUES[bitrate_idx] * 1000) / 8
    else
        data_rate = SAMPLE_RATE_VALUES[samplerate_idx] * (BIT_DEPTH_VALUES[bitdepth_idx] / 8) * num_tracks
    end

    local wav_overhead = 44
    local result_text

    if unit_idx <= 3 then
        local bytes
        if unit_idx == 1 then bytes = input_value * 1000 * 1000 * 1000
        elseif unit_idx == 2 then bytes = input_value * 1000 * 1000
        else bytes = input_value * 1000 * 1000 * 1000 * 1000 end

        if format_idx == 1 then bytes = bytes - wav_overhead end

        local duration_seconds = bytes / data_rate
        result_text = "Duration: " .. format_duration(duration_seconds)
    else
        local duration_seconds
        if unit_idx == 4 then duration_seconds = input_value * 3600
        elseif unit_idx == 5 then duration_seconds = input_value * 60
        else duration_seconds = input_value end

        local file_size_bytes = (duration_seconds * data_rate) + (format_idx == 1 and wav_overhead or 0)
        local file_size_mb = file_size_bytes / (1000 * 1000)
        local file_size_gb = file_size_bytes / (1000 * 1000 * 1000)
        result_text = string.format("File size: %.2f MB (%.2f GB)", file_size_mb, file_size_gb)
    end

    local data_rate_kbps = data_rate * 8 / 1000
    local data_rate_mbps = data_rate_kbps / 1000
    result_text = result_text .. string.format(". Data rate: %.2f Kbps (%.2f Mbps)", data_rate_kbps, data_rate_mbps)

    return result_text
end

local function build_fields()
    local list = {}
    list[#list + 1] = {
        kind = "combo", label = "Unit Type", names = UNIT_NAMES,
        get_idx = function() return unit_idx end, set_idx = function(i) unit_idx = i end,
    }
    list[#list + 1] = {
        kind = "number", label = (unit_idx <= 3) and "File Size" or "Duration", allow_decimal = true,
        get_val = function() return input_value end,
        set_val = function(v) input_value = math.max(0, v) end,
    }
    list[#list + 1] = {
        kind = "combo", label = "Format", names = FORMAT_NAMES,
        get_idx = function() return format_idx end, set_idx = function(i) format_idx = i end,
    }
    if format_idx == 2 then
        list[#list + 1] = {
            kind = "combo", label = "Bitrate", names = BITRATE_NAMES,
            get_idx = function() return bitrate_idx end, set_idx = function(i) bitrate_idx = i end,
        }
    else
        list[#list + 1] = {
            kind = "combo", label = "Sample Rate", names = SAMPLE_RATE_NAMES,
            get_idx = function() return samplerate_idx end, set_idx = function(i) samplerate_idx = i end,
        }
        list[#list + 1] = {
            kind = "combo", label = "Bit Depth", names = BIT_DEPTH_NAMES,
            get_idx = function() return bitdepth_idx end, set_idx = function(i) bitdepth_idx = i end,
        }
        list[#list + 1] = {
            kind = "number", label = "Number of Tracks", allow_decimal = false, min = 1,
            get_val = function() return num_tracks end,
            set_val = function(v) num_tracks = math.max(1, math.floor(v)) end,
        }
    end
    return list
end

local function current_field() return fields[list_pos] end

local function field_value_label(f)
    if f.kind == "combo" then return f.names[f.get_idx()] end
    return tostring(f.get_val())
end

local function announce_field(pos)
    local f = fields[pos]
    say(f.label .. ": " .. field_value_label(f))
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_COMBO then
        local f = current_field()
        gfx.drawstr("[" .. f.label .. " - editing]  " .. f.names[pending_idx])
    else
        local f = current_field()
        gfx.drawstr("[" .. f.label .. "]  " .. field_value_label(f) .. "   |   " .. calculate())
    end
    gfx.update()
end

local function refresh_after_commit()
    fields = build_fields()
    list_pos = math.min(list_pos, #fields)
    local f = current_field()
    say(f.label .. " set: " .. field_value_label(f) .. ". " .. calculate())
end

local function handle_key(char)
    if state == STATE_LIST then
        if char == KEY_UP then
            list_pos = list_pos > 1 and list_pos - 1 or #fields
            announce_field(list_pos)
        elseif char == KEY_DOWN then
            list_pos = list_pos < #fields and list_pos + 1 or 1
            announce_field(list_pos)
        elseif char == KEY_ENTER then
            local f = current_field()
            if f.kind == "combo" then
                pending_idx = f.get_idx()
                state = STATE_COMBO
                say("Editing " .. f.label .. ": " .. f.names[pending_idx]
                    .. ". Up or down to choose, Enter to confirm, Escape to cancel.")
            else
                state = STATE_LIST
                while true do
                    local ok, entered = ui_input.ask(WINDOW_TITLE, f.label, f.label,
                        tostring(f.get_val()))
                    if not ok then
                        say("Cancelled")
                        break
                    end
                    local num = tonumber(entered)
                    if num then
                        f.set_val(num)
                        refresh_after_commit()
                        break
                    end
                    say("Please enter a number")
                end
            end
        elseif char == KEY_SPACE then
            say(calculate())
        elseif char == KEY_ESC then
            say("Closed")
            return false
        end
    elseif state == STATE_COMBO then
        local f = current_field()
        if char == KEY_UP then
            pending_idx = pending_idx > 1 and pending_idx - 1 or #f.names
            say(f.names[pending_idx])
        elseif char == KEY_DOWN then
            pending_idx = pending_idx < #f.names and pending_idx + 1 or 1
            say(f.names[pending_idx])
        elseif char == KEY_ENTER then
            f.set_idx(pending_idx)
            state = STATE_LIST
            refresh_after_commit()
        elseif char == KEY_ESC then
            state = STATE_LIST
            say("Cancelled")
        end
    end
    return true
end

local function main()
    local char = gfx.getchar()
    if char == -1 then gfx.quit() return end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        if not handle_key(char) then
            gfx.quit()
            return
        end
    end
    draw_window()
    defer(main)
end

fields = build_fields()

gfx.init(WINDOW_TITLE, 600, 44, 0)
say(string.format(
    "Audio Calculator. %s: %s. %s Up or down to move, Enter to edit, Space to hear the result, Escape to close.",
    fields[1].label, field_value_label(fields[1]), calculate()))

defer(main)
