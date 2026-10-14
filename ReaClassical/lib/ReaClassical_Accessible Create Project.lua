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
local af  = require("ReaClassical_Accessible_Focus")
local ui_input = require("ReaClassical_Accessible_Input")
set_action_options(3)

local WINDOW_TITLE = "Create Project"

local STATE_TRACKS   = "tracks"
local STATE_WORKFLOW = "workflow"
local STATE_FOLDERS  = "folders"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local WORKFLOW_TYPES = { "Horizontal", "Vertical" }

local state          = STATE_TRACKS
local track_count    = 10
local workflow_idx   = 1
local folder_count   = 6
local last_char       = 0

local function ask_count(box_title, caption, current, minimum, min_msg)
    while true do
        local ok, entered = ui_input.ask(WINDOW_TITLE, box_title,
            caption .. ", minimum " .. minimum, tostring(current))
        if not ok then return nil end
        if entered == "" then return current end
        local n = tonumber(entered)
        if n and n >= minimum then return n end
        say(min_msg)
    end
end

local function create_project()
    if track_count == 1 then
        SetProjExtState(0, "ReaClassical", "TrackCount", "2")
        SetProjExtState(0, "ReaClassical", "SingleTrack", "1")
    else
        SetProjExtState(0, "ReaClassical", "TrackCount", tostring(track_count))
        SetProjExtState(0, "ReaClassical", "SingleTrack", "")
    end
    _G.RC_SCRIPT_ARGS = {}
    if workflow_idx == 1 then
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
    else
        SetProjExtState(0, "ReaClassical", "SourceFolderCount", tostring(folder_count))
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    end
    _G.RC_SCRIPT_ARGS = nil
    if APIExists("SNM_SetIntConfigVar") then SNM_SetIntConfigVar("scrubmode", 1) end
    af.refocus_existing(WINDOW_TITLE)
end

local function handle_key(char)
    if state == STATE_TRACKS then
        if char == KEY_ENTER then
            local n = ask_count("Tracks Per Folder", "Track count per folder",
                track_count, 1, "Minimum of 1 track per folder required")
            if n then
                track_count = n
                state = STATE_WORKFLOW
                say(WORKFLOW_TYPES[workflow_idx]
                    .. ". Up or down to change, Enter to continue, Escape to cancel.")
            else
                say("Cancelled")
            end
        elseif char == KEY_ESC then
            say("Cancelled")
            return false
        end
    elseif state == STATE_WORKFLOW then
        if char == KEY_UP or char == KEY_DOWN then
            workflow_idx = workflow_idx == 1 and 2 or 1
            say(WORKFLOW_TYPES[workflow_idx])
        elseif char == KEY_ENTER then
            if workflow_idx == 1 then
                say("Creating project.")
                create_project()
                say("Project created.")
                dofile(script_path .. "ReaClassical_Accessible Track Setup.lua")
                return "handoff"
            end
            while true do
                local ok, entered = ui_input.ask(WINDOW_TITLE, "Source Folders",
                    "Number of source folders, minimum 1", tostring(folder_count))
                if not ok then
                    say("Cancelled")
                    break
                end
                local n = tonumber(entered)
                if n and n >= 1 then
                    folder_count = n
                    say("Creating project.")
                    create_project()
                    say("Project created.")
                    dofile(script_path .. "ReaClassical_Accessible Track Setup.lua")
                    return "handoff"
                end
                say("Minimum of 1 source folder required")
            end
        elseif char == KEY_ESC then
            state = STATE_TRACKS
            say(string.format("Track count per folder: %d. Enter opens the box; "
                .. "keep or change it there. Enter continues, Escape cancels.",
                track_count))
        end
    elseif state == STATE_FOLDERS then
        if char == KEY_ENTER then
            local n = ask_count("Source Folders", "Number of source folders",
                folder_count, 1, "Minimum of 1 source folder required")
            if n then
                folder_count = n
                say("Creating project.")
                create_project()
                say("Project created.")
                dofile(script_path .. "ReaClassical_Accessible Track Setup.lua")
                return "handoff"
            else
                say("Cancelled")
            end
        elseif char == KEY_ESC then
            state = STATE_WORKFLOW
            say(WORKFLOW_TYPES[workflow_idx]
                .. ". Up or down to change, Enter to continue, Escape to cancel.")
        end
    end

    return true
end

local function status_line()
    if state == STATE_TRACKS then
        return "[Tracks per folder]  " .. tostring(track_count)
    elseif state == STATE_WORKFLOW then
        return "[Workflow]  " .. WORKFLOW_TYPES[workflow_idx]
    elseif state == STATE_FOLDERS then
        return "[Source folders]  " .. tostring(folder_count)
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
        local result = handle_key(char)
        if result == "handoff" then
            return
        elseif not result then
            gfx.quit()
            return
        end
    end
    draw_window()
    defer(main)
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow ~= "" then
    MB("You can only use this function on an empty REAPER project", "ReaClassical Error", 0)
    return
end

gfx.init(WINDOW_TITLE, 500, 44, 0)

while true do
    local ok, entered = ui_input.ask(WINDOW_TITLE, "Tracks Per Folder",
        "Track count per folder, minimum 1", tostring(track_count))
    if not ok then
        say("Cancelled")
        return
    end
    local n = tonumber(entered)
    if n and n >= 1 then
        track_count = n
        break
    end
    say("Minimum of 1 track per folder required")
end

state = STATE_WORKFLOW
say(WORKFLOW_TYPES[workflow_idx] .. ". Up or down to change, "
    .. "Enter to continue, Escape to cancel.")
defer(main)
