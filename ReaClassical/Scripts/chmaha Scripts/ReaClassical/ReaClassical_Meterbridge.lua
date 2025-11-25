for key in pairs(reaper) do _G[key] = reaper[key] end

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
  MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
  return
end

package.path                    = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui                     = require 'imgui' '0.10'
local ctx                       = ImGui.CreateContext("ReaClassical Meterbridge")
local peak_hold_time            = 1.2
local peak_fall_per_sec         = 6.0
local track_state               = {}
local window_open               = true
local max_channels_per_row      = 8

-- Color threshold settings (in dB)
local threshold_green_to_yellow = -18
local threshold_yellow_to_red   = -6
-- Default values for reset
local default_green_to_yellow   = -18
local default_yellow_to_red     = -6

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

local function get_rec_armed_tracks()
  local out = {}
  for i = 0, CountTracks(0) - 1 do
    local tr = GetTrack(0, i)
    if tr and GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 then
      out[#out + 1] = tr
    end
  end
  return out
end

local function get_input_label(tr)
  local rec_input = math.floor(GetMediaTrackInfo_Value(tr, "I_RECINPUT"))

  -- Check if it's MIDI input (bit 12 set, value 4096)
  if rec_input & 4096 ~= 0 then
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

local function refresh_tracks()
  local tracks = get_rec_armed_tracks()
  local seen = {}
  for _, tr in ipairs(tracks) do
    local guid = GetTrackGUID(tr)
    seen[guid] = true
    if not track_state[guid] then
      track_state[guid] = {
        track = tr,
        input_label = get_input_label(tr),
        last_peak = 0,
        hold_db = -200,
        hold_until = 0
      }
    else
      track_state[guid].track = tr
      track_state[guid].input_label = get_input_label(tr) -- Update in case input changed
    end
  end
  for g, _ in pairs(track_state) do
    if not seen[g] then
      track_state[g] = nil
    end
  end
end

local function clear_all_holds()
  local tracks = get_rec_armed_tracks()
  for _, tr in ipairs(tracks) do
    -- Clear peak hold for both channels
    Track_GetPeakHoldDB(tr, 0, true)
    Track_GetPeakHoldDB(tr, 1, true)
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
  local now = time_precise()

  -- Tab bar
  if ImGui.BeginTabBar(ctx, "MeterTabs") then
    -- Meters tab
    if ImGui.BeginTabItem(ctx, "Meters") then
      -- Add clear button
      if ImGui.Button(ctx, "Clear All Holds") then
        clear_all_holds()
      end

      ImGui.Separator(ctx)

      -- Get tracks in project order
      local ordered_tracks = get_rec_armed_tracks()

      local track_count = 0
      for _, tr in ipairs(ordered_tracks) do
        local guid = GetTrackGUID(tr)
        local st = track_state[guid]

        if st then
          local p0 = Track_GetPeakInfo(tr, 0) or 0
          local p1 = Track_GetPeakInfo(tr, 1) or 0
          local peak = math.max(p0, p1, 0)
          st.last_peak = st.last_peak * 0.4 + peak * 0.6
          local db = lin_to_db(st.last_peak)

          -- Get peak hold values from both channels
          local hold0 = Track_GetPeakHoldDB(tr, 0, false) * 100 -- Convert from dB*0.01 to dB
          local hold1 = Track_GetPeakHoldDB(tr, 1, false) * 100
          local peak_hold_db = math.max(hold0, hold1)

          if db > st.hold_db then
            st.hold_db = db
            st.hold_until = now + peak_hold_time
          elseif now > st.hold_until then
            st.hold_db = st.hold_db - peak_fall_per_sec * (now - st.hold_until)
            if st.hold_db < db then st.hold_db = db end
          end

          -- Check if we need to start a new row
          if track_count > 0 and track_count % max_channels_per_row == 0 then
            -- Add spacing and separator before new row
            ImGui.Dummy(ctx, 0, 10) -- Vertical spacing
            ImGui.Separator(ctx)
            ImGui.Dummy(ctx, 0, 10) -- Vertical spacing after separator
          elseif track_count > 0 then
            -- Continue on same row
            ImGui.SameLine(ctx)
          end
          track_count = track_count + 1

          -- Begin a vertical group for each track
          ImGui.BeginGroup(ctx)

          -- Calculate text widths for alignment
          ImGui.PushFont(ctx, nil, 14)
          local hold_text = string.format("%.1f", peak_hold_db)
          local hold_text_width = ImGui.CalcTextSize(ctx, hold_text)
          ImGui.PopFont(ctx)

          ImGui.PushFont(ctx, nil, 24)
          local db_text = string.format("%.1f", st.hold_db)
          local db_text_width = ImGui.CalcTextSize(ctx, db_text)
          ImGui.PopFont(ctx)

          -- Display peak hold value centered above the larger dB value
          ImGui.PushFont(ctx, nil, 14)
          local hold_color = color_for_db(peak_hold_db)
          local hold_offset = (db_text_width - hold_text_width) * 0.5
          if hold_offset > 0 then
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + hold_offset)
          end
          ImGui.TextColored(ctx, hold_color, hold_text)
          ImGui.PopFont(ctx)

          -- Display continuous peak dB value in larger font
          ImGui.PushFont(ctx, nil, 24)
          local color = color_for_db(db)
          ImGui.TextColored(ctx, color, db_text)
          ImGui.PopFont(ctx)

          -- Display input label below, centered under the larger dB value
          local label_width = ImGui.CalcTextSize(ctx, st.input_label)
          local label_offset = (db_text_width - label_width) * 0.5
          if label_offset > 0 then
            ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + label_offset)
          end
          ImGui.Text(ctx, st.input_label)
          ImGui.EndGroup(ctx)
        end
      end
      ImGui.EndTabItem(ctx)
    end

    -- Options tab
    if ImGui.BeginTabItem(ctx, "Options") then
      ImGui.Text(ctx, "Color Thresholds:")
      ImGui.Spacing(ctx)

      -- Green to Yellow threshold slider
      ImGui.PushItemWidth(ctx, 250)
      local changed1, new_green_yellow = ImGui.SliderDouble(ctx, "Green --> Yellow (dB)", threshold_green_to_yellow, -60,
        0, "%.1f")
      if changed1 then
        threshold_green_to_yellow = new_green_yellow
        -- Ensure yellow->red is always higher than green->yellow
        if threshold_yellow_to_red < threshold_green_to_yellow then
          threshold_yellow_to_red = threshold_green_to_yellow
        end
      end

      -- Yellow to Red threshold slider
      local changed2, new_yellow_red = ImGui.SliderDouble(ctx, "Yellow --> Red (dB)", threshold_yellow_to_red, -60, 0,
        "%.1f")
      if changed2 then
        -- Clamp to ensure it's never lower than green->yellow
        threshold_yellow_to_red = math.max(new_yellow_red, threshold_green_to_yellow)
      end
      ImGui.PopItemWidth(ctx)

      ImGui.Spacing(ctx)

      -- Single reset button for both sliders
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
