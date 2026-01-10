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

local main, is_special_track, calc_curve_val, interpolate_val, get_track_state
local find_track_by_GUID, apply_track_state, create_snapshot, get_morph_in_name
local delete_user_markers, find_marker_by_name, find_snapshot_by_marker_name, find_prev_rcmix
local find_snapshot_by_pos, del_marker_by_name, del_all_rcmix, restore_all_rcmix
local ensure_marker_exists, recall_snapshot, serialize_table, deserialize_table, save_snapshots_to_project
local load_snapshots_from_project, copy_from_bank, clear_bank, switch_to_bank
local sync_marker_pos, sort_snapshots, draw_table, find_active_and_morph, draw_UI
local check_auto_recall, handle_project_change, get_morph_out_name

local script_name = "Mixer Snapshots"

-- Check for ReaImGui
if not ImGui_CreateContext then
  ShowMessageBox("ReaImGui is required for this script.\nPlease install it via ReaPack.", "Missing Dependency", 0)
  return
end

set_action_options(2)

package.path        = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui         = require 'imgui' '0.10'

-- Global state
local ctx = ImGui.CreateContext(script_name)
local snapshots = {}
local selected_snapshot = nil
local last_play_pos = -1
local last_edit_pos = -1
local is_playing = false
local snapshot_counter = 0
local current_bank = "A" -- Current active bank (A, B, C, or D)
local last_recalled_snapshot = nil
local last_morph_factor = nil

-- Position sync throttling
local sync_counter = 0
local sync_interval = 30 -- Check every 30 frames (~once per second at 30fps)

-- UI state
local show_window = true
local editing_row = nil
local editing_column = nil
local edit_buffer = ""
local sort_mode = 0        -- 0=marker position, 1=name, 2=time
local sort_direction = nil -- Will be set to ascending after context is created
local jump_to_marker = false
local last_sort_mode = 0
local last_sort_direction = nil

-- New feature flags
local disable_auto_recall = false
local hide_markers = false

-- Selective parameter recall flags (all enabled by default)
local recall_volume = true
local recall_pan = true
local recall_mute = true
local recall_solo = true
local recall_phase = true
local recall_fx = true
local recall_sends = true
local recall_routing = true

-- Column widths: #, Name, Position, In, In Sec, In Curve, Out, Out Sec, Out Curve, Date/Time, Notes
local col_widths = { 35, 180, 80, 40, 60, 100, 40, 60, 100, 140, 250 }

-- Curve type names and suffixes
local curve_types = { "Linear", "Slow", "Fast Start", "Fast End", "Bezier" }
local curve_suffixes = { "", "s", "f", "e", "b" }

---------------------------------------------------------------------

function main()
  handle_project_change()
  check_auto_recall()
  local open = draw_UI()
  if open then defer(main) 
  else
    del_all_rcmix()
  end
end

---------------------------------------------------------------------

function is_special_track(track)
  local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
  local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
  local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
  
  return mixer_state == "y" or aux_state == "y" or submix_state == "y"
end

---------------------------------------------------------------------

function calc_curve_val(t, curve_type)
  if curve_type == "Linear" then
    return t
  elseif curve_type == "Slow" then
    return t * t * (3 - 2 * t)
  elseif curve_type == "Fast Start" then
    return t * t
  elseif curve_type == "Fast End" then
    return 1 - (1 - t) * (1 - t)
  elseif curve_type == "Bezier" then
    return t * t * t
  end
  return t
end

---------------------------------------------------------------------

function interpolate_val(start_val, end_val, t, curve_type)
  local curve_t = calc_curve_val(t, curve_type)
  return start_val + (end_val - start_val) * curve_t
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

function apply_track_state(track, state, morph_factor, source_state)
  if not track then return end

  if morph_factor and source_state then
    if recall_volume then
      local vol = interpolate_val(source_state.volume, state.volume, morph_factor, "Linear")
      SetMediaTrackInfo_Value(track, "D_VOL", vol)
    end

    if recall_pan then
      local pan = interpolate_val(source_state.pan, state.pan, morph_factor, "Linear")
      SetMediaTrackInfo_Value(track, "D_PAN", pan)
    end

    if recall_fx then
      for fx_idx, fx in pairs(state.fx_chain) do
        if TrackFX_GetCount(track) > fx_idx and source_state.fx_chain[fx_idx] then
          for param_idx, target_value in pairs(fx.params) do
            if source_state.fx_chain[fx_idx].params[param_idx] then
              local start_value = source_state.fx_chain[fx_idx].params[param_idx]
              local interp_value = interpolate_val(start_value, target_value, morph_factor, "Linear")
              TrackFX_SetParam(track, fx_idx, param_idx, interp_value)
            end
          end
        end
      end
    end

    if recall_sends then
      for send_idx, send in pairs(state.sends) do
        if GetTrackNumSends(track, 0) > send_idx and source_state.sends[send_idx] then
          local vol = interpolate_val(source_state.sends[send_idx].volume, send.volume, morph_factor, "Linear")
          local pan = interpolate_val(source_state.sends[send_idx].pan, send.pan, morph_factor, "Linear")
          SetTrackSendInfo_Value(track, 0, send_idx, "D_VOL", vol)
          SetTrackSendInfo_Value(track, 0, send_idx, "D_PAN", pan)
        end
      end
    end

    if morph_factor >= 1.0 then
      if recall_mute then
        SetMediaTrackInfo_Value(track, "B_MUTE", state.mute)
      end
      if recall_solo then
        SetMediaTrackInfo_Value(track, "I_SOLO", state.solo)
      end
      if recall_phase then
        SetMediaTrackInfo_Value(track, "B_PHASE", state.phase)
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
              SetTrackSendInfo_Value(track, 1, i, "B_MUTE", state.hw_outs[i].mute)
            end
          end
        end
      end

      if recall_fx then
        for fx_idx, fx in pairs(state.fx_chain) do
          if TrackFX_GetCount(track) > fx_idx then
            TrackFX_SetEnabled(track, fx_idx, fx.enabled)
          end
        end
      end
    end
  else
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
end

---------------------------------------------------------------------

function create_snapshot(name, notes, start_pos, end_pos, prev_snapshot)
  local snapshot = {}
  snapshot_counter = snapshot_counter + 1
  snapshot.name = name or ("RCmix" .. snapshot_counter)
  snapshot.marker_name = "RCmix" .. snapshot_counter
  snapshot.date = os.date("%Y-%m-%d")
  snapshot.time = os.date("%H:%M:%S")
  snapshot.notes = notes or ""
  snapshot.tracks = {}
  snapshot.marker_pos = start_pos or GetCursorPosition()
  snapshot.is_region = (end_pos ~= nil)
  snapshot.region_end = end_pos
  snapshot.prev_tracks = prev_snapshot and prev_snapshot.tracks or nil

  -- Initialize morph in data (for all snapshots)
  snapshot.morph_in = {
    enabled = false,
    seconds_before = 3.0,
    curve_type = "Linear"
  }
  
  -- Initialize morph out data (only used for regions)
  snapshot.morph_out = {
    enabled = false,
    seconds_after = 3.0,
    curve_type = "Linear"
  }

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    snapshot.tracks[i] = get_track_state(track)
  end

  if not hide_markers then
    if snapshot.is_region then
      AddProjectMarker(0, true, snapshot.marker_pos, end_pos, snapshot.marker_name, -1)
    else
      AddProjectMarker(0, false, snapshot.marker_pos, 0, snapshot.marker_name, -1)
    end
  end

  return snapshot
end

---------------------------------------------------------------------

function get_morph_in_name(morph_data)
  if not morph_data or not morph_data.enabled then return nil end
  local suffix = ""
  for i, ctype in ipairs(curve_types) do
    if ctype == morph_data.curve_type then
      suffix = curve_suffixes[i]
      break
    end
  end
  return "/" .. suffix
end

---------------------------------------------------------------------

function get_morph_out_name(morph_data)
  if not morph_data or not morph_data.enabled then return nil end
  local suffix = ""
  for i, ctype in ipairs(curve_types) do
    if ctype == morph_data.curve_type then
      suffix = curve_suffixes[i]
      break
    end
  end
  return "\\" .. suffix
end

---------------------------------------------------------------------

function delete_user_markers()
  local managed_morph_positions = {}
  
  for _, snap in ipairs(snapshots) do
    if snap.morph_in and snap.morph_in.enabled then
      local morph_pos = snap.marker_pos - snap.morph_in.seconds_before
      managed_morph_positions[morph_pos] = true
    end
    if snap.is_region and snap.morph_out and snap.morph_out.enabled then
      local morph_pos = snap.region_end + snap.morph_out.seconds_after
      managed_morph_positions[morph_pos] = true
    end
  end
  
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = num_markers + num_regions - 1, 0, -1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
    if name:match("^[/\\]") then
      if not managed_morph_positions[pos] then
        DeleteProjectMarker(0, markrgnindexnumber, isrgn)
      end
    end
  end
end

---------------------------------------------------------------------

function find_marker_by_name(marker_name)
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
    if name == marker_name and (name:match("^RCmix%d+$") or name:match("^RCmix%-")) then
      return pos, markrgnindexnumber, isrgn, rgnend
    end
  end
  return nil
end

---------------------------------------------------------------------

function find_snapshot_by_marker_name(marker_name)
  for i, snap in ipairs(snapshots) do
    if snap.marker_name == marker_name then
      return snap, i
    end
  end
  return nil
end

---------------------------------------------------------------------

function find_prev_rcmix(cursor_pos)
  local prev_marker_name = nil
  local prev_marker_pos = -1
  local prev_is_region = false
  local num_markers, num_regions = CountProjectMarkers(0)
  
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, marker_name, markrgnindexnumber = EnumProjectMarkers(i)
    if (marker_name:match("^RCmix%d+$") or marker_name:match("^RCmix%-")) and isrgn then
      if cursor_pos >= pos and cursor_pos < rgnend then
        if pos > prev_marker_pos then
          prev_marker_pos = pos
          prev_marker_name = marker_name
          prev_is_region = true
        end
      end
    end
  end

  if prev_is_region then return prev_marker_name end

  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, marker_name, markrgnindexnumber = EnumProjectMarkers(i)
    if (marker_name:match("^RCmix%d+$") or marker_name:match("^RCmix%-")) and not isrgn then
      if pos <= cursor_pos and pos > prev_marker_pos then
        prev_marker_pos = pos
        prev_marker_name = marker_name
      end
    end
  end

  return prev_marker_name
end

---------------------------------------------------------------------

function find_snapshot_by_pos(cursor_pos)
  local prev_snapshot = nil
  local prev_pos = -1

  for i, snap in ipairs(snapshots) do
    if snap.marker_pos <= cursor_pos then
      if snap.is_region and snap.region_end then
        if cursor_pos >= snap.marker_pos and cursor_pos < snap.region_end then
          if snap.marker_pos > prev_pos then
            prev_pos = snap.marker_pos
            prev_snapshot = snap
          end
        end
      else
        if (not prev_snapshot or not prev_snapshot.is_region) and snap.marker_pos > prev_pos then
          prev_pos = snap.marker_pos
          prev_snapshot = snap
        end
      end
    end
  end

  return prev_snapshot
end

---------------------------------------------------------------------

function del_marker_by_name(marker_name)
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
    if name == marker_name then
      DeleteProjectMarker(0, markrgnindexnumber, isrgn)
      return
    end
  end
end

---------------------------------------------------------------------

function del_all_rcmix()
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = num_markers + num_regions - 1, 0, -1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
    if name:match("^RCmix%d+$") or name:match("^RCmix%-") or name:match("^[/\\]") then
      DeleteProjectMarker(0, markrgnindexnumber, isrgn)
    end
  end
end

---------------------------------------------------------------------

function restore_all_rcmix()
  for i, snap in ipairs(snapshots) do
    if snap.is_region and snap.region_end then
      AddProjectMarker(0, true, snap.marker_pos, snap.region_end, snap.marker_name, -1)
    else
      AddProjectMarker(0, false, snap.marker_pos, 0, snap.marker_name, -1)
    end
    
    if snap.morph_in and snap.morph_in.enabled then
      local morph_name = get_morph_in_name(snap.morph_in)
      if morph_name then
        local morph_pos = snap.marker_pos - snap.morph_in.seconds_before
        AddProjectMarker(0, false, morph_pos, 0, morph_name, -1)
      end
    end
    
    if snap.is_region and snap.morph_out and snap.morph_out.enabled then
      local morph_name = get_morph_out_name(snap.morph_out)
      if morph_name then
        local morph_pos = snap.region_end + snap.morph_out.seconds_after
        AddProjectMarker(0, false, morph_pos, 0, morph_name, -1)
      end
    end
  end
end

---------------------------------------------------------------------

function ensure_marker_exists(snapshot)
  if not snapshot then return end
  if hide_markers then return end

  local marker_pos, marker_idx = find_marker_by_name(snapshot.marker_name)
  if not marker_pos then
    if snapshot.is_region and snapshot.region_end then
      AddProjectMarker(0, true, snapshot.marker_pos, snapshot.region_end, snapshot.marker_name, -1)
    else
      AddProjectMarker(0, false, snapshot.marker_pos, 0, snapshot.marker_name, -1)
    end
  end
  
  if snapshot.morph_in and snapshot.morph_in.enabled then
    local morph_name = get_morph_in_name(snapshot.morph_in)
    if morph_name then
      local morph_pos = snapshot.marker_pos - snapshot.morph_in.seconds_before
      local found = false
      local num_markers, num_regions = CountProjectMarkers(0)
      for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
        if name == morph_name and math.abs(pos - morph_pos) < 0.1 then
          found = true
          break
        end
      end
      if not found then
        AddProjectMarker(0, false, morph_pos, 0, morph_name, -1)
      end
    end
  end
  
  if snapshot.is_region and snapshot.morph_out and snapshot.morph_out.enabled then
    local morph_name = get_morph_out_name(snapshot.morph_out)
    if morph_name then
      local morph_pos = snapshot.region_end + snapshot.morph_out.seconds_after
      local found = false
      local num_markers, num_regions = CountProjectMarkers(0)
      for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
        if name == morph_name and math.abs(pos - morph_pos) < 0.1 then
          found = true
          break
        end
      end
      if not found then
        AddProjectMarker(0, false, morph_pos, 0, morph_name, -1)
      end
    end
  end
end

---------------------------------------------------------------------

function recall_snapshot(snapshot, should_jump, morph_factor, source_snapshot)
  if not snapshot then return end

  if not disable_auto_recall and not hide_markers then
    ensure_marker_exists(snapshot)
  end

  if should_jump and jump_to_marker then
    SetEditCurPos(snapshot.marker_pos + 0.001, true, true)
  end

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if snapshot.tracks[i] then
      local source_state = (morph_factor and source_snapshot and source_snapshot.tracks[i]) or nil
      apply_track_state(track, snapshot.tracks[i], morph_factor, source_state)
    end
  end

  -- Only update UI if snapshot changed or morph factor changed significantly
  local should_update = false
  if snapshot ~= last_recalled_snapshot then
    should_update = true
  elseif morph_factor then
    if not last_morph_factor or math.abs(morph_factor - last_morph_factor) > 0.05 then
      should_update = true
    end
  end
  
  if should_update then
    UpdateArrange()
    TrackList_AdjustWindows(false)
    last_recalled_snapshot = snapshot
    last_morph_factor = morph_factor
  end
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
  local func, err = load("return " .. str)
  if func then return func() else return nil end
end

---------------------------------------------------------------------

function save_snapshots_to_project()
  local data = {}
  data.counter = snapshot_counter
  data.snapshots = {}
  data.disable_auto_recall = disable_auto_recall
  data.hide_markers = hide_markers
  data.recall_volume = recall_volume
  data.recall_pan = recall_pan
  data.recall_mute = recall_mute
  data.recall_solo = recall_solo
  data.recall_phase = recall_phase
  data.recall_fx = recall_fx
  data.recall_sends = recall_sends
  data.recall_routing = recall_routing

  for i, snap in ipairs(snapshots) do
    local s = {
      name = snap.name,
      marker_name = snap.marker_name,
      date = snap.date,
      time = snap.time,
      notes = snap.notes,
      marker_pos = snap.marker_pos,
      tracks = snap.tracks,
      is_region = snap.is_region,
      region_end = snap.region_end,
      prev_tracks = snap.prev_tracks,
      morph_in = snap.morph_in,
      morph_out = snap.morph_out
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
      hide_markers = data.hide_markers or false
      recall_volume = data.recall_volume ~= false
      recall_pan = data.recall_pan ~= false
      recall_mute = data.recall_mute ~= false
      recall_solo = data.recall_solo ~= false
      recall_phase = data.recall_phase ~= false
      recall_fx = data.recall_fx ~= false
      recall_sends = data.recall_sends ~= false
      recall_routing = data.recall_routing ~= false

      for i, s in ipairs(data.snapshots or {}) do
        if not s.morph_in then
          s.morph_in = { enabled = false, seconds_before = 3.0, curve_type = "Linear" }
        else
          s.morph_in.seconds_before = math.floor((s.morph_in.seconds_before or 3.0) * 100 + 0.5) / 100
        end
        if not s.morph_out then
          s.morph_out = { enabled = false, seconds_after = 3.0, curve_type = "Linear" }
        else
          s.morph_out.seconds_after = math.floor((s.morph_out.seconds_after or 3.0) * 100 + 0.5) / 100
        end
        table.insert(snapshots, s)
      end

      if not hide_markers then
        for i, snap in ipairs(snapshots) do
          ensure_marker_exists(snap)
        end
      end
      
      delete_user_markers()
      
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
      for i, s in ipairs(data.snapshots or {}) do
        if not s.morph_in then
          s.morph_in = { enabled = false, seconds_before = 3.0, curve_type = "Linear" }
        else
          s.morph_in.seconds_before = math.floor((s.morph_in.seconds_before or 3.0) * 100 + 0.5) / 100
        end
        if not s.morph_out then
          s.morph_out = { enabled = false, seconds_after = 3.0, curve_type = "Linear" }
        else
          s.morph_out.seconds_after = math.floor((s.morph_out.seconds_after or 3.0) * 100 + 0.5) / 100
        end
        table.insert(snapshots, s)
      end
      save_snapshots_to_project()
      if not hide_markers and not disable_auto_recall then
        restore_all_rcmix()
      end
    end
  end
end

---------------------------------------------------------------------

function clear_bank()
  del_all_rcmix()
  snapshots = {}
  snapshot_counter = 0
  selected_snapshot = nil
  save_snapshots_to_project()
end

---------------------------------------------------------------------

function switch_to_bank(new_bank)
  if new_bank == current_bank then return end
  save_snapshots_to_project()
  del_all_rcmix()
  current_bank = new_bank
  selected_snapshot = nil
  load_snapshots_from_project()
end

---------------------------------------------------------------------

function sync_marker_pos()
  if hide_markers then return end
  
  local marker_map = {}
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
    marker_map[name] = {pos = pos, rgnend = rgnend, isrgn = isrgn}
  end
  
  local changed = false
  for _, snap in ipairs(snapshots) do
    local marker_data = marker_map[snap.marker_name]
    if marker_data then
      -- Use larger tolerance to avoid constant tiny changes
      if math.abs(marker_data.pos - snap.marker_pos) > 0.01 then
        snap.marker_pos = marker_data.pos
        changed = true
      end
      if snap.is_region and marker_data.rgnend and math.abs(marker_data.rgnend - snap.region_end) > 0.01 then
        snap.region_end = marker_data.rgnend
        changed = true
      end
    end
    
    if snap.morph_in and snap.morph_in.enabled then
      local morph_name = get_morph_in_name(snap.morph_in)
      if morph_name then
        local morph_data = marker_map[morph_name]
        if morph_data then
          local new_seconds_before = snap.marker_pos - morph_data.pos
          new_seconds_before = math.floor(new_seconds_before * 100 + 0.5) / 100
          if new_seconds_before > 0 and math.abs(new_seconds_before - snap.morph_in.seconds_before) > 0.02 then
            snap.morph_in.seconds_before = new_seconds_before
            changed = true
          end
        end
      end
    end
    
    if snap.is_region and snap.morph_out and snap.morph_out.enabled then
      local morph_name = get_morph_out_name(snap.morph_out)
      if morph_name then
        local morph_data = marker_map[morph_name]
        if morph_data then
          local new_seconds_after = morph_data.pos - snap.region_end
          new_seconds_after = math.floor(new_seconds_after * 100 + 0.5) / 100
          if new_seconds_after > 0 and math.abs(new_seconds_after - snap.morph_out.seconds_after) > 0.02 then
            snap.morph_out.seconds_after = new_seconds_after
            changed = true
          end
        end
      end
    end
  end
  
  -- Only save if something actually changed
  if changed then
    save_snapshots_to_project()
  end
end

---------------------------------------------------------------------

function sort_snapshots()
  local ascending = (sort_direction == ImGui.SortDirection_Ascending)
  if sort_mode == 0 then
    table.sort(snapshots, function(a, b)
      if ascending then
        return a.marker_pos < b.marker_pos
      else
        return a.marker_pos > b.marker_pos
      end
    end)
  elseif sort_mode == 1 then
    table.sort(snapshots, function(a, b)
      if ascending then
        return a.name < b.name
      else
        return a.name > b.name
      end
    end)
  elseif sort_mode == 2 then
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

  if ImGui.BeginTable(ctx, "SnapshotsTable", 11, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_Resizable) then
    ImGui.TableSetupColumn(ctx, "#", ImGui.TableColumnFlags_WidthFixed, col_widths[1])
    ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthFixed, col_widths[2])
    ImGui.TableSetupColumn(ctx, "Position", ImGui.TableColumnFlags_WidthFixed, col_widths[3])
    ImGui.TableSetupColumn(ctx, "In", ImGui.TableColumnFlags_WidthFixed, col_widths[4])
    ImGui.TableSetupColumn(ctx, "In Sec", ImGui.TableColumnFlags_WidthFixed, col_widths[5])
    ImGui.TableSetupColumn(ctx, "In Curve", ImGui.TableColumnFlags_WidthFixed, col_widths[6])
    ImGui.TableSetupColumn(ctx, "Out", ImGui.TableColumnFlags_WidthFixed, col_widths[7])
    ImGui.TableSetupColumn(ctx, "Out Sec", ImGui.TableColumnFlags_WidthFixed, col_widths[8])
    ImGui.TableSetupColumn(ctx, "Out Curve", ImGui.TableColumnFlags_WidthFixed, col_widths[9])
    ImGui.TableSetupColumn(ctx, "Date/Time", ImGui.TableColumnFlags_WidthFixed, col_widths[10])
    ImGui.TableSetupColumn(ctx, "Notes", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableHeadersRow(ctx)

    for i, snap in ipairs(snapshots) do
      ImGui.TableNextRow(ctx)
      ImGui.PushID(ctx, i)

      -- Column 0: Index
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.PushID(ctx, "index_sel")
      if ImGui.Selectable(ctx, tostring(i), selected_snapshot == snap) then
        selected_snapshot = snap
        recall_snapshot(snap, true)
      end
      ImGui.PopID(ctx)

      -- Column 1: Name
      ImGui.TableSetColumnIndex(ctx, 1)
      if editing_row == i and editing_column == 1 then
        ImGui.SetKeyboardFocusHere(ctx)
        ImGui.PushID(ctx, "edit_name")
        local rv, new_text = ImGui.InputText(ctx, "##edit", edit_buffer, ImGui.InputTextFlags_EnterReturnsTrue)
        ImGui.PopID(ctx)
        if rv then edit_buffer = new_text end
        if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
          editing_row = nil
          editing_column = nil
        elseif ImGui.IsItemDeactivatedAfterEdit(ctx) then
          if edit_buffer ~= snap.name then
            del_marker_by_name(snap.marker_name)
            snap.name = edit_buffer
            snap.marker_name = edit_buffer:match("^RCmix%d+$") and edit_buffer or ("RCmix-" .. edit_buffer)
            if not hide_markers then
              if snap.is_region and snap.region_end then
                AddProjectMarker(0, true, snap.marker_pos, snap.region_end, snap.marker_name, -1)
              else
                AddProjectMarker(0, false, snap.marker_pos, 0, snap.marker_name, -1)
              end
            end
            save_snapshots_to_project()
          end
          editing_row = nil
          editing_column = nil
        end
      else
        ImGui.PushID(ctx, "name_sel")
        if ImGui.Selectable(ctx, snap.name, selected_snapshot == snap) then
          selected_snapshot = snap
          recall_snapshot(snap, true)
        end
        ImGui.PopID(ctx)
        if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
          editing_row = i
          editing_column = 1
          edit_buffer = snap.name
        end
      end

      -- Column 2: Position
      ImGui.TableSetColumnIndex(ctx, 2)
      local minutes = math.floor(snap.marker_pos / 60)
      local seconds = snap.marker_pos % 60
      ImGui.PushID(ctx, "pos_sel")
      if ImGui.Selectable(ctx, string.format("%d:%05.2f", minutes, seconds), selected_snapshot == snap) then
        selected_snapshot = snap
        recall_snapshot(snap, true)
      end
      ImGui.PopID(ctx)

      -- Column 3: Morph In checkbox
      ImGui.TableSetColumnIndex(ctx, 3)
      ImGui.PushID(ctx, "morph_in_check")
      local morph_in_enabled = snap.morph_in and snap.morph_in.enabled or false
      local rv_morph_in, new_morph_in = ImGui.Checkbox(ctx, "##morphin", morph_in_enabled)
      if rv_morph_in then
        if not snap.morph_in then
          snap.morph_in = { enabled = new_morph_in, seconds_before = 3.0, curve_type = "Linear" }
        else
          snap.morph_in.enabled = new_morph_in
        end
        
        if new_morph_in and not hide_markers then
          local morph_name = get_morph_in_name(snap.morph_in)
          if morph_name then
            local morph_pos = snap.marker_pos - snap.morph_in.seconds_before
            AddProjectMarker(0, false, morph_pos, 0, morph_name, -1)
          end
        elseif not new_morph_in then
          local morph_pos = snap.marker_pos - snap.morph_in.seconds_before
          local num_markers, num_regions = CountProjectMarkers(0)
          for m = num_markers + num_regions - 1, 0, -1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
            if name:match("^/") and math.abs(pos - morph_pos) < 0.1 then
              DeleteProjectMarker(0, markrgnindexnumber, isrgn)
              break
            end
          end
        end
        save_snapshots_to_project()
      end
      ImGui.PopID(ctx)

      -- Column 4: Morph In seconds
      ImGui.TableSetColumnIndex(ctx, 4)
      if snap.morph_in and snap.morph_in.enabled then
        ImGui.PushID(ctx, "seconds_in")
        ImGui.SetNextItemWidth(ctx, 50)
        local seconds_display = string.format("%.2f", snap.morph_in.seconds_before)
        
        if editing_row == i and editing_column == 4 then
          ImGui.SetKeyboardFocusHere(ctx)
          local rv, new_text = ImGui.InputText(ctx, "##sec", edit_buffer, ImGui.InputTextFlags_EnterReturnsTrue)
          if rv then edit_buffer = new_text end
          if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
            editing_row, editing_column = nil, nil
          elseif ImGui.IsItemDeactivatedAfterEdit(ctx) then
            local new_seconds = tonumber(edit_buffer)
            if new_seconds and new_seconds > 0 then
              new_seconds = math.floor(new_seconds * 100 + 0.5) / 100
              if math.abs(new_seconds - snap.morph_in.seconds_before) > 0.01 then
                local old_morph_pos = snap.marker_pos - snap.morph_in.seconds_before
                local num_markers, num_regions = CountProjectMarkers(0)
                for m = num_markers + num_regions - 1, 0, -1 do
                  local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
                  if name:match("^/") and math.abs(pos - old_morph_pos) < 0.1 then
                    DeleteProjectMarker(0, markrgnindexnumber, isrgn)
                    break
                  end
                end
                snap.morph_in.seconds_before = new_seconds
                if not hide_markers then
                  local morph_name = get_morph_in_name(snap.morph_in)
                  if morph_name then
                    AddProjectMarker(0, false, snap.marker_pos - new_seconds, 0, morph_name, -1)
                  end
                end
                save_snapshots_to_project()
              end
            end
            editing_row, editing_column = nil, nil
          end
        else
          if ImGui.Selectable(ctx, seconds_display, selected_snapshot == snap) then end
          if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
            editing_row, editing_column, edit_buffer = i, 4, seconds_display
          end
        end
        ImGui.PopID(ctx)
      else
        ImGui.Text(ctx, "")
      end

      -- Column 5: Morph In curve
      ImGui.TableSetColumnIndex(ctx, 5)
      if snap.morph_in and snap.morph_in.enabled then
        ImGui.PushID(ctx, "curve_in_combo")
        ImGui.SetNextItemWidth(ctx, 90)
        local current_idx = 0
        for idx, ctype in ipairs(curve_types) do
          if ctype == snap.morph_in.curve_type then current_idx = idx - 1; break end
        end
        if ImGui.BeginCombo(ctx, "##curvein", curve_types[current_idx + 1]) then
          for idx, ctype in ipairs(curve_types) do
            local is_selected = (idx - 1 == current_idx)
            if ImGui.Selectable(ctx, ctype, is_selected) then
              local old_morph_pos = snap.marker_pos - snap.morph_in.seconds_before
              local num_markers, num_regions = CountProjectMarkers(0)
              for m = num_markers + num_regions - 1, 0, -1 do
                local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
                if name:match("^/") and math.abs(pos - old_morph_pos) < 0.1 then
                  DeleteProjectMarker(0, markrgnindexnumber, isrgn)
                  break
                end
              end
              snap.morph_in.curve_type = ctype
              if not hide_markers then
                local morph_name = get_morph_in_name(snap.morph_in)
                if morph_name then
                  AddProjectMarker(0, false, old_morph_pos, 0, morph_name, -1)
                end
              end
              save_snapshots_to_project()
            end
            if is_selected then ImGui.SetItemDefaultFocus(ctx) end
          end
          ImGui.EndCombo(ctx)
        end
        ImGui.PopID(ctx)
      else
        ImGui.Text(ctx, "")
      end

      -- Column 6: Morph Out checkbox (regions only)
      ImGui.TableSetColumnIndex(ctx, 6)
      if snap.is_region then
        ImGui.PushID(ctx, "morph_out_check")
        local morph_out_enabled = snap.morph_out and snap.morph_out.enabled or false
        local rv_morph_out, new_morph_out = ImGui.Checkbox(ctx, "##morphout", morph_out_enabled)
        if rv_morph_out then
          if not snap.morph_out then
            snap.morph_out = { enabled = new_morph_out, seconds_after = 3.0, curve_type = "Linear" }
          else
            snap.morph_out.enabled = new_morph_out
          end
          
          if new_morph_out and not hide_markers then
            local morph_name = get_morph_out_name(snap.morph_out)
            if morph_name then
              local morph_pos = snap.region_end + snap.morph_out.seconds_after
              AddProjectMarker(0, false, morph_pos, 0, morph_name, -1)
            end
          elseif not new_morph_out then
            local morph_pos = snap.region_end + snap.morph_out.seconds_after
            local num_markers, num_regions = CountProjectMarkers(0)
            for m = num_markers + num_regions - 1, 0, -1 do
              local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
              if name:match("^\\") and math.abs(pos - morph_pos) < 0.1 then
                DeleteProjectMarker(0, markrgnindexnumber, isrgn)
                break
              end
            end
          end
          save_snapshots_to_project()
        end
        ImGui.PopID(ctx)
      else
        ImGui.Text(ctx, "")
      end

      -- Column 7: Morph Out seconds (regions only)
      ImGui.TableSetColumnIndex(ctx, 7)
      if snap.is_region and snap.morph_out and snap.morph_out.enabled then
        ImGui.PushID(ctx, "seconds_out")
        ImGui.SetNextItemWidth(ctx, 50)
        local seconds_display = string.format("%.2f", snap.morph_out.seconds_after)
        
        if editing_row == i and editing_column == 7 then
          ImGui.SetKeyboardFocusHere(ctx)
          local rv, new_text = ImGui.InputText(ctx, "##sec", edit_buffer, ImGui.InputTextFlags_EnterReturnsTrue)
          if rv then edit_buffer = new_text end
          if ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
            editing_row, editing_column = nil, nil
          elseif ImGui.IsItemDeactivatedAfterEdit(ctx) then
            local new_seconds = tonumber(edit_buffer)
            if new_seconds and new_seconds > 0 then
              new_seconds = math.floor(new_seconds * 100 + 0.5) / 100
              if math.abs(new_seconds - snap.morph_out.seconds_after) > 0.01 then
                local old_morph_pos = snap.region_end + snap.morph_out.seconds_after
                local num_markers, num_regions = CountProjectMarkers(0)
                for m = num_markers + num_regions - 1, 0, -1 do
                  local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
                  if name:match("^\\") and math.abs(pos - old_morph_pos) < 0.1 then
                    DeleteProjectMarker(0, markrgnindexnumber, isrgn)
                    break
                  end
                end
                snap.morph_out.seconds_after = new_seconds
                if not hide_markers then
                  local morph_name = get_morph_out_name(snap.morph_out)
                  if morph_name then
                    AddProjectMarker(0, false, snap.region_end + new_seconds, 0, morph_name, -1)
                  end
                end
                save_snapshots_to_project()
              end
            end
            editing_row, editing_column = nil, nil
          end
        else
          if ImGui.Selectable(ctx, seconds_display, selected_snapshot == snap) then end
          if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
            editing_row, editing_column, edit_buffer = i, 7, seconds_display
          end
        end
        ImGui.PopID(ctx)
      else
        ImGui.Text(ctx, "")
      end

      -- Column 8: Morph Out curve (regions only)
      ImGui.TableSetColumnIndex(ctx, 8)
      if snap.is_region and snap.morph_out and snap.morph_out.enabled then
        ImGui.PushID(ctx, "curve_out_combo")
        ImGui.SetNextItemWidth(ctx, 90)
        local current_idx = 0
        for idx, ctype in ipairs(curve_types) do
          if ctype == snap.morph_out.curve_type then current_idx = idx - 1; break end
        end
        if ImGui.BeginCombo(ctx, "##curveout", curve_types[current_idx + 1]) then
          for idx, ctype in ipairs(curve_types) do
            local is_selected = (idx - 1 == current_idx)
            if ImGui.Selectable(ctx, ctype, is_selected) then
              local old_morph_pos = snap.region_end + snap.morph_out.seconds_after
              local num_markers, num_regions = CountProjectMarkers(0)
              for m = num_markers + num_regions - 1, 0, -1 do
                local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
                if name:match("^\\") and math.abs(pos - old_morph_pos) < 0.1 then
                  DeleteProjectMarker(0, markrgnindexnumber, isrgn)
                  break
                end
              end
              snap.morph_out.curve_type = ctype
              if not hide_markers then
                local morph_name = get_morph_out_name(snap.morph_out)
                if morph_name then
                  AddProjectMarker(0, false, old_morph_pos, 0, morph_name, -1)
                end
              end
              save_snapshots_to_project()
            end
            if is_selected then ImGui.SetItemDefaultFocus(ctx) end
          end
          ImGui.EndCombo(ctx)
        end
        ImGui.PopID(ctx)
      else
        ImGui.Text(ctx, "")
      end

      -- Column 9: Date/Time
      ImGui.TableSetColumnIndex(ctx, 9)
      ImGui.PushID(ctx, "time_sel")
      if ImGui.Selectable(ctx, snap.date .. " " .. snap.time, selected_snapshot == snap) then
        selected_snapshot = snap
        recall_snapshot(snap, true)
      end
      ImGui.PopID(ctx)

      -- Column 10: Notes
      ImGui.TableSetColumnIndex(ctx, 10)
      if editing_row == i and editing_column == 10 then
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
          recall_snapshot(snap, true)
        end
        ImGui.PopID(ctx)
        if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
          editing_row, editing_column, edit_buffer = i, 10, snap.notes
        end
      end

      ImGui.PopID(ctx)
    end

    ImGui.EndTable(ctx)
  end
end

---------------------------------------------------------------------

function find_active_and_morph(cursor_pos)
  local active_snapshot = nil
  local morph_source = nil
  local morph_factor = nil
  
  local sorted_snaps = {}
  for _, snap in ipairs(snapshots) do
    table.insert(sorted_snaps, snap)
  end
  table.sort(sorted_snaps, function(a, b) return a.marker_pos < b.marker_pos end)
  
  for i, snap in ipairs(sorted_snaps) do
    -- Check if morphing INTO this snapshot
    if snap.morph_in and snap.morph_in.enabled then
      local morph_start = snap.marker_pos - snap.morph_in.seconds_before
      if cursor_pos >= morph_start and cursor_pos < snap.marker_pos then
        -- We're in the morph zone
        active_snapshot = snap
        if i > 1 then morph_source = sorted_snaps[i - 1] end
        local morph_duration = snap.marker_pos - morph_start
        if morph_duration > 0 then
          morph_factor = (cursor_pos - morph_start) / morph_duration
          morph_factor = calc_curve_val(math.max(0, math.min(1, morph_factor)), snap.morph_in.curve_type)
        else
          morph_factor = 1.0
        end
        return active_snapshot, morph_source, morph_factor
      end
    end
    
    -- Check if we're at or past this snapshot
    if cursor_pos >= snap.marker_pos then
      if snap.is_region and snap.region_end then
        if cursor_pos < snap.region_end then
          -- Inside the region - this is our active snapshot
          active_snapshot = snap
          -- Don't return yet - keep checking for morph out zones
        elseif snap.morph_out and snap.morph_out.enabled then
          -- Check if morphing OUT of this region
          local morph_end = snap.region_end + snap.morph_out.seconds_after
          if cursor_pos >= snap.region_end and cursor_pos < morph_end then
            local next_snap = sorted_snaps[i + 1]
            if next_snap then
              active_snapshot = next_snap
              morph_source = snap
              local morph_duration = snap.morph_out.seconds_after
              if morph_duration > 0 then
                morph_factor = (cursor_pos - snap.region_end) / morph_duration
                morph_factor = calc_curve_val(math.max(0, math.min(1, morph_factor)), snap.morph_out.curve_type)
              else
                morph_factor = 1.0
              end
              return active_snapshot, morph_source, morph_factor
            end
          end
        end
      elseif not snap.is_region then
        -- Regular marker - update active snapshot
        active_snapshot = snap
      end
    end
  end
  
  return active_snapshot, nil, nil
end

---------------------------------------------------------------------

function draw_UI()
  ImGui.SetNextWindowSize(ctx, 1150, 0, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, script_name, true)
  if visible then
    if ImGui.BeginTabBar(ctx, "Banks") then
      for _, bank in ipairs({"A", "B", "C", "D"}) do
        if ImGui.BeginTabItem(ctx, "     " .. bank .. "     ") then
          if current_bank ~= bank then switch_to_bank(bank) end
          ImGui.EndTabItem(ctx)
        end
      end
      ImGui.EndTabBar(ctx)
    end

    ImGui.Text(ctx, "Copy from:")
    ImGui.SameLine(ctx)
    for _, bank in ipairs({"A", "B", "C", "D"}) do
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

    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local has_time_sel = (end_time - start_time) > 0.001
    local button_label = has_time_sel and "New snapshot in time selection" or "New snapshot at edit cursor"

    if ImGui.Button(ctx, button_label) then
      Undo_BeginBlock()
      if has_time_sel then
        local prev_snapshot
        if hide_markers then
          prev_snapshot = find_snapshot_by_pos(start_time)
        else
          local prev_marker_name = find_prev_rcmix(start_time)
          if prev_marker_name then prev_snapshot = find_snapshot_by_marker_name(prev_marker_name) end
        end
        local snap = create_snapshot(nil, nil, start_time, end_time, prev_snapshot)
        table.insert(snapshots, snap)
        selected_snapshot = snap
        GetSet_LoopTimeRange(true, false, 0, 0, false)
      else
        local snap = create_snapshot()
        table.insert(snapshots, snap)
        selected_snapshot = snap
      end
      save_snapshots_to_project()
      Undo_EndBlock("Create Mixer Snapshot", -1)
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Update Selected") then
      if selected_snapshot then
        Undo_BeginBlock()
        selected_snapshot.tracks = {}
        for i = 0, CountTracks(0) - 1 do
          selected_snapshot.tracks[i] = get_track_state(GetTrack(0, i))
        end
        selected_snapshot.date = os.date("%Y-%m-%d")
        selected_snapshot.time = os.date("%H:%M:%S")
        save_snapshots_to_project()
        Undo_EndBlock("Update Mixer Snapshot", -1)
      end
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Duplicate Selected") then
      if selected_snapshot then
        Undo_BeginBlock()
        snapshot_counter = snapshot_counter + 1
        local new_snap = {
          name = "RCmix" .. snapshot_counter,
          marker_name = "RCmix" .. snapshot_counter,
          date = os.date("%Y-%m-%d"),
          time = os.date("%H:%M:%S"),
          notes = selected_snapshot.notes,
          marker_pos = GetCursorPosition(),
          morph_in = { enabled = false, seconds_before = 3.0, curve_type = "Linear" },
          morph_out = { enabled = false, seconds_after = 3.0, curve_type = "Linear" },
          tracks = {}
        }
        for i, track_state in pairs(selected_snapshot.tracks) do
          new_snap.tracks[i] = {}
          for k, v in pairs(track_state) do
            if k == "fx_chain" then
              new_snap.tracks[i].fx_chain = {}
              for fx_idx, fx in pairs(v) do
                new_snap.tracks[i].fx_chain[fx_idx] = {
                  enabled = fx.enabled,
                  name = fx.name,
                  params = {}
                }
                for p_idx, p_val in pairs(fx.params) do
                  new_snap.tracks[i].fx_chain[fx_idx].params[p_idx] = p_val
                end
              end
            elseif k == "sends" then
              new_snap.tracks[i].sends = {}
              for send_idx, send in pairs(v) do
                new_snap.tracks[i].sends[send_idx] = {}
                for send_k, send_v in pairs(send) do
                  new_snap.tracks[i].sends[send_idx][send_k] = send_v
                end
              end
            else
              new_snap.tracks[i][k] = v
            end
          end
        end
        if not hide_markers then
          AddProjectMarker(0, false, new_snap.marker_pos, 0, new_snap.marker_name, -1)
        end
        table.insert(snapshots, new_snap)
        selected_snapshot = new_snap
        save_snapshots_to_project()
        Undo_EndBlock("Duplicate Mixer Snapshot", -1)
      end
    end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Delete Selected") then
      if selected_snapshot then
        Undo_BeginBlock()
        del_marker_by_name(selected_snapshot.marker_name)
        
        if selected_snapshot.morph_in and selected_snapshot.morph_in.enabled then
          local morph_pos = selected_snapshot.marker_pos - selected_snapshot.morph_in.seconds_before
          local num_markers, num_regions = CountProjectMarkers(0)
          for m = num_markers + num_regions - 1, 0, -1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
            if name:match("^/") and math.abs(pos - morph_pos) < 0.1 then
              DeleteProjectMarker(0, markrgnindexnumber, isrgn)
              break
            end
          end
        end
        
        if selected_snapshot.is_region and selected_snapshot.morph_out and selected_snapshot.morph_out.enabled then
          local morph_pos = selected_snapshot.region_end + selected_snapshot.morph_out.seconds_after
          local num_markers, num_regions = CountProjectMarkers(0)
          for m = num_markers + num_regions - 1, 0, -1 do
            local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(m)
            if name:match("^\\") and math.abs(pos - morph_pos) < 0.1 then
              DeleteProjectMarker(0, markrgnindexnumber, isrgn)
              break
            end
          end
        end

        for i, snap in ipairs(snapshots) do
          if snap == selected_snapshot then
            table.remove(snapshots, i)
            selected_snapshot = nil
            break
          end
        end
        save_snapshots_to_project()
        Undo_EndBlock("Delete Mixer Snapshot", -1)
      end
    end

    ImGui.Separator(ctx)

    ImGui.Text(ctx, "Sort by:")
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Position", sort_mode == 0) then sort_mode = 0 end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Name", sort_mode == 1) then sort_mode = 1 end
    ImGui.SameLine(ctx)
    if ImGui.RadioButton(ctx, "Time", sort_mode == 2) then sort_mode = 2 end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    local dir_label = sort_direction == ImGui.SortDirection_Ascending and "Ascending ▲" or "Descending ▼"
    if ImGui.Button(ctx, dir_label) then
      sort_direction = sort_direction == ImGui.SortDirection_Ascending and ImGui.SortDirection_Descending or ImGui.SortDirection_Ascending
    end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    local rv, new_val = ImGui.Checkbox(ctx, "Jump to marker on recall", jump_to_marker)
    if rv then jump_to_marker = new_val end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 20, 0); ImGui.SameLine(ctx)
    local rv_disable, new_disable = ImGui.Checkbox(ctx, "Disable auto-recall", disable_auto_recall)
    if rv_disable then
      disable_auto_recall = new_disable
      if disable_auto_recall then
        del_all_rcmix()
        hide_markers = false
      else
        if not hide_markers then restore_all_rcmix() end
      end
      save_snapshots_to_project()
    end
    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 10, 0); ImGui.SameLine(ctx)
    if disable_auto_recall then ImGui.BeginDisabled(ctx) end
    local rv_hide, new_hide = ImGui.Checkbox(ctx, "Hide markers", hide_markers)
    if rv_hide then
      hide_markers = new_hide
      if hide_markers then del_all_rcmix() else restore_all_rcmix() end
      save_snapshots_to_project()
    end
    if disable_auto_recall then ImGui.EndDisabled(ctx) end

    ImGui.Separator(ctx)
    draw_table()
    ImGui.Separator(ctx)

    ImGui.Text(ctx, "Recall:")
    ImGui.SameLine(ctx)
    for _, param in ipairs({
      {"Volume", recall_volume, function(v) recall_volume = v end},
      {"Pan", recall_pan, function(v) recall_pan = v end},
      {"Mute", recall_mute, function(v) recall_mute = v end},
      {"Solo", recall_solo, function(v) recall_solo = v end},
      {"Phase", recall_phase, function(v) recall_phase = v end},
      {"FX", recall_fx, function(v) recall_fx = v end},
      {"Send Levels", recall_sends, function(v) recall_sends = v end},
      {"Send Routing", recall_routing, function(v) recall_routing = v end}
    }) do
      local rv, new_val = ImGui.Checkbox(ctx, param[1], param[2])
      if rv then param[3](new_val); save_snapshots_to_project() end
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

  sync_counter = sync_counter + 1
  if sync_counter >= sync_interval then
    sync_counter = 0
    sync_marker_pos()
  end

  if current_playing then
    local play_pos = GetPlayPosition()
    if last_play_pos >= 0 and math.abs(play_pos - last_play_pos) > 0.001 then
      local active_snap, morph_source, morph_factor = find_active_and_morph(play_pos)
      if active_snap then
        if morph_factor then
          -- Only update during morph, don't change selected snapshot
          recall_snapshot(active_snap, false, morph_factor, morph_source)
        else
          -- Only recall if snapshot actually changed
          if active_snap ~= selected_snapshot then
            recall_snapshot(active_snap, false)
            selected_snapshot = active_snap
          end
        end
      end
    end
    last_play_pos = play_pos
    is_playing = true
  else
    -- Check edit cursor position (whether we just stopped or not)
    local edit_pos = GetCursorPosition()
    
    if is_playing then
      -- Just stopped playing - force immediate check at new cursor position
      is_playing = false
      last_play_pos = -1
      last_edit_pos = -1
      last_recalled_snapshot = nil
      last_morph_factor = nil
      
      -- Immediately check where we are now
      local active_snap, morph_source, morph_factor = find_active_and_morph(edit_pos)
      if active_snap then
        recall_snapshot(active_snap, false, morph_factor, morph_source)
        selected_snapshot = active_snap
      end
      last_edit_pos = edit_pos
    elseif math.abs(edit_pos - last_edit_pos) > 0.001 then
      -- Edit cursor moved while stopped
      last_edit_pos = edit_pos
      local active_snap, morph_source, morph_factor = find_active_and_morph(edit_pos)
      if active_snap then
        if morph_factor then
          recall_snapshot(active_snap, false, morph_factor, morph_source)
          if active_snap ~= selected_snapshot then
            selected_snapshot = active_snap
          end
        else
          if active_snap ~= selected_snapshot or last_morph_factor then
            recall_snapshot(active_snap, false)
            selected_snapshot = active_snap
          end
        end
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
    last_play_pos, last_edit_pos, is_playing = -1, -1, false
    load_snapshots_from_project()
    TrackList_AdjustWindows(false)
    UpdateArrange()
  end
end

---------------------------------------------------------------------

sort_direction = ImGui.SortDirection_Ascending
load_snapshots_from_project()
defer(main)