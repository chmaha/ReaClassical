--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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
    local replace_toggle = NamedCommandLookup("_RSfb9968dc637180b9e9d1627a5be31048ae2034e9")
    local state = GetToggleCommandState(replace_toggle)
    if state == 0 or state == -1 then
        SetToggleCommandState(1, replace_toggle, 1)
        RefreshToolbar2(1, replace_toggle)
    else
        SetToggleCommandState(1, replace_toggle, 0)
        RefreshToolbar2(1, replace_toggle)
    end
end

---------------------------------------------------------------------

main()
