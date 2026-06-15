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

local function main()
    local track = GetSelectedTrack(0, 0)
    if not track then return end

    local count = CountTrackMediaItems(track)
    if count == 0 then return end

    local item = GetTrackMediaItem(track, count - 1)
    local pos  = GetMediaItemInfo_Value(item, "D_POSITION")

    Main_OnCommand(40289, 0) -- Item: Unselect all items
    SetMediaItemSelected(item, true)
    SetEditCurPos(pos, true, true)
    UpdateArrange()
end

main()
