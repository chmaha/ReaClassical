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

local enum_project_markers = require("ReaClassical_Marker_Enum")

local M = {}

function M.parse(str, max_track)
    if not str or str:match("^%s*$") then
        return nil, nil
    end

    local set = {}
    for token in str:gmatch("[^,]+") do
        token = token:match("^%s*(.-)%s*$")
        local a, b = token:match("^(%d+)%s*%-%s*(%d+)$")
        if a then
            a, b = tonumber(a), tonumber(b)
            if a > b then
                return nil, "invalid range \"" .. token .. "\" (start after end)"
            end
            for n = a, b do set[n] = true end
        else
            local n = token:match("^(%d+)$")
            if not n then
                return nil, "invalid entry \"" .. token .. "\""
            end
            set[tonumber(n)] = true
        end
    end

    if next(set) == nil then
        return nil, "no tracks specified"
    end

    for n in pairs(set) do
        if n < 1 or n > max_track then
            return nil, "track " .. n .. " out of range (1-" .. max_track .. ")"
        end
    end

    return set, nil
end

function M.get_regions(proj)
    local regions = {}
    local num_markers = GetNumRegionsOrMarkers(proj)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, idx, color = enum_project_markers(proj, i)
        if retval and isrgn then
            regions[#regions + 1] = { index = idx, pos = pos, rgnend = rgnend, name = name, color = color }
        end
    end
    table.sort(regions, function(a, b) return a.index < b.index end)
    return regions
end

function M.render_subset(proj, track_set, render_fn)
    if not track_set then
        render_fn()
        return
    end

    local regions = M.get_regions(proj)
    local removed = {}
    for _, r in ipairs(regions) do
        if not track_set[r.index] then
            removed[#removed + 1] = r
        end
    end

    for _, r in ipairs(removed) do
        DeleteProjectMarker(proj, r.index, true)
    end

    local ok, err = pcall(render_fn)

    for _, r in ipairs(removed) do
        AddProjectMarker2(proj, true, r.pos, r.rgnend, r.name, r.index, r.color)
    end

    if not ok then error(err) end
end

return M
