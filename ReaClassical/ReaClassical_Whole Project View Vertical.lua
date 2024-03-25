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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main

---------------------------------------------------------------------

function main()
    Main_OnCommand(40296, 0) -- Track: Select all tracks
    local zoom = NamedCommandLookup("_SWS_VZOOMFIT")
    Main_OnCommand(zoom, 0) -- SWS: Vertical zoom to selected tracks
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
end

---------------------------------------------------------------------

main()
