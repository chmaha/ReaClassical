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

return {
        dest_marker = ColorToNative(23,203,223) | 0x1000000,
        source_marker = ColorToNative(23, 223, 143) | 0x1000000,
        aux = ColorToNative(127, 88, 85),
        roomtone = ColorToNative(127, 99, 65),
        rcmaster = ColorToNative(25, 75, 25),
        dest_items_one = ColorToNative(18, 121, 177)|0x1000000,
        dest_items_two = ColorToNative(99, 180, 220)|0x1000000,
        source_items = ColorToNative(65, 127, 99)|0x1000000,
        audition = ColorToNative(10, 10, 10) | 0x1000000
    }

---------------------------------------------------------------------


