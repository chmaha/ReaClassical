--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "../lib/?.lua;"
local say = require("ReaEdit_Announce")
local xfu = require("ReaEdit_XFM_Utils")

local function main()
    if not xfu.is_xfade_mode() then return end

    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end
    xfu.ensure_xfade_snapshot(ctx)

    if ctx.selection == "both" then
        say("Slip requires single item selected")
        return
    end

    local amt = xfu.nudge_amount() * xfu.modifier_factor()
    local ms  = math.floor(amt * 1000 + 0.5)

    if ctx.selection == "right" then
        local s2 = xfu.get_item_soffs(ctx.item2)
        if s2 - amt < 0 then say("Cannot slip: already at source start"); return end
    else
        local l1 = GetMediaItemInfo_Value(ctx.item1, "D_LENGTH")
        if l1 - ctx.overlap - amt < 0.001 then say("Cannot slip: left item's pre-fade content too short"); return end
    end

    local skip = {}
    for _, it in ipairs(ctx.group1) do skip[it] = true end
    for _, it in ipairs(ctx.group2) do skip[it] = true end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    local old_end1 = ctx.end1

    if ctx.selection == "left" then
        for _, item in ipairs(ctx.group1) do
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_LENGTH", l - amt)
        end
        for _, item in ipairs(ctx.group2) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", p - amt)
        end
        xfu.ripple_all_from(old_end1 - 0.0001, -amt, skip)
        xfu.set_xfade_state(ctx.ref_track, ctx.center - amt)
        say("Left item slipped right by " .. ms .. " milliseconds")
    else
        for _, item in ipairs(ctx.group2) do
            local s = xfu.get_item_soffs(item)
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            xfu.set_item_soffs(item,           math.max(0, s - amt))
            SetMediaItemInfo_Value(item, "D_LENGTH", l + amt)
        end
        xfu.ripple_all_from(old_end1 - 0.0001, amt, skip)
        say("Right item slipped right by " .. ms .. " milliseconds")
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Slip Item Right modifier", -1)
end

main()
