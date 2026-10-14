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

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()
if _clara_or_debug then
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    dofile(script_path .. "lib/ReaClassical_Accessible Peak and Overs Check.lua")
    return
end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local humanize_track_name = require("ReaClassical_Track_Naming")
local say = require("ReaClassical_Announce")

local main, scan, scan_item, format_pos, go_to, is_rcmaster, chain_gain

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

local ImGui, ctx

if not _G.RC_SCRIPT_ARGS then
    local imgui_exists = APIExists("ImGui_GetVersion")
    if not imgui_exists then
        MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
        return
    end

    set_action_options(2)

    package.path = ImGui_GetBuiltinPath() .. '/?.lua'
    ImGui = require 'imgui' '0.10'

    ctx = ImGui.CreateContext('ReaClassical Peak and Overs Check')
end

local PEAK_RATE = 100
local MERGE_GAP = 0.3
local MAX_OVERS = 500
local LN10 = math.log(10)

local MAX_PEAK_ARRAY_ELEMENTS = 16000

local _, saved_threshold = GetProjExtState(0, "ReaClassical", "PeaksThreshold")
local threshold = tonumber(saved_threshold) or -1.0
local scanned = false
local overs = {}
local state = {}

function format_pos(pos)
    return format_timestr_pos(pos, "", 0)
end

function go_to(pos, track)
    SetEditCurPos(pos, true, false)
    SetOnlyTrackSelected(track)
    Main_OnCommand(40913, 0)
end

function is_rcmaster(track)
    local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return rcmaster_state == "y" or name:find("^RCMASTER") ~= nil
end

function chain_gain(track, path)
    path = path or {}
    if path[track] then return 0 end

    if GetMediaTrackInfo_Value(track, "B_MUTE") == 1 then
        return 0
    end

    if is_rcmaster(track) then
        return 1.0
    end

    local next_path = {}
    for k in pairs(path) do next_path[k] = true end
    next_path[track] = true

    local own_vol = GetMediaTrackInfo_Value(track, "D_VOL")
    local downstream

    local num_sends = GetTrackNumSends(track, 0)
    for s = 0, num_sends - 1 do
        local dest = BR_GetMediaTrackSendInfo_Track(track, 0, s, 1)
        if dest then
            local send_vol = GetTrackSendInfo_Value(track, 0, s, "D_VOL")
            local g = send_vol * chain_gain(dest, next_path)
            if not downstream or g > downstream then downstream = g end
        end
    end

    if GetMediaTrackInfo_Value(track, "B_MAINSEND") == 1 then
        local parent = GetParentTrack(track)
        if parent then
            local g = chain_gain(parent, next_path)
            if not downstream or g > downstream then downstream = g end
        end
    end

    if not downstream then
        return own_vol
    end

    return own_vol * downstream
end

function scan_item(item, track, track_name, track_gain)
    local take = GetActiveTake(item)
    if not take or TakeIsMIDI(take) then return end

    local source = GetMediaItemTake_Source(take)
    if not source then return end

    local num_channels = math.max(1, GetMediaSourceNumChannels(source))
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
    local playrate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    local start_offs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local item_vol = GetMediaItemInfo_Value(item, "D_VOL")
    local take_vol = GetMediaItemTakeInfo_Value(take, "D_VOL")
    local gain = item_vol * take_vol * track_gain

    local vol_env = GetTakeEnvelopeByName(take, "Volume")
    local br_vol_env = vol_env and APIExists("CF_GetSWSVersion") and BR_EnvAlloc(vol_env, false) or nil

    if playrate <= 0 or item_len <= 0 then
        if br_vol_env then BR_EnvFree(br_vol_env, false) end
        return
    end

    local total_samples = math.floor(item_len * playrate * PEAK_RATE + 0.5)
    if total_samples < 1 then
        if br_vol_env then BR_EnvFree(br_vol_env, false) end
        return
    end

    local chunk_samples = math.max(1, math.floor(MAX_PEAK_ARRAY_ELEMENTS / (2 * num_channels)))
    local buf = new_array(2 * chunk_samples * num_channels)

    local samples_done = 0
    while samples_done < total_samples do
        local this_count = math.min(chunk_samples, total_samples - samples_done)
        local chunk_start_offs = start_offs + samples_done / PEAK_RATE
        local frame_count = num_channels * this_count
        local retval = PCM_Source_GetPeaks(source, PEAK_RATE, chunk_start_offs, num_channels, this_count, 0, buf)
        local vals = buf.table(1, 2 * frame_count)

        local returned = retval & 0xFFFFF
        if returned <= 0 or returned > this_count then
            returned = this_count
        end

        for f = 1, returned do
            local peak = 0
            local base = (f - 1) * num_channels
            for c = 1, num_channels do
                local idx = base + c
                local v = math.max(math.abs(vals[idx]), math.abs(vals[frame_count + idx]))
                if v > peak then peak = v end
            end

            local abs_f = samples_done + f
            local pos = item_pos + (abs_f - 1) / (PEAK_RATE * playrate)
            local env_gain = br_vol_env and BR_EnvValueAtPos(br_vol_env, pos) or 1.0
            peak = peak * gain * env_gain

            local db = peak > 0 and (20 * math.log(peak) / LN10) or -150

            if not state.peak_db or db > state.peak_db then
                state.peak_db = db
                state.peak_pos = pos
                state.peak_track = track
                state.peak_track_name = track_name
            end

            if db >= threshold then
                local last = overs[#overs]
                if last and last.track == track and (pos - last.last_pos) <= MERGE_GAP then
                    last.last_pos = pos
                    if db > last.db then
                        last.db = db
                        last.pos = pos
                    end
                elseif #overs < MAX_OVERS then
                    overs[#overs + 1] = { pos = pos, db = db, last_pos = pos, track = track, track_name = track_name }
                end
            end
        end

        samples_done = samples_done + this_count
    end

    if br_vol_env then BR_EnvFree(br_vol_env, false) end
end

function scan()
    overs = {}
    state = {}

    local num_tracks = CountTracks(0)
    for t = 0, num_tracks - 1 do
        local track = GetTrack(0, t)
        if track and GetMediaTrackInfo_Value(track, "B_MUTE") == 0 then
            local num_items = CountTrackMediaItems(track)
            if num_items > 0 then
                local _, track_name = GetTrackName(track)
                track_name = humanize_track_name(track_name)
                local track_gain = chain_gain(track)
                for i = 0, num_items - 1 do
                    local item = GetTrackMediaItem(track, i)
                    if item then
                        scan_item(item, track, track_name, track_gain)
                    end
                end
            end
        end
    end

    scanned = true
end

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    ImGui.SetNextWindowSize(ctx, 340, 420, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, 'ReaClassical Peak and Overs Check', true)

    if visible then
        ImGui.Text(ctx, "Scans all unmuted tracks containing items")
        ImGui.Spacing(ctx)

        ImGui.Text(ctx, "Over threshold (dB):")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_t, new_t = ImGui.SliderDouble(ctx, "##threshold", threshold, -20.0, 0.0, "%.1f dB",
            ImGui.SliderFlags_AlwaysClamp)
        if changed_t then
            threshold = new_t
            SetProjExtState(0, "ReaClassical", "PeaksThreshold", tostring(threshold))
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Ctrl+click to type a precise value")
        end

        if ImGui.Button(ctx, "Re-scan", -1, 0) then
            scan()
        end

        ImGui.Separator(ctx)

        if scanned then
            if state.peak_db then
                ImGui.Text(ctx, string.format("Peak level: %.2f dB @ %s (%s)",
                    state.peak_db, format_pos(state.peak_pos), state.peak_track_name))
                ImGui.SameLine(ctx)
                if ImGui.SmallButton(ctx, "Go to Peak") then
                    go_to(state.peak_pos, state.peak_track)
                end
            else
                ImGui.Text(ctx, "No audio found on unmuted tracks.")
            end

            ImGui.Spacing(ctx)
            ImGui.Text(ctx, string.format("Overs (>= %.1f dB): %d", threshold, #overs))
            if #overs >= MAX_OVERS then
                ImGui.TextWrapped(ctx, "(list truncated at " .. MAX_OVERS .. " entries)")
            end

            if #overs > 0 then
                if ImGui.BeginChild(ctx, "overs_list", -1, 150, ImGui.ChildFlags_Borders) then
                    for i, o in ipairs(overs) do
                        ImGui.Text(ctx, string.format("%.2f dB @ %s (%s)", o.db, format_pos(o.pos), o.track_name))
                        ImGui.SameLine(ctx)
                        if ImGui.SmallButton(ctx, "Go to##over" .. i) then
                            go_to(o.pos, o.track)
                        end
                    end
                    ImGui.EndChild(ctx)
                end
            end
        else
            ImGui.Text(ctx, "Click 'Re-scan' to analyse.")
        end

        if gui_mode.imgui_close_shortcut(ImGui, ctx) then open = false end
        ImGui.End(ctx)
    end

    if open then
        defer(main)
    end
end

if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.threshold then
    threshold = _G.RC_SCRIPT_ARGS.threshold
    SetProjExtState(0, "ReaClassical", "PeaksThreshold", tostring(threshold))
end

scan()

if _G.RC_SCRIPT_ARGS then
    if _G.RC_SCRIPT_ARGS.jump_to_peak and state.peak_db then
        go_to(state.peak_pos, state.peak_track)
    end
    return {
        peak_db         = state.peak_db,
        peak_pos        = state.peak_pos,
        peak_track      = state.peak_track,
        peak_track_name = state.peak_track_name,
        overs           = overs,
        threshold       = threshold,
        max_overs       = MAX_OVERS,
    }
end

defer(main)
