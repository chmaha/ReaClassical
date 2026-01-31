--[[
@noindex

Edit Existing Automation Item
Reads an automation item's values and ramps, allows editing, then replaces it.

Copyright (C) 2022–2026 chmaha
]]

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, apply_automation, linear_to_db, db_to_linear, get_envelope_value_at_time
local format_time, get_track_envelopes, get_track_fx_params
local normalize_value, denormalize_value, get_fx_param_range, is_toggle_parameter

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
local track_envelopes = {}
local fx_params = {}
local current_tab = 0
local keep_window_open = false
local create_auto_item = true

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

  -- Get values at boundaries BEFORE deleting anything
  -- Get these from OUTSIDE the original automation item range
  local br_env = BR_EnvAlloc(env, false)
  
  -- Value before the ORIGINAL item (not the new position)
  local val_before = BR_EnvValueAtPos(br_env, editing_ai.start - 0.001)
  if not val_before then
    if selected_envelope.type == "track" then
      if selected_envelope.name == "Volume" or selected_envelope.name == "Volume (Pre-FX)" or selected_envelope.name == "Trim Volume" then
        val_before = GetMediaTrackInfo_Value(track, "D_VOL")
      elseif selected_envelope.name == "Pan" or selected_envelope.name == "Pan (Pre-FX)" then
        val_before = GetMediaTrackInfo_Value(track, "D_PAN")
      elseif selected_envelope.name == "Width" or selected_envelope.name == "Width (Pre-FX)" then
        val_before = GetMediaTrackInfo_Value(track, "D_WIDTH")
      elseif selected_envelope.name == "Mute" then
        val_before = 1 - GetMediaTrackInfo_Value(track, "B_MUTE")
      else
        val_before = 1.0
      end
    elseif selected_envelope.type == "fx" then
      val_before = TrackFX_GetParam(track, selected_envelope.fx_idx, selected_envelope.param_idx)
    else
      val_before = 1.0
    end
  end
  
  -- Value after the ORIGINAL item (not the new position)
  local val_after = BR_EnvValueAtPos(br_env, editing_ai.start + editing_ai.length + 0.001)
  if not val_after then
    if selected_envelope.type == "track" then
      if selected_envelope.name == "Volume" or selected_envelope.name == "Volume (Pre-FX)" or selected_envelope.name == "Trim Volume" then
        val_after = GetMediaTrackInfo_Value(track, "D_VOL")
      elseif selected_envelope.name == "Pan" or selected_envelope.name == "Pan (Pre-FX)" then
        val_after = GetMediaTrackInfo_Value(track, "D_PAN")
      elseif selected_envelope.name == "Width" or selected_envelope.name == "Width (Pre-FX)" then
        val_after = GetMediaTrackInfo_Value(track, "D_WIDTH")
      elseif selected_envelope.name == "Mute" then
        val_after = 1 - GetMediaTrackInfo_Value(track, "B_MUTE")
      else
        val_after = 1.0
      end
    elseif selected_envelope.type == "fx" then
      val_after = TrackFX_GetParam(track, selected_envelope.fx_idx, selected_envelope.param_idx)
    else
      val_after = 1.0
    end
  end
  
  BR_EnvFree(br_env, false)

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
    InsertEnvelopePoint(env, middle_start - 0.001, val_before_to_insert, 0, 0, false, true)
    InsertEnvelopePoint(env, middle_start, target_val_to_insert, 0, 0, false, true)
  end

  if ramp_out > 0 then
    InsertEnvelopePoint(env, middle_end, target_val_to_insert, 0, 0, false, true)
    InsertEnvelopePoint(env, new_end, val_after_to_insert, 0, 0, false, true)
  else
    InsertEnvelopePoint(env, middle_end, target_val_to_insert, 0, 0, false, true)
    InsertEnvelopePoint(env, middle_end + 0.001, val_after_to_insert, 0, 0, false, true)
  end

  Envelope_SortPoints(env)

  -- Create the automation item with the new length
  InsertAutomationItem(env, -1, new_start, new_length)

  UpdateArrange()

  if not keep_window_open then
    window_open = false
  end
end

---------------------------------------------------------------------

function initialize_from_automation_item()
  -- Get selected automation item
  local env = GetSelectedEnvelope(0)
  if not env then
    MB("Please select an envelope with an automation item", "Error", 0)
    return false
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
    MB("Please select an automation item on the selected envelope", "Error", 0)
    return false
  end

  -- Get automation item properties
  local ai_pos = GetSetAutomationItemInfo(env, selected_ai_idx, "D_POSITION", 0, false)
  local ai_len = GetSetAutomationItemInfo(env, selected_ai_idx, "D_LENGTH", 0, false)

  -- Get track from envelope
  local track = Envelope_GetParentTrack(env)
  if not track then
    MB("Could not get track from envelope", "Error", 0)
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
    MB("Could not determine envelope type", "Error", 0)
    return false
  end

  -- Get the value at the exact middle of the automation item (in project time)
  local middle_time = ai_pos + (ai_len / 2)
  local br_env = BR_EnvAlloc(env, false)
  local middle_value = BR_EnvValueAtPos(br_env, middle_time)
  BR_EnvFree(br_env, false)

  if not middle_value then
    MB("Could not read automation item value", "Error", 0)
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
      table.insert(points, { time = relative_time, value = point_val })
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
      detected_ramp_in = first_middle_time -- from left edge (0) to first middle value
    end

    -- Ramp out: last time middle value exists to right edge (ai_len)
    if last_middle_time then
      detected_ramp_out = ai_len - last_middle_time -- from last middle value to right edge
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

  track_envelopes = get_track_envelopes(track)
  fx_params = get_track_fx_params(track)

  return true
end

---------------------------------------------------------------------

function main()
  if window_open then
    local _, FLT_MAX = ImGui.NumericLimits_Float()
    ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)
    local opened, open_ref = ImGui.Begin(ctx, "Edit Automation Item", window_open, ImGui.WindowFlags_AlwaysAutoResize)
    window_open = open_ref

    if opened then
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

      -- Show envelope selection tabs
      if ImGui.BeginTabBar(ctx, "EnvelopeTabs") then
        if ImGui.BeginTabItem(ctx, "Track Envelopes") then
          current_tab = 0

          ImGui.Text(ctx, "Select Envelope:")
          local track_env_height = #track_envelopes * 21 + 16
          ImGui.BeginChild(ctx, "TrackEnvList", 0, track_env_height, ImGui.ChildFlags_Borders)

          for _, env_info in ipairs(track_envelopes) do
            local is_selected = selected_envelope and
                selected_envelope.type == "track" and
                selected_envelope.name == env_info.name

            if ImGui.Selectable(ctx, env_info.display, is_selected) then
              selected_envelope = env_info

              -- Update value for newly selected envelope
              local env = GetTrackEnvelopeByName(editing_ai.track, env_info.name)
              if env then
                local env_val = get_envelope_value_at_time(env, editing_ai.start)
                if env_val then
                  envelope_value = normalize_value(env_info, env_val)
                end
              end
            end
          end

          ImGui.EndChild(ctx)
          ImGui.EndTabItem(ctx)
        end

        if ImGui.BeginTabItem(ctx, "FX Parameters") then
          current_tab = 1

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

                    local env = GetFXEnvelope(editing_ai.track, param_info.fx_idx, param_info.param_idx, false)
                    if env then
                      local env_val = get_envelope_value_at_time(env, editing_ai.start)
                      if env_val then
                        envelope_value = env_val
                      end
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
        -- Show value control
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
          local changed_val, new_val = ImGui.SliderDouble(ctx, "##envvalue", envelope_value, min_val, max_val, format_str)
          if changed_val then
            envelope_value = new_val
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

          local old_val = reaper.TrackFX_GetParam(selected_envelope.track, selected_envelope.fx_idx,
            selected_envelope.param_idx)
          reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx,
            envelope_value)
          local _, formatted_val = reaper.TrackFX_GetFormattedParamValue(selected_envelope.track,
            selected_envelope.fx_idx, selected_envelope.param_idx, "")
          reaper.TrackFX_SetParam(selected_envelope.track, selected_envelope.fx_idx, selected_envelope.param_idx, old_val)

          ImGui.SetNextItemWidth(ctx, -1)
          local changed_val, new_val = ImGui.SliderDouble(ctx, "##envvalue", envelope_value, min_val, max_val,
            formatted_val)
          if changed_val then
            envelope_value = new_val
          end
        end

        ImGui.Separator(ctx)

        -- Ramp controls
        local is_toggle = false
        if selected_envelope.type == "track" then
          is_toggle = is_toggle_parameter(editing_ai.track, nil, nil, selected_envelope)
        elseif selected_envelope.type == "fx" then
          is_toggle = is_toggle_parameter(editing_ai.track, selected_envelope.fx_idx, selected_envelope.param_idx,
            selected_envelope)
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

        -- Keep window open checkbox
        local changed_keep, new_keep = ImGui.Checkbox(ctx, "Keep window open after applying", keep_window_open)
        if changed_keep then
          keep_window_open = new_keep
        end

        ImGui.Spacing(ctx)

        -- Apply button
        local avail_w_button = ImGui.GetContentRegionAvail(ctx)
        if ImGui.Button(ctx, "Apply Changes", avail_w_button, 30) then
          apply_automation()
        end
      else
        ImGui.TextWrapped(ctx, "Please select an envelope from the tabs above")
      end

      ImGui.End(ctx)
    end

    defer(main)
  end
end

---------------------------------------------------------------------

-- Initialize and start
if initialize_from_automation_item() then
  defer(main)
end
