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
local au = require("ReaClassical_Automation_Info")
local engine = require("ReaClassical_Snapshot_Engine")

local get_track_state = engine.get_track_state
local serialize_table = engine.serialize_table
local deserialize_table = engine.deserialize_table

local function get_current_bank()
    local _, bank = GetProjExtState(0, "MixerSnapshots", "current_bank")
    if bank == "" then bank = "A" end
    return bank
end

local function set_current_bank(bank)
    SetProjExtState(0, "MixerSnapshots", "current_bank", bank)
end

local function load_bank(bank)
    local retval, str = GetProjExtState(0, "MixerSnapshots", "data_" .. bank)
    if retval > 0 and str ~= "" then
        local data = deserialize_table(str)
        if data then
            return data.snapshots or {}, {
                volume                = data.recall_volume ~= false,
                pan                   = data.recall_pan ~= false,
                mute                  = data.recall_mute ~= false,
                solo                  = data.recall_solo ~= false,
                phase                 = data.recall_phase ~= false,
                width                 = data.recall_width ~= false,
                fx                    = data.recall_fx ~= false,
                sends                 = data.recall_sends ~= false,
                routing               = data.recall_routing ~= false,
                disable_auto_recall   = data.disable_auto_recall or false,
                switch_mid_gap        = data.switch_mid_gap ~= false,
                allow_daemon_on_close = data.allow_daemon_on_close ~= false,
                counter               = data.counter or 0,
            }
        end
    end
    return {}, {
        volume = true,
        pan = true,
        mute = true,
        solo = true,
        phase = true,
        width = true,
        fx = true,
        sends = true,
        routing = true,
        disable_auto_recall = false,
        switch_mid_gap = true,
        allow_daemon_on_close = true,
        counter = 0,
    }
end

local function save_bank(bank, snaps, flags)
    local data = {
        counter               = flags.counter or 0,
        snapshots              = snaps,
        disable_auto_recall   = flags.disable_auto_recall or false,
        switch_mid_gap        = flags.switch_mid_gap ~= false,
        allow_daemon_on_close = flags.allow_daemon_on_close ~= false,
        recall_volume         = flags.volume ~= false,
        recall_pan            = flags.pan ~= false,
        recall_mute           = flags.mute ~= false,
        recall_solo           = flags.solo ~= false,
        recall_phase          = flags.phase ~= false,
        recall_width          = flags.width ~= false,
        recall_fx             = flags.fx ~= false,
        recall_sends          = flags.sends ~= false,
        recall_routing        = flags.routing ~= false,
    }
    SetProjExtState(0, "MixerSnapshots", "data_" .. bank, serialize_table(data))
end

local function find_by_item_guid(snaps, guid)
    for i, s in ipairs(snaps) do
        if s.item_guid == guid then return s, i end
    end
    return nil
end

local find_track_by_guid = engine.find_track_by_guid

local function get_item_by_guid(guid)
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        if BR_GetMediaItemGUID(item) == guid then return item end
    end
    return nil
end

local function prune_stale_snapshots(bank)
    local snaps, flags = load_bank(bank)
    local kept = {}
    local removed = 0
    for _, s in ipairs(snaps) do
        if get_item_by_guid(s.item_guid) then
            kept[#kept + 1] = s
        else
            removed = removed + 1
        end
    end
    if removed > 0 then
        save_bank(bank, kept, flags)
    end
    return kept, flags, removed
end

local function get_first_folder_track()
    local t = GetTrack(0, 0)
    if t and GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
    return nil
end

local function get_item_position(guid)
    local item = get_item_by_guid(guid)
    if item then return GetMediaItemInfo_Value(item, "D_POSITION") end
    return math.huge
end

local function sort_by_timeline(snaps)
    table.sort(snaps, function(a, b)
        return get_item_position(a.item_guid) < get_item_position(b.item_guid)
    end)
end

local EPS = 0.001

local function fmt_db(linear)
    return string.format("Volume %.1f dB", au.linear_to_db(linear))
end

local function fmt_pan(pan)
    if pan > EPS then
        return string.format("Pan %.0fR", pan * 100)
    end
    return string.format("Pan %.0fL", -pan * 100)
end

local function fmt_width(width)
    return string.format("Width %.0f%%", width * 100)
end

local function append_value_diffs(parts, s, include_track_only_flags)
    if math.abs(s.volume - 1.0) > EPS then parts[#parts + 1] = fmt_db(s.volume) end
    if math.abs(s.pan) > EPS then parts[#parts + 1] = fmt_pan(s.pan) end
    if s.mute and s.mute ~= 0 then parts[#parts + 1] = "Muted" end
    if include_track_only_flags then
        if s.solo and s.solo ~= 0 then parts[#parts + 1] = "Soloed" end
        if s.phase and s.phase ~= 0 then parts[#parts + 1] = "Phase inverted" end
        if s.width and math.abs(s.width - 1.0) > EPS then parts[#parts + 1] = fmt_width(s.width) end
    end
end

local function compute_snapshot_diff(snapshot)
    local lines = {}

    local indices = {}
    for i in pairs(snapshot.tracks) do indices[#indices + 1] = i end
    table.sort(indices)

    for _, i in ipairs(indices) do
        local track_state = snapshot.tracks[i]
        local track = find_track_by_guid(track_state.guid)
        local label = track and au.get_track_label(track) or "(missing track)"

        local parts = {}
        append_value_diffs(parts, track_state, true)
        if #parts > 0 then
            lines[#lines + 1] = label .. ": " .. table.concat(parts, ", ")
        end

        local send_indices = {}
        for j in pairs(track_state.sends or {}) do send_indices[#send_indices + 1] = j end
        table.sort(send_indices)

        for _, j in ipairs(send_indices) do
            local send = track_state.sends[j]
            local sparts = {}
            append_value_diffs(sparts, send, false)
            if #sparts > 0 then
                local dest = find_track_by_guid(send.dest_guid)
                local dest_label = dest and au.get_track_label(dest) or "(missing track)"
                lines[#lines + 1] = label .. " send to " .. dest_label .. ": " .. table.concat(sparts, ", ")
            end
        end
    end

    return lines
end

local function daemon_running()
    return GetExtState("ReaClassical", "MixerSnapDaemonRunning") == "1"
end

local function ensure_daemon_running(daemon_path)
    if daemon_running() then return false end
    if not APIExists("AddRemoveReaScript") then return false end
    local cid = AddRemoveReaScript(true, 0, daemon_path, true)
    if cid == 0 then return false end
    Main_OnCommand(cid, 0)
    return true
end

local function stop_daemon_if_running(daemon_path)
    if not daemon_running() then return false end
    if not APIExists("AddRemoveReaScript") then return false end
    local cid = AddRemoveReaScript(true, 0, daemon_path, true)
    if cid == 0 then return false end
    Main_OnCommand(cid, 0)
    SetProjExtState(0, "MixerSnapshots", "daemon_heartbeat", "0")
    return true
end

local function capture_snapshot_for_item(item_guid, item_name, bank)
    local snaps, flags = load_bank(bank)
    local existing, existing_idx = find_by_item_guid(snaps, item_guid)

    local snapshot = {
        item_guid = item_guid,
        item_name = item_name or "",
        date = os.date("%Y-%m-%d"),
        time = os.date("%H:%M:%S"),
        notes = existing and (existing.notes or "") or "",
        tracks = {},
    }
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if au.is_special_track(track) then
            snapshot.tracks[i] = get_track_state(track)
        end
    end

    local created = existing_idx == nil
    if existing_idx then
        snaps[existing_idx] = snapshot
    else
        flags.counter = (flags.counter or 0) + 1
        table.insert(snaps, snapshot)
    end
    save_bank(bank, snaps, flags)
    return created, snapshot
end

local apply_track_state = engine.apply_track_state
local recall_snapshot = engine.recall_snapshot

local function find_at_cursor(snaps, cursor_pos)
    for _, s in ipairs(snaps) do
        local item = get_item_by_guid(s.item_guid)
        if item then
            local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end   = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")
            if cursor_pos >= item_start and cursor_pos < item_end then
                return s
            end
        end
    end
    local prev_snap, prev_pos = nil, -1
    for _, s in ipairs(snaps) do
        local item = get_item_by_guid(s.item_guid)
        if item then
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            if p < cursor_pos and p > prev_pos then
                prev_pos = p
                prev_snap = s
            end
        end
    end
    return prev_snap
end

return {
    is_special_track          = au.is_special_track,
    apply_track_state         = apply_track_state,
    recall_snapshot           = recall_snapshot,
    find_at_cursor            = find_at_cursor,
    get_track_state           = get_track_state,
    serialize_table           = serialize_table,
    deserialize_table         = deserialize_table,
    get_current_bank          = get_current_bank,
    set_current_bank          = set_current_bank,
    load_bank                 = load_bank,
    save_bank                 = save_bank,
    find_by_item_guid         = find_by_item_guid,
    find_track_by_guid        = find_track_by_guid,
    get_item_by_guid          = get_item_by_guid,
    prune_stale_snapshots     = prune_stale_snapshots,
    get_first_folder_track    = get_first_folder_track,
    sort_by_timeline          = sort_by_timeline,
    daemon_running            = daemon_running,
    ensure_daemon_running     = ensure_daemon_running,
    stop_daemon_if_running    = stop_daemon_if_running,
    capture_snapshot_for_item = capture_snapshot_for_item,
    compute_snapshot_diff     = compute_snapshot_diff,
}
