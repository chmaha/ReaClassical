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

local function enum_project_markers(proj, idx)
    local marker = GetRegionOrMarker(proj, idx, "")
    if not marker then return nil, false, 0.0, 0.0, "", 0, 0 end
    local isrgn = GetRegionOrMarkerInfo_Value(proj, marker, "B_ISREGION") == 1
    local pos = GetRegionOrMarkerInfo_Value(proj, marker, "D_STARTPOS")
    local rgnend = GetRegionOrMarkerInfo_Value(proj, marker, "D_ENDPOS")
    local _, name = GetSetRegionOrMarkerInfo_String(proj, marker, "P_NAME", "", false)
    local markrgnindexnumber = math.floor(GetRegionOrMarkerInfo_Value(proj, marker, "I_NUMBER"))
    local color = math.floor(GetRegionOrMarkerInfo_Value(proj, marker, "I_CUSTOMCOLOR"))
    return true, isrgn, pos, rgnend, name, markrgnindexnumber, color
end

return enum_project_markers
