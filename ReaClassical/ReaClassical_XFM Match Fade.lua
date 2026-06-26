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

-- Match item2's fade-in to item1's fade-out. Item1 is never touched.
-- Moves item2's left edge to item1's fade-out start (item1.end - D_FADEOUTLEN).
-- Sets item2's D_FADEINLEN = item1's D_FADEOUTLEN so fade-in end lands at item1.end.
-- item2's right end is kept fixed (D_LENGTH adjusted). Shape is copied.

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

    local end1          = GetMediaItemInfo_Value(ctx.item1, "D_POSITION")
                        + GetMediaItemInfo_Value(ctx.item1, "D_LENGTH")
    local fadeout_len   = GetMediaItemInfo_Value(ctx.item1, "D_FADEOUTLEN")
    local fadeout_shape = GetMediaItemInfo_Value(ctx.item1, "C_FADEOUTSHAPE")

    -- Target: item2.pos = fade-out start; item2.D_FADEINLEN = fade-out length.
    local old_pos2  = GetMediaItemInfo_Value(ctx.item2, "D_POSITION")
    local old_len2  = GetMediaItemInfo_Value(ctx.item2, "D_LENGTH")
    local old_end2  = old_pos2 + old_len2
    local delta     = (end1 - fadeout_len) - old_pos2  -- negative = item2 moves left

    Undo_BeginBlock()
    PreventUIRefresh(1)

    -- Build skip set for ripple.
    local skip = {}
    for _, item in ipairs(ctx.group2) do skip[item] = true end

    -- Move item2 group: pos and startoffs shift by delta, length unchanged, fades set.
    for _, item in ipairs(ctx.group2) do
        local p = GetMediaItemInfo_Value(item, "D_POSITION")
        local s = xfu.get_item_soffs(item)
        SetMediaItemInfo_Value(item, "D_POSITION",  math.max(0, p + delta))
        xfu.set_item_soffs(item,                    math.max(0, s + delta))
        SetMediaItemInfo_Value(item, "D_FADEINLEN",      fadeout_len)
        SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", fadeout_len)
        SetMediaItemInfo_Value(item, "C_FADEINSHAPE",    fadeout_shape)
    end

    -- Ripple all downstream items in the folder by the same delta.
    xfu.ripple_folder_from(ctx.folder_track, old_end2 - 0.001, delta, skip)

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Match Fade", -1)
    say("Fade matched: " .. xfu.shape_name(fadeout_shape)
        .. ", " .. string.format("%.0f", fadeout_len * 1000) .. " ms")
end

---------------------------------------------------------------------

main()
