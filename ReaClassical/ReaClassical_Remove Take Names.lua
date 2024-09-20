--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, clean_take_names

---------------------------------------------------------------------


function main()
    Undo_BeginBlock()

    local response = ShowMessageBox(
    "Are you sure you would like to remove item take names from the first destination track?", "Remove Take Names", 4)
    if response == 6 then clean_take_names() end

    Undo_EndBlock('Remove Take Names', 0)
end

---------------------------------------------------------------------

function clean_take_names()
    local first_dest_track = GetTrack(0, 0)

    if not first_dest_track then
        ShowMessageBox("No tracks found! First set up a ReaClassical project via F7 or F8.", "Error", 0)
        return
    end

    local num_of_items = CountTrackMediaItems(first_dest_track)

    if num_of_items == 0 then
        ShowMessageBox("No items found on the first track", "Error", 0)
        return
    end

    for i = 0, num_of_items - 1 do
        local item = GetTrackMediaItem(first_dest_track, i)
        local take = GetActiveTake(item)
        if take then
            GetSetMediaItemTakeInfo_String(take, "P_NAME", "", true)
        end
    end
end

---------------------------------------------------------------------

main()
