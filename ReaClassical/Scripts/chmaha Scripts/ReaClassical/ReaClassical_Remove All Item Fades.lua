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
local main, item_edge_overlaps

---------------------------------------------------------------------

function main()
  PreventUIRefresh(1)
  Undo_BeginBlock()
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if workflow == "" then
    MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
    return
  end

  local item_count = CountMediaItems(0)

  for i = 0, item_count - 1 do
    local item = GetMediaItem(0, i)
    local overlap_start = item_edge_overlaps(item, true)
    local overlap_end = item_edge_overlaps(item, false)

    -- Remove fade-in if start edge not overlapped
    if not overlap_start then
      SetMediaItemInfo_Value(item, "D_FADEINLEN", 0)
      SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", 0)
    end

    -- Remove fade-out if end edge not overlapped
    if not overlap_end then
      SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0)
      SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", 0)
    end
  end

  Undo_EndBlock('Remove Non-Overlapping Item Fades', 0)
  PreventUIRefresh(-1)
  UpdateArrange()
  UpdateTimeline()
end

---------------------------------------------------------------------

function item_edge_overlaps(item, check_start)
  local track = GetMediaItem_Track(item)
  local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_start + item_len
  local item_count = CountTrackMediaItems(track)

  for j = 0, item_count - 1 do
    local other = GetTrackMediaItem(track, j)
    if other ~= item then
      local other_start = GetMediaItemInfo_Value(other, "D_POSITION")
      local other_len = GetMediaItemInfo_Value(other, "D_LENGTH")
      local other_end = other_start + other_len

      -- Check overlap at start or end
      if check_start then
        if other_start < item_start and other_end > item_start then
          return true -- overlap at start edge
        end
      else
        if other_start < item_end and other_end > item_end then
          return true -- overlap at end edge
        end
      end
    end
  end
  return false
end

---------------------------------------------------------------------

main()
