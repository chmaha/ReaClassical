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

local function humanize_marker_label(raw_name)
    if not raw_name or raw_name == "" then return "marker" end
    local label = raw_name:match(":(.+)$") or raw_name
    local map = {
        ["DEST-IN"] = "destination in",
        ["DEST-OUT"] = "destination out",
        ["SOURCE-IN"] = "source in",
        ["SOURCE-OUT"] = "source out",
    }
    return map[label] or raw_name
end

return humanize_marker_label
