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
local core = require("ReaClassical_Crossfade_Fix_Core")

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

local folder_track, left, right, selection_err = core.resolve_selection()
if selection_err then
    say(selection_err)
    return
end

local track_list = core.folder_track_list(folder_track)

set_action_options(3)

local WINDOW_TITLE = "Fix Crossfade Sequence Edits"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local list_pos = 1
local last_char = 0

local function announce_list_pos()
    say(track_list[list_pos].name)
end

local function run_and_report(good_track)
    Undo_BeginBlock()
    PreventUIRefresh(1)
    local fixed, warnings = core.run_fix(folder_track, good_track, left, right)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
    Undo_EndBlock('Fix Crossfade Sequence Edits', -1)

    if #warnings > 0 then
        say(string.format("Fixed %d item%s. %d issue%s: %s",
            fixed, fixed == 1 and "" or "s",
            #warnings, #warnings == 1 and "" or "s",
            table.concat(warnings, "; ")))
    else
        say(string.format("Fixed %d item%s", fixed, fixed == 1 and "" or "s"))
    end
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    gfx.drawstr("[Reference Track]  " .. track_list[list_pos].name)
    gfx.update()
end

local function handle_key(char)
    if char == KEY_UP then
        list_pos = list_pos > 1 and list_pos - 1 or #track_list
        announce_list_pos()
    elseif char == KEY_DOWN then
        list_pos = list_pos < #track_list and list_pos + 1 or 1
        announce_list_pos()
    elseif char == KEY_ENTER then
        run_and_report(track_list[list_pos].track)
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
say(string.format(
    "Fix crossfade sequence edits. Reference track: %s. "
    .. "Up or down to change, Enter to fix using this track, Escape to cancel.",
    track_list[list_pos].name))

defer(main)
