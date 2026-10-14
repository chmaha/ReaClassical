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
local say = require("ReaClassical_Announce")
local keymap = require("ReaClassical_Keymap_Shortcuts")

if APIExists("clara_outputMessage") then
    set_action_options(3)
else
    set_action_options(2)
end

local main, file_exists, get_path, show_mode_shortcuts

local KEY_UP   = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local MIXER_NUDGE_BASE_DESCS = {
    ["Pan Left"] = true, ["Pan Right"] = true,
    ["Fader Down"] = true, ["Fader Up"] = true,
}

local function relabel_mixer_mode_granularity(list)
    for _, e in ipairs(list) do
        local base_name = e.desc:match("^(.-) x modifier$")
        if base_name and MIXER_NUDGE_BASE_DESCS[base_name] then
            e.desc = base_name .. " (fine-grain)"
        elseif MIXER_NUDGE_BASE_DESCS[e.desc] then
            e.desc = e.desc .. " (rough)"
        end
    end
end

function show_mode_shortcuts(title, section, prefix)
    local list = keymap.shortcuts_for_section(section, prefix)
    if not list or #list == 0 then
        say(title .. ": no shortcuts found in the current keymap.")
        return
    end
    if section == 3 then relabel_mixer_mode_granularity(list) end

    local idx = 1
    gfx.init(title .. " Shortcuts", 500, 44, 0)

    local function announce_current()
        local e = list[idx]
        say(string.format("%s: %s", e.desc, e.key))
    end

    say(string.format("%s shortcuts. %d shortcut%s. Up or down to browse, H or Escape to close.",
        title, #list, #list == 1 and "" or "s"))
    announce_current()

    local last_char = 0
    local function loop()
        local char = gfx.getchar()
        if char == -1 then return end
        if char == 0 then
            last_char = 0
        elseif char ~= last_char then
            last_char = char
            if char == KEY_UP then
                idx = idx > 1 and idx - 1 or #list
                announce_current()
            elseif char == KEY_DOWN then
                idx = idx < #list and idx + 1 or 1
                announce_current()
            elseif char == KEY_ENTER then
                local e = list[idx]
                gfx.quit()
                if not keymap.run_command(e.cmdid) then
                    say("Could not run: " .. e.desc)
                end
                return
            elseif char == KEY_ESC or char == 72 or char == 104 then
                gfx.quit()
                return
            end
        end
        gfx.set(0.12, 0.12, 0.12, 1)
        gfx.rect(0, 0, gfx.w, gfx.h, true)
        gfx.set(0.9, 0.9, 0.9, 1)
        gfx.setfont(1, "Arial", 15)
        gfx.x, gfx.y = 8, 13
        local e = list[idx]
        gfx.drawstr(string.format("[%s %d/%d]  %s: %s", title, idx, #list, e.key, e.desc))
        gfx.update()
        defer(loop)
    end
    defer(loop)
end

function main()
    if GetExtState("ReaClassical", "XFadeMode") == "1" then
        show_mode_shortcuts("Crossfade Mode", 1, "ReaClassical_XFM ")
        return
    elseif GetExtState("ReaClassical", "IEMMode") == "1" then
        show_mode_shortcuts("Item Edit Mode", 2, "ReaClassical_IEM ")
        return
    elseif GetExtState("ReaClassical", "MixerMode") == "1" then
        show_mode_shortcuts("Mixer Mode", 3, "ReaClassical_MM_")
        return
    end

    if not APIExists("CF_ShellExecute") then
        if APIExists("clara_outputMessage") then
            clara_outputMessage("SWS/S&M extension required to open the manual")
        else
            MB("SWS/S&M extension required to open the manual", "ReaClassical Error", 0)
        end
        return
    end

    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "ReaClassical-Manual.html")
    local html = resource_path .. relative_path
    local bool = file_exists(html)
    if bool == true then
        CF_ShellExecute(html)
    else
        MB("Re-install ReaClassical metapackage via ReaPack first!",
            "ReaClassical HTML Manual not found!", 0)
    end
end

function file_exists(name)
    local exists = false
    local file = io.open(name, "r")
    if file ~= nil then
        io.close(file)
        exists = true
    end
    return exists
end

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

main()
