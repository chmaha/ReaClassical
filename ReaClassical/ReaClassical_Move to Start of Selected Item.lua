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
local say = require("ReaClassical_Announce")

local function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

-- Mirrors announce_current_item() (Next/Previous Item or Fade.lua):
-- "008" -> "Take 8", "Beethoven_T006" -> "Beethoven take 6", anything else
-- -> the raw name as-is.
local function humanize_take_name(name)
    if name == "" then return "unnamed item" end
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
    local item = get_selected_media_item_at(0)
    if not item then
        say("No item selected")
        return
    end

    local pos = GetMediaItemInfo_Value(item, "D_POSITION")

    SetEditCurPos(pos, true, true)
    UpdateArrange()

    local take = GetActiveTake(item)
    local name = ""
    if take then
        _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    end
    say("Moved to start of " .. humanize_take_name(name))
end

main()
