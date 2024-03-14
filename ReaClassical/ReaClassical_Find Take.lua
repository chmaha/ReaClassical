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

local main

---------------------------------------------------------------------

function main()
    ::start::
    local retval, take_choice = GetUserInputs('Find Take', 1,'Take Number:','')
    if not retval or take_choice == "" then return end
    local found = false
    local num_of_items = CountMediaItems(0)
    for i=0, num_of_items -1, 1 do
        local item = GetMediaItem(0, i)
        local take = reaper.GetActiveTake(item)
        local src = reaper.GetMediaItemTake_Source(take)
        local filename = reaper.GetMediaSourceFileName(src, "")
        local take_capture = tonumber(filename:match(".*[^%d](%d+)%.%a+$"))
        local edit, _ = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", 0)
        if take_capture == tonumber(take_choice) and not edit then
            found = true
            local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
            SetEditCurPos(item_start, 1, 0)
            local center = NamedCommandLookup("_SWS_HSCROLL50")
            Main_OnCommand(center,0)
            break
        end
    end
    if not found then
        local response = ShowMessageBox("Take not found. Try again?", "Find Take", 4)
        if response == 6 then
        goto start
        end
    end
end

---------------------------------------------------------------------

main()
