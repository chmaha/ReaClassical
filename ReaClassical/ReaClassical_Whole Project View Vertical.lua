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
local folder_check

function Main()
  r.Main_OnCommand(40296, 0) -- Track: Select all tracks
  folders = folder_check()
  local zoom = r.NamedCommandLookup("_SWS_VZOOMFIT")
  r.Main_OnCommand(zoom, 0) -- SWS: Vertical zoom to selected tracks
  r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
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

Main()
