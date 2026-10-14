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

local M = {}

M.is_special_track = au.is_special_track

function M.find_track_by_guid(guid)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetTrackGUID(t) == guid then return t end
    end
    return nil
end

local all_items_cache, all_items_by_guid_cache, all_items_change_count

function M.get_all_items()
    local cc = GetProjectStateChangeCount(0)
    if all_items_cache and all_items_change_count == cc then
        return all_items_cache, all_items_by_guid_cache
    end

    local items, by_guid = {}, {}
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local start = GetMediaItemInfo_Value(item, "D_POSITION")
        local entry = {
            item = item,
            track = GetMediaItem_Track(item),
            start = start,
            ["end"] = start + GetMediaItemInfo_Value(item, "D_LENGTH"),
            guid = BR_GetMediaItemGUID(item),
        }
        items[#items + 1] = entry
        by_guid[entry.guid] = entry
    end
    table.sort(items, function(a, b) return a.start < b.start end)

    all_items_cache, all_items_by_guid_cache, all_items_change_count = items, by_guid, cc
    return items, by_guid
end

function M.find_item_by_guid(guid)
    local _, by_guid = M.get_all_items()
    local entry = by_guid[guid]
    return entry and entry.item or nil
end

local function find_snap_by_guid(snaps, guid)
    for _, s in ipairs(snaps) do
        if s.item_guid == guid then return s end
    end
    return nil
end

function M.find_snapshot_at_cursor(snaps, cursor_pos)
    local all_items = M.get_all_items()
    for _, di in ipairs(all_items) do
        if cursor_pos >= di.start and cursor_pos < di["end"] then
            local snap = find_snap_by_guid(snaps, di.guid)
            if snap then return snap end
            break
        end
    end
    local prev_snap, prev_pos = nil, -1
    for _, di in ipairs(all_items) do
        if di.start < cursor_pos and di.start > prev_pos then
            local snap = find_snap_by_guid(snaps, di.guid)
            if snap then
                prev_pos = di.start
                prev_snap = snap
            end
        end
    end
    return prev_snap
end

function M.find_snapshot_with_gap_logic(snaps, cursor_pos, switch_mid_gap)
    if not switch_mid_gap then
        return M.find_snapshot_at_cursor(snaps, cursor_pos)
    end

    local all_items = M.get_all_items()

    local function is_track_in_folder(track, folder_track)
        if track == folder_track then return true end
        local folder_depth = GetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH")
        if folder_depth <= 0 then return false end
        local folder_idx = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
        local track_idx  = GetMediaTrackInfo_Value(track,        "IP_TRACKNUMBER") - 1
        if track_idx <= folder_idx then return false end
        local depth = folder_depth
        for i = folder_idx + 1, track_idx do
            local t       = GetTrack(0, i)
            local t_depth = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
            depth = depth + t_depth
            if i == track_idx then return depth > 0 end
            if depth <= 0 then return false end
        end
        return false
    end

    local snapshot_items = {}
    for _, di in ipairs(all_items) do
        local snap = find_snap_by_guid(snaps, di.guid)
        if snap then
            snapshot_items[#snapshot_items + 1] = { di = di, snap = snap }
        end
    end

    local prev_folder
    local next_snap, next_folder, next_start = nil, nil, math.huge
    for _, e in ipairs(snapshot_items) do
        if e.di.start <= cursor_pos then
            prev_folder = e.di.track
        else
            next_snap, next_folder, next_start = e.snap, e.di.track, e.di.start
            break
        end
    end

    local cursor_on_relevant_item = false
    for _, di in ipairs(all_items) do
        if cursor_pos >= di.start and cursor_pos < di["end"] then
            if (prev_folder and is_track_in_folder(di.track, prev_folder)) or
                (next_folder and is_track_in_folder(di.track, next_folder)) then
                cursor_on_relevant_item = true
            end
            break
        end
    end

    if cursor_on_relevant_item then
        return M.find_snapshot_at_cursor(snaps, cursor_pos)
    end

    local last_item_end_in_prev_folder = -1
    if prev_folder then
        for _, di in ipairs(all_items) do
            if is_track_in_folder(di.track, prev_folder) and
                di["end"] < next_start and di["end"] > last_item_end_in_prev_folder then
                last_item_end_in_prev_folder = di["end"]
            end
        end
    end

    if next_snap and last_item_end_in_prev_folder >= 0 and
        last_item_end_in_prev_folder < next_start then
        local gap_mid = last_item_end_in_prev_folder +
            (next_start - last_item_end_in_prev_folder) / 2
        if cursor_pos >= gap_mid and cursor_pos < next_start then
            return next_snap
        end
    end

    return M.find_snapshot_at_cursor(snaps, cursor_pos)
end

function M.serialize_table(tbl, indent)
    indent = indent or 0
    local result = {}
    local prefix = string.rep("  ", indent)
    table.insert(result, "{\n")
    for k, v in pairs(tbl) do
        local key_str = type(k) == "number" and ("[" .. k .. "]") or ('["' .. tostring(k) .. '"]')
        if type(v) == "table" then
            table.insert(result, prefix .. "  " .. key_str .. " = " .. M.serialize_table(v, indent + 1) .. ",\n")
        elseif type(v) == "string" then
            local escaped = v:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
            table.insert(result, prefix .. "  " .. key_str .. ' = "' .. escaped .. '",\n')
        elseif type(v) == "number" or type(v) == "boolean" then
            table.insert(result, prefix .. "  " .. key_str .. " = " .. tostring(v) .. ",\n")
        end
    end
    table.insert(result, prefix .. "}")
    return table.concat(result)
end

function M.deserialize_table(str)
    if not str or str == "" then return nil end
    local func = load("return " .. str, "snapshot", "t", {})
    if not func then return nil end
    local ok, result = pcall(func)
    if not ok then return nil end
    return result
end

function M.get_track_state(track)
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

function M.apply_track_state(track, state, flags)
    if not track then return end
    if flags.volume then SetMediaTrackInfo_Value(track, "D_VOL", state.volume) end
    if flags.pan then SetMediaTrackInfo_Value(track, "D_PAN", state.pan) end
    if flags.mute then SetMediaTrackInfo_Value(track, "B_MUTE", state.mute) end
    if flags.solo then SetMediaTrackInfo_Value(track, "I_SOLO", state.solo) end
    if flags.phase then SetMediaTrackInfo_Value(track, "B_PHASE", state.phase) end
    if flags.width and state.width then
        SetMediaTrackInfo_Value(track, "D_WIDTH", state.width)
    end
    if flags.fx then
        for fx_idx, fx in pairs(state.fx_chain) do
            if TrackFX_GetCount(track) > fx_idx then
                TrackFX_SetEnabled(track, fx_idx, fx.enabled)
                for p, v in pairs(fx.params) do
                    TrackFX_SetParam(track, fx_idx, p, v)
                end
            end
        end
    end
    if flags.sends then
        for i, send in pairs(state.sends) do
            if GetTrackNumSends(track, 0) > i then
                SetTrackSendInfo_Value(track, 0, i, "D_VOL", send.volume)
                SetTrackSendInfo_Value(track, 0, i, "D_PAN", send.pan)
                SetTrackSendInfo_Value(track, 0, i, "B_MUTE", send.mute)
            end
        end
    end
    if flags.routing and state.sends then
        local n = GetTrackNumSends(track, 0)
        for i = n - 1, 0, -1 do RemoveTrackSend(track, 0, i) end
        local rcmaster_guid = nil
        for i = 0, CountTracks(0) - 1 do
            local tr = GetTrack(0, i)
            local _, rcs = GetSetMediaTrackInfo_String(tr, "P_EXT:rcmaster", "", false)
            if rcs == "y" then
                rcmaster_guid = GetTrackGUID(tr); break
            end
        end
        local has_rcm = false
        for _, send in pairs(state.sends) do
            local dst = M.find_track_by_guid(send.dest_guid)
            if dst then
                local idx = CreateTrackSend(track, dst)
                if idx >= 0 then
                    SetTrackSendInfo_Value(track, 0, idx, "D_VOL", send.volume)
                    SetTrackSendInfo_Value(track, 0, idx, "D_PAN", send.pan)
                    SetTrackSendInfo_Value(track, 0, idx, "B_MUTE", send.mute)
                    if rcmaster_guid and send.dest_guid == rcmaster_guid then
                        has_rcm = true
                    end
                end
            end
        end
        if M.is_special_track(track) then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect",
                has_rcm and "" or "y", true)
        end
        if state.hw_outs then
            local hw_n = GetTrackNumSends(track, 1)
            for i = 0, math.min(hw_n - 1, #state.hw_outs) do
                if state.hw_outs[i] then
                    SetTrackSendInfo_Value(track, 1, i, "D_VOL", state.hw_outs[i].volume)
                    SetTrackSendInfo_Value(track, 1, i, "D_PAN", state.hw_outs[i].pan)
                    SetTrackSendInfo_Value(track, 1, i, "B_MUTE", state.hw_outs[i].mute)
                end
            end
        end
    end
end

function M.recall_snapshot(snapshot, flags)
    if not snapshot then return end
    for i, state in pairs(snapshot.tracks) do
        local track
        if state.guid then
            track = M.find_track_by_guid(state.guid)
        else
            local candidate = GetTrack(0, i)
            if candidate and M.is_special_track(candidate) then track = candidate end
        end
        if track then
            M.apply_track_state(track, state, flags)
        end
    end
    UpdateArrange()
    TrackList_AdjustWindows(false)
end

return M
