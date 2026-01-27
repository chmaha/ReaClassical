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

local main, apply_automation, linear_to_db, db_to_linear, get_envelope_value_at_time
local format_time, get_selected_tracks, get_track_envelopes, get_track_fx_params
local normalize_value, denormalize_value

---------------------------------------------------------------------

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

package.path              = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui               = require 'imgui' '0.10'

local ctx                 = ImGui.CreateContext('ReaClassical Volume Automation')
local window_open         = true

local DEFAULT_W           = 400
local DEFAULT_H           = 180

local selected_tracks     = {}
local volume_db           = 0.0
local ramp_in             = 0.0
local ramp_out            = 0.0
local has_time_sel        = false
local start_time          = 0
local end_time            = 0

-- Track last cursor/time selection position to detect changes
local last_cursor_pos     = nil
local last_time_sel_start = nil
local last_time_sel_end   = nil
local last_track_count    = 0

-- Reset flag for double-click
local volume_reset        = false

-- Advanced mode variables
local advanced_mode       = false
local selected_envelope   = nil
local envelope_value      = 0.0
local track_envelopes     = {}
local fx_params           = {}
local current_tab         = 0 -- 0 = Track, 1 = FX
local keep_window_open    = false

-- Track last FX count to detect changes
local last_fx_count       = 0

---------------------------------------------------------------------

function get_selected_tracks()
  local tracks = {}
  local count = CountSelectedTracks(0)
  for i = 0, count - 1 do
    tracks[#tracks + 1] = GetSelectedTrack(0, i)
  end
  return tracks
end

---------------------------------------------------------------------

function get_track_envelopes(track)
  local envelopes = {}
  
  -- Standard track envelopes
  local standard_envs = {
    {name = "Volume", display = "Volume"},
    {name = "Pan", display = "Pan"},
    {name = "Width", display = "Width"},
    {name = "Volume (Pre-FX)", display = "Volume (Pre-FX)"},
    {name = "Pan (Pre-FX)", display = "Pan (Pre-FX)"},
    {name = "Width (Pre-FX)", display = "Width (Pre-FX)"},
    {name = "Trim Volume", display = "Trim Volume"},
    {name = "Mute", display = "Mute"},
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

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function format_time(time_seconds)
  -- Format time according to project time format
  local time_str = format_timestr_pos(time_seconds, "", 5)
  return time_str
end

---------------------------------------------------------------------

function linear_to_db(val)
  -- Convert linear volume value to dB
  -- REAPER uses: 1.0 = 0dB, 0 = -inf dB
  if val <= 0.0000000298023223876953125 then -- -150 dB
    return -150.0
  end
  return 20 * math.log(val, 10)
end

---------------------------------------------------------------------

function db_to_linear(db)
  -- Convert dB to linear volume value
  if db <= -150 then
    return 0.0
  end
  return 10 ^ (db / 20)
end

---------------------------------------------------------------------

function normalize_value(envelope_info, raw_value)
  -- Normalize envelope value to a displayable range
  if not envelope_info then return 0 end
  
  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return linear_to_db(raw_value)
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return raw_value -- Keep as -1 to +1
    elseif envelope_info.name == "Width" or envelope_info.name == "Width (Pre-FX)" then
      return raw_value -- Keep as -1 to +1
    elseif envelope_info.name == "Mute" then
      return raw_value -- 0 or 1
    end
  elseif envelope_info.type == "fx" then
    -- For FX parameters, return the raw 0-1 normalized value
    -- We'll use TrackFX_GetFormattedParamValue for display
    return raw_value
  end
  
  return raw_value
end

---------------------------------------------------------------------

function denormalize_value(envelope_info, display_value)
  -- Convert display value back to envelope value
  if not envelope_info then return 0 end
  
  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return db_to_linear(display_value)
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return display_value -- Already in -1 to +1 range
    elseif envelope_info.name == "Width" or envelope_info.name == "Width (Pre-FX)" then
      return display_value -- Already in -1 to +1 range
    elseif envelope_info.name == "Mute" then
      return display_value
    end
  elseif envelope_info.type == "fx" then
    -- For FX parameters, the envelope stores values in the actual parameter range
    -- So we just return the display value as-is
    return display_value
  end
  
  return display_value
end

---------------------------------------------------------------------

function get_envelope_value_at_time(envelope, time)
  -- Use BR_EnvValueAtPos to get the envelope value at a time
  -- This returns the actual linear value
  if not envelope then return nil end

  local br_env = BR_EnvAlloc(envelope, false)
  local value = BR_EnvValueAtPos(br_env, time)
  BR_EnvFree(br_env, false)

  return value
end

---------------------------------------------------------------------

function get_fx_param_range(track, fx_idx, param_idx)
  -- Get actual parameter range for the FX parameter
  -- Returns min, max, current_value_in_range, is_normalized
  local current_val, min_val, max_val = reaper.TrackFX_GetParam(track, fx_idx, param_idx)
  
  -- Ensure min is always less than max
  if min_val > max_val then
    min_val, max_val = max_val, min_val
  end
  
  -- Check if this is a normalized 0-1 parameter (most VST/VST3)
  -- or if it has a custom range (JSFX, some LV2)
  if math.abs(min_val - 0.0) < 0.001 and math.abs(max_val - 1.0) < 0.001 then
    -- Standard normalized parameter - current value is already in 0-1 range
    return 0.0, 1.0, current_val, true
  else
    -- Custom range parameter (JSFX, LV2, etc.)
    -- current_val is already in the actual range!
    return min_val, max_val, current_val, false
  end
end

---------------------------------------------------------------------

function get_default_track_value(track, envelope_info)
  -- Get the default track value for a given envelope type when no envelope exists
  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return GetMediaTrackInfo_Value(track, "D_VOL")
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return GetMediaTrackInfo_Value(track, "D_PAN")
    elseif envelope_info.name == "Width" or envelope_info.name == "Width (Pre-FX)" then
      return GetMediaTrackInfo_Value(track, "D_WIDTH")
    elseif envelope_info.name == "Mute" then
      return GetMediaTrackInfo_Value(track, "B_MUTE")
    end
  elseif envelope_info.type == "fx" then
    return TrackFX_GetParam(track, envelope_info.fx_idx, envelope_info.param_idx)
  end
  return 1.0 -- Default fallback
end

---------------------------------------------------------------------

function apply_automation()
  if #selected_tracks == 0 then return end

  local target_envelope_info = advanced_mode and selected_envelope or {
    type = "track",
    name = "Volume",
    display = "Volume"
  }
  
  if not target_envelope_info then return end

  -- Convert value based on envelope type
  local target_value
  if advanced_mode then
    target_value = denormalize_value(target_envelope_info, envelope_value)
  else
    target_value = db_to_linear(volume_db)
  end

  -- Apply to each selected track
  for _, track in ipairs(selected_tracks) do
    -- Get or create envelope
    local env
    
    if target_envelope_info.type == "track" then
      env = GetTrackEnvelopeByName(track, target_envelope_info.name)
      if not env then
        -- Create envelope if it doesn't exist
        SetOnlyTrackSelected(track)
        -- Show envelope based on type
        if target_envelope_info.name == "Volume" then
          Main_OnCommand(40406, 0)
        elseif target_envelope_info.name == "Pan" then
          Main_OnCommand(40407, 0)
        elseif target_envelope_info.name == "Width" then
          Main_OnCommand(41991, 0)
        elseif target_envelope_info.name == "Mute" then
          Main_OnCommand(40867, 0)
        elseif target_envelope_info.name == "Volume (Pre-FX)" then
          Main_OnCommand(41865, 0)
        elseif target_envelope_info.name == "Pan (Pre-FX)" then
          Main_OnCommand(41866, 0)
        elseif target_envelope_info.name == "Width (Pre-FX)" then
          Main_OnCommand(41867, 0)
        elseif target_envelope_info.name == "Trim Volume" then
          Main_OnCommand(41612, 0)
        end
        env = GetTrackEnvelopeByName(track, target_envelope_info.name)
        if not env then goto continue end
      end
    elseif target_envelope_info.type == "fx" then
      env = GetFXEnvelope(track, target_envelope_info.fx_idx, target_envelope_info.param_idx, true)
      if not env then goto continue end
    end

    -- Determine if we need to scale values (only for volume envelopes)
    local needs_scaling = target_envelope_info.type == "track" and 
                         (target_envelope_info.name == "Volume" or 
                          target_envelope_info.name == "Volume (Pre-FX)" or 
                          target_envelope_info.name == "Trim Volume")

    if has_time_sel and (start_time ~= end_time) then
      -- Time selection mode with ramps OUTSIDE the selection
      local actual_start = start_time
      local actual_end = end_time

      -- Calculate ramp start/end times OUTSIDE the time selection
      local ramp_in_start = actual_start - ramp_in
      local ramp_out_end = actual_end + ramp_out

      -- Get values at boundaries BEFORE deleting anything
      local val_before, val_after

      if ramp_in > 0 then
        val_before = get_envelope_value_at_time(env, ramp_in_start)
        if not val_before then
          val_before = get_default_track_value(track, target_envelope_info)
        end
      else
        val_before = get_envelope_value_at_time(env, actual_start - 0.001)
        if not val_before then
          val_before = get_default_track_value(track, target_envelope_info)
        end
      end

      if ramp_out > 0 then
        val_after = get_envelope_value_at_time(env, ramp_out_end)
        if not val_after then
          val_after = get_default_track_value(track, target_envelope_info)
        end
      else
        val_after = get_envelope_value_at_time(env, actual_end + 0.001)
        if not val_after then
          val_after = get_default_track_value(track, target_envelope_info)
        end
      end

      -- Clear existing points in the entire range including ramps
      local clear_start = ramp_in > 0 and ramp_in_start or (actual_start - 0.002)
      local clear_end = ramp_out > 0 and ramp_out_end or (actual_end + 0.002)
      DeleteEnvelopePointRange(env, clear_start - 0.001, clear_end + 0.001)

      -- Scale values if needed (only for volume envelopes)
      local target_val_to_insert = needs_scaling and ScaleToEnvelopeMode(1, target_value) or target_value
      local val_before_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_before) or val_before
      local val_after_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_after) or val_after

      -- Add points based on ramp settings
      if ramp_in > 0 then
        InsertEnvelopePoint(env, ramp_in_start, val_before_to_insert, 0, 0, false, true)
        InsertEnvelopePoint(env, actual_start, target_val_to_insert, 0, 0, false, true)
      else
        InsertEnvelopePoint(env, actual_start - 0.001, val_before_to_insert, 0, 0, false, true)
        InsertEnvelopePoint(env, actual_start, target_val_to_insert, 0, 0, false, true)
      end

      if ramp_out > 0 then
        InsertEnvelopePoint(env, actual_end, target_val_to_insert, 0, 0, false, true)
        InsertEnvelopePoint(env, ramp_out_end, val_after_to_insert, 0, 0, false, true)
      else
        InsertEnvelopePoint(env, actual_end, target_val_to_insert, 0, 0, false, true)
        InsertEnvelopePoint(env, actual_end + 0.001, val_after_to_insert, 0, 0, false, true)
      end
    else
      -- Edit cursor mode with optional ramp in
      local cursor_pos = GetCursorPosition()
      local ramp_start = cursor_pos - ramp_in

      -- Get value BEFORE deleting anything
      local val_before
      if ramp_in > 0 then
        val_before = get_envelope_value_at_time(env, ramp_start)
        if not val_before then
          val_before = get_default_track_value(track, target_envelope_info)
        end
      else
        val_before = get_envelope_value_at_time(env, cursor_pos - 0.001)
        if not val_before then
          val_before = get_default_track_value(track, target_envelope_info)
        end
      end

      -- Delete existing points from ramp start onwards
      local num_points = CountEnvelopePoints(env)
      local delete_from = ramp_in > 0 and ramp_start or (cursor_pos - 0.002)
      for i = num_points - 1, 0, -1 do
        local _, time = GetEnvelopePoint(env, i)
        if time >= delete_from then
          DeleteEnvelopePointEx(env, -1, i)
        end
      end

      -- Scale values if needed (only for volume envelopes)
      local target_val_to_insert = needs_scaling and ScaleToEnvelopeMode(1, target_value) or target_value
      local val_before_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_before) or val_before

      -- Insert new points
      if ramp_in > 0 then
        InsertEnvelopePoint(env, ramp_start, val_before_to_insert, 0, 0, false, true)
        InsertEnvelopePoint(env, cursor_pos, target_val_to_insert, 0, 0, false, true)
      else
        InsertEnvelopePoint(env, cursor_pos - 0.001, val_before_to_insert, 0, 0, false, true)
        InsertEnvelopePoint(env, cursor_pos, target_val_to_insert, 0, 0, false, true)
      end
    end

    Envelope_SortPoints(env)

    ::continue::
  end

  UpdateArrange()
  
  -- Only close window if keep_window_open is false
  if not keep_window_open then
    window_open = false
  end
end

---------------------------------------------------------------------

function main()
  -- Load advanced mode state from project
  local _, adv_mode_str = GetProjExtState(0, "ReaClassical", "AdvancedAutomationMode")
  if adv_mode_str == "1" then
    advanced_mode = true
  else
    advanced_mode = false
  end

  -- Get currently selected tracks
  local tracks = get_selected_tracks()
  local track_count = #tracks

  -- Get current cursor and time selection
  local current_cursor = GetCursorPosition()
  local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  local current_has_time_sel = (ts_start ~= ts_end)
  
  -- Check if FX count changed (to refresh FX list)
  local current_fx_count = 0
  if track_count > 0 then
    current_fx_count = TrackFX_GetCount(tracks[1])
  end
  local fx_count_changed = (current_fx_count ~= last_fx_count)
  if fx_count_changed then
    last_fx_count = current_fx_count
  end

  -- Detect if track selection changed
  if track_count ~= last_track_count or
      (track_count > 0 and tracks[1] ~= selected_tracks[1]) then
    selected_tracks = tracks
    last_track_count = track_count
    last_cursor_pos = current_cursor
    last_time_sel_start = ts_start
    last_time_sel_end = ts_end
    last_fx_count = current_fx_count

    if track_count > 0 then
      -- Refresh envelope lists for advanced mode
      if advanced_mode then
        track_envelopes = get_track_envelopes(tracks[1])
        fx_params = get_track_fx_params(tracks[1])
      end
      
      -- Get current value at cursor or time selection start from first track
      local first_track = tracks[1]
      local query_time = current_has_time_sel and ts_start or current_cursor

      if advanced_mode and selected_envelope then
        local env
        if selected_envelope.type == "track" then
          env = GetTrackEnvelopeByName(first_track, selected_envelope.name)
        elseif selected_envelope.type == "fx" then
          env = GetFXEnvelope(first_track, selected_envelope.fx_idx, selected_envelope.param_idx, false)
        end
        
        if env then
          local env_val = get_envelope_value_at_time(env, query_time)
          if env_val then
            if selected_envelope.type == "track" then
              envelope_value = normalize_value(selected_envelope, env_val)
            else
              -- FX parameters: envelope stores values in actual parameter range
              envelope_value = env_val
            end
          end
        end
      else
        -- Standard volume mode
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

    -- Update value based on new position from first track
    local first_track = tracks[1]
    local query_time = current_has_time_sel and ts_start or current_cursor

    if advanced_mode and selected_envelope then
      local env
      if selected_envelope.type == "track" then
        env = GetTrackEnvelopeByName(first_track, selected_envelope.name)
      elseif selected_envelope.type == "fx" then
        env = GetFXEnvelope(first_track, selected_envelope.fx_idx, selected_envelope.param_idx, false)
      end
      
      if env then
        local env_val = get_envelope_value_at_time(env, query_time)
        if env_val then
          if selected_envelope.type == "track" then
            envelope_value = normalize_value(selected_envelope, env_val)
          else
            -- FX parameters: envelope stores values in actual parameter range
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

  -- Update time selection status
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
      else
        -- Display selected tracks
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
        
        -- Advanced mode checkbox
        local changed_adv, new_adv = ImGui.Checkbox(ctx, "Advanced Mode", advanced_mode)
        if changed_adv then
          advanced_mode = new_adv
          SetProjExtState(0, "ReaClassical", "AdvancedAutomationMode", advanced_mode and "1" or "0")
          
          if advanced_mode and #selected_tracks > 0 then
            track_envelopes = get_track_envelopes(selected_tracks[1])
            fx_params = get_track_fx_params(selected_tracks[1])
          end
        end
        
        ImGui.Separator(ctx)

        if advanced_mode then
          -- Advanced mode: Show tabs for track and FX envelopes
          if ImGui.BeginTabBar(ctx, "EnvelopeTabs") then
            if ImGui.BeginTabItem(ctx, "Track Envelopes") then
              if current_tab ~= 0 then
                current_tab = 0
              end
              
              ImGui.Text(ctx, "Select Envelope:")
              -- Calculate height needed for all track envelopes (8 items)
              -- Each item needs more space - using 24 pixels per item plus padding
              local track_env_height = #track_envelopes * 21 + 16
              ImGui.BeginChild(ctx, "TrackEnvList", 0, track_env_height, ImGui.ChildFlags_Borders)
              
              for i, env_info in ipairs(track_envelopes) do
                local is_selected = selected_envelope and 
                                   selected_envelope.type == "track" and 
                                   selected_envelope.name == env_info.name
                
                if ImGui.Selectable(ctx, env_info.display, is_selected) then
                  selected_envelope = env_info
                  
                  -- Update value for newly selected envelope
                  local first_track = selected_tracks[1]
                  local query_time = has_time_sel and start_time or GetCursorPosition()
                  local env = GetTrackEnvelopeByName(first_track, env_info.name)
                  
                  if env then
                    local env_val = get_envelope_value_at_time(env, query_time)
                    if env_val then
                      envelope_value = normalize_value(env_info, env_val)
                    else
                      envelope_value = 0
                    end
                  else
                    -- Get default track value when no envelope exists
                    if env_info.name == "Volume" or env_info.name == "Volume (Pre-FX)" or env_info.name == "Trim Volume" then
                      local vol = GetMediaTrackInfo_Value(first_track, "D_VOL")
                      envelope_value = linear_to_db(vol)
                    elseif env_info.name == "Pan" or env_info.name == "Pan (Pre-FX)" then
                      envelope_value = GetMediaTrackInfo_Value(first_track, "D_PAN")
                    elseif env_info.name == "Width" or env_info.name == "Width (Pre-FX)" then
                      envelope_value = GetMediaTrackInfo_Value(first_track, "D_WIDTH")
                    elseif env_info.name == "Mute" then
                      envelope_value = GetMediaTrackInfo_Value(first_track, "B_MUTE")
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
              -- Refresh FX list when switching to this tab or when FX count changed
              if current_tab ~= 1 or fx_count_changed then
                current_tab = 1
                if #selected_tracks > 0 then
                  fx_params = get_track_fx_params(selected_tracks[1])
                end
              end
              
              ImGui.Text(ctx, "Select FX Parameter:")
              ImGui.BeginChild(ctx, "FXParamList", 0, 150, ImGui.ChildFlags_Borders)
              
              if #fx_params == 0 then
                ImGui.TextWrapped(ctx, "No FX on selected track")
              else
                for _, fx_info in ipairs(fx_params) do
                  if ImGui.TreeNode(ctx, fx_info.fx_name) then
                    for _, param_info in ipairs(fx_info.params) do
                      local is_selected = selected_envelope and 
                                         selected_envelope.type == "fx" and 
                                         selected_envelope.fx_idx == param_info.fx_idx and
                                         selected_envelope.param_idx == param_info.param_idx
                      
                      if ImGui.Selectable(ctx, param_info.display, is_selected) then
                        selected_envelope = param_info
                        
                        -- Update value for newly selected parameter
                        local first_track = selected_tracks[1]
                        local query_time = has_time_sel and start_time or GetCursorPosition()
                        local env = GetFXEnvelope(first_track, param_info.fx_idx, param_info.param_idx, false)
                        
                        if env then
                          local env_val = get_envelope_value_at_time(env, query_time)
                          if env_val then
                            -- Envelope stores values in actual parameter range
                            envelope_value = env_val
                          else
                            envelope_value = 0
                          end
                        else
                          -- Get current parameter value (in actual parameter range)
                          local _, _, current_val, _ = get_fx_param_range(first_track, param_info.fx_idx, param_info.param_idx)
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
            -- Show value control for selected envelope
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
                label = "Value (0=Unmuted, 1=Muted):"
              else
                min_val, max_val = 0.0, 100.0
                format_str = "%.1f"
                label = "Value:"
              end
              
              ImGui.Text(ctx, label)
              ImGui.SetNextItemWidth(ctx, -1)
              local changed_val, new_val = ImGui.SliderDouble(ctx, "##envvalue", envelope_value, min_val, max_val, format_str)
              
              if changed_val then
                envelope_value = new_val
              end
              
              if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Right-click to type value")
              end
              
              -- Right-click popup for typing value
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
              -- FX parameters: get actual range (normalized 0-1 or custom range for JSFX/LV2)
              local param_min, param_max, _, is_normalized = get_fx_param_range(
                selected_envelope.track,
                selected_envelope.fx_idx,
                selected_envelope.param_idx
              )
              
              min_val, max_val = param_min, param_max
              label = is_normalized and "Value (normalized):" or "Value:"
              
              ImGui.Text(ctx, label)
              
              -- Get formatted parameter value for display based on current envelope_value
              -- Temporarily set the param to get its formatted value
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
              local changed_val, new_val = ImGui.SliderDouble(ctx, "##envvalue", envelope_value, min_val, max_val, formatted_val)
              
              if changed_val then
                envelope_value = new_val
              end
              
              if ImGui.IsItemHovered(ctx) then
                local tooltip = "Drag to adjust. Current: " .. formatted_val
                if not is_normalized then
                  tooltip = tooltip .. string.format("\nRange: %.2f to %.2f", min_val, max_val)
                end
                ImGui.SetTooltip(ctx, tooltip)
              end
            end
          else
            ImGui.TextWrapped(ctx, "Please select an envelope from the tabs above")
          end
          
        else
          -- Standard mode: Volume only
          ImGui.Text(ctx, "Volume (dB):")
          ImGui.SetNextItemWidth(ctx, -1)
          local changed_vol, new_vol = ImGui.SliderDouble(ctx, "##volume", volume_db, -150.0, 12.0, "%.1f dB")

          -- Check for double-click reset to 0dB
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

          -- Right-click popup for typing dB value
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

        -- Mode indicator
        if has_time_sel then
          ImGui.Text(ctx, "Mode: Time Selection")
          ImGui.Text(ctx, string.format("Range: %s - %s", format_time(start_time), format_time(end_time)))

          ImGui.Spacing(ctx)

          -- Ramp controls (outside the time selection)
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
        else
          ImGui.Text(ctx, "Mode: Edit Cursor to End")
          local cursor_pos = GetCursorPosition()
          ImGui.Text(ctx, string.format("Cursor: %s", format_time(cursor_pos)))

          ImGui.Spacing(ctx)

          -- Ramp in control for cursor mode
          ImGui.Text(ctx, "Ramp In (seconds before cursor):")
          ImGui.SetNextItemWidth(ctx, -1)
          local changed_in, new_in = ImGui.SliderDouble(ctx, "##ramp_in_cursor", ramp_in, 0.0, 10.0, "%.2f sec")
          if changed_in then
            ramp_in = math.max(0, new_in)
          end

          if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Right-click to type value")
          end

          if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
            ImGui.OpenPopup(ctx, "ramp_in_cursor_input")
          end

          if ImGui.BeginPopup(ctx, "ramp_in_cursor_input") then
            ImGui.Text(ctx, "Enter ramp in (seconds):")
            ImGui.SetNextItemWidth(ctx, 100)
            local ramp_in_buf = string.format("%.2f", ramp_in)
            local rv, buf = ImGui.InputText(ctx, "##rampincursorinput", ramp_in_buf,
              ImGui.InputTextFlags_EnterReturnsTrue)
            if rv then
              local val = tonumber(buf)
              if val then
                ramp_in = math.max(0, val)
              end
              ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
          end
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Keep window open checkbox
        local changed_keep, new_keep = ImGui.Checkbox(ctx, "Keep window open after applying", keep_window_open)
        if changed_keep then
          keep_window_open = new_keep
        end

        ImGui.Spacing(ctx)

        -- Apply button
        local can_apply = true
        if advanced_mode and not selected_envelope then
          can_apply = false
        end
        
        if not can_apply then
          ImGui.BeginDisabled(ctx)
        end
        
        local avail_w_button = ImGui.GetContentRegionAvail(ctx)
        if ImGui.Button(ctx, "Apply Automation", avail_w_button, 30) then
          apply_automation()
          if not keep_window_open then
            Main_OnCommand(40635, 0) -- remove time selection if present
          end
        end
        
        if not can_apply then
          ImGui.EndDisabled(ctx)
        end
      end

      ImGui.End(ctx)
    end

    defer(main)
  end
end

---------------------------------------------------------------------

defer(main)