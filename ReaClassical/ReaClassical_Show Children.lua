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
local main

---------------------------------------------------------------------

function main()
  local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
  local mastering
  if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    mastering = tonumber(table[6])
  end

  local selected_tracks = CountSelectedTracks(0)

  for i = 0, selected_tracks - 1 do
    local track = GetSelectedTrack(0, i)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local special = string.match(name, "^M:") or string.match(name, "^#") or string.match(name, "^@") or
    string.match(name, "^RoomTone") or string.match(name, "^RCMASTER")
    if mastering == 1 and special then
      Main_OnCommand(40888, 0) -- Envelope: Show all active envelopes for tracks
      local arm = NamedCommandLookup("_S&M_ARMALLENVS")
      Main_OnCommand(arm, 0)
    else
      local show = NamedCommandLookup("_SWS_FOLDSMALL")
      Main_OnCommand(show, 0)
    end
  end
end

---------------------------------------------------------------------

main()