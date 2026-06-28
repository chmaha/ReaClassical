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

-- Cycle fade shape (selection-aware):
--   Left   → cycle item1's fade-out shape (C_FADEOUTSHAPE) on item1 + peers.
--   Right  → cycle item2's fade-in shape (C_FADEINSHAPE) on item2 + peers.
--   Both   → cycle item1's fade-out to next shape and match item2's fade-in to the same shape.

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

    local sel = ctx.selection

    Undo_BeginBlock()
    PreventUIRefresh(1)

    if sel == "left" then
        local cur   = GetMediaItemInfo_Value(ctx.item1, "C_FADEOUTSHAPE")
        local next  = xfu.next_fade_shape(cur)
        for _, item in ipairs(ctx.group1) do
            SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", next)
        end
        say("Fade-out shape: " .. xfu.shape_name(next))

    elseif sel == "right" then
        local cur   = GetMediaItemInfo_Value(ctx.item2, "C_FADEINSHAPE")
        local next  = xfu.next_fade_shape(cur)
        for _, item in ipairs(ctx.group2) do
            SetMediaItemInfo_Value(item, "C_FADEINSHAPE", next)
        end
        say("Fade-in shape: " .. xfu.shape_name(next))

    else
        -- Both: cycle item1's fade-out to next shape, then match item2's fade-in to it.
        local cur  = GetMediaItemInfo_Value(ctx.item1, "C_FADEOUTSHAPE")
        local next = xfu.next_fade_shape(cur)
        for _, item in ipairs(ctx.group1) do
            SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", next)
        end
        for _, item in ipairs(ctx.group2) do
            SetMediaItemInfo_Value(item, "C_FADEINSHAPE", next)
        end
        say("Fade shapes: " .. xfu.shape_name(next))
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Cycle Fade Shape", -1)
end

---------------------------------------------------------------------

main()
