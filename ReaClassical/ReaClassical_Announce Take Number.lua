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

local main, say, get_item_at_cursor, extract_take_number

---------------------------------------------------------------------

function say(msg)
    if osara_outputMessage then
        osara_outputMessage(tostring(msg))
    end
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function extract_take_number(name)
    local number = name:match("(%d+)$")
    return number and tonumber(number) or nil
end

---------------------------------------------------------------------

function main()
    local track = GetSelectedTrack(0, 0)
    if not track then
        say("No track selected.")
        return
    end

    local item = get_item_at_cursor(track, GetCursorPosition())
    if not item then
        say("No item under edit cursor.")
        return
    end

    local take = GetActiveTake(item)
    if not take then
        say("No active take.")
        return
    end

    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    local take_number = extract_take_number(name)

    if take_number then
        say("Take " .. take_number)
    else
        say("No take number found in item name.")
    end
end

---------------------------------------------------------------------

main()
