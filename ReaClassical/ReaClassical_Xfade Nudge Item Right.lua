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

-- Xfade Nudge Item Right (selection-aware):
--   Left selected  → item1 right edge extends only; overlap grows; no ripple; fades updated.
--   Right selected → item1 right edge extends + item2 shifts right; overlap unchanged; downstream ripple.
--   Both selected  → blocked.

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

    local amt = xfu.nudge_amount()
    local sel = ctx.selection

    Undo_BeginBlock()
    PreventUIRefresh(1)

    if sel == "both" then
        say("Select left or right item first")
        PreventUIRefresh(-1)
        Undo_EndBlock("Xfade Nudge Item Right", -1)
        return

    elseif sel == "left" then
        -- Extend item1 right edge only. Overlap grows. No ripple.
        for _, item in ipairs(ctx.group1) do
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_LENGTH", l + amt)
        end
        xfu.update_xfade_fades(ctx)
        xfu.set_xfade_state(ctx.folder_track, ctx.center + amt * 0.5)
        say("Left item nudged right")

    else
        -- Extend item1 right edge + shift item2 right. Overlap unchanged. Downstream ripple.
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
        say("Right item nudged right")
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("Xfade Nudge Item Right", -1)
end

---------------------------------------------------------------------

main()
