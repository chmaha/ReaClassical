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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local snap_info = require("ReaClassical_Mixer_Snapshot_Info")
local automation_ownership = require("ReaClassical_Automation_Ownership")
local automation_mode = require("ReaClassical_Automation_Mode")

local M = {}

function M.clear_all_automation()
  snap_info.prune_stale_snapshots(snap_info.get_current_bank())

  Undo_BeginBlock()

  local cleared_count = 0
  local tracks_to_hide = {}

  automation_ownership.deselect_all_automation_items()

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
    local is_special = snap_info.is_special_track(track)

    if mixer_state == "y" or is_special then
      local num_envelopes = CountTrackEnvelopes(track)
      local has_ai = false
      for env_idx = 0, num_envelopes - 1 do
        local env = GetTrackEnvelope(track, env_idx)

        automation_ownership.delete_conversion_owned_ai(env)

        local ai_count = CountAutomationItems(env)
        if ai_count == 0 then
          DeleteEnvelopePointRange(env, -1000000, 1000000)
          GetSetEnvelopeInfo_String(env, "VISIBLE", "0", true)
          GetSetEnvelopeInfo_String(env, "ACTIVE", "0", true)
          GetSetEnvelopeInfo_String(env, "ARM", "0", true)
        else
          has_ai = true
          local ranges = {}
          for ai = 0, ai_count - 1 do
            local pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
            local len = GetSetAutomationItemInfo(env, ai, "D_LENGTH", 0, false)
            table.insert(ranges, { s = pos, e = pos + len })
          end
          table.sort(ranges, function(a, b) return a.s < b.s end)
          DeleteEnvelopePointRange(env, -1000000, ranges[1].s)
          for i2 = 1, #ranges - 1 do
            DeleteEnvelopePointRange(env, ranges[i2].e, ranges[i2 + 1].s)
          end
          DeleteEnvelopePointRange(env, ranges[#ranges].e, 1000000)
        end
      end
      if num_envelopes > 0 then
        cleared_count = cleared_count + 1
      end

      if not has_ai then
        table.insert(tracks_to_hide, track)
      end
    end
  end

  for _, track in ipairs(tracks_to_hide) do
    local current_tcp_state = GetMediaTrackInfo_Value(track, "B_SHOWINTCP")

    if current_tcp_state == 1 then
      SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)

      local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
      local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)

      if mixer_state == "y" then
        SetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. guid, "0")
      else
        SetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid, "0")
      end
    end
  end

  UpdateArrange()
  TrackList_AdjustWindows(false)
  SetProjExtState(0, "ReaClassical", "SnapshotsConvertedToAutomation", "")
  Undo_EndBlock("Clear All Mixer Automation", -1)

  return cleared_count
end

function M.convert_snapshots_to_automation()
  local bank = snap_info.get_current_bank()
  local snaps, flags = snap_info.prune_stale_snapshots(bank)
  if #snaps == 0 then
    return 0, 0
  end

  local first_folder_track = snap_info.get_first_folder_track()

  Undo_BeginBlock()

  automation_ownership.deselect_all_automation_items()

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
    local is_special = snap_info.is_special_track(track)

    if mixer_state == "y" or is_special then
      local num_envelopes = CountTrackEnvelopes(track)
      for env_idx = 0, num_envelopes - 1 do
        local env = GetTrackEnvelope(track, env_idx)

        automation_ownership.delete_conversion_owned_ai(env)

        local ai_count = CountAutomationItems(env)
        if ai_count == 0 then
          DeleteEnvelopePointRange(env, -1000000, 1000000)
          GetSetEnvelopeInfo_String(env, "VISIBLE", "0", true)
          GetSetEnvelopeInfo_String(env, "ACTIVE", "0", true)
          GetSetEnvelopeInfo_String(env, "ARM", "0", true)
        else
          local ranges = {}
          for ai = 0, ai_count - 1 do
            local pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
            local len = GetSetAutomationItemInfo(env, ai, "D_LENGTH", 0, false)
            table.insert(ranges, { s = pos, e = pos + len })
          end
          table.sort(ranges, function(a, b) return a.s < b.s end)
          DeleteEnvelopePointRange(env, -1000000, ranges[1].s)
          for i2 = 1, #ranges - 1 do
            DeleteEnvelopePointRange(env, ranges[i2].e, ranges[i2 + 1].s)
          end
          DeleteEnvelopePointRange(env, ranges[#ranges].e, 1000000)
        end
      end
    end
  end

  local sorted_snapshots = {}
  for i, snap in ipairs(snaps) do
    local item = snap_info.get_item_by_guid(snap.item_guid)
    if item then
      local pos = GetMediaItemInfo_Value(item, "D_POSITION")
      table.insert(sorted_snapshots, { snap = snap, pos = pos, idx = i })
    end
  end
  table.sort(sorted_snapshots, function(a, b) return a.pos < b.pos end)

  local param_changes = {}

  for _, snap_data in ipairs(sorted_snapshots) do
    local snap = snap_data.snap
    local snap_idx = snap_data.idx
    local item = snap_info.get_item_by_guid(snap.item_guid)
    if item then
      local snap_pos = GetMediaItemInfo_Value(item, "D_POSITION")

      for track_idx, track_state in pairs(snap.tracks) do
        local track_guid = track_state.guid

        if not param_changes[track_guid] then
          param_changes[track_guid] = {
            volume = {},
            pan = {},
            mute = {},
            solo = {},
            phase = {},
            width = {},
            fx = {},
            sends = {}
          }
        end

        if flags.volume then
          table.insert(param_changes[track_guid].volume,
            { pos = snap_pos, value = track_state.volume, snap_idx = snap_idx })
        end
        if flags.pan then
          table.insert(param_changes[track_guid].pan, { pos = snap_pos, value = track_state.pan, snap_idx = snap_idx })
        end
        if flags.mute then
          table.insert(param_changes[track_guid].mute, { pos = snap_pos, value = track_state.mute, snap_idx = snap_idx })
        end
        if flags.solo then
          table.insert(param_changes[track_guid].solo, { pos = snap_pos, value = track_state.solo, snap_idx = snap_idx })
        end
        if flags.phase then
          table.insert(param_changes[track_guid].phase,
            { pos = snap_pos, value = track_state.phase, snap_idx = snap_idx })
        end
        if flags.width and track_state.width then
          table.insert(param_changes[track_guid].width,
            { pos = snap_pos, value = track_state.width, snap_idx = snap_idx })
        end

        if flags.fx then
          for fx_idx, fx in pairs(track_state.fx_chain) do
            if not param_changes[track_guid].fx[fx_idx] then
              param_changes[track_guid].fx[fx_idx] = {}
            end
            for param_idx, param_value in pairs(fx.params) do
              if not param_changes[track_guid].fx[fx_idx][param_idx] then
                param_changes[track_guid].fx[fx_idx][param_idx] = {}
              end
              table.insert(param_changes[track_guid].fx[fx_idx][param_idx],
                { pos = snap_pos, value = param_value, snap_idx = snap_idx })
            end
          end
        end

        if flags.sends then
          for send_idx, send in pairs(track_state.sends) do
            if not param_changes[track_guid].sends[send_idx] then
              param_changes[track_guid].sends[send_idx] = {
                volume = {},
                pan = {},
                mute = {}
              }
            end
            table.insert(param_changes[track_guid].sends[send_idx].volume,
              { pos = snap_pos, value = send.volume, snap_idx = snap_idx })
            table.insert(param_changes[track_guid].sends[send_idx].pan,
              { pos = snap_pos, value = send.pan, snap_idx = snap_idx })
            table.insert(param_changes[track_guid].sends[send_idx].mute,
              { pos = snap_pos, value = send.mute, snap_idx = snap_idx })
          end
        end
      end
    end
  end

  local automation_count = 0
  local tracks_with_automation = {}

  local function has_changes(points)
    if #points < 2 then return false end
    local first_val = points[1].value
    for i = 2, #points do
      if math.abs(points[i].value - first_val) > 0.0001 then
        return true
      end
    end
    return false
  end

  local function is_track_in_folder(track, folder_track)
    if track == folder_track then return true end

    local folder_depth = GetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH")
    if folder_depth <= 0 then return false end

    local folder_idx = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

    if track_idx <= folder_idx then return false end

    local depth = folder_depth
    for i = folder_idx + 1, track_idx do
      local t = GetTrack(0, i)
      local t_depth = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
      depth = depth + t_depth
      if i == track_idx then
        return depth > 0
      end
      if depth <= 0 then
        return false
      end
    end
    return false
  end

  local function get_or_create_envelope(track, param_name)
    local env = GetTrackEnvelopeByName(track, param_name)
    if env then
      GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
      GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
      GetSetEnvelopeInfo_String(env, "ARM", "1", true)
      return env
    end

    local num_selected = CountSelectedTracks(0)
    local selected_tracks = {}
    for i = 0, num_selected - 1 do
      selected_tracks[i] = GetSelectedTrack(0, i)
    end

    Main_OnCommand(40297, 0)
    SetTrackSelected(track, true)

    if param_name == "Volume" then
      local env_count = CountTrackEnvelopes(track)
      local had_vol_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Volume" or name == "Volume (Pre-FX)" then
          had_vol_env = true
          break
        end
      end
      if not had_vol_env then
        Main_OnCommand(40406, 0)
      end
    elseif param_name == "Pan" then
      local env_count = CountTrackEnvelopes(track)
      local had_pan_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Pan" or name == "Pan (Pre-FX)" then
          had_pan_env = true
          break
        end
      end
      if not had_pan_env then
        Main_OnCommand(40407, 0)
      end
    elseif param_name == "Mute" then
      local env_count = CountTrackEnvelopes(track)
      local had_mute_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Mute" then
          had_mute_env = true
          break
        end
      end
      if not had_mute_env then
        Main_OnCommand(40867, 0)
      end
    elseif param_name == "Width" then
      local env_count = CountTrackEnvelopes(track)
      local had_width_env = false
      for i = 0, env_count - 1 do
        local e = GetTrackEnvelope(track, i)
        local _, name = GetEnvelopeName(e, "")
        if name == "Width" or name == "Width (Pre-FX)" then
          had_width_env = true
          break
        end
      end
      if not had_width_env then
        Main_OnCommand(41870, 0)
      end
    end

    Main_OnCommand(40297, 0)
    for i = 0, num_selected - 1 do
      SetTrackSelected(selected_tracks[i], true)
    end

    env = GetTrackEnvelopeByName(track, param_name)
    if env then
      GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
      GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
      GetSetEnvelopeInfo_String(env, "ARM", "1", true)
    end
    return env
  end

  local function insert_automation_points(env, points, needs_scaling)
    local points_to_write = {}
    local prev_value = nil

    for i, point in ipairs(points) do
      if not prev_value or math.abs(point.value - prev_value) > 0.0001 then
        table.insert(points_to_write, point)
        prev_value = point.value
      end
    end

    if #points_to_write == 0 then return end

    local resolved = {}
    for i = 1, #points_to_write do
      local point = points_to_write[i]
      local snap = snaps[point.snap_idx]
      local snap_item = snap_info.get_item_by_guid(snap.item_guid)

      if snap_item then
        local snap_item_start = GetMediaItemInfo_Value(snap_item, "D_POSITION")
        local target_pos = snap_item_start

        if i > 1 and flags.switch_mid_gap and first_folder_track then
          local prev_point = points_to_write[i - 1]
          local prev_snap = snaps[prev_point.snap_idx]
          local prev_snap_item = snap_info.get_item_by_guid(prev_snap.item_guid)

          if prev_snap_item then
            local snap_item_guid = BR_GetMediaItemGUID(snap_item)
            local has_overlap = false
            local latest_item_end = -1

            for item_idx = 0, CountMediaItems(0) - 1 do
              local item = GetMediaItem(0, item_idx)
              local item_guid = BR_GetMediaItemGUID(item)

              if item_guid ~= snap_item_guid and GetMediaItem_Track(item) == first_folder_track then
                local item_start_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_start_pos + item_length

                if item_start_pos < snap_item_start and item_end > snap_item_start then
                  has_overlap = true
                  break
                end

                if item_end < snap_item_start and item_end > latest_item_end then
                  latest_item_end = item_end
                end
              end
            end

            if not has_overlap and latest_item_end >= 0 then
              local gap_size = snap_item_start - latest_item_end

              if gap_size > 0.001 then
                local gap_mid = latest_item_end + gap_size / 2
                target_pos = gap_mid
              end
            end
          end
        end

        resolved[#resolved + 1] = { pos = target_pos, value = point.value }
      end
    end

    if #resolved == 0 then return end

    for track_guid, params in pairs(param_changes) do
      local track = snap_info.find_track_by_guid(track_guid)
      if track then
        if has_changes(params.volume) then
          SetMediaTrackInfo_Value(track, "D_VOL", 1.0)
        end

        if has_changes(params.pan) then
          SetMediaTrackInfo_Value(track, "D_PAN", 0.0)
        end

        if has_changes(params.mute) then
          SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        end

        if has_changes(params.phase) then
          SetMediaTrackInfo_Value(track, "B_PHASE", 0)
        end

        if has_changes(params.width) then
          SetMediaTrackInfo_Value(track, "D_WIDTH", 1.0)
        end

        for send_idx, send_params in pairs(params.sends) do
          if has_changes(send_params.volume) then
            SetTrackSendInfo_Value(track, 0, send_idx, "D_VOL", 1.0)
          end
          if has_changes(send_params.pan) then
            SetTrackSendInfo_Value(track, 0, send_idx, "D_PAN", 0.0)
          end
          if has_changes(send_params.mute) then
            SetTrackSendInfo_Value(track, 0, send_idx, "B_MUTE", 0)
          end
        end
      end
    end

    local baseline = resolved[1].value
    do
      local env_val = needs_scaling and ScaleToEnvelopeMode(1, baseline) or baseline
      InsertEnvelopePoint(env, 0, env_val, 0, 0, false, true)
    end

    local stretches = {}
    local in_stretch = false
    local stretch_start = nil

    for i = 2, #resolved do
      local deviates = math.abs(resolved[i].value - baseline) > 0.0001
      if deviates and not in_stretch then
        stretch_start = i
        in_stretch = true
      elseif not deviates and in_stretch then
        stretches[#stretches + 1] = { first = stretch_start, last = i - 1, return_idx = i }
        in_stretch = false
      end
    end
    if in_stretch then
      stretches[#stretches + 1] = { first = stretch_start, last = #resolved, return_idx = nil }
    end

    for _, stretch in ipairs(stretches) do
      local auto_points = {}

      table.insert(auto_points, { pos = resolved[stretch.first].pos - 0.035, value = baseline })
      table.insert(auto_points, { pos = resolved[stretch.first].pos, value = resolved[stretch.first].value })

      for i = stretch.first + 1, stretch.last do
        table.insert(auto_points, { pos = resolved[i].pos - 0.035, value = resolved[i - 1].value })
        table.insert(auto_points, { pos = resolved[i].pos, value = resolved[i].value })
      end

      if stretch.return_idx then
        table.insert(auto_points,
          { pos = resolved[stretch.return_idx].pos - 0.035, value = resolved[stretch.last].value })
        table.insert(auto_points, { pos = resolved[stretch.return_idx].pos, value = baseline })
      end

      for _, auto_point in ipairs(auto_points) do
        local env_val = needs_scaling and ScaleToEnvelopeMode(1, auto_point.value) or auto_point.value
        InsertEnvelopePoint(env, auto_point.pos, env_val, 0, 0, false, true)
      end
    end
  end

  for track_guid, params in pairs(param_changes) do
    local track = snap_info.find_track_by_guid(track_guid)
    if track then
      local track_got_automation = false
      SetMediaTrackInfo_Value(track, "I_AUTOMODE", 1)
      if has_changes(params.volume) then
        local env = get_or_create_envelope(track, "Volume")
        if env then
          insert_automation_points(env, params.volume, true)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      if has_changes(params.pan) then
        local env = get_or_create_envelope(track, "Pan")
        if env then
          local inverted_pan_points = {}
          for _, point in ipairs(params.pan) do
            table.insert(inverted_pan_points, {
              pos = point.pos,
              value = -point.value,
              snap_idx = point.snap_idx
            })
          end
          insert_automation_points(env, inverted_pan_points, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      if has_changes(params.mute) then
        local env = get_or_create_envelope(track, "Mute")
        if env then
          local inverted_mute_points = {}
          for _, point in ipairs(params.mute) do
            table.insert(inverted_mute_points, {
              pos = point.pos,
              value = point.value == 1 and 0 or 1,
              snap_idx = point.snap_idx
            })
          end
          insert_automation_points(env, inverted_mute_points, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      if has_changes(params.solo) then
        local env = GetTrackEnvelopeByName(track, "Solo")
        if env then
          insert_automation_points(env, params.solo, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      if has_changes(params.phase) then
        local env = GetTrackEnvelopeByName(track, "Phase")
        if not env then
          env = GetTrackEnvelopeByName(track, "Polarity")
        end
        if env then
          insert_automation_points(env, params.phase, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      if has_changes(params.width) then
        local env = get_or_create_envelope(track, "Width")
        if env then
          insert_automation_points(env, params.width, false)
          Envelope_SortPoints(env)
          automation_count = automation_count + 1
          track_got_automation = true
        end
      end

      for fx_idx, fx_params in pairs(params.fx) do
        for param_idx, points in pairs(fx_params) do
          if has_changes(points) then
            local env = GetFXEnvelope(track, fx_idx, param_idx, true)
            if env then
              insert_automation_points(env, points, false)
              Envelope_SortPoints(env)
              automation_count = automation_count + 1
              track_got_automation = true
              GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
              GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
              GetSetEnvelopeInfo_String(env, "ARM", "1", true)
            end
          end
        end
      end

      for send_idx, send_params in pairs(params.sends) do
        local num_selected = CountSelectedTracks(0)
        local selected_tracks = {}
        for i = 0, num_selected - 1 do
          selected_tracks[i] = GetSelectedTrack(0, i)
        end

        Main_OnCommand(40297, 0)
        SetTrackSelected(track, true)

        if has_changes(send_params.volume) or has_changes(send_params.pan) or has_changes(send_params.mute) then
          Main_OnCommand(41327, 0)
        end

        Main_OnCommand(40297, 0)
        for i = 0, num_selected - 1 do
          SetTrackSelected(selected_tracks[i], true)
        end

        if has_changes(send_params.volume) then
          local env = BR_GetMediaTrackSendInfo_Envelope(track, 0, send_idx, 0)
          if env then
            insert_automation_points(env, send_params.volume, true)
            Envelope_SortPoints(env)
            automation_count = automation_count + 1
            track_got_automation = true
          end
        end

        if has_changes(send_params.pan) then
          local env = BR_GetMediaTrackSendInfo_Envelope(track, 0, send_idx, 1)
          if env then
            insert_automation_points(env, send_params.pan, false)
            Envelope_SortPoints(env)
            automation_count = automation_count + 1
            track_got_automation = true
          end
        end

        if has_changes(send_params.mute) then
          local env = BR_GetMediaTrackSendInfo_Envelope(track, 0, send_idx, 2)
          if env then
            local inverted_send_mute_points = {}
            for _, point in ipairs(send_params.mute) do
              table.insert(inverted_send_mute_points, {
                pos = point.pos,
                value = point.value == 1 and 0 or 1,
                snap_idx = point.snap_idx
              })
            end
            insert_automation_points(env, inverted_send_mute_points, false)
            Envelope_SortPoints(env)
            automation_count = automation_count + 1
            track_got_automation = true
          end
        end
      end

      if track_got_automation then
        tracks_with_automation[track] = true
      end
    end
  end

  for track, _ in pairs(tracks_with_automation) do
    local current_tcp_state = GetMediaTrackInfo_Value(track, "B_SHOWINTCP")

    if current_tcp_state == 0 then
      SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)

      local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
      local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)

      if mixer_state == "y" then
        SetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. guid, "1")
      else
        SetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid, "1")
      end
    end
  end

  UpdateArrange()
  TrackList_AdjustWindows(false)

  if automation_count > 0 then
    SetProjExtState(0, "ReaClassical", "SnapshotsConvertedToAutomation", "1")
    automation_mode.ensure_engaged()
  end

  Undo_EndBlock("Convert Mixer Snapshots to Automation", -1)

  return automation_count, #snaps
end

return M
