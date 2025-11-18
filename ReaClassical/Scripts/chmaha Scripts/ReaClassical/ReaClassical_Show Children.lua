--[[
@noindex

This file is part of the "ReaClassical" package.
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

-- Expose all Reaper functions globally
for key in pairs(reaper) do _G[key] = reaper[key] end

local main, arm_all_active_envs, fold_small

---------------------------------------------------------------------

function main()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
    MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
    return
  end

  local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
  mastering = tonumber(mastering) or 0

  local selected_tracks_count = CountSelectedTracks(0)
  for i = 0, selected_tracks_count - 1 do
    local track = GetSelectedTrack(0, i)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

    local is_special_track = string.match(name, "^M:")
        or string.match(name, "^#")
        or string.match(name, "^@")
        or string.match(name, "^RoomTone")
        or string.match(name, "^RCMASTER")

    if mastering == 1 and is_special_track then
      Main_OnCommand(40888, 0) -- Show all active envelopes

      -- Iterate over all tracks including master track
      for j = -1, CountTracks(0) - 1 do
        local automation_track = (j == -1) and GetMasterTrack(0) or GetTrack(0, j)
        if GetMediaTrackInfo_Value(automation_track, "I_SELECTED") == 1 then
          arm_all_active_envs(automation_track)
        end
      end
    else
      -- Fold all tracks (non-mastering mode)
      fold_small()
    end
  end
end

---------------------------------------------------------------------

function arm_all_active_envs(track)
  local _, chunk = GetTrackStateChunk(track, "", false)

  -- Look for any envelope block with ACT 1 (active), then set ARM 1
  chunk = chunk:gsub("(<.-ENV.-\n.-ACT 1.-\n.-ARM )%d", function(prefix)
    return prefix .. "1"
  end)

  SetTrackStateChunk(track, chunk, false)
end

---------------------------------------------------------------------

function fold_small()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            local folderDepth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if folderDepth == 1 then -- folder start
                SetMediaTrackInfo_Value(track, "I_FOLDERCOMPACT", 1)
            end
        end
    end
end

---------------------------------------------------------------------

main()
