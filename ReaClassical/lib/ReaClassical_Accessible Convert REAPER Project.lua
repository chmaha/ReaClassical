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
local convert = require("ReaClassical_Convert_Core")

local WINDOW_TITLE = "Convert REAPER Project"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local OPTIONS = {
    {
        label = "Microphones of one recording",
        sequential = false,
        detail = "The tracks become one folder with a track per microphone.",
    },
    {
        label = "Separate material",
        sequential = true,
        detail = "The tracks are placed one after another on a single track, "
            .. "with a marker named after each original track. "
            .. "Track FX and automation are kept from the first track only.",
    },
}

local function finish(sequential, marker_track_index)
    local _, msg = convert.run(sequential, marker_track_index)
    say((msg:gsub("\n+", " ")))
end

if convert.is_rc_project() then
    say("This is already a ReaClassical project.")
    return
end

if convert.save_problem() then
    say(convert.save_problem())
    return
end

local tracks_with_items = convert.count_tracks_with_items()
local single = tracks_with_items < 2
if single then
    OPTIONS = { { label = "Convert", sequential = false, detail = "Converts the project." } }
end

set_action_options(3)

local list_pos = 1
local last_char = 0
local choosing_markers = false
local has_markers = convert.has_markers()
local tracks = convert.tracks_with_items()
local marker_pos = has_markers and convert.default_marker_track(tracks) or 1

local function marker_label(n)
    return tracks[n] and tracks[n].name or "Leave in place"
end

local function announce_option()
    local option = OPTIONS[list_pos]
    say(option.label .. ". " .. option.detail)
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if choosing_markers then
        gfx.drawstr("[Markers belong to]  " .. marker_label(marker_pos))
    else
        gfx.drawstr(single and "[Convert]  Enter to convert, Escape to cancel"
            or ("[Tracks contain]  " .. OPTIONS[list_pos].label))
    end
    gfx.update()
end

local function handle_marker_key(char)
    if char == KEY_UP then
        marker_pos = marker_pos > 1 and marker_pos - 1 or #tracks + 1
        say(marker_label(marker_pos))
    elseif char == KEY_DOWN then
        marker_pos = marker_pos < #tracks + 1 and marker_pos + 1 or 1
        say(marker_label(marker_pos))
    elseif char == KEY_ENTER then
        gfx.quit()
        finish(true, tracks[marker_pos] and tracks[marker_pos].index or nil)
        return false
    elseif char == KEY_ESC then
        choosing_markers = false
        say("Back. " .. OPTIONS[list_pos].label)
    end
    return true
end

local function handle_key(char)
    if choosing_markers then return handle_marker_key(char) end
    if char == KEY_UP then
        list_pos = list_pos > 1 and list_pos - 1 or #OPTIONS
        announce_option()
    elseif char == KEY_DOWN then
        list_pos = list_pos < #OPTIONS and list_pos + 1 or 1
        announce_option()
    elseif char == KEY_ENTER then
        if OPTIONS[list_pos].sequential and has_markers then
            choosing_markers = true
            say("Existing markers and regions belong to which track? " .. marker_label(marker_pos)
                .. ". Up or down to change, Enter to convert, Escape to go back.")
            return true
        end
        gfx.quit()
        finish(OPTIONS[list_pos].sequential)
        return false
    elseif char == KEY_ESC then
        say("Cancelled")
        return false
    end
    return true
end

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
if single then
    say("Convert REAPER project. " .. convert.INFO .. " Press Enter to convert or Escape to cancel.")
else
    say(string.format(
        "Convert REAPER project. %s This project has %d tracks with items. What do they contain? %s. "
        .. "Up or down to change, Enter to convert, Escape to cancel.",
        convert.INFO, tracks_with_items, OPTIONS[list_pos].label))
end

defer(main)
