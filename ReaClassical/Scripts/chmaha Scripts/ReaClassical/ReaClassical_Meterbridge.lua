--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
  MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
  return
end

set_action_options(2)

package.path                         = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui                          = require 'imgui' '0.10'
local ctx                            = ImGui.CreateContext("ReaClassical Meterbridge")
local track_state                    = {}
local window_open                    = true
local max_channels_per_row_numeric   = 8 -- For numeric display
local max_channels_per_row_graphical = 8 -- For graphical display (reduced since we show L+R)
local show_graphical_meters          = false

-- Color threshold settings (in dB)
local threshold_green_to_yellow      = -18
local threshold_yellow_to_red        = -6
-- Default values for reset
local default_green_to_yellow        = -18
local default_yellow_to_red          = -6

-- Meter display settings
local meter_height                   = 200
local meter_width                    = 15 -- Width per channel
local meter_spacing                  = 1  -- Space between L and R meters

local function clamp(v, a, b)
  if v < a then return a elseif v > b then return b else return v end
end

local function lin_to_db(l)
  if not l or l <= 0 then return -200 end
  return 20 * math.log(l, 10)
end

local function color_for_db(db)
  local r, g, b, a

  if db < threshold_green_to_yellow then
    -- Green: safe / quiet
    r, g, b, a = 0.0, 0.8, 0.0, 1.0
  elseif db < threshold_yellow_to_red then
    -- Yellow: caution zone
    r, g, b, a = 0.9, 0.8, 0.0, 1.0
  else
    -- Red: too hot / clipping risk
    r, g, b, a = 0.9, 0.2, 0.2, 1.0
  end

  return ImGui.ColorConvertDouble4ToU32(r, g, b, a)
end

local function is_m_track(name)
  -- Check if track name starts with "M:"
  return name:match("^M:")
end

local function is_other_master_track(name)
  -- Check for aux, submix, roomtone, RCMASTER, live, REF
  return name:match("^@") or name:match("^#")
      or name:match("^RoomTone") or name:match("^LIVE") or name:match("^REF")
      or name == "RCMASTER"
end

local function get_tracks_to_display()
  local rec_armed = {}
  local m_tracks = {}
  local other_masters = {}

  -- First check for rec-armed tracks
  for i = 0, CountTracks(0) - 1 do
    local tr = GetTrack(0, i)
    if tr and GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 then
      rec_armed[#rec_armed + 1] = tr
    end
  end

  -- If we have rec-armed tracks, use only those
  if #rec_armed > 0 then
    return rec_armed, {}, {}
  end

  -- Otherwise, categorize non-muted tracks
  for i = 0, CountTracks(0) - 1 do
    local tr = GetTrack(0, i)
    if tr then
      local is_muted = GetMediaTrackInfo_Value(tr, "B_MUTE") == 1
      if not is_muted then
        local ok, name = GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
        local track_name = (ok and name ~= "" and name) or ("Track " .. GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))

        if is_m_track(track_name) then
          m_tracks[#m_tracks + 1] = tr
        elseif is_other_master_track(track_name) then
          other_masters[#other_masters + 1] = tr
        end
      end
    end
  end

  -- Also check the master track
  local master_tr = GetMasterTrack(0)
  if master_tr then
    local is_muted = GetMediaTrackInfo_Value(master_tr, "B_MUTE") == 1
    if not is_muted then
      other_masters[#other_masters + 1] = master_tr
    end
  end

  return {}, m_tracks, other_masters
end

local function get_input_label(tr)
  local rec_input = math.floor(GetMediaTrackInfo_Value(tr, "I_RECINPUT"))

  -- Check if input is disabled (-1 or specific disabled flag)
  if rec_input == -1 or rec_input == 4096 then
    return "-"
  end

  -- Check if it's MIDI input (bit 12 set AND has valid MIDI channel data)
  -- Real MIDI inputs have bit 12 set plus additional bits for MIDI device/channel
  if (rec_input & 4096) ~= 0 and rec_input > 4096 then
    return "MIDI"
  end

  -- Get the input start channel (low 10 bits, 0-1023)
  local start_channel = rec_input & 1023

  -- Check if stereo (bit 10 set, value 1024)
  local is_stereo = (rec_input & 1024) ~= 0

  -- Check if multichannel (bit 11 set, value 2048)
  local is_multichannel = (rec_input & 2048) ~= 0

  -- Convert from 0-based to 1-based for display
  local first_input = start_channel + 1

  if is_stereo then
    -- Stereo input
    return string.format("%d-%d", first_input, first_input + 1)
  elseif is_multichannel then
    -- Multichannel - get track channel count
    local num_channels = math.floor(GetMediaTrackInfo_Value(tr, "I_NCHAN"))
    return string.format("%d-%d", first_input, first_input + num_channels - 1)
  else
    -- Mono input
    return string.format("%d", first_input)
  end
end

local function get_track_label(tr)
  local ok, name = GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)

  -- Check if it's the master track
  if tr == GetMasterTrack(0) then
    return (ok and name ~= "" and name) or "Master"
  end

  -- For regular tracks, return name or track number
  return (ok and name ~= "" and name) or ("Track " .. GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
end

local function refresh_tracks()
  local rec_armed, m_tracks, other_masters = get_tracks_to_display()
  local all_tracks = {}

  -- Combine all track types
  for _, tr in ipairs(rec_armed) do
    all_tracks[#all_tracks + 1] = tr
  end
  for _, tr in ipairs(m_tracks) do
    all_tracks[#all_tracks + 1] = tr
  end
  for _, tr in ipairs(other_masters) do
    all_tracks[#all_tracks + 1] = tr
  end

  local seen = {}
  for _, tr in ipairs(all_tracks) do
    local guid = GetTrackGUID(tr)
    seen[guid] = true
    if not track_state[guid] then
      -- Check if rec-armed to determine label
      local is_rec_armed = GetMediaTrackInfo_Value(tr, "I_RECARM") == 1
      local label
      if is_rec_armed then
        label = get_input_label(tr)
      else
        label = get_track_label(tr)
      end

      track_state[guid] = {
        track = tr,
        input_label = label
      }
    else
      track_state[guid].track = tr
      -- Update label in case rec-arm status changed
      local is_rec_armed = GetMediaTrackInfo_Value(tr, "I_RECARM") == 1
      if is_rec_armed then
        track_state[guid].input_label = get_input_label(tr)
      else
        track_state[guid].input_label = get_track_label(tr)
      end
    end
  end

  -- Remove tracks that are no longer in the list
  for g, _ in pairs(track_state) do
    if not seen[g] then
      track_state[g] = nil
    end
  end
end

local function clear_all_holds()
  local rec_armed, m_tracks, other_masters = get_tracks_to_display()
  for _, tr in ipairs(rec_armed) do
    Track_GetPeakHoldDB(tr, 0, true)
    Track_GetPeakHoldDB(tr, 1, true)
  end
  for _, tr in ipairs(m_tracks) do
    Track_GetPeakHoldDB(tr, 0, true)
    Track_GetPeakHoldDB(tr, 1, true)
  end
  for _, tr in ipairs(other_masters) do
    Track_GetPeakHoldDB(tr, 0, true)
    Track_GetPeakHoldDB(tr, 1, true)
  end
end

local function draw_single_meter(draw_list, x, y, width, height, db, peak_hold_db)
  -- Background
  local bg_color = ImGui.ColorConvertDouble4ToU32(0.2, 0.2, 0.2, 1.0)
  ImGui.DrawList_AddRectFilled(draw_list, x, y, x + width, y + height, bg_color)

  -- Calculate meter fill height (-60 dB to 0 dB range)
  local db_range = 60
  local db_normalized = clamp((db + db_range) / db_range, 0, 1)
  local fill_height = db_normalized * height

  -- Draw meter fill from bottom up with color zones
  local bottom_y = y + height

  -- Calculate color zone heights
  local green_threshold_norm = (threshold_green_to_yellow + db_range) / db_range
  local yellow_threshold_norm = (threshold_yellow_to_red + db_range) / db_range

  local green_height = green_threshold_norm * height
  local yellow_height = yellow_threshold_norm * height

  -- Draw red zone (top)
  if db_normalized > yellow_threshold_norm then
    local red_color = ImGui.ColorConvertDouble4ToU32(0.9, 0.2, 0.2, 1.0)
    ImGui.DrawList_AddRectFilled(draw_list, x, bottom_y - fill_height,
      x + width, bottom_y - yellow_height, red_color)
  end

  -- Draw yellow zone (middle)
  if db_normalized > green_threshold_norm then
    local yellow_fill = math.min(fill_height, yellow_height) - green_height
    if yellow_fill > 0 then
      local yellow_color = ImGui.ColorConvertDouble4ToU32(0.9, 0.8, 0.0, 1.0)
      ImGui.DrawList_AddRectFilled(draw_list, x, bottom_y - math.min(fill_height, yellow_height),
        x + width, bottom_y - green_height, yellow_color)
    end
  end

  -- Draw green zone (bottom)
  local green_fill = math.min(fill_height, green_height)
  if green_fill > 0 then
    local green_color = ImGui.ColorConvertDouble4ToU32(0.0, 0.8, 0.0, 1.0)
    ImGui.DrawList_AddRectFilled(draw_list, x, bottom_y - green_fill,
      x + width, bottom_y, green_color)
  end

  -- Draw peak hold line
  local peak_normalized = clamp((peak_hold_db + db_range) / db_range, 0, 1)
  local peak_y = bottom_y - (peak_normalized * height)
  local peak_color = color_for_db(peak_hold_db)
  ImGui.DrawList_AddLine(draw_list, x, peak_y, x + width, peak_y, peak_color, 2)

  -- Draw border
  local border_color = ImGui.ColorConvertDouble4ToU32(0.5, 0.5, 0.5, 1.0)
  ImGui.DrawList_AddRect(draw_list, x, y, x + width, y + height, border_color)
end

local function draw_graphical_meter(db_L, db_R, peak_hold_L, peak_hold_R, label)
  ImGui.BeginGroup(ctx)

  -- Draw the meter bars
  local draw_list = ImGui.GetWindowDrawList(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

  -- Draw L channel meter
  draw_single_meter(draw_list, cursor_x, cursor_y, meter_width, meter_height, db_L, peak_hold_L)

  -- Draw R channel meter
  local r_x = cursor_x + meter_width + meter_spacing
  draw_single_meter(draw_list, r_x, cursor_y, meter_width, meter_height, db_R, peak_hold_R)

  -- Total width for both meters
  local total_width = meter_width * 2 + meter_spacing

  -- Advance cursor past the meters
  ImGui.Dummy(ctx, total_width, meter_height)

  -- Draw L and R labels above peak values
  ImGui.PushFont(ctx, nil, 9)
  local l_text = "L"
  local r_text = "R"
  local l_width = ImGui.CalcTextSize(ctx, l_text)
  local r_width = ImGui.CalcTextSize(ctx, r_text)

  -- L label centered over L meter
  local l_offset = (meter_width - l_width) * 0.5
  if l_offset > 0 then
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + l_offset)
  end
  ImGui.Text(ctx, l_text)

  -- R label centered over R meter
  ImGui.SameLine(ctx)
  local r_offset = meter_spacing + (meter_width - r_width) * 0.5
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + r_offset)
  ImGui.Text(ctx, r_text)
  ImGui.PopFont(ctx)

  -- Draw peak hold values
  ImGui.PushFont(ctx, nil, 10)

  -- L peak value
  local hold_L_text = string.format("%.1f", peak_hold_L)
  local hold_L_width = ImGui.CalcTextSize(ctx, hold_L_text)
  local hold_L_offset = (meter_width - hold_L_width) * 0.5
  if hold_L_offset > 0 then
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + hold_L_offset)
  end
  local hold_L_color = color_for_db(peak_hold_L)
  ImGui.TextColored(ctx, hold_L_color, hold_L_text)

  -- R peak value
  ImGui.SameLine(ctx)
  local hold_R_text = string.format("%.1f", peak_hold_R)
  local hold_R_width = ImGui.CalcTextSize(ctx, hold_R_text)
  local hold_R_offset = meter_spacing + (meter_width - hold_R_width) * 0.5
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + hold_R_offset)
  local hold_R_color = color_for_db(peak_hold_R)
  ImGui.TextColored(ctx, hold_R_color, hold_R_text)
  ImGui.PopFont(ctx)

  -- Draw label centered under both meters
  local label_width = ImGui.CalcTextSize(ctx, label)
  local label_offset = (total_width - label_width) * 0.5
  if label_offset > 0 then
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + label_offset)
  end
  ImGui.Text(ctx, label)

  ImGui.EndGroup(ctx)
end

local function display_track_row(tracks, max_channels_per_row)
  local track_count = 0
  for _, tr in ipairs(tracks) do
    local guid = GetTrackGUID(tr)
    local st = track_state[guid]

    if st then
      -- Get instant peak values for both channels
      local p0 = Track_GetPeakInfo(tr, 0) or 0
      local p1 = Track_GetPeakInfo(tr, 1) or 0
      local db_L = lin_to_db(p0)
      local db_R = lin_to_db(p1)

      -- Get peak hold values from both channels separately
      local peak_hold_L = Track_GetPeakHoldDB(tr, 0, false) * 100
      local peak_hold_R = Track_GetPeakHoldDB(tr, 1, false) * 100

      -- For numeric display, use the max of both channels
      local peak_hold_db = math.max(peak_hold_L, peak_hold_R)

      -- Check if we need to start a new row
      if track_count > 0 and track_count % max_channels_per_row == 0 then
        ImGui.Dummy(ctx, 0, 10)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 10)
      elseif track_count > 0 then
        ImGui.SameLine(ctx)
      end
      track_count = track_count + 1

      if show_graphical_meters then
        draw_graphical_meter(db_L, db_R, peak_hold_L, peak_hold_R, st.input_label)
      else
        -- Numeric display: show ONLY peak hold value
        ImGui.BeginGroup(ctx)

        ImGui.PushFont(ctx, nil, 24)
        local db_text = string.format("%.1f", peak_hold_db)
        local db_text_width = ImGui.CalcTextSize(ctx, db_text)
        local color = color_for_db(peak_hold_db)
        ImGui.TextColored(ctx, color, db_text)
        ImGui.PopFont(ctx)

        local label_width = ImGui.CalcTextSize(ctx, st.input_label)
        local label_offset = (db_text_width - label_width) * 0.5
        if label_offset > 0 then
          ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + label_offset)
        end
        ImGui.Text(ctx, st.input_label)
        ImGui.EndGroup(ctx)
      end
    end
  end
end

local function main()
  if not window_open then return end

  -- Set window flags to auto-resize
  local window_flags = ImGui.WindowFlags_AlwaysAutoResize

  local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Meterbridge", true, window_flags)
  window_open = open_ref
  if not opened then
    ImGui.End(ctx)
    defer(main)
    return
  end
  refresh_tracks()

  -- Tab bar
  if ImGui.BeginTabBar(ctx, "MeterTabs") then
    -- Meters tab
    if ImGui.BeginTabItem(ctx, "Meters") then
      -- Add clear button and meter mode checkbox
      if ImGui.Button(ctx, "Clear All Holds") then
        clear_all_holds()
      end

      ImGui.SameLine(ctx)
      local changed, new_value = ImGui.Checkbox(ctx, "Graphical Meters", show_graphical_meters)
      if changed then
        show_graphical_meters = new_value
      end

      ImGui.Separator(ctx)

      -- Determine max channels per row based on display mode
      local max_channels_per_row = show_graphical_meters and max_channels_per_row_graphical or
          max_channels_per_row_numeric

      -- Get tracks in categorized groups
      local rec_armed, m_tracks, other_masters = get_tracks_to_display()

      -- Display rec-armed tracks (if any)
      if #rec_armed > 0 then
        display_track_row(rec_armed, max_channels_per_row)
      else
        -- Display M: tracks on first row
        if #m_tracks > 0 then
          display_track_row(m_tracks, max_channels_per_row)
        end

        -- Display other master tracks on second row if they exist
        if #other_masters > 0 then
          if #m_tracks > 0 then
            ImGui.Dummy(ctx, 0, 10)
            ImGui.Separator(ctx)
            ImGui.Dummy(ctx, 0, 10)
          end
          display_track_row(other_masters, max_channels_per_row)
        end
      end

      ImGui.EndTabItem(ctx)
    end

    -- Options tab
    if ImGui.BeginTabItem(ctx, "Options") then
      ImGui.Text(ctx, "Color Thresholds:")
      ImGui.Spacing(ctx)

      ImGui.PushItemWidth(ctx, 250)
      local changed1, new_green_yellow = ImGui.SliderDouble(ctx, "Green --> Yellow (dB)",
        threshold_green_to_yellow, -60, 0, "%.1f")
      if changed1 then
        threshold_green_to_yellow = new_green_yellow
        if threshold_yellow_to_red < threshold_green_to_yellow then
          threshold_yellow_to_red = threshold_green_to_yellow
        end
      end

      local changed2, new_yellow_red = ImGui.SliderDouble(ctx, "Yellow --> Red (dB)", threshold_yellow_to_red, -60, 0,
        "%.1f")
      if changed2 then
        threshold_yellow_to_red = math.max(new_yellow_red, threshold_green_to_yellow)
      end
      ImGui.PopItemWidth(ctx)

      ImGui.Spacing(ctx)

      if ImGui.Button(ctx, "Reset to Defaults") then
        threshold_green_to_yellow = default_green_to_yellow
        threshold_yellow_to_red = default_yellow_to_red
      end

      ImGui.EndTabItem(ctx)
    end

    ImGui.EndTabBar(ctx)
  end

  ImGui.End(ctx)
  defer(main)
end

defer(main)
