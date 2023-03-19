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
local solo, mixer, on_stop, bus_check
local fade_editor_toggle = r.NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
local fade_editor_state = r.GetToggleCommandState(fade_editor_toggle)

function Main()
  r.PreventUIRefresh(1)
  r.Undo_BeginBlock()
  if fade_editor_state ~= 1 then
    local track, context, pos = r.BR_TrackAtMouseCursor()
    if track then
      r.SetOnlyTrackSelected(track)
      solo()
      local select_children = r.NamedCommandLookup("_SWS_SELCHILDREN2") -- SWS: Select children of selected folder track(s)
      r.Main_OnCommand(select_children, 0)
      mixer()
      local unselect_children = r.NamedCommandLookup("_SWS_UNSELCHILDREN")
      r.Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
      r.SetEditCurPos(pos, 0, 0)
      r.OnPlayButton()
      r.Undo_EndBlock('Audition', 0)
      r.PreventUIRefresh(-1)
      r.UpdateArrange()
      r.UpdateTimeline()
      r.TrackList_AdjustWindows(false)
    end
  else
    r.DeleteProjectMarker(NULL, 1000, false)
    local item_one = r.GetSelectedMediaItem(0, 0)
    local item_two = r.GetSelectedMediaItem(0, 1)
    if item_one == nil or item_two == nil then
      r.ShowMessageBox("Please select both items involved in the crossfade", "Crossfade Audition", 0)
      return
    end
    local one_pos = r.GetMediaItemInfo_Value(item_one, "D_POSITION")
    local one_length = r.GetMediaItemInfo_Value(item_one, "D_LENGTH")
    local two_pos = r.GetMediaItemInfo_Value(item_two, "D_POSITION")
    r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
    r.BR_GetMouseCursorContext()
    local mouse_pos = r.BR_GetMouseCursorContext_Position()
    local item_hover = r.BR_GetMouseCursorContext_Item()
    local end_of_one = one_pos + one_length
    local overlap = end_of_one - two_pos
    local mouse_to_item_two = two_pos - mouse_pos
    local total_time = 2 * mouse_to_item_two + overlap
    if item_hover == item_one then
      local item_pos = r.GetMediaItemInfo_Value(item_one, "D_POSITION")
      local item_length = r.GetMediaItemInfo_Value(item_one, "D_LENGTH")
      r.SetMediaItemSelected(item_hover, true)
      r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
      r.Main_OnCommand(41559, 0) -- Item properties: Solo
      r.AddProjectMarker2(0, false, one_pos + item_length, 0, "!1016", 1000, r.ColorToNative(10, 10, 10) | 0x1000000)
      r.SetEditCurPos(mouse_pos, false, false)
      r.OnPlayButton() -- play until end of item_hover (one_pos + item_length)
    elseif item_hover == item_two then
      local item_pos = r.GetMediaItemInfo_Value(item_two, "D_POSITION")
      r.SetMediaItemSelected(item_hover, true)
      r.Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
      r.Main_OnCommand(41559, 0) -- Item properties: Solo
      r.SetEditCurPos(two_pos, false, false)
      r.AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1000, r.ColorToNative(10, 10, 10) | 0x1000000)
      r.OnPlayButton() -- play until mouse cursor
    elseif not item_hover and mouse_pos < two_pos then
      r.AddProjectMarker2(0, false, mouse_pos + total_time, 0, "!1016", 1000,
        r.ColorToNative(10, 10, 10) | 0x1000000)
      r.SetEditCurPos(mouse_pos, false, false)
      r.OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
    else
      local mouse_to_item_one = mouse_pos - end_of_one
      local total_time = 2 * mouse_to_item_one + overlap
      r.AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1000,
        r.ColorToNative(10, 10, 10) | 0x1000000)
      r.AddProjectMarker2(0, false, mouse_pos - total_time, 0, "START", 1001,
        r.ColorToNative(10, 10, 10) | 0x1000000)
      r.GoToMarker(0, 1001, false)
      r.OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
      r.DeleteProjectMarker(NULL, 1001, false)
    end
    r.SetMediaItemSelected(item_one, true)
    r.SetMediaItemSelected(item_two, true)
    r.SetEditCurPos(two_pos + (overlap / 2), false, false)
    on_stop()
    r.Undo_EndBlock('Audition', 0)
    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.UpdateTimeline()
    r.TrackList_AdjustWindows(false)
  end
end

function solo()
  local track = r.GetSelectedTrack(0, 0)
  r.SetMediaTrackInfo_Value(track, "I_SOLO", 2)

  for i = 0, r.CountTracks(0) - 1, 1 do
    track = r.GetTrack(0, i)
    if r.IsTrackSelected(track) == false then
      r.SetMediaTrackInfo_Value(track, "I_SOLO", 0)
      i = i + 1
    end
  end
end

function bus_check(track)
  _, trackname = r.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  return string.find(trackname, "^@")
end

function mixer()
  for i = 0, r.CountTracks(0) - 1, 1 do
    local track = r.GetTrack(0, i)
    if r.IsTrackSelected(track) or bus_check(track) then
      r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
    else
      r.SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
    end
  end
end

function on_stop()
  if r.GetPlayState() == 0 then
    r.DeleteProjectMarker(NULL, 1000, false)
    r.Main_OnCommand(41185, 0) -- Item properties: Unsolo all
    return
  else
    r.defer(on_stop)
  end
end

Main()
