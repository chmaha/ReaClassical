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

local main, count_rec_armed_tracks, draw_mic_icon

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
        color = ImGui.ColorConvertDouble4ToU32(1.0, 0.2, 0.2, 1.0)
      elseif state == "paused" then
        color = ImGui.ColorConvertDouble4ToU32(1.0, 0.85, 0.1, 1.0)
      elseif state == "standby" then
        local alpha = 0.5 + 0.5 * math.sin(time * 4)
        color = ImGui.ColorConvertDouble4ToU32(0.1, 1.0, 0.1, alpha)
      else
        color = ImGui.ColorConvertDouble4ToU32(0.6, 0.6, 0.6, 1.0)
      end

      local text_w = select(1, ImGui.CalcTextSize(ctx, label))
      ImGui.SetCursorPosX(ctx, (win_w - text_w) * 0.5)
      ImGui.TextColored(ctx, color, label)
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
  -- Determine color based on state
  local mic_color
  if state == "recording" then
    mic_color = ImGui.ColorConvertDouble4ToU32(0.9, 0.1, 0.1, 1.0)
  elseif state == "paused" then
    mic_color = ImGui.ColorConvertDouble4ToU32(1.0, 0.85, 0.1, 1.0)
  elseif state == "standby" then
    mic_color = ImGui.ColorConvertDouble4ToU32(0.1, 0.9, 0.1, 1.0)
  else
    mic_color = ImGui.ColorConvertDouble4ToU32(0.6, 0.6, 0.6, 1.0)
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
      glow_color = ImGui.ColorConvertDouble4ToU32(1.0, 0.0, 0.0, glow_alpha)
    elseif state == "paused" then
      glow_color = ImGui.ColorConvertDouble4ToU32(1.0, 0.85, 0.1, glow_alpha)
    elseif state == "standby" then
      glow_color = ImGui.ColorConvertDouble4ToU32(0.1, 1.0, 0.1, glow_alpha)
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