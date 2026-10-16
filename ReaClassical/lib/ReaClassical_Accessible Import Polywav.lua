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
local scan = require("ReaClassical_Smart_Import_Scan")
local placement = require("ReaClassical_Import_Placement")
local polywav = require("ReaClassical_Polywav_Import")
local ui_input = require("ReaClassical_Accessible_Input")

set_action_options(3)

local WINDOW_TITLE = "Import Polywav"

local STATE_PATTERN           = "pattern"
local STATE_DISTRIBUTION_MODE = "distribution_mode"
local STATE_FOLDER_COUNT      = "folder_count"
local STATE_STARTING_FOLDER   = "starting_folder"
local STATE_IMPORT            = "import"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local state = nil
local last_char = 0

local workflow    = ""
local is_vertical = false

local sessions, session_names
local total_takes, channel_count = 0, nil

local pattern_text = "1"
local groups, comp_err, cap_err

local DISTRIBUTION_ORDER = { 0, 2, 1 }
local DISTRIBUTION_LABELS = {
    [0] = "One folder per take",
    [2] = "Use current folder count",
    [1] = "Round-robin across custom number of folders",
}
local dm_idx            = 1
local distribution_mode = 0
local folder_count      = 2
local start_folder_idx  = 2

local function evaluate_pattern()
    local ordered
    groups, ordered, comp_err = polywav.compute_composition(channel_count, pattern_text)
    cap_err = nil
    if groups then
        local ok, msg = polywav.validate_capacity(#groups, workflow)
        if not ok then cap_err = msg end
    end
    return groups ~= nil and cap_err == nil
end

local function spoken_pattern()
    return (pattern_text:gsub("%d", "%0 "):gsub("%s+$", ""))
end

local function pattern_problem()
    return comp_err or cap_err
end

local function announce_pattern(with_hint)
    local valid = evaluate_pattern()
    if with_hint then
        local summary = string.format("%d take%s, %d channels each.", total_takes,
            total_takes == 1 and "" or "s", channel_count)
        local result
        if valid then
            result = string.format("Pattern %s gives %d track%s.", spoken_pattern(), #groups,
                #groups == 1 and "" or "s")
        else
            result = "Pattern " .. spoken_pattern() .. " is not usable. " .. pattern_problem()
        end
        say(string.format("Import Polywav. %s %s Enter to set the pattern and continue, "
            .. "Escape to cancel.", summary, result))
    else
        say(valid and string.format("Pattern %s gives %d tracks", spoken_pattern(), #groups)
            or pattern_problem())
    end
end

local function announce_distribution_mode(with_hint)
    local mode = DISTRIBUTION_ORDER[dm_idx]
    if with_hint then
        say(string.format("Distribution Mode: %s. Up or down to change, Enter to continue, "
            .. "Escape to go back.", DISTRIBUTION_LABELS[mode]))
    else
        say(DISTRIBUTION_LABELS[mode])
    end
end

local function announce_folder_count(with_hint)
    if with_hint then
        say(string.format("Number of folders: %d. Enter opens the box; "
            .. "keep or change it there. Escape goes back.", folder_count))
    else
        say(tostring(folder_count))
    end
end

local function announce_starting_folder(with_hint)
    local label = scan.spoken_folder_label_for_index(start_folder_idx)
    if with_hint then
        say(string.format("Starting folder: %s. Up or down to change, Enter to continue, "
            .. "Escape to go back.", label))
    else
        say(label)
    end
end

local function announce_import(with_hint)
    local text = string.format("Import %d take%s with pattern %s.", total_takes,
        total_takes == 1 and "" or "s", spoken_pattern())
    if with_hint then
        say(text .. " Enter to import, Escape to go back.")
    else
        say(text)
    end
end

local function enter_pattern()
    state = STATE_PATTERN
    announce_pattern(true)
end

local function enter_distribution_mode()
    state = STATE_DISTRIBUTION_MODE
    announce_distribution_mode(true)
end

local function enter_folder_count()
    state = STATE_FOLDER_COUNT
    announce_folder_count(true)
end

local function enter_starting_folder()
    state = STATE_STARTING_FOLDER
    announce_starting_folder(true)
end

local function enter_import()
    state = STATE_IMPORT
    announce_import(true)
end

local function perform_import()
    local target_folder_count = folder_count
    if distribution_mode == 2 then
        target_folder_count = scan.total_existing_folders() - start_folder_idx + 1
    end

    PreventUIRefresh(1)
    Undo_BeginBlock()
    placement.disable_ripple()

    local _, errors = polywav.run({
        sessions            = sessions,
        session_names       = session_names,
        composition_pattern = pattern_text,
        workflow            = workflow,
        distribution_mode   = distribution_mode,
        target_folder_count = target_folder_count,
        start_folder_idx    = start_folder_idx,
        start_pos           = GetCursorPosition(),
    })

    placement.finish_import_tail({
        errors          = errors,
        announce        = true,
        success_message = "Files imported successfully",
        script_path     = script_path:match("^(.+[\\/]).+[\\/]$") or script_path,
        undo_label      = "Import Audio",
    })
end

local function handle_key(char)
    if state == STATE_PATTERN then
        if char == KEY_ENTER then
            local ok, entered = ui_input.ask(WINDOW_TITLE, "Channel Pattern",
                "Pattern of 1 (mono) and 2 (stereo), e.g. 2 2 1 for the pattern 221", pattern_text)
            if ok then
                local trimmed = entered:gsub("%s", "")
                if trimmed ~= "" then pattern_text = trimmed end
                if evaluate_pattern() then
                    announce_pattern(false)
                    if is_vertical then enter_distribution_mode() else enter_import() end
                else
                    announce_pattern(true)
                end
            else
                say("Cancelled")
            end
        elseif char == KEY_ESC then
            say("Cancelled")
            return false
        end
    elseif state == STATE_DISTRIBUTION_MODE then
        if char == KEY_UP then
            dm_idx = dm_idx > 1 and dm_idx - 1 or #DISTRIBUTION_ORDER
            announce_distribution_mode(false)
        elseif char == KEY_DOWN then
            dm_idx = dm_idx < #DISTRIBUTION_ORDER and dm_idx + 1 or 1
            announce_distribution_mode(false)
        elseif char == KEY_ENTER then
            distribution_mode = DISTRIBUTION_ORDER[dm_idx]
            if distribution_mode == 1 then enter_folder_count() else enter_starting_folder() end
        elseif char == KEY_ESC then
            enter_pattern()
        end
    elseif state == STATE_FOLDER_COUNT then
        if char == KEY_ENTER then
            while true do
                local ok, entered = ui_input.ask(WINDOW_TITLE, "Folder Count",
                    "Number of folders", tostring(folder_count))
                if not ok then
                    say("Cancelled")
                    break
                end
                local n = tonumber(entered)
                if n and n >= 1 then
                    folder_count = math.floor(n)
                    enter_starting_folder()
                    break
                end
                say("Minimum of 1 folder required")
            end
        elseif char == KEY_ESC then
            enter_distribution_mode()
        end
    elseif state == STATE_STARTING_FOLDER then
        local total = scan.total_existing_folders()
        if char == KEY_UP then
            start_folder_idx = start_folder_idx > 1 and start_folder_idx - 1 or total
            announce_starting_folder(false)
        elseif char == KEY_DOWN then
            start_folder_idx = start_folder_idx < total and start_folder_idx + 1 or 1
            announce_starting_folder(false)
        elseif char == KEY_ENTER then
            enter_import()
        elseif char == KEY_ESC then
            if distribution_mode == 1 then enter_folder_count() else enter_distribution_mode() end
        end
    elseif state == STATE_IMPORT then
        if char == KEY_ENTER then
            perform_import()
            return false
        elseif char == KEY_ESC then
            if is_vertical then enter_starting_folder() else enter_pattern() end
        end
    end

    return true
end

local function status_line()
    if state == STATE_PATTERN then
        return "[Pattern]  " .. pattern_text
    elseif state == STATE_DISTRIBUTION_MODE then
        return "[Distribution]  " .. DISTRIBUTION_LABELS[DISTRIBUTION_ORDER[dm_idx]]
    elseif state == STATE_FOLDER_COUNT then
        return "[Folder Count]  " .. tostring(folder_count)
    elseif state == STATE_STARTING_FOLDER then
        return "[Starting Folder]  " .. scan.spoken_folder_label_for_index(start_folder_idx)
    elseif state == STATE_IMPORT then
        return "[Import]  Pattern " .. pattern_text
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
        if not handle_key(char) then
            gfx.quit()
            return
        end
    end
    draw_window()
    defer(main)
end

local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
workflow = wf
if workflow == "" then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end
is_vertical = (workflow == "Vertical")

say("Scanning files in project media folder")
local candidates = polywav.scan_candidates()
local parse_errors
sessions, session_names, parse_errors = polywav.build_sessions(candidates)
say("Scan complete")

if #candidates == 0 then
    MB("No unused multi-channel files were found in the project recording path.",
        "Import Aborted", 0)
    return
end

if #parse_errors > 0 then
    MB("These polywav files need to be renamed to [SessionName_]T###.ext "
        .. "(session optional, take number required):\n\n" .. table.concat(parse_errors, "\n"),
        "Import Aborted", 0)
    return
end

for _, session_name in ipairs(session_names) do
    for _, candidate in pairs(sessions[session_name]) do
        total_takes = total_takes + 1
        if not channel_count then
            channel_count = candidate.channel_count
        elseif candidate.channel_count ~= channel_count then
            MB("Selected polywav files have differing channel counts -- "
                .. "all files in one import must match.", "Import Aborted", 0)
            return
        end
    end
end

local _, mode_str  = GetProjExtState(0, "ReaClassical", "ImportDistributionMode")
local _, count_str = GetProjExtState(0, "ReaClassical", "ImportFolderCount")
distribution_mode = (mode_str ~= "") and (tonumber(mode_str) or 0) or 0
for i, mode in ipairs(DISTRIBUTION_ORDER) do
    if mode == distribution_mode then dm_idx = i break end
end
folder_count     = (count_str ~= "") and (tonumber(count_str) or 2) or 2
start_folder_idx = scan.get_start_folder_idx_from_selection()

gfx.init(WINDOW_TITLE, 500, 44, 0)
enter_pattern()
defer(main)
