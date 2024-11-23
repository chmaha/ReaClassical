--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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
local seconds_to_hhmm

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
  MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
  return
end

local iterated_filenames = false
local added_take_number = false
local rec_name_set = false
local take_count, take_text
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

if reset == "" then reset = 0 end

local win
local values = {}
local current_time = os.time()

if pos_string ~= "" then
  for value in pos_string:gmatch("[^" .. "," .. "]+") do
    table.insert(values, value)
  end
  win = {
    width = 300,
    height = 125,
    xpos = values[1],
    ypos = values[2]
  }
else
  win = {
    width = 300,
    height = 125,
    xpos = 0,
    ypos = 0
  }
end

local take_counter = NamedCommandLookup("_RSac9d8eec87fd6c1d70abfe3dcc57849e2aac0bdc")
SetToggleCommandState(1, take_counter, 1)

local red_ruler = NamedCommandLookup("_SWS_RECREDRULER")
local red_ruler_state = GetToggleCommandState(red_ruler)
if red_ruler_state then
  Main_OnCommand(red_ruler,0)
end

local marker_actions = NamedCommandLookup("_SWSMA_ENABLE")
Main_OnCommand(marker_actions, 0)


local session_dir = ""
local session_suffix = ""
local session

local rec_color = ColorToNative(255, 0, 0) | 0x1000000
local recpause_color = ColorToNative(255, 255, 127) | 0x1000000

local laststate
local project_userdata, project_name
local gfx = gfx

local start_time, end_time, duration
local run_once = false

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
    added_take_number = false
    if run_once then
      run_once = false
      remove_markers_by_name("!1013")
    end
    if not iterated_filenames then
      take_text = get_take_count(session) + 1
    else
      take_text = take_count + 1
    end

    if gfx.mouse_cap & 1 == 1 then
      laststate = nil
      local choice = MB("Recalculate take count?", "ReaClassical Take Counter", 4)
      if choice == 6 then
        take_text = get_take_count(session) + 1
        rec_name_set = false
      end
    elseif gfx.mouse_cap & 2 == 2 then
      laststate = nil

      local session_text = session
      local ret, choices = GetUserInputs(
        'ReaClassical Take Counter', 6,
        'Set Take Number:,Session Name:,Allow Take Number Override?:,Recording Start Time (HH:MM):,' ..
        'Recording End Time (HH:MM):,Duration (HH:MM):',
        table.concat({ take_text, session_text, reset, start_text, end_text, duration_text }, ',')
      )

      local take_choice, session_choice, reset_choice, start_choice, end_choice, duration_choice =
          string.match(choices, "(.-),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*)")

      take_choice = tonumber(take_choice) or take_text
      reset_choice = tonumber(reset_choice) or reset

      if ret then
        start_next_day = ""
        end_next_day = ""
        if start_choice ~= "" then
          start_time = parse_time(start_choice)
          if start_time then start_text = start_choice end
          if start_time <= current_time then
            start_time = start_time + 24 * 60 * 60
            start_next_day = "*"
          end
        else
          start_text, start_time = "", nil
        end

        if end_choice ~= "" then
          end_time = parse_time(end_choice)
          if end_time then end_text = end_choice end
          if not start_time and end_time <= current_time then
            end_time = end_time + 24 * 60 * 60
            end_next_day = "*"
          elseif start_time and end_time <= start_time then
            end_time = end_time + 24 * 60 * 60
            end_next_day = "*"
          end
        else
          end_text, end_time = "", nil
        end

        if duration_choice ~= "" then
          duration = parse_duration(duration_choice)
          if duration then
            duration_text = duration_choice
            if start_time then
              calc_end_time = seconds_to_hhmm(start_time + duration)
            end
          end
        else
          duration_text, duration, calc_end_time = "", nil, nil
        end
      else
        start_choice, end_choice, duration_choice = start_text, end_text, duration_text
      end

      if session_choice and session_choice ~= "" then
        session = session_choice
        session_dir = session .. separator
        session_suffix = session .. "_"
      elseif ret then
        session, session_dir, session_suffix = "", "", ""
      end

      local reset_choice_num = tonumber(reset_choice)
      if reset_choice_num and (reset_choice_num == 0 or reset_choice_num == 1) then
        reset = reset_choice_num
      end

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

      SetProjExtState(0, "ReaClassical", "TakeSessionName", session)
      SetProjExtState(0, "ReaClassical", "TakeCounterOverride", reset)
      SetProjExtState(0, "ReaClassical", "Recording Start", start_choice)
      SetProjExtState(0, "ReaClassical", "Recording End", end_choice)
      SetProjExtState(0, "ReaClassical", "Recording Duration", duration_choice)

      if reset == 0 then
        take_text = get_take_count(session) + 1
        rec_name_set = false
      end
    end


    if not rec_name_set then
      local padded_take_text = string.format("%03d", tonumber(take_text))
      SNM_SetStringConfigVar("recfile_wildcards", session_dir .. session_suffix
        .. "$track_T" .. padded_take_text)
      rec_name_set = true
    end

    if laststate ~= playstate then
      laststate = playstate
      gfx.setfont(1, "Arial", 90, 98)
      gfx.x = 0
      gfx.y = 0
      gfx.set(0.5, 0.8, 0.5, 1)
      local take_width, take_height = gfx.measurestr(take_text)
      gfx.x = ((win.width - take_width) / 2)
      gfx.drawstr(take_text)
      gfx.setfont(1, "Arial", 25, 98)
      local session_text = session
      if session_text == "" and take_text == 1 then
        gfx.setfont(1, "Arial", 15, 98)
        session_text = "Right-click to set session name"
      end
      local session_width, session_height = gfx.measurestr(session_text)
      gfx.x = ((win.width - session_width) / 2)
      gfx.y = ((win.height - session_height + take_height / 3) / 2)
      gfx.set(0.8, 0.8, 0.9, 1)
      gfx.drawstr("\n" .. session_text)
      SetThemeColor("ts_lane_bg", -1)
      SetThemeColor("marker_lane_bg", -1)
      SetThemeColor("region_lane_bg", -1)

      if start_time or end_time or duration then
        gfx.setfont(1, "Arial", 15, 98)
        gfx.set(0.337, 0.627, 0.827, 1)
        gfx.x = win.width - 60
        gfx.y = 15

        if start_time and end_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. end_text .. end_next_day)
        elseif start_time and calc_end_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. calc_end_time .. end_next_day)
        elseif start_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day)
        elseif end_time then
          gfx.drawstr("End\n" .. end_text .. end_next_day)
        else
          gfx.drawstr("Dur." .. "\n" .. duration_text)
        end
      end

      UpdateTimeline()
    end
  elseif playstate == 5 or playstate == 6 then -- recording
    local stop_pos
    if not run_once then
      if not start_time and end_time then
        stop_pos = GetCursorPosition() + (end_time - current_time)
        remove_markers_by_name("!1013")
        AddProjectMarker2(0, false, stop_pos, 0, "!1013", 1013, 0)
      elseif duration then
        stop_pos = GetCursorPosition() + duration
        remove_markers_by_name("!1013")
        AddProjectMarker2(0, false, stop_pos, 0, "!1013", 1013, 0)
      end
      run_once = true
    end
    if not iterated_filenames then
      take_text = get_take_count(session) + 1
    end

    if laststate ~= playstate then
      laststate = playstate
      if playstate == 6 then
        gfx.set(1, 1, 0.5, 1)
        gfx.rect(30, 25, 15, 50)
        gfx.rect(55, 25, 15, 50)
        SetThemeColor("ts_lane_bg", recpause_color)
        SetThemeColor("marker_lane_bg", recpause_color)
        SetThemeColor("region_lane_bg", recpause_color)
      else
        gfx.set(1, 0.5, 0.5, 1)
        gfx.circle(50, 50, 20, 40)
        SetThemeColor("ts_lane_bg", rec_color)
        SetThemeColor("marker_lane_bg", rec_color)
        SetThemeColor("region_lane_bg", rec_color)
      end
      UpdateTimeline()

      gfx.setfont(1, "Arial", 90, 98)
      gfx.x = 0
      gfx.y = 0
      local take_width, take_height = gfx.measurestr(take_text)
      gfx.x = ((win.width - take_width) / 2)
      gfx.drawstr(take_text)

      local session_text = session
      gfx.setfont(1, "Arial", 25, 98)
      local session_width, session_height = gfx.measurestr(session_text)
      gfx.x = ((win.width - session_width) / 2)
      gfx.y = ((win.height - session_height + take_height / 3) / 2)
      gfx.drawstr("\n" .. session_text)

      if start_time or end_time or duration then
        gfx.setfont(1, "Arial", 15, 98)
        gfx.set(0.337, 0.627, 0.827, 1)
        gfx.x = win.width - 60
        gfx.y = 15

        if start_time and end_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. end_text .. end_next_day)
        elseif start_time and calc_end_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. calc_end_time .. end_next_day)
        elseif start_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day)
        elseif end_time then
          gfx.drawstr("End\n" .. end_text .. end_next_day)
        else
          gfx.drawstr("Dur." .. "\n" .. duration_text)
        end
      end

      if start_time or end_time then
        duration = nil
        duration_text = ""
      end
      start_time = nil
      start_text = ""
      end_time = nil
      end_text = ""
      calc_end_time = nil

      if not added_take_number then
        take_count = take_count + 1
        take_text = take_count
        added_take_number = true
        rec_name_set = false
      end
    end
  end

  if start_time then
    check_time()
    if playstate == 5 then
      start_time = nil
      start_text = ""
      end_time = nil
      end_text = ""
    end
  end

  local key = gfx.getchar()
  if key ~= -1 then
    defer(main)
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
  SetToggleCommandState(1, take_counter, 0)
  local _, x, y, _, _ = gfx.dock(-1, 1, 1, 1, 1)
  local pos = x .. "," .. y
  SetProjExtState(0, "ReaClassical", "TakeCounterPosition", pos)
  SNM_SetStringConfigVar("recfile_wildcards", prev_recfilename_value)
  SetThemeColor("ts_lane_bg", -1)
  SetThemeColor("marker_lane_bg", -1)
  SetThemeColor("region_lane_bg", -1)
  remove_markers_by_name("!1013")
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
    return (hours * 3600) + (minutes * 60) -- Return duration in seconds
  end
  return nil
end

---------------------------------------------------------------------

function check_time()
  current_time = os.time()
  if current_time >= start_time and reaper.GetPlayState() ~= 5 then
    if end_time then
      remove_markers_by_name("!1013")
      local stop_pos = GetCursorPosition() + (end_time - start_time)
      AddProjectMarker2(0, false, stop_pos, 0, "!1013", 1013, 0)
    end
    local cursor_pos = GetCursorPosition()
    SetProjExtState(0, "ReaClassical", "ClassicalTakeRecordCurPos", cursor_pos)
    reaper.Main_OnCommand(1013, 0) -- Record command
    SetProjExtState(0, "ReaClassical", "Recording Start", "")
    SetProjExtState(0, "ReaClassical", "Recording End", "")
  end
end

---------------------------------------------------------------------

function remove_markers_by_name(marker_name)
  local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
  local total_markers = num_markers + num_regions

  for i = total_markers - 1, 0, -1 do -- Iterate backward to avoid index shifting
    local retval, isrgn, _, _, name, markrgnindex = reaper.EnumProjectMarkers(i)
    if retval and name == marker_name then
      reaper.DeleteProjectMarker(0, markrgnindex, isrgn)
    end
  end
end

---------------------------------------------------------------------

function seconds_to_hhmm(seconds)
  local hours = math.floor(seconds / 3600) % 24 -- Wrap around if past midnight
  local minutes = math.floor((seconds % 3600) / 60)
  return string.format("%02d:%02d", hours, minutes)
end

---------------------------------------------------------------------

gfx.init("Take Number", win.width, win.height, 0, win.xpos, win.ypos)
atexit(clean_up)
main()
