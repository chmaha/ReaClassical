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

local ia_script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. ia_script_path .. "?.lua;" .. ia_script_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

if not _G.RC_SCRIPT_ARGS and gui_mode.accessible() then
    dofile(ia_script_path .. "lib/ReaClassical_Accessible Automation Navigator.lua")
    return
end

if not APIExists("CF_GetSWSVersion") then
    MB("Insert Automation requires the SWS extension to be installed.", "ReaClassical Error", 0)
    return
end

local main, apply_automation, linear_to_db, db_to_linear, get_envelope_value_at_time
local format_time, get_selected_tracks, get_track_envelopes, get_track_fx_params
local normalize_value, denormalize_value, get_default_track_value
local get_fx_param_range, is_toggle_parameter, delete_overlapping_automation_items
local get_snap_track, get_mixer_track, is_folder_track, get_parent_folder, is_destination_track
local refresh_preview_target, apply_preview_now

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
  MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
  return
end

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

set_action_options(2)

package.path              = ImGui_GetBuiltinPath() .. '/?.lua;' .. ia_script_path .. 'lib/?.lua;'
local ImGui               = require 'imgui' '0.10'
local preview             = require 'ReaClassical_Automation_Preview'
local special_track_nav   = require 'ReaClassical_Special_Track_Nav'
local automation_ownership = require 'ReaClassical_Automation_Ownership'
local automation_mode     = require 'ReaClassical_Automation_Mode'
local get_destination_source = require('ReaClassical_Automation_Info').get_destination_source

local ctx                 = ImGui.CreateContext('ReaClassical Volume Automation')
local window_open         = true

atexit(preview.clear)

local DEFAULT_W           = 400
local DEFAULT_H           = 180

local selected_tracks     = {}
local volume_db           = 0.0
local ramp_in             = 0.0
local ramp_out            = 0.0
local has_time_sel        = false
local start_time          = 0
local end_time            = 0

local last_cursor_pos     = nil
local last_time_sel_start = nil
local last_time_sel_end   = nil
local last_track_count    = 0

local volume_reset        = false

local advanced_mode       = false
local selected_envelope   = nil
local envelope_value      = 0.0
local track_envelopes     = {}
local fx_params           = {}
local current_tab         = 0
local keep_window_open    = false

local last_fx_count       = 0

function get_mixer_track(src)
  local _, ms = GetSetMediaTrackInfo_String(src, "P_EXT:mixer", "", false)
  local _, nm = GetSetMediaTrackInfo_String(src, "P_NAME", "", false)
  if ms == "y" or (nm and nm:match("^M:")) then return src end
  for s = 0, GetTrackNumSends(src, 0) - 1 do
    local dest = GetTrackSendInfo_Value(src, 0, s, "P_DESTTRACK")
    if dest then
      local _, ds = GetSetMediaTrackInfo_String(dest, "P_EXT:mixer", "", false)
      local _, dn = GetSetMediaTrackInfo_String(dest, "P_NAME", "", false)
      if ds == "y" or (dn and dn:match("^M:")) then return dest end
    end
  end
  return src
end

function is_folder_track(track)
  if not track then return false end
  return GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
end

function get_parent_folder(track)
  if not track then return nil end
  local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
  for i = track_idx - 1, 0, -1 do
    local t = GetTrack(0, i)
    if not t then break end
    if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
  end
  return nil
end

function is_destination_track(track)
  if not track then return false end
  local folder = is_folder_track(track) and track or get_parent_folder(track)
  if not folder then return false end
  local _, is_dest = GetSetMediaTrackInfo_String(folder, "P_EXT:destination", "", false)
  return is_dest == "y"
end

function get_snap_track(src)
  if is_destination_track(src) then return src end
  return get_mixer_track(src)
end

function get_selected_tracks()
  local tracks = {}
  local count = CountSelectedTracks(0)
  for i = 0, count - 1 do
    tracks[#tracks + 1] = get_snap_track(GetSelectedTrack(0, i))
  end
  return tracks
end

function get_track_envelopes(track)
  local envelopes = {}

  local standard_envs = {
    { name = "Volume",          display = "Volume" },
    { name = "Pan",             display = "Pan" },
    { name = "Width",           display = "Width" },
    { name = "Volume (Pre-FX)", display = "Volume (Pre-FX)" },
    { name = "Pan (Pre-FX)",    display = "Pan (Pre-FX)" },
    { name = "Width (Pre-FX)",  display = "Width (Pre-FX)" },
    { name = "Trim Volume",     display = "Trim Volume" },
    { name = "Mute",            display = "Mute" },
  }

  for _, env_info in ipairs(standard_envs) do
    table.insert(envelopes, {
      type = "track",
      name = env_info.name,
      display = env_info.display,
      track = track
    })
  end

  return envelopes
end

function get_track_fx_params(track)
  local params = {}
  local fx_count = TrackFX_GetCount(track)

  for fx_idx = 0, fx_count - 1 do
    local _, fx_name = TrackFX_GetFXName(track, fx_idx, "")
    local param_count = TrackFX_GetNumParams(track, fx_idx)

    local fx_params_list = {}
    for param_idx = 0, param_count - 1 do
      local _, param_name = TrackFX_GetParamName(track, fx_idx, param_idx, "")
      table.insert(fx_params_list, {
        type = "fx",
        fx_idx = fx_idx,
        param_idx = param_idx,
        name = param_name,
        display = param_name,
        track = track,
        fx_name = fx_name
      })
    end

    if #fx_params_list > 0 then
      table.insert(params, {
        fx_name = fx_name,
        fx_idx = fx_idx,
        params = fx_params_list
      })
    end
  end

  return params
end

function format_time(time_seconds)
  local time_str = format_timestr_pos(time_seconds, "", 5)
  return time_str
end

function linear_to_db(val)
  if val <= 0.0000000298023223876953125 then
    return -150.0
  end
  return 20 * math.log(val, 10)
end

function db_to_linear(db)
  if db <= -150 then
    return 0.0
  end
  return 10 ^ (db / 20)
end

function normalize_value(envelope_info, raw_value)
  if not envelope_info then return 0 end

  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return linear_to_db(raw_value)
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return -raw_value
    elseif envelope_info.name == "Width" or envelope_info.name == "Width (Pre-FX)" then
      return raw_value
    elseif envelope_info.name == "Mute" then
      return raw_value
    end
  elseif envelope_info.type == "fx" then
    return raw_value
  end

  return raw_value
end

function denormalize_value(envelope_info, display_value)
  if not envelope_info then return 0 end

  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return db_to_linear(display_value)
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return -display_value
    elseif envelope_info.name == "Width" or envelope_info.name == "Width (Pre-FX)" then
      return display_value
    elseif envelope_info.name == "Mute" then
      return display_value
    end
  elseif envelope_info.type == "fx" then
    return display_value
  end

  return display_value
end

function get_envelope_value_at_time(envelope, time)
  if not envelope then return nil end

  local br_env = BR_EnvAlloc(envelope, false)
  local value = BR_EnvValueAtPos(br_env, time)
  BR_EnvFree(br_env, false)

  return value
end

function get_fx_param_range(track, fx_idx, param_idx)
  local current_val, min_val, max_val = reaper.TrackFX_GetParam(track, fx_idx, param_idx)

  if min_val > max_val then
    min_val, max_val = max_val, min_val
  end

  if math.abs(min_val - 0.0) < 0.001 and math.abs(max_val - 1.0) < 0.001 then
    return 0.0, 1.0, current_val, true
  else
    return min_val, max_val, current_val, false
  end
end

function get_default_track_value(track, envelope_info)
  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return GetMediaTrackInfo_Value(track, "D_VOL")
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return GetMediaTrackInfo_Value(track, "D_PAN")
    elseif envelope_info.name == "Width" or envelope_info.name == "Width (Pre-FX)" then
      return GetMediaTrackInfo_Value(track, "D_WIDTH")
    elseif envelope_info.name == "Mute" then
      return 1 - GetMediaTrackInfo_Value(track, "B_MUTE")
    end
  elseif envelope_info.type == "fx" then
    return TrackFX_GetParam(track, envelope_info.fx_idx, envelope_info.param_idx)
  end
  return 1.0
end

function refresh_preview_target()
  preview.clear()
  if #selected_tracks == 0 or not has_time_sel then return end

  if advanced_mode then
    if not selected_envelope then return end
    if selected_envelope.type == "track" then
      local field = preview.DIRECT_FIELD[selected_envelope.name]
      for _, t in ipairs(selected_tracks) do
        preview.snapshot_track(t, field)
      end
    else
      for _, t in ipairs(selected_tracks) do
        preview.snapshot_fx(get_mixer_track(t), selected_envelope.fx_idx, selected_envelope.param_idx)
      end
    end
  else
    for _, t in ipairs(selected_tracks) do
      preview.snapshot_track(t, preview.DIRECT_FIELD.Volume)
    end
  end
end

function apply_preview_now()
  if not preview.has_targets() then return end
  if advanced_mode then
    if selected_envelope.type == "track" then
      preview.apply_track(envelope_value)
    else
      preview.apply_fx(envelope_value)
    end
  else
    preview.apply_track(volume_db)
  end
end

function delete_overlapping_automation_items(env, start_t, end_t)
  local count = CountAutomationItems(env)
  if count == 0 then return end
  local any = false
  for i = 0, count - 1 do
    local pos = GetSetAutomationItemInfo(env, i, "D_POSITION", 0, false)
    local len = GetSetAutomationItemInfo(env, i, "D_LENGTH", 0, false)
    local overlaps = pos < end_t and (pos + len) > start_t
    GetSetAutomationItemInfo(env, i, "D_UISEL", overlaps and 1 or 0, true)
    if overlaps then any = true end
  end
  if any then
    Main_OnCommand(42086, 0)
  end
end

function apply_automation()
  if #selected_tracks == 0 then return end
  if not has_time_sel or start_time == end_time then return end

  local target_envelope_info = advanced_mode and selected_envelope or {
    type = "track",
    name = "Volume",
    display = "Volume"
  }

  if not target_envelope_info then return end

  local target_value
  if advanced_mode then
    target_value = denormalize_value(target_envelope_info, envelope_value)
  else
    target_value = db_to_linear(volume_db)
  end

  for _, track in ipairs(selected_tracks) do
    local env_track = (target_envelope_info.type == "fx") and get_mixer_track(track)
      or (get_destination_source(track) or track)

    local env

    if target_envelope_info.type == "track" then
      env = GetTrackEnvelopeByName(env_track, target_envelope_info.name)
      if not env then
        SetOnlyTrackSelected(env_track)
        if target_envelope_info.name == "Volume" then
          Main_OnCommand(40406, 0)
        elseif target_envelope_info.name == "Pan" then
          Main_OnCommand(40407, 0)
        elseif target_envelope_info.name == "Width" then
          Main_OnCommand(41870, 0)
        elseif target_envelope_info.name == "Mute" then
          Main_OnCommand(40867, 0)
        elseif target_envelope_info.name == "Volume (Pre-FX)" then
          Main_OnCommand(41865, 0)
        elseif target_envelope_info.name == "Pan (Pre-FX)" then
          Main_OnCommand(41867, 0)
        elseif target_envelope_info.name == "Width (Pre-FX)" then
          Main_OnCommand(41869, 0)
        elseif target_envelope_info.name == "Trim Volume" then
          Main_OnCommand(42020, 0)
        end
        env = GetTrackEnvelopeByName(env_track, target_envelope_info.name)
        if not env then goto continue end
      end
    elseif target_envelope_info.type == "fx" then
      env = GetFXEnvelope(env_track, target_envelope_info.fx_idx, target_envelope_info.param_idx, true)
      if not env then goto continue end
    end

    local needs_scaling = target_envelope_info.type == "track" and
        (target_envelope_info.name == "Volume" or
          target_envelope_info.name == "Volume (Pre-FX)" or
          target_envelope_info.name == "Trim Volume")

    local actual_start = start_time
    local actual_end = end_time

    local ramp_in_start = math.max(0, actual_start - ramp_in)
    local ramp_out_end = actual_end + ramp_out

    local affected_start = ramp_in > 0 and ramp_in_start or math.max(0, actual_start - 0.002)
    local affected_end = ramp_out > 0 and ramp_out_end or (actual_end + 0.002)
    delete_overlapping_automation_items(env, affected_start, affected_end)

    local val_before, val_after

    if ramp_in > 0 then
      val_before = get_envelope_value_at_time(env, ramp_in_start)
      if not val_before then
        val_before = get_default_track_value(env_track, target_envelope_info)
      end
    else
      val_before = get_envelope_value_at_time(env, actual_start - 0.001)
      if not val_before then
        val_before = get_default_track_value(env_track, target_envelope_info)
      end
    end

    if ramp_out > 0 then
      val_after = get_envelope_value_at_time(env, ramp_out_end)
      if not val_after then
        val_after = get_default_track_value(env_track, target_envelope_info)
      end
    else
      val_after = get_envelope_value_at_time(env, actual_end + 0.001)
      if not val_after then
        val_after = get_default_track_value(env_track, target_envelope_info)
      end
    end

    DeleteEnvelopePointRange(env, affected_start - 0.001, affected_end + 0.001)

    local target_val_to_insert = needs_scaling and ScaleToEnvelopeMode(1, target_value) or target_value
    local val_before_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_before) or val_before
    local val_after_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_after) or val_after

    if ramp_in > 0 then
      if ramp_in_start < actual_start then
        InsertEnvelopePoint(env, ramp_in_start, val_before_to_insert, 0, 0, false, true)
      end
      InsertEnvelopePoint(env, actual_start, target_val_to_insert, 0, 0, false, true)
    else
      local before_point = math.max(0, actual_start - 0.001)
      if before_point < actual_start then
        InsertEnvelopePoint(env, before_point, val_before_to_insert, 0, 0, false, true)
      end
      InsertEnvelopePoint(env, actual_start, target_val_to_insert, 0, 0, false, true)
    end

    if ramp_out > 0 then
      InsertEnvelopePoint(env, actual_end, target_val_to_insert, 0, 0, false, true)
      InsertEnvelopePoint(env, ramp_out_end, val_after_to_insert, 0, 0, false, true)
    else
      InsertEnvelopePoint(env, actual_end, target_val_to_insert, 0, 0, false, true)
      InsertEnvelopePoint(env, actual_end + 0.001, val_after_to_insert, 0, 0, false, true)
    end

    Envelope_SortPoints(env)

    ::continue::
  end

  for _, track in ipairs(selected_tracks) do
    local env_track = (target_envelope_info.type == "fx") and get_mixer_track(track)
      or (get_destination_source(track) or track)
    local env
    if target_envelope_info.type == "track" then
      env = GetTrackEnvelopeByName(env_track, target_envelope_info.name)
    elseif target_envelope_info.type == "fx" then
      env = GetFXEnvelope(env_track, target_envelope_info.fx_idx, target_envelope_info.param_idx, false)
    end

    if env then
      local item_start = ramp_in > 0 and math.max(0, start_time - ramp_in) or math.max(0, start_time - 0.002)
      local item_end = ramp_out > 0 and (end_time + ramp_out) or (end_time + 0.002)
      local ai_idx = InsertAutomationItem(env, -1, item_start, item_end - item_start)
      if special_track_nav.is_special_track(env_track) then
        automation_ownership.mark_user_ai(env, ai_idx)
      end
      automation_mode.ensure_engaged()
    end

    SetMediaTrackInfo_Value(env_track, "B_SHOWINTCP", 1)
    local _, ms   = GetSetMediaTrackInfo_String(env_track, "P_EXT:mixer", "", false)
    local _, guid = GetSetMediaTrackInfo_String(env_track, "GUID", "", false)
    local mc_key  = (ms == "y") and ("mixer_tcp_visible_" .. guid) or ("tcp_visible_" .. guid)
    SetProjExtState(0, "ReaClassical_MissionControl", mc_key, "1")
  end

  TrackList_AdjustWindows(false)
  UpdateArrange()

  if not keep_window_open then
    window_open = false
  end
end

function main()
  local _, adv_mode_str = GetProjExtState(0, "ReaClassical", "AdvancedAutomationMode")
  if adv_mode_str == "1" then
    advanced_mode = true
  else
    advanced_mode = false
  end

  local _, keep_open_str = GetProjExtState(0, "ReaClassical", "KeepAutomationWindowOpen")
  if keep_open_str == "1" then
    keep_window_open = true
  elseif keep_open_str == "0" then
    keep_window_open = false
  end

  local tracks = get_selected_tracks()
  local track_count = #tracks

  local current_cursor = GetCursorPosition()
  local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  local current_has_time_sel = (ts_start ~= ts_end)

  local current_fx_count = 0
  if track_count > 0 then
    current_fx_count = TrackFX_GetCount(get_mixer_track(tracks[1]))
  end
  local fx_count_changed = (current_fx_count ~= last_fx_count)
  if fx_count_changed then
    last_fx_count = current_fx_count
  end

  if track_count ~= last_track_count or
      (track_count > 0 and tracks[1] ~= selected_tracks[1]) then
    selected_tracks = tracks
    last_track_count = track_count
    last_cursor_pos = current_cursor
    last_time_sel_start = ts_start
    last_time_sel_end = ts_end
    last_fx_count = current_fx_count

    if track_count > 0 then
      if advanced_mode then
        track_envelopes = get_track_envelopes(tracks[1])
        fx_params = get_track_fx_params(get_mixer_track(tracks[1]))
      end

      local first_track = tracks[1]
      local query_time = current_has_time_sel and ts_start or current_cursor

      if advanced_mode and selected_envelope then
        local env
        if selected_envelope.type == "track" then
          env = GetTrackEnvelopeByName(first_track, selected_envelope.name)
        elseif selected_envelope.type == "fx" then
          env = GetFXEnvelope(get_mixer_track(first_track), selected_envelope.fx_idx, selected_envelope.param_idx, false)
        end

        if env then
          local env_val = get_envelope_value_at_time(env, query_time)
          if env_val then
            if selected_envelope.type == "track" then
              envelope_value = normalize_value(selected_envelope, env_val)
            else
              envelope_value = env_val
            end
          end
        end
      else
        local vol_env = GetTrackEnvelopeByName(first_track, "Volume")
        if vol_env then
          local env_val = get_envelope_value_at_time(vol_env, query_time)
          if env_val and env_val > 0 then
            volume_db = linear_to_db(env_val)
          else
            local vol = GetMediaTrackInfo_Value(first_track, "D_VOL")
            volume_db = linear_to_db(vol)
          end
        else
          local vol = GetMediaTrackInfo_Value(first_track, "D_VOL")
          volume_db = linear_to_db(vol)
        end
      end
    end
  elseif track_count > 0 and (current_cursor ~= last_cursor_pos or
        ts_start ~= last_time_sel_start or
        ts_end ~= last_time_sel_end) then
    last_cursor_pos = current_cursor
    last_time_sel_start = ts_start
    last_time_sel_end = ts_end

    local first_track = tracks[1]
    local query_time = current_has_time_sel and ts_start or current_cursor

    if advanced_mode and selected_envelope then
      local env
      if selected_envelope.type == "track" then
        env = GetTrackEnvelopeByName(first_track, selected_envelope.name)
      elseif selected_envelope.type == "fx" then
        env = GetFXEnvelope(get_mixer_track(first_track), selected_envelope.fx_idx, selected_envelope.param_idx, false)
      end

      if env then
        local env_val = get_envelope_value_at_time(env, query_time)
        if env_val then
          if selected_envelope.type == "track" then
            envelope_value = normalize_value(selected_envelope, env_val)
          else
            envelope_value = env_val
          end
        end
      end
    else
      local vol_env = GetTrackEnvelopeByName(first_track, "Volume")
      if vol_env then
        local env_val = get_envelope_value_at_time(vol_env, query_time)
        if env_val and env_val > 0 then
          volume_db = linear_to_db(env_val)
        else
          local vol = GetMediaTrackInfo_Value(first_track, "D_VOL")
          volume_db = linear_to_db(vol)
        end
      else
        local vol = GetMediaTrackInfo_Value(first_track, "D_VOL")
        volume_db = linear_to_db(vol)
      end
    end
  end

  start_time, end_time = ts_start, ts_end
  has_time_sel = current_has_time_sel

  if window_open then
    local _, FLT_MAX = ImGui.NumericLimits_Float()
    ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)
    local opened, open_ref = ImGui.Begin(ctx, "Volume Automation", window_open, ImGui.WindowFlags_AlwaysAutoResize)
    window_open = open_ref

    if opened then
      if #selected_tracks == 0 then
        ImGui.TextWrapped(ctx, "Please select one or more tracks to apply automation.")
      elseif not has_time_sel then
        ImGui.TextWrapped(ctx, "Please make a time selection to apply automation.")
        ImGui.Spacing(ctx)
        ImGui.TextWrapped(ctx,
          "For open-ended changes with no end point, use the Mixer Snapshot Manager instead.")
      else
        if #selected_tracks == 1 then
          local _, track_name = GetSetMediaTrackInfo_String(selected_tracks[1], "P_NAME", "", false)
          if track_name == "" then
            local track_num = GetMediaTrackInfo_Value(selected_tracks[1], "IP_TRACKNUMBER")
            track_name = "Track " .. math.floor(track_num)
          end
          ImGui.Text(ctx, "Selected Track: " .. track_name)
        else
          ImGui.Text(ctx, "Selected Tracks: " .. #selected_tracks)
          if ImGui.IsItemHovered(ctx) then
            local tooltip = ""
            for i, track in ipairs(selected_tracks) do
              local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
              if track_name == "" then
                local track_num = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
                track_name = "Track " .. math.floor(track_num)
              end
              tooltip = tooltip .. track_name
              if i < #selected_tracks then
                tooltip = tooltip .. "\n"
              end
            end
            ImGui.SetTooltip(ctx, tooltip)
          end
        end

        local changed_adv, new_adv = ImGui.Checkbox(ctx, "Advanced Mode", advanced_mode)
        if changed_adv then
          advanced_mode = new_adv
          SetProjExtState(0, "ReaClassical", "AdvancedAutomationMode", advanced_mode and "1" or "0")

          if advanced_mode and #selected_tracks > 0 then
            track_envelopes = get_track_envelopes(selected_tracks[1])
            fx_params = get_track_fx_params(get_mixer_track(selected_tracks[1]))
          end
        end

        ImGui.Separator(ctx)

        if advanced_mode then
          if ImGui.BeginTabBar(ctx, "EnvelopeTabs") then
            if ImGui.BeginTabItem(ctx, "Track Envelopes") then
              if current_tab ~= 0 then
                current_tab = 0
              end

              ImGui.Text(ctx, "Select Envelope:")
              local track_env_height = #track_envelopes * 21 + 16
              ImGui.BeginChild(ctx, "TrackEnvList", 0, track_env_height, ImGui.ChildFlags_Borders)

              for _, env_info in ipairs(track_envelopes) do
                local is_selected = selected_envelope and
                    selected_envelope.type == "track" and
                    selected_envelope.name == env_info.name

                if ImGui.Selectable(ctx, env_info.display, is_selected) then
                  selected_envelope = env_info

                  local first_track = selected_tracks[1]
                  local query_time = start_time
                  local env = GetTrackEnvelopeByName(first_track, env_info.name)

                  if env then
                    local env_val = get_envelope_value_at_time(env, query_time)
                    if env_val then
                      envelope_value = normalize_value(env_info, env_val)
                    else
                      envelope_value = 0
                    end
                  else
                    if env_info.name == "Volume" or env_info.name == "Volume (Pre-FX)" or env_info.name == "Trim Volume" then
                      local vol = GetMediaTrackInfo_Value(first_track, "D_VOL")
                      envelope_value = linear_to_db(vol)
                    elseif env_info.name == "Pan" or env_info.name == "Pan (Pre-FX)" then
                      envelope_value = GetMediaTrackInfo_Value(first_track, "D_PAN")
                    elseif env_info.name == "Width" or env_info.name == "Width (Pre-FX)" then
                      envelope_value = GetMediaTrackInfo_Value(first_track, "D_WIDTH")
                    elseif env_info.name == "Mute" then
                      envelope_value = 1 - GetMediaTrackInfo_Value(first_track, "B_MUTE")
                    else
                      envelope_value = 0
                    end
                  end
                end
              end

              ImGui.EndChild(ctx)
              ImGui.EndTabItem(ctx)
            end

            if ImGui.BeginTabItem(ctx, "FX Parameters") then
              if current_tab ~= 1 or fx_count_changed then
                current_tab = 1
                if #selected_tracks > 0 then
                  fx_params = get_track_fx_params(get_mixer_track(selected_tracks[1]))
                end
              end

              ImGui.Text(ctx, "Select FX Parameter:")
              ImGui.BeginChild(ctx, "FXParamList", 0, 150, ImGui.ChildFlags_Borders)

              if #fx_params == 0 then
                ImGui.TextWrapped(ctx, "No FX on selected track")
              else
                for _, fx_info in ipairs(fx_params) do
                  if ImGui.TreeNode(ctx, fx_info.fx_name .. "##fx" .. fx_info.fx_idx) then
                    for _, param_info in ipairs(fx_info.params) do
                      local is_selected = selected_envelope and
                          selected_envelope.type == "fx" and
                          selected_envelope.fx_idx == param_info.fx_idx and
                          selected_envelope.param_idx == param_info.param_idx

                      if ImGui.Selectable(ctx, param_info.display .. "##" .. param_info.fx_idx .. "_" .. param_info.param_idx, is_selected) then
                        selected_envelope = param_info

                        local first_track = get_mixer_track(selected_tracks[1])
                        local query_time = start_time
                        local env = GetFXEnvelope(first_track, param_info.fx_idx, param_info.param_idx, false)

                        if env then
                          local env_val = get_envelope_value_at_time(env, query_time)
                          if env_val then
                            envelope_value = env_val
                          else
                            envelope_value = 0
                          end
                        else
                          local _, _, current_val, _ = get_fx_param_range(first_track, param_info.fx_idx,
                            param_info.param_idx)
                          envelope_value = current_val
                        end
                      end
                    end
                    ImGui.TreePop(ctx)
                  end
                end
              end

              ImGui.EndChild(ctx)
              ImGui.EndTabItem(ctx)
            end

            ImGui.EndTabBar(ctx)
          end

          ImGui.Separator(ctx)

          if selected_envelope then
            ImGui.Text(ctx, "Selected: " .. selected_envelope.display)

            local min_val, max_val, format_str, label

            if selected_envelope.type == "track" then
              if selected_envelope.name == "Volume" or selected_envelope.name == "Volume (Pre-FX)" or selected_envelope.name == "Trim Volume" then
                min_val, max_val = -150.0, 12.0
                format_str = "%.1f dB"
                label = "Value (dB):"
              elseif selected_envelope.name == "Pan" or selected_envelope.name == "Pan (Pre-FX)" then
                min_val, max_val = -1.0, 1.0
                format_str = "%.2f"
                label = "Value (L=-1, C=0, R=+1):"
              elseif selected_envelope.name == "Width" or selected_envelope.name == "Width (Pre-FX)" then
                min_val, max_val = -1.0, 1.0
                format_str = "%.2f"
                label = "Value:"
              elseif selected_envelope.name == "Mute" then
                min_val, max_val = 0.0, 1.0
                format_str = "%.0f"
                label = "Value (1=Unmuted, 0=Muted):"
              else
                min_val, max_val = 0.0, 100.0
                format_str = "%.1f"
                label = "Value:"
              end

              ImGui.Text(ctx, label)
              ImGui.SetNextItemWidth(ctx, -1)
              local changed_val, new_val = ImGui.SliderDouble(ctx, "##envvalue", envelope_value, min_val, max_val,
                format_str)

              if changed_val then
                envelope_value = new_val
              end

              if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Right-click to type value")
              end

              if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
                ImGui.OpenPopup(ctx, "env_value_input")
              end

              if ImGui.BeginPopup(ctx, "env_value_input") then
                ImGui.Text(ctx, "Enter value:")
                ImGui.SetNextItemWidth(ctx, 100)
                local val_input_buf = string.format("%.2f", envelope_value)
                local rv, buf = ImGui.InputText(ctx, "##envinput", val_input_buf, ImGui.InputTextFlags_EnterReturnsTrue)
                if rv then
                  local val = tonumber(buf)
                  if val then
                    envelope_value = math.max(min_val, math.min(max_val, val))
                  end
                  ImGui.CloseCurrentPopup(ctx)
                end
                ImGui.EndPopup(ctx)
              end
            elseif selected_envelope.type == "fx" then
              local param_min, param_max, _, is_normalized = get_fx_param_range(
                selected_envelope.track,
                selected_envelope.fx_idx,
                selected_envelope.param_idx
              )

              min_val, max_val = param_min, param_max
              label = is_normalized and "Value (normalized):" or "Value:"

              ImGui.Text(ctx, label)

              local old_val = reaper.TrackFX_GetParam(selected_envelope.track,
                selected_envelope.fx_idx,
                selected_envelope.param_idx)
              reaper.TrackFX_SetParam(selected_envelope.track,
                selected_envelope.fx_idx,
                selected_envelope.param_idx,
                envelope_value)
              local _, formatted_val = reaper.TrackFX_GetFormattedParamValue(selected_envelope.track,
                selected_envelope.fx_idx,
                selected_envelope.param_idx, "")
              reaper.TrackFX_SetParam(selected_envelope.track,
                selected_envelope.fx_idx,
                selected_envelope.param_idx,
                old_val)

              ImGui.SetNextItemWidth(ctx, -1)
              local changed_val, new_val = ImGui.SliderDouble(ctx, "##envvalue", envelope_value, min_val, max_val,
                formatted_val)

              if changed_val then
                envelope_value = new_val
              end

              if ImGui.IsItemHovered(ctx) then
                local tooltip = "Drag to adjust. Current: " .. formatted_val
                if not is_normalized then
                  tooltip = tooltip .. string.format("\nRange: %.2f to %.2f", min_val, max_val)
                end
                tooltip = tooltip .. "\nRight-click to type value"
                ImGui.SetTooltip(ctx, tooltip)
              end

              if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
                ImGui.OpenPopup(ctx, "fx_value_input")
              end

              if ImGui.BeginPopup(ctx, "fx_value_input") then
                ImGui.Text(ctx, "Enter value:")
                ImGui.SetNextItemWidth(ctx, 100)
                local display_val = formatted_val:match("[-+]?[0-9]*%.?[0-9]+") or string.format("%.2f", envelope_value)
                local rv, buf = ImGui.InputText(ctx, "##fxinput", display_val, ImGui.InputTextFlags_EnterReturnsTrue)
                if rv then
                  local input_num = tonumber(buf)
                  if input_num then
                    local best_val = envelope_value
                    local best_diff = math.huge

                    for i = 0, 200 do
                      local test_val = i / 200
                      reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx,
                        selected_envelope.param_idx, test_val)
                      local _, test_str = reaper.TrackFX_GetFormattedParamValue(selected_envelope.track,
                        selected_envelope.fx_idx, selected_envelope.param_idx, "")
                      local test_num = tonumber(test_str:match("[-+]?[0-9]*%.?[0-9]+"))

                      if test_num then
                        local diff = math.abs(test_num - input_num)
                        if diff < best_diff then
                          best_diff = diff
                          best_val = test_val
                        end
                        if diff < 0.01 then break end
                      end
                    end

                    reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx,
                      selected_envelope.param_idx, old_val)
                    envelope_value = best_val
                  end
                  ImGui.CloseCurrentPopup(ctx)
                end
                ImGui.EndPopup(ctx)
              end
            end
          else
            ImGui.TextWrapped(ctx, "Please select an envelope from the tabs above")
          end
        else
          ImGui.Text(ctx, "Volume (dB):")
          ImGui.SetNextItemWidth(ctx, -1)
          local changed_vol, new_vol = ImGui.SliderDouble(ctx, "##volume", volume_db, -150.0, 12.0, "%.1f dB")

          if ImGui.IsItemDeactivated(ctx) and volume_reset then
            volume_db = 0.0
            volume_reset = false
          elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
            volume_reset = true
          end

          if changed_vol then
            volume_db = new_vol
          end

          if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Double-click to reset to 0dB, right-click to type value")
          end

          if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
            ImGui.OpenPopup(ctx, "vol_input")
          end

          if ImGui.BeginPopup(ctx, "vol_input") then
            ImGui.Text(ctx, "Enter volume (dB):")
            ImGui.SetNextItemWidth(ctx, 100)
            local vol_input_buf = string.format("%.1f", volume_db)
            local rv, buf = ImGui.InputText(ctx, "##dbinput", vol_input_buf, ImGui.InputTextFlags_EnterReturnsTrue)
            if rv then
              local db_val = tonumber(buf)
              if db_val then
                volume_db = math.max(-150, math.min(12, db_val))
              end
              ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
          end
        end

        ImGui.Separator(ctx)

        ImGui.Text(ctx, "Mode: Time Selection")
        ImGui.Text(ctx, string.format("Range: %s - %s", format_time(start_time), format_time(end_time)))

        ImGui.Spacing(ctx)

        local is_toggle = advanced_mode and selected_envelope and
            selected_envelope.type == "track" and selected_envelope.name == "Mute"

        if is_toggle then
          ImGui.BeginDisabled(ctx)
        end

        ImGui.Text(ctx, "Ramp In (seconds before selection):")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_in, new_in = ImGui.SliderDouble(ctx, "##ramp_in", ramp_in, 0.0, 10.0, "%.2f sec")
        if changed_in then
          ramp_in = math.max(0, new_in)
        end

        if ImGui.IsItemHovered(ctx) then
          ImGui.SetTooltip(ctx, "Right-click to type value")
        end

        if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
          ImGui.OpenPopup(ctx, "ramp_in_input")
        end

        if ImGui.BeginPopup(ctx, "ramp_in_input") then
          ImGui.Text(ctx, "Enter ramp in (seconds):")
          ImGui.SetNextItemWidth(ctx, 100)
          local ramp_in_buf = string.format("%.2f", ramp_in)
          local rv, buf = ImGui.InputText(ctx, "##rampininput", ramp_in_buf, ImGui.InputTextFlags_EnterReturnsTrue)
          if rv then
            local val = tonumber(buf)
            if val then
              ramp_in = math.max(0, val)
            end
            ImGui.CloseCurrentPopup(ctx)
          end
          ImGui.EndPopup(ctx)
        end

        ImGui.Text(ctx, "Ramp Out (seconds after selection):")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_out, new_out = ImGui.SliderDouble(ctx, "##ramp_out", ramp_out, 0.0, 10.0, "%.2f sec")
        if changed_out then
          ramp_out = math.max(0, new_out)
        end

        if ImGui.IsItemHovered(ctx) then
          ImGui.SetTooltip(ctx, "Right-click to type value")
        end

        if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
          ImGui.OpenPopup(ctx, "ramp_out_input")
        end

        if ImGui.BeginPopup(ctx, "ramp_out_input") then
          ImGui.Text(ctx, "Enter ramp out (seconds):")
          ImGui.SetNextItemWidth(ctx, 100)
          local ramp_out_buf = string.format("%.2f", ramp_out)
          local rv, buf = ImGui.InputText(ctx, "##rampoutinput", ramp_out_buf, ImGui.InputTextFlags_EnterReturnsTrue)
          if rv then
            local val = tonumber(buf)
            if val then
              ramp_out = math.max(0, val)
            end
            ImGui.CloseCurrentPopup(ctx)
          end
          ImGui.EndPopup(ctx)
        end
        if is_toggle then
          ImGui.EndDisabled(ctx)
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        local changed_keep, new_keep = ImGui.Checkbox(ctx, "Keep window open after applying", keep_window_open)
        if changed_keep then
          keep_window_open = new_keep
          SetProjExtState(0, "ReaClassical", "KeepAutomationWindowOpen", keep_window_open and "1" or "0")
        end

        ImGui.Spacing(ctx)

        local can_apply = true
        if advanced_mode and not selected_envelope then
          can_apply = false
        end

        if not can_apply then
          ImGui.BeginDisabled(ctx)
        end

        local avail_w_button = ImGui.GetContentRegionAvail(ctx)
        if ImGui.Button(ctx, "Apply Automation", avail_w_button, 30) then
          preview.clear()
          apply_automation()
          if not keep_window_open then
            Main_OnCommand(40635, 0)
          end
        end

        if not can_apply then
          ImGui.EndDisabled(ctx)
        end
      end

      refresh_preview_target()
      apply_preview_now()

      if gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end
      ImGui.End(ctx)
    end

    defer(main)
  end
end

function is_toggle_parameter(track, fx_idx, param_idx, envelope_info)
  if envelope_info and envelope_info.type == "track" and envelope_info.name == "Mute" then
    return true
  end

  if envelope_info and envelope_info.type == "fx" and fx_idx ~= nil and param_idx ~= nil then
    local current_val = reaper.TrackFX_GetParam(track, fx_idx, param_idx)

    reaper.TrackFX_SetParam(track, fx_idx, param_idx, 0)
    local _, val_at_0 = reaper.TrackFX_GetFormattedParamValue(track, fx_idx, param_idx, "")

    reaper.TrackFX_SetParam(track, fx_idx, param_idx, 1)
    local _, val_at_1 = reaper.TrackFX_GetFormattedParamValue(track, fx_idx, param_idx, "")

    reaper.TrackFX_SetParam(track, fx_idx, param_idx, 0.5)
    local _, val_at_mid = reaper.TrackFX_GetFormattedParamValue(track, fx_idx, param_idx, "")

    reaper.TrackFX_SetParam(track, fx_idx, param_idx, current_val)

    if val_at_mid == val_at_0 or val_at_mid == val_at_1 then
      return true
    end
  end

  return false
end

defer(main)
