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

-- Slip the right item's source content left (earlier source plays at item2.pos):
--   item2.soffs -= amt  (earlier content)
--   item2.length += amt (right edge extends to maintain downstream crossfade)
--   Downstream items ripple right by amt. item1 and item2.pos are untouched.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFade_Utils")

---------------------------------------------------------------------

local function main()
    if not xfu.is_xfade_mode() then return end

    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end

    if ctx.selection == "both" then
        say("Slip requires single item selected")
        return
    end

    local amt = xfu.nudge_amount()
    -- right selected: soffs-=amt, len+=amt, ripple right (dir=1, normal)
    -- left selected:  soffs+=amt, len-=amt, ripple left  (dir=-1, reversed)
    local dir = (ctx.selection == "left") and -1 or 1

    if dir == 1 then
        local s2 = xfu.get_item_soffs(ctx.item2)
        if s2 - amt < 0 then say("Cannot slip: already at source start"); return end
    else
        local l2 = GetMediaItemInfo_Value(ctx.item2, "D_LENGTH")
        if l2 - amt < 0.001 then say("Cannot slip: right item too short"); return end
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    local old_end1 = ctx.end1
    for _, item in ipairs(ctx.group2) do
        local s = xfu.get_item_soffs(item)
        local l = GetMediaItemInfo_Value(item, "D_LENGTH")
        xfu.set_item_soffs(item,           math.max(0,     s - amt * dir))
        SetMediaItemInfo_Value(item, "D_LENGTH", math.max(0.001, l + amt * dir))
    end

    local skip = {}
    for _, it in ipairs(ctx.group1) do skip[it] = true end
    for _, it in ipairs(ctx.group2) do skip[it] = true end
    xfu.ripple_folder_from(ctx.folder_track, old_end1 - 0.0001, amt * dir, skip)

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("Xfade Slip Item Left", -1)
    say("Item slipped left")
end

---------------------------------------------------------------------

main()
