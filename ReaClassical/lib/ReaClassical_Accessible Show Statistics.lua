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
local stats_info = require("ReaClassical_Stats_Info")
set_action_options(3)

local WINDOW_TITLE = "Statistics"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local ENTRIES = {}
do
    ENTRIES[#ENTRIES + 1] = { kind = "version" }
    for _, section in ipairs(stats_info.SECTIONS) do
        for _, f in ipairs(section.fields) do
            ENTRIES[#ENTRIES + 1] = { kind = "field", label = f.label, key = f.key,
                resettable = (f.key == "session_time") }
        end
    end
    ENTRIES[#ENTRIES + 1] = { kind = "copy_all" }
end

local stats     = {}
local idx       = 1
local last_char = 0

local function entry_text(e)
    if e.kind == "version" then return stats_info.version_text(stats) end
    if e.kind == "copy_all" then return "Copy All Statistics" end
    return e.label .. ": " .. tostring(stats[e.key])
end

local function step(delta)
    idx = ((idx - 1 + delta) % #ENTRIES) + 1
    say(entry_text(ENTRIES[idx]))
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    gfx.drawstr("[Stats]  " .. entry_text(ENTRIES[idx]))
    gfx.update()
end

local function handle_key(char)
    local e = ENTRIES[idx]
    if char == KEY_UP then
        step(-1)
    elseif char == KEY_DOWN then
        step(1)
    elseif char == KEY_ENTER then
        if e.kind == "version" then
            if APIExists("CF_SetClipboard") then
                CF_SetClipboard(stats_info.version_text(stats))
                say("Version copied")
            else
                say("Copying requires the SWS extension")
            end
        elseif e.kind == "copy_all" then
            if APIExists("CF_SetClipboard") then
                CF_SetClipboard(stats_info.stats_text(stats))
                say("All statistics copied")
            else
                say("Copying requires the SWS extension")
            end
        elseif e.kind == "field" and e.resettable then
            stats_info.reset_session_timer()
            stats = stats_info.calculate()
            say("Session timer reset. " .. entry_text(e))
        end
    elseif char == KEY_ESC then
        say("Closing")
        return false
    end
    return true
end

local function main()
    if not gui_mode.accessible() then
        gfx.quit()
        gui_mode.switch_window("ReaClassical_Show Statistics.lua")
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

PreventUIRefresh(1)
stats = stats_info.calculate()
PreventUIRefresh(-1)

gfx.init(WINDOW_TITLE, 500, 44, 0)
say(string.format(
    "Project Statistics. %s. Up or down to move, Enter to copy or reset where available, Escape to close.",
    entry_text(ENTRIES[idx])))

defer(main)
