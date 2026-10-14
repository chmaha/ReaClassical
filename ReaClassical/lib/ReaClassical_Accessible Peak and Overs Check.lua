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
local parent_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local enum_project_markers = require("ReaClassical_Marker_Enum")
local ui_input = require("ReaClassical_Accessible_Input")

set_action_options(3)

local WINDOW_TITLE = "Peak and Overs Check"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_SPACE = 32
local KEY_M_LO, KEY_M_HI = 109, 77

local MIN_THRESHOLD, MAX_THRESHOLD = -20.0, 0.0
local DEFAULT_THRESHOLD = -1.0

local AUDITION_ROLL = 2.0

local last_result = { overs = {} }

local function get_threshold()
    local _, saved = GetProjExtState(0, "ReaClassical", "PeaksThreshold")
    return tonumber(saved) or DEFAULT_THRESHOLD
end

local function seek_to(pos, track)
    SetEditCurPos(pos, false, false)
    SetOnlyTrackSelected(track)
    Main_OnCommand(40913, 0)
end

local function announce_scan_result(result)
    local parts = {}
    if result.peak_db then
        parts[#parts + 1] = string.format("Peak: %.2f dB at %s (%s).",
            result.peak_db, format_timestr_pos(result.peak_pos, "", 0), result.peak_track_name)
    else
        parts[#parts + 1] = "No audio found on unmuted tracks."
    end
    local n = #result.overs
    local over_msg = string.format("%d over%s found", n, n == 1 and "" or "s")
    if n >= result.max_overs then over_msg = over_msg .. " (list truncated)" end
    parts[#parts + 1] = over_msg .. "."
    say(table.concat(parts, " "))
end

local function run_scan(new_threshold)
    _G.RC_SCRIPT_ARGS = { jump_to_peak = true }
    if new_threshold then _G.RC_SCRIPT_ARGS.threshold = new_threshold end
    last_result = dofile(parent_path .. "ReaClassical_Peak and Overs Check.lua")
    _G.RC_SCRIPT_ARGS = nil
    announce_scan_result(last_result)
end

local IDX_THRESHOLD, IDX_RESCAN, IDX_OVERS = 1, 2, 3
local field_idx = 1
local last_char = 0

local function label(i)
    if i == IDX_THRESHOLD then return "Over Threshold" end
    if i == IDX_RESCAN then return "Rescan" end
    return "Overs"
end

local function value_label(i)
    if i == IDX_THRESHOLD then return string.format("%.1f dB", get_threshold()) end
    if i == IDX_OVERS then return "(" .. #last_result.overs .. ")" end
    return ""
end

local function announce_field(i)
    local val = value_label(i)
    say(label(i) .. (val ~= "" and (": " .. val) or ""))
end

local function apply_threshold(str)
    local num = tonumber(str)
    if not num then return "Please enter a number" end
    if num < MIN_THRESHOLD or num > MAX_THRESHOLD then
        return string.format("Must be between %.0f and %.0f", MIN_THRESHOLD, MAX_THRESHOLD)
    end
    run_scan(num)
    return nil
end

local STATE_MAIN, STATE_BROWSE = "main", "browse"
local state       = STATE_MAIN
local browse_idx  = 1
local auditioning = false
local audition_pos = nil

local function stop_audition()
    Main_OnCommand(1016, 0)
    if audition_pos then SetEditCurPos(audition_pos, false, false) end
    auditioning = false
end

local function start_audition(pos)
    audition_pos = pos
    SetEditCurPos(math.max(0, pos - AUDITION_ROLL), false, false)
    Main_OnCommand(1007, 0)
    auditioning = true
end

local function poll_audition()
    if not auditioning then return end
    if GetPlayState() == 0 then
        auditioning = false
        return
    end
    if GetPlayPosition() >= audition_pos + AUDITION_ROLL then
        stop_audition()
    end
end

local OVER_MARKER_COLOR = ColorToNative(220, 50, 50) | 0x1000000
local PEAK_MARKER_COLOR = ColorToNative(230, 170, 20) | 0x1000000

local MARKER_POS_EPSILON = 0.01

local function marker_exists_at(pos, name)
    if not APIExists("GetNumRegionsOrMarkers") then return false end
    local proj = 0
    for i = 0, GetNumRegionsOrMarkers(proj) - 1 do
        local retval, isrgn, mpos, _, mname = enum_project_markers(proj, i)
        if retval and not isrgn and mname == name and math.abs(mpos - pos) < MARKER_POS_EPSILON then
            return true
        end
    end
    return false
end

local function add_marker(pos, name, color)
    if marker_exists_at(pos, name) then
        say("Marker already exists")
        return
    end
    AddProjectMarker2(0, false, pos, 0, name, -1, color)
    say("Marker added")
end

local function mark_peak()
    if not last_result.peak_pos then
        say("No peak to mark")
        return
    end
    add_marker(last_result.peak_pos,
        string.format("Peak: %.2f dB (%s)", last_result.peak_db, last_result.peak_track_name),
        PEAK_MARKER_COLOR)
end

local function mark_over(i)
    local o = last_result.overs[i]
    add_marker(o.pos, string.format("Over: %.2f dB (%s)", o.db, o.track_name), OVER_MARKER_COLOR)
end

local function announce_over(i, with_hint)
    local o = last_result.overs[i]
    local msg = string.format("%d of %d: %.2f dB at %s (%s)",
        i, #last_result.overs, o.db, format_timestr_pos(o.pos, "", 0), o.track_name)
    if with_hint then
        msg = msg .. ". Up or down to browse, Space to audition, M to mark, Escape to go back."
    end
    say(msg)
end

local function enter_browse_overs()
    if #last_result.overs == 0 then
        say("No overs to browse")
        return
    end
    state = STATE_BROWSE
    browse_idx = 1
    seek_to(last_result.overs[1].pos, last_result.overs[1].track)
    announce_over(1, true)
end

local function handle_browse_key(char)
    if char == KEY_UP then
        if auditioning then stop_audition() end
        browse_idx = browse_idx > 1 and browse_idx - 1 or #last_result.overs
        seek_to(last_result.overs[browse_idx].pos, last_result.overs[browse_idx].track)
        announce_over(browse_idx, false)
    elseif char == KEY_DOWN then
        if auditioning then stop_audition() end
        browse_idx = browse_idx < #last_result.overs and browse_idx + 1 or 1
        seek_to(last_result.overs[browse_idx].pos, last_result.overs[browse_idx].track)
        announce_over(browse_idx, false)
    elseif char == KEY_SPACE then
        if auditioning then
            stop_audition()
        else
            say("Auditioning")
            start_audition(last_result.overs[browse_idx].pos)
        end
    elseif char == KEY_M_LO or char == KEY_M_HI then
        mark_over(browse_idx)
    elseif char == KEY_ESC then
        if auditioning then stop_audition() end
        state = STATE_MAIN
        announce_field(IDX_OVERS)
    end
    return true
end

local function handle_key(char)
    if state == STATE_BROWSE then return handle_browse_key(char) end

    if char == KEY_UP then
        if auditioning then stop_audition() end
        field_idx = field_idx > 1 and field_idx - 1 or IDX_OVERS
        announce_field(field_idx)
    elseif char == KEY_DOWN then
        if auditioning then stop_audition() end
        field_idx = field_idx < IDX_OVERS and field_idx + 1 or 1
        announce_field(field_idx)
    elseif char == KEY_ENTER then
        if auditioning then stop_audition() end
        if field_idx == IDX_THRESHOLD then
            local value = string.format("%.1f", get_threshold())
            while true do
                local ok, entered = ui_input.ask(WINDOW_TITLE, "Over Threshold",
                    "Threshold in dB, minus " .. math.abs(MIN_THRESHOLD) .. " to 0", value)
                if not ok then
                    say("Cancelled")
                    break
                end
                local err = apply_threshold(entered)
                if not err then break end
                say(err .. ". Correct it or Cancel")
                value = entered
            end
        elseif field_idx == IDX_RESCAN then
            run_scan()
        else
            enter_browse_overs()
        end
    elseif char == KEY_SPACE then
        if not last_result.peak_pos then
            say("No peak to audition")
        elseif auditioning then
            stop_audition()
        else
            say("Auditioning peak")
            start_audition(last_result.peak_pos)
        end
    elseif char == KEY_M_LO or char == KEY_M_HI then
        mark_peak()
    elseif char == KEY_ESC then
        if auditioning then stop_audition() end
        return false
    end
    return true
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_BROWSE then
        local o = last_result.overs[browse_idx]
        local txt = o and string.format("[Over %d of %d]  %.2f dB @ %s (%s)",
            browse_idx, #last_result.overs, o.db, format_timestr_pos(o.pos, "", 0), o.track_name)
            or "[Overs]"
        gfx.drawstr(txt)
    else
        local val = value_label(field_idx)
        gfx.drawstr("[" .. label(field_idx) .. "]" .. (val ~= "" and ("  " .. val) or ""))
    end
    gfx.update()
end

local function main()
    poll_audition()
    local char = gfx.getchar()
    if char == -1 then gfx.quit() return end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        if not handle_key(char) then
            gfx.quit()
            return
        end
    end
    draw_window()
    defer(main)
end

local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
if wf == "" then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

run_scan()

gfx.init(WINDOW_TITLE, 500, 44, 0)
say(string.format(
    "%s: %s. Up or down to move, Enter to edit, rescan, or browse overs, "
    .. "Space to audition the peak, M to mark it, Escape to close.",
    label(1), value_label(1)))

defer(main)
