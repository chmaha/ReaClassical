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

local M = {}

M.DIRECT_FIELD = { Volume = "D_VOL", Pan = "D_PAN", Width = "D_WIDTH", Mute = "B_MUTE" }

local function db_to_linear(db)
    if db <= -150 then return 0.0 end
    return 10 ^ (db / 20)
end

function M.display_to_raw_field(field, val)
    if field == "D_VOL"   then return db_to_linear(val) end
    if field == "D_PAN"   then return val end
    if field == "D_WIDTH" then return val end
    if field == "B_MUTE"  then return 1 - val end
end

local snapshots = {}

function M.clear()
    for _, snap in ipairs(snapshots) do
        if snap.field then
            SetMediaTrackInfo_Value(snap.track, snap.field, snap.value)
        else
            TrackFX_SetParam(snap.track, snap.fx, snap.param, snap.value)
        end
    end
    snapshots = {}
end

function M.snapshot_track(t, field)
    if not field then return end
    snapshots[#snapshots + 1] = { track = t, field = field, value = GetMediaTrackInfo_Value(t, field) }
end

function M.snapshot_fx(t, fx, param)
    snapshots[#snapshots + 1] = { track = t, fx = fx, param = param, value = TrackFX_GetParam(t, fx, param) }
end

function M.has_targets()
    return #snapshots > 0
end

function M.apply_track(val)
    for _, snap in ipairs(snapshots) do
        if snap.field then
            SetMediaTrackInfo_Value(snap.track, snap.field, M.display_to_raw_field(snap.field, val))
        end
    end
end

function M.apply_fx(val)
    for _, snap in ipairs(snapshots) do
        if snap.fx then
            TrackFX_SetParam(snap.track, snap.fx, snap.param, val)
        end
    end
end

return M
