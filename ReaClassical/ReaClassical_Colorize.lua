--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local main

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    PreventUIRefresh(1)

    Main_OnCommand(40034, 0) -- select all in group
    Main_OnCommand(40704, 0) -- set to custom color

    -- loop through selected items and set P_EXT:ranked="y" if on a folder track
    local sel_count = CountSelectedMediaItems(0)
    for i = 0, sel_count - 1 do
        local item = GetSelectedMediaItem(0, i)
        local track = GetMediaItemTrack(item)
        if track then
            local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if folder_depth > 0 then
                GetSetMediaItemInfo_String(item, "P_EXT:ranked", "y", true)
            end
        end
    end

    Main_OnCommand(40769, 0) -- unselect all items

    PreventUIRefresh(-1)
    Undo_EndBlock("ReaClassical Colorize + Mark Folder Items Ranked", 0)
end

---------------------------------------------------------------------

main()
