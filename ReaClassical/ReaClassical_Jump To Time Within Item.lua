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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local jump_to_time_utils = require("ReaClassical_Jump_To_Time_Utils")

local function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    local count = CountSelectedMediaItems(0)
    if count == 0 then
        MB("Select one or more crossfaded items first.", "Jump to Time Within Item", 0)
        return
    end

    local first_item = GetSelectedMediaItem(0, 0)
    local first_position = GetMediaItemInfo_Value(first_item, "D_POSITION")
    local last_end_position = first_position

    for i = 0, count - 1 do
        local item = GetSelectedMediaItem(0, i)
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_start + item_length

        if i > 0 and item_start > last_end_position then
            MB("Selected items must be crossfaded.", "Jump to Time Within Item(s)", 0)
            return
        end

        if item_end > last_end_position then
            last_end_position = item_end
        end
    end

    local combined_length = last_end_position - first_position

    jump_to_time_utils.jump_to_time("Jump to Time Within Item(s)", first_position, combined_length)
end

main()
