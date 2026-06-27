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

local main, get_take_num_from_name

---------------------------------------------------------------------

-- Parses take number from item names in two forms:
-- "006" (pure numeric) -> 6
-- "Beethoven_T006" (_T suffix) -> 6
function get_take_num_from_name(name)
    if not name or name == "" then return nil end
    local t = name:match("_T(%d+)$")
    if t then return tonumber(t) end
    local p = name:match("^(%d+)$")
    if p then return tonumber(p) end
    return nil
end

---------------------------------------------------------------------

function main()
    local highest = 0
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local n = get_take_num_from_name(name)
            if n and n > highest then highest = n end
        end
    end
    if highest == 0 then
        say("No take numbers found.")
    else
        say("Highest take: " .. highest)
    end
end

---------------------------------------------------------------------

main()
