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

local main, count_rec_armed_tracks, draw_mic_icon
local save_colors_to_project, load_colors_from_project

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
  MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
  return
end

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'
local ctx = ImGui.CreateContext("Recording Indicator")
local window_open = true

-- Mic icon size (DOUBLED)
local icon_size = 128

-- Color settings with defaults
local colors = {
  offline = { 0.6, 0.6, 0.6, 1.0 },
  standby = { 0.1, 1.0, 0.1, 1.0 },
  recording = { 0.9, 0.1, 0.1, 1.0 },
  paused = { 1.0, 0.85, 0.1, 1.0 }
}

-- Text colors (slightly different from icon colors)
local text_colors = {
  offline = { 0.6, 0.6, 0.6, 1.0 },
  standby = { 0.1, 1.0, 0.1, 1.0 }, -- alpha will be animated
  recording = { 1.0, 0.2, 0.2, 1.0 },
  paused = { 1.0, 0.85, 0.1, 1.0 }
}

-- Project state key
local EXT_KEY = "recording_indicator_colors"

---------------------------------------------------------------------

function save_colors_to_project()
  -- Serialize colors to a single string
  local data = string.format(
    "offline:%.3f,%.3f,%.3f,%.3f|standby:%.3f,%.3f,%.3f,%.3f|recording:%.3f,%.3f,%.3f,%.3f|paused:%.3f,%.3f,%.3f,%.3f",
    colors.offline[1], colors.offline[2], colors.offline[3], colors.offline[4],
    colors.standby[1], colors.standby[2], colors.standby[3], colors.standby[4],
    colors.recording[1], colors.recording[2], colors.recording[3], colors.recording[4],
    colors.paused[1], colors.paused[2], colors.paused[3], colors.paused[4]
  )

  SetProjExtState(0, EXT_KEY, "colors", data)
end

---------------------------------------------------------------------

function load_colors_from_project()
  local retval, data = GetProjExtState(0, EXT_KEY, "colors")

  if retval == 0 or data == "" then
    return -- No saved data, use defaults
  end

  -- Parse the data
  local states = {}
  for state_data in data:gmatch("([^|]+)") do
    local state_name, values = state_data:match("([^:]+):(.+)")
    if state_name and values then
      local nums = {}
      for num in values:gmatch("([^,]+)") do
        table.insert(nums, tonumber(num))
      end
      if #nums == 4 then
        states[state_name] = nums
      end
    end
  end

  -- Update colors if valid data was found
  if states.offline then colors.offline = states.offline end
  if states.standby then colors.standby = states.standby end
  if states.recording then colors.recording = states.recording end
  if states.paused then colors.paused = states.paused end

  -- Update text colors to match
  if states.offline then
    text_colors.offline = { states.offline[1], states.offline[2], states.offline[3], states.offline
        [4] }
  end
  if states.standby then
    text_colors.standby = { states.standby[1], states.standby[2], states.standby[3], states.standby
        [4] }
  end
  if states.recording then
    text_colors.recording = {
      math.min(1.0, states.recording[1] + 0.1),
      math.min(1.0, states.recording[2] + 0.1),
      math.min(1.0, states.recording[3] + 0.1),
      states.recording[4]
    }
  end
  if states.paused then text_colors.paused = { states.paused[1], states.paused[2], states.paused[3], states.paused[4] } end
end

---------------------------------------------------------------------

-- Load colors on startup
load_colors_from_project()

---------------------------------------------------------------------

function main()
  if not window_open then return end

  local window_flags = ImGui.WindowFlags_NoScrollbar |
      ImGui.WindowFlags_TopMost

  -- Set minimum window size
  ImGui.SetNextWindowSizeConstraints(ctx, 160, 175, math.huge, math.huge)

  local opened, open_ref = ImGui.Begin(ctx, "Recording Indicator", true, window_flags)
  window_open = open_ref

  if opened then
    -- Right-click context menu with direct color pickers
    if ImGui.BeginPopupContextWindow(ctx) then
      ImGui.Text(ctx, "Color Settings")
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      local colors_changed = false
      local label_width = 80 -- Fixed width for alignment

      -- Offline color
      ImGui.Text(ctx, "Offline:")
      ImGui.SameLine(ctx, label_width)
      local col = ImGui.ColorConvertDouble4ToU32(colors.offline[1], colors.offline[2], colors.offline[3],
        colors.offline[4])
      local changed, new_col = ImGui.ColorEdit4(ctx, "##offline", col, ImGui.ColorEditFlags_NoInputs)
      if changed then
        local r, g, b, a = ImGui.ColorConvertU32ToDouble4(new_col)
        colors.offline = { r, g, b, a }
        text_colors.offline = { r, g, b, a }
        colors_changed = true
      end

      ImGui.Spacing(ctx)

      -- Standby color
      ImGui.Text(ctx, "Standby:")
      ImGui.SameLine(ctx, label_width)
      col = ImGui.ColorConvertDouble4ToU32(colors.standby[1], colors.standby[2], colors.standby[3], colors.standby[4])
      changed, new_col = ImGui.ColorEdit4(ctx, "##standby", col, ImGui.ColorEditFlags_NoInputs)
      if changed then
        local r, g, b, a = ImGui.ColorConvertU32ToDouble4(new_col)
        colors.standby = { r, g, b, a }
        text_colors.standby = { r, g, b, a }
        colors_changed = true
      end

      ImGui.Spacing(ctx)

      -- Recording color
      ImGui.Text(ctx, "Recording:")
      ImGui.SameLine(ctx, label_width)
      col = ImGui.ColorConvertDouble4ToU32(colors.recording[1], colors.recording[2], colors.recording[3],
        colors.recording[4])
      changed, new_col = ImGui.ColorEdit4(ctx, "##recording", col, ImGui.ColorEditFlags_NoInputs)
      if changed then
        local r, g, b, a = ImGui.ColorConvertU32ToDouble4(new_col)
        colors.recording = { r, g, b, a }
        text_colors.recording = {
          math.min(1.0, r + 0.1),
          math.min(1.0, g + 0.1),
          math.min(1.0, b + 0.1),
          a
        }
        colors_changed = true
      end

      ImGui.Spacing(ctx)

      -- Paused color
      ImGui.Text(ctx, "Paused:")
      ImGui.SameLine(ctx, label_width)
      col = ImGui.ColorConvertDouble4ToU32(colors.paused[1], colors.paused[2], colors.paused[3], colors.paused[4])
      changed, new_col = ImGui.ColorEdit4(ctx, "##paused", col, ImGui.ColorEditFlags_NoInputs)
      if changed then
        local r, g, b, a = ImGui.ColorConvertU32ToDouble4(new_col)
        colors.paused = { r, g, b, a }
        text_colors.paused = { r, g, b, a }
        colors_changed = true
      end

      -- Save to project state when colors change
      if colors_changed then
        save_colors_to_project()
      end

      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      -- Reset button
      if ImGui.MenuItem(ctx, "Reset to Defaults") then
        colors.offline = { 0.6, 0.6, 0.6, 1.0 }
        colors.standby = { 0.1, 1.0, 0.1, 1.0 }
        colors.recording = { 0.9, 0.1, 0.1, 1.0 }
        colors.paused = { 1.0, 0.85, 0.1, 1.0 }

        text_colors.offline = { 0.6, 0.6, 0.6, 1.0 }
        text_colors.standby = { 0.1, 1.0, 0.1, 1.0 }
        text_colors.recording = { 1.0, 0.2, 0.2, 1.0 }
        text_colors.paused = { 1.0, 0.85, 0.1, 1.0 }

        save_colors_to_project()
      end

      ImGui.EndPopup(ctx)
    end

    local armed = count_rec_armed_tracks()
    local play_state = GetPlayState()

    local state, label

    if armed == 0 then
      state = "idle"
      label = "OFFLINE"
    elseif play_state == 6 then
      state = "paused"
      label = "PAUSED"
    elseif (play_state & 4) == 4 then
      state = "recording"
      label = "RECORDING"
    else
      state = "standby"
      label = "STANDBY"
    end

    -- Reserve width (auto-scales since text is unchanged)
    local widest = "RECORDING"
    local max_w = select(1, ImGui.CalcTextSize(ctx, widest))
    local target_w = math.max(icon_size, max_w + 20)

    ImGui.SetNextItemWidth(ctx, target_w)
    ImGui.Dummy(ctx, target_w, 0)

    local win_w = ImGui.GetWindowWidth(ctx)
    local win_h = ImGui.GetWindowHeight(ctx)

    -- Scale icon size based on window size (no upper limit!)
    local available_size = math.min(win_w - 40, win_h - 80)
    local display_icon_size = math.max(64, available_size)

    -- Center icon
    local icon_center_x = (win_w - display_icon_size) * 0.5
    ImGui.SetCursorPosX(ctx, icon_center_x)

    local draw_list = ImGui.GetWindowDrawList(ctx)
    local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

    draw_mic_icon(draw_list, cursor_x, cursor_y, display_icon_size, state)
    ImGui.Dummy(ctx, display_icon_size, display_icon_size)

    -- Text
    if label ~= "" then
      ImGui.Spacing(ctx)
      local time = ImGui.GetTime(ctx)
      local color

      if state == "recording" then
        color = ImGui.ColorConvertDouble4ToU32(
          text_colors.recording[1],
          text_colors.recording[2],
          text_colors.recording[3],
          text_colors.recording[4]
        )
      elseif state == "paused" then
        color = ImGui.ColorConvertDouble4ToU32(
          text_colors.paused[1],
          text_colors.paused[2],
          text_colors.paused[3],
          text_colors.paused[4]
        )
      elseif state == "standby" then
        local alpha = 0.5 + 0.5 * math.sin(time * 4)
        color = ImGui.ColorConvertDouble4ToU32(
          text_colors.standby[1],
          text_colors.standby[2],
          text_colors.standby[3],
          alpha
        )
      else
        color = ImGui.ColorConvertDouble4ToU32(
          text_colors.offline[1],
          text_colors.offline[2],
          text_colors.offline[3],
          text_colors.offline[4]
        )
      end

      local text_w = select(1, ImGui.CalcTextSize(ctx, label))
      ImGui.SetCursorPosX(ctx, (win_w - text_w) * 0.5)
      ImGui.TextColored(ctx, color, label)
    end
    -- keyboard shortcut capture
    if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_R, false) then
      if ImGui.GetKeyMods(ctx) & ImGui.Mod_Alt ~= 0 then
        window_open = false
      end
    end
    ImGui.End(ctx)
  end

  defer(main)
end

---------------------------------------------------------------------

function count_rec_armed_tracks()
  local cnt = CountTracks(0)
  local armed = 0
  for i = 0, cnt - 1 do
    local tr = GetTrack(0, i)
    if tr then
      local arm = GetMediaTrackInfo_Value(tr, "I_RECARM")
      if arm == 1 then armed = armed + 1 end
    end
  end
  return armed
end

---------------------------------------------------------------------

function draw_mic_icon(draw_list, x, y, size, state)
  -- Determine color based on state using custom colors
  local mic_color
  if state == "recording" then
    mic_color = ImGui.ColorConvertDouble4ToU32(
      colors.recording[1], colors.recording[2], colors.recording[3], colors.recording[4])
  elseif state == "paused" then
    mic_color = ImGui.ColorConvertDouble4ToU32(
      colors.paused[1], colors.paused[2], colors.paused[3], colors.paused[4])
  elseif state == "standby" then
    mic_color = ImGui.ColorConvertDouble4ToU32(
      colors.standby[1], colors.standby[2], colors.standby[3], colors.standby[4])
  else
    mic_color = ImGui.ColorConvertDouble4ToU32(
      colors.offline[1], colors.offline[2], colors.offline[3], colors.offline[4])
  end

  local center_x = x + size / 2
  local center_y = y + size / 2

  -- Main capsule (rounded rectangle)
  local capsule_width = size * 0.32
  local capsule_height = size * 0.45
  local capsule_top = center_y - size * 0.28
  local capsule_radius = capsule_width / 2

  -- Draw filled rounded rectangle for capsule
  ImGui.DrawList_AddRectFilled(draw_list,
    center_x - capsule_width / 2, capsule_top,
    center_x + capsule_width / 2, capsule_top + capsule_height,
    mic_color, capsule_radius, ImGui.DrawFlags_RoundCornersAll)

  -- U-shaped bracket below capsule
  local bracket_width = size * 0.50
  local bracket_height = size * 0.12
  local bracket_top = capsule_top + capsule_height / 2.5 - size * 0.02
  local bracket_thickness = size * 0.06

  -- Bottom curve of bracket (arc)
  local bracket_bottom = bracket_top + bracket_height
  local arc_radius = bracket_width / 2
  ImGui.DrawList_PathArcTo(draw_list,
    center_x, bracket_bottom,
    arc_radius, 0, math.pi, 16)
  ImGui.DrawList_PathStroke(draw_list, mic_color, ImGui.DrawFlags_None, bracket_thickness)

  -- Vertical stand/stem
  local stem_top = bracket_bottom + size * 0.02
  local stem_bottom = y + size * 0.88
  ImGui.DrawList_AddLine(draw_list,
    center_x, stem_top,
    center_x, stem_bottom,
    mic_color, bracket_thickness * 0.7)

  -- Base
  local base_width = size * 0.42
  ImGui.DrawList_AddLine(draw_list,
    center_x - base_width / 2, stem_bottom,
    center_x + base_width / 2, stem_bottom,
    mic_color, bracket_thickness)

  -- Glow effect
  if state == "recording" or state == "paused" or state == "standby" then
    local time = ImGui.GetTime(ctx)
    local pulse = (math.sin(time * 4) + 1) / 2
    local glow_alpha = 0.2 + pulse * 0.3

    local glow_color
    if state == "recording" then
      glow_color = ImGui.ColorConvertDouble4ToU32(
        colors.recording[1], colors.recording[2], colors.recording[3], glow_alpha)
    elseif state == "paused" then
      glow_color = ImGui.ColorConvertDouble4ToU32(
        colors.paused[1], colors.paused[2], colors.paused[3], glow_alpha)
    elseif state == "standby" then
      glow_color = ImGui.ColorConvertDouble4ToU32(
        colors.standby[1], colors.standby[2], colors.standby[3], glow_alpha)
    end

    -- Outer glow
    ImGui.DrawList_AddCircle(draw_list,
      center_x, capsule_top + capsule_height / 2,
      size * 0.45, glow_color, 32, 6)

    -- Inner glow
    ImGui.DrawList_AddCircle(draw_list,
      center_x, capsule_top + capsule_height / 2,
      size * 0.38, glow_color, 32, 4)
  end
end

---------------------------------------------------------------------

defer(main)
