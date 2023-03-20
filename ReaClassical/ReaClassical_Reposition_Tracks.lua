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

function main()
  reaper.Undo_BeginBlock()
  local gap, choice
  local bool, gap = reaper.GetUserInputs('Reposition Tracks',1,"No. of seconds between items?",',')
  
  if not bool then
    return
  elseif gap == "" then
    choice = r.ShowMessageBox("Please enter a number!", "Reposition Tracks", 0)
    return
  else
    track_count = r.CountTracks(0)
    for i=0,track_count-1 do
      track = r.GetTrack(0,i)
      local track_items = {}
      local item_count = r.CountTrackMediaItems(track)
      for i=0, item_count - 1 do
        track_items[i] = r.GetTrackMediaItem(track, i)
      end
      local shift = 0;
      for i=1,item_count-1,1 do
        local prev_item = track_items[i-1]
        local PrevItemStart = r.GetMediaItemInfo_Value(prev_item, "D_POSITION")
        local prev_length = r.GetMediaItemInfo_Value(prev_item, "D_LENGTH") 
        local current_item = track_items[i]
        local CurrentItemStart = r.GetMediaItemInfo_Value(current_item, "D_POSITION")
        local take = r.GetActiveTake(current_item)
        local _, take_name = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        local NewPos = 0
        if take_name ~= "" then
          NewPos = PrevItemStart + prev_length + gap
          r.SetMediaItemInfo_Value(current_item, "D_POSITION", NewPos)
        else
          NewPos = CurrentItemStart + shift
          r.SetMediaItemInfo_Value(current_item, "D_POSITION", NewPos)
        end
        shift = NewPos - CurrentItemStart
      end
      if r.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == -1 then
        break
      end
    end
  end
  reaper.Undo_EndBlock("Reposition Tracks",0)
end

main()



