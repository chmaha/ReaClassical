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

-- local profiler = dofile(GetResourcePath() ..
--   '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
-- defer = profiler.defer

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, get_take_count, clean_up, parse_time, parse_duration, check_time, remove_markers_by_name
local seconds_to_hhmm, find_first_rec_enabled_parent, draw, get_reaper_version
local marker_actions

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
  MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
  return
end

---------------------------------------------------------------------

function get_reaper_version()
  local version_str = GetAppVersion()
  local version = version_str:match("^(%d+%.%d+)")
  return tonumber(version)
end

---------------------------------------------------------------------

local reaper_ver = get_reaper_version()

local iterated_filenames = false
local added_take_number = false
local rec_name_set = false
local take_count, take_text, session_text
local take_width, take_height
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

local old_height = win.height
local old_width = win.width

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
local gfx = gfx

local start_time, end_time, duration
local run_once = false

local F9_command = NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")

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

    if gfx.mouse_cap & 1 == 1 then
      laststate = nil
      local choice = MB("Recalculate take count?", "ReaClassical Take Counter", 4)
      if choice == 6 then
        take_text = get_take_count(session) + 1
        rec_name_set = false
      end
    elseif gfx.mouse_cap & 2 == 2 then
      marker_actions_running = false
      laststate = nil
      session_text = session
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

      set_via_right_click = true
    end


    if not rec_name_set then
      local padded_take_text = string.format("%03d", tonumber(take_text))
      if reaper_ver > 7.28 then
        SNM_SetStringConfigVar("recfile_wildcards", session_dir .. session_suffix
          .. "$tracknameornumber_T" .. padded_take_text)
      else
        SNM_SetStringConfigVar("recfile_wildcards", session_dir .. session_suffix
          .. "$track_T" .. padded_take_text)
      end
      rec_name_set = true
    end

    if laststate ~= playstate then
      laststate = playstate
      draw(playstate)
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

      draw(playstate)

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

  if old_height ~= gfx.h or old_width ~= gfx.w then
    draw(playstate)
    old_height = gfx.h
    old_width = gfx.w
  end


  local quit_response
  local key = gfx.getchar()
  if key == -1 and (playstate == 5 or playstate == 6) then
    quit_response = MB("Are you sure you want to quit the take counter window during a recording?", "Take Counter", 4)
  end

  if quit_response == 7 then
    local _, x, y, _, _ = gfx.dock(-1, 1, 1, 1, 1)
    gfx.init("Take Counter", gfx.w, gfx.h, 0, x, y)
    defer(main)
  elseif quit_response == nil and key ~= -1 then
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
  Main_OnCommand(24800, 0) -- clear any section override
  SetToggleCommandState(1, take_counter, 0)
  local _, x, y, _, _ = gfx.dock(-1, 1, 1, 1, 1)
  local pos = x .. "," .. y
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
  local base_width = 300
  local base_height = 125

  local scale_x = gfx.w / base_width
  local scale_y = gfx.h / base_height
  local scale = math.min(scale_x, scale_y)

  gfx.setfont(1, "Arial", 90 * scale, 98)
  gfx.set(0.5, 0.8, 0.5, 1)
  take_width, take_height = gfx.measurestr(take_text)
  session_text = session

  if playstate == 0 or playstate == 1 then
    gfx.x = (gfx.w - take_width) / 2
    gfx.y = (gfx.h - take_height) / 4
    gfx.drawstr(take_text)

    if session_text == "" and take_text == 1 then
      gfx.setfont(1, "Arial", 15 * scale, 98)
      session_text = "Right-click to set session name"
      take_height = take_height + 75
    else
      gfx.setfont(1, "Arial", 25 * scale, 98)
    end
    local session_width, session_height = gfx.measurestr(session_text)
    gfx.x = (gfx.w - session_width) / 2
    gfx.y = ((gfx.h - session_height + take_height / 3) / 2)
    gfx.set(0.8, 0.8, 0.9, 1)
    gfx.drawstr("\n" .. session_text)

    SetThemeColor("ts_lane_bg", -1)
    SetThemeColor("marker_lane_bg", -1)
    SetThemeColor("region_lane_bg", -1)

    if start_time or end_time or duration then
      gfx.setfont(1, "Arial", 15 * scale, 98)
      gfx.set(0.337, 0.627, 0.827, 1)
      gfx.x = gfx.w - (60 * scale)
      gfx.y = 15 * scale
      if start_time and end_time then
        gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. end_text .. end_next_day)
      elseif start_time and calc_end_time then
        gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. calc_end_time .. end_next_day)
      elseif start_time then
        gfx.drawstr("Start\n" .. start_text .. start_next_day)
      elseif end_time then
        gfx.drawstr("End\n" .. end_text .. end_next_day)
      else
        gfx.drawstr("Dur.\n" .. duration_text)
      end
    end
  elseif playstate == 5 or playstate == 6 then
    if playstate == 6 then
      gfx.set(1, 1, 0.5, 1)
      local pause_y = (gfx.h - take_height) / 4 + (take_height / 2) - (50 * scale) / 2
      gfx.rect(30 * scale, pause_y, 15 * scale, 50 * scale)
      gfx.rect(55 * scale, pause_y, 15 * scale, 50 * scale)
      SetThemeColor("ts_lane_bg", recpause_color)
      SetThemeColor("marker_lane_bg", recpause_color)
      SetThemeColor("region_lane_bg", recpause_color)
    else
      gfx.set(1, 0.5, 0.5, 1)
      local circle_y = (gfx.h - take_height) / 4 + (take_height / 2)
      gfx.circle(50 * scale, circle_y, 20 * scale, 1)
      SetThemeColor("ts_lane_bg", rec_color)
      SetThemeColor("marker_lane_bg", rec_color)
      SetThemeColor("region_lane_bg", rec_color)
    end

    gfx.x = (gfx.w - take_width) / 2
    gfx.y = (gfx.h - take_height) / 4
    gfx.drawstr(take_text)

    gfx.setfont(1, "Arial", 25 * scale, 98)
    gfx.set(0.8, 0.8, 0.9, 1)
    local session_width, session_height = gfx.measurestr(session_text)
    gfx.x = (gfx.w - session_width) / 2
    gfx.y = ((gfx.h - session_height + take_height / 3) / 2)
    gfx.drawstr("\n" .. session_text)

    if start_time and start_time > current_time then
      set_via_right_click = false
    end

    if set_via_right_click then
      if start_time or end_time or duration then
        gfx.setfont(1, "Arial", 15 * scale, 98)
        gfx.set(0.337, 0.627, 0.827, 1)
        gfx.x = gfx.w - (60 * scale)
        gfx.y = 15 * scale
        if start_time and end_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. end_text .. end_next_day)
        elseif start_time and calc_end_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day .. "\nEnd\n" .. calc_end_time .. end_next_day)
        elseif start_time then
          gfx.drawstr("Start\n" .. start_text .. start_next_day)
        elseif end_time then
          gfx.drawstr("End\n" .. end_text .. end_next_day)
        else
          gfx.drawstr("Dur.\n" .. duration_text)
        end
      end
    end
  end
  UpdateTimeline()
end

---------------------------------------------------------------------

function marker_actions()
  if marker_actions_running then return end   -- do not start twice
  marker_actions_running = true

  local markers = {}
  local next_idx = 1
  local tolerance = 0.05   -- seconds (50 ms)

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

  scan_markers()   -- initial scan

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
    if not marker_actions_running then return end     -- allow external stop

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

-- profiler.attachToWorld()
-- profiler.run()

gfx.init("Take Counter", win.width, win.height, 0, win.xpos, win.ypos)
atexit(clean_up)
main()
