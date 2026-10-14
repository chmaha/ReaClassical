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
local humanize_timestr = require("ReaClassical_Time_Naming")

local M = {}

function M.time_to_seconds(time_str)
    local relative = false
    local sign = 1

    if time_str:match("^%+") then
        relative = true
        time_str = time_str:sub(2)
    elseif time_str:match("^%-") then
        relative = true
        sign = -1
        time_str = time_str:sub(2)
    end

    time_str = time_str:gsub("%D", "")
    local num = tonumber(time_str)
    if not num then return nil end

    local frame_rate = TimeMap_curFrameRate(0)
    local padded = string.format("%08d", num)

    local frames  = tonumber(padded:sub(-2)) or 0
    local seconds = tonumber(padded:sub(-4, -3)) or 0
    local minutes = tonumber(padded:sub(-6, -5)) or 0
    local hours   = tonumber(padded:sub(-8, -7)) or 0

    if frames >= frame_rate then
        MB(string.format("Invalid frame count: %d exceeds frame rate of %d.", frames, frame_rate), "Error", 0)
        return nil
    elseif seconds >= 60 or minutes >= 60 then
        MB("Invalid time format: seconds and minutes must be below 60.", "Error", 0)
        return nil
    end

    return sign * (hours * 3600 + minutes * 60 + seconds + frames / frame_rate), relative
end

function M.jump_to_time(dialog_title, first_position, combined_length)
    local retval, time_str = GetUserInputs(dialog_title, 1, "Enter time (use +/- for relative)", "")
    if not retval then return end

    local target_time, relative = M.time_to_seconds(time_str)
    if not target_time then return end

    local cursor_position
    if relative then
        cursor_position = GetCursorPosition() + target_time
    else
        cursor_position = first_position + target_time
    end

    if cursor_position < 0 or cursor_position > first_position + combined_length then
        MB("The specified time is outside the valid range.", "Error", 0)
        return
    end

    SetEditCurPos(cursor_position, true, false)
    say("Jumped to " .. humanize_timestr(format_timestr_pos(cursor_position, "", -1)))
end

return M
