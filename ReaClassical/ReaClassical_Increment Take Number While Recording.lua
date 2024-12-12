--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

local main, delayed_record

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local classical_take_record = reaper.NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")
local delay_cycles = 2

---------------------------------------------------------------------

function main()
    local playstate = reaper.GetPlayState()
    if playstate == 5 then
        reaper.Main_OnCommand(classical_take_record, 0)
        reaper.defer(delayed_record)
    end
end

---------------------------------------------------------------------

function delayed_record()
    delay_cycles = delay_cycles - 1
    if delay_cycles > 0 then
        reaper.defer(delayed_record)
    else
        reaper.Main_OnCommand(classical_take_record, 0)
    end
end

---------------------------------------------------------------------

main()
