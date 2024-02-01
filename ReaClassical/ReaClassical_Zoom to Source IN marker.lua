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

---------------------------------------------------------------------
function main()
  GoToMarker(0, 998, false)
  zoom()
end

---------------------------------------------------------------------

function zoom()
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    SetEditCurPos(cur_pos - 3, false, false)
    Main_OnCommand(40625, 0) -- Time selection: Set start point
    SetEditCurPos(cur_pos + 3, false, false)
    Main_OnCommand(40626, 0) -- Time selection: Set end point
    local zoom = NamedCommandLookup("_SWS_ZOOMSIT")
    Main_OnCommand(zoom, 0)  -- SWS: Zoom to selected items or time selection
    SetEditCurPos(cur_pos, false, false)
    Main_OnCommand(1012, 0)  -- View: Zoom in horizontal
    Main_OnCommand(40635, 0) -- Time selection: Remove (unselect) time selection
end

---------------------------------------------------------------------

main()
