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

-- Narrow the crossfade. item1 boundaries unchanged; only fade-out shrinks.
-- item2 shifts right to reduce overlap, waveform pinned, right edge fixed.
--   item1: D_FADEOUTLEN -= amt
--   item2: D_POSITION += amt, D_STARTOFFS += amt, D_LENGTH -= amt, D_FADEINLEN -= amt
-- No ripple.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

---------------------------------------------------------------------

local min_fade = 0.001

local function main()
    if not xfu.is_xfade_mode() then return end

    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end

    local amt = xfu.nudge_amount()

    local fo = GetMediaItemInfo_Value(ctx.item1, "D_FADEOUTLEN")
    local fi = GetMediaItemInfo_Value(ctx.item2, "D_FADEINLEN")
    if fo - amt < min_fade or fi - amt < min_fade then
        say("Cannot narrow: fades too short")
        return
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    for _, item in ipairs(ctx.group1) do
        local fo = GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN",      math.max(min_fade, fo - amt))
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", math.max(min_fade, fo - amt))
    end
    for _, item in ipairs(ctx.group2) do
        local p  = GetMediaItemInfo_Value(item, "D_POSITION")
        local s  = xfu.get_item_soffs(item)
        local l  = GetMediaItemInfo_Value(item, "D_LENGTH")
        local fi = GetMediaItemInfo_Value(item, "D_FADEINLEN")
        SetMediaItemInfo_Value(item, "D_POSITION",       p + amt)
        xfu.set_item_soffs(item,                         s + amt)
        SetMediaItemInfo_Value(item, "D_LENGTH",         math.max(0.001, l - amt))
        SetMediaItemInfo_Value(item, "D_FADEINLEN",      math.max(min_fade, fi - amt))
        SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", math.max(min_fade, fi - amt))
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Narrow", -1)
    say("Crossfade narrowed to " .. math.floor(math.max(min_fade, fo - amt) * 1000 + 0.5)  .. " milliseconds")
end

---------------------------------------------------------------------

main()
