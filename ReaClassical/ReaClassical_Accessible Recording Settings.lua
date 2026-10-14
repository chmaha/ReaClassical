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

set_action_options(3)

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local record_daemon = require("ReaClassical_Record_Daemon")
local rec_settings = require("ReaClassical_Recording_Settings")
local ui_input = require("ReaClassical_Accessible_Input")

local WINDOW_TITLE = "Recording Settings"

if not (APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed) then
    local _, debug_str = GetProjExtState(0, "ReaClassical", "DebugAnnounce")
    if debug_str ~= "on" then
        MB("Accessible Recording Settings requires ReaClassical Clara (an accessibility bridge) to be installed.",
            "ReaClassical Error", 0)
        return
    end
end

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

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_BACK  = 8

local function daemon_running()
    return record_daemon.is_running()
end

local FIELDS = {}

FIELDS[#FIELDS + 1] = {
    label = "Session", kind = "text",
    value = function()
        local _, v = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        return v ~= "" and v or "(none)"
    end,
    edit_seed = function()
        local _, v = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        return v
    end,
    commit = function(text)
        if text == "" then
            say(string.format("Session cleared  (next take: T%03d)", rec_settings.clear_session()))
        else
            say(string.format("Session: %s  (next take: T%03d)", text, rec_settings.set_session(text)))
        end
    end,
    clear = function()
        say(string.format("Session cleared  (next take: T%03d)", rec_settings.clear_session()))
    end,
}

FIELDS[#FIELDS + 1] = {
    label = "Take", kind = "text",
    value = function()
        local _, take_str = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        local _, override = GetProjExtState(0, "ReaClassical", "TakeCounterOverride")
        local n = tonumber(take_str) or 0
        if n <= 0 then return "auto-detect" end
        return string.format("T%03d (%s)", n, override == "1" and "manual override" or "auto")
    end,
    edit_seed = function()
        local _, take_str = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        return take_str ~= "" and take_str or ""
    end,
    commit = function(text)
        if text == "" then
            say(string.format("Take: auto-detect  (next: T%03d)", rec_settings.set_take_auto()))
            return
        end
        local n = tonumber(text)
        local ok, max_found = rec_settings.set_take(n)
        if ok then
            say(string.format("Take set to T%03d (manual override)", n))
        else
            say(string.format("Cannot set take to %d — highest found is T%03d.", n, max_found))
        end
    end,
    clear = function()
        say(string.format("Take: auto-detect  (next: T%03d)", rec_settings.set_take_auto()))
    end,
}

local function time_field(label, spoken_label, ext_key, setter)
        return {
        label = label, kind = "text",
        value = function()
            local _, v = GetProjExtState(0, "ReaClassical", ext_key)
            return v ~= "" and v or "(none)"
        end,
        edit_seed = function()
            local _, v = GetProjExtState(0, "ReaClassical", ext_key)
            return v
        end,
        commit = function(text)
            if text == "" then
                rec_settings.clear_time()
                say("Recording time window cleared")
            elseif setter(text) then
                say(spoken_label .. ": " .. text)
            else
                say("Invalid format — use HH:MM")
            end
        end,
        clear = function()
            rec_settings.clear_time()
            say("Recording time window cleared")
        end,
    }
end

FIELDS[#FIELDS + 1] = time_field("Start Time", "Recording start", "Recording Start", rec_settings.set_start)
FIELDS[#FIELDS + 1] = time_field("End Time", "Recording end", "Recording End", rec_settings.set_end)
FIELDS[#FIELDS + 1] = time_field("Duration", "Recording duration", "Recording Duration", rec_settings.set_duration)

local function toggle_enabled(v, default_on)
    if default_on then return v ~= "0" end
    return v == "1"
end

local function toggle_field(label, ext_key, setter, spoken_label, default_on)
    return {
        label = label, kind = "toggle",
        value = function()
            local _, v = GetProjExtState(0, "ReaClassical", ext_key)
            local text = toggle_enabled(v, default_on) and "Yes" or "No"
            if v == "" then text = text .. " (default)" end
            return text
        end,
        toggle = function()
            local _, v = GetProjExtState(0, "ReaClassical", ext_key)
            local new_on = not toggle_enabled(v, default_on)
            setter(new_on)
            say(spoken_label .. ": " .. (new_on and "yes" or "no"))
        end,
    }
end

FIELDS[#FIELDS + 1] = toggle_field("Allow Overlap", "AllowOverlappingTakes",
    rec_settings.set_overlap, "Allow overlapping takes")

if workflow == "Vertical" then
    FIELDS[#FIELDS + 1] = toggle_field("Horizontal", "RecordTakesHorizontally",
        rec_settings.set_horizontal, "Record takes horizontally")
end

FIELDS[#FIELDS + 1] = toggle_field("Clip Reporting", "ClipReporting",
    rec_settings.set_clip, "Clip reporting", true)

FIELDS[#FIELDS + 1] = {
    label = "Daemon", kind = "action",
    value = function() return daemon_running() and "Running" or "Stopped" end,
    activate = function()
        if daemon_running() then
            say(record_daemon.close_message(record_daemon.close()))
        else
            local status, take_num = record_daemon.open()
            say(record_daemon.open_message(status, take_num))
        end
    end,
}

local field_idx = 1

local function announce_field(i)
    local f = FIELDS[i]
    say(f.label .. ": " .. f.value())
end

local function handle_key(char)
    local f = FIELDS[field_idx]

    if char == KEY_UP then
        field_idx = field_idx > 1 and field_idx - 1 or #FIELDS
        announce_field(field_idx)
    elseif char == KEY_DOWN then
        field_idx = field_idx < #FIELDS and field_idx + 1 or 1
        announce_field(field_idx)
    elseif char == KEY_ENTER then
        if f.kind == "text" then
            local ok, entered = ui_input.ask(WINDOW_TITLE, f.label, f.label, f.edit_seed())
            if ok then
                f.commit(entered)
            else
                say("Cancelled")
            end
        elseif f.kind == "toggle" then
            f.toggle()
        elseif f.kind == "action" then
            f.activate()
        end
    elseif char == KEY_BACK then
        if f.kind == "text" then
            f.clear()
        end
    elseif char == KEY_ESC then
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
    local f = FIELDS[field_idx]
    gfx.drawstr("[" .. f.label .. "]  " .. f.value())
    gfx.update()
end

local last_char = 0
local function main()
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

gfx.init(WINDOW_TITLE, 500, 44, 0)
say(string.format("Recording Settings. %s: %s. Up or down to move, Enter to edit, Escape to close.",
    FIELDS[1].label, FIELDS[1].value()))

defer(main)
