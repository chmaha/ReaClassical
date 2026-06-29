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

-- Grow the END of the selected item's fade (selection-aware):
--   Both   → item1 right edge grows AND item2 D_FADEINLEN grows.
--   Left   → item1 right edge moves right (D_LENGTH + D_FADEOUTLEN both grow; fade-out start anchored).
--   Right  → D_FADEINLEN on item2 grows only; item2 boundaries unchanged.
-- No ripple.

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

    local sel    = ctx.selection
    local amt    = xfu.nudge_amount()
    local old_fo = GetMediaItemInfo_Value(ctx.item1, "D_FADEOUTLEN")
    local old_fi = GetMediaItemInfo_Value(ctx.item2, "D_FADEINLEN")

    if sel == "both" or sel == "left" then
        local ok, err = xfu.check_item2_headroom(ctx, amt)
        if not ok then say(err); return end
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    if sel == "both" then
        for _, item in ipairs(ctx.group1) do
            local l  = GetMediaItemInfo_Value(item, "D_LENGTH")
            local fo = GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
            SetMediaItemInfo_Value(item, "D_LENGTH",          l  + amt)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN",      fo + amt)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", fo + amt)
        end
        for _, item in ipairs(ctx.group2) do
            local fi = GetMediaItemInfo_Value(item, "D_FADEINLEN")
            SetMediaItemInfo_Value(item, "D_FADEINLEN",      fi + amt)
            SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", fi + amt)
        end
        say("Fade ends grown to " .. math.floor((old_fo + amt) * 1000 + 0.5)  .. " milliseconds")
    elseif sel == "left" then
        for _, item in ipairs(ctx.group1) do
            local l  = GetMediaItemInfo_Value(item, "D_LENGTH")
            local fo = GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
            SetMediaItemInfo_Value(item, "D_LENGTH",          l  + amt)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN",      fo + amt)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", fo + amt)
        end
        say("Fade-out end grown to " .. math.floor((old_fo + amt) * 1000 + 0.5)  .. " milliseconds")
    else
        for _, item in ipairs(ctx.group2) do
            local fi = GetMediaItemInfo_Value(item, "D_FADEINLEN")
            SetMediaItemInfo_Value(item, "D_FADEINLEN",      fi + amt)
            SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", fi + amt)
        end
        say("Fade-in end grown to " .. math.floor((old_fi + amt) * 1000 + 0.5)  .. " milliseconds")
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Grow Fade End", -1)
end

---------------------------------------------------------------------

main()
