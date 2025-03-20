--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local main, time_to_seconds

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local selected_items = {}
    local count = 0

    for i = 0, CountSelectedMediaItems(0) - 1 do
        local item = GetSelectedMediaItem(0, i)
        if item then
            selected_items[count + 1] = item
            count = count + 1
        end
    end

    local first_position = 0
    local combined_length

    if count > 0 then
        -- Check if items are consecutive and calculate positions
        first_position = GetMediaItemInfo_Value(selected_items[1], "D_POSITION")
        local last_end_position = first_position

        for i = 1, count do
            local item = selected_items[i]
            local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_end = item_start + item_length

            -- Check for consecutiveness
            if i > 1 then
                local prev_end_position = last_end_position
                if item_start > prev_end_position then
                    MB("Selected items must be crossfaded.", "Jump to Time Within Items", 0)
                    return
                end
            end

            if item_end > last_end_position then
                last_end_position = item_end
            end
        end

        combined_length = last_end_position - first_position
    else
        combined_length = GetProjectLength()
    end

    local dialog_title = count > 0 and "Jump to Time Within Item(s)" or "Jump to Time Within Project"
    local retval, time_str = GetUserInputs(dialog_title, 1, "Enter time (right-aligned logic)", "")

    if retval then
        local target_time = time_to_seconds(time_str)

        if target_time then
            if target_time < 0 or target_time > combined_length then
                MB("The specified time is outside the valid range.", "Error", 0)
                return
            end

            local cursor_position = first_position + target_time
            SetEditCurPos(cursor_position, true, false)
        else
            return
        end
    end
end

---------------------------------------------------------------------

function time_to_seconds(time_str)
    local frames, seconds, minutes, hours = 0, 0, 0, 0
    local frame_rate = TimeMap_curFrameRate(0)

    if time_str:match("%D") then
        local parts = {}
        for part in time_str:gmatch("%d+") do
            table.insert(parts, tonumber(part))
        end
        local len = #parts

        if len == 1 then
            frames = parts[1]
        elseif len == 2 then
            seconds, frames = parts[1], parts[2]
        elseif len == 3 then
            minutes, seconds, frames = parts[1], parts[2], parts[3]
        elseif len == 4 then
            hours, minutes, seconds, frames = parts[1], parts[2], parts[3], parts[4]
        else
            return nil
        end
    else
        local num = tonumber(time_str)
        if not num then return nil end
        local str = string.format("%08d", num)

        frames    = tonumber(str:sub(-2)) or 0
        seconds   = tonumber(str:sub(-4, -3)) or 0
        minutes   = tonumber(str:sub(-6, -5)) or 0
        hours     = tonumber(str:sub(-8, -7)) or 0
    end

    if frames >= frame_rate then
        MB(string.format("Invalid frame count: %d exceeds frame rate of %d.", frames, frame_rate), "Error", 0)
        return nil
    elseif seconds >= 60 or minutes >= 60 then
        MB("Invalid time format: seconds and minutes must be below 60.", "Error", 0)
        return nil
    end

    return hours * 3600 + minutes * 60 + seconds + frames / frame_rate
end

---------------------------------------------------------------------

main()
