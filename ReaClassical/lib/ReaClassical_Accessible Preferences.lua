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
local gui_mode = require("ReaClassical_GuiMode")
local ui_input = require("ReaClassical_Accessible_Input")
set_action_options(3)

local WINDOW_TITLE = "Preferences"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_BACK  = 8

local PREF_LABELS = {
    "Crossfade Length in Milliseconds", "CD Track Offset in Milliseconds", "Index 0 Length in Seconds",
    "Album Lead-out Time in Seconds", "No Auto Item Coloring", "No Ranking Color",
    "Reference Tracks Are Overdub Guides", "Add S-D Markers at Mouse Hover", "Alternate Audition Playback Rate",
    "Year of Production", "CUE Audio Format", "Floating Destination Folder",
    "Find Takes Using Item Names", "Show Only Item Take Numbers", "Source Audition Mode",
}
local PREF_BINARY = { [5] = true, [6] = true, [7] = true, [8] = true,
    [12] = true, [13] = true, [14] = true, [15] = true }
local PREF_FORMATS = { "WAV", "FLAC", "MP3", "AIFF" }
local PREF_DEFAULTS = "35,200,3,7,0,0,0,0,0.75," .. os.date("%Y") .. ",WAV,0,0,0,0"

local PREF_DEFAULT_VALUES = {}

local OTHER_LABELS   = { "Nudge amount in milliseconds",
    "Item Edge Grow/Shrink Amount in milliseconds", "Modifier Multiplier" }
local OTHER_KEYS     = { "NudgeMs", "EdgeGrowShrinkMs", "ModifierFactor" }
local OTHER_DEFAULTS = { 5, 500, 5 }
local OTHER_MENU_IDX = #PREF_LABELS + 1
local RESET_ALL_MENU_IDX = OTHER_MENU_IDX + 1

do
    local entries = {}
    for entry in PREF_DEFAULTS:gmatch("([^,]+)") do entries[#entries + 1] = entry end
    for i = 1, #PREF_LABELS do
        PREF_DEFAULT_VALUES[i] = (i == 11) and (entries[i] or "WAV") or (tonumber(entries[i]) or 0)
    end
end

local prefs         = {}
local other_vals    = {}
local pref_idx      = 1
local last_char      = 0

local in_other_menu   = false
local other_idx       = 1

local function load_prefs()
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
    if saved == "" then saved = PREF_DEFAULTS end
    local entries = {}
    for entry in saved:gmatch("([^,]+)") do entries[#entries + 1] = entry end
    if #entries ~= #PREF_LABELS then
        saved = PREF_DEFAULTS
        entries = {}
        for entry in saved:gmatch("([^,]+)") do entries[#entries + 1] = entry end
    end
    for i = 1, #PREF_LABELS do
        prefs[i] = (i == 11) and (entries[i] or "WAV") or (tonumber(entries[i]) or 0)
    end
end

local function save_prefs()
    local values = {}
    for i = 1, #PREF_LABELS do values[i] = tostring(prefs[i]) end
    SetProjExtState(0, "ReaClassical", "Preferences", table.concat(values, ","))
end

local function apply_pref_value(i, str)
    local num = tonumber(str)
    if not num then return "Please enter a number" end
    if num < 0 then return "Must not be negative" end
    if i == 3 and num < 1 then return "Must be at least 1" end
    if i ~= 9 and num ~= math.floor(num) then return "Must be a whole number" end
    prefs[i] = num
    save_prefs()
    return nil
end

local function pref_value_label(i)
    if i == 11 then return prefs[11]:lower() end
    if PREF_BINARY[i] then return prefs[i] == 1 and "On" or "Off" end
    return tostring(prefs[i])
end

local function load_other_vals()
    for oi, key in ipairs(OTHER_KEYS) do
        local _, stored = GetProjExtState(0, "ReaClassical", key)
        other_vals[oi] = tonumber(stored) or OTHER_DEFAULTS[oi]
    end
end

local function apply_other_value(oi, str)
    local num = tonumber(str)
    if not num then return "Please enter a number" end
    if num <= 0 then return "Must be a positive number" end
    other_vals[oi] = num
    SetProjExtState(0, "ReaClassical", OTHER_KEYS[oi], tostring(num))
    return nil
end

local function ask_numeric(box_title, caption, current, apply_fn)
    while true do
        local ok, entered = ui_input.ask(box_title, caption,
            caption, tostring(current))
        if not ok then return false end
        local err = apply_fn(entered)
        if not err then return true end
        say(err)
    end
end

local function main_label(i)
    if i == OTHER_MENU_IDX then return "Other Settings" end
    if i == RESET_ALL_MENU_IDX then return "Reset All to Defaults" end
    return PREF_LABELS[i]
end

local function main_value_label(i)
    if i == OTHER_MENU_IDX or i == RESET_ALL_MENU_IDX then return "" end
    return pref_value_label(i)
end

local function announce_main(i)
    local val = main_value_label(i)
    say(main_label(i) .. (val ~= "" and (": " .. val) or ""))
end

local function other_value_label(oi)
    return tostring(other_vals[oi])
end

local function announce_other(oi)
    say(OTHER_LABELS[oi] .. ": " .. other_value_label(oi))
end

local function handle_other_key(char)
    if char == KEY_UP then
        other_idx = other_idx > 1 and other_idx - 1 or #OTHER_LABELS
        announce_other(other_idx)
    elseif char == KEY_DOWN then
        other_idx = other_idx < #OTHER_LABELS and other_idx + 1 or 1
        announce_other(other_idx)
    elseif char == KEY_BACK then
        other_vals[other_idx] = OTHER_DEFAULTS[other_idx]
        SetProjExtState(0, "ReaClassical", OTHER_KEYS[other_idx], tostring(OTHER_DEFAULTS[other_idx]))
        say("Reset to default: " .. other_value_label(other_idx))
    elseif char == KEY_ENTER then
        local oi = other_idx
        local ok = ask_numeric(WINDOW_TITLE, OTHER_LABELS[oi],
            other_vals[oi], function(str) return apply_other_value(oi, str) end)
        if ok then
            say(other_value_label(oi))
        else
            say("Cancelled")
        end
    elseif char == KEY_ESC then
        in_other_menu = false
        say("Other Settings")
    end
    return true
end

local function handle_key(char)
    if in_other_menu then return handle_other_key(char) end

    do
        if char == KEY_UP then
            pref_idx = pref_idx > 1 and pref_idx - 1 or RESET_ALL_MENU_IDX
            announce_main(pref_idx)
        elseif char == KEY_DOWN then
            pref_idx = pref_idx < RESET_ALL_MENU_IDX and pref_idx + 1 or 1
            announce_main(pref_idx)
        elseif char == KEY_BACK then
            if pref_idx ~= OTHER_MENU_IDX and pref_idx ~= RESET_ALL_MENU_IDX then
                prefs[pref_idx] = PREF_DEFAULT_VALUES[pref_idx]
                save_prefs()
                say("Reset to default: " .. pref_value_label(pref_idx))
            end
        elseif char == KEY_ENTER then
            if pref_idx == OTHER_MENU_IDX then
                in_other_menu = true
                other_idx = 1
                say("Other Settings. " .. OTHER_LABELS[1] .. ": " .. other_value_label(1))
            elseif pref_idx == RESET_ALL_MENU_IDX then
                for i = 1, #PREF_LABELS do prefs[i] = PREF_DEFAULT_VALUES[i] end
                save_prefs()
                for oi = 1, #OTHER_LABELS do
                    other_vals[oi] = OTHER_DEFAULTS[oi]
                    SetProjExtState(0, "ReaClassical", OTHER_KEYS[oi], tostring(OTHER_DEFAULTS[oi]))
                end
                say("All preferences reset to defaults")
            elseif PREF_BINARY[pref_idx] then
                prefs[pref_idx] = (prefs[pref_idx] == 1) and 0 or 1
                save_prefs()
                say(pref_value_label(pref_idx))
            elseif pref_idx == 11 then
                local fi = 1
                for i, f in ipairs(PREF_FORMATS) do
                    if f == prefs[11] then fi = i; break end
                end
                prefs[11] = PREF_FORMATS[(fi % #PREF_FORMATS) + 1]
                save_prefs()
                say(pref_value_label(11))
            else
                local pi = pref_idx
                local ok = ask_numeric(WINDOW_TITLE, PREF_LABELS[pi],
                    prefs[pi], function(str) return apply_pref_value(pi, str) end)
                if ok then
                    say(pref_value_label(pi))
                else
                    say("Cancelled")
                end
            end
        elseif char == KEY_ESC then
            return false
        end
    end
    return true
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if in_other_menu then
        gfx.drawstr("[Other Settings: " .. OTHER_LABELS[other_idx] .. "]  " .. other_value_label(other_idx))
    else
        local val = main_value_label(pref_idx)
        gfx.drawstr("[" .. main_label(pref_idx) .. "]" .. (val ~= "" and ("  " .. val) or ""))
    end
    gfx.update()
end

local function main()
    if not gui_mode.accessible() then
        gfx.quit()
        gui_mode.switch_window("ReaClassical_Preferences.lua")
        return
    end

    local char = gfx.getchar()
    if char ~= last_char and gui_mode.gfx_shortcut(char) then
        last_char = char
        gui_mode.toggle_and_announce()
        defer(main)
        return
    end
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

load_prefs()
load_other_vals()
gfx.init(WINDOW_TITLE, 500, 44, 0)
say(string.format("Preferences. %s: %s. Up or down to move, Enter to edit, Backspace to reset, Escape to close.",
    PREF_LABELS[1], pref_value_label(1)))

defer(main)
