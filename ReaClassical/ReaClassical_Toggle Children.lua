--[[
@noindex

This file is a part of "ReaClassical" package.
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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, toggle_folders

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local spare_track = require("ReaClassical_Spare_Track")

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

  local shown, only_single_track = toggle_folders()
  if shown == nil then
    say(only_single_track and "Single-track folder, no children to show" or "No folder selected")
  elseif shown then
    say("Children shown")
  else
    say("Children hidden")
  end
end

function toggle_folders()
  local target
  local skipped_single_track = false
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1
        and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
        and spare_track.is_spare_folder(track) then
      skipped_single_track = true
    elseif GetMediaTrackInfo_Value(track, "I_SELECTED") == 1
        and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
      if target == nil then
        target = (GetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT") == 2) and 1 or 2
      end
      SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", target)
    end
  end
  if target == nil then return nil, skipped_single_track end
  return target == 1
end

main()
