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

local function get_humanized_name(item)
    local take = GetActiveTake(item)
    local name = ""
    if take then
        _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    end
    if name == "" then return nil end
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        return prefix .. " take " .. tonumber(take_num)
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        return "take " .. tonumber(only_num)
    end
    return name
end

local function main()
    local track = GetSelectedTrack(0, 0)
    if not track then return end

    local count = CountTrackMediaItems(track)
    if count == 0 then return end

    local item = GetTrackMediaItem(track, count - 1)
    local pos  = GetMediaItemInfo_Value(item, "D_POSITION")

    Main_OnCommand(40289, 0) -- Item: Unselect all items
    SetMediaItemSelected(item, true)
    SetEditCurPos(pos, true, true)
    UpdateArrange()
    local human_name = get_humanized_name(item)
    if human_name then
        say("Moved to last item " .. human_name)
    else
        say("Moved to last item")
    end
end

main()
