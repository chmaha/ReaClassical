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

local main, source_markers, dest_check, adaptive_delete
local ripple_lock_mode, return_xfade_length, xfade
local select_item_under_cursor_on_selected_track

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    local first_group = dest_check()
    if not first_group then
        MB("Delete with ripple can only be run on the destination folder.", "ReaClassical Error", 0)
        return
    end

    Main_OnCommand(40927, 0) -- Options: Enable auto-crossfade on split
    Main_OnCommand(41121, 0) -- Options: Disable trim content behind media items when editing
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end
    if source_markers() == 2 then
        ripple_lock_mode()
        SetCursorContext(1, nil)
        GoToMarker(0, 998, false)
        local source_in_pos = GetCursorPosition()
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40625, 0) -- Time Selection: Set start point
        GoToMarker(0, 999, false)
        Main_OnCommand(40626, 0) -- Time Selection: Set end point
        Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
        Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
        local folder = GetSelectedTrack(0, 0)
        if not folder or GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER") ~= 1 then
            return
        end
        if workflow == "Vertical" and GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER") == 1 then
            Main_OnCommand(40310, 0) -- Set ripple-per-track
        else
            Main_OnCommand(40311, 0) -- Set ripple-all-tracks
        end
        adaptive_delete()
        Main_OnCommand(40630, 0)  -- Go to start of time selection

        local xfade_len = return_xfade_length()
        SetEditCurPos(source_in_pos, false, false)
        MoveEditCursor(xfade_len, false)
        MoveEditCursor(-0.0001, false)
        select_item_under_cursor_on_selected_track()
        MoveEditCursor(-xfade_len * 2, false)
        Main_OnCommand(41305, 0)        -- Item edit: Trim left edge of item to edit cursor
        SetEditCurPos(source_in_pos, false, false)
        xfade(xfade_len)
        Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
        DeleteProjectMarker(NULL, 998, false)
        DeleteProjectMarker(NULL, 999, false)
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40310, 0) -- Ripple per-track
    else
        MB("Please use SOURCE-IN and SOURCE-OUT markers", "Delete With Ripple", 0)
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
        if string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT") then
            exists = exists + 1
        end
    end
    return exists
end

---------------------------------------------------------------------

function ripple_lock_mode()
    local _, original_ripple_lock_mode = get_config_var_string("ripplelockmode")
    original_ripple_lock_mode = tonumber(original_ripple_lock_mode)
    if original_ripple_lock_mode ~= 2 then
        SNM_SetIntConfigVar("ripplelockmode", 2)
    end
end

---------------------------------------------------------------------

function return_xfade_length()
    local xfade_len = 0.035
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[1] then xfade_len = table[1] / 1000 end
    end
    return xfade_len
end

---------------------------------------------------------------------

function xfade(xfade_len)
    select_item_under_cursor_on_selected_track()
    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(40625, 0)        -- Time selection: Set start point
    MoveEditCursor(xfade_len, false)
    Main_OnCommand(40626, 0)        -- Time selection: Set end point
    Main_OnCommand(40916, 0)        -- Item: Crossfade items within time selection
    Main_OnCommand(40635, 0)        -- Time selection: Remove time selection
    MoveEditCursor(0.001, false)
    select_item_under_cursor_on_selected_track()
    MoveEditCursor(-0.001, false)
end

---------------------------------------------------------------------

function dest_check()
    -- Get first selected item
    local item = GetSelectedMediaItem(0, 0)
    if not item then
        return
    end

    -- Find its track
    local track = GetMediaItem_Track(item)
    if not track then
        return
    end

    -- Walk upward to the topmost parent (folder) track
    local folder = track
    while GetParentTrack(folder) do
        folder = GetParentTrack(folder)
    end

    -- Check if that folder is the first track
    return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER") == 1
end

---------------------------------------------------------------------

function adaptive_delete()
  local sel_items = {}
  local item_count = CountSelectedMediaItems(0)
  for i = 0, item_count - 1 do
    sel_items[#sel_items+1] = GetSelectedMediaItem(0, i)
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

function select_item_under_cursor_on_selected_track()
  Main_OnCommand(40289, 0) -- Unselect all items

  local curpos = GetCursorPosition()
  local item_count = CountMediaItems(0)

  for i = 0, item_count - 1 do
    local item = GetMediaItem(0, i)
    local track = GetMediaItem_Track(item)
    local track_sel = IsTrackSelected(track)

    if track_sel then
      local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
      local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
      local item_end = item_pos + item_len

      if curpos >= item_pos and curpos <= item_end then
        SetMediaItemInfo_Value(item, "B_UISEL", 1) -- Select this item
      end
    end
  end
end

---------------------------------------------------------------------

main()
