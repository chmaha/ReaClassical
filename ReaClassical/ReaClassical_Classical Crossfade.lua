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

local main, return_xfade_length, is_cursor_between_items
local get_selected_media_item_at, count_selected_media_items
local select_item_under_cursor_on_selected_track
local select_midpoint_peers
---------------------------------------------------------------------

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
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end
    local correct_cursor_position = is_cursor_between_items()
    if not correct_cursor_position then
        MB("Ensure the parent items on the parent track overlap and that the edit cursor " ..
            "is positioned somewhere within the overlap.",
            "Classical Crossfade", 0)
        return
    end
    local xfade_len = return_xfade_length()
    local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
    local state = GetToggleCommandState(fade_editor_toggle)
    select_item_under_cursor_on_selected_track()
    Main_OnCommand(40297, 0)        -- Track: Unselect (clear selection of) all tracks

    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(40625, 0) -- Time selection: Set start point

    MoveEditCursor(xfade_len, false)
    Main_OnCommand(40626, 0) -- Time selection: Set end point
    Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection
    Main_OnCommand(40635, 0) -- Time selection: Remove time selection

    local selected_items = count_selected_media_items()
    if selected_items > 0 and (state == -1 or state == 0) then
        local item = get_selected_media_item_at(0)
        Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
        SetMediaItemSelected(item, 1)
    end

    if state == 1 then
        local _, item1_orig_pos = GetProjExtState(0, "ReaClassical", "FirstItemPos")
        local _, item1_orig_offset = GetProjExtState(0, "ReaClassical", "FirstItemOffset")
        local item1 = get_selected_media_item_at(0)
        local item1_take = GetActiveTake(item1)
        local item1_new_offset = GetMediaItemTakeInfo_Value(item1_take, "D_STARTOFFS")
        local offset_amount = item1_new_offset - item1_orig_offset
        if item1_orig_pos ~= "" then
            local item1_new_pos = GetMediaItemInfo_Value(item1, "D_POSITION")
            local move_amount = item1_new_pos - item1_orig_pos
            local item_count = CountMediaItems(0)
            if move_amount > 0 then
                for i = 0, item_count - 1 do
                    local item = GetMediaItem(0, i)
                    local item_start_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                    local item_locked = GetMediaItemInfo_Value(item, "C_LOCK") -- Get the lock state

                    if item_locked == 0 then
                        local corrected_pos = item_start_pos - move_amount
                        SetMediaItemInfo_Value(item, "D_POSITION", corrected_pos)
                    end
                end
            elseif move_amount < 0 then
                for i = item_count - 1, 0, -1 do
                    local item = GetMediaItem(0, i)
                    local item_start_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                    local item_locked = GetMediaItemInfo_Value(item, "C_LOCK") -- Get the lock state

                    if item_locked == 0 then
                        local corrected_pos = item_start_pos - move_amount
                        SetMediaItemInfo_Value(item, "D_POSITION", corrected_pos)
                    end
                end
            end
            MoveEditCursor(-move_amount, false)
        end
        if item1_orig_offset ~= "" and math.abs(offset_amount) > 1e-10 then
            Main_OnCommand(40289, 0)                     -- unselect all items
            SetMediaItemSelected(item1, true)
            select_midpoint_peers()
            local num_items = count_selected_media_items() -- Get the number of selected items
            for i = 0, num_items - 1 do
                local item = get_selected_media_item_at(i)  -- Get the selected media item
                local take = GetActiveTake(item)
                if take then
                    local item_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")          -- Get the active take
                    SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", item_offset - offset_amount) -- Set the offset
                end
            end
            Main_OnCommand(40289, 0) -- unselect all items
            SetMediaItemSelected(item1, true)
        end
        if math.abs(offset_amount) > 1e-10 then
            MB(
                "WARNING: The left item of the crossfade was accidentally slip-edited.\n" ..
                "The item's position and offset have been reset to original values but " ..
                "the current crossfade may need attention.",
                "Crossfade Editor", 0)
        end
    end


    Undo_EndBlock('Classical Crossfade', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
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

function is_cursor_between_items()
    local track = GetSelectedTrack(0, 0)
    if not track or IsTrackSelected(track) == false then return false end

    local item_count = CountTrackMediaItems(track)
    if item_count < 2 then return false end

    local cursor_pos = GetCursorPosition()
    local left_item, right_item = nil, nil

    -- Find the left item
    for i = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, i)
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")

        if item_start <= cursor_pos and cursor_pos < item_end then
            left_item = item
            right_item = GetTrackMediaItem(track, i + 1) -- Get the next item if it exists
            break
        end
    end

    if not left_item or not right_item then return false end

    local left_item_end = GetMediaItemInfo_Value(left_item, "D_POSITION") +
        GetMediaItemInfo_Value(left_item, "D_LENGTH")
    local right_item_start = GetMediaItemInfo_Value(right_item, "D_POSITION")

    return cursor_pos >= right_item_start and cursor_pos <= left_item_end
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

function select_midpoint_peers()
    local sel_track = GetSelectedTrack(0, 0)
    if not sel_track then return end
    local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local folder_start, folder_end = nil, nil
    local start_search = track_num
    if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
    for t = start_search, num_tracks - 1 do
        local tt = GetTrack(0, t)
        if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    if not folder_start then return end
    local seed_items = {}
    local num_sel = CountSelectedMediaItems(0)
    for i = 0, num_sel - 1 do
        seed_items[#seed_items + 1] = GetSelectedMediaItem(0, i)
    end
    for _, ref_item in ipairs(seed_items) do
        local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
        local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
        local mid = pos + len * 0.5
        local tolerance = 0.0001
        for t = folder_start, folder_end do
            local track = GetTrack(0, t)
            local n = CountTrackMediaItems(track)
            for i = 0, n - 1 do
                local item = GetTrackMediaItem(track, i)
                local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
                local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
                if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                    SetMediaItemSelected(item, true)
                end
            end
        end
    end
end

---------------------------------------------------------------------

main()
