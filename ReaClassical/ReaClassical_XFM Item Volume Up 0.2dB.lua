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

-- Raise the selected item group's volume by 0.2 dB (selection-aware).
--   Left selected  → raise item1 group volume by 0.2 dB.
--   Right selected → raise item2 group volume by 0.2 dB.
--   Both selected  → blocked.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

---------------------------------------------------------------------

local STEP_LIN = 10 ^ (0.2 / 20)  -- +0.2 dB as a linear multiplier

local function main()
    if not xfu.is_xfade_mode() then return end

    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end

    if ctx.selection == "both" then
        say("Select left or right item first")
        return
    end

    local group    = ctx.selection == "left" and ctx.group1 or ctx.group2
    local ref_item = ctx.selection == "left" and ctx.item1  or ctx.item2
    local label    = ctx.selection == "left" and "Left"     or "Right"

    local new_vol = GetMediaItemInfo_Value(ref_item, "D_VOL") * STEP_LIN
    local new_db  = 20 * math.log(new_vol) / math.log(10)

    Undo_BeginBlock()
    PreventUIRefresh(1)

    for _, item in ipairs(group) do
        local v = GetMediaItemInfo_Value(item, "D_VOL")
        SetMediaItemInfo_Value(item, "D_VOL", v * STEP_LIN)
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Item Volume Up 0.2dB", -1)
    say(label .. " item volume: " .. string.format("%.1f", new_db) .. " dB")
end

---------------------------------------------------------------------

main()
