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
local format_time, get_track_envelopes, get_track_fx_params
local normalize_value, denormalize_value, get_fx_param_range, is_toggle_parameter
local check_automation_item_validity, get_selected_automation_item

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

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('Edit Automation Item')
local window_open = true

local DEFAULT_W = 400
local DEFAULT_H = 180

-- Variables for the automation item being edited
local editing_ai = {
  env = nil,
  ai_idx = -1,
  start = 0,
  length = 0,
  track = nil
}

local selected_envelope = nil
local envelope_value = 0.0
local ramp_in = 0.0
local ramp_out = 0.0
local original_ramp_in = 0.0
local original_ramp_out = 0.0
local original_val_before = nil
local original_val_after = nil

local no_selection_state = false -- Track if we're in "no selection" state

---------------------------------------------------------------------

function linear_to_db(val)
  if val <= 0.0000000298023223876953125 then
    return -150.0
  end
  return 20 * math.log(val, 10)
end

---------------------------------------------------------------------

function db_to_linear(db)
  if db <= -150 then
    return 0.0
  end
  return 10 ^ (db / 20)
end

---------------------------------------------------------------------

function normalize_value(envelope_info, raw_value)
  if not envelope_info then return 0 end

  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return linear_to_db(raw_value)
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return raw_value
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

---------------------------------------------------------------------

function denormalize_value(envelope_info, display_value)
  if not envelope_info then return 0 end

  if envelope_info.type == "track" then
    if envelope_info.name == "Volume" or envelope_info.name == "Volume (Pre-FX)" or envelope_info.name == "Trim Volume" then
      return db_to_linear(display_value)
    elseif envelope_info.name == "Pan" or envelope_info.name == "Pan (Pre-FX)" then
      return display_value
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

---------------------------------------------------------------------

function get_envelope_value_at_time(envelope, time)
  if not envelope then return nil end

  local br_env = BR_EnvAlloc(envelope, false)
  local value = BR_EnvValueAtPos(br_env, time)
  BR_EnvFree(br_env, false)

  return value
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function format_time(time_seconds)
  local time_str = format_timestr_pos(time_seconds, "", 5)
  return time_str
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function check_automation_item_validity()
  -- Check if the currently tracked automation item still exists and is selected
  if not editing_ai.env or editing_ai.ai_idx < 0 then
    return false
  end
  
  -- Check if envelope still exists
  local test_track = Envelope_GetParentTrack(editing_ai.env)
  if not test_track then
    return false
  end
  
  -- Check if automation item still exists at this index
  local ai_count = CountAutomationItems(editing_ai.env)
  if editing_ai.ai_idx >= ai_count then
    return false
  end
  
  -- Check if this automation item is still selected
  local is_selected = GetSetAutomationItemInfo(editing_ai.env, editing_ai.ai_idx, "D_UISEL", 0, false)
  if is_selected <= 0 then
    return false
  end
  
  return true
end

---------------------------------------------------------------------

function get_selected_automation_item()
  -- Get selected envelope
  local env = GetSelectedEnvelope(0)
  if not env then
    return nil, nil
  end
  
  local ai_count = CountAutomationItems(env)
  local selected_ai_idx = -1
  
  for i = 0, ai_count - 1 do
    local selected = GetSetAutomationItemInfo(env, i, "D_UISEL", 0, false)
    if selected > 0 then
      selected_ai_idx = i
      break
    end
  end
  
  if selected_ai_idx == -1 then
    return nil, nil
  end
  
  return env, selected_ai_idx
end

---------------------------------------------------------------------

function apply_automation()
  if not editing_ai.env or editing_ai.ai_idx < 0 then return end
  if not selected_envelope then return end

  local target_value = denormalize_value(selected_envelope, envelope_value)
  local track = editing_ai.track
  local env = editing_ai.env

  -- Determine if we need to scale values (only for volume envelopes)
  local needs_scaling = selected_envelope.type == "track" and
      (selected_envelope.name == "Volume" or
        selected_envelope.name == "Volume (Pre-FX)" or
        selected_envelope.name == "Trim Volume")

  -- Calculate the stable middle section from the ORIGINAL automation item
  -- using the ORIGINAL detected ramps (not the current slider values)
  local middle_start = editing_ai.start + original_ramp_in
  local middle_end = editing_ai.start + editing_ai.length - original_ramp_out

  -- Use the STORED original boundary values (from initialization)
  local val_before = original_val_before
  local val_after = original_val_after

  -- Select the automation item and delete it
  GetSetAutomationItemInfo(env, editing_ai.ai_idx, "D_UISEL", 1, true)
  Main_OnCommand(42086, 0) -- Envelope: Delete automation items

  -- Calculate the new automation item range
  -- Middle section stays the same, new ramps extend left and right from it
  local new_start = middle_start - ramp_in
  local new_end = middle_end + ramp_out
  local new_length = new_end - new_start

  -- Clear existing points in a WIDER range to ensure we get everything
  DeleteEnvelopePointRange(env, math.min(new_start, editing_ai.start) - 0.002, 
                               math.max(new_end, editing_ai.start + editing_ai.length) + 0.002)

  -- Scale values if needed (only for volume envelopes)
  local target_val_to_insert = needs_scaling and ScaleToEnvelopeMode(1, target_value) or target_value
  local val_before_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_before) or val_before
  local val_after_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_after) or val_after

  -- Add points based on NEW ramp settings
  if ramp_in > 0 then
    InsertEnvelopePoint(env, new_start, val_before_to_insert, 0, 0, false, true)
    InsertEnvelopePoint(env, middle_start, target_val_to_insert, 0, 0, false, true)
  else
    -- When ramp_in is 0, create step transition just inside the automation item
    InsertEnvelopePoint(env, middle_start, val_before_to_insert, 0, 0, false, true)
    InsertEnvelopePoint(env, middle_start + 0.001, target_val_to_insert, 0, 0, false, true)
  end

  if ramp_out > 0 then
    InsertEnvelopePoint(env, middle_end, target_val_to_insert, 0, 0, false, true)
    InsertEnvelopePoint(env, new_end, val_after_to_insert, 0, 0, false, true)
  else
    -- When ramp_out is 0, create step transition just inside the automation item
    InsertEnvelopePoint(env, middle_end - 0.001, target_val_to_insert, 0, 0, false, true)
    InsertEnvelopePoint(env, middle_end, val_after_to_insert, 0, 0, false, true)
  end

  Envelope_SortPoints(env)

  -- Create the automation item with the new length
  InsertAutomationItem(env, -1, new_start, new_length)

  UpdateArrange()
  
  -- After applying, reinitialize with the newly created automation item
  initialize_from_automation_item()
end

---------------------------------------------------------------------

function initialize_from_automation_item()
  -- Get selected automation item
  local env, selected_ai_idx = get_selected_automation_item()
  
  if not env or not selected_ai_idx then
    no_selection_state = true
    return false
  end
  
  -- Get automation item properties
  local ai_pos = GetSetAutomationItemInfo(env, selected_ai_idx, "D_POSITION", 0, false)
  local ai_len = GetSetAutomationItemInfo(env, selected_ai_idx, "D_LENGTH", 0, false)
  
  -- Get track from envelope
  local track = Envelope_GetParentTrack(env)
  if not track then
    no_selection_state = true
    return false
  end
  
  -- Determine envelope type
  local env_info = nil
  
  local standard_envs = {
    "Volume", "Pan", "Width", "Volume (Pre-FX)", 
    "Pan (Pre-FX)", "Width (Pre-FX)", "Trim Volume", "Mute"
  }
  
  for _, name in ipairs(standard_envs) do
    if GetTrackEnvelopeByName(track, name) == env then
      env_info = {
        type = "track",
        name = name,
        display = name,
        track = track
      }
      break
    end
  end
  
  if not env_info then
    local fx_count = TrackFX_GetCount(track)
    for fx_idx = 0, fx_count - 1 do
      local param_count = TrackFX_GetNumParams(track, fx_idx)
      for param_idx = 0, param_count - 1 do
        local param_env = GetFXEnvelope(track, fx_idx, param_idx, false)
        if param_env == env then
          local _, fx_name = TrackFX_GetFXName(track, fx_idx, "")
          local _, param_name = TrackFX_GetParamName(track, fx_idx, param_idx, "")
          env_info = {
            type = "fx",
            fx_idx = fx_idx,
            param_idx = param_idx,
            name = param_name,
            display = param_name,
            track = track,
            fx_name = fx_name
          }
          break
        end
      end
      if env_info then break end
    end
  end
  
  if not env_info then
    no_selection_state = true
    return false
  end
  
  -- Get the value at the exact middle of the automation item (in project time)
  local middle_time = ai_pos + (ai_len / 2)
  local br_env = BR_EnvAlloc(env, false)
  local middle_value = BR_EnvValueAtPos(br_env, middle_time)
  
  -- Store original boundary values (BEFORE any edits)
  original_val_before = BR_EnvValueAtPos(br_env, ai_pos - 0.001)
  if not original_val_before then
    if env_info.type == "track" then
      if env_info.name == "Volume" or env_info.name == "Volume (Pre-FX)" or env_info.name == "Trim Volume" then
        original_val_before = GetMediaTrackInfo_Value(track, "D_VOL")
      elseif env_info.name == "Pan" or env_info.name == "Pan (Pre-FX)" then
        original_val_before = GetMediaTrackInfo_Value(track, "D_PAN")
      elseif env_info.name == "Width" or env_info.name == "Width (Pre-FX)" then
        original_val_before = GetMediaTrackInfo_Value(track, "D_WIDTH")
      elseif env_info.name == "Mute" then
        original_val_before = 1 - GetMediaTrackInfo_Value(track, "B_MUTE")
      else
        original_val_before = 1.0
      end
    elseif env_info.type == "fx" then
      original_val_before = TrackFX_GetParam(track, env_info.fx_idx, env_info.param_idx)
    else
      original_val_before = 1.0
    end
  end
  
  original_val_after = BR_EnvValueAtPos(br_env, ai_pos + ai_len + 0.001)
  if not original_val_after then
    if env_info.type == "track" then
      if env_info.name == "Volume" or env_info.name == "Volume (Pre-FX)" or env_info.name == "Trim Volume" then
        original_val_after = GetMediaTrackInfo_Value(track, "D_VOL")
      elseif env_info.name == "Pan" or env_info.name == "Pan (Pre-FX)" then
        original_val_after = GetMediaTrackInfo_Value(track, "D_PAN")
      elseif env_info.name == "Width" or env_info.name == "Width (Pre-FX)" then
        original_val_after = GetMediaTrackInfo_Value(track, "D_WIDTH")
      elseif env_info.name == "Mute" then
        original_val_after = 1 - GetMediaTrackInfo_Value(track, "B_MUTE")
      else
        original_val_after = 1.0
      end
    elseif env_info.type == "fx" then
      original_val_after = TrackFX_GetParam(track, env_info.fx_idx, env_info.param_idx)
    else
      original_val_after = 1.0
    end
  end
  
  BR_EnvFree(br_env, false)
  
  if not middle_value then
    no_selection_state = true
    return false
  end
  
  -- Analyze automation item points to detect ramps
  local point_count = CountEnvelopePointsEx(env, selected_ai_idx)
  
  local detected_ramp_in = 0
  local detected_ramp_out = 0
  
  if point_count >= 2 then
    local points = {}
    for i = 0, point_count - 1 do
      local _, time, value, shape, tension = GetEnvelopePointEx(env, selected_ai_idx, i)
      -- IMPORTANT: time is in ABSOLUTE PROJECT TIME, need to convert to relative
      local relative_time = time - ai_pos
      
      local point_val = value
      -- For volume envelopes, unscale to compare
      if env_info.type == "track" and 
         (env_info.name == "Volume" or env_info.name == "Volume (Pre-FX)" or env_info.name == "Trim Volume") then
        point_val = ScaleFromEnvelopeMode(1, point_val)
      end
      table.insert(points, {time = relative_time, value = point_val})
    end
    
    table.sort(points, function(a, b) return a.time < b.time end)
    
    -- Find when the middle value is first reached and last maintained
    local tolerance = 0.001 -- Tolerance for floating point comparison
    local first_middle_time = nil
    local last_middle_time = nil
    
    for i, point in ipairs(points) do
      if math.abs(point.value - middle_value) < tolerance then
        if not first_middle_time then
          first_middle_time = point.time
        end
        last_middle_time = point.time
      end
    end
    
    -- Ramp in: left edge (0) to first time middle value is reached
    if first_middle_time then
      detected_ramp_in = first_middle_time  -- from left edge (0) to first middle value
    end
    
    -- Ramp out: last time middle value exists to right edge (ai_len)
    if last_middle_time then
      detected_ramp_out = ai_len - last_middle_time  -- from last middle value to right edge
    end
  end
  
  -- Set up editing state
  editing_ai.env = env
  editing_ai.ai_idx = selected_ai_idx
  editing_ai.start = ai_pos
  editing_ai.length = ai_len
  editing_ai.track = track
  
  selected_envelope = env_info
  
  -- Normalize the middle value for display
  if env_info.type == "track" then
    envelope_value = normalize_value(env_info, middle_value)
  else
    envelope_value = middle_value
  end
  
  ramp_in = detected_ramp_in
  ramp_out = detected_ramp_out
  
  -- Store the original detected ramps
  original_ramp_in = detected_ramp_in
  original_ramp_out = detected_ramp_out
  
  no_selection_state = false
  return true
end

---------------------------------------------------------------------

function main()
  if window_open then
    -- Check if current automation item is still valid
    local current_valid = check_automation_item_validity()
    
    -- If not valid, check if there's a new selection
    if not current_valid then
      local new_env, new_ai_idx = get_selected_automation_item()
      
      -- If there's an automation item selected, initialize it
      -- (either a different one, or the same one being re-selected after no_selection_state)
      if new_env and new_ai_idx then
        if no_selection_state or new_env ~= editing_ai.env or new_ai_idx ~= editing_ai.ai_idx then
          initialize_from_automation_item()
        end
      else
        -- No valid selection - reset tracking variables
        no_selection_state = true
        editing_ai.env = nil
        editing_ai.ai_idx = -1
        editing_ai.track = nil
      end
    else
      -- Check if position or length has changed (automation item was edited externally)
      local current_pos = GetSetAutomationItemInfo(editing_ai.env, editing_ai.ai_idx, "D_POSITION", 0, false)
      local current_len = GetSetAutomationItemInfo(editing_ai.env, editing_ai.ai_idx, "D_LENGTH", 0, false)
      
      if current_pos ~= editing_ai.start or current_len ~= editing_ai.length then
        initialize_from_automation_item()
      end
    end
    
    local _, FLT_MAX = ImGui.NumericLimits_Float()
    ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)
    local opened, open_ref = ImGui.Begin(ctx, "Edit Automation Item", window_open, ImGui.WindowFlags_AlwaysAutoResize)
    window_open = open_ref

    if opened then
      -- If no valid automation item selected, show message
      if no_selection_state then
        ImGui.TextWrapped(ctx, "Please select an automation item on an envelope to edit.")
        ImGui.Spacing(ctx)
        ImGui.TextWrapped(ctx, "The window will update automatically when you select an automation item.")
      else
        -- Display automation item info
        local _, track_name = GetSetMediaTrackInfo_String(editing_ai.track, "P_NAME", "", false)
        if track_name == "" then
          local track_num = GetMediaTrackInfo_Value(editing_ai.track, "IP_TRACKNUMBER")
          track_name = "Track " .. math.floor(track_num)
        end
        ImGui.Text(ctx, "Track: " .. track_name)
        ImGui.Text(ctx, string.format("Position: %s", format_time(editing_ai.start)))
        ImGui.Text(ctx, string.format("Length: %s", format_time(editing_ai.length)))
        
        ImGui.Separator(ctx)

        if selected_envelope then
          -- Show parameter name
          ImGui.Text(ctx, "Parameter: " .. selected_envelope.display)
          
          ImGui.Separator(ctx)

          -- Show value control
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
            local changed_val, new_val = ImGui.SliderDouble(ctx, "##envvalue", envelope_value, min_val, max_val, format_str)
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

            local old_val = reaper.TrackFX_GetParam(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx)
            reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx, envelope_value)
            local _, formatted_val = reaper.TrackFX_GetFormattedParamValue(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx, "")
            reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx, old_val)

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
                    reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx, test_val)
                    local _, test_str = reaper.TrackFX_GetFormattedParamValue(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx, "")
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

                  reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx, old_val)
                  envelope_value = best_val
                end
                ImGui.CloseCurrentPopup(ctx)
              end
              ImGui.EndPopup(ctx)
            end
          end

          ImGui.Separator(ctx)

          -- Ramp controls
          local is_toggle = false
          if selected_envelope.type == "track" then
            is_toggle = is_toggle_parameter(editing_ai.track, nil, nil, selected_envelope)
          elseif selected_envelope.type == "fx" then
            is_toggle = is_toggle_parameter(editing_ai.track, selected_envelope.fx_idx, selected_envelope.param_idx, selected_envelope)
          end

          if is_toggle then
            ImGui.BeginDisabled(ctx)
          end

          ImGui.Text(ctx, "Ramp In (seconds from start):")
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

          ImGui.Text(ctx, "Ramp Out (seconds before end):")
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

          -- Apply button
          local avail_w_button = ImGui.GetContentRegionAvail(ctx)
          if ImGui.Button(ctx, "Apply Changes", avail_w_button, 30) then
            apply_automation()
          end

        else
          ImGui.TextWrapped(ctx, "Could not detect envelope parameter")
        end
      end

      ImGui.End(ctx)
    end

    defer(main)
  end
end

---------------------------------------------------------------------

-- Initialize and start
if not initialize_from_automation_item() then
  -- If no automation item selected initially, still open the window with message
  no_selection_state = true
end

defer(main)