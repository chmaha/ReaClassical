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

local script_name = "Mixer Snapshots"

-- Check for ReaImGui
if not ImGui_CreateContext then
  ShowMessageBox("ReaImGui is required for this script.\nPlease install it via ReaPack.", "Missing Dependency", 0)
  return
end

-- Global state
local ctx = ImGui_CreateContext(script_name)
local snapshots = {}
local selected_snapshot = nil
local last_play_pos = -1
local last_edit_pos = -1
local is_playing = false
local snapshot_counter = 0

-- UI state
local show_window = true
local editing_row = nil
local editing_column = nil
local edit_buffer = ""
local sort_mode = 0  -- 0=marker position, 1=name, 2=time
local sort_direction = nil  -- Will be set to ascending after context is created
local jump_to_marker = false

-- Column widths (swapped Name and Position)
local col_widths = {35, 200, 80, 140, 300}

-- Helper Functions
local function GetTrackState(track)
  local state = {}
  state.volume = GetMediaTrackInfo_Value(track, "D_VOL")
  state.pan = GetMediaTrackInfo_Value(track, "D_PAN")
  state.mute = GetMediaTrackInfo_Value(track, "B_MUTE")
  state.solo = GetMediaTrackInfo_Value(track, "I_SOLO")
  state.phase = GetMediaTrackInfo_Value(track, "B_PHASE")
  state.guid = GetTrackGUID(track)
  
  -- Store FX chain state
  state.fx_chain = {}
  local fx_count = TrackFX_GetCount(track)
  for i = 0, fx_count - 1 do
    local fx = {}
    fx.enabled = TrackFX_GetEnabled(track, i)
    fx.name = select(2, TrackFX_GetFXName(track, i, ""))
    
    -- Store FX parameters
    fx.params = {}
    local param_count = TrackFX_GetNumParams(track, i)
    for p = 0, param_count - 1 do
      fx.params[p] = TrackFX_GetParam(track, i, p)
    end
    
    state.fx_chain[i] = fx
  end
  
  -- Store sends
  state.sends = {}
  local send_count = GetTrackNumSends(track, 0)
  for i = 0, send_count - 1 do
    local send = {}
    send.volume = GetTrackSendInfo_Value(track, 0, i, "D_VOL")
    send.pan = GetTrackSendInfo_Value(track, 0, i, "D_PAN")
    send.mute = GetTrackSendInfo_Value(track, 0, i, "B_MUTE")
    send.dest_guid = GetTrackGUID(BR_GetMediaTrackSendInfo_Track(track, 0, i, 1))
    state.sends[i] = send
  end
  
  return state
end

local function FindTrackByGUID(guid)
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if GetTrackGUID(track) == guid then
      return track
    end
  end
  return nil
end

local function ApplyTrackState(track, state)
  if not track then return end
  
  SetMediaTrackInfo_Value(track, "D_VOL", state.volume)
  SetMediaTrackInfo_Value(track, "D_PAN", state.pan)
  SetMediaTrackInfo_Value(track, "B_MUTE", state.mute)
  SetMediaTrackInfo_Value(track, "I_SOLO", state.solo)
  SetMediaTrackInfo_Value(track, "B_PHASE", state.phase)
  
  -- Apply FX chain
  for fx_idx, fx in pairs(state.fx_chain) do
    if TrackFX_GetCount(track) > fx_idx then
      TrackFX_SetEnabled(track, fx_idx, fx.enabled)
      
      -- Apply FX parameters
      for param_idx, value in pairs(fx.params) do
        TrackFX_SetParam(track, fx_idx, param_idx, value)
      end
    end
  end
  
  -- Apply sends
  for send_idx, send in pairs(state.sends) do
    if GetTrackNumSends(track, 0) > send_idx then
      SetTrackSendInfo_Value(track, 0, send_idx, "D_VOL", send.volume)
      SetTrackSendInfo_Value(track, 0, send_idx, "D_PAN", send.pan)
      SetTrackSendInfo_Value(track, 0, send_idx, "B_MUTE", send.mute)
    end
  end
end

local function CreateSnapshot(name, notes, start_pos, end_pos, prev_snapshot)
  local snapshot = {}
  snapshot_counter = snapshot_counter + 1  -- Increment first
  snapshot.name = name or ("RCmix" .. snapshot_counter)
  snapshot.marker_name = "RCmix" .. snapshot_counter  -- Always use RCmix prefix
  snapshot.date = os.date("%Y-%m-%d")
  snapshot.time = os.date("%H:%M:%S")
  snapshot.notes = notes or ""
  snapshot.tracks = {}
  snapshot.marker_pos = start_pos or GetCursorPosition()
  snapshot.is_region = (end_pos ~= nil)
  snapshot.region_end = end_pos
  snapshot.prev_tracks = prev_snapshot and prev_snapshot.tracks or nil  -- Store previous settings
  
  -- Store all track states (current mixer settings)
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    snapshot.tracks[i] = GetTrackState(track)
  end
  
  -- Create marker or region
  if snapshot.is_region then
    -- Create a region
    local marker_idx = AddProjectMarker(0, true, snapshot.marker_pos, end_pos, snapshot.marker_name, -1)
    snapshot.marker_idx = marker_idx
  else
    -- Create a regular marker
    local marker_idx = AddProjectMarker(0, false, snapshot.marker_pos, 0, snapshot.marker_name, -1)
    snapshot.marker_idx = marker_idx
  end
  
  return snapshot
end

local function FindMarkerByName(marker_name)
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
    -- Match both markers and regions, but only RCmix ones
    if name == marker_name and (name:match("^RCmix%d+$") or name:match("^RCmix%-")) then
      return pos, markrgnindexnumber, isrgn, rgnend
    end
  end
  return nil
end

local function FindSnapshotByMarkerName(marker_name)
  for i, snap in ipairs(snapshots) do
    if snap.marker_name == marker_name then
      return snap, i
    end
  end
  return nil
end

local function FindPreviousRCmixMarker(cursor_pos)
  local prev_marker_name = nil
  local prev_marker_pos = -1
  local prev_is_region = false
  
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, marker_name, markrgnindexnumber = EnumProjectMarkers(i)
    -- Match both "RCmix#" and "RCmix-*" formats
    if (marker_name:match("^RCmix%d+$") or marker_name:match("^RCmix%-")) and pos <= cursor_pos then
      -- For regions, check if cursor is actually inside the region
      if isrgn then
        if cursor_pos >= pos and cursor_pos < rgnend then
          -- Inside this region - prefer innermost (most recent) region
          if pos > prev_marker_pos then
            prev_marker_pos = pos
            prev_marker_name = marker_name
            prev_is_region = true
          end
        end
      else
        -- Regular marker - only consider if we haven't found a region
        if not prev_is_region and pos > prev_marker_pos then
          prev_marker_pos = pos
          prev_marker_name = marker_name
          prev_is_region = false
        end
      end
    end
  end
  
  return prev_marker_name
end

local function DeleteMarkerByName(marker_name)
  local num_markers, num_regions = CountProjectMarkers(0)
  for i = 0, num_markers + num_regions - 1 do
    local retval, isrgn, pos, rgnend, name, markrgnindexnumber = EnumProjectMarkers(i)
    -- Only delete if it's an RCmix marker/region and matches the name
    if name == marker_name and (name:match("^RCmix%d+$") or name:match("^RCmix%-")) then
      DeleteProjectMarker(0, markrgnindexnumber, isrgn)
      return
    end
  end
end

local function EnsureMarkerExists(snapshot)
  if not snapshot then return end
  
  -- Check if marker/region exists
  local marker_pos, marker_idx = FindMarkerByName(snapshot.marker_name)
  
  if not marker_pos then
    -- Marker/region doesn't exist, create it
    if snapshot.is_region and snapshot.region_end then
      AddProjectMarker(0, true, snapshot.marker_pos, snapshot.region_end, snapshot.marker_name, -1)
    else
      AddProjectMarker(0, false, snapshot.marker_pos, 0, snapshot.marker_name, -1)
    end
  end
end

local function RecallSnapshot(snapshot, should_jump)
  if not snapshot then return end
  
  -- Ensure marker exists
  EnsureMarkerExists(snapshot)
  
  -- Jump to just right of marker if requested
  if should_jump and jump_to_marker then
    SetEditCurPos(snapshot.marker_pos + 0.001, true, true)  -- Move slightly right of marker
  end
  
  -- Apply all track states
  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if snapshot.tracks[i] then
      ApplyTrackState(track, snapshot.tracks[i])
    end
  end
  
  UpdateArrange()
  TrackList_AdjustWindows(false)
end

-- Simple table serialization
local function SerializeTable(tbl, indent)
  indent = indent or 0
  local result = {}
  local prefix = string.rep("  ", indent)
  
  table.insert(result, "{\n")
  
  for k, v in pairs(tbl) do
    local key_str = type(k) == "number" and ("[" .. k .. "]") or ('["' .. tostring(k) .. '"]')
    
    if type(v) == "table" then
      table.insert(result, prefix .. "  " .. key_str .. " = " .. SerializeTable(v, indent + 1) .. ",\n")
    elseif type(v) == "string" then
      table.insert(result, prefix .. "  " .. key_str .. ' = "' .. v:gsub('"', '\\"') .. '",\n')
    elseif type(v) == "number" or type(v) == "boolean" then
      table.insert(result, prefix .. "  " .. key_str .. " = " .. tostring(v) .. ",\n")
    end
  end
  
  table.insert(result, prefix .. "}")
  return table.concat(result)
end

local function DeserializeTable(str)
  if not str or str == "" then return nil end
  local func, err = load("return " .. str)
  if func then
    return func()
  else
    return nil
  end
end

-- Save/Load Project State
local function SaveSnapshotsToProject()
  local data = {}
  data.counter = snapshot_counter
  data.snapshots = {}
  
  for i, snap in ipairs(snapshots) do
    -- Create a serializable version
    local s = {
      name = snap.name,
      marker_name = snap.marker_name,
      date = snap.date,
      time = snap.time,
      notes = snap.notes,
      marker_pos = snap.marker_pos,
      tracks = snap.tracks,
      is_region = snap.is_region,
      region_end = snap.region_end,
      prev_tracks = snap.prev_tracks
    }
    table.insert(data.snapshots, s)
  end
  
  local serialized = SerializeTable(data)
  SetProjExtState(0, "MixerSnapshots", "data", serialized)
end

local function LoadSnapshotsFromProject()
  local retval, serialized = GetProjExtState(0, "MixerSnapshots", "data")
  if retval > 0 and serialized ~= "" then
    local data = DeserializeTable(serialized)
    if data then
      snapshot_counter = data.counter or 0
      snapshots = {}
      
      for i, s in ipairs(data.snapshots or {}) do
        table.insert(snapshots, s)
      end
      
      -- Ensure all markers exist when loading
      for i, snap in ipairs(snapshots) do
        EnsureMarkerExists(snap)
      end
    end
  end
end

-- UI Drawing
local function SortSnapshots()
  local ascending = (sort_direction == ImGui_SortDirection_Ascending())
  
  if sort_mode == 0 then
    -- Sort by marker position
    table.sort(snapshots, function(a, b) 
      if ascending then
        return a.marker_pos < b.marker_pos
      else
        return a.marker_pos > b.marker_pos
      end
    end)
  elseif sort_mode == 1 then
    -- Sort by name
    table.sort(snapshots, function(a, b)
      if ascending then
        return a.name < b.name
      else
        return a.name > b.name
      end
    end)
  elseif sort_mode == 2 then
    -- Sort by time (combine date and time)
    table.sort(snapshots, function(a, b) 
      local a_datetime = a.date .. " " .. a.time
      local b_datetime = b.date .. " " .. b.time
      if ascending then
        return a_datetime < b_datetime
      else
        return a_datetime > b_datetime
      end
    end)
  end
end

local function DrawTable()
  SortSnapshots()
  
  if ImGui_BeginTable(ctx, "SnapshotsTable", 5, ImGui_TableFlags_Borders() | ImGui_TableFlags_RowBg() | ImGui_TableFlags_Resizable()) then
    
    -- Setup columns with widths (Name before Position)
    ImGui_TableSetupColumn(ctx, "#", ImGui_TableColumnFlags_WidthFixed(), col_widths[1])
    ImGui_TableSetupColumn(ctx, "Name", ImGui_TableColumnFlags_WidthFixed(), col_widths[2])
    ImGui_TableSetupColumn(ctx, "Position", ImGui_TableColumnFlags_WidthFixed(), col_widths[3])
    ImGui_TableSetupColumn(ctx, "Date/Time", ImGui_TableColumnFlags_WidthFixed(), col_widths[4])
    ImGui_TableSetupColumn(ctx, "Notes", ImGui_TableColumnFlags_WidthStretch())
    ImGui_TableHeadersRow(ctx)
    
    -- Draw rows
    for i, snap in ipairs(snapshots) do
      ImGui_TableNextRow(ctx)
      ImGui_PushID(ctx, i)
      
      -- Column 0: Index
      ImGui_TableSetColumnIndex(ctx, 0)
      ImGui_PushID(ctx, "index_sel")
      if ImGui_Selectable(ctx, tostring(i), selected_snapshot == snap) then
        selected_snapshot = snap
        RecallSnapshot(snap, true)
      end
      ImGui_PopID(ctx)
      
      -- Column 1: Name (editable, selectable)
      ImGui_TableSetColumnIndex(ctx, 1)
      
      if editing_row == i and editing_column == 1 then
        ImGui_SetKeyboardFocusHere(ctx)
        ImGui_PushID(ctx, "edit_name")
        local rv, new_text = ImGui_InputText(ctx, "##edit", edit_buffer, ImGui_InputTextFlags_EnterReturnsTrue())
        ImGui_PopID(ctx)
        
        -- Update buffer as user types
        if rv then
          edit_buffer = new_text
        end
        
        -- Check if user pressed ESC to cancel
        if ImGui_IsKeyPressed(ctx, ImGui_Key_Escape()) then
          editing_row = nil
          editing_column = nil
        -- Check if user pressed Enter or clicked away
        elseif ImGui_IsItemDeactivatedAfterEdit(ctx) then
          if edit_buffer ~= snap.name then
            -- Delete old marker/region
            DeleteMarkerByName(snap.marker_name)
            
            -- Update display name
            snap.name = edit_buffer
            
            -- Update marker name with RCmix- prefix if name was changed from default
            if edit_buffer:match("^RCmix%d+$") then
              -- Keep original marker name if it's still the default format
              snap.marker_name = edit_buffer
            else
              -- Add RCmix- prefix for custom names
              snap.marker_name = "RCmix-" .. edit_buffer
            end
            
            -- Create new marker or region with updated name
            if snap.is_region and snap.region_end then
              AddProjectMarker(0, true, snap.marker_pos, snap.region_end, snap.marker_name, -1)
            else
              AddProjectMarker(0, false, snap.marker_pos, 0, snap.marker_name, -1)
            end
            SaveSnapshotsToProject()
          end
          editing_row = nil
          editing_column = nil
        end
      else
        ImGui_PushID(ctx, "name_sel")
        if ImGui_Selectable(ctx, snap.name, selected_snapshot == snap) then
          selected_snapshot = snap
          RecallSnapshot(snap, true)  -- Allow jump to marker on user selection
        end
        ImGui_PopID(ctx)
        
        -- Double-click to edit
        if ImGui_IsItemHovered(ctx) and ImGui_IsMouseDoubleClicked(ctx, 0) then
          editing_row = i
          editing_column = 1
          edit_buffer = snap.name
        end
      end
      
      -- Column 2: Position (timeline position in format m:ss.ms)
      ImGui_TableSetColumnIndex(ctx, 2)
      local minutes = math.floor(snap.marker_pos / 60)
      local seconds = snap.marker_pos % 60
      ImGui_PushID(ctx, "pos_sel")
      if ImGui_Selectable(ctx, string.format("%d:%05.2f", minutes, seconds), selected_snapshot == snap) then
        selected_snapshot = snap
        RecallSnapshot(snap, true)
      end
      ImGui_PopID(ctx)
      
      -- Column 3: Date/Time (combined)
      ImGui_TableSetColumnIndex(ctx, 3)
      ImGui_PushID(ctx, "time_sel")
      if ImGui_Selectable(ctx, snap.date .. " " .. snap.time, selected_snapshot == snap) then
        selected_snapshot = snap
        RecallSnapshot(snap, true)
      end
      ImGui_PopID(ctx)
      
      -- Column 4: Notes (editable)
      ImGui_TableSetColumnIndex(ctx, 4)
      
      if editing_row == i and editing_column == 4 then
        ImGui_SetKeyboardFocusHere(ctx)
        ImGui_PushID(ctx, "edit_notes")
        ImGui_SetNextItemWidth(ctx, -1)  -- Fill available width
        local rv, new_text = ImGui_InputText(ctx, "##edit", edit_buffer, ImGui_InputTextFlags_EnterReturnsTrue())
        ImGui_PopID(ctx)
        
        -- Update buffer as user types
        if rv then
          edit_buffer = new_text
        end
        
        -- Check if user pressed ESC to cancel
        if ImGui_IsKeyPressed(ctx, ImGui_Key_Escape()) then
          editing_row = nil
          editing_column = nil
        -- Check if user pressed Enter or clicked away
        elseif ImGui_IsItemDeactivatedAfterEdit(ctx) then
          if edit_buffer ~= snap.notes then
            snap.notes = edit_buffer
            SaveSnapshotsToProject()
          end
          editing_row = nil
          editing_column = nil
        end
      else
        ImGui_PushID(ctx, "notes_sel")
        if ImGui_Selectable(ctx, snap.notes, selected_snapshot == snap) then
          selected_snapshot = snap
          RecallSnapshot(snap, true)
        end
        ImGui_PopID(ctx)
        
        -- Double-click to edit
        if ImGui_IsItemHovered(ctx) and ImGui_IsMouseDoubleClicked(ctx, 0) then
          editing_row = i
          editing_column = 4
          edit_buffer = snap.notes
        end
      end
      
      ImGui_PopID(ctx)
    end
    
    ImGui_EndTable(ctx)
  end
end

local function DrawUI()
  ImGui_SetNextWindowSize(ctx, 900, 0, ImGui_Cond_FirstUseEver())
  
  local visible, open = ImGui_Begin(ctx, script_name, true)
  if visible then
    
    -- Buttons
    local start_time, end_time = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local has_time_sel = (end_time - start_time) > 0.001
    local button_label = has_time_sel and "New snapshot in time selection" or "New snapshot at edit cursor"
    
    if ImGui_Button(ctx, button_label) then
      Undo_BeginBlock()
      
      if has_time_sel then
        -- Find the previous RCmix marker/region before the START of time selection
        local prev_marker_name = FindPreviousRCmixMarker(start_time)
        local prev_snapshot = nil
        
        if prev_marker_name then
          prev_snapshot = FindSnapshotByMarkerName(prev_marker_name)
        end
        
        -- Create a region snapshot with previous settings stored
        local snap = CreateSnapshot(nil, nil, start_time, end_time, prev_snapshot)
        table.insert(snapshots, snap)
        selected_snapshot = snap
        
        -- Clear the time selection
        GetSet_LoopTimeRange(true, false, 0, 0, false)
      else
        -- Regular snapshot at edit cursor (marker)
        local snap = CreateSnapshot()
        table.insert(snapshots, snap)
        selected_snapshot = snap
      end
      
      SaveSnapshotsToProject()
      Undo_EndBlock("Create Mixer Snapshot", -1)
    end
    
    ImGui_SameLine(ctx)
    
    if ImGui_Button(ctx, "Update Selected") then
      if selected_snapshot then
        Undo_BeginBlock()
        -- Capture current mixer state and overwrite selected snapshot
        selected_snapshot.tracks = {}
        for i = 0, CountTracks(0) - 1 do
          local track = GetTrack(0, i)
          selected_snapshot.tracks[i] = GetTrackState(track)
        end
        selected_snapshot.date = os.date("%Y-%m-%d")
        selected_snapshot.time = os.date("%H:%M:%S")
        SaveSnapshotsToProject()
        Undo_EndBlock("Update Mixer Snapshot", -1)
      end
    end
    
    ImGui_SameLine(ctx)
    
    if ImGui_Button(ctx, "Duplicate Selected") then
      if selected_snapshot then
        Undo_BeginBlock()
        
        -- Create a new snapshot with the same track states
        snapshot_counter = snapshot_counter + 1
        local new_snap = {}
        new_snap.name = "RCmix" .. snapshot_counter
        new_snap.marker_name = "RCmix" .. snapshot_counter
        new_snap.date = os.date("%Y-%m-%d")
        new_snap.time = os.date("%H:%M:%S")
        new_snap.notes = selected_snapshot.notes
        new_snap.marker_pos = GetCursorPosition()  -- Use current edit cursor position
        
        -- Deep copy the track states from selected snapshot
        new_snap.tracks = {}
        for i, track_state in pairs(selected_snapshot.tracks) do
          new_snap.tracks[i] = {}
          for k, v in pairs(track_state) do
            if k == "fx_chain" then
              -- Deep copy FX chain
              new_snap.tracks[i].fx_chain = {}
              for fx_idx, fx in pairs(v) do
                new_snap.tracks[i].fx_chain[fx_idx] = {}
                new_snap.tracks[i].fx_chain[fx_idx].enabled = fx.enabled
                new_snap.tracks[i].fx_chain[fx_idx].name = fx.name
                new_snap.tracks[i].fx_chain[fx_idx].params = {}
                for p_idx, p_val in pairs(fx.params) do
                  new_snap.tracks[i].fx_chain[fx_idx].params[p_idx] = p_val
                end
              end
            elseif k == "sends" then
              -- Deep copy sends
              new_snap.tracks[i].sends = {}
              for send_idx, send in pairs(v) do
                new_snap.tracks[i].sends[send_idx] = {}
                for send_k, send_v in pairs(send) do
                  new_snap.tracks[i].sends[send_idx][send_k] = send_v
                end
              end
            else
              new_snap.tracks[i][k] = v
            end
          end
        end
        
        -- Create marker at edit cursor
        AddProjectMarker(0, false, new_snap.marker_pos, 0, new_snap.marker_name, -1)
        
        table.insert(snapshots, new_snap)
        selected_snapshot = new_snap
        SaveSnapshotsToProject()
        Undo_EndBlock("Duplicate Mixer Snapshot", -1)
      end
    end
    
    ImGui_SameLine(ctx)
    
    if ImGui_Button(ctx, "Delete Selected") then
      if selected_snapshot then
        Undo_BeginBlock()
        DeleteMarkerByName(selected_snapshot.marker_name)
        
        for i, snap in ipairs(snapshots) do
          if snap == selected_snapshot then
            table.remove(snapshots, i)
            selected_snapshot = nil
            break
          end
        end
        
        SaveSnapshotsToProject()
        Undo_EndBlock("Delete Mixer Snapshot", -1)
      end
    end
    
    ImGui_Separator(ctx)
    
    -- Sort controls
    ImGui_Text(ctx, "Sort by:")
    ImGui_SameLine(ctx)
    if ImGui_RadioButton(ctx, "Position", sort_mode == 0) then sort_mode = 0 end
    ImGui_SameLine(ctx)
    if ImGui_RadioButton(ctx, "Name", sort_mode == 1) then sort_mode = 1 end
    ImGui_SameLine(ctx)
    if ImGui_RadioButton(ctx, "Time", sort_mode == 2) then sort_mode = 2 end
    
    ImGui_SameLine(ctx)
    ImGui_Dummy(ctx, 20, 0)
    ImGui_SameLine(ctx)
    
    -- Sort direction toggle
    local dir_label = sort_direction == ImGui_SortDirection_Ascending() and "Ascending ▲" or "Descending ▼"
    if ImGui_Button(ctx, dir_label) then
      sort_direction = sort_direction == ImGui_SortDirection_Ascending() and ImGui_SortDirection_Descending() or ImGui_SortDirection_Ascending()
    end
    
    ImGui_SameLine(ctx)
    ImGui_Dummy(ctx, 20, 0)
    ImGui_SameLine(ctx)
    
    -- Jump to marker checkbox
    local rv, new_val = ImGui_Checkbox(ctx, "Jump to marker on recall", jump_to_marker)
    if rv then jump_to_marker = new_val end
    
    ImGui_Separator(ctx)
    
    -- Table
    DrawTable()
    
    ImGui_End(ctx)
  end
  
  return open
end

-- Check for marker-based auto-recall
local function CheckAutoRecall()
  local play_state = GetPlayState()
  local current_playing = (play_state & 1) == 1
  
  -- Transport is playing
  if current_playing then
    local play_pos = GetPlayPosition()
    
    -- Check if we crossed a marker/region
    if last_play_pos >= 0 and play_pos ~= last_play_pos then
      local num_markers, num_regions = CountProjectMarkers(0)
      
      for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, marker_name, markrgnindexnumber = EnumProjectMarkers(i)
        
        -- Match both "RCmix#" and "RCmix-*" formats
        if (marker_name:match("^RCmix%d+$") or marker_name:match("^RCmix%-")) then
          if isrgn then
            -- Region: check if we entered it
            if last_play_pos < pos and play_pos >= pos then
              local snap = FindSnapshotByMarkerName(marker_name)
              if snap then
                RecallSnapshot(snap, false)
                selected_snapshot = snap
              end
            -- Check if we exited the region
            elseif last_play_pos < rgnend and play_pos >= rgnend then
              local snap = FindSnapshotByMarkerName(marker_name)
              if snap and snap.prev_tracks then
                -- Restore previous settings when exiting region
                for j = 0, CountTracks(0) - 1 do
                  local track = GetTrack(0, j)
                  if snap.prev_tracks[j] then
                    ApplyTrackState(track, snap.prev_tracks[j])
                  end
                end
                UpdateArrange()
                TrackList_AdjustWindows(false)
              end
            end
          else
            -- Regular marker
            if last_play_pos < pos and play_pos >= pos then
              local snap = FindSnapshotByMarkerName(marker_name)
              if snap then
                RecallSnapshot(snap, false)
                selected_snapshot = snap
              end
            end
          end
        end
      end
    end
    
    last_play_pos = play_pos
    is_playing = true
  else
    -- Transport stopped - just check current cursor position
    if is_playing then
      is_playing = false
      last_play_pos = -1
    end
    
    -- Check edit cursor position
    local edit_pos = GetCursorPosition()
    if edit_pos ~= last_edit_pos then
      last_edit_pos = edit_pos
      
      -- Use the improved FindPreviousRCmixMarker which handles regions properly
      local marker_name = FindPreviousRCmixMarker(edit_pos)
      if marker_name then
        local snap = FindSnapshotByMarkerName(marker_name)
        if snap and snap ~= selected_snapshot then
          RecallSnapshot(snap, false)
          selected_snapshot = snap
        end
      end
    end
  end
end

-- Main Loop
local function Main()
  CheckAutoRecall()
  
  local open = DrawUI()
  
  if open then
    defer(Main)
  end
end

-- Initialize
sort_direction = ImGui_SortDirection_Ascending()  -- Default to ascending sort
LoadSnapshotsFromProject()
defer(Main)