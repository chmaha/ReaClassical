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

local main, is_special_track, get_track_state, find_track_by_GUID, apply_track_state
local create_snapshot, serialize_table, deserialize_table, save_snapshots_to_project
local load_snapshots_from_project, copy_from_bank, clear_bank, switch_to_bank
local sort_snapshots, draw_table, draw_UI, handle_project_change
local get_selected_item_info, recall_snapshot, check_auto_recall
local find_snapshot_by_item_guid, get_item_by_guid, refresh_snapshot_items
local get_item_position, find_snapshot_with_gap_logic, find_snapshot_at_cursor
local get_display_name_from_guid, update_snapshot_names

local script_name = "Mixer Snapshot Manager"

-- Check for ReaImGui
if not ImGui_CreateContext then
  ShowMessageBox("ReaImGui is required for this script.\nPlease install it via ReaPack.", "Missing Dependency", 0)
  return
end

set_action_options(2)

package.path                  = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui                   = require 'imgui' '0.10'

-- Global state
local ctx                     = ImGui.CreateContext(script_name)
local snapshots               = {}
local selected_snapshot       = nil
local snapshot_counter        = 0
local current_bank            = "A"
local last_selected_item_guid = nil
local last_edit_cursor_pos    = -1
local last_play_pos           = -1
local is_playing              = false

-- UI state
local editing_row             = nil
local editing_column          = nil
local edit_buffer             = ""
local sort_mode               = 0   -- 0=timeline position, 1=name, 2=time
local sort_direction          = nil -- Will be set to ascending after context is created
local last_sort_mode          = 0
local last_sort_direction     = nil

-- Feature flags
local disable_auto_recall     = false
local switch_mid_gap          = true -- Switch snapshots in the middle of gaps

-- Track restriction per bank - REMOVED (now supports multiple tracks)
local bank_track_guid         = nil -- Deprecated but kept for backwards compatibility

-- Selective parameter recall flags (all enabled by default)
local recall_volume           = true
local recall_pan              = true
local recall_mute             = true
local recall_solo             = true
local recall_phase            = true
local recall_fx               = true
local recall_sends            = true
local recall_routing          = true

-- Column widths: #, Item Name, Date/Time, Notes, Delete
local col_widths              = { 35, 250, 140, 350, 60 }

local last_project

---------------------------------------------------------------------

function main()
  handle_project_change()
  update_snapshot_names() -- NEW: Check for name changes every frame
  check_auto_recall()
  local open = draw_UI()
  if open then defer(main) end
end

---------------------------------------------------------------------

function is_special_track(track)
  local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
  local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
  local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)

  return mixer_state == "y" or aux_state == "y" or submix_state == "y"
end

---------------------------------------------------------------------

function get_track_state(track)
  local state = {}
  state.volume = GetMediaTrackInfo_Value(track, "D_VOL")
  state.pan = GetMediaTrackInfo_Value(track, "D_PAN")
  state.mute = GetMediaTrackInfo_Value(track, "B_MUTE")
  state.solo = GetMediaTrackInfo_Value(track, "I_SOLO")
  state.phase = GetMediaTrackInfo_Value(track, "B_PHASE")
  state.guid = GetTrackGUID(track)

  state.fx_chain = {}
  local fx_count = TrackFX_GetCount(track)
  for i = 0, fx_count - 1 do
    local fx = {}
    fx.enabled = TrackFX_GetEnabled(track, i)
    fx.name = select(2, TrackFX_GetFXName(track, i, ""))
    fx.params = {}
    local param_count = TrackFX_GetNumParams(track, i)
    for p = 0, param_count - 1 do
      fx.params[p] = TrackFX_GetParam(track, i, p)
    end
    state.fx_chain[i] = fx
  end

  state.sends = {}
  local send_count = GetTrackNumSends(track, 0)
  for i = 0, send_count - 1 do
    local send = {}
    send.volume = GetTrackSendInfo_Value(track, 0, i, "D_VOL")
    send.pan = GetTrackSendInfo_Value(track, 0, i, "D_PAN")
    send.mute = GetTrackSendInfo_Value(track, 0, i, "B_MUTE")
    send.dest_guid = GetTrackGUID(BR_GetMediaTrackSendInfo_Track(track, 0, i, 1))
    state.sends[i] = send
  end

  state.hw_outs = {}
  local hw_out_count = GetTrackNumSends(track, 1)
  for i = 0, hw_out_count - 1 do
    local hw_out = {}
    hw_out.volume = GetTrackSendInfo_Value(track, 1, i, "D_VOL")
    hw_out.pan = GetTrackSendInfo_Value(track, 1, i, "D_PAN")
    hw_out.mute = GetTrackSendInfo_Value(track, 1, i, "B_MUTE")
    hw_out.channel = GetTrackSendInfo_Value(track, 1, i, "I_DSTCHAN")
    state.hw_outs[i] = hw_out
  end

  return state
end

---------------------------------------------------------------------

function find_track_by_GUID(guid)
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if GetTrackGUID(track) == guid then
      return track
    end
  end
  return nil
end

---------------------------------------------------------------------

function apply_track_state(track, state)
  if not track then return end

  if recall_volume then SetMediaTrackInfo_Value(track, "D_VOL", state.volume) end
  if recall_pan then SetMediaTrackInfo_Value(track, "D_PAN", state.pan) end
  if recall_mute then SetMediaTrackInfo_Value(track, "B_MUTE", state.mute) end
  if recall_solo then SetMediaTrackInfo_Value(track, "I_SOLO", state.solo) end
  if recall_phase then SetMediaTrackInfo_Value(track, "B_PHASE", state.phase) end

  if recall_fx then
    for fx_idx, fx in pairs(state.fx_chain) do
      if TrackFX_GetCount(track) > fx_idx then
        TrackFX_SetEnabled(track, fx_idx, fx.enabled)
        for param_idx, value in pairs(fx.params) do
          TrackFX_SetParam(track, fx_idx, param_idx, value)
        end
      end
    end
  end

  if recall_sends then
    for send_idx, send in pairs(state.sends) do
      if GetTrackNumSends(track, 0) > send_idx then
        SetTrackSendInfo_Value(track, 0, send_idx, "D_VOL", send.volume)
        SetTrackSendInfo_Value(track, 0, send_idx, "D_PAN", send.pan)
        SetTrackSendInfo_Value(track, 0, send_idx, "B_MUTE", send.mute)
      end
    end
  end

  if recall_routing and state.sends then
    local current_send_count = GetTrackNumSends(track, 0)
    for i = current_send_count - 1, 0, -1 do
      RemoveTrackSend(track, 0, i)
    end

    local rcmaster_guid = nil
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
      local tr = GetTrack(0, i)
      local _, rcmaster_state = GetSetMediaTrackInfo_String(tr, "P_EXT:rcmaster", "", false)
      if rcmaster_state == "y" then
        rcmaster_guid = GetTrackGUID(tr)
        break
      end
    end

    local has_rcmaster_connection = false
    for _, send in pairs(state.sends) do
      local dest_track = find_track_by_GUID(send.dest_guid)
      if dest_track then
        local new_send_idx = CreateTrackSend(track, dest_track)
        if new_send_idx >= 0 then
          SetTrackSendInfo_Value(track, 0, new_send_idx, "D_VOL", send.volume)
          SetTrackSendInfo_Value(track, 0, new_send_idx, "D_PAN", send.pan)
          SetTrackSendInfo_Value(track, 0, new_send_idx, "B_MUTE", send.mute)
          if rcmaster_guid and send.dest_guid == rcmaster_guid then
            has_rcmaster_connection = true
          end
        end
      end
    end

    if is_special_track(track) then
      if has_rcmaster_connection then
        GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", true)
      else
        GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "y", true)
      end
    end

    if state.hw_outs then
      local hw_out_count = GetTrackNumSends(track, 1)
      for i = 0, math.min(hw_out_count - 1, #state.hw_outs) do
        if state.hw_outs[i] then
          SetTrackSendInfo_Value(track, 1, i, "D_VOL", state.hw_outs[i].volume)
          SetTrackSendInfo_Value(track, 1, i, "D_PAN", state.hw_outs[i].pan)
          SetTrackSendInfo_Value(track, 1, i, "D_MUTE", state.hw_outs[i].mute)
        end
      end
    end
  end
end

---------------------------------------------------------------------

-- NEW: Get selected item info (works with any item, named or unnamed)
function get_selected_item_info()
  local item = GetSelectedMediaItem(0, 0)
  if not item then return nil, nil, nil end

  local take = GetActiveTake(item)
  local name = ""
  if take then
    _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  end
  
  local item_guid = BR_GetMediaItemGUID(item)
  return item_guid, name
end

---------------------------------------------------------------------

function get_item_by_guid(guid)
  for i = 0, CountMediaItems(0) - 1 do
    local item = GetMediaItem(0, i)
    if BR_GetMediaItemGUID(item) == guid then
      return item
    end
  end
  return nil
end

---------------------------------------------------------------------

function get_item_position(item_guid)
  local item = get_item_by_guid(item_guid)
  if item then
    return GetMediaItemInfo_Value(item, "D_POSITION")
  end
  return math.huge -- Items that don't exist go to end
end

---------------------------------------------------------------------

-- NEW: Extract display name from GUID (first alphanumeric segment before first hyphen)
function get_display_name_from_guid(guid)
  if not guid then return "Unknown" end
  -- Remove opening brace if present, then get first segment before hyphen
  local cleaned = guid:gsub("^{", "")
  local first_segment = cleaned:match("^([^%-]+)")
  return "{" .. (first_segment or guid) .. "}"  -- Added curly braces around the return
end

---------------------------------------------------------------------

-- NEW: Update snapshot display names if item names have changed
function update_snapshot_names()
  local needs_save = false
  
  for _, snap in ipairs(snapshots) do
    local item = get_item_by_guid(snap.item_guid)
    if item then
      local take = GetActiveTake(item)
      local current_name = ""
      if take then
        _, current_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      end
      
      -- Update item_name if it has changed
      if snap.item_name ~= current_name then
        snap.item_name = current_name
        needs_save = true
      end
    end
  end
  
  if needs_save then
    save_snapshots_to_project()
  end
end

---------------------------------------------------------------------

function find_snapshot_with_gap_logic(cursor_pos)
  if not switch_mid_gap then
    return find_snapshot_at_cursor(cursor_pos)
  end

  -- Helper function to check if a track is within a folder (or is the folder itself)
  local function is_track_in_folder(track, folder_track)
    if track == folder_track then return true end
    
    -- Check if track is a child of the folder
    local folder_depth = GetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH")
    if folder_depth <= 0 then return false end -- Not a folder
    
    local folder_idx = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    
    if track_idx <= folder_idx then return false end -- Track is before folder
    
    -- Walk through tracks to see if this track is within the folder
    local depth = folder_depth
    for i = folder_idx + 1, track_idx do
      local t = GetTrack(0, i)
      local t_depth = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
      depth = depth + t_depth
      if i == track_idx then
        return depth > 0 -- Track is in folder if depth is still positive
      end
      if depth <= 0 then
        return false -- Folder ended before reaching our track
      end
    end
    return false
  end

  -- Build list of items WITH snapshots (for snapshot lookup)
  local snapshot_items = {}
  for i = 0, CountMediaItems(0) - 1 do
    local item = GetMediaItem(0, i)
    local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_guid = BR_GetMediaItemGUID(item)
    if find_snapshot_by_item_guid(item_guid) then
      table.insert(snapshot_items, { item = item, start = item_start, guid = item_guid })
    end
  end
  table.sort(snapshot_items, function(a, b) return a.start < b.start end)

  -- Find which snapshot folders are relevant (previous and next)
  local prev_snap_folder = nil
  local next_snap_folder = nil
  
  for i = #snapshot_items, 1, -1 do
    if snapshot_items[i].start <= cursor_pos then
      local prev_snap = find_snapshot_by_item_guid(snapshot_items[i].guid)
      local prev_item = get_item_by_guid(prev_snap.item_guid)
      if prev_item then
        prev_snap_folder = GetMediaItem_Track(prev_item)
      end
      break
    end
  end
  
  for _, snap_data in ipairs(snapshot_items) do
    if snap_data.start > cursor_pos then
      local next_snap = find_snapshot_by_item_guid(snap_data.guid)
      local next_item = get_item_by_guid(next_snap.item_guid)
      if next_item then
        next_snap_folder = GetMediaItem_Track(next_item)
      end
      break
    end
  end

  -- Check if cursor is on an item within the RELEVANT folders only
  local cursor_on_relevant_item = false
  for i = 0, CountMediaItems(0) - 1 do
    local item = GetMediaItem(0, i)
    local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")
    
    if cursor_pos >= item_start and cursor_pos < item_end then
      local item_track = GetMediaItem_Track(item)
      -- Check if this item is in either the previous or next snapshot's folder
      if (prev_snap_folder and is_track_in_folder(item_track, prev_snap_folder)) or
         (next_snap_folder and is_track_in_folder(item_track, next_snap_folder)) then
        cursor_on_relevant_item = true
        break
      end
    end
  end
  
  if cursor_on_relevant_item then
    -- Cursor is on a relevant item - use normal logic
    return find_snapshot_at_cursor(cursor_pos)
  end

  
  -- Cursor is in a GAP (not on any relevant item)
  -- Find the next snapshot item
  local next_snap = nil
  local next_snap_item_start = math.huge
  for _, snap_data in ipairs(snapshot_items) do
    if snap_data.start > cursor_pos then
      local snap = find_snapshot_by_item_guid(snap_data.guid)
      if snap then
        next_snap = snap
        next_snap_item_start = snap_data.start
        break
      end
    end
  end

  -- Find the PREVIOUS snapshot
  local prev_snap = nil
  for i = #snapshot_items, 1, -1 do
    if snapshot_items[i].start <= cursor_pos then
      prev_snap = find_snapshot_by_item_guid(snapshot_items[i].guid)
      break
    end
  end

  -- Find the last item end within the previous snapshot's folder
  local last_item_end_in_prev_folder = -1
  if prev_snap_folder then
    for i = 0, CountMediaItems(0) - 1 do
      local item = GetMediaItem(0, i)
      local item_track = GetMediaItem_Track(item)
      
      -- Only consider items in the previous snapshot's folder
      if is_track_in_folder(item_track, prev_snap_folder) then
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_start + item_length
        
        -- Only consider items that end before the next snapshot starts
        if item_end < next_snap_item_start and item_end > last_item_end_in_prev_folder then
          last_item_end_in_prev_folder = item_end
        end
      end
    end
  end

  -- If we have both snapshots and there's a gap, check midpoint
  if next_snap and last_item_end_in_prev_folder >= 0 and last_item_end_in_prev_folder < next_snap_item_start then
    local gap_mid = last_item_end_in_prev_folder + (next_snap_item_start - last_item_end_in_prev_folder) / 2

    -- Only switch to next snapshot if cursor is past midpoint AND before the next snapshot item
    if cursor_pos >= gap_mid and cursor_pos < next_snap_item_start then
      return next_snap
    end
  end

  -- Otherwise use previous snapshot
  return find_snapshot_at_cursor(cursor_pos)
end

---------------------------------------------------------------------

function find_snapshot_at_cursor(cursor_pos)
  -- First, check if cursor is directly on an item with a snapshot
  for i = 0, CountMediaItems(0) - 1 do
    local item = GetMediaItem(0, i)
    local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_length

    if cursor_pos >= item_start and cursor_pos < item_end then
      local item_guid = BR_GetMediaItemGUID(item)
      local snap = find_snapshot_by_item_guid(item_guid)
      if snap then
        return snap
      end
      -- Item at cursor but no snapshot, continue to search backwards
      break
    end
  end

  -- Search backwards from cursor position through all items
  local prev_snapshot = nil
  local prev_pos = -1

  for i = 0, CountMediaItems(0) - 1 do
    local item = GetMediaItem(0, i)
    local item_start = GetMediaItemInfo_Value(item, "D_POSITION")

    if item_start < cursor_pos and item_start > prev_pos then
      local item_guid = BR_GetMediaItemGUID(item)
      local snap = find_snapshot_by_item_guid(item_guid)
      if snap then
        prev_pos = item_start
        prev_snapshot = snap
      end
    end
  end

  return prev_snapshot
end

---------------------------------------------------------------------

-- MODIFIED: Create snapshot using GUID (works for any item)
function create_snapshot(item_guid, item_name, notes)
  if not item_guid then return nil end

  local snapshot = {}
  snapshot_counter = snapshot_counter + 1
  snapshot.item_guid = item_guid
  snapshot.item_name = item_name or "" -- Store name (can be empty)
  snapshot.date = os.date("%Y-%m-%d")
  snapshot.time = os.date("%H:%M:%S")
  snapshot.notes = notes or ""
  snapshot.tracks = {}

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if is_special_track(track) then
      snapshot.tracks[i] = get_track_state(track)
    end
  end

  return snapshot
end

---------------------------------------------------------------------

-- MODIFIED: Find snapshot by item GUID instead of name
function find_snapshot_by_item_guid(item_guid)
  for i, snap in ipairs(snapshots) do
    if snap.item_guid == item_guid then
      return snap, i
    end
  end
  return nil
end

---------------------------------------------------------------------

function refresh_snapshot_items()
  -- Item GUIDs don't change, so just force re-sort if in timeline mode
  if sort_mode == 0 then
    last_sort_mode = -1
  end
end

---------------------------------------------------------------------

function recall_snapshot(snapshot)
  if not snapshot then return end

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if is_special_track(track) and snapshot.tracks[i] then
      apply_track_state(track, snapshot.tracks[i])
    end
  end

  UpdateArrange()
  TrackList_AdjustWindows(false)
end

---------------------------------------------------------------------

function serialize_table(tbl, indent)
  indent = indent or 0
  local result = {}
  local prefix = string.rep("  ", indent)
  table.insert(result, "{\n")
  for k, v in pairs(tbl) do
    local key_str = type(k) == "number" and ("[" .. k .. "]") or ('["' .. tostring(k) .. '"]')
    if type(v) == "table" then
      table.insert(result, prefix .. "  " .. key_str .. " = " .. serialize_table(v, indent + 1) .. ",\n")
    elseif type(v) == "string" then
      table.insert(result, prefix .. "  " .. key_str .. ' = "' .. v:gsub('"', '\\"') .. '",\n')
    elseif type(v) == "number" or type(v) == "boolean" then
      table.insert(result, prefix .. "  " .. key_str .. " = " .. tostring(v) .. ",\n")
    end
  end
  table.insert(result, prefix .. "}")
  return table.concat(result)
end

---------------------------------------------------------------------

function deserialize_table(str)
  if not str or str == "" then return nil end
  local func = load("return " .. str)
  if func then return func() else return nil end
end

---------------------------------------------------------------------

function save_snapshots_to_project()
  local data = {}
  data.counter = snapshot_counter
  data.snapshots = {}
  data.disable_auto_recall = disable_auto_recall
  data.switch_mid_gap = switch_mid_gap
  data.bank_track_guid = bank_track_guid
  data.recall_volume = recall_volume
  data.recall_pan = recall_pan
  data.recall_mute = recall_mute
  data.recall_solo = recall_solo
  data.recall_phase = recall_phase
  data.recall_fx = recall_fx
  data.recall_sends = recall_sends
  data.recall_routing = recall_routing

  for _, snap in ipairs(snapshots) do
    local s = {
      item_guid = snap.item_guid,
      item_name = snap.item_name,
      date = snap.date,
      time = snap.time,
      notes = snap.notes,
      tracks = snap.tracks
    }
    table.insert(data.snapshots, s)
  end

  local serialized = serialize_table(data)
  SetProjExtState(0, "MixerSnapshots", "data_" .. current_bank, serialized)
end

---------------------------------------------------------------------

function load_snapshots_from_project()
  local retval, serialized = GetProjExtState(0, "MixerSnapshots", "data_" .. current_bank)
  if retval > 0 and serialized ~= "" then
    local data = deserialize_table(serialized)
    if data then
      snapshot_counter = data.counter or 0
      snapshots = {}
      disable_auto_recall = data.disable_auto_recall or false
      switch_mid_gap = data.switch_mid_gap ~= false
      bank_track_guid = data.bank_track_guid
      recall_volume = data.recall_volume ~= false
      recall_pan = data.recall_pan ~= false
      recall_mute = data.recall_mute ~= false
      recall_solo = data.recall_solo ~= false
      recall_phase = data.recall_phase ~= false
      recall_fx = data.recall_fx ~= false
      recall_sends = data.recall_sends ~= false
      recall_routing = data.recall_routing ~= false

      for _, s in ipairs(data.snapshots or {}) do
        table.insert(snapshots, s)
      end

      -- Force a resort after loading
      last_sort_mode = -1
    end
  else
    snapshot_counter = 0
    snapshots = {}
    selected_snapshot = nil
  end
end

---------------------------------------------------------------------

function copy_from_bank(source_bank)
  if source_bank == current_bank then return end
  local retval, serialized = GetProjExtState(0, "MixerSnapshots", "data_" .. source_bank)
  if retval > 0 and serialized ~= "" then
    local data = deserialize_table(serialized)
    if data then
      snapshot_counter = data.counter or 0
      snapshots = {}
      for _, s in ipairs(data.snapshots or {}) do
        table.insert(snapshots, s)
      end
      save_snapshots_to_project()
    end
  end
end

---------------------------------------------------------------------

function clear_bank()
  snapshots = {}
  snapshot_counter = 0
  selected_snapshot = nil
  bank_track_guid = nil
  save_snapshots_to_project()
end

---------------------------------------------------------------------

function switch_to_bank(new_bank)
  if new_bank == current_bank then return end
  save_snapshots_to_project()
  current_bank = new_bank
  selected_snapshot = nil
  load_snapshots_from_project()
end

---------------------------------------------------------------------

function sort_snapshots()
  local ascending = (sort_direction == ImGui.SortDirection_Ascending)
  if sort_mode == 0 then
    -- Sort by timeline position
    table.sort(snapshots, function(a, b)
      local pos_a = get_item_position(a.item_guid)
      local pos_b = get_item_position(b.item_guid)
      if ascending then
        return pos_a < pos_b
      else
        return pos_a > pos_b
      end
    end)
  elseif sort_mode == 1 then
    -- Sort by name (use display name)
    table.sort(snapshots, function(a, b)
      local name_a = a.item_name ~= "" and a.item_name or get_display_name_from_guid(a.item_guid)
      local name_b = b.item_name ~= "" and b.item_name or get_display_name_from_guid(b.item_guid)
      if ascending then
        return name_a < name_b
      else
        return name_a > name_b
      end
    end)
  elseif sort_mode == 2 then
    -- Sort by time
    table.sort(snapshots, function(a, b)
      local a_datetime = a.date .. " " .. a.time
      local b_datetime = b.date .. " " .. b.time
      if ascending then
        return a_datetime < b_datetime
      else
        return a_datetime > b_datetime
      end
    end)
  end
end

---------------------------------------------------------------------

function draw_table()
  -- Only sort if sort mode or direction changed
  if sort_mode ~= last_sort_mode or sort_direction ~= last_sort_direction then
    sort_snapshots()
    last_sort_mode = sort_mode
    last_sort_direction = sort_direction
  end

  if ImGui.BeginTable(ctx, "SnapshotsTable", 5, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_Resizable) then
    ImGui.TableSetupColumn(ctx, "#", ImGui.TableColumnFlags_WidthFixed, col_widths[1])
    ImGui.TableSetupColumn(ctx, "Item Name", ImGui.TableColumnFlags_WidthFixed, col_widths[2])
    ImGui.TableSetupColumn(ctx, "Date/Time", ImGui.TableColumnFlags_WidthFixed, col_widths[3])
    ImGui.TableSetupColumn(ctx, "Notes", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(ctx, "Delete", ImGui.TableColumnFlags_WidthFixed, col_widths[5])
    ImGui.TableHeadersRow(ctx)

    for i, snap in ipairs(snapshots) do
      ImGui.TableNextRow(ctx)
      ImGui.PushID(ctx, i)

      -- Column 0: Index
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.PushID(ctx, "index_sel")
      if ImGui.Selectable(ctx, tostring(i), selected_snapshot == snap) then
        selected_snapshot = snap
        recall_snapshot(snap)
        -- Move edit cursor to item start if auto-recall is enabled
        if not disable_auto_recall then
          local item = get_item_by_guid(snap.item_guid)
          if item then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetEditCurPos(item_pos, true, true)
          end
        end
      end
      ImGui.PopID(ctx)

      -- Column 1: Item Name (use actual name if present, otherwise GUID prefix)
      ImGui.TableSetColumnIndex(ctx, 1)
      local display_name
      if snap.item_name and snap.item_name ~= "" then
        display_name = snap.item_name
        -- Strip everything from first "|" onwards
        local pipe_pos = display_name:find("|")
        if pipe_pos then
          display_name = display_name:sub(1, pipe_pos - 1)
        end
      else
        display_name = get_display_name_from_guid(snap.item_guid)
      end
      
      ImGui.PushID(ctx, "name_sel")
      if ImGui.Selectable(ctx, display_name, selected_snapshot == snap) then
        selected_snapshot = snap
        recall_snapshot(snap)
        if not disable_auto_recall then
          local item = get_item_by_guid(snap.item_guid)
          if item then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetEditCurPos(item_pos, true, true)
          end
        end
      end
      ImGui.PopID(ctx)

      -- Column 2: Date/Time
      ImGui.TableSetColumnIndex(ctx, 2)
      ImGui.PushID(ctx, "time_sel")
      if ImGui.Selectable(ctx, snap.date .. " " .. snap.time, selected_snapshot == snap) then
        selected_snapshot = snap
        recall_snapshot(snap)
        if not disable_auto_recall then
          local item = get_item_by_guid(snap.item_guid)
          if item then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetEditCurPos(item_pos, true, true)
          end
        end
      end
      ImGui.PopID(ctx)

      -- Column 3: Notes
      ImGui.TableSetColumnIndex(ctx, 3)
      if editing_row == i and editing_column == 3 then
        ImGui.SetKeyboardFocusHere(ctx)
        ImGui.PushID(ctx, "edit_notes")
        ImGui.SetNextItemWidth(ctx, -1)
        local rv, new_text = ImGui.InputText(ctx, "##edit", edit_buffer, ImGui.InputTextFlags_EnterReturnsTrue)
        ImGui.PopID(ctx)
        if rv then edit_buffer = new_text end
        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
          editing_row, editing_column = nil, nil
        elseif ImGui.IsItemDeactivatedAfterEdit(ctx) then
          if edit_buffer ~= snap.notes then
            snap.notes = edit_buffer
            save_snapshots_to_project()
          end
          editing_row, editing_column = nil, nil
        end
      else
        ImGui.PushID(ctx, "notes_sel")
        if ImGui.Selectable(ctx, snap.notes, selected_snapshot == snap) then
          selected_snapshot = snap
          recall_snapshot(snap)
          if not disable_auto_recall then
            local item = get_item_by_guid(snap.item_guid)
            if item then
              local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
              SetEditCurPos(item_pos, true, true)
            end
          end
        end
        ImGui.PopID(ctx)
        if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
          editing_row, editing_column, edit_buffer = i, 3, snap.notes
        end
      end

      -- Column 4: Delete button
      ImGui.TableSetColumnIndex(ctx, 4)
      ImGui.PushID(ctx, "delete_btn")
      if ImGui.Button(ctx, "✕") then
        Undo_BeginBlock()
        table.remove(snapshots, i)
        if selected_snapshot == snap then
          selected_snapshot = nil
        end
        save_snapshots_to_project()
        Undo_EndBlock("Delete Mixer Snapshot", -1)
      end
      ImGui.PopID(ctx)

      ImGui.PopID(ctx)
    end

    ImGui.EndTable(ctx)
  end
end

---------------------------------------------------------------------

function draw_UI()
  ImGui.SetNextWindowSize(ctx, 900, 600, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, script_name, true)
  if visible then
    -- Bank tabs
    if ImGui.BeginTabBar(ctx, "Banks") then
      for _, bank in ipairs({ "A", "B", "C", "D" }) do
        if ImGui.BeginTabItem(ctx, "     " .. bank .. "     ") then
          if current_bank ~= bank then switch_to_bank(bank) end
          ImGui.EndTabItem(ctx)
        end
      end
      ImGui.EndTabBar(ctx)
    end

    -- Bank operations
    ImGui.Text(ctx, "Copy from:")
    ImGui.SameLine(ctx)
    for _, bank in ipairs({ "A", "B", "C", "D" }) do
      if bank ~= current_bank then
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, bank) then copy_from_bank(bank) end
        if ImGui.IsItemHovered(ctx) then
          ImGui.SetTooltip(ctx, "Copy all snapshots from bank " .. bank)
        end
      end
    end

    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear Bank " .. current_bank) then
      ImGui.OpenPopup(ctx, "confirm_clear")
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Delete all snapshots in current bank")
    end

    if ImGui.BeginPopupModal(ctx, "confirm_clear", true, ImGui.WindowFlags_AlwaysAutoResize) then
      ImGui.Text(ctx, "Are you sure you want to clear all snapshots in Bank " .. current_bank .. "?")
      ImGui.Text(ctx, "This cannot be undone.")
      ImGui.Separator(ctx)
      if ImGui.Button(ctx, "Yes, Clear Bank", 120, 0) then
        clear_bank()
        ImGui.CloseCurrentPopup(ctx)
      end
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, "Cancel", 120, 0) then
        ImGui.CloseCurrentPopup(ctx)
      end
      ImGui.EndPopup(ctx)
    end

    ImGui.Separator(ctx)

    -- Snapshot creation/management
    local item_guid, item_name = get_selected_item_info()
    local can_create = item_guid ~= nil  -- MODIFIED: Any item works now

    -- Generate display name for button
    local display_name
    if item_name and item_name ~= "" then
      display_name = item_name
      local pipe_pos = display_name:find("|")
      if pipe_pos then
        display_name = display_name:sub(1, pipe_pos - 1)
      end
    elseif item_guid then
      display_name = get_display_name_from_guid(item_guid)
    end

    if not can_create then ImGui.BeginDisabled(ctx) end
    local existing_snap = nil
    if item_guid then
      existing_snap = find_snapshot_by_item_guid(item_guid)
    end
    local button_label
    if existing_snap then
      button_label = "Update snapshot for: " .. (display_name or "Unknown")
    elseif display_name then
      button_label = "Set snapshot for: " .. display_name
    else
      button_label = "Set snapshot (select an item first)"
    end

    if ImGui.Button(ctx, button_label) then
      if can_create then
        local selected_item = GetSelectedMediaItem(0, 0)
        if selected_item then
          Undo_BeginBlock()
          local existing_snap = find_snapshot_by_item_guid(item_guid)
          if existing_snap then
            -- Update existing snapshot
            existing_snap.tracks = {}
            for i = 0, CountTracks(0) - 1 do
              local track = GetTrack(0, i)
              if is_special_track(track) then
                existing_snap.tracks[i] = get_track_state(track)
              end
            end
            existing_snap.item_name = item_name or ""
            existing_snap.date = os.date("%Y-%m-%d")
            existing_snap.time = os.date("%H:%M:%S")
            selected_snapshot = existing_snap
          else
            -- Create new snapshot
            local snap = create_snapshot(item_guid, item_name)
            if snap then
              table.insert(snapshots, snap)
              selected_snapshot = snap
            end
          end
          save_snapshots_to_project()
          Undo_EndBlock("Set Mixer Snapshot", -1)
        end
      end
    end
    if not can_create then ImGui.EndDisabled(ctx) end

    ImGui.Separator(ctx)

    -- Sort controls
    ImGui.Text(ctx, "Sort by:")
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Timeline Position", sort_mode == 0) then sort_mode = 0 end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Name", sort_mode == 1) then sort_mode = 1 end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Time", sort_mode == 2) then sort_mode = 2 end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    local dir_label = sort_direction == ImGui.SortDirection_Ascending and "Ascending ▲" or "Descending ▼"
    if ImGui.Button(ctx, dir_label) then
      sort_direction = sort_direction == ImGui.SortDirection_Ascending and ImGui.SortDirection_Descending or
          ImGui.SortDirection_Ascending
    end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Refresh Order") then
      refresh_snapshot_items()
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Refresh table order after moving items on timeline")
    end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    local rv_disable, new_disable = ImGui.Checkbox(ctx, "Disable auto-recall", disable_auto_recall)
    if rv_disable then
      disable_auto_recall = new_disable
      save_snapshots_to_project()
    end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 10, 0); ImGui.SameLine(ctx)

    -- Grey out mid-gap checkbox when auto-recall is disabled
    if disable_auto_recall then
      ImGui.BeginDisabled(ctx)
    end
    local rv_gap, new_gap = ImGui.Checkbox(ctx, "Switch mid-gap during playback", switch_mid_gap)
    if rv_gap then
      switch_mid_gap = new_gap
      save_snapshots_to_project()
    end
    if disable_auto_recall then
      ImGui.EndDisabled(ctx)
    end

    ImGui.Separator(ctx)
    draw_table()
    ImGui.Separator(ctx)

    -- Recall parameter selection
    ImGui.Text(ctx, "Recall:")
    ImGui.SameLine(ctx)
    for _, param in ipairs({
      { "Volume",       recall_volume,  function(v) recall_volume = v end },
      { "Pan",          recall_pan,     function(v) recall_pan = v end },
      { "Mute",         recall_mute,    function(v) recall_mute = v end },
      { "Solo",         recall_solo,    function(v) recall_solo = v end },
      { "Phase",        recall_phase,   function(v) recall_phase = v end },
      { "FX",           recall_fx,      function(v) recall_fx = v end },
      { "Send Levels",  recall_sends,   function(v) recall_sends = v end },
      { "Send Routing", recall_routing, function(v) recall_routing = v end }
    }) do
      local rv, new_val = ImGui.Checkbox(ctx, param[1], param[2])
      if rv then
        param[3](new_val); save_snapshots_to_project()
      end
      ImGui.SameLine(ctx)
    end

    ImGui.End(ctx)
  end
  return open
end

---------------------------------------------------------------------

function check_auto_recall()
  if disable_auto_recall then return end

  local play_state = GetPlayState()
  local current_playing = (play_state & 1) == 1

  -- Get current item selection
  local item_guid, item_name = get_selected_item_info()

  -- MODIFIED: No blocking - any item can have a snapshot
  -- Check for item selection changes (only when stopped)
  if not current_playing then
    local guid_changed = (item_guid ~= last_selected_item_guid)
    if guid_changed then
      last_selected_item_guid = item_guid

      if item_guid then
        local snap = find_snapshot_by_item_guid(item_guid)
        if snap then
          recall_snapshot(snap)
          selected_snapshot = snap
        else
          -- No snapshot for this item - recall previous snapshot based on cursor
          local edit_cursor = GetCursorPosition()
          local snap = find_snapshot_at_cursor(edit_cursor)
          if snap then
            recall_snapshot(snap)
            selected_snapshot = snap
          end
        end
      else
        -- No item selected - recall based on cursor
        local edit_cursor = GetCursorPosition()
        local snap = find_snapshot_at_cursor(edit_cursor)
        if snap then
          recall_snapshot(snap)
          selected_snapshot = snap
        end
      end
      last_edit_cursor_pos = GetCursorPosition()
    end
  end

  if current_playing then
    -- During playback, check play cursor position with gap logic
    local play_pos = GetPlayPosition()
    if math.abs(play_pos - last_play_pos) > 0.001 then
      last_play_pos = play_pos

      local snap = find_snapshot_with_gap_logic(play_pos)
      if snap then
        if snap ~= selected_snapshot then
          recall_snapshot(snap)
          selected_snapshot = snap
        end
      end
    end
    is_playing = true
  else
    -- Not playing, check edit cursor position
    local edit_cursor = GetCursorPosition()

    -- If we just stopped playing, force an update
    if is_playing then
      is_playing = false
      last_play_pos = -1
      local snap = find_snapshot_at_cursor(edit_cursor)
      if snap then
        recall_snapshot(snap)
        selected_snapshot = snap
      end
      last_edit_cursor_pos = edit_cursor
    elseif math.abs(edit_cursor - last_edit_cursor_pos) > 0.001 then
      last_edit_cursor_pos = edit_cursor

      local snap = find_snapshot_at_cursor(edit_cursor)
      if snap then
        recall_snapshot(snap)
        selected_snapshot = snap
      end
    end
  end
end

---------------------------------------------------------------------

function handle_project_change()
  local current_project = EnumProjects(-1)
  if current_project ~= last_project then
    last_project = current_project
    snapshots, selected_snapshot, snapshot_counter = {}, nil, 0
    editing_row, editing_column, edit_buffer = nil, nil, ""
    last_selected_item_guid = nil
    last_edit_cursor_pos = -1
    last_play_pos = -1
    is_playing = false
    load_snapshots_from_project()
    TrackList_AdjustWindows(false)
    UpdateArrange()
  end
end

---------------------------------------------------------------------

sort_direction = ImGui.SortDirection_Ascending
load_snapshots_from_project()
defer(main)