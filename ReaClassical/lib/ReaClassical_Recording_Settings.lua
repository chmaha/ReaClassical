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

function M.get_take_count(session_name)
    local sep = package.config:sub(1, 1)
    local media_path = GetProjectPath(0)
    local max_take = 0
    local i = 0
    while true do
        local filename = EnumerateFiles(media_path .. sep .. session_name, i)
        if not filename then break end
        local n = tonumber(filename:match(".*[^%d](%d+)%)?%.%a+$"))
        if n and n > max_take then max_take = n end
        i = i + 1
    end
    return max_take
end

function M.update_wildcards(sess, take_num)
    if not APIExists("SNM_SetStringConfigVar") then return end
    local sep = package.config:sub(1, 1)
    local s_dir = sess ~= "" and (sess .. sep) or ""
    local s_sfx = sess ~= "" and (sess .. "_") or ""
    local padded = string.format("%03d", math.max(1, tonumber(take_num) or 1))
    SNM_SetStringConfigVar("recfile_wildcards", s_dir .. s_sfx .. "$tracknameornumber_T" .. padded)
end

function M.set_session(name)
    SetProjExtState(0, "ReaClassical", "TakeSessionName", name)
    SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "0")
    local next_take = M.get_take_count(name) + 1
    SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(next_take))
    M.update_wildcards(name, next_take)
    return next_take
end

function M.clear_session()
    return M.set_session("")
end

function M.set_take(n)
    local _, sess = GetProjExtState(0, "ReaClassical", "TakeSessionName")
    local max_found = M.get_take_count(sess)
    if n < max_found then
        return false, max_found
    end
    SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(n))
    SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "1")
    M.update_wildcards(sess, n)
    return true
end

function M.set_take_auto()
    local _, sess = GetProjExtState(0, "ReaClassical", "TakeSessionName")
    SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "0")
    local next_take = M.get_take_count(sess) + 1
    SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(next_take))
    M.update_wildcards(sess, next_take)
    return next_take
end

local function set_time_field(ext_key, val)
    if not val:match("^%d+:%d%d$") then return false end
    SetProjExtState(0, "ReaClassical", ext_key, val)
    return true
end

function M.set_start(val) return set_time_field("Recording Start", val) end

function M.set_end(val) return set_time_field("Recording End", val) end

function M.set_duration(val) return set_time_field("Recording Duration", val) end

function M.clear_time()
    SetProjExtState(0, "ReaClassical", "Recording Start", "")
    SetProjExtState(0, "ReaClassical", "Recording End", "")
    SetProjExtState(0, "ReaClassical", "Recording Duration", "")
end

function M.set_overlap(on) SetProjExtState(0, "ReaClassical", "AllowOverlappingTakes", on and "1" or "0") end

function M.set_horizontal(on) SetProjExtState(0, "ReaClassical", "RecordTakesHorizontally", on and "1" or "0") end

function M.set_clip(on) SetProjExtState(0, "ReaClassical", "ClipReporting", on and "1" or "0") end

return M
