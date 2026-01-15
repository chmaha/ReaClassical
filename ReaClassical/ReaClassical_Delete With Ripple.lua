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

local main, source_markers, dest_check, adaptive_delete
local ripple_lock_mode, return_xfade_length, xfade
local select_item_under_cursor_on_selected_track
local count_selected_media_items , get_selected_media_item_at
local select_items_containing_midpoint, get_folder_children, get_parent_folder

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
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
        select_items_containing_midpoint()
        local folder = GetSelectedTrack(0, 0)
        if not folder then
            return
        end
        if workflow == "Vertical" then
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
        select_items_containing_midpoint()
        MoveEditCursor(-xfade_len * 2, false)
        Main_OnCommand(41305, 0)        -- Item edit: Trim left edge of item to edit cursor
        SetEditCurPos(source_in_pos, false, false)
        xfade(xfade_len)
        Main_OnCommand(40020, 0) -- Time Selection: Remove time selection and loop point selection
        DeleteProjectMarker(nil, 998, false)
        DeleteProjectMarker(nil, 999, false)
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
    local item = get_selected_media_item_at(0)
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

    -- Get the folder tracks for all selected items
    local folder_tracks = {}
    for i = 0, num_sel - 1 do
        local item = GetSelectedMediaItem(0, i)
        local track = GetMediaItemTrack(item)
        local folder = get_parent_folder(track)
        if folder then
            folder_tracks[folder] = true
        end
    end

    -- Get all tracks within the relevant folders
    local tracks_to_check = {}
    for folder, _ in pairs(folder_tracks) do
        local children = get_folder_children(folder)
        tracks_to_check[folder] = true -- Include folder track itself
        for _, child in ipairs(children) do
            tracks_to_check[child] = true
        end
    end

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

    -- For each midpoint position, select items in folder that contain it
    for _, check_pos in ipairs(positions_to_check) do
        for track, _ in pairs(tracks_to_check) do
            local num_items = CountTrackMediaItems(track)
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)
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
end

---------------------------------------------------------------------

function get_parent_folder(track)
    -- Returns the parent folder track, or nil if track is not in a folder
    if not track then return nil end

    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

    -- Walk backwards to find parent folder
    for i = track_idx, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end

        local depth = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
        if depth == 1 then
            return t
        end
    end

    return nil
end

---------------------------------------------------------------------

function get_folder_children(parent_track)
    -- Returns all child tracks of a folder
    local children = {}
    if not parent_track then return children end

    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1

    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end

        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if depth > 0 then
            table.insert(children, tr)
        end

        depth = depth + folder_depth

        if depth <= 0 then break end

        idx = idx + 1
    end

    return children
end

---------------------------------------------------------------------

main()
