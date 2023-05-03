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

for key in pairs(reaper) do _G[key] = reaper[key] end

function Main()
  Undo_BeginBlock()
  if CountSelectedMediaItems(0) == 0 then
    ShowMessageBox("Please select one media item before running the script.", "Error", 0)
    return
  elseif CountSelectedMediaItems(0) > 1 then
    ShowMessageBox("Please select a single media item before running the script.", "Error", 0)
    return
  end
  
  local item = GetSelectedMediaItem(0, 0)
  local item_track = GetMediaItemTrack(item)
  local track_number = GetMediaTrackInfo_Value(item_track, 'IP_TRACKNUMBER')
  local take = GetActiveTake(item)
  local source = GetMediaItemTake_Source(take)
  local num_channels = GetMediaSourceNumChannels(source)
    
  for i = 1, num_channels - 1 do
    local track = GetTrack(0, track_number - 1 + i)
    new_item = AddMediaItemToTrack(track)
    SetMediaItemInfo_Value(new_item, "D_POSITION", GetMediaItemInfo_Value(item, "D_POSITION"))
    SetMediaItemInfo_Value(new_item, "D_LENGTH", GetMediaItemInfo_Value(item, "D_LENGTH"))
    local new_take = AddTakeToMediaItem(new_item)
    SetMediaItemTake_Source(new_take, source)
    SetMediaItemTakeInfo_Value(new_take, "I_CHANMODE", 3)
    SetMediaItemTakeInfo_Value(new_take, "I_CHANMODE", 3 + i)
  end
  
  local int = ShowMessageBox("Do you want to treat the first two iso tracks as interleaved stereo?", "Multi-channel Explode", 4)
  if int == 6 then
    SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 67)
    local second_track = GetTrack(0, track_number)
    DeleteTrack(second_track)
  else
    InsertTrackAtIndex(track_number, true)
    local second_track = GetTrack(0, track_number)
    MoveMediaItemToTrack(item, second_track)
    SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 3)
    
  end
  Undo_EndBlock("Explode multi-channel audio",0)
end

Main()



