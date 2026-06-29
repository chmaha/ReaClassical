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

-- Reset both fades to 35ms equal-power. Always affects both fades regardless of selection.
-- item1 FADEOUTLEN → 0.035; item2 shifts so overlap = 0.035 (waveform pinned, right edge fixed),
-- item2 FADEINLEN → 0.035. No ripple.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

---------------------------------------------------------------------

local TARGET = 0.035

local function main()
    if not xfu.is_xfade_mode() then return end

    local ctx = xfu.get_xfade_context()
    if not ctx then say("No crossfade context"); return end
    xfu.ensure_xfade_snapshot(ctx)

    local current_overlap = ctx.end1 - ctx.pos2
    local delta = TARGET - current_overlap

    Undo_BeginBlock()
    PreventUIRefresh(1)

    for _, item in ipairs(ctx.group1) do
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN",      TARGET)
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", TARGET)
        SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE",    1)
    end

    for _, item in ipairs(ctx.group2) do
        local p = GetMediaItemInfo_Value(item, "D_POSITION")
        local s = xfu.get_item_soffs(item)
        local l = GetMediaItemInfo_Value(item, "D_LENGTH")
        SetMediaItemInfo_Value(item, "D_POSITION",  math.max(0, p - delta))
        xfu.set_item_soffs(item,                    math.max(0, s - delta))
        SetMediaItemInfo_Value(item, "D_LENGTH",    l + delta)
        SetMediaItemInfo_Value(item, "D_FADEINLEN",      TARGET)
        SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", TARGET)
        SetMediaItemInfo_Value(item, "C_FADEINSHAPE",    1)
    end

    xfu.set_xfade_state(ctx.folder_track, ctx.end1 - TARGET / 2)

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("XFM Reset", -1)
    say("Crossfade reset to 35ms equal power")
end

---------------------------------------------------------------------

main()
