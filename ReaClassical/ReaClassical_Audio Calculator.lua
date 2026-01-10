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

local main, format_duration, calculate

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

---------------------------------------------------------------------

local ctx = ImGui.CreateContext('ReaClassical Audio Calculator')
local window_open = true

-- State variables
local unit_type = 0 -- 0=GB, 1=MB, 2=TB, 3=Hours, 4=Minutes, 5=Seconds
local input_value = 1
local input_value_str = "1" -- String representation for display
local format_type = 0 -- 0=WAV, 1=MP3
local bitrate = 7 -- Index for 320 kbps
local sample_rate = 1 -- Index for 48kHz
local bit_depth = 1 -- Index for 24-bit
local num_tracks = 2

local unit_names = {"GB", "MB", "TB", "Hours", "Minutes", "Seconds"}
local format_names = {"WAV", "MP3"}
local bitrate_values = {32, 64, 96, 128, 160, 192, 256, 320}
local bitrate_names = {"32 kbps", "64 kbps", "96 kbps", "128 kbps", "160 kbps", "192 kbps", "256 kbps", "320 kbps"}
local sample_rate_values = {44100, 48000, 88200, 96000, 192000}
local sample_rate_names = {"44.1 kHz", "48 kHz", "88.2 kHz", "96 kHz", "192 kHz"}
local bit_depth_values = {16, 24, 32}
local bit_depth_names = {"16-bit", "24-bit", "32-bit float"}

---------------------------------------------------------------------

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end
    
    ImGui.SetNextWindowSize(ctx, 275, 375, ImGui.Cond_Always)
    local visible, open = ImGui.Begin(ctx, 'ReaClassical Audio Calculator', true)
    
    if visible then
        -- Unit Type
        ImGui.Text(ctx, "Select Unit Type:")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_unit, new_unit = ImGui.Combo(ctx, "##unit_type", unit_type, table.concat(unit_names, "\0") .. "\0")
        if changed_unit then
            unit_type = new_unit
        end
        
        -- Input Value
        if unit_type <= 2 then
            ImGui.Text(ctx, "Enter File Size:")
        else
            ImGui.Text(ctx, "Enter Duration:")
        end
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_input, new_input = ImGui.InputDouble(ctx, "##input_value", input_value, 1, 10, "%.4g")
        if changed_input then
            input_value = math.max(0, new_input)
        end
        
        -- Format
        ImGui.Text(ctx, "Select Format:")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_format, new_format = ImGui.Combo(ctx, "##format", format_type, table.concat(format_names, "\0") .. "\0")
        if changed_format then
            format_type = new_format
            if format_type == 1 then -- MP3
                num_tracks = 2
            end
        end
        
        -- Bitrate (only for MP3)
        if format_type == 1 then
            ImGui.Text(ctx, "Select Bitrate:")
            ImGui.SetNextItemWidth(ctx, -1)
            local changed_bitrate, new_bitrate = ImGui.Combo(ctx, "##bitrate", bitrate, table.concat(bitrate_names, "\0") .. "\0")
            if changed_bitrate then
                bitrate = new_bitrate
            end
        end
        
        -- Sample Rate
        ImGui.Text(ctx, "Sample Rate:")
        ImGui.SetNextItemWidth(ctx, -1)
        if format_type == 1 then
            ImGui.BeginDisabled(ctx)
        end
        local changed_sr, new_sr = ImGui.Combo(ctx, "##sample_rate", sample_rate, table.concat(sample_rate_names, "\0") .. "\0")
        if changed_sr then
            sample_rate = new_sr
        end
        if format_type == 1 then
            ImGui.EndDisabled(ctx)
        end
        
        -- Bit Depth
        ImGui.Text(ctx, "Bit Depth:")
        ImGui.SetNextItemWidth(ctx, -1)
        if format_type == 1 then
            ImGui.BeginDisabled(ctx)
        end
        local changed_bd, new_bd = ImGui.Combo(ctx, "##bit_depth", bit_depth, table.concat(bit_depth_names, "\0") .. "\0")
        if changed_bd then
            bit_depth = new_bd
        end
        if format_type == 1 then
            ImGui.EndDisabled(ctx)
        end
        
        -- Number of Tracks
        ImGui.Text(ctx, "Number of Tracks:")
        ImGui.SetNextItemWidth(ctx, -1)
        if format_type == 1 then
            ImGui.BeginDisabled(ctx)
        end
        local changed_tracks, new_tracks = ImGui.InputInt(ctx, "##num_tracks", num_tracks)
        if changed_tracks then
            num_tracks = math.max(1, new_tracks)
        end
        if format_type == 1 then
            ImGui.EndDisabled(ctx)
        end
        
        -- Result
        ImGui.Separator(ctx)
        local result = calculate()
        ImGui.PushFont(ctx, nil, 14)
        ImGui.TextWrapped(ctx, result)
        ImGui.PopFont(ctx)
        ImGui.End(ctx)
    end
    
    if open then
        defer(main)
    end
end
---------------------------------------------------------------------

function format_duration(seconds)
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = math.floor(seconds % 60)
    return string.format("%dh %dm %ds", hours, minutes, seconds)
end

---------------------------------------------------------------------

function calculate()
    local data_rate
    
    -- calculate data rate
    if format_type == 1 then -- MP3
        data_rate = (bitrate_values[bitrate + 1] * 1000) / 8
    else -- WAV
        data_rate = sample_rate_values[sample_rate + 1] * (bit_depth_values[bit_depth + 1] / 8) * num_tracks
    end
    
    local wav_overhead = 44
    local result_text = ""
    
    -- calculate based on unit type
    if unit_type <= 2 then -- GB, MB, TB (file size input)
        local bytes
        
        if unit_type == 0 then -- GB
            bytes = input_value * 1000 * 1000 * 1000
        elseif unit_type == 1 then -- MB
            bytes = input_value * 1000 * 1000
        else -- TB
            bytes = input_value * 1000 * 1000 * 1000 * 1000
        end
        
        if format_type == 0 then -- WAV
            bytes = bytes - wav_overhead
        end
        
        local duration_seconds = bytes / data_rate
        result_text = "Duration: " .. format_duration(duration_seconds)
    else -- Hours, Minutes, Seconds (duration input)
        local duration_seconds
        
        if unit_type == 3 then -- Hours
            duration_seconds = input_value * 3600
        elseif unit_type == 4 then -- Minutes
            duration_seconds = input_value * 60
        else -- Seconds
            duration_seconds = input_value
        end
        
        local file_size_bytes = (duration_seconds * data_rate) + (format_type == 0 and wav_overhead or 0)
        local file_size_mb = file_size_bytes / (1000 * 1000)
        local file_size_gb = file_size_bytes / (1000 * 1000 * 1000)
        
        result_text = string.format("File size: %.2f MB (%.2f GB)", file_size_mb, file_size_gb)
    end
    
    -- Add data rate info
    local data_rate_kbps = data_rate * 8 / 1000
    local data_rate_mbps = data_rate_kbps / 1000
    result_text = result_text .. string.format("\nData Rate: %.2f Kbps (%.2f Mbps)", data_rate_kbps, data_rate_mbps)
    
    return result_text
end

---------------------------------------------------------------------

defer(main)