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

-- XFM Shift Right (selection-aware). No ripple.
--   Both selected  → whole xfade shifts right: item1.length += amt; item2 shifts right with
--                    waveform pinned and right edge fixed.
--   Left selected  → fade-out shifts right: item1.length += amt only (FADEOUTLEN unchanged).
--   Right selected → fade-in shifts right: item2.pos += amt, item2.soffs += amt,
--                    item2.length -= amt (right edge fixed, FADEINLEN unchanged).

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

    local _, stored_mod = GetProjExtState(0, "ReaClassical", "ModifierFactor")
    local modifier = tonumber(stored_mod) or 5
    local amt = xfu.nudge_amount() * modifier
    local ms  = math.floor(amt * 1000 + 0.5)
    local sel = ctx.selection

    if sel == "right" then
        local ok, err = xfu.check_min_overlap(ctx, amt)
        if not ok then say(err); return end
    else
        local ok, err = xfu.check_item2_headroom(ctx, amt)
        if not ok then say(err); return end
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    if sel == "both" then
        for _, item in ipairs(ctx.group1) do
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_LENGTH", l + amt)
        end
        for _, item in ipairs(ctx.group2) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            local s = xfu.get_item_soffs(item)
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_POSITION", p + amt)
            xfu.set_item_soffs(item,                   s + amt)
            SetMediaItemInfo_Value(item, "D_LENGTH",   math.max(0.001, l - amt))
        end
        xfu.set_xfade_state(ctx.folder_track, ctx.center + amt)
        say("Crossfade shifted right by " .. ms  .. " milliseconds")

    elseif sel == "left" then
        for _, item in ipairs(ctx.group1) do
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_LENGTH", l + amt)
        end
        say("Fade-out shifted right by " .. ms  .. " milliseconds")

    else
        for _, item in ipairs(ctx.group2) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            local s = xfu.get_item_soffs(item)
            local l = GetMediaItemInfo_Value(item, "D_LENGTH")
            SetMediaItemInfo_Value(item, "D_POSITION", p + amt)
            xfu.set_item_soffs(item,                   s + amt)
            SetMediaItemInfo_Value(item, "D_LENGTH",   math.max(0.001, l - amt))
        end
        say("Fade-in shifted right by " .. ms  .. " milliseconds")
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    local new_end1 = ctx.pos1 + ctx.len1
    if sel ~= "right" then new_end1 = new_end1 + amt end
    SetEditCurPos(new_end1, true, true)
    Undo_EndBlock("XFM Shift Right modifier", -1)
end

---------------------------------------------------------------------

main()
