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

-- Match item1's fade-out to item2's fade-in. Item2 is never touched.
-- Moves item1's right edge to item2.pos + D_FADEINLEN (fade-in end).
-- Sets item1's D_FADEOUTLEN = item2's D_FADEINLEN and copies shape.
-- item1's left edge is kept fixed (D_POSITION unchanged, D_LENGTH adjusted).

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

    local fadein_len   = GetMediaItemInfo_Value(ctx.item2, "D_FADEINLEN")
    local fadein_shape = GetMediaItemInfo_Value(ctx.item2, "C_FADEINSHAPE")
    local pos2         = GetMediaItemInfo_Value(ctx.item2, "D_POSITION")

    -- Target: item1's right edge = item2.pos + fadein_len (= fade-in end).
    local new_end1 = pos2 + fadein_len

    Undo_BeginBlock()
    PreventUIRefresh(1)

    -- Adjust item1 group: right edge moves to new_end1, fades set. Left edge fixed.
    for _, item in ipairs(ctx.group1) do
        local p     = GetMediaItemInfo_Value(item, "D_POSITION")
        local new_l = new_end1 - p
        if new_l > 0.001 then
            SetMediaItemInfo_Value(item, "D_LENGTH",          new_l)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN",      fadein_len)
            SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", fadein_len)
            SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE",    fadein_shape)
        end
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Match Right Item Fade", -1)
    say("Fade matched: " .. xfu.shape_name(fadein_shape)
        .. ", " .. string.format("%.0f", fadein_len * 1000) .. " milliseconds")
end

---------------------------------------------------------------------

main()
