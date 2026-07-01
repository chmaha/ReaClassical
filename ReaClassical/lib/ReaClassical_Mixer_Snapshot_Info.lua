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

---------------------------------------------------------------------
-- Read/write access to the same Mixer Snapshot data the ImGui GUI
-- (ReaClassical_Mixer Snapshots.lua) and the Terminal's snap.* commands
-- (ReaClassical_Terminal.lua) use, so any consumer here is immediately
-- visible to/editable by those. is_special_track is shared with
-- Automation_Info rather than duplicated a third time.

local function get_track_state(track)
    local state = {}
    state.volume = GetMediaTrackInfo_Value(track, "D_VOL")
    state.pan = GetMediaTrackInfo_Value(track, "D_PAN")
    state.mute = GetMediaTrackInfo_Value(track, "B_MUTE")
    state.solo = GetMediaTrackInfo_Value(track, "I_SOLO")
    state.phase = GetMediaTrackInfo_Value(track, "B_PHASE")
    state.width = GetMediaTrackInfo_Value(track, "D_WIDTH")
    state.guid = GetTrackGUID(track)

    state.fx_chain = {}
    local fx_count = TrackFX_GetCount(track)
    for i = 0, fx_count - 1 do
        local fx = {}
        fx.enabled = TrackFX_GetEnabled(track, i)
        fx.name = select(2, TrackFX_GetFXName(track, i, ""))
        fx.params = {}
        local param_count = TrackFX_GetNumParams(track, i)
        for p = 0, param_count - 1 do
            fx.params[p] = TrackFX_GetParam(track, i, p)
        end
        state.fx_chain[i] = fx
    end

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

    state.hw_outs = {}
    local hw_out_count = GetTrackNumSends(track, 1)
    for i = 0, hw_out_count - 1 do
        local hw_out = {}
        hw_out.volume = GetTrackSendInfo_Value(track, 1, i, "D_VOL")
        hw_out.pan = GetTrackSendInfo_Value(track, 1, i, "D_PAN")
        hw_out.mute = GetTrackSendInfo_Value(track, 1, i, "B_MUTE")
        hw_out.channel = GetTrackSendInfo_Value(track, 1, i, "I_DSTCHAN")
        state.hw_outs[i] = hw_out
    end

    return state
end

---------------------------------------------------------------------

local function serialize_table(tbl, indent)
    indent = indent or 0
    local result = {}
    local prefix = string.rep("  ", indent)
    table.insert(result, "{\n")
    for k, v in pairs(tbl) do
        local key_str = type(k) == "number" and ("[" .. k .. "]") or ('["' .. tostring(k) .. '"]')
        if type(v) == "table" then
            table.insert(result, prefix .. "  " .. key_str .. " = " .. serialize_table(v, indent + 1) .. ",\n")
        elseif type(v) == "string" then
            table.insert(result, prefix .. "  " .. key_str .. ' = "' .. v:gsub('"', '\\"') .. '",\n')
        elseif type(v) == "number" or type(v) == "boolean" then
            table.insert(result, prefix .. "  " .. key_str .. " = " .. tostring(v) .. ",\n")
        end
    end
    table.insert(result, prefix .. "}")
    return table.concat(result)
end

---------------------------------------------------------------------

local function deserialize_table(str)
    if not str or str == "" then return nil end
    local func = load("return " .. str)
    return func and func() or nil
end

---------------------------------------------------------------------

local function get_current_bank()
    local _, bank = GetProjExtState(0, "MixerSnapshots", "current_bank")
    if bank == "" then bank = "A" end
    return bank
end

---------------------------------------------------------------------

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
                counter               = data.counter or 0,
                bank_folder_selection = data.bank_folder_selection or "all",
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
        counter = 0,
        bank_folder_selection = "all",
    }
end

---------------------------------------------------------------------

local function save_bank(bank, snaps, flags)
    local data = {
        counter               = flags.counter or 0,
        snapshots              = snaps,
        disable_auto_recall   = flags.disable_auto_recall or false,
        switch_mid_gap        = flags.switch_mid_gap ~= false,
        bank_folder_selection = flags.bank_folder_selection or "all",
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

---------------------------------------------------------------------

local function find_by_item_guid(snaps, guid)
    for i, s in ipairs(snaps) do
        if s.item_guid == guid then return s, i end
    end
    return nil
end

---------------------------------------------------------------------

local function find_track_by_guid(guid)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetTrackGUID(t) == guid then return t end
    end
    return nil
end

---------------------------------------------------------------------
-- "Changes from default" diff over an already-captured snapshot. Compares
-- against known REAPER defaults (0dB, center pan, unmuted, normal phase,
-- 100% width, unity/center/unmuted sends) -- not a change history, so a
-- value that was set away from default and back reports nothing, which
-- matches "what would I need to change if not happy" rather than a log of
-- what was ever touched. FX params are deliberately not diffed: REAPER
-- doesn't expose a plugin's true factory default via the API, so there's
-- nothing reliable to compare a captured FX param value against.

local EPS = 0.001

local function fmt_db(linear)
    return string.format("Volume %.1f dB", au.linear_to_db(linear))
end

-- D_VOL/D_PAN-style pan: -1 = full left, +1 = full right (unlike the
-- inverted convention Automation_Info.format_display uses for envelopes).
local function fmt_pan(pan)
    if pan > EPS then
        return string.format("Pan %.0fR", pan * 100)
    end
    return string.format("Pan %.0fL", -pan * 100)
end

local function fmt_width(width)
    return string.format("Width %.0f%%", width * 100)
end

-- Appends formatted non-default fields for a track/send-shaped state table
-- (volume/pan/mute, and mute-only sibling flags for track-level state) into
-- parts. include_track_only_flags covers solo/phase/width, which sends
-- don't have.
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

---------------------------------------------------------------------

-- Auto-recall is driven by a background daemon script that periodically
-- re-checks the edit/play cursor against snapshot positions; ensure it's
-- running whenever a snapshot is created or updated outside the Terminal's
-- own snap.add (which already does this), so newly-set values from this
-- script are actually auto-recalled like any other snapshot.
local function daemon_running()
    local _, ts = GetProjExtState(0, "MixerSnapshots", "daemon_heartbeat")
    return (os.time() - (tonumber(ts) or 0)) < 5
end

local function ensure_daemon_running(daemon_path)
    if daemon_running() then return false end
    if not APIExists("AddRemoveReaScript") then return false end
    local cid = AddRemoveReaScript(true, 0, daemon_path, true)
    if cid ~= 0 then
        Main_OnCommand(cid, 0)
        return true
    end
    return false
end

---------------------------------------------------------------------

-- The actual "snap.add" operation: find-or-create the snapshot entry for
-- item_guid, do a full recapture of every special track's current live
-- state, and save. Returns (created, snapshot).
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

---------------------------------------------------------------------

return {
    is_special_track          = au.is_special_track,
    get_track_state           = get_track_state,
    serialize_table           = serialize_table,
    deserialize_table         = deserialize_table,
    get_current_bank          = get_current_bank,
    load_bank                 = load_bank,
    save_bank                 = save_bank,
    find_by_item_guid         = find_by_item_guid,
    find_track_by_guid        = find_track_by_guid,
    ensure_daemon_running     = ensure_daemon_running,
    capture_snapshot_for_item = capture_snapshot_for_item,
    compute_snapshot_diff     = compute_snapshot_diff,
}
