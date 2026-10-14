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

function M.is_iem_mode()
    return GetExtState("ReaClassical", "IEMMode") == "1"
end

function M.get_selection()
    local s = GetExtState("ReaClassical", "IEMSelection")
    if s == "" then return "in" end
    return s
end

function M.set_selection(sel)
    SetExtState("ReaClassical", "IEMSelection", sel, false)
end

function M.get_item_guid(item)
    local _, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
    return guid
end

function M.default_side(iu, item)
    local cursor = GetCursorPosition()
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
    local d_in  = math.abs(pos - cursor)
    local d_out = math.abs((pos + len) - cursor)

    local left_crossfaded, right_crossfaded = iu.edge_crossfade_state(item)
    local left_free  = not left_crossfaded
    local right_free = not right_crossfaded

    if left_free and right_free then
        return d_in <= d_out and "in" or "out"
    elseif left_free then
        return "in"
    elseif right_free then
        return "out"
    end
    return "none"
end

function M.sync_context(iu)
    local sel = GetSelectedMediaItem(0, 0)
    if not sel then return nil end

    local peers = iu.get_item_peers(sel)
    local item  = peers[1]
    local guid  = M.get_item_guid(item)

    local stored_guid = GetExtState("ReaClassical", "IEMItemGuid")
    local changed = stored_guid ~= guid
    local side

    if changed then
        side = M.default_side(iu, item)
        SetExtState("ReaClassical", "IEMItemGuid", guid, false)
        M.set_selection(side)
    else
        side = M.get_selection()
    end

    return { item = item, peers = peers, selection = side, changed = changed }
end

return M
