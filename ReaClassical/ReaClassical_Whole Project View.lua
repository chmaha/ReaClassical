--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022 chmaha

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

local r = reaper
r.PreventUIRefresh(1)
r.Undo_BeginBlock()

local _, zs = r.GetProjExtState(0, "Whole Project View", "Zoom Start")
local _, ze = r.GetProjExtState(0, "Whole Project View", "Zoom End")
zs = tonumber(string.format("%.3f", zs))
ze = tonumber(string.format("%.3f", ze))
local inits, inite = r.GetSet_ArrangeView2(0, false, 0, 0, 0, 0)
inits = tonumber(string.format("%.3f", inits))
inite = tonumber(string.format("%.3f", inite))

if inits == zs and inite == ze then
r.Main_OnCommand(40848, 0) -- restore previous zoom
else
r.Main_OnCommand(40182, 0) -- Select all items
r.Main_OnCommand(41622, 0) -- toggle zoom to items
local zooms, zoome = r.GetSet_ArrangeView2(0, false, 0, 0, 0, 0)
r.SetProjExtState(0, "Whole Project View", "Zoom Start", zooms)
r.SetProjExtState(0, "Whole Project View", "Zoom End", zoome)
r.Main_OnCommand(40769, 0) -- unselect items
end
r.Undo_EndBlock('Whole Project View', 0)
r.PreventUIRefresh(-1)
r.UpdateArrange()
r.UpdateTimeline()
