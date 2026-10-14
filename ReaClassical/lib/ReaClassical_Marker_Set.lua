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

local function set_project_marker_by_index(proj, markrgnidx, isrgn, pos, rgnend, IDnumber, name, color)
    local marker = GetRegionOrMarker(proj, markrgnidx, "")
    if not marker then return false end
    SetRegionOrMarkerInfo_Value(proj, marker, "D_STARTPOS", pos)
    if isrgn then
        SetRegionOrMarkerInfo_Value(proj, marker, "D_ENDPOS", rgnend)
    end
    if IDnumber and IDnumber >= 0 then
        SetRegionOrMarkerInfo_Value(proj, marker, "I_NUMBER", IDnumber)
    end
    SetRegionOrMarkerInfo_Value(proj, marker, "I_CUSTOMCOLOR", color)
    local ok = GetSetRegionOrMarkerInfo_String(proj, marker, "P_NAME", name, true)
    return ok
end

return set_project_marker_by_index
