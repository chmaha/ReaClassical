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
local folder_check, get_track_number

function Main()
  local cur_pos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
  local track_number = math.floor(get_track_number())
  r.DeleteProjectMarker(NULL, 998, false)
  r.AddProjectMarker2(0, false, cur_pos, 0, track_number .. ":SOURCE-IN", 998, r.ColorToNative(23, 223, 143) | 0x1000000)
end

function folder_check()
  local folders = 0
  local total_tracks = r.CountTracks(0)
  for i = 0, total_tracks - 1, 1 do
    local track = r.GetTrack(0, i)
    if r.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
      folders = folders + 1
    end
  end
  return folders
end

function get_track_number()
  local selected = r.GetSelectedTrack(0, 0)
  if folder_check() == 0 or selected == nil then
    return 1
  elseif r.GetMediaTrackInfo_Value(selected, "I_FOLDERDEPTH") == 1 then
    return r.GetMediaTrackInfo_Value(selected, "IP_TRACKNUMBER")
  else
    local folder = r.GetParentTrack(selected)
    return r.GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
  end
end

Main()
