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
local peak_scan = require("ReaClassical_Peak_Scan")

local main, scan, scan_item, format_pos, go_to

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

local MERGE_GAP = 0.3
local MAX_OVERS = 500

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

function scan_item(item, track, track_name, track_gain)
    if not track_gain then return end
    peak_scan.scan_item(item, track_gain, function(pos, db)
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
    end)
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
                local track_gain = peak_scan.chain_gain(track)
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
        ImGui.Text(ctx, "Scans all unmuted tracks containing items (levels before effects)")
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
                ImGui.Text(ctx, string.format("Peak before effects: %.2f dB @ %s (%s)",
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
