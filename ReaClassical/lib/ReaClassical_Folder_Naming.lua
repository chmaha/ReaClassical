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

-- Converts a track prefix (e.g. "D", "S1", "S2", or a bare track number)
-- into a humanized folder phrase suitable for screen-reader announcements,
-- e.g. "destination folder", "source 2 folder", "folder 1".
local function humanize_folder_phrase(prefix)
    if not prefix or prefix == "" then return "" end
    if prefix:match("^D") then return "destination folder" end
    local snum = prefix:match("^S(%d+)$")
    if snum then return "source " .. snum .. " folder" end
    if prefix:match("^%d+$") then return "folder " .. prefix end
    return prefix .. " folder"
end

return humanize_folder_phrase
