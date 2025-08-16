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
local main, zoom_out_to_all_items

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    zoom_out_to_all_items()
    Undo_EndBlock('Zoom out project', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function zoom_out_to_all_items()
    -- Save current item selection
    local sel_items = {}
    local sel_count = reaper.CountSelectedMediaItems(0)
    for i = 0, sel_count - 1 do
        sel_items[#sel_items + 1] = reaper.GetSelectedMediaItem(0, i)
    end

    Main_OnCommand(40182, 0) -- Select all items in project
    Main_OnCommand(41622, 0) -- View: Zoom out project
    
    -- Restore original selection
    Main_OnCommand(40289, 0) -- Unselect all
    for _, item in ipairs(sel_items) do
        if ValidatePtr(item, "MediaItem*") then
            SetMediaItemSelected(item, true)
        end
    end
end

---------------------------------------------------------------------

main()

