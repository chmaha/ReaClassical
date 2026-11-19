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

local PREF_INDEX = 18
local COUNTER_KEY = "GlobalTakeNext"

function M.enabled()
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
    local entries = {}
    for entry in saved:gmatch("([^,]+)") do entries[#entries + 1] = entry end
    return tonumber(entries[PREF_INDEX]) == 1
end

function M.get_next()
    local _, stored = GetProjExtState(0, "ReaClassical", COUNTER_KEY)
    local n = tonumber(stored)
    if not n or n < 1 then return 1 end
    return math.floor(n)
end

function M.set_next(n)
    n = math.max(1, math.floor(tonumber(n) or 1))
    SetProjExtState(0, "ReaClassical", COUNTER_KEY, tostring(n))
end

function M.get(item)
    local _, val = GetSetMediaItemInfo_String(item, "P_EXT:global_take", "", false)
    return tonumber(val)
end

function M.assign_to_guids(guid_str)
    if not M.enabled() or not guid_str or guid_str == "" then return nil end

    local targets = {}
    for guid in guid_str:gmatch("([^,]+)") do targets[guid] = true end

    local items = {}
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local _, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
        if targets[guid] then items[#items + 1] = item end
    end
    if #items == 0 then return nil end

    for _, item in ipairs(items) do
        local existing = M.get(item)
        if existing then return existing end
    end

    local number = M.get_next()
    for _, item in ipairs(items) do
        GetSetMediaItemInfo_String(item, "P_EXT:global_take", tostring(number), true)
    end
    M.set_next(number + 1)
    return number
end

return M
