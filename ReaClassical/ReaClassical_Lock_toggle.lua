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
local lock_toggle = r.NamedCommandLookup("_RS63db9a9d1dae64f15f6ca0b179bb5ea0bc4d06f6")
local state = r.GetToggleCommandState(lock_toggle)
local lock_items, unlock_items

function Main()
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()
  local focus = r.NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
  r.Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
  if state == 0 or state == -1 then
    r.SetToggleCommandState(1, lock_toggle, 1)
    r.Main_OnCommand(40311, 0) -- Set ripple editing all tracks
    lock_items()
  else
    r.SetToggleCommandState(1, lock_toggle, 0)
    unlock_items()
    r.Main_OnCommand(40310, 0) -- Set ripple editing per-track
  end

  r.Undo_EndBlock('Lock Toggle', 0)
  r.PreventUIRefresh(-1)
  -- r.UpdateArrange()
  r.UpdateTimeline()
end

function lock_items()
  r.Main_OnCommand(40182, 0) -- select all items
  r.Main_OnCommand(40939, 0) -- select track 01
  local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2")
  r.Main_OnCommand(select_children, 0) -- select children of track 1
  local unselect_items = r.NamedCommandLookup("_SWS_UNSELONTRACKS")
  r.Main_OnCommand(unselect_items, 0) -- unselect items in first folder
  local total_items = r.CountSelectedMediaItems(0)
  for i = 0, total_items - 1, 1 do
    local item = r.GetSelectedMediaItem(0, i)
    r.SetMediaItemInfo_Value(item, "C_LOCK", 1)
  end
  r.Main_OnCommand(40289, 0) -- Item: Unselect all items
end

function unlock_items()
  local total_items = r.CountMediaItems(0)
  for i = 0, total_items - 1, 1 do
    local item = r.GetMediaItem(0, i)
    r.SetMediaItemInfo_Value(item, "C_LOCK", 0)
  end
  r.Main_OnCommand(40289, 0) -- Item: Unselect all items
  r.UpdateArrange()
end

Main()
