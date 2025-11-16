--[[
@noindex

This file is a part of "ReaClassical Core" package.

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

local main, shift, item_group, prepare, empty_items_check
local get_selected_media_item_at, count_selected_media_items
local nudge_right, scroll_to_first_track
local select_item_under_cursor_on_selected_track
local select_children_of_selected_folders

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    local start_time, end_time = GetSet_ArrangeView2(0, false, 0, 0, 0, 0)
    local num_of_project_items = CountMediaItems(0)
    if num_of_project_items == 0 then
        MB("Please add your takes before running...", "Prepare Takes", 0)
        return
    end
    local empty_count = empty_items_check(num_of_project_items)
    if empty_count > 0 then
        MB("Error: Empty items found. Delete them to continue.", "Prepare Takes", 0)
        return
    end

    PreventUIRefresh(1)
    Undo_BeginBlock()

    for track_idx = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, track_idx)
        for item_idx = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, item_idx)
            SetMediaItemInfo_Value(item, "I_GROUPID", 0)
        end
    end

    Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points

    local first_item = GetMediaItem(0, 0)
    local position = GetMediaItemInfo_Value(first_item, "D_POSITION")
    if position == 0.0 then
        shift()
    end

    prepare()

    GetSet_ArrangeView2(0, true, 0, 0, start_time, end_time)
    SetEditCurPos(cur_pos, 0, 0)

    scroll_to_first_track()

    SetProjExtState(0, "ReaClassical Core", "RCCoreProject", "y")
    SetProjExtState(0, "ReaClassical Core", "PreparedTakes", "y")

    Main_OnCommand(40310, 0) -- set ripple-per-track

    MB("Project takes have been prepared! " ..
        "You can run again if you import or record more material..."
        , "ReaClassical Core", 0)

    Undo_EndBlock('ReaClassical Core Prepare Takes', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function shift()
    Main_OnCommand(40182, 0)       -- select all items
    nudge_right(1)
    Main_OnCommand(40289, 0)       -- unselect all items
end

---------------------------------------------------------------------

function item_group(string, group)
    if string == "horizontal" then
        Main_OnCommand(40296, 0) -- Track: Select all tracks
    else
        select_children_of_selected_folders()
    end

    local selected = get_selected_media_item_at(0)
    local start = GetMediaItemInfo_Value(selected, "D_POSITION")
    local length = GetMediaItemInfo_Value(selected, "D_LENGTH")
    SetEditCurPos(start + (length / 2), false, false) -- move to middle of item
    select_item_under_cursor_on_selected_track()

    local num_selected_items = count_selected_media_items()
    for i = 0, num_selected_items - 1 do
        local item = get_selected_media_item_at(i)
        if item then
            SetMediaItemInfo_Value(item, "I_GROUPID", group)
        end
    end
end

---------------------------------------------------------------------

function prepare()
    local length = GetProjectLength(0)
    local first_track = GetTrack(0, 0)
    local new_item = AddMediaItemToTrack(first_track)
    SetMediaItemPosition(new_item, length + 1, false)

    if first_track then
        SetOnlyTrackSelected(first_track) -- Select only the first track
    end
    SetEditCurPos(0, false, false)

    local workflow = "horizontal"
    local group = 1
    Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    repeat
        item_group(workflow, group)
        group = group + 1
        Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item
    until IsMediaItemSelected(new_item) == true

    DeleteTrackMediaItem(first_track, new_item)
    SelectAllMediaItems(0, false)
    Main_OnCommand(42579, 0) -- Track: Remove selected tracks from all track media/razor editing groups
    Main_OnCommand(42578, 0) -- Track: Create new track media/razor editing group from selected tracks
    Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    SetEditCurPos(0, false, false)
end

---------------------------------------------------------------------

function empty_items_check(num_of_items)
    local count = 0
    for i = 0, num_of_items - 1, 1 do
        local current_item = GetMediaItem(0, i)
        local take = GetActiveTake(current_item)
        if not take then
            count = count + 1
        end
    end
    return count
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

function nudge_right(nudgeSamples)
    -- get project sample rate using GetSetProjectInfo
    local sampleRate = GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)

    local nudgeAmount = nudgeSamples / sampleRate

    local numTracks = CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = GetTrack(0, i)
        local itemCount = CountTrackMediaItems(track)
        for j = 0, itemCount - 1 do
            local item = GetTrackMediaItem(track, j)
            if IsMediaItemSelected(item) then
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                SetMediaItemInfo_Value(item, "D_POSITION", pos + nudgeAmount)
            end
        end
    end
end

---------------------------------------------------------------------

function scroll_to_first_track()
  local track1 = GetTrack(0, 0)
  if not track1 then return end

  -- Save current selected tracks to restore later
  local saved_sel = {}
  local count_sel = CountSelectedTracks(0)
  for i = 0, count_sel - 1 do
    saved_sel[i+1] = GetSelectedTrack(0, i)
  end

  -- Select only Track 1
  Main_OnCommand(40297, 0) -- Unselect all tracks
  SetTrackSelected(track1, true)

  -- Scroll Track 1 into view (vertically)
  Main_OnCommand(40913, 0) -- "Track: Vertical scroll selected tracks into view"

  -- Restore previous selection
  Main_OnCommand(40297, 0) -- Unselect all tracks
  for i, tr in ipairs(saved_sel) do
    SetTrackSelected(tr, true)
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

function select_children_of_selected_folders()
  local track_count = CountTracks(0)

  for i = 0, track_count - 1 do
    local tr = GetTrack(0, i)
    if IsTrackSelected(tr) then
      local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
      if depth == 1 then -- folder parent
        local j = i + 1
        while j < track_count do
          local ch_tr = GetTrack(0, j)
          SetTrackSelected(ch_tr, true) -- select child track

          local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
          if ch_depth == -1 then
            break -- end of folder children
          end

          j = j + 1
        end
      end
    end
  end
end

---------------------------------------------------------------------

main()
