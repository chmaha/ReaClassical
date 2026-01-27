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

local main, apply_volume_automation, linear_to_db, db_to_linear, get_envelope_value_at_time
local format_time, get_selected_tracks

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

function apply_volume_automation()
  if #selected_tracks == 0 then return end

  -- Convert dB to linear
  local vol_linear = db_to_linear(volume_db)

  -- Scale to envelope mode for insertion
  local vol_scaled = ScaleToEnvelopeMode(1, vol_linear)

  -- Apply to each selected track
  for _, track in ipairs(selected_tracks) do
    -- Get or create volume envelope
    local vol_env = GetTrackEnvelopeByName(track, "Volume")
    if not vol_env then
      -- Create volume envelope if it doesn't exist
      SetOnlyTrackSelected(track)
      Main_OnCommand(40406, 0) -- Track: Toggle track volume envelope visible
      vol_env = GetTrackEnvelopeByName(track, "Volume")
      if not vol_env then goto continue end
    end

    if has_time_sel and (start_time ~= end_time) then
      -- Time selection mode with ramps OUTSIDE the selection
      local actual_start = start_time
      local actual_end = end_time

      -- Calculate ramp start/end times OUTSIDE the time selection
      local ramp_in_start = actual_start - ramp_in
      local ramp_out_end = actual_end + ramp_out

      -- Get volume values at boundaries BEFORE deleting anything
      local vol_before, vol_after

      if ramp_in > 0 then
        vol_before = get_envelope_value_at_time(vol_env, ramp_in_start)
        if not vol_before or vol_before <= 0 then
          vol_before = GetMediaTrackInfo_Value(track, "D_VOL")
        end
      else
        -- No ramp in - get value just before selection start for sudden dip
        vol_before = get_envelope_value_at_time(vol_env, actual_start - 0.001)
        if not vol_before or vol_before <= 0 then
          vol_before = GetMediaTrackInfo_Value(track, "D_VOL")
        end
      end

      if ramp_out > 0 then
        vol_after = get_envelope_value_at_time(vol_env, ramp_out_end)
        if not vol_after or vol_after <= 0 then
          vol_after = GetMediaTrackInfo_Value(track, "D_VOL")
        end
      else
        -- No ramp out - get value just after selection end for sudden dip
        vol_after = get_envelope_value_at_time(vol_env, actual_end + 0.001)
        if not vol_after or vol_after <= 0 then
          vol_after = GetMediaTrackInfo_Value(track, "D_VOL")
        end
      end

      -- Scale the before/after values for insertion
      local vol_before_scaled = ScaleToEnvelopeMode(1, vol_before)
      local vol_after_scaled = ScaleToEnvelopeMode(1, vol_after)

      -- Clear existing points in the entire range including ramps
      local clear_start = ramp_in > 0 and ramp_in_start or (actual_start - 0.002)
      local clear_end = ramp_out > 0 and ramp_out_end or (actual_end + 0.002)
      DeleteEnvelopePointRange(vol_env, clear_start - 0.001, clear_end + 0.001)

      -- Add points based on ramp settings (using scaled values)
      if ramp_in > 0 then
        -- Gradual ramp in
        InsertEnvelopePoint(vol_env, ramp_in_start, vol_before_scaled, 0, 0, false, true)
        InsertEnvelopePoint(vol_env, actual_start, vol_scaled, 0, 0, false, true)
      else
        -- Sudden dip - add point just before to maintain previous value
        InsertEnvelopePoint(vol_env, actual_start - 0.001, vol_before_scaled, 0, 0, false, true)
        InsertEnvelopePoint(vol_env, actual_start, vol_scaled, 0, 0, false, true)
      end

      if ramp_out > 0 then
        -- Gradual ramp out
        InsertEnvelopePoint(vol_env, actual_end, vol_scaled, 0, 0, false, true)
        InsertEnvelopePoint(vol_env, ramp_out_end, vol_after_scaled, 0, 0, false, true)
      else
        -- Sudden rise - add point just after to return to previous value
        InsertEnvelopePoint(vol_env, actual_end, vol_scaled, 0, 0, false, true)
        InsertEnvelopePoint(vol_env, actual_end + 0.001, vol_after_scaled, 0, 0, false, true)
      end
    else
      -- Edit cursor mode with optional ramp in
      local cursor_pos = GetCursorPosition()

      -- Calculate ramp start time BEFORE cursor
      local ramp_start = cursor_pos - ramp_in

      -- Get volume value BEFORE deleting anything
      local vol_before
      if ramp_in > 0 then
        vol_before = get_envelope_value_at_time(vol_env, ramp_start)
        if not vol_before or vol_before <= 0 then
          vol_before = GetMediaTrackInfo_Value(track, "D_VOL")
        end
      else
        -- No ramp - get value just before cursor for sudden dip
        vol_before = get_envelope_value_at_time(vol_env, cursor_pos - 0.001)
        if not vol_before or vol_before <= 0 then
          vol_before = GetMediaTrackInfo_Value(track, "D_VOL")
        end
      end

      -- Scale the before value for insertion
      local vol_before_scaled = ScaleToEnvelopeMode(1, vol_before)

      -- Delete existing points from ramp start (or just before cursor) onwards
      local num_points = CountEnvelopePoints(vol_env)
      local delete_from = ramp_in > 0 and ramp_start or (cursor_pos - 0.002)
      for i = num_points - 1, 0, -1 do
        local _, time = GetEnvelopePoint(vol_env, i)
        if time >= delete_from then
          DeleteEnvelopePointEx(vol_env, -1, i)
        end
      end

      -- Insert new points (using scaled values)
      if ramp_in > 0 then
        -- Gradual ramp in before cursor
        InsertEnvelopePoint(vol_env, ramp_start, vol_before_scaled, 0, 0, false, true)
        InsertEnvelopePoint(vol_env, cursor_pos, vol_scaled, 0, 0, false, true)
      else
        -- Sudden dip - add point just before cursor to maintain previous value
        InsertEnvelopePoint(vol_env, cursor_pos - 0.001, vol_before_scaled, 0, 0, false, true)
        InsertEnvelopePoint(vol_env, cursor_pos, vol_scaled, 0, 0, false, true)
      end
    end

    Envelope_SortPoints(vol_env)

    ::continue::
  end

  UpdateArrange()
end

---------------------------------------------------------------------

function main()
  -- Get currently selected tracks
  local tracks = get_selected_tracks()
  local track_count = #tracks

  -- Get current cursor and time selection
  local current_cursor = GetCursorPosition()
  local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  local current_has_time_sel = (ts_start ~= ts_end)

  -- Detect if track selection changed
  if track_count ~= last_track_count or
      (track_count > 0 and tracks[1] ~= selected_tracks[1]) then
    selected_tracks = tracks
    last_track_count = track_count
    last_cursor_pos = current_cursor
    last_time_sel_start = ts_start
    last_time_sel_end = ts_end

    if track_count > 0 then
      -- Get current volume at cursor or time selection start from first track
      local first_track = tracks[1]
      local vol_env = GetTrackEnvelopeByName(first_track, "Volume")
      local query_time = current_has_time_sel and ts_start or current_cursor

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
    -- Detect if cursor or time selection changed
  elseif track_count > 0 and (current_cursor ~= last_cursor_pos or
        ts_start ~= last_time_sel_start or
        ts_end ~= last_time_sel_end) then
    last_cursor_pos = current_cursor
    last_time_sel_start = ts_start
    last_time_sel_end = ts_end

    -- Update volume based on new position from first track
    local first_track = tracks[1]
    local vol_env = GetTrackEnvelopeByName(first_track, "Volume")
    local query_time = current_has_time_sel and ts_start or current_cursor

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
        ImGui.TextWrapped(ctx, "Please select one or more tracks to apply volume automation.")
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
            -- Build tooltip with track names
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
        ImGui.Separator(ctx)

        -- Volume slider
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

          -- Right-click popup for ramp in
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

          -- Right-click popup for ramp out
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

          -- Right-click popup for ramp in
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

        -- Apply button
        local avail_w_button = ImGui.GetContentRegionAvail(ctx)
        if ImGui.Button(ctx, "Apply Automation", avail_w_button, 30) then
          apply_volume_automation()
          window_open = false      -- Close window after applying
          Main_OnCommand(40635, 0) -- remove time selection if present
        end
      end

      ImGui.End(ctx)
    end

    defer(main)
  end
end

---------------------------------------------------------------------

defer(main)
