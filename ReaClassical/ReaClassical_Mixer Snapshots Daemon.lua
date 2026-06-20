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

-- Headless Mixer Snapshot auto-recall daemon.
-- Run once to start; run again to stop (toggle via set_action_options(1)).
-- Provides the same cursor/playback-position auto-recall as the GUI window,
-- but without requiring ImGui or the Mixer Snapshots GUI to be open.
-- Snapshot data is read from the same project ext state used by the GUI,
-- so both can coexist (run one OR the other for auto-recall, not both).

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")

set_action_options(1) -- re-running this script stops the daemon

if GetExtState("ReaClassical", "MixerSnapDaemonRunning") == "1" then
    SetExtState("ReaClassical", "MixerSnapDaemonRunning", "0", false)
    say("Mixer snapshot daemon stopped")
    return
end
SetExtState("ReaClassical", "MixerSnapDaemonRunning", "1", false)
say("Mixer snapshot daemon started")

---------------------------------------------------------------------
-- Helpers (mirror of ReaClassical_Terminal.lua snap_* functions and
-- the non-ImGui parts of ReaClassical_Mixer Snapshots.lua)
---------------------------------------------------------------------

local function is_special_track(track)
    local _, mixer = GetSetMediaTrackInfo_String(track, "P_EXT:mixer",  "", false)
    local _, aux   = GetSetMediaTrackInfo_String(track, "P_EXT:aux",    "", false)
    local _, sub   = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
    return mixer == "y" or aux == "y" or sub == "y"
end

local function find_track_by_guid(guid)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetTrackGUID(t) == guid then return t end
    end
    return nil
end

local function get_item_by_guid(guid)
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        if BR_GetMediaItemGUID(item) == guid then return item end
    end
    return nil
end

local function deserialize_table(str)
    if not str or str == "" then return nil end
    local func = load("return " .. str)
    return func and func() or nil
end

local function apply_track_state(track, state, flags)
    if not track then return end
    if flags.volume then SetMediaTrackInfo_Value(track, "D_VOL",   state.volume) end
    if flags.pan    then SetMediaTrackInfo_Value(track, "D_PAN",   state.pan)    end
    if flags.mute   then SetMediaTrackInfo_Value(track, "B_MUTE",  state.mute)   end
    if flags.solo   then SetMediaTrackInfo_Value(track, "I_SOLO",  state.solo)   end
    if flags.phase  then SetMediaTrackInfo_Value(track, "B_PHASE", state.phase)  end
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
                SetTrackSendInfo_Value(track, 0, i, "D_VOL",  send.volume)
                SetTrackSendInfo_Value(track, 0, i, "D_PAN",  send.pan)
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
            if rcs == "y" then rcmaster_guid = GetTrackGUID(tr); break end
        end
        local has_rcm = false
        for _, send in pairs(state.sends) do
            local dst = find_track_by_guid(send.dest_guid)
            if dst then
                local idx = CreateTrackSend(track, dst)
                if idx >= 0 then
                    SetTrackSendInfo_Value(track, 0, idx, "D_VOL",  send.volume)
                    SetTrackSendInfo_Value(track, 0, idx, "D_PAN",  send.pan)
                    SetTrackSendInfo_Value(track, 0, idx, "B_MUTE", send.mute)
                    if rcmaster_guid and send.dest_guid == rcmaster_guid then
                        has_rcm = true
                    end
                end
            end
        end
        if is_special_track(track) then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect",
                has_rcm and "" or "y", true)
        end
        if state.hw_outs then
            local hw_n = GetTrackNumSends(track, 1)
            for i = 0, math.min(hw_n - 1, #state.hw_outs) do
                if state.hw_outs[i] then
                    SetTrackSendInfo_Value(track, 1, i, "D_VOL",  state.hw_outs[i].volume)
                    SetTrackSendInfo_Value(track, 1, i, "D_PAN",  state.hw_outs[i].pan)
                    SetTrackSendInfo_Value(track, 1, i, "D_MUTE", state.hw_outs[i].mute)
                end
            end
        end
    end
end

local function recall_snapshot(snapshot, flags)
    if not snapshot then return end
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if is_special_track(track) and snapshot.tracks[i] then
            apply_track_state(track, snapshot.tracks[i], flags)
        end
    end
    UpdateArrange()
    TrackList_AdjustWindows(false)
end

local function find_by_item_guid(snaps, guid)
    for _, s in ipairs(snaps) do
        if s.item_guid == guid then return s end
    end
    return nil
end

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

local function get_current_bank()
    local _, bank = GetProjExtState(0, "MixerSnapshots", "current_bank")
    return (bank ~= "") and bank or "A"
end

local function load_bank(bank)
    local retval, str = GetProjExtState(0, "MixerSnapshots", "data_" .. bank)
    if retval > 0 and str ~= "" then
        local data = deserialize_table(str)
        if data then
            return data.snapshots or {}, {
                volume  = data.recall_volume  ~= false,
                pan     = data.recall_pan     ~= false,
                mute    = data.recall_mute    ~= false,
                solo    = data.recall_solo    ~= false,
                phase   = data.recall_phase   ~= false,
                width   = data.recall_width   ~= false,
                fx      = data.recall_fx      ~= false,
                sends   = data.recall_sends   ~= false,
                routing = data.recall_routing ~= false,
                disable_auto_recall   = data.disable_auto_recall or false,
                switch_mid_gap        = data.switch_mid_gap ~= false,
                bank_folder_selection = data.bank_folder_selection or "all",
            }
        end
    end
    return {}, {
        volume=true, pan=true, mute=true, solo=true, phase=true,
        width=true, fx=true, sends=true, routing=true,
        disable_auto_recall=false,
        switch_mid_gap=true,
        bank_folder_selection="all",
    }
end

---------------------------------------------------------------------
-- Daemon state
---------------------------------------------------------------------

local current_bank        = get_current_bank()
local snapshots, flags    = load_bank(current_bank)
local selected_snap       = nil
local last_item_guid      = nil
local last_cursor_pos     = -1
local last_play_pos       = -1
local is_playing_state    = false
local last_project        = EnumProjects(-1)
local reload_counter      = 0
local RELOAD_EVERY        = 200 -- ticks (~2-3 s at typical defer rates)

local function find_snapshot_with_gap_logic(snaps, cursor_pos, smg)
    if not smg then
        return find_at_cursor(snaps, cursor_pos)
    end

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

    -- Build sorted list of items that have snapshots
    local snapshot_items = {}
    for i = 0, CountMediaItems(0) - 1 do
        local item       = GetMediaItem(0, i)
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_guid  = BR_GetMediaItemGUID(item)
        if find_by_item_guid(snaps, item_guid) then
            table.insert(snapshot_items, { item = item, start = item_start, guid = item_guid })
        end
    end
    table.sort(snapshot_items, function(a, b) return a.start < b.start end)

    -- Identify the folder tracks for the previous and next snapshots
    local prev_snap_folder = nil
    local next_snap_folder = nil

    for i = #snapshot_items, 1, -1 do
        if snapshot_items[i].start <= cursor_pos then
            local ps = find_by_item_guid(snaps, snapshot_items[i].guid)
            local pi = ps and get_item_by_guid(ps.item_guid)
            if pi then prev_snap_folder = GetMediaItem_Track(pi) end
            break
        end
    end

    for _, sd in ipairs(snapshot_items) do
        if sd.start > cursor_pos then
            local ns = find_by_item_guid(snaps, sd.guid)
            local ni = ns and get_item_by_guid(ns.item_guid)
            if ni then next_snap_folder = GetMediaItem_Track(ni) end
            break
        end
    end

    -- Check whether cursor sits on an item in the prev/next snapshot folder
    local cursor_on_relevant_item = false
    for i = 0, CountMediaItems(0) - 1 do
        local item       = GetMediaItem(0, i)
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end   = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")
        if cursor_pos >= item_start and cursor_pos < item_end then
            local item_track = GetMediaItem_Track(item)
            if (prev_snap_folder and is_track_in_folder(item_track, prev_snap_folder)) or
               (next_snap_folder and is_track_in_folder(item_track, next_snap_folder)) then
                cursor_on_relevant_item = true
                break
            end
        end
    end

    if cursor_on_relevant_item then
        return find_at_cursor(snaps, cursor_pos)
    end

    -- Cursor is in a gap — find the next snapshot and its item start
    local next_snap            = nil
    local next_snap_item_start = math.huge
    for _, sd in ipairs(snapshot_items) do
        if sd.start > cursor_pos then
            local s = find_by_item_guid(snaps, sd.guid)
            if s then
                next_snap            = s
                next_snap_item_start = sd.start
                break
            end
        end
    end

    -- Find the last item end within the previous snapshot's folder
    local last_item_end_in_prev_folder = -1
    if prev_snap_folder then
        for i = 0, CountMediaItems(0) - 1 do
            local item       = GetMediaItem(0, i)
            local item_track = GetMediaItem_Track(item)
            if is_track_in_folder(item_track, prev_snap_folder) then
                local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_end   = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")
                if item_end < next_snap_item_start and item_end > last_item_end_in_prev_folder then
                    last_item_end_in_prev_folder = item_end
                end
            end
        end
    end

    -- Use midpoint logic if we have both a prev and next snapshot
    if next_snap and last_item_end_in_prev_folder >= 0 and
       last_item_end_in_prev_folder < next_snap_item_start then
        local gap_mid = last_item_end_in_prev_folder +
            (next_snap_item_start - last_item_end_in_prev_folder) / 2
        if cursor_pos >= gap_mid and cursor_pos < next_snap_item_start then
            return next_snap
        end
    end

    return find_at_cursor(snaps, cursor_pos)
end

---------------------------------------------------------------------

local function check_auto_recall()
    -- Periodically reload in case terminal commands changed the data
    reload_counter = reload_counter + 1
    if reload_counter >= RELOAD_EVERY then
        reload_counter = 0
        local new_bank = get_current_bank()
        -- Always reload (picks up snap+/snap-/snapar= changes from terminal)
        current_bank = new_bank
        snapshots, flags = load_bank(current_bank)
    end

    if flags.disable_auto_recall then return end
    if #snapshots == 0 then return end

    local play_state    = GetPlayState()
    local now_playing   = (play_state & 1) == 1

    if now_playing then
        local play_pos = GetPlayPosition()
        if math.abs(play_pos - last_play_pos) > 0.001 then
            last_play_pos = play_pos
            local snap = find_snapshot_with_gap_logic(snapshots, play_pos, flags.switch_mid_gap)
            if snap and snap ~= selected_snap then
                recall_snapshot(snap, flags)
                selected_snap = snap
            end
        end
        is_playing_state = true
    else
        local item      = GetSelectedMediaItem(0, 0)
        local item_guid = item and BR_GetMediaItemGUID(item) or nil
        local cursor    = GetCursorPosition()

        if is_playing_state then
            -- Playback just stopped — sync to edit cursor
            is_playing_state = false
            last_play_pos    = -1
            local snap = find_at_cursor(snapshots, cursor)
            if snap then
                recall_snapshot(snap, flags)
                selected_snap = snap
            end
            last_cursor_pos = cursor
            last_item_guid  = item_guid
        elseif item_guid ~= last_item_guid then
            -- Item selection changed
            last_item_guid = item_guid
            local snap
            if item_guid then
                snap = find_by_item_guid(snapshots, item_guid)
                    or find_at_cursor(snapshots, cursor)
            else
                snap = find_at_cursor(snapshots, cursor)
            end
            if snap then
                recall_snapshot(snap, flags)
                selected_snap = snap
            end
            last_cursor_pos = cursor
        elseif math.abs(cursor - last_cursor_pos) > 0.001 then
            -- Edit cursor moved
            last_cursor_pos = cursor
            local snap = find_at_cursor(snapshots, cursor)
            if snap and snap ~= selected_snap then
                recall_snapshot(snap, flags)
                selected_snap = snap
            end
        end
    end
end

---------------------------------------------------------------------

local function main()
    -- Reset on project change
    local proj = EnumProjects(-1)
    if proj ~= last_project then
        last_project      = proj
        current_bank      = get_current_bank()
        snapshots, flags  = load_bank(current_bank)
        selected_snap     = nil
        last_item_guid    = nil
        last_cursor_pos   = -1
        last_play_pos     = -1
        is_playing_state  = false
        reload_counter    = 0
    end

    SetProjExtState(0, "MixerSnapshots", "daemon_heartbeat", tostring(os.time()))
    check_auto_recall()
    defer(main)
end

defer(main)
