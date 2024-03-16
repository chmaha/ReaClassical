--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

local main, folder_check

---------------------------------------------------------------------

function main()
  Undo_BeginBlock()
  local is_parent
  local count = 0
  local num_of_selected = CountSelectedTracks(0)
  for i = 0, num_of_selected - 1, 1 do
      local track = GetSelectedTrack(0,i)
      if track then
          is_parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
          if is_parent == 1 then
              count = count + 1
          end
      end
  end
  
  if count ~= 1 then
      ShowMessageBox("Please select one parent track before running", "Record-Arm Folder", 0)
      return
  end
  
  local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
  Main_OnCommand(select_children, 0) -- SWS: Select children of selected folder track(s)
  
  Main_OnCommand(40491, 0)         -- Track: Unarm all tracks for recording
  local arm = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED")
  Main_OnCommand(arm, 0)           -- Xenakios/SWS: Set selected tracks record armed
  local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
  Main_OnCommand(unselect_children, 0) -- SWS: Unselect children of selected folder track(s)
  Undo_EndBlock('Record-Arm Folder', 0)
end



main()
