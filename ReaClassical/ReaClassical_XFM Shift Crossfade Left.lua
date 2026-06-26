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

-- XFM Shift Left (selection-aware). No ripple.
--   Both selected  → whole xfade shifts left: item1.length -= amt; item2 shifts left with
--                    waveform pinned and right edge fixed.
--   Left selected  → fade-out shifts left: item1.length -= amt only (FADEOUTLEN unchanged).
--   Right selected → fade-in shifts left: item2.pos -= amt, item2.soffs -= amt,
--                    item2.length += amt (right edge fixed, FADEINLEN unchanged).

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

---------------------------------------------------------------------

local function main()
    if not xfu.is_xfade_mode() then return end

    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end

    local amt = xfu.nudge_amount()
    local ms  = math.floor(amt * 1000 + 0.5)
    local sel = ctx.selection

    if ctx.len1 - amt < 0.001 then
        say("Cannot shift: left item too short")
        return
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    if sel == "both" then
        for _, item in ipairs(ctx.group1) do
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_LENGTH", math.max(0.001, l - amt))
        end
        for _, item in ipairs(ctx.group2) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            local s = xfu.get_item_soffs(item)
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p - amt))
            xfu.set_item_soffs(item,                   math.max(0, s - amt))
            SetMediaItemInfo_Value(item, "D_LENGTH",   l + amt)
        end
        xfu.set_xfade_state(ctx.folder_track, ctx.center - amt)
        say("Crossfade shifted left by " .. ms .. "ms")

    elseif sel == "left" then
        for _, item in ipairs(ctx.group1) do
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_LENGTH", math.max(0.001, l - amt))
        end
        say("Fade-out shifted left by " .. ms .. "ms")

    else
        for _, item in ipairs(ctx.group2) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            local s = xfu.get_item_soffs(item)
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p - amt))
            xfu.set_item_soffs(item,                   math.max(0, s - amt))
            SetMediaItemInfo_Value(item, "D_LENGTH",   l + amt)
        end
        say("Fade-in shifted left by " .. ms .. "ms")
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Shift Left", -1)
end

---------------------------------------------------------------------

main()
