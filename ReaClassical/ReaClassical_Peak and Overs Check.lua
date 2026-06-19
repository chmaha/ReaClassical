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

-- ReaImGui windows are unusable/distracting for a blind user relying on
-- OSARA + the Terminal instead of the mouse, so skip opening this GUI when
-- OSARA is installed unless allowgui=y has been set in the Terminal. Calls
-- coming from the Terminal itself (_G.RC_TERMINAL_ARGS set) always bypass
-- this -- they never open a GUI in the first place.
if not _G.RC_TERMINAL_ARGS and APIExists("osara_outputMessage") and GetExtState("ReaClassical", "AllowGui") ~= "y" then
    osara_outputMessage("GUI blocked (OSARA detected) -- use allowgui=y in the Terminal to override")
    return
end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local humanize_track_name = require("ReaClassical_Track_Naming")
local say = require("ReaClassical_Announce")

local main, scan, scan_item, format_pos, go_to, is_rcmaster, chain_gain

---------------------------------------------------------------------

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

if not _G.RC_TERMINAL_ARGS then
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

local PEAK_RATE = 100  -- peak samples per second analysed (~10ms resolution)
local MERGE_GAP = 0.3  -- seconds; nearby overs are merged into one entry
local MAX_OVERS = 500  -- safety cap on number of reported overs
local LN10 = math.log(10)

local _, saved_threshold = GetProjExtState(0, "ReaClassical", "PeaksThreshold")
local threshold = tonumber(saved_threshold) or -1.0
local scanned = false
local overs = {}
local state = {}

---------------------------------------------------------------------

function format_pos(pos)
    return format_timestr_pos(pos, "", 0)
end

---------------------------------------------------------------------

function go_to(pos, track)
    SetEditCurPos(pos, true, false)
    SetOnlyTrackSelected(track)
    Main_OnCommand(40913, 0) -- vertical scroll selected tracks into view
end

---------------------------------------------------------------------

function is_rcmaster(track)
    local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return rcmaster_state == "y" or name:find("^RCMASTER") ~= nil
end

---------------------------------------------------------------------

-- Multiplies a track's own fader with the fader(s) of whatever it routes
-- to (sends and/or parent folder), stopping at RCMASTER (its own fader is
-- excluded so the result reflects levels arriving AT the mix bus).
-- `path` tracks the current routing chain to guard against send loops.
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
        return own_vol -- no further routing info; use track's own fader only
    end

    return own_vol * downstream
end

---------------------------------------------------------------------

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
    local gain = GetMediaItemTakeInfo_Value(take, "D_VOL") * track_gain

    if playrate <= 0 or item_len <= 0 then return end

    local num_samples = math.floor(item_len * playrate * PEAK_RATE + 0.5)
    if num_samples < 1 then return end

    -- buf layout is two interleaved blocks: maximums, then minimums
    local frame_count = num_channels * num_samples
    local buf = new_array(2 * frame_count)
    local retval = PCM_Source_GetPeaks(source, PEAK_RATE, start_offs, num_channels, num_samples, 0, buf)
    local vals = buf.table(1, 2 * frame_count)

    local returned = retval & 0xFFFFF
    if returned <= 0 or returned > num_samples then
        returned = num_samples
    end

    for f = 1, returned do
        local peak = 0
        local base = (f - 1) * num_channels
        for c = 1, num_channels do
            local idx = base + c
            local v = math.max(math.abs(vals[idx]), math.abs(vals[frame_count + idx]))
            if v > peak then peak = v end
        end
        peak = peak * gain

        local db = peak > 0 and (20 * math.log(peak) / LN10) or -150
        local pos = item_pos + (f - 1) / (PEAK_RATE * playrate)

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
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

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

        ImGui.End(ctx)
    end

    if open then
        defer(main)
    end
end

---------------------------------------------------------------------

if _G.RC_TERMINAL_ARGS and _G.RC_TERMINAL_ARGS.threshold then
    threshold = _G.RC_TERMINAL_ARGS.threshold
    SetProjExtState(0, "ReaClassical", "PeaksThreshold", tostring(threshold))
end

scan()

if _G.RC_TERMINAL_ARGS then
    local lines = {}
    if state.peak_db then
        lines[#lines + 1] = string.format("Peak level: %.2f dB @ %s (%s)",
            state.peak_db, format_pos(state.peak_pos), state.peak_track_name)
        if _G.RC_TERMINAL_ARGS.jump_to_peak then
            go_to(state.peak_pos, state.peak_track)
        end
    else
        lines[#lines + 1] = "No audio found on unmuted tracks."
    end
    lines[#lines + 1] = string.format("Overs (>= %.1f dB): %d", threshold, #overs)
    if #overs >= MAX_OVERS then
        lines[#lines + 1] = "(list truncated at " .. MAX_OVERS .. " entries)"
    end
    for _, o in ipairs(overs) do
        lines[#lines + 1] = string.format("  %.2f dB @ %s (%s)", o.db, format_pos(o.pos), o.track_name)
    end
    say(table.concat(lines, "\n"))
    return
end

defer(main)