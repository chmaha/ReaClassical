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
local iu = require("ReaClassical_Item_Utils")
local ieu = require("ReaClassical_IEM_Utils")

local function main()
    if not ieu.is_iem_mode() then return end

    local ctx = ieu.sync_context(iu)
    if not ctx then say("No item edit context"); return end

    if iu.right_edge_crossfaded(ctx.item) then
        say("Right edge is crossfaded; use crossfade mode instead")
        return
    end

    ieu.set_selection("out")
    say("Fade-out selected")
end

main()
