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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local cd = require("ReaClassical_CD_Player_Data")

local M = {}

local NUDGE_SECONDS = 5
local RESTART_THRESHOLD = 3

function M.play_from_here()
    Main_OnCommand(1007, 0)
end

function M.pause()
    Main_OnCommand(1008, 0)
    return (GetPlayState() & 2) == 2
end

function M.stop()
    Main_OnCommand(1016, 0)
    SetEditCurPos(0, false, false)
    return 1
end

function M.next_track(layout)
    local idx = cd.track_index_at(layout, cd.current_pos())
    if idx >= #layout then return nil end
    idx = idx + 1
    cd.seek(layout[idx].start_pos)
    return idx
end

function M.previous_track(layout)
    local pos = cd.current_pos()
    local idx = cd.track_index_at(layout, pos)
    local t = layout[idx]
    if idx > 1 and (pos - t.start_pos) <= RESTART_THRESHOLD then
        idx = idx - 1
    end
    cd.seek(layout[idx].start_pos)
    return idx
end

function M.fast_forward(album_end)
    local pos = math.min(cd.current_pos() + NUDGE_SECONDS, album_end)
    cd.seek(pos)
    return pos
end

function M.rewind()
    local pos = math.max(0, cd.current_pos() - NUDGE_SECONDS)
    cd.seek(pos)
    return pos
end

function M.jump_to_track(layout, n)
    if n > #layout then return nil end
    cd.seek(layout[n].start_pos)
    return n
end

function M.start_review(boundaries, pre_roll, post_roll)
    local pos
    if cd.is_stopped() then
        cd.seek(0)
        pos = 0
    else
        pos = cd.current_pos()
    end

    local idx = nil
    for i, b in ipairs(boundaries) do
        if pos <= b + post_roll then
            idx = i
            break
        end
    end
    if not idx then return nil end

    local b = boundaries[idx]
    local target = idx == 1 and b or math.max(0, b - pre_roll)
    if pos < target then
        cd.seek(target)
    end
    if not cd.is_playing() then M.play_from_here() end
    return idx
end

function M.advance_review(boundaries, idx, pre_roll, post_roll)
    local pos = cd.current_pos()
    local b = boundaries[idx]
    if pos < b + post_roll then return idx end

    local next_idx = idx + 1
    if next_idx > #boundaries then return nil end
    cd.seek(math.max(0, boundaries[next_idx] - pre_roll))
    return next_idx
end

local TIME_MODES = { "track_elapsed", "track_remaining", "album_elapsed", "album_remaining" }
M.TIME_LABELS = {
    track_elapsed   = "Track Elapsed",
    track_remaining = "Track Remaining",
    album_elapsed   = "Album Elapsed",
    album_remaining = "Album Remaining",
}

function M.cycle_time_mode(current)
    for i, m in ipairs(TIME_MODES) do
        if m == current then return TIME_MODES[i % #TIME_MODES + 1] end
    end
    return TIME_MODES[1]
end

local REPEAT_MODES = { "off", "track", "album" }
M.REPEAT_LABELS = { off = "Repeat off", track = "Repeat track", album = "Repeat album" }

function M.cycle_repeat_mode(current)
    for i, m in ipairs(REPEAT_MODES) do
        if m == current then return REPEAT_MODES[i % #REPEAT_MODES + 1] end
    end
    return REPEAT_MODES[1]
end

return M
