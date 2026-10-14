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
local scan = require("ReaClassical_Smart_Import_Scan")
local polywav = require("ReaClassical_Polywav_Import")
local ui_input = require("ReaClassical_Accessible_Input")

set_action_options(3)

local WINDOW_TITLE = "Smart Import"

local STATE_TRACK_ORDER       = "track_order"
local STATE_DISTRIBUTION_MODE = "distribution_mode"
local STATE_FOLDER_COUNT      = "folder_count"
local STATE_STARTING_FOLDER   = "starting_folder"
local STATE_FILTER_SESSION    = "filter_session"
local STATE_FILTER_TAKES      = "filter_takes"
local STATE_IMPORT            = "import"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_TAB   = 9
local KEY_ESC   = 27

local state = nil
local last_char = 0

local workflow      = ""
local is_vertical    = false
local needed_names   = {}
local has_track_order = false

local track_order_combined = {}
local track_order_slots    = 0
local to_position          = 1
local to_picked_up         = false
local to_original_position = 1

local DISTRIBUTION_ORDER = { 0, 2, 1 }
local DISTRIBUTION_LABELS = {
    [0] = "One folder per take",
    [2] = "Use current folder count",
    [1] = "Round-robin across custom number of folders",
}

local dm_idx        = 1
local distribution_mode = 0
local folder_count      = 2
local start_folder_idx  = 2

local filter_session_text = ""
local filter_takes_text   = ""

local function is_assigned(pos)
    return pos <= track_order_slots
end

local function announce_track_order(with_hint)
    local entry = track_order_combined[to_position]
    if not entry then say("No tracks found") return end
    local status = is_assigned(to_position) and "to be assigned" or "not used this run"
    if with_hint then
        say(string.format("Track Name Order. %d of %d: %s, %s. Up or down to browse, "
            .. "Enter to pick up, Tab to confirm and continue, Escape to cancel import.",
            to_position, #track_order_combined, entry.display_name, status))
    else
        say(string.format("%d: %s, %s", to_position, entry.display_name, status))
    end
end

local function announce_to_picked_up(with_hint)
    local entry = track_order_combined[to_position]
    local status = is_assigned(to_position) and "to be assigned" or "not used this run"
    if with_hint then
        say(string.format("Picked up %s. Up or down to move, Enter to drop, Escape to cancel move.",
            entry.display_name))
    else
        say(string.format("Position %d: %s, %s", to_position, entry.display_name, status))
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
            .. "keep or change it there. Enter continues, Escape goes back.", folder_count))
    else
        say(folder_count_str ~= "" and folder_count_str or tostring(folder_count))
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

local function announce_filter_session(with_hint)
    local val = filter_session_text ~= "" and filter_session_text or "Any"
    if with_hint then
        say("Sessions: " .. val .. ". Enter to filter, Up or down to navigate, Escape to go back.")
    else
        say(val)
    end
end

local function announce_filter_takes(with_hint)
    local val = filter_takes_text ~= "" and filter_takes_text or "All"
    if with_hint then
        say("Takes: " .. val .. ". Enter to set range, Up or down to navigate, Escape to go back.")
    else
        say(val)
    end
end

local function announce_import(with_hint)
    local session_desc = filter_session_text ~= "" and filter_session_text or "Any"
    local takes_desc = filter_takes_text ~= "" and filter_takes_text or "All"
    if with_hint then
        say(string.format(
            "Import. Sessions: %s. Takes: %s. Enter to import, Up or down to navigate, Escape to go back.",
            session_desc, takes_desc))
    else
        say(string.format("Import. Sessions: %s. Takes: %s.", session_desc, takes_desc))
    end
end

local function enter_track_order()
    state = STATE_TRACK_ORDER
    to_position, to_picked_up = 1, false
    announce_track_order(true)
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

local function enter_filter_session()
    state = STATE_FILTER_SESSION
    announce_filter_session(true)
end

local function enter_filter_takes()
    state = STATE_FILTER_TAKES
    announce_filter_takes(true)
end

local function enter_import()
    state = STATE_IMPORT
    announce_import(true)
end

local function perform_import()
    local args = {}

    if has_track_order then
        local order = {}
        for i = 1, track_order_slots do
            local entry = track_order_combined[i]
            if entry then order[#order + 1] = entry.base_name end
        end
        args.track_order = order
    end

    if is_vertical then
        args.start_folder_idx = start_folder_idx
        local mode = DISTRIBUTION_ORDER[dm_idx]
        if mode == 1 then
            args.robin_folder_count = folder_count
        elseif mode == 2 then
            args.robin_folder_count = "current"
        end
    end

    if filter_session_text ~= "" or filter_takes_text ~= "" then
        args.post_filter = { session_text = filter_session_text, takes_text = filter_takes_text }
    end

    _G.RC_SCRIPT_ARGS = args
    dofile(parent_path .. "ReaClassical_Smart Import Audio.lua")
    _G.RC_SCRIPT_ARGS = nil
end

local function handle_key(char)
    if state == STATE_TRACK_ORDER then
        if to_picked_up then
            if char == KEY_UP then
                if to_position > 1 then
                    local entry = table.remove(track_order_combined, to_position)
                    to_position = to_position - 1
                    table.insert(track_order_combined, to_position, entry)
                    announce_to_picked_up(false)
                else
                    say("Top of list")
                end
            elseif char == KEY_DOWN then
                if to_position < #track_order_combined then
                    local entry = table.remove(track_order_combined, to_position)
                    to_position = to_position + 1
                    table.insert(track_order_combined, to_position, entry)
                    announce_to_picked_up(false)
                else
                    say("Bottom of list")
                end
            elseif char == KEY_ENTER then
                to_picked_up = false
                say("Dropped")
                announce_track_order(false)
            elseif char == KEY_ESC then
                local entry = table.remove(track_order_combined, to_position)
                table.insert(track_order_combined, to_original_position, entry)
                to_position = to_original_position
                to_picked_up = false
                say("Cancelled")
                announce_track_order(false)
            end
        else
            if char == KEY_UP then
                to_position = to_position > 1 and to_position - 1 or #track_order_combined
                announce_track_order(false)
            elseif char == KEY_DOWN then
                to_position = to_position < #track_order_combined and to_position + 1 or 1
                announce_track_order(false)
            elseif char == KEY_ENTER then
                to_original_position = to_position
                to_picked_up = true
                announce_to_picked_up(true)
            elseif char == KEY_TAB then
                if is_vertical then enter_distribution_mode() else enter_filter_session() end
            elseif char == KEY_ESC then
                say("Cancelled")
                return false
            end
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
            if distribution_mode == 1 then
                enter_folder_count()
            else
                enter_starting_folder()
            end
        elseif char == KEY_ESC then
            if has_track_order then enter_track_order() else say("Cancelled") return false end
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
                    folder_count = n
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
            enter_filter_session()
        elseif char == KEY_ESC then
            if distribution_mode == 1 then enter_folder_count() else enter_distribution_mode() end
        end
    elseif state == STATE_FILTER_SESSION then
        if char == KEY_ENTER then
            local ok, entered = ui_input.ask(WINDOW_TITLE, "Filter Sessions",
                "Only these sessions, blank for all", filter_session_text)
            if ok then
                filter_session_text = entered
                enter_filter_takes()
            else
                say("Cancelled")
            end
        elseif char == KEY_DOWN then
            enter_filter_takes()
        elseif char == KEY_UP then
            enter_import()
        elseif char == KEY_ESC then
            if is_vertical then
                enter_starting_folder()
            elseif has_track_order then
                enter_track_order()
            else
                say("Cancelled")
                return false
            end
        end
    elseif state == STATE_FILTER_TAKES then
        if char == KEY_ENTER then
            local ok, entered = ui_input.ask(WINDOW_TITLE, "Filter Takes",
                "Takes e.g. 1-3,5,11-15, blank for all", filter_takes_text)
            if ok then
                filter_takes_text = entered
                enter_import()
            else
                say("Cancelled")
            end
        elseif char == KEY_DOWN then
            enter_import()
        elseif char == KEY_UP then
            enter_filter_session()
        elseif char == KEY_ESC then
            enter_filter_session()
        end
    elseif state == STATE_IMPORT then
        if char == KEY_ENTER then
            perform_import()
            return false
        elseif char == KEY_DOWN then
            enter_filter_session()
        elseif char == KEY_UP or char == KEY_ESC then
            enter_filter_takes()
        end
    end

    return true
end

local function status_line()
    if state == STATE_TRACK_ORDER then
        local entry = track_order_combined[to_position]
        local label = entry and entry.display_name or ""
        return "[Track Order]  " .. label .. (is_assigned(to_position) and "" or "  (unused)")
    elseif state == STATE_DISTRIBUTION_MODE then
        return "[Distribution]  " .. DISTRIBUTION_LABELS[DISTRIBUTION_ORDER[dm_idx]]
    elseif state == STATE_FOLDER_COUNT then
        return "[Folder Count]  " .. tostring(folder_count)
    elseif state == STATE_STARTING_FOLDER then
        return "[Starting Folder]  " .. scan.spoken_folder_label_for_index(start_folder_idx)
    elseif state == STATE_FILTER_SESSION then
        return "[Sessions]  " .. (filter_session_text ~= "" and filter_session_text or "Any")
    elseif state == STATE_FILTER_TAKES then
        return "[Takes]  " .. (filter_takes_text ~= "" and filter_takes_text or "All")
    elseif state == STATE_IMPORT then
        return "[Import]  Sessions: " .. (filter_session_text ~= "" and filter_session_text or "Any")
            .. "  Takes: " .. (filter_takes_text ~= "" and filter_takes_text or "All")
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
is_vertical = (workflow == "Vertical")
local is_rc_project    = (workflow ~= "")
local is_blank_project = (not is_rc_project and CountTracks(0) == 0)

if is_blank_project then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Smart Import requires a saved ReaClassical project with audio files "
        .. "in the project recording path.\n\n"
        .. "Please create and save a ReaClassical project first (" .. modifier .. "+N), "
        .. "then place your audio files in the project media folder before running Smart Import.",
        "Smart Import", 0)
    return
end

if not is_rc_project then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

if not is_blank_project then
    local named_count, blank_count = 0, 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            local _, name = GetTrackName(track)
            local stripped = name:gsub("^M:?", ""):gsub("^%s*(.-)%s*$", "%1")
            if stripped ~= "" then named_count = named_count + 1 else blank_count = blank_count + 1 end
        end
    end
    if named_count > 0 and blank_count > 0 then
        MB("Some mixer tracks are named and some are not.\n\n"
            .. "Please use Mission Control to either:\n"
            .. "  • Remove all track names (Smart Import will then auto-name them), or\n"
            .. "  • Finish naming the remaining blank tracks.",
            "Smart Import", 0)
        return
    end
end

say("Scanning files in project media folder")

local used_files = scan.get_used_source_files()

local polywav_exclude = {}
for _, c in ipairs(polywav.scan_candidates()) do
    polywav_exclude[c.filepath:gsub("\\", "/")] = true
end

local all_files = {}
for _, filepath in ipairs(scan.scan_media_folder_recursive(scan.get_project_media_path())) do
    if not polywav_exclude[filepath:gsub("\\", "/")] then
        table.insert(all_files, filepath)
    end
end

local files = {}
for _, filepath in ipairs(all_files) do
    local normalized = filepath:gsub("\\", "/")
    if not used_files[normalized] then
        table.insert(files, filepath)
    end
end

if #all_files == 0 then
    MB("No audio files were found in the project recording path. Please add audio files and try again.",
        "Import Aborted", 0)
    return
end

if #files == 0 then
    MB("No unused audio files were found in the project recording path. All files are already in the project.",
        "Import Aborted", 0)
    return
end

local errors = {}
local name_seen = {}
local parsed_count = 0

for _, filepath in ipairs(files) do
    local info = scan.parse_canonical_filename(filepath)
    if not info then
        table.insert(errors, filepath:match("([^/\\]+)$") .. " (invalid filename format)")
    else
        parsed_count = parsed_count + 1
        if not name_seen[info.track_name] then
            name_seen[info.track_name] = true
            table.insert(needed_names, { base_name = info.track_name, display_name = info.track_name_display })
        end
    end
end

say("Scan complete")

if parsed_count == 0 then
    MB("Audio files were found but none matched the expected naming pattern.\n"
        .. "Files should be named like: trackname_T001.wav\n\n"
        .. "The following issues were found:\n\n" .. table.concat(errors, "\n"),
        "Import Aborted", 0)
    return
end

if #errors > 0 then
    MB("Some files could not be matched to the expected naming pattern.\n"
        .. "Please fix or remove these files and try again:\n\n"
        .. table.concat(errors, "\n"),
        "Import Aborted", 0)
    return
end

local blank_slots = scan.count_blank_mixer_tracks()
has_track_order = #needed_names > 0 and blank_slots > 0

if has_track_order then
    track_order_slots = math.min(blank_slots, #needed_names)
    for _, entry in ipairs(needed_names) do
        track_order_combined[#track_order_combined + 1] = entry
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

if has_track_order then
    enter_track_order()
elseif is_vertical then
    enter_distribution_mode()
else
    enter_filter_session()
end

defer(main)
