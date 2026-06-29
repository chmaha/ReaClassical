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

-- Reset the selected item group's volume to 0 dB (selection-aware).
--   Left selected  → reset item1 group volume to 0 dB.
--   Right selected → reset item2 group volume to 0 dB.
--   Both selected  → blocked.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

---------------------------------------------------------------------

local function main()
    if not xfu.is_xfade_mode() then return end

    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end
    xfu.ensure_xfade_snapshot(ctx)

    if ctx.selection == "both" then
        say("Select left or right item first")
        return
    end

    local group = ctx.selection == "left" and ctx.group1 or ctx.group2
    local label = ctx.selection == "left" and "Left"     or "Right"

    Undo_BeginBlock()
    PreventUIRefresh(1)

    for _, item in ipairs(group) do
        SetMediaItemInfo_Value(item, "D_VOL", 1.0)
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Item Volume Reset", -1)
    say(label .. " item volume: 0.0 dB")
end

---------------------------------------------------------------------

main()
