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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, lock_items, unlock_items

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local lock_toggle = NamedCommandLookup("_RS63db9a9d1dae64f15f6ca0b179bb5ea0bc4d06f6")
    local state = GetToggleCommandState(lock_toggle)
    local focus = NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
    Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
    if state == 0 or state == -1 then
        SetToggleCommandState(1, lock_toggle, 1)
        Main_OnCommand(40311, 0) -- Set ripple editing all tracks
        lock_items()
    else
        SetToggleCommandState(1, lock_toggle, 0)
        unlock_items()
        Main_OnCommand(40310, 0) -- Set ripple editing per-track
    end

    Undo_EndBlock('Lock Toggle', 0)
    PreventUIRefresh(-1)
    UpdateTimeline()
end

---------------------------------------------------------------------

function lock_items()
    Main_OnCommand(40182, 0)           -- select all items
    Main_OnCommand(40939, 0)           -- select track 01
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0) -- select children of track 1
    local unselect_items = NamedCommandLookup("_SWS_UNSELONTRACKS")
    Main_OnCommand(unselect_items, 0)  -- unselect items in first folder
    local total_items = CountSelectedMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetSelectedMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 1)
    end
    Main_OnCommand(40289, 0) -- Item: Unselect all items
end

---------------------------------------------------------------------

function unlock_items()
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 0)
    end
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    UpdateArrange()
end

---------------------------------------------------------------------

main()
