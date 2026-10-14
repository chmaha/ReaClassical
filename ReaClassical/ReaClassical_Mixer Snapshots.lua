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

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()

if _clara_or_debug then
    dofile(script_path .. "lib/ReaClassical_Accessible Snapshot Settings.lua")
    return
end

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

if not ImGui_CreateContext then
  ShowMessageBox("ReaImGui is required for this script.\nPlease install it via ReaPack.", "Missing Dependency", 0)
  return
end

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua;' .. script_path .. 'lib/?.lua;'
local ImGui     = require 'imgui' '0.10'
local snap_info = require 'ReaClassical_Mixer_Snapshot_Info'
local engine = require 'ReaClassical_Snapshot_Engine'
local snap_automation = require 'ReaClassical_Snapshot_Automation'

local ctx                     = ImGui.CreateContext(script_name)
local snapshots               = {}
local selected_snapshot       = nil
local snapshot_counter        = 0
local current_bank            = "A"
local last_selected_item_guid = nil
local last_edit_cursor_pos    = -1
local last_play_pos           = -1
local is_playing              = false

local editing_row             = nil
local editing_column          = nil
local edit_buffer             = ""
local note_buffers            = {}
local sort_mode               = 0
local sort_direction          = nil
local last_sort_mode          = 0
local last_sort_direction     = nil

local disable_auto_recall     = false
local switch_mid_gap          = true
local allow_daemon_on_close   = true
local automation_detected     = false

local bank_track_guid         = nil

local recall_volume           = true
local recall_pan              = true
local recall_mute             = true
local recall_solo             = true
local recall_phase            = true
local recall_width            = true
local recall_fx               = true
local recall_sends            = true
local recall_routing          = true

local col_widths              = { 35, 250, 140, 350, 90, 60 }

local diff_popup_lines        = {}
local diff_popup_title        = ""

local last_project

function main()
  handle_project_change()
  update_snapshot_names()
  check_for_automation_on_special_tracks()
  check_auto_recall()
  local open = draw_UI()
  local switching = gui_mode.accessible()
  if switching then open = false end
  if open then
    defer(main)
  elseif not disable_auto_recall and allow_daemon_on_close then
    snap_info.ensure_daemon_running(script_path .. "lib/ReaClassical_Mixer Snapshots Daemon.lua")
  end
  if switching then gui_mode.switch_window("ReaClassical_Mixer Snapshots.lua") end
end

function is_special_track(track)
  local checks = {
    "P_EXT:mixer", "P_EXT:rcmaster", "P_EXT:aux", "P_EXT:submix",
    "P_EXT:roomtone", "P_EXT:rcref", "P_EXT:live", "P_EXT:listenback"
  }
  for _, key in ipairs(checks) do
    local _, v = GetSetMediaTrackInfo_String(track, key, "", false)
    if v == "y" then return true end
  end
  local _, nm = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  nm = nm or ""
  return nm:match("^M:") or nm:match("^RCMASTER") or
         nm:match("^@") or nm:match("^#")
end

function check_for_automation_on_special_tracks()
  local has_automation = false

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if is_special_track(track) then
      local num_envelopes = CountTrackEnvelopes(track)
      for env_idx = 0, num_envelopes - 1 do
        local env = GetTrackEnvelope(track, env_idx)

        local _, visible_str = GetSetEnvelopeInfo_String(env, "VISIBLE", "", false)
        local _, active_str = GetSetEnvelopeInfo_String(env, "ACTIVE", "", false)
        local _, arm_str = GetSetEnvelopeInfo_String(env, "ARM", "", false)

        local has_real_points = false
        local pt_count = CountEnvelopePointsEx(env, -1)
        for pi = 0, pt_count - 1 do
            local _, pt_t = GetEnvelopePointEx(env, -1, pi)
            if pt_t > 0.001 then
                has_real_points = true
                break
            end
        end
        if not has_real_points and CountAutomationItems(env) > 0 then
            has_real_points = true
        end

        if (visible_str == "1" or active_str == "1" or arm_str == "1")
            and has_real_points then
          has_automation = true
          break
        end
      end
      if has_automation then break end
    end
  end

  if has_automation and not automation_detected then
    automation_detected = true
    SetProjExtState(0, "ReaClassical", "auto_recall_before_automation_" .. current_bank, tostring(disable_auto_recall))
    disable_auto_recall = true
  elseif not has_automation and automation_detected then
    automation_detected = false
    local retval, saved_state = GetProjExtState(0, "ReaClassical", "auto_recall_before_automation_" .. current_bank)
    if retval > 0 and saved_state ~= "" then
      disable_auto_recall = (saved_state == "true")
    end
    SetProjExtState(0, "ReaClassical", "auto_recall_before_automation_" .. current_bank, "")
  elseif has_automation then
    automation_detected = true
    disable_auto_recall = true
  else
    automation_detected = false
  end
end

function get_track_state(track)
  local state = {}
  state.volume = GetMediaTrackInfo_Value(track, "D_VOL")
  state.pan = GetMediaTrackInfo_Value(track, "D_PAN")
  state.mute = GetMediaTrackInfo_Value(track, "B_MUTE")
  state.solo = GetMediaTrackInfo_Value(track, "I_SOLO")
  state.phase = GetMediaTrackInfo_Value(track, "B_PHASE")
  state.width = GetMediaTrackInfo_Value(track, "D_WIDTH")
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

function find_track_by_GUID(guid)
  return engine.find_track_by_guid(guid)
end

function apply_track_state(track, state)
  engine.apply_track_state(track, state, {
    volume = recall_volume, pan = recall_pan, mute = recall_mute,
    solo = recall_solo, phase = recall_phase, width = recall_width,
    fx = recall_fx, sends = recall_sends, routing = recall_routing,
  })
end

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

function get_item_by_guid(guid)
  return engine.find_item_by_guid(guid)
end

function get_item_position(item_guid)
  local item = get_item_by_guid(item_guid)
  if item then
    return GetMediaItemInfo_Value(item, "D_POSITION")
  end
  return math.huge
end

function get_display_name_from_guid(guid)
  if not guid then return "Unknown" end
  local cleaned = guid:gsub("^{", "")
  local first_segment = cleaned:match("^([^%-]+)")
  return "{" .. (first_segment or guid) .. "}"
end

function update_snapshot_names()
  local needs_save = false

  for _, snap in ipairs(snapshots) do
    local item = get_item_by_guid(snap.item_guid)
    if item then
      local take = GetActiveTake(item)
      local current_name = ""
      if take then
        local _
        _, current_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      end

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

function find_snapshot_with_gap_logic(cursor_pos)
  return engine.find_snapshot_with_gap_logic(snapshots, cursor_pos, switch_mid_gap)
end

function find_snapshot_at_cursor(cursor_pos)
  return engine.find_snapshot_at_cursor(snapshots, cursor_pos)
end

function create_snapshot(item_guid, item_name, notes)
  if not item_guid then return nil end

  local snapshot = {}
  snapshot_counter = snapshot_counter + 1
  snapshot.item_guid = item_guid
  snapshot.item_name = item_name or ""
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

function find_snapshot_by_item_guid(item_guid)
  for i, snap in ipairs(snapshots) do
    if snap.item_guid == item_guid then
      return snap, i
    end
  end
  return nil
end

function refresh_snapshot_items()
  if sort_mode == 0 then
    last_sort_mode = -1
  end
end

function recall_snapshot(snapshot)
  engine.recall_snapshot(snapshot, {
    volume = recall_volume, pan = recall_pan, mute = recall_mute,
    solo = recall_solo, phase = recall_phase, width = recall_width,
    fx = recall_fx, sends = recall_sends, routing = recall_routing,
  })
end

function serialize_table(tbl, indent)
  return engine.serialize_table(tbl, indent)
end

function deserialize_table(str)
  return engine.deserialize_table(str)
end

function save_snapshots_to_project()
  local data = {}
  data.counter = snapshot_counter
  data.snapshots = {}
  data.disable_auto_recall = disable_auto_recall
  data.switch_mid_gap = switch_mid_gap
  data.allow_daemon_on_close = allow_daemon_on_close
  data.bank_track_guid = bank_track_guid
  data.recall_volume = recall_volume
  data.recall_pan = recall_pan
  data.recall_mute = recall_mute
  data.recall_solo = recall_solo
  data.recall_phase = recall_phase
  data.recall_width = recall_width
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

function load_snapshots_from_project()
  snap_info.prune_stale_snapshots(current_bank)

  local retval, serialized = GetProjExtState(0, "MixerSnapshots", "data_" .. current_bank)
  if retval > 0 and serialized ~= "" then
    local data = deserialize_table(serialized)
    if data then
      snapshot_counter = data.counter or 0
      snapshots = {}
      disable_auto_recall = data.disable_auto_recall or false
      switch_mid_gap = data.switch_mid_gap ~= false
      allow_daemon_on_close = data.allow_daemon_on_close ~= false
      bank_track_guid = data.bank_track_guid
      recall_volume = data.recall_volume ~= false
      recall_pan = data.recall_pan ~= false
      recall_mute = data.recall_mute ~= false
      recall_solo = data.recall_solo ~= false
      recall_phase = data.recall_phase ~= false
      recall_width = data.recall_width ~= false
      recall_fx = data.recall_fx ~= false
      recall_sends = data.recall_sends ~= false
      recall_routing = data.recall_routing ~= false

      for _, s in ipairs(data.snapshots or {}) do
        table.insert(snapshots, s)
      end
      note_buffers = {}
      for _, s in ipairs(snapshots) do
        note_buffers[s.item_guid] = s.notes or ""
      end

      last_sort_mode = -1
    end
  else
    snapshot_counter = 0
    snapshots = {}
    selected_snapshot = nil
  end
end

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
      note_buffers = {}
      for _, s in ipairs(snapshots) do
        note_buffers[s.item_guid] = s.notes or ""
      end
      save_snapshots_to_project()
    end
  end
end

function clear_bank()
  snapshots = {}
  snapshot_counter = 0
  selected_snapshot = nil
  bank_track_guid = nil
  note_buffers = {}
  save_snapshots_to_project()
end

function switch_to_bank(new_bank)
  if new_bank == current_bank then return end
  save_snapshots_to_project()
  current_bank = new_bank
  selected_snapshot = nil
  load_snapshots_from_project()
end

function sort_snapshots()
  local ascending = (sort_direction == ImGui.SortDirection_Ascending)
  if sort_mode == 0 then
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

function draw_table()
  if sort_mode ~= last_sort_mode or sort_direction ~= last_sort_direction then
    sort_snapshots()
    last_sort_mode = sort_mode
    last_sort_direction = sort_direction
  end

  local open_diff_popup = false

  if ImGui.BeginTable(ctx, "SnapshotsTable", 6, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_Resizable) then
    ImGui.TableSetupColumn(ctx, "#", ImGui.TableColumnFlags_WidthFixed, col_widths[1])
    ImGui.TableSetupColumn(ctx, "Item Name", ImGui.TableColumnFlags_WidthFixed, col_widths[2])
    ImGui.TableSetupColumn(ctx, "Date/Time", ImGui.TableColumnFlags_WidthFixed, col_widths[3])
    ImGui.TableSetupColumn(ctx, "Notes", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(ctx, "Changes", ImGui.TableColumnFlags_WidthFixed, col_widths[5])
    ImGui.TableSetupColumn(ctx, "Delete", ImGui.TableColumnFlags_WidthFixed, col_widths[6])
    ImGui.TableHeadersRow(ctx)

    for i, snap in ipairs(snapshots) do
      ImGui.TableNextRow(ctx)
      ImGui.PushID(ctx, i)

      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.PushID(ctx, "index_sel")
      if ImGui.Selectable(ctx, tostring(i), selected_snapshot == snap) then
        selected_snapshot = snap
        recall_snapshot(snap)
        if not disable_auto_recall then
          local item = get_item_by_guid(snap.item_guid)
          if item then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetEditCurPos(item_pos, true, true)
            SelectAllMediaItems(0, false)
            SetMediaItemSelected(item, true)
            UpdateArrange()
          end
        end
      end
      ImGui.PopID(ctx)

      ImGui.TableSetColumnIndex(ctx, 1)
      local display_name
      if snap.item_name and snap.item_name ~= "" then
        display_name = snap.item_name
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
            SelectAllMediaItems(0, false)
            SetMediaItemSelected(item, true)
            UpdateArrange()
          end
        end
      end
      ImGui.PopID(ctx)

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
            SelectAllMediaItems(0, false)
            SetMediaItemSelected(item, true)
            UpdateArrange()
          end
        end
      end
      ImGui.PopID(ctx)

      ImGui.TableSetColumnIndex(ctx, 3)
      if not note_buffers[snap.item_guid] then
        note_buffers[snap.item_guid] = snap.notes or ""
      end
      ImGui.SetNextItemWidth(ctx, -1)
      local changed, new_notes = ImGui.InputText(ctx, "##notes_" .. snap.item_guid, note_buffers[snap.item_guid])
      if changed then
        note_buffers[snap.item_guid] = new_notes
        snap.notes = new_notes
        save_snapshots_to_project()
      end

      ImGui.TableSetColumnIndex(ctx, 4)
      ImGui.PushID(ctx, "changes_btn")
      if ImGui.Button(ctx, "Changes") then
        diff_popup_lines = snap_info.compute_snapshot_diff(snap)
        diff_popup_title = display_name
        open_diff_popup = true
      end
      ImGui.PopID(ctx)

      ImGui.TableSetColumnIndex(ctx, 5)
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

  if open_diff_popup then
    ImGui.OpenPopup(ctx, "snapshot_diff_popup")
  end

  if ImGui.BeginPopupModal(ctx, "snapshot_diff_popup", true, ImGui.WindowFlags_AlwaysAutoResize) then
    ImGui.Text(ctx, "Changes from default: " .. diff_popup_title)
    ImGui.Separator(ctx)
    if #diff_popup_lines == 0 then
      ImGui.Text(ctx, "All captured values are at default")
    else
      for _, line in ipairs(diff_popup_lines) do
        ImGui.Text(ctx, line)
      end
    end
    ImGui.Separator(ctx)
    if ImGui.Button(ctx, "Close", 120, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end
    ImGui.EndPopup(ctx)
  end
end

function draw_UI()
  ImGui.SetNextWindowSize(ctx, 900, 600, ImGui.Cond_FirstUseEver)
  local visible, open = ImGui.Begin(ctx, script_name, true)
  if visible then
    if ImGui.BeginTabBar(ctx, "Banks") then
      for _, bank in ipairs({ "A", "B", "C", "D" }) do
        if ImGui.BeginTabItem(ctx, "     " .. bank .. "     ") then
          if current_bank ~= bank then switch_to_bank(bank) end
          ImGui.EndTabItem(ctx)
        end
      end
      ImGui.EndTabBar(ctx)
    end

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

    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 4, 0); ImGui.SameLine(ctx)
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

    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 4, 0); ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear All Automation") then
      clear_all_automation()
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Clear all automation from mixer, aux, and submix tracks")
    end

    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 4, 0); ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Convert to Automation") then
      convert_snapshots_to_automation()
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Create real automation lanes from all snapshots in current bank")
    end
    local first_folder_track = snap_info.get_first_folder_track()
    local first_folder_name = "(none -- first track isn't a folder)"
    if first_folder_track then
      local _, nm = GetSetMediaTrackInfo_String(first_folder_track, "P_NAME", "", false)
      first_folder_name = nm ~= "" and nm or "Folder 1"
    end

    ImGui.Separator(ctx)

    local item_guid, item_name = get_selected_item_info()
    local selected_item = item_guid and GetSelectedMediaItem(0, 0) or nil
    local on_first_folder = selected_item ~= nil and first_folder_track ~= nil
        and GetMediaItem_Track(selected_item) == first_folder_track
    local can_create = on_first_folder

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
    if can_create then
      existing_snap = find_snapshot_by_item_guid(item_guid)
    end
    local button_label
    if not item_guid then
      button_label = "Set snapshot (select an item first)"
    elseif not on_first_folder then
      button_label = "Set snapshot (select an item on " .. first_folder_name .. ")"
    elseif existing_snap then
      button_label = "Update snapshot for: " .. (display_name or "Unknown")
    else
      button_label = "Set snapshot for: " .. (display_name or "Unknown")
    end

    if ImGui.Button(ctx, button_label) then
      if can_create then
        Undo_BeginBlock()
        local existing = find_snapshot_by_item_guid(item_guid)
        if existing then
          existing.tracks = {}
          for i = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, i)
            if is_special_track(track) then
              existing.tracks[i] = get_track_state(track)
            end
          end
          existing.item_name = item_name or ""
          existing.date = os.date("%Y-%m-%d")
          existing.time = os.date("%H:%M:%S")
          selected_snapshot = existing
        else
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
    if not can_create then ImGui.EndDisabled(ctx) end

    ImGui.Separator(ctx)

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
    local rv_bg, new_bg = ImGui.Checkbox(ctx, "Background auto-recall", allow_daemon_on_close)
    if rv_bg then
      allow_daemon_on_close = new_bg
      save_snapshots_to_project()
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Keep auto-recall running via the headless daemon after this window closes")
    end

    ImGui.SameLine(ctx); ImGui.Dummy(ctx, 10, 0); ImGui.SameLine(ctx)

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

    ImGui.Text(ctx, "Recall:")
    ImGui.SameLine(ctx)
    for _, param in ipairs({
      { "Volume",       recall_volume,  function(v) recall_volume = v end },
      { "Pan",          recall_pan,     function(v) recall_pan = v end },
      { "Mute",         recall_mute,    function(v) recall_mute = v end },
      { "Solo",         recall_solo,    function(v) recall_solo = v end },
      { "Phase",        recall_phase,   function(v) recall_phase = v end },
      { "Width",        recall_width,   function(v) recall_width = v end },
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
    if gui_mode.imgui_shortcut(ImGui, ctx) then gui_mode.toggle_and_announce() end
    if gui_mode.imgui_close_shortcut(ImGui, ctx) then open = false end
    ImGui.End(ctx)
  end
  return open
end

function check_auto_recall()
  if disable_auto_recall then return end

  local play_state = GetPlayState()
  local current_playing = (play_state & 1) == 1

  local item_guid, item_name = get_selected_item_info()

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
          local edit_cursor = GetCursorPosition()
          local snap = find_snapshot_at_cursor(edit_cursor)
          if snap then
            recall_snapshot(snap)
            selected_snapshot = snap
          end
        end
      else
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
    local edit_cursor = GetCursorPosition()

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

function clear_all_automation()
  snap_info.set_current_bank(current_bank)
  local cleared_count = snap_automation.clear_all_automation()
  ShowMessageBox("Cleared automation from " .. cleared_count .. " tracks.", "Clear All Automation", 0)
end

function convert_snapshots_to_automation()
  snap_info.set_current_bank(current_bank)
  local automation_count, snapshot_count = snap_automation.convert_snapshots_to_automation()
  if snapshot_count == 0 then
    ShowMessageBox("No snapshots to convert.", "Convert to Automation", 0)
  else
    ShowMessageBox(automation_count .. " automation lanes created from " .. snapshot_count .. " snapshots.",
      "Convert to Automation", 0)
  end
  load_snapshots_from_project()
end

sort_direction = ImGui.SortDirection_Ascending
load_snapshots_from_project()

snap_info.stop_daemon_if_running(script_path .. "lib/ReaClassical_Mixer Snapshots Daemon.lua")

defer(main)
