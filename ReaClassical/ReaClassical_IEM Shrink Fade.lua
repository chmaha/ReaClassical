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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local rank_info = require("ReaClassical_Rank_Info")
local iu = require("ReaClassical_Item_Utils")
local ieu = require("ReaClassical_IEM_Utils")

local function main()
    if not ieu.is_iem_mode() then return end

    local ctx = ieu.sync_context(iu)
    if not ctx then say("No item edit context"); return end

    if ctx.selection == "none" then
        say("No free fade edge; use gain controls instead")
        return
    end

    local crossfaded = ctx.selection == "in"
        and iu.left_edge_crossfaded(ctx.item)
        or  iu.right_edge_crossfaded(ctx.item)
    if crossfaded then
        say((ctx.selection == "in" and "Left" or "Right")
            .. " edge is crossfaded; use crossfade mode instead")
        return
    end

    local param      = ctx.selection == "in" and "D_FADEINLEN" or "D_FADEOUTLEN"
    local auto_param = param .. "_AUTO"
    local word       = ctx.selection == "in" and "fade in" or "fade out"

    local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
    local amt = (tonumber(stored) or 5) / 1000

    local new_len = math.max(0, GetMediaItemInfo_Value(ctx.item, param) - amt)

    Undo_BeginBlock()
    PreventUIRefresh(1)

    for _, peer in ipairs(ctx.peers) do
        SetMediaItemInfo_Value(peer, param,      new_len)
        SetMediaItemInfo_Value(peer, auto_param, new_len)
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("IEM Shrink Fade", -1)

    say(iu.item_label(ctx.item, rank_info) .. " " .. word .. " shrunk to "
        .. math.floor(new_len * 1000 + 0.5) .. " milliseconds")
end

main()
