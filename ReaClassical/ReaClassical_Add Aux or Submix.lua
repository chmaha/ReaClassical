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
r.Undo_BeginBlock()
r.Main_OnCommand(41147,0) -- Add track to end of mixer
track = r.GetSelectedTrack(0, 0)
native_color = r.ColorToNative(76,145,101)
r.SetTrackColor(track, native_color)
r.GetSetMediaTrackInfo_String(track, "P_NAME", "@", true) -- Add @ as track name
r.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
r.Main_OnCommand(40297,0)
r.Undo_EndBlock("Add Aux/Submix track",0)
