--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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
local move_to_item, deselect
local fadeStart, fadeEnd, zoom, view, lock_items, unlock_items, select_check
local lock_previous_items, save_color, paint, load_color, move_cur_to_mid
local fade_editor_toggle = r.NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
local xfade_state = r.GetToggleCommandState(fade_editor_toggle)
local win_state = r.GetToggleCommandState(41827)

function main()

  if win_state ~= 1 then
    move_to_item()
    deselect()
  else
    sel = fadeEnd()
    if sel == -1 then
      return
    end
    move_to_item()
    move_to_item()
    local check = select_check()
    move_cur_to_mid(check)
    lock_previous_items(check)
    fadeStart()
    r.UpdateArrange()
    r.UpdateTimeline()
  end
end

function move_to_item()
  r.Main_OnCommand(40416, 0) -- Select and move to prev item
  local item = r.GetSelectedMediaItem(0, 0)
  return item
end

function deselect()
  r.Main_OnCommand(40289, 0) -- deselect all items
end

function select_check()
  local item = r.GetSelectedMediaItem(0, 0)
  if item ~= nil then
    item_position = r.GetMediaItemInfo_Value(item, "D_POSITION")
    item_length = r.GetMediaItemInfo_Value(item, "D_LENGTH")
    item_end = item_position + item_length
  end
  local cursor_position = r.GetCursorPosition()
  return item
end

function exit_check()
  local item = r.GetSelectedMediaItem(0, 0)
  if item then
    color = r.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
    return item
  else
    return -1
  end
end

function lock_previous_items(item)
  local num = r.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER")
  local first_track = r.GetTrack(0, 0)
  for i = 0,num do
    item = r.GetTrackMediaItem(first_track, i)
    r.SetMediaItemInfo_Value(item, "C_LOCK", 1)
  end
end

function fadeStart()
  r.SetToggleCommandState(1, fade_editor_toggle, 1)
  item1 = r.GetSelectedMediaItem(0, 0)
  save_color("1",item1)
  paint(item1, 32648759)
  r.Main_OnCommand(40311, 0) -- Set ripple editing all tracks
  lock_items()
  r.Main_OnCommand(40289, 0) -- Item: Unselect all items
  r.RefreshToolbar2(1, fade_editor_toggle)
  local start_time, end_time = r.GetSet_ArrangeView2(0, false, 0, 0, 0, 0)
  r.SetProjExtState(0, "Classical Crossfade Editor", "start_time", start_time)
  r.SetProjExtState(0, "Classical Crossfade Editor", "end_time", end_time)
  local select_1 = r.NamedCommandLookup("_SWS_SEL1") -- SWS: Select only track 1
  r.Main_OnCommand(select_1, 0)
  r.Main_OnCommand(40319, 0) -- move edit cursor to end of item
  view()
  zoom()
  r.SetMediaItemSelected(item1, true)
  local select_next = r.NamedCommandLookup("_SWS_SELNEXTITEM2") -- SWS: Select next item, keeping current selection (across tracks)
  r.Main_OnCommand(select_next, 0)
  item2 = r.GetSelectedMediaItem(0, 1)
  save_color("2",item2)
  paint(item2, 20967993)
end

function fadeEnd()
  local item = exit_check()
  if item == -1 then
    r.ShowMessageBox("Please select the left or right item of the crossfade pair to move to another crossfade", "Crossfade Editor", 0)
    return -1
  end
  local color = r.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
  if color == 20967993 then -- if green
    local prev_item = r.NamedCommandLookup("_SWS_SELPREVITEM2")
    r.Main_OnCommand(prev_item, 0)
    item = r.GetSelectedMediaItem(0, 0)
  end
  local first_color = load_color("1", item)
  paint(item, first_color)
  local select_next_item = r.NamedCommandLookup("_SWS_SELNEXTITEM2")
  r.Main_OnCommand(select_next_item,0)
  item2 = r.GetSelectedMediaItem(0, 1)
  second_color = load_color("2", item2)
  paint(item2, second_color)
  r.SetToggleCommandState(1, fade_editor_toggle, 0)
  r.RefreshToolbar2(1, fade_editor_toggle)
  unlock_items()
  move_cur_to_mid(item)
  r.Main_OnCommand(40289, 0) -- Item: Unselect all items
  r.SetMediaItemSelected(item, 1)
  view()
  --local selected_items = r.CountSelectedMediaItems(0)
  --if selected_items > 0 then
  --  local item = r.GetSelectedMediaItem(0, 0)
  --  r.Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
  --  r.SetMediaItemSelected(item, 1)
  --end
  local _,start_time = r.GetProjExtState(0, "Classical Crossfade Editor", "start_time")
  local _,end_time = r.GetProjExtState(0, "Classical Crossfade Editor", "end_time")
  r.GetSet_ArrangeView2(0, true, 0, 0, start_time, end_time)
  r.Main_OnCommand(40310, 0) -- Set ripple editing per-track
  return 1
end

function zoom()
  local cur_pos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
  reaper.SetEditCurPos(cur_pos - 3, false, false)
  r.Main_OnCommand(40625, 0) -- Time selection: Set start point
  reaper.SetEditCurPos(cur_pos + 3, false, false)
  r.Main_OnCommand(40626, 0) -- Time selection: Set end point
  local zoom = r.NamedCommandLookup("_SWS_ZOOMSIT")
  r.Main_OnCommand(zoom, 0) -- SWS: Zoom to selected items or time selection
  r.SetEditCurPos(cur_pos, false, false)
  r.Main_OnCommand(1012, 0) -- View: Zoom in horizontal
  r.Main_OnCommand(40635, 0) -- Time selection: Remove (unselect) time selection
end

function view()
  local track1 = r.NamedCommandLookup("_SWS_SEL1")
  local tog_state = r.GetToggleCommandState(fade_editor_toggle)
  --local win_state = r.GetToggleCommandState(41827)
  local overlap_state = r.GetToggleCommandState(40507)
  r.Main_OnCommand(track1, 0) -- select only track 1

  local max_height = r.GetToggleCommandState(40113)
  if max_height ~= tog_state then
    r.Main_OnCommand(40113, 0) -- View: Toggle track zoom to maximum height
  end

  if overlap_state ~= tog_state then
    r.Main_OnCommand(40507, 0) -- Options: Offset overlapping media items vertically
  end

  --if tog_state ~= win_state then
  --  r.Main_OnCommand(41827, 0) -- View: Show crossfade editor window
  --end

  local scroll_home = r.NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
  r.Main_OnCommand(scroll_home, 0) -- XENAKIOS_TVPAGEHOME
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
end

function unlock_items()
  local total_items = r.CountMediaItems(0)
  for i = 0, total_items - 1, 1 do
    local item = r.GetMediaItem(0, i)
    r.SetMediaItemInfo_Value(item, "C_LOCK", 0)
  end
end

function save_color(num,item)
  color = r.GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
  r.SetProjExtState(0, "Classical Crossfade Editor", "item" .. " " .. num .. " color", color) -- save to project file
end

function paint(item,color)
  r.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
end

function load_color(num,item)
  _, color = r.GetProjExtState(0, "Classical Crossfade Editor", "item" .. " " .. num .. " color")
  return color
end

function move_cur_to_mid(item)
  local pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  r.SetEditCurPos(pos+len/2, false, false)
end

main()
