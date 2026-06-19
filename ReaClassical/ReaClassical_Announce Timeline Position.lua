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

local main, say, humanize_timestr

---------------------------------------------------------------------

function say(msg)
    if osara_outputMessage then
        osara_outputMessage(tostring(msg))
    end
end

---------------------------------------------------------------------

-- Speaks a format_timestr_pos() position in words, dropping leading
-- zero-valued units: "0:03:56:45" -> "3 minutes, 56 seconds, 45
-- frames"; "1:23:45.678" -> "1 hour, 23 minutes, 45 seconds, 678
-- milliseconds"; all-zero -> "At beginning of project". The last unit is
-- CD frames (mode 5, "h:m:s:f" -- ReaClassical's default) or milliseconds
-- (mode 0, "h:m:s.mmm"), detected via SWS's projtimemode2 config var since
-- format_timestr_pos() itself doesn't say which format it used. Any other
-- ruler format (bars/beats, samples, seconds-only) doesn't split into
-- exactly 4 numeric groups and is returned unchanged.
function humanize_timestr(str)
    local mode = APIExists("SNM_GetIntConfigVar") and SNM_GetIntConfigVar("projtimemode2", -1) or -1
    local last_unit_name = (mode == 5) and "frame" or "millisecond"

    local nums = {}
    for part in str:gmatch("%d+") do table.insert(nums, tonumber(part)) end
    if #nums ~= 4 then return str end

    local unit_names = { "hour", "minute", "second", last_unit_name }

    local first_nonzero
    for i, n in ipairs(nums) do
        if n ~= 0 then first_nonzero = i; break end
    end
    if not first_nonzero then return "At beginning of project" end

    local parts = {}
    for i = first_nonzero, 4 do
        local n = nums[i]
        table.insert(parts, n .. " " .. unit_names[i] .. (n == 1 and "" or "s"))
    end

    return table.concat(parts, ", ")
end

---------------------------------------------------------------------

function main()
    say(humanize_timestr(format_timestr_pos(GetCursorPosition(), "", -1)))
end

---------------------------------------------------------------------

main()
