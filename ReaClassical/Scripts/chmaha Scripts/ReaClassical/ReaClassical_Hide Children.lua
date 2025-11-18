--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end
local main, collapse_folder

---------------------------------------------------------------------

function main()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
      MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
      return
  end
  local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
  mastering = (mastering ~= "" and tonumber(mastering)) or 0

  local selected_tracks = CountSelectedTracks(0)

  for i = 0, selected_tracks - 1 do
    local track = GetSelectedTrack(0, i)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local special = string.match(name, "^M:") or string.match(name, "^#") or string.match(name, "^@") or
        string.match(name, "^RoomTone") or string.match(name, "^REF") or string.match(name, "^RCMASTER")
    if mastering == 1 and special then
      Main_OnCommand(40889, 0) -- Envelope: Hide all envelopes for tracks
    else
      collapse_folder()
    end
  end
end

---------------------------------------------------------------------

function collapse_folder()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            local folderDepth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if folderDepth == 1 then -- folder start
                SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 2)
            end
        end
    end
end

---------------------------------------------------------------------

main()
