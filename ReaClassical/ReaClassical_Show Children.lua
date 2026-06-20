--[[
@noindex

This file is part of the "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

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

-- Expose all Reaper functions globally
for key in pairs(reaper) do _G[key] = reaper[key] end

local main, fold_small

---------------------------------------------------------------------

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")

function main()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
      modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
    return
  end

  fold_small()
  say("Children shown")
end

---------------------------------------------------------------------

function fold_small()
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
      local folderDepth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
      if folderDepth == 1 then       -- folder start
        SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 1)
      end
    end
  end
end

---------------------------------------------------------------------

main()
