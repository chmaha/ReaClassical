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
local track_count = r.CountTracks(0)
local folder_check

function main()
  folders = folder_check()
  if folders == 0 then
    r.ShowMessageBox("Please use either the 'Create folder' or 'Create Source Groups' script first!","Add Aux/Submix track",0)
    return
  end
  r.Undo_BeginBlock()
  r.Main_OnCommand(40702,0) -- Add track to end of tracklist
  track = r.GetSelectedTrack(0, 0)
  native_color = r.ColorToNative(76,145,101)
  r.SetTrackColor(track, native_color)
  r.GetSetMediaTrackInfo_String(track, "P_NAME", "@", true) -- Add @ as track name
  r.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
  r.Main_OnCommand(40297,0)
  local home = r.NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
  r.Main_OnCommand(home,0)
  r.Undo_EndBlock("Add Aux/Submix track",0)
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

main()
