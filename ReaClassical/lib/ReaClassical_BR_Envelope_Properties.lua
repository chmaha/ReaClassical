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

local function find_line(lines, prefix)
    for i, line in ipairs(lines) do
        if line:sub(1, #prefix) == prefix then return i end
    end
    return nil
end

local function split_lines(chunk)
    local lines = {}
    for line in chunk:gmatch("[^\n]+") do table.insert(lines, line) end
    return lines
end

local function get_br_env_properties(env)
    if not env then return false, false, false, false, 0, 0, false end
    local ok, chunk = GetEnvelopeStateChunk(env, "", false)
    if not ok then return false, false, false, false, 0, 0, false end
    local lines = split_lines(chunk)

    local active, visible, lane, height, armed, shape = 0, 0, 0, 0, 0, 0

    local i = find_line(lines, "ACT ")
    if i then active = lines[i]:match("^ACT (%-?%d+)") end

    i = find_line(lines, "VIS ")
    if i then visible, lane = lines[i]:match("^VIS (%-?%d+) (%-?%d+)") end

    i = find_line(lines, "LANEHEIGHT ")
    if i then height = lines[i]:match("^LANEHEIGHT (%-?%d+)") end

    i = find_line(lines, "ARM ")
    if i then armed = lines[i]:match("^ARM (%-?%d+)") end

    i = find_line(lines, "DEFSHAPE ")
    if i then shape = lines[i]:match("^DEFSHAPE (%-?%d+)") end

    local fader_scaling = find_line(lines, "VOLTYPE ") ~= nil

    return (tonumber(active) or 0) ~= 0, (tonumber(visible) or 0) ~= 0, (tonumber(armed) or 0) ~= 0,
        (tonumber(lane) or 0) ~= 0, tonumber(height) or 0, tonumber(shape) or 0, fader_scaling
end

local function set_br_env_properties(env, active, visible, armed, in_lane, lane_height, default_shape, fader_scaling)
    if not env then return end
    local ok, chunk = GetEnvelopeStateChunk(env, "", false)
    if not ok then return end
    local lines = split_lines(chunk)

    local is_take_env = GetEnvelopeInfo_Value(env, "P_TAKE") ~= 0

    local i = find_line(lines, "ACT ")
    if i then
        local _, ai = lines[i]:match("^ACT (%-?%d+) (%-?%d+)")
        lines[i] = string.format("ACT %d %s", active and 1 or 0, ai or "-1")
    end

    i = find_line(lines, "VIS ")
    if i then
        local _, existing_lane = lines[i]:match("^VIS (%-?%d+) (%-?%d+)")
        local lane_val = is_take_env and (tonumber(existing_lane) or 0) or (in_lane and 1 or 0)
        lines[i] = string.format("VIS %d %d 1", visible and 1 or 0, lane_val)
    end

    i = find_line(lines, "LANEHEIGHT ")
    if i then
        local _, height_unknown = lines[i]:match("^LANEHEIGHT (%-?%d+) (%-?%d+)")
        lines[i] = string.format("LANEHEIGHT %d %s", lane_height, height_unknown or "0")
    end

    i = find_line(lines, "ARM ")
    if i then
        lines[i] = string.format("ARM %d", armed and 1 or 0)
    end

    i = find_line(lines, "DEFSHAPE ")
    if i then
        local _, range, snap = lines[i]:match("^DEFSHAPE (%-?%d+) (%-?%d+) (%-?%d+)")
        lines[i] = string.format("DEFSHAPE %d %s %s", default_shape, range or "-1", snap or "-1")
    end

    local is_volume_env = lines[1] and lines[1]:find("VOLENV") ~= nil
    if is_volume_env then
        local voltype_idx = find_line(lines, "VOLTYPE ")
        if fader_scaling and not voltype_idx then
            local defshape_idx = find_line(lines, "DEFSHAPE ")
            table.insert(lines, (defshape_idx or #lines) + 1, "VOLTYPE 1")
        elseif not fader_scaling and voltype_idx then
            table.remove(lines, voltype_idx)
        end
    end

    SetEnvelopeStateChunk(env, table.concat(lines, "\n"), false)
end

return { get = get_br_env_properties, set = set_br_env_properties }
