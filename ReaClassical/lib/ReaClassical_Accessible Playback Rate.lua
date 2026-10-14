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
local help = require("ReaClassical_Accessible_Help")
local ui_input = require("ReaClassical_Accessible_Input")
set_action_options(3)

local WINDOW_TITLE = "Playback Rate"

local STATE_MENU  = "menu"
local STATE_RATE  = "rate"
local STATE_PITCH = "pitch"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local MENU_ITEMS = { "Rate", "Pitch" }

local state        = STATE_MENU
local menu_idx      = 1
local is_relative   = true
local last_char       = 0

local function count_selected_items()
    local n = 0
    for i = 0, CountMediaItems(0) - 1 do
        if IsMediaItemSelected(GetMediaItem(0, i)) then n = n + 1 end
    end
    return n
end

local function run_action(args)
    _G.RC_SCRIPT_ARGS = args
    dofile(parent_path .. "ReaClassical_Set Item Playback Rate.lua")
    _G.RC_SCRIPT_ARGS = nil
end

local function rate_example()
    return is_relative
        and "e.g. 50 speeds up by half, minus 50 slows down by half"
        or "e.g. 100 doubles speed, minus 50 halves speed, 0 is normal"
end

local function announce_rate(with_hint)
    if with_hint then
        say(string.format("Rate. %d item%s selected. Mode: %s. Enter opens the input box, "
            .. "H for shortcuts, Escape to go back.",
            count_selected_items(), count_selected_items() == 1 and "" or "s",
            is_relative and "Relative" or "Absolute"))
    else
        say((is_relative and "Relative" or "Absolute") .. ". " .. rate_example())
    end
end

local function rate_shortcuts()
    return {
        { key = "Up or Down arrow", desc = "Toggle Relative or Absolute mode" },
        { key = "Enter", desc = "Open the input box. A number applies and ripples. " .. rate_example() },
        { key = "R", desc = "Reset to normal speed" },
        { key = "Escape", desc = "Go back" },
    }
end

local function announce_pitch(with_hint)
    if with_hint then
        say(string.format("Pitch. %d item%s selected. Enter opens the input box, "
            .. "H for shortcuts, Escape to go back.",
            count_selected_items(), count_selected_items() == 1 and "" or "s"))
    end
end

local PITCH_SHORTCUTS = {
    { key = "Enter", desc = "Open the input box. A number applies. 12 is one octave up, minus 12 is one octave down" },
    { key = "R", desc = "Reset pitch to zero" },
    { key = "Escape", desc = "Go back" },
}

local function ask_number(box_title, caption)
    local value = ""
    while true do
        local ok, entered = ui_input.ask(WINDOW_TITLE, box_title, caption, value)
        if not ok then return nil end
        local num = tonumber(entered)
        if num then return num end
        say("Please enter a number")
        value = entered
    end
end

local function handle_key(char)
    if state == STATE_MENU then
        if char == KEY_UP or char == KEY_DOWN then
            menu_idx = menu_idx == 1 and 2 or 1
            say(MENU_ITEMS[menu_idx])
        elseif char == KEY_ENTER then
            if menu_idx == 1 then
                state = STATE_RATE
                announce_rate(true)
            else
                state = STATE_PITCH
                announce_pitch(true)
            end
        elseif char == KEY_ESC then
            return false
        end
    elseif state == STATE_RATE then
        if char == KEY_UP or char == KEY_DOWN then
            is_relative = not is_relative
            announce_rate(false)
        elseif char == KEY_ENTER then
            local val = ask_number("Rate",
                "Percentage" .. (is_relative and ", relative to current speed" or ""))
            if val then
                run_action({ action = "rate", value = val, relative = is_relative })
                announce_rate(false)
            else
                say("Cancelled")
            end
        elseif char == 114 or char == 82 then
            run_action({ action = "reset_rate" })
        elseif char == 104 or char == 72 then
            help.enter(rate_shortcuts(), function() announce_rate(false) end)
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_PITCH then
        if char == KEY_ENTER then
            local val = ask_number("Pitch", "Semitones")
            if val then
                run_action({ action = "pitch", value = val })
            else
                say("Cancelled")
            end
        elseif char == 114 or char == 82 then
            run_action({ action = "pitch", value = 0 })
        elseif char == 104 or char == 72 then
            help.enter(PITCH_SHORTCUTS, "Back to Pitch.")
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    end

    return true
end

local function status_line()
    if state == STATE_MENU then
        return "[Playback Rate]  " .. MENU_ITEMS[menu_idx]
    elseif state == STATE_RATE then
        return "[Rate " .. (is_relative and "Relative" or "Absolute") .. "]"
    elseif state == STATE_PITCH then
        return "[Pitch]"
    end
    return ""
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    gfx.drawstr(status_line())
    gfx.update()
end

local function main()
    local char = gfx.getchar()
    if char == -1 then gfx.quit() return end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        local consumed = help.is_active() and help.handle_key(char)
        if not consumed then
            if not handle_key(char) then
                gfx.quit()
                return
            end
        end
    end
    draw_window()
    defer(main)
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

gfx.init(WINDOW_TITLE, 500, 44, 0)
say("Playback Rate. Rate. Up or down for other options, Enter to select, Escape to close.")

defer(main)
