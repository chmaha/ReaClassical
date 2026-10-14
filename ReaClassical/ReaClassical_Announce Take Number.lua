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
local say = require("ReaClassical_Announce")
local rank_info = require("ReaClassical_Rank_Info")

local main, get_items_at_cursor, display_name, humanize_item_name

function get_items_at_cursor(track, cursor_pos)
    local found = {}
    for i = 0, CountTrackMediaItems(track) - 1 do
        local item = GetTrackMediaItem(track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        if cursor_pos >= pos and cursor_pos <= pos + len then
            found[#found + 1] = { item = item, pos = pos, end_pos = pos + len }
        end
    end
    return found
end

function humanize_item_name(name)
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        return prefix .. " take " .. tonumber(take_num)
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        return "Take " .. tonumber(only_num)
    end
    return nil
end

function display_name(item)
    local take = GetActiveTake(item)
    if not take then return nil end
    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    local stripped_name = rank_info.strip_rank_prefix(name)
    return humanize_item_name(stripped_name)
        or (stripped_name ~= "" and stripped_name or "no name")
end

function main()
    local playstate = GetPlayState()

    if playstate & 4 == 4 then
        local _, take_num = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        if take_num ~= "" then
            say("Recording take " .. take_num)
        else
            say("No take number found.")
        end
        return
    end

    local track = GetSelectedTrack(0, 0)
    if not track then
        say("No track selected.")
        return
    end

    local is_playing = playstate & 1 == 1
    local cursor_pos = is_playing and GetPlayPosition() or GetCursorPosition()

    local containing = get_items_at_cursor(track, cursor_pos)
    if #containing == 0 then
        say(is_playing and "No item under playhead." or "No item under edit cursor.")
        return
    end

    local chosen = containing[#containing]

    if not is_playing and #containing >= 2 then
        local previous = containing[#containing - 1]
        if chosen.pos < previous.end_pos - 0.0001 then
            local previous_name = display_name(previous.item)
            local chosen_name = display_name(chosen.item)
            if previous_name and chosen_name then
                say(previous_name .. " crossfaded with " .. chosen_name
                    .. rank_info.rank_announce_suffix(chosen.item))
                return
            end
        end
    end

    local humanized = display_name(chosen.item)
    if not humanized then
        say("No active take.")
        return
    end

    if is_playing then
        local only_num = humanized:match("^Take (%d+)$")
        say((only_num and ("Playing take " .. only_num) or ("Playing " .. humanized))
            .. rank_info.rank_announce_suffix(chosen.item))
    else
        say(humanized .. rank_info.rank_announce_suffix(chosen.item))
    end
end

main()
