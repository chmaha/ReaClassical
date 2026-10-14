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

local WINDOW_TITLE = "MM Group Tracks (Multi-select)"

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say    = require("ReaClassical_Announce")
local mm     = require("ReaClassical_MM_Utils")
local groups = require("ReaClassical_MM_Groups")

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local pick_tracks     = {}
local pick_idx        = 1
local virtual_sel     = {}
local virtual_sel_set = {}
local last_char       = 0

local function announce_pick_track(with_hint)
    local t = pick_tracks[pick_idx]
    if not t then
        say("No special tracks found")
        return
    end
    mm.set_current_target(t)
    local label = mm.get_label(t)
    local sel_suffix = virtual_sel_set[t] and " (selected)" or ""
    if with_hint then
        say("Group tracks. " .. label .. sel_suffix
            .. ". Up or down to browse tracks, Shift+Enter to add or remove from "
            .. "the group selection, Enter to create the group, Escape to cancel")
    else
        say(label .. sel_suffix)
    end
end

local function toggle_virtual_selection()
    local t = pick_tracks[pick_idx]
    if not t then return end
    local label = mm.get_label(t)
    if virtual_sel_set[t] then
        virtual_sel_set[t] = nil
        for i, vt in ipairs(virtual_sel) do
            if vt == t then table.remove(virtual_sel, i) break end
        end
        say(label .. " removed. " .. #virtual_sel .. " track" .. (#virtual_sel == 1 and "" or "s") .. " selected")
    else
        virtual_sel_set[t] = true
        virtual_sel[#virtual_sel + 1] = t
        say(label .. " added. " .. #virtual_sel .. " track" .. (#virtual_sel == 1 and "" or "s") .. " selected")
    end
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13

    if #pick_tracks == 0 then
        gfx.drawstr("No special tracks found")
    else
        local sel_suffix = #virtual_sel > 0 and ("  [" .. #virtual_sel .. " selected]") or ""
        gfx.drawstr("[Track]  " .. mm.get_label(pick_tracks[pick_idx]) .. sel_suffix)
    end
    gfx.update()
end

local function build_pattern()
    local parts = {}
    for _, t in ipairs(virtual_sel) do
        parts[#parts + 1] = mm.get_label(t):gsub(",", "")
    end
    return table.concat(parts, ", ")
end

local function handle_key(char)
    if #pick_tracks == 0 then
        if char == KEY_ESC then return false end
        return true
    end
    if char == KEY_UP then
        pick_idx = pick_idx > 1 and pick_idx - 1 or #pick_tracks
        announce_pick_track(false)
    elseif char == KEY_DOWN then
        pick_idx = pick_idx < #pick_tracks and pick_idx + 1 or 1
        announce_pick_track(false)
    elseif char == KEY_ENTER then
        if (gfx.mouse_cap & 8) == 8 then
            toggle_virtual_selection()
        elseif #virtual_sel < 2 then
            say("Need at least two tracks selected to form a group. Closing.")
            return false
        else
            local default_name = "Group " .. (#groups.load_groups() + 1)
            local retval, name = GetUserInputs("Name Group", 1, "Group name:,extrawidth=100", default_name)
            if not retval then
                say("Cancelled")
                return false
            end
            local _, msg = groups.create_group(build_pattern(), name)
            say(msg)
            return false
        end
    elseif char == KEY_ESC then
        say("Cancelled")
        return false
    end
    return true
end

local function main()
    local char = gfx.getchar()
    if char == -1 then
        gfx.quit()
        return
    end
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

if GetExtState("ReaClassical", "MixerMode") ~= "1" then
    say("Enable Mixer Mode first")
    return
end

for _, t in ipairs(mm.get_special_tracks_list()) do
    pick_tracks[#pick_tracks + 1] = t
end
if #pick_tracks == 0 then
    say("No special tracks found")
    return
end

local current = mm.get_current_target()
if current then
    for i, t in ipairs(pick_tracks) do
        if t == current then
            pick_idx = i
            break
        end
    end
end

gfx.init(WINDOW_TITLE, 480, 44, 0)
announce_pick_track(true)
defer(main)
