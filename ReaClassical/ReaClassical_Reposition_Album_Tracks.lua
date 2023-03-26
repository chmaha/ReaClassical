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
local get_grouped_items, copy_shift, empty_items_check
local first_track = r.GetTrack(0, 0)
if first_track then NUM_OF_ITEMS = r.CountTrackMediaItems(first_track) end

function main()
  r.Undo_BeginBlock()
  if not first_track or NUM_OF_ITEMS == 0 then
    r.ShowMessageBox("Error: No media items found.","Reposition Album Tracks",0)
    return
  end
  local empty_count = empty_items_check()
  if empty_count > 0 then
    r.ShowMessageBox("Error: Empty items found on first track. Delete them to continue.","Reposition Tracks",0)
    return
  end
  
  local bool, gap = reaper.GetUserInputs('Reposition Tracks',1,"No. of seconds between items?",',')
  
  if not bool then
    return
  elseif gap == "" then
    r.ShowMessageBox("Please enter a number!", "Reposition Album Tracks", 0)
    return
  else
    track = r.GetTrack(0,0)
    local track_items = {}
    local item_count = r.CountTrackMediaItems(track)
    for i=0, item_count - 1 do
      track_items[i] = r.GetTrackMediaItem(track, i)
    end
    local shift = 0;
    local num_tracks = 0
    for i=1,item_count-1,1 do
      local prev_item = track_items[i-1]
      local PrevItemStart = r.GetMediaItemInfo_Value(prev_item, "D_POSITION")
      local prev_length = r.GetMediaItemInfo_Value(prev_item, "D_LENGTH") 
      local current_item = track_items[i]
      local CurrentItemStart = r.GetMediaItemInfo_Value(current_item, "D_POSITION")
      local take = r.GetActiveTake(current_item)
      local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      local NewPos = 0
      local grouped_items = get_grouped_items(current_item)
      if take_name ~= "" then
        NewPos = PrevItemStart + prev_length + gap
        r.SetMediaItemInfo_Value(current_item, "D_POSITION", NewPos)
        num_tracks = num_tracks + 1
      else
        NewPos = CurrentItemStart + shift
        r.SetMediaItemInfo_Value(current_item, "D_POSITION", NewPos)
      end
      shift = NewPos - CurrentItemStart
      copy_shift(grouped_items, shift)
    end
    if num_tracks == 0 then
      r.ShowMessageBox("No item take names found.", "Reposition Album Tracks", 0)
      return
    end
  end
  local create_cd_markers = reaper.NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")
  local _, run = r.GetProjExtState(0, "Create CD Markers", "Run?")
  if run == "yes" then r.Main_OnCommand(create_cd_markers, 0) end
  r.Undo_EndBlock("Reposition Tracks",0)
end

function get_grouped_items(item)
 r.Main_OnCommand(40289,0) -- unselect all items
 r.SetMediaItemSelected(item, true)
 r.Main_OnCommand(40034,0) -- Item grouping: Select all items in groups
 
 selected_item_count = r.CountSelectedMediaItems(0)
 
 selected_items = {}
 
 for i=1,selected_item_count - 1 do
   selected_items[i] = r.GetSelectedMediaItem(0, i)
 end
 return selected_items
end

function copy_shift(grouped_items, shift)
  
  for _,v in pairs(grouped_items) do
   local start = r.GetMediaItemInfo_Value(v, "D_POSITION")
   r.SetMediaItemInfo_Value(v, "D_POSITION", start + shift)
  end
  r.Main_OnCommand(40289,0) -- unselect all items
end

function empty_items_check()
  local count = 0
  for i = 0, NUM_OF_ITEMS - 1, 1 do
    local current_item = r.GetTrackMediaItem(first_track, i)
    local take = r.GetActiveTake(current_item)
    if not take then 
      count = count + 1 
    end 
  end
  return count
end

main()



