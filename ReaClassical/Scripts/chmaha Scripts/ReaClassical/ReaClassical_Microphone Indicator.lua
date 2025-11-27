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

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'
local ctx = ImGui.CreateContext("Recording Indicator")
local window_open = true

-- Mic icon size (DOUBLED)
local icon_size = 128

--------------------------------------------
-- Count rec-armed tracks
--------------------------------------------
local function count_rec_armed_tracks()
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

--------------------------------------------
-- Draw microphone icon
--------------------------------------------
local function draw_mic_icon(draw_list, x, y, size, state)

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

  -- Capsule geometry
  local capsule_width = size * 0.35
  local capsule_height = size * 0.5
  local capsule_top = center_y - size * 0.25
  local capsule_bottom = center_y + size * 0.05
  local capsule_left = center_x - capsule_width / 2
  local capsule_right = center_x + capsule_width / 2
  
  -- Capsule body
  ImGui.DrawList_AddRectFilled(draw_list, 
    capsule_left, capsule_top + capsule_width/2,
    capsule_right, capsule_bottom - capsule_width/2,
    mic_color)

  ImGui.DrawList_AddCircleFilled(draw_list, center_x, capsule_top + capsule_width/2,
    capsule_width/2, mic_color, 16)

  ImGui.DrawList_AddCircleFilled(draw_list, center_x, capsule_bottom - capsule_width/2,
    capsule_width/2, mic_color, 16)

  -- Detail lines (unchanged ratio → scaled automatically)
  local line_color = ImGui.ColorConvertDouble4ToU32(0.3, 0.3, 0.3, 0.5)
  for i = 1, 3 do
    local line_y = capsule_top + (capsule_height * i / 4)
    ImGui.DrawList_AddLine(draw_list, capsule_left, line_y, capsule_right, line_y, line_color, 2)
  end

  -- Stand
  local stand_width = size * 0.5
  local stand_height = size * 0.15
  local stand_top = capsule_bottom + size * 0.05
  local stand_bottom = stand_top + stand_height

  ImGui.DrawList_AddLine(draw_list,
    center_x - stand_width/2, stand_top,
    center_x - stand_width/2, stand_bottom, mic_color, 4)

  ImGui.DrawList_AddLine(draw_list,
    center_x + stand_width/2, stand_top,
    center_x + stand_width/2, stand_bottom, mic_color, 4)

  ImGui.DrawList_AddLine(draw_list,
    center_x - stand_width/2, stand_bottom,
    center_x + stand_width/2, stand_bottom, mic_color, 4)

  -- Stem
  local stem_top = stand_bottom
  local stem_bottom = y + size * 0.85
  ImGui.DrawList_AddLine(draw_list, center_x, stem_top, center_x, stem_bottom, mic_color, 6)

  -- Base
  local base_width = size * 0.4
  ImGui.DrawList_AddLine(draw_list,
    center_x - base_width/2, stem_bottom,
    center_x + base_width/2, stem_bottom,
    mic_color, 8)

  -- Glow
  local time = ImGui.GetTime(ctx)
  local pulse = (math.sin(time * 4) + 1) / 2
  local glow_alpha = 0.3 + pulse * 0.3

  local glow_color = nil
  if state == "recording" then
    glow_color = ImGui.ColorConvertDouble4ToU32(1.0, 0.0, 0.0, glow_alpha)
  elseif state == "paused" then
    glow_color = ImGui.ColorConvertDouble4ToU32(1.0, 0.85, 0.1, glow_alpha)
  elseif state == "standby" then
    glow_color = ImGui.ColorConvertDouble4ToU32(0.1, 1.0, 0.1, glow_alpha)
  end

  if glow_color then
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y - size * 0.1, size * 0.4, glow_color, 32, 6)
    ImGui.DrawList_AddCircle(draw_list, center_x, center_y - size * 0.1, size * 0.45, glow_color, 32, 4)
  end
end

--------------------------------------------
-- Main
--------------------------------------------
local function main()
  if not window_open then return end

  local window_flags = ImGui.WindowFlags_NoResize |
                       ImGui.WindowFlags_NoTitleBar |
                       ImGui.WindowFlags_NoScrollbar |
                       ImGui.WindowFlags_AlwaysAutoResize |
                       ImGui.WindowFlags_TopMost

  local opened, open_ref = ImGui.Begin(ctx, "Recording Indicator", true, window_flags)
  window_open = open_ref

  if not opened then
    ImGui.End(ctx)
    defer(main)
    return
  end

  local armed = count_rec_armed_tracks()
  local play_state = GetPlayState()

  local state = "idle"
  local label = ""

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

  -- Center icon
  local icon_center_x = (win_w - icon_size) * 0.5
  ImGui.SetCursorPosX(ctx, icon_center_x)

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local cursor_x, cursor_y = ImGui.GetCursorScreenPos(ctx)

  draw_mic_icon(draw_list, cursor_x, cursor_y, icon_size, state)
  ImGui.Dummy(ctx, icon_size, icon_size)

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

  if ImGui.BeginPopupContextWindow(ctx) then
    if ImGui.MenuItem(ctx, "Close") then window_open = false end
    ImGui.EndPopup(ctx)
  end

  ImGui.End(ctx)
  defer(main)
end

defer(main)
