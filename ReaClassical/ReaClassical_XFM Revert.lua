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

-- Revert the current xfade to the state captured when it was first edited
-- this session. Ripples downstream items by the change in item2's right edge.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

---------------------------------------------------------------------

local function main()
    if not xfu.is_xfade_mode() then return end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    local ok, err = xfu.revert_xfade_snapshot()

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)

    if ok then
        Undo_EndBlock("XFM Revert", -1)
        say("Crossfade reverted")
    else
        Undo_EndBlock("", -1)
        say(err or "Revert failed")
    end
end

---------------------------------------------------------------------

main()
