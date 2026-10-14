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
local say = require("ReaClassical_Announce")
local engine = require("ReaClassical_Snapshot_Engine")

set_action_options(1)

if GetExtState("ReaClassical", "MixerSnapDaemonRunning") == "1" then
    SetExtState("ReaClassical", "MixerSnapDaemonRunning", "0", false)
    say("Mixer snapshot daemon stopped")
    return
end
SetExtState("ReaClassical", "MixerSnapDaemonRunning", "1", false)
say("Mixer snapshot daemon started")

local deserialize_table = engine.deserialize_table
local recall_snapshot = engine.recall_snapshot

local function find_by_item_guid(snaps, guid)
    for _, s in ipairs(snaps) do
        if s.item_guid == guid then return s end
    end
    return nil
end

local find_at_cursor              = engine.find_snapshot_at_cursor
local find_snapshot_with_gap_logic = engine.find_snapshot_with_gap_logic

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
            }
        end
    end
    return {}, {
        volume=true, pan=true, mute=true, solo=true, phase=true,
        width=true, fx=true, sends=true, routing=true,
        disable_auto_recall=false,
        switch_mid_gap=true,
    }
end

local current_bank        = get_current_bank()
local snapshots, flags    = load_bank(current_bank)
local selected_snap       = nil
local last_item_guid      = nil
local last_cursor_pos     = -1
local last_play_pos       = -1
local is_playing_state    = false
local last_project        = EnumProjects(-1)
local reload_counter      = 0
local RELOAD_EVERY        = 200

local function check_auto_recall()
    reload_counter = reload_counter + 1
    if reload_counter >= RELOAD_EVERY then
        reload_counter = 0
        local new_bank = get_current_bank()
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
            last_cursor_pos = cursor
            local snap = find_at_cursor(snapshots, cursor)
            if snap and snap ~= selected_snap then
                recall_snapshot(snap, flags)
                selected_snap = snap
            end
        end
    end
end

local function main()
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
