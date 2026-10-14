--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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

local function humanize_timestr(str)
    local _, mode_str = get_config_var_string("projtimemode2")
    local mode = tonumber(mode_str) or -1
    local last_unit_name = (mode == 5) and "frame" or "millisecond"

    local nums = {}
    for part in str:gmatch("%d+") do table.insert(nums, tonumber(part)) end
    if #nums ~= 4 then return str end

    local unit_names = { "hour", "minute", "second", last_unit_name }

    local first_nonzero
    for i, n in ipairs(nums) do
        if n ~= 0 then
            first_nonzero = i; break
        end
    end
    if not first_nonzero then return "At beginning of project" end

    local parts = {}
    for i = first_nonzero, 4 do
        local n = nums[i]
        table.insert(parts, n .. " " .. unit_names[i] .. (n == 1 and "" or "s"))
    end

    return table.concat(parts, ", ")
end

return humanize_timestr
