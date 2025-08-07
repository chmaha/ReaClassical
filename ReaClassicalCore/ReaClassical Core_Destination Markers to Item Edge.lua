--[[
@noindex

This file is a part of "ReaClassical Core" package.

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

local main

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local left_pos, right_pos, selected
    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    if start_time ~= end_time then
        left_pos = start_time
        right_pos = end_time
    else
        selected = CountSelectedMediaItems(0)

        if selected == 0 then
            MB(
                "Please select one or more consecutive media items " ..
                "in the first folder or make a time selection before running the function.",
                "Destination Markers to Item Edge / Time Selection: Error", 0)
            return
        end

        -- Set marker positions
        local first_item = GetSelectedMediaItem(0, 0)
        left_pos = GetMediaItemInfo_Value(first_item, "D_POSITION")
        local last_item
        if selected > 1 then
            last_item = GetSelectedMediaItem(0, selected - 1)
            local start = GetMediaItemInfo_Value(last_item, "D_POSITION")
            local length = GetMediaItemInfo_Value(last_item, "D_LENGTH")
            right_pos = start + length
        else
            local length = GetMediaItemInfo_Value(first_item, "D_LENGTH")
            right_pos = left_pos + length
        end
    end


    -- Remove old markers
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then
            break
        else
            DeleteProjectMarker(project, 996, false)
            DeleteProjectMarker(project, 997, false)
        end
        i = i + 1
    end

    -- add new markers
    AddProjectMarker2(0, false, left_pos, 0, "DEST-IN", 996, ColorToNative(23,203,223) | 0x1000000)
    AddProjectMarker2(0, false, right_pos, 0, "DEST-OUT", 997, ColorToNative(23,203,223) | 0x1000000)

    Undo_EndBlock("ReaClassical Core Destination Markers to Item Edge", 0)
end

---------------------------------------------------------------------

main()
