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


---------------------------------------------------------------------

return {
        dest_marker = ColorToNative(23,203,223) | 0x1000000,
        source_marker = ColorToNative(23, 223, 143) | 0x1000000,
        aux = ColorToNative(127, 88, 85),
        submix = ColorToNative(85,124,127),
        roomtone = ColorToNative(127, 99, 65),
        rcmaster = ColorToNative(25, 75, 25),
        mixer = ColorToNative(200, 200, 250),
        dest_items_one = ColorToNative(18, 121, 177)|0x1000000,
        dest_items_two = ColorToNative(99, 180, 220)|0x1000000,
        source_items = ColorToNative(65, 127, 99)|0x1000000,
        audition = ColorToNative(10, 10, 10) | 0x1000000,
        ref = ColorToNative(100, 100, 100) | 0x1000000,
        xfade_red = ColorToNative(242, 46, 55) | 0x1000000,
        xfade_green = ColorToNative(63, 242, 57) | 0x1000000,
        rank_good = ColorToNative(0, 173, 131) | 0x1000000,
        rank_very_good = ColorToNative(50, 205, 50) | 0x1000000,
        rank_excellent = ColorToNative(57, 255, 20)  | 0x1000000,
        rank_below_average = ColorToNative(255, 191, 0) | 0x1000000,
        rank_poor = ColorToNative(255, 69, 0) | 0x1000000,
        rank_unusable = ColorToNative(220, 20, 60) | 0x1000000
    }

---------------------------------------------------------------------


