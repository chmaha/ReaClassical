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
local fade_editor_toggle = r.NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
local fade_editor_state = r.GetToggleCommandState(fade_editor_toggle)

function Main()
   r.PreventUIRefresh(1)
   r.Undo_BeginBlock()
   if fade_editor_state ~= 1 then
     r.ShowMessageBox('This ReaClassical script only works while in the fade editor (F)', "Edit Classical Crossfade", 0)
   end
   local item_one, item_two, color, prev_item, next_item, curpos, diff
   
   item_one = r.GetSelectedMediaItem(0, 0)
   item_two = r.GetSelectedMediaItem(0, 1)
  if not item_one and not item_two then
      r.ShowMessageBox("Please select at least one of the items involved in the crossfade", "Edit Classical Crossfade", 0)
      return
  elseif item_one and not item_two then
      color = r.GetMediaItemInfo_Value(item_one, "I_CUSTOMCOLOR")
      if color == 20967993 then
        item_two = item_one
        prev_item = r.NamedCommandLookup("_SWS_SELPREVITEM")
        r.Main_OnCommand(prev_item, 0)
        item_one = r.GetSelectedMediaItem(0, 0)
      else
        next_item = r.NamedCommandLookup("_SWS_SELNEXTITEM")
        r.Main_OnCommand(next_item, 0)
        item_two = r.GetSelectedMediaItem(0, 0)
      end
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
    
    if not item_hover and mouse_pos < two_pos then
      r.SetMediaItemInfo_Value(item_one, "C_LOCK", 0) --unlock item 1
      r.SetEditCurPos(mouse_pos, false, false)
      curpos = r.GetCursorPosition()
      r.SetMediaItemSelected(item_two, true)
      r.Main_OnCommand(41305,0) -- extend item left
      r.SetMediaItemSelected(item_two, false)
      r.SetMediaItemSelected(item_one, true)
      diff = end_of_one - curpos
      r.SetEditCurPos(end_of_one + diff, false, false)
      r.Main_OnCommand(41991,0) -- toggle ripple-all OFF
      r.Main_OnCommand(41311,0) -- extend item right
      r.Main_OnCommand(41991,0) -- toggle ripple-all ON
      r.SetMediaItemInfo_Value(item_one, "C_LOCK", 1) --lock item 1
    elseif not item_hover and mouse_pos > two_pos then
      r.SetMediaItemInfo_Value(item_one, "C_LOCK", 0) --unlock item 1
      r.SetEditCurPos(mouse_pos, false, false)
      curpos = r.GetCursorPosition()
      r.SetMediaItemSelected(item_one, true)
      r.Main_OnCommand(41991,0) -- toggle ripple-all OFF
      r.Main_OnCommand(41311,0) -- extend item right
      r.SetMediaItemSelected(item_one, false)
      r.SetMediaItemInfo_Value(item_one, "C_LOCK", 1) --lock item 1
      r.SetMediaItemSelected(item_two, true)
      one_length = r.GetMediaItemInfo_Value(item_one, "D_LENGTH")
      end_of_one = one_pos + one_length
      diff = end_of_one - two_pos
      r.SetEditCurPos(two_pos - diff, false, false)
      r.Main_OnCommand(41305,0) -- extend item left
      r.Main_OnCommand(41991,0) -- toggle ripple-all ON
    end
    
    r.SetMediaItemSelected(item_one, false)
    r.SetMediaItemSelected(item_two, false)
    two_pos = r.GetMediaItemInfo_Value(item_two, "D_POSITION")
    one_length = r.GetMediaItemInfo_Value(item_one, "D_LENGTH")
    local one_end = one_pos + one_length
    r.SetEditCurPos(two_pos + ((one_end - two_pos)/2), false, false)
    r.Undo_EndBlock('Edit Classical Crossfade', 0)
    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.UpdateTimeline()
end

Main()
