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

local main, get_take_count, clean_up, parse_time, parse_duration, check_time, remove_markers_by_name
local seconds_to_hhmm, find_first_rec_enabled_parent, draw, marker_actions
local get_item_color, pastel_color, get_color_table, extract_take_from_filename
local disarm_all_tracks, extract_session_from_filename, is_folder_parent_or_child
local get_folder_arm_status, find_mixer_for_track, is_mixer_disabled, check_prefs
local load_item_rank_and_notes, save_item_rank_and_notes, rgba_to_native, update_take_name
local apply_rank_and_notes_to_items, store_last_recorded_guids, apply_rank_and_notes_by_guids
local apply_rank_and_notes_to_item

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
  MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
  return
end

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
  MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
  return
end

local system = GetOS()
local is_mac = string.find(system, "^OSX") or string.find(system, "^macOS")
local ctrl_key = is_mac and "Cmd" or "Ctrl"
local alt_key = is_mac and "Opt" or "Alt"

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
  MB("Please create a ReaClassical project via " .. ctrl_key
    .. "+N to use this function.", "ReaClassical Error", 0)
  return
end

local auto_color_pref = 0
local ranking_color_pref = 0

function check_prefs()
  local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
  if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[5] then auto_color_pref = tonumber(table[5]) or 0 end
    if table[6] then ranking_color_pref = tonumber(table[6]) or 0 end
  end
end

check_prefs()

set_action_options(2)

---------------------------------------------------------------------

local iterated_filenames = false
local added_take_number = false
local rec_name_set = false
local take_count, take_text, session_text
local _, prev_recfilename_value = get_config_var_string("recfile_wildcards")
local separator = package.config:sub(1, 1);

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
local current_time = os.time()

package.path       = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui        = require 'imgui' '0.10'

-- Default window settings
local win          = {
  width = 350,
  height = 440,
  xpos = nil,
  ypos = nil
}

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
local stop_cursor_pos = nil

local F9_command = NamedCommandLookup("_RS25887d941a72868731ba67ccb1abcbacb587e006")
local increment_take_cmd = NamedCommandLookup("_RSbb6037bb7fbe86a2d5a3c24cda322cf422e37612")
local next_section_cmd = NamedCommandLookup("_RSf1714b103174d14151f1b058f4defa9c6f10e1a1")

-- ImGui Context
local ctx = ImGui.CreateContext('Record Panel')
local large_font = ImGui.CreateFont('Arial', 120)
local medium_font = ImGui.CreateFont('Arial', 50)
local small_font = ImGui.CreateFont('Arial', 25)
ImGui.Attach(ctx, large_font)
ImGui.Attach(ctx, medium_font)
ImGui.Attach(ctx, small_font)

local open = true

-- Popup state variables (persisted across frames)
local popup_take_text = nil
local popup_session_text = nil
local popup_reset = nil
local popup_start_text = nil
local popup_end_text = nil
local popup_duration_text = nil

-- Recording rank and notes
local recording_rank = "" -- Default to "No Rank"
local recording_note = ""

-- Track the item being edited when stopped
local editing_item = nil
local last_selected_item = nil
local take_extracted = false    -- Track if current take_text was extracted from take name
local session_extracted = false -- Track if current session was extracted from take name

-- Set true when a recording finishes; only cleared when a new recording starts.
-- When true and no item is selected, rank/notes changes target the last recorded items
-- by GUID (stored in ProjExtState "LastRecordedItemGUIDs").
local had_recent_recording = false

-- NEW: "Record Takes Horizontally" checkbox state (Vertical workflow only)
-- Persisted in ProjExtState so it survives panel restarts.
local record_takes_horizontally = false
do
  local _, rth_val = GetProjExtState(0, "ReaClassical", "RecordTakesHorizontally")
  record_takes_horizontally = (rth_val == "1")
end

-- Rank color options (matching SAI marker manager and notes app)
local RANKS = {
  { name = "Excellent",     rgba = 0x39FF1499, prefix = "Excellent" },
  { name = "Very Good",     rgba = 0x32CD3299, prefix = "Very Good" },
  { name = "Good",          rgba = 0x00AD8399, prefix = "Good" },
  { name = "OK",            rgba = 0xFFFFAA99, prefix = "OK" },
  { name = "Below Average", rgba = 0xFFBF0099, prefix = "Below Average" },
  { name = "Poor",          rgba = 0xFF753899, prefix = "Poor" },
  { name = "Unusable",      rgba = 0xDC143C99, prefix = "Unusable" },
  { name = "False Start",   rgba = 0x2A2A2AFF, prefix = "False Start" },
  { name = "No Rank",       rgba = 0x00000000, prefix = "" }
}

---------------------------------------------------------------------
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
      session_dir = ""
      session_suffix = ""
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

      -- Apply rank and notes to recorded items and store their GUIDs for later re-targeting
      local apply_pos = stop_cursor_pos or GetCursorPosition()
      apply_rank_and_notes_to_items(apply_pos)
      store_last_recorded_guids(apply_pos)
      stop_cursor_pos = nil

      -- Mark that we just finished a recording so the UI can retarget those items by GUID.
      -- recording_rank/note are intentionally NOT reset here so the dropdown continues to
      -- reflect whatever rank was set during recording.
      had_recent_recording = true
      editing_item = nil
    end

    -- When stopped, check for selected item changes
    if playstate == 0 then
      local selected_item = GetSelectedMediaItem(0, 0)

      -- Validate that editing_item still exists
      if editing_item and not ValidatePtr2(0, editing_item, "MediaItem*") then
        editing_item = nil
      end

      -- If selection changed, save previous and load new
      if selected_item ~= last_selected_item then
        -- Save changes to previously edited item ONLY if something changed
        if editing_item and editing_item ~= selected_item then
          local _, stored_rank = GetSetMediaItemInfo_String(editing_item, "P_EXT:item_rank", "", false)
          local _, stored_notes = GetSetMediaItemInfo_String(editing_item, "P_NOTES", "", false)
          if recording_rank ~= stored_rank or recording_note ~= stored_notes then
            save_item_rank_and_notes(editing_item, recording_rank, recording_note)
          end
        end

        -- Load new item's data
        if selected_item and ValidatePtr2(0, selected_item, "MediaItem*") then
          load_item_rank_and_notes(selected_item)
          editing_item = selected_item

          -- Try to extract take number from take name
          local extracted_take = extract_take_from_filename(selected_item)
          if extracted_take then
            take_text = extracted_take
            take_extracted = true
          else
            if not iterated_filenames then
              take_text = get_take_count(session) + 1
            else
              take_text = take_count + 1
            end
            take_extracted = false
          end

          -- Try to extract session name from take name
          local extracted_session = extract_session_from_filename(selected_item)
          if extracted_session then
            session_text = extracted_session
            session_extracted = true
          else
            session_text = session
            session_extracted = false
          end
        else
          -- No item selected - restore take count and session.
          editing_item = nil
          take_extracted = false
          session_extracted = false
          session_text = session
          -- If returning to last-recording mode, restore rank/notes from the stored GUIDs
          -- so the dropdown reflects the last recording, not the previously selected item.
          if had_recent_recording then
            local _, guid_str = GetProjExtState(0, "ReaClassical", "LastRecordedItemGUIDs")
            if guid_str and guid_str ~= "" then
              local first_guid = guid_str:match("([^,]+)")
              if first_guid then
                local total_items = CountMediaItems(0)
                for i = 0, total_items - 1 do
                  local item = GetMediaItem(0, i)
                  local _, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
                  if guid == first_guid then
                    load_item_rank_and_notes(item)
                    break
                  end
                end
              end
            end
          end
          if not iterated_filenames then
            take_text = get_take_count(session) + 1
          else
            take_text = take_count + 1
          end
        end

        last_selected_item = selected_item
      end
    end

    if not iterated_filenames and not editing_item then
      take_text = get_take_count(session) + 1
    elseif not editing_item then
      take_text = take_count + 1
    end

    -- Reset session_text if not editing an item
    if not editing_item and not session_extracted then
      session_text = session
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

      if editing_item and ValidatePtr2(0, editing_item, "MediaItem*") then
        -- Save pending edits before recording starts
        save_item_rank_and_notes(editing_item, recording_rank, recording_note)
        editing_item = nil
        last_selected_item = nil
        session_extracted = false
        session_text = session
      end

      -- Starting a new recording clears last-recording targeting mode and stored GUIDs
      had_recent_recording = false
      SetProjExtState(0, "ReaClassical", "LastRecordedItemGUIDs", "")
      recording_rank = ""
      recording_note = ""

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
    stop_cursor_pos = GetCursorPosition()
  end

  -- Draw ImGui window
  draw(playstate)

  if open then
    defer(main)
  end
end

---------------------------------------------------------------------

function load_item_rank_and_notes(item)
  if not item then
    recording_rank = ""
    recording_note = ""
    return
  end

  local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
  if rank_str ~= "" then
    local rank_num = tonumber(rank_str)
    recording_rank = (rank_num and rank_num >= 1 and rank_num <= 9) and tostring(rank_num) or ""
  else
    recording_rank = ""
  end

  local _, note = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
  recording_note = note
end

---------------------------------------------------------------------

function save_item_rank_and_notes(item, rank, note)
  if not item then return end

  local _, colorized = GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", false)
  local is_colorized = (colorized == "y")

  GetSetMediaItemInfo_String(item, "P_EXT:item_rank", rank, true)

  local color_to_use
  if rank ~= "" then
    if is_colorized then
      GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)
    end
    if ranking_color_pref == 0 then
      local rank_index = tonumber(rank)
      if rank_index and RANKS[rank_index] then
        color_to_use = rgba_to_native(RANKS[rank_index].rgba) | 0x1000000
      else
        color_to_use = get_item_color(item)
      end
    end
  else
    if is_colorized then
      GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)
    end
    if auto_color_pref == 0 then
      local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
      if workflow == "Horizontal" then
        local _, stored_take_num = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
        if stored_take_num ~= "" then
          local take_num = tonumber(stored_take_num)
          if take_num then
            color_to_use = pastel_color(take_num - 1)
          else
            color_to_use = get_item_color(item)
          end
        else
          color_to_use = get_item_color(item)
        end
      else
        color_to_use = get_item_color(item)
      end
    else
      color_to_use = 0
    end
  end

  if color_to_use then
    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)
    UpdateItemInProject(item)
  end

  update_take_name(item, rank)

  GetSetMediaItemInfo_String(item, "P_NOTES", note, true)

  local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
  if group_id ~= 0 then
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
      local track = GetTrack(0, i)
      local item_count = CountTrackMediaItems(track)
      for j = 0, item_count - 1 do
        local current_item = GetTrackMediaItem(track, j)
        local current_group_id = GetMediaItemInfo_Value(current_item, "I_GROUPID")
        if current_group_id == group_id and current_item ~= item then
          GetSetMediaItemInfo_String(current_item, "P_EXT:item_rank", rank, true)
          GetSetMediaItemInfo_String(current_item, "P_NOTES", note, true)

          local _, grouped_colorized = GetSetMediaItemInfo_String(current_item, "P_EXT:colorized", "", false)
          local grouped_is_colorized = (grouped_colorized == "y")

          local grouped_color
          if rank ~= "" then
            if grouped_is_colorized then
              GetSetMediaItemInfo_String(current_item, "P_EXT:colorized", "", true)
            end
            if ranking_color_pref == 0 then
              local rank_index = tonumber(rank)
              if rank_index and RANKS[rank_index] then
                grouped_color = rgba_to_native(RANKS[rank_index].rgba) | 0x1000000
              else
                grouped_color = get_item_color(current_item)
              end
            end
          else
            if grouped_is_colorized then
              GetSetMediaItemInfo_String(current_item, "P_EXT:colorized", "", true)
            end
            if auto_color_pref == 0 then
              local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
              if workflow == "Horizontal" then
                local _, stored_take_num = GetSetMediaItemInfo_String(current_item, "P_EXT:item_take_num", "", false)
                if stored_take_num ~= "" then
                  local take_num = tonumber(stored_take_num)
                  if take_num then
                    grouped_color = pastel_color(take_num - 1)
                  else
                    grouped_color = get_item_color(current_item)
                  end
                else
                  grouped_color = get_item_color(current_item)
                end
              else
                grouped_color = get_item_color(current_item)
              end
            else
              grouped_color = 0
            end
          end

          if grouped_color then
            SetMediaItemInfo_Value(current_item, "I_CUSTOMCOLOR", grouped_color)
            UpdateItemInProject(current_item)
          end

          update_take_name(current_item, rank)
        end
      end
    end
  end

  UpdateArrange()
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
  if editing_item and ValidatePtr2(0, editing_item, "MediaItem*") then
    save_item_rank_and_notes(editing_item, recording_rank, recording_note)
  end

  Main_OnCommand(24800, 0) -- clear any section override
  SetToggleCommandState(1, take_counter, 0)

  local x, y = ImGui.GetWindowPos(ctx)
  local w, h = ImGui.GetWindowSize(ctx)
  local pos = x .. "," .. y .. "," .. w .. "," .. h
  SetProjExtState(0, "ReaClassical", "TakeCounterPosition", pos)

  SNM_SetStringConfigVar("recfile_wildcards", prev_recfilename_value)
  SetThemeColor("ts_lane_bg", -1)
  SetThemeColor("marker_lane_bg", -1)
  SetThemeColor("region_lane_bg", -1)
  remove_markers_by_name("!1013")
  remove_markers_by_name("!" .. F9_command)
  disarm_all_tracks()
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
      Main_OnCommand(1013, 0)
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

function is_folder_parent_or_child()
  local selected_track = GetSelectedTrack(0, 0)
  if not selected_track then
    return false
  end

  local depth = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

  if depth == 1 then
    return true
  end

  local track_idx = GetMediaTrackInfo_Value(selected_track, "IP_TRACKNUMBER") - 1

  for i = track_idx - 1, 0, -1 do
    local track = GetTrack(0, i)
    local track_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

    if track_depth == 1 then
      return true
    elseif track_depth < 0 then
      break
    end
  end

  return false
end

---------------------------------------------------------------------

function draw(playstate)
  if win.xpos and win.ypos then
    ImGui.SetNextWindowPos(ctx, win.xpos, win.ypos, ImGui.Cond_FirstUseEver)
  end
  ImGui.SetNextWindowSize(ctx, win.width, win.height, ImGui.Cond_Appearing)
  ImGui.SetNextWindowSizeConstraints(ctx, win.width, win.height, 3000, 3500)

  local visible, should_close = ImGui.Begin(ctx, 'Record Panel', true,
    ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse)

  if not visible then
    ImGui.End(ctx)
    return
  end

  if should_close == false then
    if playstate == 5 or playstate == 6 then
      local choice = MB("Are you sure you want to quit the take counter window during a recording?",
        "Take Counter", 4)
      if choice == 6 then
        open = false
      end
    else
      open = false
    end
  end

  local draw_list = ImGui.GetWindowDrawList(ctx)
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  local win_x, win_y = ImGui.GetWindowPos(ctx)

  local base_width = win.width
  local base_height = win.height
  local scale_x = win_w / base_width
  local scale_y = win_h / base_height
  local scale = math.min(scale_x, scale_y)

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

  -- Draw time info at top
  if (playstate == 0 or playstate == 1 or (playstate == 5 or playstate == 6) and set_via_right_click) then
    if start_time or end_time or duration then
      ImGui.PushFont(ctx, small_font, 15 * scale)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xD3A056FF)

      local time_text
      if start_time and end_time then
        time_text = "Start: " .. start_text .. start_next_day .. "  |  End: " .. end_text .. end_next_day
      elseif start_time and calc_end_time then
        time_text = "Start: " .. start_text .. start_next_day .. "  |  End: " .. calc_end_time .. end_next_day
      elseif start_time then
        time_text = "Start: " .. start_text .. start_next_day
      elseif end_time then
        time_text = "End: " .. end_text .. end_next_day
      else
        time_text = "Duration: " .. duration_text
      end

      local time_w = ImGui.CalcTextSize(ctx, time_text)
      ImGui.SetCursorPos(ctx, (win_w - time_w) / 2, 45 * scale)
      ImGui.Text(ctx, time_text)

      ImGui.PopStyleColor(ctx)
      ImGui.PopFont(ctx)
    end
  end

  -- Draw take number (large font)
  ImGui.PushFont(ctx, large_font, 175 * scale)
  local take_str = tostring(take_text)
  local text_w, text_h = ImGui.CalcTextSize(ctx, take_str)
  local take_x = (win_w - text_w) / 2
  local take_y = (win_h - text_h) / 3.75
  ImGui.SetCursorPos(ctx, take_x, take_y)

  local take_color
  if playstate == 0 and editing_item and take_extracted then
    take_color = 0x4B9CD3FF -- Carolina blue: editing a selected item
  elseif playstate == 6 then
    take_color = 0xFFFF7FFF -- Yellow: paused
  elseif playstate == 5 then
    take_color = 0xFF7F7FFF -- Red: recording
  else
    take_color = 0x7FCC7FFF -- Green: stopped/playing
  end

  ImGui.PushStyleColor(ctx, ImGui.Col_Text, take_color)
  ImGui.Text(ctx, take_str)
  ImGui.PopStyleColor(ctx)
  ImGui.PopFont(ctx)

  -- Recording indicator
  if playstate == 5 or playstate == 6 then
    local indicator_x = win_x + 50 * scale
    local indicator_y = win_y + take_y + (text_h / 2)

    if playstate == 6 then
      local bar_height = 50 * scale
      ImGui.DrawList_AddRectFilled(draw_list,
        indicator_x - 20 * scale, indicator_y - bar_height / 2,
        indicator_x - 5 * scale, indicator_y + bar_height / 2,
        0xFFFF7FFF)
      ImGui.DrawList_AddRectFilled(draw_list,
        indicator_x + 5 * scale, indicator_y - bar_height / 2,
        indicator_x + 20 * scale, indicator_y + bar_height / 2,
        0xFFFF7FFF)
    else
      ImGui.DrawList_AddCircleFilled(draw_list,
        indicator_x, indicator_y,
        20 * scale,
        0xFF7F7FFF)
    end
  end

  -- Invisible button over take number for click detection
  ImGui.SetCursorPos(ctx, take_x, take_y)
  if ImGui.InvisibleButton(ctx, "take_number_btn", text_w, text_h) then
    laststate = nil
    local choice = MB("Recalculate take count?", "ReaClassical Take Counter", 4)
    if choice == 6 then
      take_text = get_take_count(session) + 1
      rec_name_set = false
    end
  end

  -- Session name
  local display_session = session_text
  local use_small = false

  if display_session == "" and take_count == 0 then
    display_session = "Right-click for options"
  end

  if use_small then
    ImGui.PushFont(ctx, small_font, 12 * scale)
  else
    ImGui.PushFont(ctx, medium_font, 25 * scale)
  end
  local session_w, session_h = ImGui.CalcTextSize(ctx, display_session)
  ImGui.SetCursorPos(ctx, (win_w - session_w) / 2, take_y + text_h * 0.95)

  if playstate == 0 and editing_item and session_extracted then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x4B9CD3FF) -- Carolina blue
  else
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xE6CCCCFF) -- Light purple
  end
  ImGui.Text(ctx, display_session)
  ImGui.PopStyleColor(ctx)
  ImGui.PopFont(ctx)

  -- Transport buttons
  local button_width = 60 * scale
  local button_height = 25 * scale
  local button_spacing = 5 * scale
  local total_button_width = (button_width * 4) + (button_spacing * 3)
  local buttons_start_x = (win_w - total_button_width) / 2

  local button_y = take_y + text_h + (10 * scale) + session_h + (5 * scale)

  -- "Record Takes Horizontally" checkbox (Vertical workflow only), drawn above button row
  local _, current_workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  if current_workflow == "Vertical" then
    ImGui.SetCursorPos(ctx, buttons_start_x, button_y - (25 * scale))
    ImGui.PushFont(ctx, small_font, 13 * scale)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xCCCCCCFF)
    local rv_cb, new_rth = ImGui.Checkbox(ctx, "Record takes horizontally", record_takes_horizontally)
    if rv_cb then
      record_takes_horizontally = new_rth
      SetProjExtState(0, "ReaClassical", "RecordTakesHorizontally", new_rth and "1" or "0")
    end
    ImGui.PopStyleColor(ctx)
    ImGui.PopFont(ctx)
    -- button_y = button_y + (20 * scale)
  end

  ImGui.SetCursorPos(ctx, buttons_start_x, button_y)

  local any_armed = false
  local selected_track_armed = false
  local num_tracks = CountTracks(0)
  local selected_track = GetSelectedTrack(0, 0)
  local is_valid_selection = is_folder_parent_or_child()

  local folder_status = nil
  local is_recording = (playstate == 5 or playstate == 6)

  if selected_track and not is_recording then
    local depth = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")
    if depth == 1 then
      folder_status = get_folder_arm_status(selected_track)
    end
  end

  for i = 0, num_tracks - 1 do
    local track = GetTrack(0, i)
    if GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
      any_armed = true
      if selected_track and track == selected_track then
        selected_track_armed = true
      end
    end
  end

  local rec_button_label
  local show_select_message = false
  local button_disabled = false

  if is_recording then
    rec_button_label = "Stop"
  elseif not selected_track and not any_armed then
    rec_button_label = "Arm"
    show_select_message = true
    button_disabled = true
  elseif selected_track and not is_valid_selection then
    rec_button_label = "Arm"
    button_disabled = true
  elseif selected_track and not selected_track_armed then
    rec_button_label = "Arm"
  elseif any_armed then
    rec_button_label = "Rec"
  else
    rec_button_label = "Arm"
  end

  if button_disabled then
    ImGui.BeginDisabled(ctx, true)
  end

  if ImGui.Button(ctx, rec_button_label, button_width, button_height) then
    check_prefs()
    if rec_button_label == "Rec" and not selected_track and any_armed then
      for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
          SetOnlyTrackSelected(track)
          break
        end
      end
    end
    Main_OnCommand(F9_command, 0)
  end
  ImGui.SetItemTooltip(ctx, rec_button_label == "Rec" and "Start recording (F9)" or
    rec_button_label == "Stop" and "Stop recording (F9)" or "Arm selected folder for recording (F9)")

  if button_disabled then
    ImGui.EndDisabled(ctx)
  end

  -- Warning indicator to the left of rec button
  if not is_recording and folder_status and (folder_status == "partial" or folder_status == "has_disabled") then
    local warning_x = buttons_start_x - (10 * scale)
    ImGui.SetCursorPos(ctx, warning_x, button_y)
    ImGui.PushFont(ctx, medium_font, 25 * scale)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAA00FF)
    ImGui.Text(ctx, "!")
    ImGui.PopStyleColor(ctx)
    ImGui.PopFont(ctx)

    if ImGui.IsItemHovered(ctx) then
      local tooltip_text = ""
      if folder_status == "has_disabled" then
        tooltip_text = "Some tracks disabled in Mission Control"
      end
      ImGui.SetTooltip(ctx, tooltip_text)
    end
  end

  -- Status message below rec button (maintains layout height)
  ImGui.SetCursorPos(ctx, buttons_start_x, button_y + button_height + (5 * scale))
  if not editing_item and not had_recent_recording then
    if show_select_message then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAAAAFF)
      ImGui.TextWrapped(ctx, "Select a parent track to arm")
      ImGui.PopStyleColor(ctx)
    elseif selected_track and not is_valid_selection then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAAAAFF)
      ImGui.TextWrapped(ctx, "Select a folder parent or child")
      ImGui.PopStyleColor(ctx)
    else
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00000000)
      ImGui.TextWrapped(ctx, "Select a parent track to arm")
      ImGui.PopStyleColor(ctx)
    end
  else
    -- Invisible placeholder to maintain spacing
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x00000000)
    ImGui.TextWrapped(ctx, "Select a parent track to arm")
    ImGui.PopStyleColor(ctx)
  end

  -- Pause / Disarm button
  ImGui.SetCursorPos(ctx, buttons_start_x + button_width + button_spacing, button_y)
  if is_recording then
    if ImGui.Button(ctx, "Pause", button_width, button_height) then
      Main_OnCommand(1008, 0)
    end
    ImGui.SetItemTooltip(ctx, "Pause/unpause recording (" .. ctrl_key .. "+F9)")
  elseif any_armed then
    if ImGui.Button(ctx, "Disarm", button_width, button_height) then
      disarm_all_tracks()
    end
    ImGui.SetItemTooltip(ctx, "Disarm all tracks")
  else
    ImGui.BeginDisabled(ctx, true)
    ImGui.Button(ctx, "Pause", button_width, button_height)
    ImGui.EndDisabled(ctx)
    ImGui.SetItemTooltip(ctx, "Pause/unpause recording (" .. ctrl_key .. "+F9)")
  end

  -- Increment Take button
  ImGui.SetCursorPos(ctx, buttons_start_x + (button_width + button_spacing) * 2, button_y)
  if not is_recording then ImGui.BeginDisabled(ctx, true) end
  if ImGui.Button(ctx, "+Take", button_width, button_height) then
    Main_OnCommand(increment_take_cmd, 0)
  end
  if record_takes_horizontally then
  ImGui.SetItemTooltip(ctx, "Split and increment take number (Shift+F9)")
  else
  ImGui.SetItemTooltip(ctx, "Move to next folder and start new take (Shift+F9)")
  end
  if not is_recording then ImGui.EndDisabled(ctx) end

  -- Next section button
  ImGui.SetCursorPos(ctx, buttons_start_x + (button_width + button_spacing) * 3, button_y)
  local is_stopped = (playstate == 0)
  if not is_stopped then ImGui.BeginDisabled(ctx, true) end
  if ImGui.Button(ctx, "Next", button_width, button_height) then
    Main_OnCommand(next_section_cmd, 0)
  end
  ImGui.SetItemTooltip(ctx, "Move to Next Recording Section (" .. alt_key .. "+F9)")
  if not is_stopped then ImGui.EndDisabled(ctx) end

  -- Rank and Notes section
  local rank_y = button_y + button_height + (30 * scale)

  -- Context indicator: which items rank/notes changes will target
  if playstate == 0 then
    ImGui.SetCursorPos(ctx, buttons_start_x, rank_y - (18 * scale))
    if editing_item then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x4B9CD3FF)
      ImGui.Text(ctx, "Editing Selected Item")
      ImGui.PopStyleColor(ctx)
    elseif had_recent_recording then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xAACC88FF)
      ImGui.Text(ctx, "Editing Last Recording")
      ImGui.PopStyleColor(ctx)
    end
  end

  -- Rank dropdown
  ImGui.SetCursorPos(ctx, buttons_start_x, rank_y)

  local display_index = recording_rank == "" and 9 or tonumber(recording_rank)

  ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, RANKS[display_index].rgba)
  ImGui.SetNextItemWidth(ctx, total_button_width / 2)

  local rank_id = editing_item and tostring(editing_item):sub(-8) or "recording"
  if ImGui.BeginCombo(ctx, "##rank_" .. rank_id, RANKS[display_index].name) then
    for i, rank in ipairs(RANKS) do
      ImGui.PushStyleColor(ctx, ImGui.Col_Header, rank.rgba)
      local is_selected = (display_index == i)
      if ImGui.Selectable(ctx, rank.name, is_selected) then
        recording_rank = (i == 9) and "" or tostring(i)
        if playstate == 0 and editing_item then
          -- Selected item mode: save directly to that item
          save_item_rank_and_notes(editing_item, recording_rank, recording_note)
        elseif playstate == 0 and had_recent_recording then
          -- Last-recording mode: apply to stored GUIDs regardless of cursor/selection
          apply_rank_and_notes_by_guids()
        end
      end
      if is_selected then
        ImGui.SetItemDefaultFocus(ctx)
      end
      ImGui.PopStyleColor(ctx)
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.PopStyleColor(ctx)

  -- Notes input
  local note_y = rank_y + (25 * scale)
  ImGui.SetCursorPos(ctx, buttons_start_x, note_y)
  local note_height = 40 * scale

  local note_id = editing_item and tostring(editing_item):sub(-8) or "recording"
  local rv, val = ImGui.InputTextMultiline(ctx, "##note_" .. note_id, recording_note, total_button_width, note_height)
  if rv then
    recording_note = val
    if playstate == 0 and editing_item then
      -- Selected item mode: save directly to that item
      save_item_rank_and_notes(editing_item, recording_rank, recording_note)
    elseif playstate == 0 and had_recent_recording then
      -- Last-recording mode: apply to stored GUIDs regardless of cursor/selection
      apply_rank_and_notes_by_guids()
    end
  end

  -- Right-click popup
  if ImGui.IsWindowHovered(ctx) and ImGui.IsMouseClicked(ctx, 1) then
    popup_take_text = take_text
    popup_session_text = session
    popup_reset = reset
    popup_start_text = start_text
    popup_end_text = end_text
    popup_duration_text = duration_text
    ImGui.OpenPopup(ctx, "settings_popup")
  end

  if ImGui.BeginPopup(ctx, "settings_popup") then
    marker_actions_running = false
    laststate = nil

    ImGui.Text(ctx, "Take Counter Settings")
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    if ImGui.BeginTable(ctx, "settings_table", 2, ImGui.TableFlags_SizingStretchProp) then
      ImGui.TableSetupColumn(ctx, "labels", ImGui.TableColumnFlags_WidthFixed, 230)
      ImGui.TableSetupColumn(ctx, "inputs", ImGui.TableColumnFlags_WidthFixed, 250)

      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, "Allow Take Number Override:")
      ImGui.TableSetColumnIndex(ctx, 1)
      local override_checked = (tonumber(popup_reset) == 1)
      local rv, val = ImGui.Checkbox(ctx, "##override", override_checked)
      if rv then popup_reset = val and 1 or 0 end

      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, "Set Take Number:")
      ImGui.TableSetColumnIndex(ctx, 1)
      local take_disabled = (tonumber(popup_reset) ~= 1)
      if take_disabled then ImGui.BeginDisabled(ctx, true) end
      ImGui.SetNextItemWidth(ctx, -1)
      local rv, val = ImGui.InputInt(ctx, "##take", popup_take_text)
      if rv and not take_disabled then popup_take_text = val end
      if take_disabled then ImGui.EndDisabled(ctx) end

      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, "Session Name:")
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.SetNextItemWidth(ctx, -1)
      local rv, val = ImGui.InputText(ctx, "##session", popup_session_text, 256)
      if rv then popup_session_text = val end

      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, "Recording Start Time (HH:MM):")
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.SetNextItemWidth(ctx, 80)
      local rv, val = ImGui.InputText(ctx, "##start", popup_start_text, 256)
      if rv then popup_start_text = val end

      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, "Recording End Time (HH:MM):")
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.SetNextItemWidth(ctx, 80)
      local rv, val = ImGui.InputText(ctx, "##end", popup_end_text, 256)
      if rv then popup_end_text = val end

      ImGui.TableNextRow(ctx)
      ImGui.TableSetColumnIndex(ctx, 0)
      ImGui.AlignTextToFramePadding(ctx)
      ImGui.Text(ctx, "Duration (HH:MM):")
      ImGui.TableSetColumnIndex(ctx, 1)
      ImGui.SetNextItemWidth(ctx, 80)
      local rv, val = ImGui.InputText(ctx, "##duration", popup_duration_text, 256)
      if rv then popup_duration_text = val end

      ImGui.EndTable(ctx)
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    if ImGui.Button(ctx, "Apply", 120, 0) then
      local session_changed = (popup_session_text ~= session)

      take_text = popup_take_text
      start_text = popup_start_text
      end_text = popup_end_text
      duration_text = popup_duration_text
      reset = popup_reset

      start_next_day = ""
      end_next_day = ""

      if start_text ~= "" then
        start_time = parse_time(start_text)
        if start_time and start_time <= current_time then
          start_time = start_time + 24 * 60 * 60
          start_next_day = "*"
        end
      else
        start_time = nil
      end

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

      if duration_text ~= "" then
        duration = parse_duration(duration_text)
        if duration and start_time then
          calc_end_time = seconds_to_hhmm(start_time + duration)
        end
      else
        duration = nil
        calc_end_time = nil
      end

      if popup_session_text and popup_session_text ~= "" then
        session = popup_session_text
        session_dir = session .. separator
        session_suffix = session .. "_"
      else
        session, session_dir, session_suffix = "", "", ""
      end

      if session_changed then
        iterated_filenames = false
        take_text = get_take_count(session) + 1
        rec_name_set = false
        session_text = session
        session_extracted = false
      else
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
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Cancel", 120, 0) then
      ImGui.CloseCurrentPopup(ctx)
    end

    ImGui.EndPopup(ctx)
  end

  -- Keyboard shortcuts
  if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Enter, false) then
    if ImGui.GetKeyMods(ctx) & ImGui.Mod_Ctrl ~= 0 then
      open = false
    end
  end

  if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_F9, false) then
    local mods = ImGui.GetKeyMods(ctx)

    if mods & ImGui.Mod_Shift ~= 0 then
      if is_recording then
        Main_OnCommand(increment_take_cmd, 0)
      end
    elseif mods & ImGui.Mod_Alt ~= 0 then
      if is_stopped then
        Main_OnCommand(next_section_cmd, 0)
      end
    elseif mods & ImGui.Mod_Ctrl ~= 0 then
      if is_recording then
        Main_OnCommand(1008, 0)
      end
    else
      if not button_disabled then
        if rec_button_label == "Rec" and not selected_track and any_armed then
          for i = 0, num_tracks - 1 do
            local track = GetTrack(0, i)
            if GetMediaTrackInfo_Value(track, "I_RECARM") == 1 then
              SetOnlyTrackSelected(track)
              break
            end
          end
        end
        check_prefs()
        Main_OnCommand(F9_command, 0)
      end
    end
  end

  UpdateTimeline()

  ImGui.End(ctx)
end

---------------------------------------------------------------------

function marker_actions()
  if marker_actions_running then return end
  marker_actions_running = true

  local markers = {}
  local next_idx = 1
  local tolerance = 0.05

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

  scan_markers()

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
    if not marker_actions_running then return end

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

function rgba_to_native(rgba)
  local r = (rgba >> 24) & 0xFF
  local g = (rgba >> 16) & 0xFF
  local b = (rgba >> 8) & 0xFF
  return ColorToNative(r, g, b)
end

---------------------------------------------------------------------

function get_color_table()
  local resource_path = GetResourcePath()
  local pathseparator = package.config:sub(1, 1)
  local relative_path = table.concat({ "", "Scripts", "chmaha Scripts", "ReaClassical", "" }, pathseparator)
  package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
  return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function pastel_color(index)
  local golden_ratio_conjugate = 0.61803398875
  local hue                    = (index * golden_ratio_conjugate) % 1.0

  local saturation             = 0.45 + 0.15 * math.sin(index * 1.7)
  local lightness              = 0.70 + 0.1 * math.cos(index * 1.1)

  local function h2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end

  local q = lightness < 0.5 and (lightness * (1 + saturation))
      or (lightness + saturation - lightness * saturation)
  local p = 2 * lightness - q

  local r = h2rgb(p, q, hue + 1 / 3)
  local g = h2rgb(p, q, hue)
  local b = h2rgb(p, q, hue - 1 / 3)

  local color_int = ColorToNative(
    math.floor(r * 255 + 0.5),
    math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5)
  )

  return color_int | 0x1000000
end

---------------------------------------------------------------------

function get_item_color(item)
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  local colors = get_color_table()

  local color_to_use = nil
  local _, saved_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)

  if saved_guid ~= "" then
    local referenced_item = nil
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
      local test_item = GetMediaItem(0, i)
      local _, test_guid = GetSetMediaItemInfo_String(test_item, "GUID", "", false)
      if test_guid == saved_guid then
        referenced_item = test_item
        break
      end
    end

    if referenced_item then
      color_to_use = GetMediaItemInfo_Value(referenced_item, "I_CUSTOMCOLOR")
    end
  end

  if workflow == "Horizontal" then
    local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
    if saved_color ~= "" then
      color_to_use = tonumber(saved_color)
    else
      color_to_use = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
    end
  elseif not color_to_use then
    local item_track = GetMediaItemTrack(item)
    local folder_tracks = {}
    local num_tracks = CountTracks(0)

    for t = 0, num_tracks - 1 do
      local track = GetTrack(0, t)
      local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
      if depth > 0 then
        table.insert(folder_tracks, track)
      end
    end

    local parent_folder = nil
    local track_idx = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER") - 1
    for t = track_idx, 0, -1 do
      local track = GetTrack(0, t)
      local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
      if depth > 0 then
        parent_folder = track
        break
      end
    end

    local folder_index = 0

    if parent_folder then
      for i, track in ipairs(folder_tracks) do
        if track == parent_folder then
          folder_index = i - 2
          break
        end
      end
      if folder_index < 0 then
        color_to_use = colors.dest_items
      else
        color_to_use = pastel_color(folder_index)
      end
    else
      color_to_use = colors.dest_items
    end
  end

  return color_to_use
end

---------------------------------------------------------------------

function update_take_name(item, rank)
  local take = GetActiveTake(item)
  if not take then return end

  local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

  local all_prefixes = { "Excellent", "Very Good", "Good", "OK", "Below Average", "Poor", "Unusable", "False Start" }
  for _, prefix in ipairs(all_prefixes) do
    item_name = item_name:gsub("^" .. prefix .. "%-", "")
    item_name = item_name:gsub("^" .. prefix .. "$", "")
  end

  if rank ~= "" then
    local rank_index = tonumber(rank)
    if rank_index and RANKS[rank_index] and RANKS[rank_index].prefix ~= "" then
      if item_name ~= "" then
        item_name = RANKS[rank_index].prefix .. "-" .. item_name
      else
        item_name = RANKS[rank_index].prefix
      end
    end
  end

  GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
end

---------------------------------------------------------------------
---
function store_last_recorded_guids(cursor_pos)
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
  cursor_pos = cursor_pos or GetCursorPosition()
  local guids = {}

  local function collect_item(item)
    local take = GetActiveTake(item)
    if not take then return end
    local source = GetMediaItemTake_Source(take)
    if GetMediaSourceType(source, "") ~= "WAVE" then return end
    local _, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
    if guid and guid ~= "" then
      guids[#guids + 1] = guid
    end
  end

  if workflow == "Vertical" then
    -- Find rec-armed folder track
    local rec_track = nil
    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
      local track = GetTrack(0, i)
      if GetMediaTrackInfo_Value(track, "I_RECARM") == 1 and
          GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        rec_track = track
        break
      end
    end

    if rec_track then
      local rec_track_idx = GetMediaTrackInfo_Value(rec_track, "IP_TRACKNUMBER") - 1
      local folder_tracks = {}
      for t = 0, num_tracks - 1 do
        local track = GetTrack(0, t)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
          folder_tracks[#folder_tracks + 1] = track
        end
      end
      local current_folder_idx = nil
      for idx, folder in ipairs(folder_tracks) do
        if GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER") - 1 == rec_track_idx then
          current_folder_idx = idx
          break
        end
      end
      local target_folder
      if current_folder_idx then
        local _, rth = GetProjExtState(0, "ReaClassical", "RecordTakesHorizontally")
        if rth == "1" then
          target_folder = folder_tracks[current_folder_idx]
        elseif current_folder_idx > 1 then
          target_folder = folder_tracks[current_folder_idx - 1]
        end
      end

      if target_folder then
        local target_folder_idx = GetMediaTrackInfo_Value(target_folder, "IP_TRACKNUMBER") - 1
        local folder_end = num_tracks
        for t = target_folder_idx + 1, num_tracks - 1 do
          if GetMediaTrackInfo_Value(GetTrack(0, t), "I_FOLDERDEPTH") == 1 then
            folder_end = t
            break
          end
        end
        for t = target_folder_idx, folder_end - 1 do
          local track = GetTrack(0, t)
          for j = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, j)
            if math.abs(GetMediaItemInfo_Value(item, "D_POSITION") - cursor_pos) < 0.5 then
              collect_item(item)
            end
          end
        end
      end
    end
  else
    -- Horizontal workflow: match by item_end OR item_start
    for i = 0, CountTracks(0) - 1 do
      local track = GetTrack(0, i)
      for j = 0, CountTrackMediaItems(track) - 1 do
        local item = GetTrackMediaItem(track, j)
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")
        if math.abs(item_end - cursor_pos) < 0.5 or math.abs(item_start - cursor_pos) < 0.5 then
          collect_item(item)
        end
      end
    end
  end

  SetProjExtState(0, "ReaClassical", "LastRecordedItemGUIDs", table.concat(guids, ","))
end

---------------------------------------------------------------------

-- Apply rank/notes to a single item (shared logic used by both apply functions).
function apply_rank_and_notes_to_item(item)
  local _, colorized = GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", false)
  local is_colorized = (colorized == "y")

  if recording_rank ~= "" then
    if is_colorized then
      GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)
    end
    GetSetMediaItemInfo_String(item, "P_EXT:item_rank", recording_rank, true)
    if ranking_color_pref == 0 then
      local rank_index = tonumber(recording_rank)
      if rank_index and RANKS[rank_index] then
        SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR",
          rgba_to_native(RANKS[rank_index].rgba) | 0x1000000)
      end
    end
    update_take_name(item, recording_rank)
  else
    GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", true)
    if not is_colorized then
      if auto_color_pref == 0 then
        local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
        local color_to_use
        if workflow == "Horizontal" then
          local take_num = tonumber(take_text)
          color_to_use = take_num and pastel_color(take_num - 1) or get_item_color(item)
        else
          color_to_use = get_item_color(item)
        end
        SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)
      else
        SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0)
      end
    end
    update_take_name(item, "")
  end

  -- FIX: Always write notes (including empty string to clear them)
  GetSetMediaItemInfo_String(item, "P_NOTES", recording_note, true)

  GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", tostring(take_text), true)
  UpdateItemInProject(item)
end

---------------------------------------------------------------------

function apply_rank_and_notes_by_guids()
  local _, guid_str = GetProjExtState(0, "ReaClassical", "LastRecordedItemGUIDs")
  if not guid_str or guid_str == "" then return end

  -- Build lookup table of target GUIDs
  local target_guids = {}
  for guid in guid_str:gmatch("([^,]+)") do
    target_guids[guid] = true
  end

  -- Scan all items and apply to matching ones
  local total_items = CountMediaItems(0)
  for i = 0, total_items - 1 do
    local item = GetMediaItem(0, i)
    local _, guid = GetSetMediaItemInfo_String(item, "GUID", "", false)
    if guid and target_guids[guid] then
      apply_rank_and_notes_to_item(item)
    end
  end

  UpdateArrange()
end

---------------------------------------------------------------------

function apply_rank_and_notes_to_items(cursor_pos)
  local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")

  local target_folder = nil
  if workflow == "Vertical" then
    local rec_track = nil
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
      local track = GetTrack(0, i)
      local rec_armed = GetMediaTrackInfo_Value(track, "I_RECARM")
      local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
      if rec_armed == 1 and depth == 1 then
        rec_track = track
        break
      end
    end

    if rec_track then
      local rec_track_idx = GetMediaTrackInfo_Value(rec_track, "IP_TRACKNUMBER") - 1

      local folder_tracks = {}
      for t = 0, num_tracks - 1 do
        local track = GetTrack(0, t)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth == 1 then
          table.insert(folder_tracks, track)
        end
      end

      local current_folder_idx = nil
      for idx, folder in ipairs(folder_tracks) do
        local folder_idx = GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER") - 1
        if folder_idx == rec_track_idx then
          current_folder_idx = idx
          break
        end
      end

      if current_folder_idx then
        local _, rth = GetProjExtState(0, "ReaClassical", "RecordTakesHorizontally")
        if rth == "1" then
          -- Horizontal mode: arming stayed on the folder that just recorded
          target_folder = folder_tracks[current_folder_idx]
        elseif current_folder_idx > 1 then
          -- Normal mode: arming advanced to next folder, so recorded folder is one back
          target_folder = folder_tracks[current_folder_idx - 1]
        end
      end
    end
  end

  cursor_pos = cursor_pos or GetCursorPosition()
  local items_found = 0

  if workflow == "Vertical" then
    if target_folder then
      local num_tracks = CountTracks(0)
      local target_folder_idx = GetMediaTrackInfo_Value(target_folder, "IP_TRACKNUMBER") - 1

      local folder_start = target_folder_idx
      local folder_end = num_tracks

      for t = target_folder_idx + 1, num_tracks - 1 do
        local track = GetTrack(0, t)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth == 1 then
          folder_end = t
          break
        end
      end

      for t = folder_start, folder_end - 1 do
        local track = GetTrack(0, t)
        local item_count = CountTrackMediaItems(track)

        for j = 0, item_count - 1 do
          local item = GetTrackMediaItem(track, j)

          local take = GetActiveTake(item)
          if take then
            local source = GetMediaItemTake_Source(take)
            local source_type = GetMediaSourceType(source, "")

            if source_type == "WAVE" then
              local item_start = GetMediaItemInfo_Value(item, "D_POSITION")

              if math.abs(item_start - cursor_pos) < 0.5 then
                items_found = items_found + 1

                local _, colorized = GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", false)
                local is_colorized = (colorized == "y")

                if recording_rank ~= "" then
                  if is_colorized then
                    GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)
                  end
                  GetSetMediaItemInfo_String(item, "P_EXT:item_rank", recording_rank, true)
                  if ranking_color_pref == 0 then
                    local rank_index = tonumber(recording_rank)
                    if rank_index and RANKS[rank_index] then
                      local color_to_use = rgba_to_native(RANKS[rank_index].rgba) | 0x1000000
                      SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)
                    end
                  end
                  update_take_name(item, recording_rank)
                else
                  GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", true)
                  if not is_colorized and auto_color_pref == 0 then
                    local color_to_use = get_item_color(item)
                    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)
                  elseif not is_colorized and auto_color_pref == 1 then
                    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0)
                  end
                  update_take_name(item, "")
                end

                -- FIX: Always write notes (including empty string to clear them)
                GetSetMediaItemInfo_String(item, "P_NOTES", recording_note, true)

                GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", tostring(take_text), true)
              end
            end
          end
        end
      end
    end
  else
    -- Horizontal workflow
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
      local track = GetTrack(0, i)
      local item_count = CountTrackMediaItems(track)

      for j = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, j)

        local take = GetActiveTake(item)
        if take then
          local source = GetMediaItemTake_Source(take)
          local source_type = GetMediaSourceType(source, "")

          if source_type == "WAVE" then
            local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_end = item_start + item_length

            -- FIX: Also match by item_start as fallback for cursor position differences
            if math.abs(item_end - cursor_pos) < 0.5 or math.abs(item_start - cursor_pos) < 0.5 then
              items_found = items_found + 1

              local _, colorized = GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", false)
              local is_colorized = (colorized == "y")

              if recording_rank ~= "" then
                if is_colorized then
                  GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)
                end
                GetSetMediaItemInfo_String(item, "P_EXT:item_rank", recording_rank, true)
                if ranking_color_pref == 0 then
                  local rank_index = tonumber(recording_rank)
                  if rank_index and RANKS[rank_index] then
                    local color_to_use = rgba_to_native(RANKS[rank_index].rgba) | 0x1000000
                    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)
                  end
                end
                update_take_name(item, recording_rank)
              else
                GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", true)
                if not is_colorized and auto_color_pref == 0 then
                  local color_to_use
                  local take_num = tonumber(take_text)
                  if take_num then
                    color_to_use = pastel_color(take_num - 1)
                  else
                    color_to_use = get_item_color(item)
                  end
                  SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)
                elseif not is_colorized and auto_color_pref == 1 then
                  SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0)
                end
                update_take_name(item, "")
              end

              -- FIX: Always write notes (including empty string to clear them)
              GetSetMediaItemInfo_String(item, "P_NOTES", recording_note, true)

              GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", tostring(take_text), true)
            end
          end
        end
      end
    end
  end

  UpdateArrange()
end

---------------------------------------------------------------------

function extract_take_from_filename(item)
  local take = GetActiveTake(item)
  if not take then return nil end

  local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  if not take_name or take_name == "" then return nil end

  local take_num = take_name:match("_T(%d+)$")
  if take_num then
    return tonumber(take_num)
  end

  take_num = take_name:match("^(%d+)$")
  if take_num then
    return tonumber(take_num)
  end

  return nil
end

---------------------------------------------------------------------

function extract_session_from_filename(item)
  local take = GetActiveTake(item)
  if not take then return nil end

  local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  if not take_name or take_name == "" then return nil end

  local session_name = take_name:match("^(.+)_T%d+")
  if session_name then
    return session_name
  end

  if take_name:match("^%d+$") then
    return nil
  end

  return nil
end

---------------------------------------------------------------------

function disarm_all_tracks()
  local playstate = GetPlayState()
  if playstate == 5 or playstate == 6 then
    return
  end

  local num_tracks = CountTracks(0)
  for i = 0, num_tracks - 1 do
    local track = GetTrack(0, i)
    local is_rec_armed = GetMediaTrackInfo_Value(track, "I_RECARM")
    if is_rec_armed == 1 then
      SetMediaTrackInfo_Value(track, "I_RECARM", 0)
    end
  end
end

---------------------------------------------------------------------

function get_folder_arm_status(folder_track)
  local num_tracks = CountTracks(0)
  local folder_idx = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1

  local folder_tracks = { folder_track }
  local i = folder_idx + 1
  local depth = 1

  while i < num_tracks and depth > 0 do
    local track = GetTrack(0, i)
    local track_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    table.insert(folder_tracks, track)
    depth = depth + track_depth
    if depth <= 0 then break end
    i = i + 1
  end

  if #folder_tracks == 0 then
    return "none"
  end

  local armed_count = 0
  local has_any_disabled = false

  for _, track in ipairs(folder_tracks) do
    local is_armed = GetMediaTrackInfo_Value(track, "I_RECARM") == 1
    local mixer_track = find_mixer_for_track(track)
    local is_disabled = is_mixer_disabled(mixer_track)
    if is_disabled then has_any_disabled = true end
    if is_armed then armed_count = armed_count + 1 end
  end

  if has_any_disabled then
    return "has_disabled"
  elseif armed_count > 0 and armed_count < #folder_tracks then
    return "partial"
  elseif armed_count == 0 then
    return "none"
  else
    return "all"
  end
end

---------------------------------------------------------------------

function find_mixer_for_track(track)
  local num_sends = GetTrackNumSends(track, 0)

  for i = 0, num_sends - 1 do
    local dest_track = GetTrackSendInfo_Value(track, 0, i, "P_DESTTRACK")
    if dest_track then
      local _, mixer_state = GetSetMediaTrackInfo_String(dest_track, "P_EXT:mixer", "", false)
      if mixer_state == "y" then
        return dest_track
      end
    end
  end

  return nil
end

---------------------------------------------------------------------

function is_mixer_disabled(mixer_track)
  if not mixer_track then
    return false
  end

  local _, disabled_state = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:input_disabled", "", false)
  return (disabled_state == "y")
end

---------------------------------------------------------------------

atexit(clean_up)
main()