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
local xfu = require("ReaClassical_XFM_Utils")
local iu = require("ReaClassical_Item_Utils")
local rank_info = require("ReaClassical_Rank_Info")

local LABELS = {
    left  = "Left item selected",
    right = "Right item selected",
    both  = "Both items selected",
}

local function main()
    if not xfu.is_xfade_mode() then return end
    local sel = xfu.get_selection()
    local ctx = xfu.get_xfade_context()

    if not ctx then
        say(LABELS[sel] or LABELS.both)
        return
    end

    local msg = LABELS[sel] or LABELS.both
    if sel == "left" then
        msg = msg .. ", " .. iu.item_label(ctx.item1, rank_info)
    elseif sel == "right" then
        msg = msg .. ", " .. iu.item_label(ctx.item2, rank_info)
    else
        msg = msg .. ", " .. iu.item_label(ctx.item1, rank_info)
            .. " and " .. iu.item_label(ctx.item2, rank_info)
    end
    say(msg)
end

main()
