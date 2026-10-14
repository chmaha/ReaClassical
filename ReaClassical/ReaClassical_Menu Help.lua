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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say    = require("ReaClassical_Announce")
local menu   = require("ReaClassical_Menu_Shortcuts")
local keymap = require("ReaClassical_Keymap_Shortcuts")

local has_clara = APIExists("clara_outputMessage")
if not has_clara then
    local _, debug_str = GetProjExtState(0, "ReaClassical", "DebugAnnounce")
    if debug_str ~= "on" then
        MB("ReaClassical Menu Help requires ReaClassical Clara (an accessibility bridge) to be installed.",
            "ReaClassical Error", 0)
        return
    end
end

if has_clara then
    set_action_options(3)
else
    set_action_options(2)
end

local WINDOW_TITLE = "ReaClassical Menu"
local MENU_SECTION = "Main actions"

local root = menu.parse_section(MENU_SECTION)
if not root or #root == 0 then
    say("Could not read the ReaClassical menu from the live keymap.")
    return
end
local key_map = keymap.key_map_for_section(0)

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local nav_stack = { { list = root, idx = 1 } }

local function current_frame() return nav_stack[#nav_stack] end
local function current_entry()
    local f = current_frame()
    return f.list[f.idx]
end

local function announce_current()
    local f = current_frame()
    local e = f.list[f.idx]
    if not e then say("Empty") return end
    local pos = string.format("%d of %d", f.idx, #f.list)
    if e.type == "submenu" then
        say(string.format("%s. %s, submenu, %d item%s. Enter to open.",
            pos, e.label, #e.items, #e.items == 1 and "" or "s"))
    elseif e.type == "header" then
        say(string.format("%s. Group: %s", pos, e.label))
    else
        local shortcut = key_map[e.cmdid]
        if shortcut then
            say(string.format("%s. %s. Shortcut: %s", pos, e.label, shortcut))
        else
            say(string.format("%s. %s", pos, e.label))
        end
    end
end

say(string.format("ReaClassical Menu. %d top-level item%s. Up or down to browse, "
    .. "Enter to open or run, Escape to go back or close.", #root, #root == 1 and "" or "s"))
announce_current()

gfx.init(WINDOW_TITLE, 500, 44, 0)

local last_char = 0
local function main()
    local char = gfx.getchar()
    if char == -1 then return end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        local f = current_frame()
        if char == KEY_UP then
            f.idx = f.idx > 1 and f.idx - 1 or #f.list
            announce_current()
        elseif char == KEY_DOWN then
            f.idx = f.idx < #f.list and f.idx + 1 or 1
            announce_current()
        elseif char == KEY_ENTER then
            local e = current_entry()
            if e and e.type == "submenu" then
                nav_stack[#nav_stack + 1] = { list = e.items, idx = 1 }
                say(e.label .. ". " .. #e.items .. " item" .. (#e.items == 1 and "" or "s") .. ".")
                announce_current()
            elseif e and e.type == "item" then
                gfx.quit()
                if not keymap.run_command(e.cmdid) then
                    say("Could not run: " .. e.label)
                end
                return
            end
        elseif char == KEY_ESC then
            if #nav_stack > 1 then
                nav_stack[#nav_stack] = nil
                announce_current()
            else
                gfx.quit()
                return
            end
        end
    end

    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    local f = current_frame()
    local e = f.list[f.idx]
    local label = e and e.label or ""
    gfx.drawstr(string.format("[Menu %d/%d]  %s", f.idx, #f.list, label))
    gfx.update()
    defer(main)
end

defer(main)
