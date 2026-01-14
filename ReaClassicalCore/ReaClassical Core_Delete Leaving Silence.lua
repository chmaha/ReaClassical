--[[
@noindex

This file is a part of "ReaClassical Core" package.
See "ReaClassicalCore.lua" for more information.

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

local main, source_markers
local adaptive_delete, count_selected_media_items, get_selected_media_item_at
local select_items_containing_midpoint

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()

    local workflow = "Horizontal"
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
                MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.",
            "ReaClassical Error", 0)
        return
    end

    if source_markers() == 2 then
        SetCursorContext(1, nil)
        Main_OnCommand(40310, 0) -- Set ripple per-track
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        GoToMarker(0, 998, false)
        Main_OnCommand(40625, 0)  -- Time Selection: Set start point
        GoToMarker(0, 999, false)
        Main_OnCommand(40626, 0)  -- Time Selection: Set end point
        Main_OnCommand(40718, 0)  -- Select all items on selected tracks in current time selection
        select_items_containing_midpoint()
        Main_OnCommand(41990, 0)  -- Toggle ripple per-track (off)
        adaptive_delete()
        Main_OnCommand(40630, 0)  -- Go to start of time selection
        Main_OnCommand(40020, 0)  -- Time Selection: Remove time selection and loop point selection
        DeleteProjectMarker(nil, 998, false)
        DeleteProjectMarker(nil, 999, false)
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(41990, 0) -- Toggle ripple per-track (on)
    else
        MB("Please use SOURCE-IN and SOURCE-OUT markers", "Delete Leaving Silence", 0)
    end
    Undo_EndBlock('Cut and Ripple', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function source_markers()
    local _, num_markers, num_regions = CountProjectMarkers(0)
    local exists = 0
    for i = 0, num_markers + num_regions - 1, 1 do
        local _, _, _, _, label, _ = EnumProjectMarkers(i)
        if string.match(label, "SOURCE[-]IN") or string.match(label, "SOURCE[-]OUT") then
            exists = exists + 1
        end
    end
    return exists
end

---------------------------------------------------------------------

function adaptive_delete()
  local sel_items = {}
  local item_count = count_selected_media_items()
  for i = 0, item_count - 1 do
    sel_items[#sel_items+1] = get_selected_media_item_at(i)
  end

  local time_sel_start, time_sel_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
  local items_in_time_sel = {}

  if time_sel_end - time_sel_start > 0 then
    for _, item in ipairs(sel_items) do
      local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
      local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_sel = GetMediaItemInfo_Value(item, "B_UISEL") == 1

      if item_sel then
        local intersectmatches = 0
        -- conditions copied from original C++ logic
        if time_sel_start >= item_pos and time_sel_end <= item_pos + item_len then
          intersectmatches = intersectmatches + 1
        end
        if item_pos >= time_sel_start and item_pos + item_len <= time_sel_end then
          intersectmatches = intersectmatches + 1
        end
        if time_sel_start <= item_pos + item_len and time_sel_end >= item_pos + item_len then
          intersectmatches = intersectmatches + 1
        end
        if time_sel_end >= item_pos and time_sel_start < item_pos then
          intersectmatches = intersectmatches + 1
        end

        if intersectmatches > 0 then
          table.insert(items_in_time_sel, item)
        end
      end
    end
  end

  if #items_in_time_sel > 0 then
    Main_OnCommand(40312, 0) -- Delete items in time selection
  else
    Main_OnCommand(40006, 0) -- Delete items or time selection contents
  end
end

---------------------------------------------------------------------

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            selected_count = selected_count + 1
        end
    end

    return selected_count
end

---------------------------------------------------------------------

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

---------------------------------------------------------------------

function select_items_containing_midpoint()
    local num_sel = CountSelectedMediaItems(0)
    if num_sel == 0 then return end

    -- Collect selected items' midpoints
    local positions_to_check = {}
    for i = 0, num_sel - 1 do
        local item = GetSelectedMediaItem(0, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local mid = pos + (len / 2)
        table.insert(positions_to_check, mid)
    end

    local tolerance = 0.0001
    local num_items = CountMediaItems(0)

    -- For each midpoint position, select all items that contain it
    for _, check_pos in ipairs(positions_to_check) do
        for i = 0, num_items - 1 do
            local item = GetMediaItem(0, i)
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_end = item_pos + item_len

            -- Select if this item's span contains the check position
            if check_pos >= (item_pos - tolerance) and check_pos <= (item_end + tolerance) then
                SetMediaItemSelected(item, true)
            end
        end
    end
end

---------------------------------------------------------------------

main()
