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

-- XFM Nudge Item Right (selection-aware):
--   Right selected → item1 right edge extends + item2 shifts right; overlap unchanged; downstream ripple.
--   Left selected  → item2.soffs -= amt, item2.length += amt (slip right on item2); downstream ripple right.
--   Both selected  → blocked.

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

    Undo_BeginBlock()
    PreventUIRefresh(1)

    if sel == "both" then
        say("Select left or right item first")
        PreventUIRefresh(-1)
        Undo_EndBlock("XFM Nudge Item Right", -1)
        return

    elseif sel == "left" then
        -- Soffs-based: slip item2 left (earlier source content). item1 untouched.
        local s2 = xfu.get_item_soffs(ctx.item2)
        if s2 - amt < 0 then
            say("Cannot nudge: already at source start")
            PreventUIRefresh(-1)
            Undo_EndBlock("XFM Nudge Item Right", -1)
            return
        end
        local old_end1 = ctx.end1
        for _, item in ipairs(ctx.group2) do
            local s = xfu.get_item_soffs(item)
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            xfu.set_item_soffs(item, math.max(0, s - amt))
            SetMediaItemInfo_Value(item, "D_LENGTH", l + amt)
        end
        local skip = {}
        for _, it in ipairs(ctx.group1) do skip[it] = true end
        for _, it in ipairs(ctx.group2) do skip[it] = true end
        xfu.ripple_folder_from(ctx.folder_track, old_end1 - 0.0001, amt, skip)
        say("Left item nudged right by " .. ms .. "ms")

    else
        -- Position-based: extend item1 right edge + shift item2 right. Overlap unchanged.
        local old_end1 = ctx.end1
        for _, item in ipairs(ctx.group1) do
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_LENGTH", l + amt)
        end
        for _, item in ipairs(ctx.group2) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", p + amt)
        end
        local skip = {}
        for _, it in ipairs(ctx.group1) do skip[it] = true end
        for _, it in ipairs(ctx.group2) do skip[it] = true end
        xfu.ripple_folder_from(ctx.folder_track, old_end1 - 0.0001, amt, skip)
        xfu.set_xfade_state(ctx.folder_track, ctx.center + amt)
        say("Right item nudged right by " .. ms .. "ms")
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Nudge Item Right", -1)
end

---------------------------------------------------------------------

main()
