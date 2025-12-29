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

local main, get_take_count, clean_up, parse_time, parse_duration, check_time, remove_markers_by_name
local seconds_to_hhmm, find_first_rec_enabled_parent, draw, marker_actions

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
  MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
  return
end

-- Check for ReaImGui
if not reaper.ImGui_CreateContext then
  MB('Please install ReaImGui extension before running this function', 'Error: Missing Extension', 0)
  return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
  MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
  return
end

---------------------------------------------------------------------

local iterated_filenames = false
local added_take_number = false
local rec_name_set = false
local take_count, take_text, session_text
local _, prev_recfilename_value = get_config_var_string("recfile_wildcards")
local separator = package.config:sub(1, 1);

local _, pos_string = GetProjExtState(0, "ReaClassical", "TakeCounterPosition")
local _, reset = GetProjExtState(0, "ReaClassical", "TakeCounterOverride")
local _, start_text = GetProjExtState(0, "ReaClassical", "Recording Start")
local _, end_text = GetProjExtState(0, "ReaClassical", "Recording End")
local _, duration_text = GetProjExtState(0, "ReaClassical", "Recording Duration")
local calc_end_time
local start_next_day = ""
local end_next_day = ""
local set_via_right_click = false
local auto_started = false

if reset == "" then reset = 0 end

local values = {}
local current_time = os.time()

-- Default window settings
local win = {
  width = 300,
  height = 200,
  xpos = nil,
  ypos = nil
}

-- if pos_string ~= "" then
--   for value in pos_string:gmatch("[^" .. "," .. "]+") do
--     table.insert(values, value)
--   end
--   if #values >= 2 then
--     win.xpos = tonumber(values[1])
--     win.ypos = tonumber(values[2])
--   end
--   if #values >= 4 then
--     win.width = tonumber(values[3]) or 300
--     win.height = tonumber(values[4]) or 125
--   end
-- end

local take_counter = NamedCommandLookup("_RSac9d8eec87fd6c1d70abfe3dcc57849e2aac0bdc")
SetToggleCommandState(1, take_counter, 1)

local marker_actions_running = false

local session_dir = ""
local session_suffix = ""
local session

local rec_color = ColorToNative(255, 0, 0) | 0x1000000
local recpause_color = ColorToNative(255, 255, 127) | 0x1000000

local laststate
local project_userdata, project_name

local start_time, end_time, duration
local run_once = false

local F9_command = NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")

-- ImGui Context
local ctx = reaper.ImGui_CreateContext('Take Counter')
local large_font = reaper.ImGui_CreateFont('Arial', 120)
local medium_font = reaper.ImGui_CreateFont('Arial', 50)
local small_font = reaper.ImGui_CreateFont('Arial', 25)
reaper.ImGui_Attach(ctx, large_font)
reaper.ImGui_Attach(ctx, medium_font)
reaper.ImGui_Attach(ctx, small_font)

local open = true

-- Popup state variables (persisted across frames)
local popup_open = false
local popup_take_text = nil
local popup_session_text = nil
local popup_reset = nil
local popup_start_text = nil
local popup_end_text = nil
local popup_duration_text = nil

---------------------------------------------------------------------

function main()
  local retval, projfn = EnumProjects(-1)
  if project_userdata ~= retval or project_name ~= projfn then
    project_userdata = retval
    project_name = projfn
    _, session = GetProjExtState(0, "ReaClassical", "TakeSessionName")
    if session ~= nil and session ~= "" then
      session_dir = session .. separator
      session_suffix = session .. "_"
    else
      session = ""
    end
    iterated_filenames = false
    laststate = nil
    rec_name_set = false
  end
  
  local playstate = GetPlayState()
  
  if playstate == 0 or playstate == 1 then -- stopped or playing
    if auto_started then
      auto_started = false
      end_time = nil
      end_text = ""
      duration = nil
      duration_text = ""
    end
    added_take_number = false
    if run_once then
      run_once = false
      Main_OnCommand(24800, 0) -- clear any section override
      if set_via_right_click then
        start_time = nil
        end_time = nil
      end
      calc_end_time = nil
      remove_markers_by_name("!1013")
      remove_markers_by_name("!" .. F9_command)
    end
    if not iterated_filenames then
      take_text = get_take_count(session) + 1
    else
      take_text = take_count + 1
    end

    if not rec_name_set then
      local padded_take_text = string.format("%03d", tonumber(take_text))
      SNM_SetStringConfigVar("recfile_wildcards", session_dir .. session_suffix
        .. "$tracknameornumber_T" .. padded_take_text)
      rec_name_set = true
    end

    if laststate ~= playstate then
      laststate = playstate
    end

    if start_time then
      check_time()
    end
  elseif playstate == 5 or playstate == 6 then -- recording
    local stop_pos

    if start_time and start_time > current_time then
      start_time = nil
      end_time = nil
      duration = nil
    end

    if not run_once then
      Main_OnCommand(24800, 0) -- clear any section override
      Main_OnCommand(24802, 0) -- set section to recording
      if not start_time and end_time then
        remove_markers_by_name("!" .. F9_command)
        remove_markers_by_name("!1013")
        current_time = os.time()
        stop_pos = GetCursorPosition() + (end_time - current_time)
      elseif duration then
        stop_pos = GetCursorPosition() + duration
      end
      if stop_pos then
        local marker_name = F9_command ~= 0 and "!" .. F9_command or "!1013"
        local marker_id = F9_command ~= 0 and F9_command or 1013
        AddProjectMarker2(0, false, stop_pos, 0, marker_name, marker_id, 0)
        marker_actions()
      end
      run_once = true
    end

    if not iterated_filenames then
      take_text = get_take_count(session) + 1
    end

    if laststate ~= playstate then
      laststate = playstate

      if start_time or end_time then
        duration = nil
        duration_text = ""
      end

      if not added_take_number then
        take_count = take_count + 1
        take_text = take_count
        added_take_number = true
        rec_name_set = false
      end
    end
  end

  -- Draw ImGui window
  draw(playstate)
  
  if open then
    reaper.defer(main)
  end
end

---------------------------------------------------------------------

function get_take_count(session_name)
  take_count = 0

  local media_path = GetProjectPath(0)

  local i = 0
  while true do
    local filename = EnumerateFiles(media_path .. separator .. session_name, i)
    if not filename then
      break
    end

    local take_capture = tonumber(filename:match(".*[^%d](%d+)%)?%.%a+$"))
    if take_capture and take_capture > take_count then
      take_count = take_capture
    end

    i = i + 1
  end

  if (GetPlayState() == 5 or GetPlayState() == 6) and take_count > 0 then
    take_count = take_count - 1
  end

  iterated_filenames = true
  return take_count
end

---------------------------------------------------------------------

function clean_up()
  Main_OnCommand(24800, 0) -- clear any section override
  SetToggleCommandState(1, take_counter, 0)
  
  -- Save window position and size
  local x, y = reaper.ImGui_GetWindowPos(ctx)
  local w, h = reaper.ImGui_GetWindowSize(ctx)
  local pos = x .. "," .. y .. "," .. w .. "," .. h
  SetProjExtState(0, "ReaClassical", "TakeCounterPosition", pos)
  
  SNM_SetStringConfigVar("recfile_wildcards", prev_recfilename_value)
  SetThemeColor("ts_lane_bg", -1)
  SetThemeColor("marker_lane_bg", -1)
  SetThemeColor("region_lane_bg", -1)
  remove_markers_by_name("!1013")
  remove_markers_by_name("!" .. F9_command)
  UpdateTimeline()
end

---------------------------------------------------------------------

function parse_time(input)
  local pattern = "(%d+):(%d+)"
  local hour, min = input:match(pattern)
  if hour and min then
    local now = os.date("*t")
    now.hour = tonumber(hour)
    now.min = tonumber(min)
    now.sec = 0
    return os.time(now)
  else
    return nil
  end
end

---------------------------------------------------------------------

function parse_duration(duration_str)
  local hours, minutes = duration_str:match("^(%d+):(%d+)$")
  if hours and minutes then
    hours = tonumber(hours)
    minutes = tonumber(minutes)
    return (hours * 3600) + (minutes * 60)
  end
  return nil
end

---------------------------------------------------------------------

function check_time()
  current_time = os.time()
  if current_time >= start_time and GetPlayState() ~= 5 then
    if end_time then
      local stop_pos = GetCursorPosition() + (end_time - start_time)
      remove_markers_by_name("!" .. F9_command)
      remove_markers_by_name("!1013")
      if stop_pos then
        local marker_name = F9_command ~= 0 and "!" .. F9_command or "!1013"
        local marker_id = F9_command ~= 0 and F9_command or 1013
        AddProjectMarker2(0, false, stop_pos, 0, marker_name, marker_id, 0)
        marker_actions()
      end
    end
    local cursor_pos = GetCursorPosition()
    SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", cursor_pos)
    if F9_command ~= 0 then
      local rec_enabled_parent = find_first_rec_enabled_parent()
      if rec_enabled_parent then
        SetOnlyTrackSelected(rec_enabled_parent)
      end
      Main_OnCommand(F9_command, 0)
    else
      Main_OnCommand(1013, 0) -- Regular record command
    end
    SetProjExtState(0, "ReaClassical", "Recording Start", "")
    SetProjExtState(0, "ReaClassical", "Recording End", "")
    SetProjExtState(0, "ReaClassical", "Recording Duration", "")
    start_time = nil
    start_text = ""
    auto_started = true
  end
end

---------------------------------------------------------------------

function remove_markers_by_name(marker_name)
  local _, num_markers, num_regions = CountProjectMarkers(0)
  local total_markers = num_markers + num_regions

  for i = total_markers - 1, 0, -1 do
    local retval, isrgn, _, _, name, markrgnindex = EnumProjectMarkers(i)
    if retval and name == marker_name then
      DeleteProjectMarker(0, markrgnindex, isrgn)
    end
  end
end

---------------------------------------------------------------------

function seconds_to_hhmm(seconds)
  local t = os.date("*t", seconds)
  return string.format("%02d:%02d", t.hour, t.min)
end

---------------------------------------------------------------------

function find_first_rec_enabled_parent()
  local num_tracks = CountTracks(0)

  for i = 0, num_tracks - 1 do
    local track = GetTrack(0, i)
    local is_parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
    local is_rec_enabled = GetMediaTrackInfo_Value(track, "I_RECARM") == 1

    if is_parent and is_rec_enabled then
      return track
    end
  end

  return nil
end

---------------------------------------------------------------------

function draw(playstate)
  -- Always set window to default size when opening (but allow user to resize)
  if win.xpos and win.ypos then
    reaper.ImGui_SetNextWindowPos(ctx, win.xpos, win.ypos, reaper.ImGui_Cond_FirstUseEver())
  end
  -- Always start at 300x125, but user can resize
  reaper.ImGui_SetNextWindowSize(ctx, win.width, win.height, reaper.ImGui_Cond_Appearing())
  
  -- Set minimum and maximum size constraints to maintain aspect ratio
  reaper.ImGui_SetNextWindowSizeConstraints(ctx, win.width, win.height, 3000,1750)
  
  local visible, should_close = reaper.ImGui_Begin(ctx, 'Take Counter', true, 
    reaper.ImGui_WindowFlags_NoCollapse() | reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoScrollWithMouse())
  
  if not visible then
    reaper.ImGui_End(ctx)
    return
  end
  
  if should_close == false then
    if playstate == 5 or playstate == 6 then
      local choice = reaper.MB("Are you sure you want to quit the take counter window during a recording?", "Take Counter", 4)
      if choice == 6 then
        open = false
      end
    else
      open = false
    end
  end
  
  local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
  local win_w, win_h = reaper.ImGui_GetWindowSize(ctx)
  local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
  
  -- Calculate scaling
  local base_width = win.height
  local base_height = win.width
  local scale_x = win_w / base_width
  local scale_y = win_h / base_height
  local scale = math.min(scale_x, scale_y)
  
  session_text = session
  
  -- Set colors based on playstate
  if playstate == 0 or playstate == 1 then
    SetThemeColor("ts_lane_bg", -1)
    SetThemeColor("marker_lane_bg", -1)
    SetThemeColor("region_lane_bg", -1)
  elseif playstate == 6 then
    SetThemeColor("ts_lane_bg", recpause_color)
    SetThemeColor("marker_lane_bg", recpause_color)
    SetThemeColor("region_lane_bg", recpause_color)
  elseif playstate == 5 then
    SetThemeColor("ts_lane_bg", rec_color)
    SetThemeColor("marker_lane_bg", rec_color)
    SetThemeColor("region_lane_bg", rec_color)
  end
  
  -- Draw take number (large font) - color changes based on playstate
  reaper.ImGui_PushFont(ctx, large_font, 120 * scale)
  local take_str = tostring(take_text)
  local text_w, text_h = reaper.ImGui_CalcTextSize(ctx, take_str)
  local take_x = (win_w - text_w) / 2
  local take_y = (win_h - text_h) / 3
  reaper.ImGui_SetCursorPos(ctx, take_x, take_y)
  
  -- Set color based on playstate
  local take_color
  if playstate == 6 then
    take_color = 0xFFFF7FFF -- Yellow for paused
  elseif playstate == 5 then
    take_color = 0xFF7F7FFF -- Red for recording
  else
    take_color = 0x7FCC7FFF -- Green for stopped/playing
  end
  
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), take_color)
  reaper.ImGui_Text(ctx, take_str)
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_PopFont(ctx)
  
  -- Draw recording indicator (must come after text measurement)
  if playstate == 5 or playstate == 6 then
    local indicator_x = win_x + 50 * scale
    -- Align with center of take number
    local indicator_y = win_y + take_y + (text_h / 2)
    
    if playstate == 6 then
      -- Pause bars (yellow) - RGBA format
      local bar_height = 50 * scale
      reaper.ImGui_DrawList_AddRectFilled(draw_list, 
        indicator_x - 20 * scale, indicator_y - bar_height / 2,
        indicator_x - 5 * scale, indicator_y + bar_height / 2,
        0xFFFF7FFF)
      reaper.ImGui_DrawList_AddRectFilled(draw_list,
        indicator_x + 5 * scale, indicator_y - bar_height / 2,
        indicator_x + 20 * scale, indicator_y + bar_height / 2,
        0xFFFF7FFF)
    else
      -- Recording circle (red) - RGBA format
      reaper.ImGui_DrawList_AddCircleFilled(draw_list,
        indicator_x, indicator_y,
        20 * scale,
        0xFF7F7FFF)
    end
  end
  
  -- Create invisible button over take number for click detection
  reaper.ImGui_SetCursorPos(ctx, take_x, take_y)
  if reaper.ImGui_InvisibleButton(ctx, "take_number_btn", text_w, text_h) then
    laststate = nil
    local choice = MB("Recalculate take count?", "ReaClassical Take Counter", 4)
    if choice == 6 then
      take_text = get_take_count(session) + 1
      rec_name_set = false
    end
  end
  
  -- Draw session name (medium or small font) - closer to take number
  local display_session = session_text
  local use_small = false
  
  if display_session == "" and take_text == 1 then
    display_session = "Right-click to set session name"
    use_small = true
  end
  
  if use_small then
    reaper.ImGui_PushFont(ctx, small_font, 25 * scale)
  else
    reaper.ImGui_PushFont(ctx, medium_font, 50 * scale)
  end
  local session_w, session_h = reaper.ImGui_CalcTextSize(ctx, display_session)
  -- Smaller gap from take number to match original
  reaper.ImGui_SetCursorPos(ctx, (win_w - session_w) / 2, take_y + text_h + (10 * scale))
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xE6CCCCFF) -- Light purple (RGBA)
  reaper.ImGui_Text(ctx, display_session)
  reaper.ImGui_PopStyleColor(ctx)
  reaper.ImGui_PopFont(ctx)
  
  -- Draw time info (small font) - with more padding from top and right
  if (playstate == 0 or playstate == 1 or (playstate == 5 or playstate == 6) and set_via_right_click) then
    if start_time or end_time or duration then
      reaper.ImGui_PushFont(ctx, small_font, 25 * scale)
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xD3A056FF) -- Blue tint (RGBA)
      
      local time_text = ""
      if start_time and end_time then
        time_text = "Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. end_text .. end_next_day
      elseif start_time and calc_end_time then
        time_text = "Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. calc_end_time .. end_next_day
      elseif start_time then
        time_text = "Start\n" .. start_text .. start_next_day
      elseif end_time then
        time_text = "End\n" .. end_text .. end_next_day
      else
        time_text = "Dur.\n" .. duration_text
      end
      
      local time_w, time_h = reaper.ImGui_CalcTextSize(ctx, time_text)
      -- Increased padding from top and right edges
      reaper.ImGui_SetCursorPos(ctx, win_w - time_w - (20 * scale), take_y)
      reaper.ImGui_Text(ctx, time_text)
      
      reaper.ImGui_PopStyleColor(ctx)
      reaper.ImGui_PopFont(ctx)
    end
  end
  
  -- Handle right-click for settings popup (anywhere in window)
  if reaper.ImGui_IsWindowHovered(ctx) and reaper.ImGui_IsMouseClicked(ctx, 1) then
    -- Initialize popup values from current state when popup opens
    popup_take_text = take_text
    popup_session_text = session
    popup_reset = reset  -- This will be 0 or 1 based on current state
    popup_start_text = start_text
    popup_end_text = end_text
    popup_duration_text = duration_text
    popup_open = true
    reaper.ImGui_OpenPopup(ctx, "settings_popup")
  end
  
  -- ImGui popup menu for settings
  if reaper.ImGui_BeginPopup(ctx, "settings_popup") then
    marker_actions_running = false
    laststate = nil
    
    reaper.ImGui_Text(ctx, "Take Counter Settings")
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- Use table for aligned layout
    if reaper.ImGui_BeginTable(ctx, "settings_table", 2, reaper.ImGui_TableFlags_SizingStretchProp()) then
      reaper.ImGui_TableSetupColumn(ctx, "labels", reaper.ImGui_TableColumnFlags_WidthFixed(), 230)
      reaper.ImGui_TableSetupColumn(ctx, "inputs", reaper.ImGui_TableColumnFlags_WidthFixed(), 250)
      
      -- Override checkbox (first so we can enable/disable take number based on it)
      reaper.ImGui_TableNextRow(ctx)
      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      reaper.ImGui_AlignTextToFramePadding(ctx)
      reaper.ImGui_Text(ctx, "Allow Take Number Override:")
      reaper.ImGui_TableSetColumnIndex(ctx, 1)
      local override_checked = (tonumber(popup_reset) == 1)
      local rv, val = reaper.ImGui_Checkbox(ctx, "##override", override_checked)
      if rv then popup_reset = val and 1 or 0 end
      
      -- Take number input (disabled unless override is enabled)
      reaper.ImGui_TableNextRow(ctx)
      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      reaper.ImGui_AlignTextToFramePadding(ctx)
      reaper.ImGui_Text(ctx, "Set Take Number:")
      reaper.ImGui_TableSetColumnIndex(ctx, 1)
      local take_disabled = (tonumber(popup_reset) ~= 1)
      if take_disabled then
        reaper.ImGui_BeginDisabled(ctx, true)
      end
      reaper.ImGui_SetNextItemWidth(ctx, -1)
      local rv, val = reaper.ImGui_InputInt(ctx, "##take", popup_take_text)
      if rv and not take_disabled then popup_take_text = val end
      if take_disabled then
        reaper.ImGui_EndDisabled(ctx)
      end
      
      -- Session name input
      reaper.ImGui_TableNextRow(ctx)
      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      reaper.ImGui_AlignTextToFramePadding(ctx)
      reaper.ImGui_Text(ctx, "Session Name:")
      reaper.ImGui_TableSetColumnIndex(ctx, 1)
      reaper.ImGui_SetNextItemWidth(ctx, -1)
      local rv, val = reaper.ImGui_InputText(ctx, "##session", popup_session_text, 256)
      if rv then popup_session_text = val end
      
      -- Start time input
      reaper.ImGui_TableNextRow(ctx)
      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      reaper.ImGui_AlignTextToFramePadding(ctx)
      reaper.ImGui_Text(ctx, "Recording Start Time (HH:MM):")
      reaper.ImGui_TableSetColumnIndex(ctx, 1)
      reaper.ImGui_SetNextItemWidth(ctx, 80)
      local rv, val = reaper.ImGui_InputText(ctx, "##start", popup_start_text, 256)
      if rv then popup_start_text = val end
      
      -- End time input
      reaper.ImGui_TableNextRow(ctx)
      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      reaper.ImGui_AlignTextToFramePadding(ctx)
      reaper.ImGui_Text(ctx, "Recording End Time (HH:MM):")
      reaper.ImGui_TableSetColumnIndex(ctx, 1)
      reaper.ImGui_SetNextItemWidth(ctx, 80)
      local rv, val = reaper.ImGui_InputText(ctx, "##end", popup_end_text, 256)
      if rv then popup_end_text = val end
      
      -- Duration input
      reaper.ImGui_TableNextRow(ctx)
      reaper.ImGui_TableSetColumnIndex(ctx, 0)
      reaper.ImGui_AlignTextToFramePadding(ctx)
      reaper.ImGui_Text(ctx, "Duration (HH:MM):")
      reaper.ImGui_TableSetColumnIndex(ctx, 1)
      reaper.ImGui_SetNextItemWidth(ctx, 80)
      local rv, val = reaper.ImGui_InputText(ctx, "##duration", popup_duration_text, 256)
      if rv then popup_duration_text = val end
      
      reaper.ImGui_EndTable(ctx)
    end
    
    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Spacing(ctx)
    
    -- Apply button
    if reaper.ImGui_Button(ctx, "Apply", 120, 0) then
      -- Copy popup values to main variables
      local session_changed = (popup_session_text ~= session)
      
      take_text = popup_take_text
      start_text = popup_start_text
      end_text = popup_end_text
      duration_text = popup_duration_text
      reset = popup_reset
      
      start_next_day = ""
      end_next_day = ""
      
      -- Parse start time
      if start_text ~= "" then
        start_time = parse_time(start_text)
        if start_time and start_time <= current_time then
          start_time = start_time + 24 * 60 * 60
          start_next_day = "*"
        end
      else
        start_time = nil
      end
      
      -- Parse end time
      if end_text ~= "" then
        end_time = parse_time(end_text)
        if end_time then
          if not start_time and end_time <= current_time then
            end_time = end_time + 24 * 60 * 60
            end_next_day = "*"
          elseif start_time and end_time <= start_time then
            end_time = end_time + 24 * 60 * 60
            end_next_day = "*"
          end
        end
      else
        end_time = nil
      end
      
      -- Parse duration
      if duration_text ~= "" then
        duration = parse_duration(duration_text)
        if duration and start_time then
          calc_end_time = seconds_to_hhmm(start_time + duration)
        end
      else
        duration = nil
        calc_end_time = nil
      end
      
      -- Apply session
      if popup_session_text and popup_session_text ~= "" then
        session = popup_session_text
        session_dir = session .. separator
        session_suffix = session .. "_"
      else
        session, session_dir, session_suffix = "", "", ""
      end
      
      -- If session changed, recalculate take count
      if session_changed then
        iterated_filenames = false
        take_text = get_take_count(session) + 1
        rec_name_set = false
      else
        -- Apply take number only if session didn't change
        local take_choice = tonumber(take_text) or take_count + 1
        if take_choice >= take_count then
          take_count = take_choice - 1
          take_text = take_choice
          rec_name_set = false
        else
          MB("You cannot set a take number lower than the highest found in the project path."
            .. "\nRecalculating take count...", "ReaClassical Take Counter", 0)
          take_text = get_take_count(session) + 1
          rec_name_set = false
        end
      end
      
      -- Save settings
      SetProjExtState(0, "ReaClassical", "TakeSessionName", session)
      SetProjExtState(0, "ReaClassical", "TakeCounterOverride", reset)
      SetProjExtState(0, "ReaClassical", "Recording Start", start_text)
      SetProjExtState(0, "ReaClassical", "Recording End", end_text)
      SetProjExtState(0, "ReaClassical", "Recording Duration", duration_text)
      
      if reset == 0 then
        take_text = get_take_count(session) + 1
        rec_name_set = false
      end
      
      set_via_right_click = true
      popup_open = false
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    
    reaper.ImGui_SameLine(ctx)
    
    -- Cancel button
    if reaper.ImGui_Button(ctx, "Cancel", 120, 0) then
      popup_open = false
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
    
    reaper.ImGui_EndPopup(ctx)
  else
    popup_open = false
  end
  
  UpdateTimeline()
  
  reaper.ImGui_End(ctx)
end

---------------------------------------------------------------------

function marker_actions()
  if marker_actions_running then return end -- do not start twice
  marker_actions_running = true

  local markers = {}
  local next_idx = 1
  local tolerance = 0.05 -- seconds (50 ms)

  -- Pre-scan markers once
  local function scan_markers()
    markers = {}
    local num_markers, num_regions = CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
      local retval, isrgn, pos, _, name, mark_idx = EnumProjectMarkers(i)
      if retval and not isrgn and name:sub(1, 1) == "!" then
        local cmd = tonumber(name:sub(2))
        if cmd then
          table.insert(markers, { pos = pos, cmd = cmd, mark_idx = mark_idx })
        end
      end
    end
    table.sort(markers, function(a, b) return a.pos < b.pos end)
  end

  scan_markers() -- initial scan

  local function reset_marker_index(play_pos)
    for i, m in ipairs(markers) do
      if m.pos >= play_pos then
        next_idx = i
        return
      end
    end
    next_idx = 1
  end

  local function check_next_marker()
    if not marker_actions_running then return end -- allow external stop

    local state = GetPlayState()

    if state & 1 == 0 then
      reset_marker_index(GetCursorPosition())
    else
      local play_pos = GetPlayPosition()
      local target = markers[next_idx]

      if target and play_pos >= target.pos - tolerance then
        Main_OnCommand(target.cmd, 0)

        if GetPlayState() & 1 == 0 then
          marker_actions_running = false
          return
        end

        next_idx = next_idx + 1
        if next_idx > #markers then
          next_idx = 1
        end
      end
    end

    defer(check_next_marker)
  end

  if #markers == 0 then
    marker_actions_running = false
    MB("No !<command_id> markers found in project", "ReaClassical Marker Actions", 0)
  else
    reset_marker_index(GetCursorPosition())
    check_next_marker()
  end
end

---------------------------------------------------------------------

reaper.atexit(clean_up)
main()