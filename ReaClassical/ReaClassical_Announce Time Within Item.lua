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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say              = require("ReaClassical_Announce")
local humanize_timestr  = require("ReaClassical_Time_Naming")
local rank_info         = require("ReaClassical_Rank_Info")
local iu                = require("ReaClassical_Item_Utils")
local track_scan        = require("ReaClassical_Track_Scan")

local main, get_active_folder, get_item_at_cursor

function get_active_folder(cache)
    local unmuted = {}
    for _, f in ipairs(cache.folders) do
        if GetMediaTrackInfo_Value(f.track, "B_MUTE") == 0 then
            unmuted[#unmuted + 1] = f.track
        end
    end
    if #unmuted == 1 then return unmuted[1] end

    local selected = GetSelectedTrack(0, 0)
    local parent = selected and cache.parent[selected]
    if parent then return parent end

    return unmuted[1]
end

function get_item_at_cursor(track, cursor_pos)
    for i = 0, CountTrackMediaItems(track) - 1 do
        local item = GetTrackMediaItem(track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        if cursor_pos >= pos and cursor_pos <= pos + len then
            return item
        end
    end
    return nil
end

function main()
    local cache = track_scan.build()
    if #cache.folders == 0 then
        say("No ReaClassical folders found.")
        return
    end

    local folder = get_active_folder(cache)
    if not folder then
        say("No active ReaClassical folder found.")
        return
    end

    local cursor_pos = GetCursorPosition()
    local item = get_item_at_cursor(folder, cursor_pos)
    if not item then
        say("No item under edit cursor.")
        return
    end

    local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
    local offset_str = humanize_timestr(format_timestr_pos(cursor_pos - item_start, "", -1))
    if offset_str == "At beginning of project" then
        offset_str = "At start of item"
    end

    say(offset_str .. ", " .. iu.item_label(item, rank_info))
end

main()
