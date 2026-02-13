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
local convert_snapshots_to_automation, clear_all_automation
local check_for_automation_on_special_tracks

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
local switch_mid_gap          = true  -- Switch snapshots in the middle of gaps
local automation_detected     = false -- NEW: Track if automation exists on special tracks

-- Track restriction per bank - REMOVED (now supports multiple tracks)
local bank_track_guid         = nil -- Deprecated but kept for backwards compatibility

-- Folder selection per bank for gap detection
local bank_folder_selection   = {} -- "all" or folder track GUID

-- Folder selection per bank for gap detection
local bank_folder_selection   = {} -- "all" or folder GUID

-- Selective parameter recall flags (all enabled by default)
local recall_volume           = true
local recall_pan              = true
local recall_mute             = true
local recall_solo             = true
local recall_phase            = true
local recall_width            = true  -- NEW: Added width recall flag
local recall_fx               = true
local recall_sends            = true
local recall_routing          = true

-- Column widths: #, Item Name, Date/Time, Notes, Delete
local col_widths              = { 35, 250, 140, 350, 60 }

local last_project

---------------------------------------------------------------------

function main()
  handle_project_change()
  update_snapshot_names()                  -- NEW: Check for name changes every frame
  check_for_automation_on_special_tracks() -- NEW: Check for automation every frame
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

-- NEW: Check if any special tracks have active automation
function check_for_automation_on_special_tracks()
  local has_automation = false

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if is_special_track(track) then
      local num_envelopes = CountTrackEnvelopes(track)
      for env_idx = 0, num_envelopes - 1 do
        local env = GetTrackEnvelope(track, env_idx)

        -- Check if envelope is visible, active, or armed
        local _, visible_str = GetSetEnvelopeInfo_String(env, "VISIBLE", "", false)
        local _, active_str = GetSetEnvelopeInfo_String(env, "ACTIVE", "", false)
        local _, arm_str = GetSetEnvelopeInfo_String(env, "ARM", "", false)

        -- If any of these are "1", the envelope is considered active
        if visible_str == "1" or active_str == "1" or arm_str == "1" then
          has_automation = true
          break
        end
      end
      if has_automation then break end
    end
  end

  -- Handle automation state changes
  if has_automation and not automation_detected then
    -- Automation just appeared - save current state and disable auto-recall
    automation_detected = true
    SetProjExtState(0, "ReaClassical", "auto_recall_before_automation_" .. current_bank, tostring(disable_auto_recall))
    disable_auto_recall = true
  elseif not has_automation and automation_detected then
    -- Automation just cleared - restore previous state
    automation_detected = false
    local retval, saved_state = GetProjExtState(0, "ReaClassical", "auto_recall_before_automation_" .. current_bank)
    if retval > 0 and saved_state ~= "" then
      disable_auto_recall = (saved_state == "true")
    end
    -- Clean up the saved state
    SetProjExtState(0, "ReaClassical", "auto_recall_before_automation_" .. current_bank, "")
  elseif has_automation then
    -- Automation still present - keep auto-recall disabled
    automation_detected = true
    disable_auto_recall = true
  else
    -- No automation
    automation_detected = false
  end
end

---------------------------------------------------------------------

function get_track_state(track)
  local state = {}
  state.volume = GetMediaTrackInfo_Value(track, "D_VOL")
  state.pan = GetMediaTrackInfo_Value(track, "D_PAN")
  state.mute = GetMediaTrackInfo_Value(track, "B_MUTE")
  state.solo = GetMediaTrackInfo_Value(track, "I_SOLO")
  state.phase = GetMediaTrackInfo_Value(track, "B_PHASE")
  state.width = GetMediaTrackInfo_Value(track, "D_WIDTH")  -- NEW: Capture track width
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
  if recall_width and state.width then SetMediaTrackInfo_Value(track, "D_WIDTH", state.width) end  -- NEW: Apply width if available

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
  return "{" .. (first_segment or guid) .. "}" -- Added curly braces around the return
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
  data.bank_folder_selection = bank_folder_selection[current_bank] or "all"
  data.recall_volume = recall_volume
  data.recall_pan = recall_pan
  data.recall_mute = recall_mute
  data.recall_solo = recall_solo
  data.recall_phase = recall_phase
  data.recall_width = recall_width  -- NEW: Save width recall flag
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
      bank_folder_selection[current_bank] = data.bank_folder_selection or "all"
      recall_volume = data.recall_volume ~= false
      recall_pan = data.recall_pan ~= false
      recall_mute = data.recall_mute ~= false
      recall_solo = data.recall_solo ~= false
      recall_phase = data.recall_phase ~= false
      recall_width = data.recall_width ~= false  -- NEW: Load width recall flag (default true)
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
    bank_folder_selection[current_bank] = "all"
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

    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear All Automation") then
      clear_all_automation()
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Clear all automation from mixer, aux, and submix tracks")
    end

    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Convert to Automation") then
      convert_snapshots_to_automation()
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Create real automation lanes from all snapshots in current bank")
    end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 10, 0); ImGui.SameLine(ctx)
    -- Folder selection dropdown for gap detection
    ImGui.Text(ctx, "Gap Detection:")
    ImGui.SameLine(ctx)

    -- Build folder options
    local folder_options = { "All Tracks" }
    local folder_guids = { "all" }
    local current_selection = 0

    -- Get all folder parent tracks
    for i = 0, CountTracks(0) - 1 do
      local track = GetTrack(0, i)
      local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
      if folder_depth == 1 then
        local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
        local prefix = track_name:match("^([^:]+):")
        if not prefix then prefix = "Folder" end
        table.insert(folder_options, prefix) -- Uses just the prefix
        table.insert(folder_guids, guid)

        -- Check if this is the current selection
        if bank_folder_selection[current_bank] == guid then
          current_selection = #folder_options - 1
        end
      end
    end

    ImGui.SetNextItemWidth(ctx, 100)
    local options_str = table.concat(folder_options, "\0") .. "\0"
    local changed, new_selection = ImGui.Combo(ctx, "##folder_select", current_selection, options_str)

    ImGui.Separator(ctx)

    -- Snapshot creation/management
    local item_guid, item_name = get_selected_item_info()
    local can_create = item_guid ~= nil -- MODIFIED: Any item works now

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

    if changed then
      bank_folder_selection[current_bank] = folder_guids[new_selection + 1]
      save_snapshots_to_project()
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Select which folder's items to check for gaps during automation conversion")
    end

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

    -- MODIFIED: Grey out checkbox when automation is detected
    if automation_detected then
      ImGui.BeginDisabled(ctx)
    end
    local rv_disable, new_disable = ImGui.Checkbox(ctx, "Disable auto-recall", disable_auto_recall)
    if rv_disable and not automation_detected then
      disable_auto_recall = new_disable
      save_snapshots_to_project()
    end
    if automation_detected then
      ImGui.EndDisabled(ctx)
      if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
        ImGui.SetTooltip(ctx, "Automation detected on special tracks - auto recall of snapshots disabled")
      end
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
      { "Width",        recall_width,   function(v) recall_width = v end },  -- NEW: Added Width checkbox
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

function clear_all_automation()
  Undo_BeginBlock()

  local cleared_count = 0
  local tracks_to_hide = {}

  -- Clear all existing automation from mixer tracks and special tracks
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
    local is_special = is_special_track(track)

    if mixer_state == "y" or is_special then
      -- Delete all envelope points on all envelopes
      local num_envelopes = CountTrackEnvelopes(track)
      for env_idx = 0, num_envelopes - 1 do
        local env = GetTrackEnvelope(track, env_idx)
        DeleteEnvelopePointRange(env, -1000000, 1000000)
        GetSetEnvelopeInfo_String(env, "VISIBLE", "0", true)
        GetSetEnvelopeInfo_String(env, "ACTIVE", "0", true)
        GetSetEnvelopeInfo_String(env, "ARM", "0", true)
      end
      if num_envelopes > 0 then
        cleared_count = cleared_count + 1
      end
      
      -- Mark track for hiding from TCP
      table.insert(tracks_to_hide, track)
    end
  end

  -- Hide tracks from TCP after clearing automation
  for _, track in ipairs(tracks_to_hide) do
    local current_tcp_state = GetMediaTrackInfo_Value(track, "B_SHOWINTCP")
    
    if current_tcp_state == 1 then
      -- Hide the track in TCP
      SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
      
      -- Update project ext state
      local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
      local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
      
      -- Use appropriate prefix for ext state key
      if mixer_state == "y" then
        SetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. guid, "0")
      else
        SetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid, "0")
      end
    end
  end

  UpdateArrange()
  TrackList_AdjustWindows(false)
  Undo_EndBlock("Clear All Mixer Automation", -1)

  ShowMessageBox("Cleared automation from " .. cleared_count .. " tracks.", "Clear All Automation", 0)
end

---------------------------------------------------------------------

function convert_snapshots_to_automation()
  if #snapshots == 0 then
    ShowMessageBox("No snapshots to convert.", "Convert to Automation", 0)
    return
  end

  Undo_BeginBlock()

  -- Clear all existing automation from mixer tracks and special tracks
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
    local is_special = is_special_track(track)

    if mixer_state == "y" or is_special then
      -- Delete all envelope points on all envelopes
      local num_envelopes = CountTrackEnvelopes(track)
      for env_idx = 0, num_envelopes - 1 do
        local env = GetTrackEnvelope(track, env_idx)
        DeleteEnvelopePointRange(env, -1000000, 1000000)
        GetSetEnvelopeInfo_String(env, "VISIBLE", "0", true)
        GetSetEnvelopeInfo_String(env, "ACTIVE", "0", true)
        GetSetEnvelopeInfo_String(env, "ARM", "0", true)
      end
    end
  end

  -- Sort snapshots by timeline position first
  local sorted_snapshots = {}
  for i, snap in ipairs(snapshots) do
    local item = get_item_by_guid(snap.item_guid)
    if item then
      local pos = GetMediaItemInfo_Value(item, "D_POSITION")
      table.insert(sorted_snapshots, { snap = snap, pos = pos, idx = i })
    end
  end
  table.sort(sorted_snapshots, function(a, b) return a.pos < b.pos end)

  -- Collect all parameters that change across snapshots
  local param_changes = {}

  for _, snap_data in ipairs(sorted_snapshots) do
    local snap = snap_data.snap
    local snap_idx = snap_data.idx
    local item = get_item_by_guid(snap.item_guid)
    if item then
      local snap_pos = GetMediaItemInfo_Value(item, "D_POSITION")

      for track_idx, track_state in pairs(snap.tracks) do
        local track_guid = track_state.guid

        if not param_changes[track_guid] then
          param_changes[track_guid] = {
            volume = {},
            pan = {},
            mute = {},
            solo = {},
            phase = {},
            width = {},  -- NEW: Added width tracking
            fx = {},
            sends = {}
          }
        end

        -- Record parameter values at this position WITH snapshot index
        table.insert(param_changes[track_guid].volume,
          { pos = snap_pos, value = track_state.volume, snap_idx = snap_idx })
        table.insert(param_changes[track_guid].pan, { pos = snap_pos, value = track_state.pan, snap_idx = snap_idx })
        table.insert(param_changes[track_guid].mute, { pos = snap_pos, value = track_state.mute, snap_idx = snap_idx })
        table.insert(param_changes[track_guid].solo, { pos = snap_pos, value = track_state.solo, snap_idx = snap_idx })
        table.insert(param_changes[track_guid].phase, { pos = snap_pos, value = track_state.phase, snap_idx = snap_idx })
        -- NEW: Record width if available
        if track_state.width then
          table.insert(param_changes[track_guid].width, { pos = snap_pos, value = track_state.width, snap_idx = snap_idx })
        end

        -- Record FX parameters
        for fx_idx, fx in pairs(track_state.fx_chain) do
          if not param_changes[track_guid].fx[fx_idx] then
            param_changes[track_guid].fx[fx_idx] = {}
          end
          for param_idx, param_value in pairs(fx.params) do
            if not param_changes[track_guid].fx[fx_idx][param_idx] then
              param_changes[track_guid].fx[fx_idx][param_idx] = {}
            end
            table.insert(param_changes[track_guid].fx[fx_idx][param_idx],
              { pos = snap_pos, value = param_value, snap_idx = snap_idx })
          end
        end

        -- Record send parameters
        for send_idx, send in pairs(track_state.sends) do
          if not param_changes[track_guid].sends[send_idx] then
            param_changes[track_guid].sends[send_idx] = {
              volume = {},
              pan = {},
              mute = {}
            }
          end
          table.insert(param_changes[track_guid].sends[send_idx].volume,
            { pos = snap_pos, value = send.volume, snap_idx = snap_idx })
          table.insert(param_changes[track_guid].sends[send_idx].pan,
            { pos = snap_pos, value = send.pan, snap_idx = snap_idx })
          table.insert(param_changes[track_guid].sends[send_idx].mute,
            { pos = snap_pos, value = send.mute, snap_idx = snap_idx })
        end
      end
    end
  end

  -- Check which parameters actually change and write automation
  local automation_count = 0
  local tracks_with_automation = {} -- Track which tracks get automation

  -- Helper to check if values change
  local function has_changes(points)
    if #points < 2 then return false end
    local first_val = points[1].value
    for i = 2, #points do
      if math.abs(points[i].value - first_val) > 0.0001 then
        return true
      end
    end
    return false
  end

  -- Helper to check if a track is within a folder (or is the folder itself)
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

  -- Helper to ensure an envelope exists
  local function get_or_create_envelope(track, param_name)
    -- First try to get it by name
    local env = GetTrackEnvelopeByName(track, param_name)
    if env then
      GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
      GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
      GetSetEnvelopeInfo_String(env, "ARM", "1", true)
      return env
    end

    -- Save current track selection
    local num_selected = CountSelectedTracks(0)
    local selected_tracks = {}
    for i = 0, num_selected - 1 do
      selected_tracks[i] = GetSelectedTrack(0, i)
    end

    -- Select only our track
    Main_OnCommand(40297, 0) -- Unselect all tracks
    SetTrackSelected(track, true)

    -- Toggle the appropriate envelope
    if param_name == "Volume" then
      local env_count = CountTrackEnvelopes(track)
      local had_vol_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Volume" or name == "Volume (Pre-FX)" then
          had_vol_env = true
          break
        end
      end
      if not had_vol_env then
        Main_OnCommand(40406, 0) -- Track: Toggle volume envelope visible
      end
    elseif param_name == "Pan" then
      local env_count = CountTrackEnvelopes(track)
      local had_pan_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Pan" or name == "Pan (Pre-FX)" then
          had_pan_env = true
          break
        end
      end
      if not had_pan_env then
        Main_OnCommand(40407, 0) -- Track: Toggle pan envelope visible
      end
    elseif param_name == "Mute" then
      local env_count = CountTrackEnvelopes(track)
      local had_mute_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Mute" then
          had_mute_env = true
          break
        end
      end
      if not had_mute_env then
        Main_OnCommand(40867, 0) -- Track: Toggle mute envelope visible
      end
    elseif param_name == "Width" then
      -- NEW: Handle width envelope
      local env_count = CountTrackEnvelopes(track)
      local had_width_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Width" or name == "Width (Pre-FX)" then
          had_width_env = true
          break
        end
      end
      if not had_width_env then
        Main_OnCommand(41870, 0) -- Track: Toggle width envelope visible
      end
    end

    -- Restore selection
    Main_OnCommand(40297, 0) -- Unselect all tracks
    for i = 0, num_selected - 1 do
      SetTrackSelected(selected_tracks[i], true)
    end

    -- Try to get the envelope again
    env = GetTrackEnvelopeByName(track, param_name)
    if env then
      GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
      GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
      GetSetEnvelopeInfo_String(env, "ARM", "1", true)
    end
    return env
  end

  -- Helper to insert automation points with gap logic and 35ms steps
  local function insert_automation_points(env, points, needs_scaling)
    -- Points are already sorted by timeline position

    -- First pass: determine which points to keep (where value changes)
    local points_to_write = {}
    local prev_value = nil

    for i, point in ipairs(points) do
      if not prev_value or math.abs(point.value - prev_value) > 0.0001 then
        table.insert(points_to_write, point)
        prev_value = point.value
      end
    end

    if #points_to_write == 0 then return end

    -- Build list of automation points to insert
    local auto_points = {}

    -- Add initial point at time 0 with first snapshot's value to prevent ramp-up
    local first_point_value = points_to_write[1].value
    table.insert(auto_points, {
      pos = 0,
      value = first_point_value
    })

    -- Process each value change
    for i = 1, #points_to_write do
      local point = points_to_write[i]
      local snap = snapshots[point.snap_idx]
      local snap_item = get_item_by_guid(snap.item_guid)

      if not snap_item then goto continue_point end

      local snap_item_start = GetMediaItemInfo_Value(snap_item, "D_POSITION")
      local snap_folder_track = GetMediaItem_Track(snap_item)
      local target_pos = snap_item_start

      -- For points after the first, determine the switch point using gap logic
      if i > 1 and switch_mid_gap then
        local prev_point = points_to_write[i - 1]
        local prev_snap = snapshots[prev_point.snap_idx]
        local prev_snap_item = get_item_by_guid(prev_snap.item_guid)

        if prev_snap_item then
          local prev_folder_track = GetMediaItem_Track(prev_snap_item)

          -- Get folder selection for this bank
          local selected_folder = bank_folder_selection[current_bank] or "all"

          -- Check if we should analyze this folder pair
          local should_check_gap = false
          if selected_folder == "all" then
            should_check_gap = true
          else
            -- Check if either snapshot is on the selected folder
            local _, prev_guid = GetSetMediaTrackInfo_String(prev_folder_track, "GUID", "", false)
            local _, snap_guid = GetSetMediaTrackInfo_String(snap_folder_track, "GUID", "", false)
            if prev_guid == selected_folder or snap_guid == selected_folder then
              should_check_gap = true
            end
          end

          if should_check_gap then
            -- Get folder selection for this bank
            local selected_folder = bank_folder_selection[current_bank] or "all"

            local snap_item_guid = BR_GetMediaItemGUID(snap_item)
            local total_items = CountMediaItems(0)
            local has_overlap = false
            local latest_item_end = -1

            -- Scan items based on folder selection
            for item_idx = 0, total_items - 1 do
              local item = GetMediaItem(0, item_idx)
              local item_guid = BR_GetMediaItemGUID(item)

              -- Skip the snapshot item itself
              if item_guid ~= snap_item_guid then
                -- If specific folder is selected, only check items on that folder track
                local should_check_item = false
                if selected_folder == "all" then
                  should_check_item = true
                else
                  -- Check if this item is on the selected folder track
                  local item_track = GetMediaItem_Track(item)
                  local _, item_track_guid = GetSetMediaTrackInfo_String(item_track, "GUID", "", false)
                  if item_track_guid == selected_folder then
                    should_check_item = true
                  end
                end

                if should_check_item then
                  local item_start_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                  local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
                  local item_end = item_start_pos + item_length

                  -- Check if this item overlaps with the snapshot item start
                  -- An item overlaps if: item_start < snap_item_start AND item_end > snap_item_start
                  if item_start_pos < snap_item_start and item_end > snap_item_start then
                    has_overlap = true
                    break
                  end

                  -- Also track the latest item end that's before the snapshot start
                  if item_end < snap_item_start and item_end > latest_item_end then
                    latest_item_end = item_end
                  end
                end
              end
            end

            -- If there's ANY overlap, no gap - use snap_item_start
            -- If there's no overlap, check if there's a gap
            if not has_overlap and latest_item_end >= 0 then
              local gap_size = snap_item_start - latest_item_end

              -- Only use gap midpoint if there's a REAL gap (more than 0.001 seconds)
              if gap_size > 0.001 then
                local gap_mid = latest_item_end + gap_size / 2
                target_pos = gap_mid
              end
            end
          end
          -- Otherwise (no gap or items are adjacent), target_pos stays at snap_item_start
        end
      end
      -- If switch_mid_gap is disabled, target_pos always stays at snap_item_start

      -- Insert ramp start point (previous value) 35ms before target
      if i > 1 then
        table.insert(auto_points, {
          pos = target_pos - 0.035,
          value = points_to_write[i - 1].value
        })
      end

      -- Insert the new value point at target position
      table.insert(auto_points, {
        pos = target_pos,
        value = point.value
      })

      ::continue_point::
    end

    -- Reset specific parameters to neutral values ONLY if they're getting automation
    for track_guid, params in pairs(param_changes) do
      local track = find_track_by_GUID(track_guid)
      if track then
        -- Reset volume only if it's getting automation
        if has_changes(params.volume) then
          SetMediaTrackInfo_Value(track, "D_VOL", 1.0)  -- 0dB
        end
        
        -- Reset pan only if it's getting automation
        if has_changes(params.pan) then
          SetMediaTrackInfo_Value(track, "D_PAN", 0.0)  -- Center
        end
        
        -- Reset mute only if it's getting automation
        if has_changes(params.mute) then
          SetMediaTrackInfo_Value(track, "B_MUTE", 0)  -- Unmuted
        end
        
        -- Reset phase only if it's getting automation
        if has_changes(params.phase) then
          SetMediaTrackInfo_Value(track, "B_PHASE", 0)  -- Normal phase
        end
        
        -- NEW: Reset width only if it's getting automation
        if has_changes(params.width) then
          SetMediaTrackInfo_Value(track, "D_WIDTH", 1.0)  -- Normal width
        end
        
        -- Reset send parameters only if they're getting automation
        for send_idx, send_params in pairs(params.sends) do
          if has_changes(send_params.volume) then
            SetTrackSendInfo_Value(track, 0, send_idx, "D_VOL", 1.0)
          end
          if has_changes(send_params.pan) then
            SetTrackSendInfo_Value(track, 0, send_idx, "D_PAN", 0.0)
          end
          if has_changes(send_params.mute) then
            SetTrackSendInfo_Value(track, 0, send_idx, "B_MUTE", 0)
          end
        end
        
        -- FX parameters don't need explicit reset as they'll be controlled by automation
      end
    end
    
    -- Insert all automation points
    for _, auto_point in ipairs(auto_points) do
      local env_val = needs_scaling and ScaleToEnvelopeMode(1, auto_point.value) or auto_point.value
      InsertEnvelopePoint(env, auto_point.pos, env_val, 0, 0, false, true)
    end
  end

  for track_guid, params in pairs(param_changes) do
    local track = find_track_by_GUID(track_guid)
    if track then
      local track_got_automation = false
      SetMediaTrackInfo_Value(track, "I_AUTOMODE", 1)
      -- Volume
      if has_changes(params.volume) then
        local env = get_or_create_envelope(track, "Volume")
        if env then
          insert_automation_points(env, params.volume, true)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      -- Pan
      if has_changes(params.pan) then
        local env = get_or_create_envelope(track, "Pan")
        if env then
          -- Invert pan values before inserting
          local inverted_pan_points = {}
          for _, point in ipairs(params.pan) do
            table.insert(inverted_pan_points, {
              pos = point.pos,
              value = -point.value, -- Invert the pan value
              snap_idx = point.snap_idx
            })
          end
          insert_automation_points(env, inverted_pan_points, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      -- Mute (need to invert: track B_MUTE is 1=muted, automation is 0=muted)
      if has_changes(params.mute) then
        local env = get_or_create_envelope(track, "Mute")
        if env then
          -- Invert mute values before inserting
          local inverted_mute_points = {}
          for _, point in ipairs(params.mute) do
            table.insert(inverted_mute_points, {
              pos = point.pos,
              value = point.value == 1 and 0 or 1, -- Invert: 1->0, 0->1
              snap_idx = point.snap_idx
            })
          end
          insert_automation_points(env, inverted_mute_points, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      -- Solo
      if has_changes(params.solo) then
        local env = GetTrackEnvelopeByName(track, "Solo")
        if env then
          insert_automation_points(env, params.solo, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      -- Phase
      if has_changes(params.phase) then
        local env = GetTrackEnvelopeByName(track, "Phase")
        if not env then
          env = GetTrackEnvelopeByName(track, "Polarity")
        end
        if env then
          insert_automation_points(env, params.phase, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      -- NEW: Width automation
      if has_changes(params.width) then
        local env = get_or_create_envelope(track, "Width")
        if env then
          insert_automation_points(env, params.width, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      -- FX parameters
      for fx_idx, fx_params in pairs(params.fx) do
        for param_idx, points in pairs(fx_params) do
          if has_changes(points) then
            local env = GetFXEnvelope(track, fx_idx, param_idx, true)
            if env then
              insert_automation_points(env, points, false)
              Envelope_SortPoints(env)
              automation_count = automation_count + 1
              track_got_automation = true
              GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
              GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
              GetSetEnvelopeInfo_String(env, "ARM", "1", true)
            end
          end
        end
      end

      -- Send parameters
      for send_idx, send_params in pairs(params.sends) do
        local num_selected = CountSelectedTracks(0)
        local selected_tracks = {}
        for i = 0, num_selected - 1 do
          selected_tracks[i] = GetSelectedTrack(0, i)
        end

        Main_OnCommand(40297, 0)
        SetTrackSelected(track, true)

        if has_changes(send_params.volume) or has_changes(send_params.pan) or has_changes(send_params.mute) then
          Main_OnCommand(41327, 0)
        end

        Main_OnCommand(40297, 0)
        for i = 0, num_selected - 1 do
          SetTrackSelected(selected_tracks[i], true)
        end

        if has_changes(send_params.volume) then
          local env = GetTrackSendEnvelope(track, 0, send_idx, 0)
          if env then
            insert_automation_points(env, send_params.volume, true)
            Envelope_SortPoints(env)
            automation_count = automation_count + 1
            track_got_automation = true
          end
        end

        if has_changes(send_params.pan) then
          local env = GetTrackSendEnvelope(track, 0, send_idx, 1)
          if env then
            insert_automation_points(env, send_params.pan, false)
            Envelope_SortPoints(env)
            automation_count = automation_count + 1
            track_got_automation = true
          end
        end

        if has_changes(send_params.mute) then
          local env = GetTrackSendEnvelope(track, 0, send_idx, 2)
          if env then
            -- Invert send mute values before inserting
            local inverted_send_mute_points = {}
            for _, point in ipairs(send_params.mute) do
              table.insert(inverted_send_mute_points, {
                pos = point.pos,
                value = point.value == 1 and 0 or 1, -- Invert: 1->0, 0->1
                snap_idx = point.snap_idx
              })
            end
            insert_automation_points(env, inverted_send_mute_points, false)
            Envelope_SortPoints(env)
            automation_count = automation_count + 1
            track_got_automation = true
          end
        end
      end

      -- If this track got automation, mark it
      if track_got_automation then
        tracks_with_automation[track] = true
      end
    end
  end

  -- Now show only tracks that got automation in TCP
  for track, _ in pairs(tracks_with_automation) do
    local current_tcp_state = GetMediaTrackInfo_Value(track, "B_SHOWINTCP")

    if current_tcp_state == 0 then
      -- Show the track in TCP
      SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)

      -- Update project ext state
      local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
      local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)

      -- Use appropriate prefix for ext state key
      if mixer_state == "y" then
        SetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. guid, "1")
      else
        SetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid, "1")
      end
    end
  end

  UpdateArrange()
  TrackList_AdjustWindows(false)
  Undo_EndBlock("Convert Mixer Snapshots to Automation", -1)

  ShowMessageBox(automation_count .. " automation lanes created from " .. #snapshots .. " snapshots.",
    "Convert to Automation", 0)
end

---------------------------------------------------------------------

sort_direction = ImGui.SortDirection_Ascending
load_snapshots_from_project()
defer(main)