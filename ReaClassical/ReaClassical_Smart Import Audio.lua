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

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()
if _clara_or_debug then
    set_action_options(3)

    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    package.path = package.path .. ";" .. script_path .. "lib/?.lua;"
    local say = require("ReaClassical_Announce")
    local polywav = require("ReaClassical_Polywav_Import")

    if #polywav.scan_candidates() == 0 then
        dofile(script_path .. "lib/ReaClassical_Accessible Smart Import.lua")
        return
    end

    local CHOICE_LABELS = { "Import Takes", "Import Polywav" }
    local CHOICE_TARGETS = {
        script_path .. "lib/ReaClassical_Accessible Smart Import.lua",
        script_path .. "ReaClassical_Accessible Import Polywav.lua",
    }
    local KEY_UP, KEY_DOWN, KEY_ENTER, KEY_ESC = 30064, 1685026670, 13, 27
    local choice_idx = 1
    local last_char = 0

    local function draw()
        gfx.set(0.12, 0.12, 0.12, 1)
        gfx.rect(0, 0, gfx.w, gfx.h, true)
        gfx.set(0.9, 0.9, 0.9, 1)
        gfx.setfont(1, "Arial", 15)
        gfx.x, gfx.y = 8, 13
        gfx.drawstr("[Smart Import Audio]  " .. CHOICE_LABELS[choice_idx])
        gfx.update()
    end

    local function picker_loop()
        local char = gfx.getchar()
        if char == -1 then gfx.quit() return end
        if char == 0 then
            last_char = 0
        elseif char ~= last_char then
            last_char = char
            if char == KEY_UP then
                choice_idx = choice_idx > 1 and choice_idx - 1 or #CHOICE_LABELS
                say(CHOICE_LABELS[choice_idx])
            elseif char == KEY_DOWN then
                choice_idx = choice_idx < #CHOICE_LABELS and choice_idx + 1 or 1
                say(CHOICE_LABELS[choice_idx])
            elseif char == KEY_ENTER then
                gfx.quit()
                dofile(CHOICE_TARGETS[choice_idx])
                return
            elseif char == KEY_ESC then
                gfx.quit()
                return
            end
        end
        draw()
        defer(picker_loop)
    end

    gfx.init("Smart Import Audio", 400, 44, 0)
    say("Smart Import Audio. " .. CHOICE_LABELS[1]
        .. ". Up or down to move, Enter to select, Escape to cancel.")
    defer(picker_loop)
    return
end

local main, generate_preview_ui
local show_import_dialog, import_vertical_round_robin
local show_track_order_dialog, draw_track_order_dialog
local finish_import
local continue_named_track_import

set_action_options(2)

local imgui_exists = APIExists("ImGui_GetVersion")
local ImGui = nil
local ctx = nil

local dialog_open = false
local distribution_mode = 0
local target_folder_count = 1
local start_folder_idx = 2
local filter_session_text = ""
local filter_takes_text = ""
local import_confirmed = false
local import_cancelled = false

local track_order_open      = false
local track_order_confirmed = false
local track_order_cancelled = false
local track_order_list      = {}
local track_order_unused    = {}
local track_order_slots     = 0

local polywav_available_candidates = {}
local polywav_committed = false
local polywav_only = false
local polywav_workflow, polywav_has_existing_items
local polywav_sessions, polywav_session_names, polywav_parse_errors
local polywav_pattern_text      = "1"
local polywav_distribution_mode = 0
local polywav_folder_count      = 2
local polywav_start_folder_idx  = 2

local cached_sessions = nil
local cached_session_names = nil
local cached_total_takes = 0
local cached_max_takes_per_session = 0
local cached_workflow = ""

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local scan = require("ReaClassical_Smart_Import_Scan")
local placement = require("ReaClassical_Import_Placement")
local polywav = require("ReaClassical_Polywav_Import")

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local is_rc_project    = (workflow ~= "")
    local is_blank_project = (not is_rc_project and CountTracks(0) == 0)

    if is_blank_project then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
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
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    if not is_blank_project then
        local named_count = 0
        local blank_count = 0
        for i = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, i)
            local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
            if mixer_state == "y" then
                local _, name = GetTrackName(track)
                local stripped = name:gsub("^M:?", ""):gsub("^%s*(.-)%s*$", "%1")
                if stripped ~= "" then
                    named_count = named_count + 1
                else
                    blank_count = blank_count + 1
                end
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

    local has_existing_items = CountMediaItems(0) > 0
    local start_pos = GetCursorPosition()

    continue_named_track_import(workflow, has_existing_items, start_pos)
end

function continue_named_track_import(workflow, has_existing_items, start_pos)
    local used_files = scan.get_used_source_files()

    polywav_available_candidates = polywav.scan_candidates()
    local polywav_exclude = {}
    for _, c in ipairs(polywav_available_candidates) do
        polywav_exclude[c.filepath:gsub("\\", "/")] = true
    end

    polywav_committed          = false
    polywav_only               = false
    polywav_workflow           = workflow
    polywav_has_existing_items = has_existing_items
    polywav_sessions, polywav_session_names, polywav_parse_errors =
        polywav.build_sessions(polywav_available_candidates)
    polywav_pattern_text      = "1"
    polywav_distribution_mode = 0
    polywav_folder_count      = 2
    polywav_start_folder_idx  = scan.get_start_folder_idx_from_selection()

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

    if #files == 0 and #polywav_available_candidates > 0
        and imgui_exists and not _G.RC_SCRIPT_ARGS then
        polywav_only = true
        show_import_dialog({}, {}, workflow)

        local function wait_for_polywav_dialog()
            if dialog_open then
                defer(wait_for_polywav_dialog)
                return
            end
            if not polywav_committed then
                Undo_EndBlock("Import Audio (Cancelled)", -1)
                PreventUIRefresh(-1)
                UpdateArrange()
            end
        end

        wait_for_polywav_dialog()
        return
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

    local parsed_files = {}
    local name_seen   = {}
    local needed_names = {}

    for _, filepath in ipairs(files) do
        local info = scan.parse_canonical_filename(filepath)
        if not info then
            table.insert(errors, filepath:match("([^/\\]+)$") .. " (invalid filename format)")
        else
            table.insert(parsed_files, { info = info, filepath = filepath })
            if not name_seen[info.track_name] then
                name_seen[info.track_name] = true
                table.insert(needed_names, {
                    base_name    = info.track_name,
                    display_name = info.track_name_display,
                })
            end
        end
    end

    if #parsed_files == 0 then
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

    if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.filter then
        local f = _G.RC_SCRIPT_ARGS.filter
        local filtered_files = {}
        for _, pf in ipairs(parsed_files) do
            local info = pf.info
            if f.take_set[info.take_num]
                and (not f.session or info.session_name == f.session) then
                table.insert(filtered_files, pf)
            end
        end

        if #filtered_files == 0 then
            say("No matching takes found")
            Undo_EndBlock("Import Audio (Cancelled)", -1)
            PreventUIRefresh(-1)
            return
        end

        parsed_files = filtered_files
        name_seen    = {}
        needed_names = {}
        for _, pf in ipairs(parsed_files) do
            if not name_seen[pf.info.track_name] then
                name_seen[pf.info.track_name] = true
                table.insert(needed_names, {
                    base_name    = pf.info.track_name,
                    display_name = pf.info.track_name_display,
                })
            end
        end
    end

    local function build_sessions()
        local tracks = scan.get_tracks(workflow)
        local sessions = {}

        local unused_set = {}
        for _, entry in ipairs(track_order_unused) do
            unused_set[entry.base_name] = true
        end

        for _, pf in ipairs(parsed_files) do
            local info      = pf.info
            local track_obj = scan.find_track_by_name(tracks, info.track_name)

            if not track_obj then
                if not unused_set[info.track_name] then
                    table.insert(errors, info.filename
                        .. " (no track match for '" .. info.track_name .. "')")
                end
            else
                if not sessions[info.session_name] then
                    sessions[info.session_name] = {}
                end
                if not sessions[info.session_name][info.take_num] then
                    sessions[info.session_name][info.take_num] = {}
                end
                track_obj.track_name_display = info.track_name_display
                sessions[info.session_name][info.take_num][track_obj] = pf.filepath
            end
        end

        local session_names = {}
        for session_name in pairs(sessions) do
            table.insert(session_names, session_name)
        end
        table.sort(session_names, function(a, b)
            if a == "default" then return true end
            if b == "default" then return false end
            return a < b
        end)

        return sessions, session_names, scan.get_tracks(workflow)
    end

    if imgui_exists and not _G.RC_SCRIPT_ARGS then
        if not ImGui then
            package.path = ImGui_GetBuiltinPath() .. '/?.lua'
            ImGui = require 'imgui' '0.10'
            ctx = ImGui.CreateContext('ReaClassical Smart Import')
        end

        local function do_import_dialog()
            local sessions, session_names, tracks = build_sessions()

            if #session_names == 0 then
                MB("Audio files were found but none matched the expected naming pattern.\n"
                    .. "Files should be named like: trackname_T001.wav\n\n"
                    .. "The following issues were found:\n\n" .. table.concat(errors, "\n"),
                    "Import Aborted", 0)
                Undo_EndBlock("Import Audio (Cancelled)", -1)
                PreventUIRefresh(-1)
                UpdateArrange()
                return
            end

            show_import_dialog(sessions, session_names, workflow)

            local function wait_for_import_dialog()
                if dialog_open then
                    defer(wait_for_import_dialog)
                    return
                end

                if polywav_committed then
                    return
                end

                if not import_confirmed then
                    Undo_EndBlock("Import Audio (Cancelled)", -1)
                    PreventUIRefresh(-1)
                    UpdateArrange()
                    return
                end

                local filter_active = filter_session_text ~= "" or filter_takes_text ~= ""
                local import_sessions, import_session_names = sessions, session_names
                if filter_active then
                    import_sessions, import_session_names = scan.filter_sessions_for_import(
                        sessions, session_names, filter_session_text,
                        scan.parse_take_range(filter_takes_text))
                end
                local import_start_pos = GetCursorPosition()

                placement.disable_ripple()

                if workflow == "Vertical" then
                    if distribution_mode == 1 or distribution_mode == 2 then
                        import_vertical_round_robin(import_sessions, import_session_names, tracks, errors,
                            target_folder_count, start_folder_idx, import_start_pos)
                    else
                        import_vertical(import_sessions, import_session_names, tracks, errors,
                            start_folder_idx, import_start_pos)
                    end
                else
                    import_horizontal(import_sessions, import_session_names, tracks, errors, import_start_pos)
                end

                finish_import(errors)
            end

            wait_for_import_dialog()
        end

        local function do_track_order_then_import()
            if #needed_names > 0 and scan.count_blank_mixer_tracks() > 0 then
                show_track_order_dialog(needed_names)

                local function after_track_order()
                    if track_order_open then
                        defer(after_track_order)
                        return
                    end

                    if polywav_committed then
                        return
                    end

                    if track_order_cancelled or #track_order_list == 0 then
                        Undo_EndBlock("Import Audio (Cancelled)", -1)
                        PreventUIRefresh(-1)
                        UpdateArrange()
                        return
                    end

                    placement.ensure_tracks_exist(track_order_list, workflow)
                    do_import_dialog()
                end

                after_track_order()
            else
                do_import_dialog()
            end
        end

        do_track_order_then_import()

        return
    end

    if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.track_order then
        local chosen_set = {}
        track_order_list, track_order_unused = {}, {}
        for _, base_name in ipairs(_G.RC_SCRIPT_ARGS.track_order) do
            for _, entry in ipairs(needed_names) do
                if entry.base_name == base_name and not chosen_set[base_name] then
                    table.insert(track_order_list, entry)
                    chosen_set[base_name] = true
                    break
                end
            end
        end
        for _, entry in ipairs(needed_names) do
            if not chosen_set[entry.base_name] then
                table.insert(track_order_unused, entry)
            end
        end
        if #track_order_list > 0 then
            placement.ensure_tracks_exist(track_order_list, workflow)
        end
    elseif #needed_names > 0 then
        placement.ensure_tracks_exist(needed_names, workflow)
    end

    local sessions, session_names, tracks = build_sessions()

    if #session_names == 0 then
        MB("Audio files were found but none matched the expected naming pattern.\n"
            .. "Files should be named like: trackname_T001.wav\n\n"
            .. "The following issues were found:\n\n" .. table.concat(errors, "\n"),
            "Import Aborted", 0)
        return
    end

    if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.post_filter then
        local pf = _G.RC_SCRIPT_ARGS.post_filter
        sessions, session_names = scan.filter_sessions_for_import(
            sessions, session_names, pf.session_text, scan.parse_take_range(pf.takes_text))
        start_pos = GetCursorPosition()
    end

    placement.disable_ripple()

    if workflow == "Vertical" then
        if _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.start_folder_idx then
            start_folder_idx = _G.RC_SCRIPT_ARGS.start_folder_idx
        end

        local robin_folder_count = _G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.robin_folder_count
        if robin_folder_count then
            if robin_folder_count == "current" then
                robin_folder_count = scan.total_existing_folders() - start_folder_idx + 1
            end
            robin_folder_count = math.max(1, robin_folder_count)
            import_vertical_round_robin(sessions, session_names, tracks, errors,
                robin_folder_count, start_folder_idx, start_pos)
        else
            import_vertical(sessions, session_names, tracks, errors, start_folder_idx, start_pos)
        end
    else
        import_horizontal(sessions, session_names, tracks, errors, start_pos)
    end

    finish_import(errors)
end

function finish_import(errors)
    placement.finish_import_tail({
        errors          = errors,
        announce        = _G.RC_SCRIPT_ARGS ~= nil,
        success_message = "Files imported successfully",
        script_path     = script_path,
        undo_label      = "Import Audio",
    })
end

function draw_polywav_tab()
    ImGui.Spacing(ctx)

    if #polywav_parse_errors > 0 then
        ImGui.TextWrapped(ctx, "These polywav files need to be renamed to "
            .. "[SessionName_]T###.ext (session optional, take number required) "
            .. "before they can be imported:")
        ImGui.Spacing(ctx)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
        for _, e in ipairs(polywav_parse_errors) do
            ImGui.Bullet(ctx)
            ImGui.SameLine(ctx)
            ImGui.Text(ctx, e)
        end
        ImGui.PopStyleColor(ctx)
        return
    end

    local total_takes = 0
    local channel_count, mismatch = nil, false
    for _, session_name in ipairs(polywav_session_names) do
        local session_data = polywav_sessions[session_name]
        local take_nums = {}
        for take_num, candidate in pairs(session_data) do
            table.insert(take_nums, take_num)
            total_takes = total_takes + 1
            if not channel_count then channel_count = candidate.channel_count
            elseif candidate.channel_count ~= channel_count then mismatch = true end
        end
        table.sort(take_nums)

        local labels = {}
        for _, tn in ipairs(take_nums) do labels[#labels + 1] = string.format("T%03d", tn) end
        local display_name = session_name == "default" and "No Session Name" or session_name
        ImGui.Bullet(ctx)
        ImGui.SameLine(ctx)
        ImGui.Text(ctx, string.format("%s (%d ch): %s",
            display_name, session_data[take_nums[1]].channel_count, table.concat(labels, ", ")))
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    ImGui.Text(ctx, "Channel composition pattern (e.g. 1, 2, 21, 221):")
    ImGui.SetNextItemWidth(ctx, 100)
    local changed_p, new_p = ImGui.InputText(ctx, "##pw_pattern", polywav_pattern_text)
    if changed_p then polywav_pattern_text = new_p end
    if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "Each digit is a group size (1 = mono, 2 = stereo). Once the "
            .. "digits are used once, the last one repeats until the remainder becomes mono, "
            .. "e.g. \"221\" on 20 channels: two stereo pairs, then 16 mono.")
    end

    ImGui.Spacing(ctx)

    local groups, ordered_names, comp_err
    local cap_ok, cap_msg = true, nil
    if channel_count and not mismatch then
        groups, ordered_names, comp_err = polywav.compute_composition(channel_count, polywav_pattern_text)
        if groups then
            cap_ok, cap_msg = polywav.validate_capacity(#groups, polywav_workflow)
        end
    end

    if not channel_count then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
        ImGui.Text(ctx, "No polywav takes found.")
        ImGui.PopStyleColor(ctx)
    elseif mismatch then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
        ImGui.Text(ctx, "Found sessions have differing channel counts -- all polywavs in one import must match.")
        ImGui.PopStyleColor(ctx)
    elseif not groups then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
        ImGui.Text(ctx, comp_err)
        ImGui.PopStyleColor(ctx)
    elseif not cap_ok then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
        ImGui.Text(ctx, cap_msg)
        ImGui.PopStyleColor(ctx)
    else
        local labels = {}
        for _, n in ipairs(ordered_names) do labels[#labels + 1] = n.display_name end
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x88CCFFFF)
        ImGui.TextWrapped(ctx, string.format("Needs %d track%s per folder: %s",
            #groups, #groups == 1 and "" or "s", table.concat(labels, ", ")))
        ImGui.PopStyleColor(ctx)
    end

    local is_vertical = polywav_workflow == "Vertical"
    if is_vertical then
        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)
        ImGui.Text(ctx, "Distribution Mode:")

        local changed_m, new_m = ImGui.RadioButtonEx(ctx, "One folder per take", polywav_distribution_mode, 0)
        if changed_m then polywav_distribution_mode = new_m end
        changed_m, new_m = ImGui.RadioButtonEx(ctx, "Use current folder count", polywav_distribution_mode, 2)
        if changed_m then polywav_distribution_mode = new_m end
        changed_m, new_m = ImGui.RadioButtonEx(ctx, "Round-robin across custom number of folders",
            polywav_distribution_mode, 1)
        if changed_m then polywav_distribution_mode = new_m end

        if polywav_distribution_mode ~= 1 then ImGui.BeginDisabled(ctx) end
        ImGui.Text(ctx, "Number of folders:")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_c, new_c = ImGui.SliderInt(ctx, "##pw_folder_count", polywav_folder_count, 1,
            math.max(1, total_takes))
        if changed_c then polywav_folder_count = new_c end
        if polywav_distribution_mode ~= 1 then ImGui.EndDisabled(ctx) end

        ImGui.Spacing(ctx)

        local folder_options = {}
        for i = 1, scan.total_existing_folders() do
            folder_options[#folder_options + 1] = scan.folder_label_for_index(i)
        end
        local combo_str = table.concat(folder_options, "\0") .. "\0"
        ImGui.Text(ctx, "Starting folder:")
        ImGui.SetNextItemWidth(ctx, 120)
        local changed_s, new_s = ImGui.Combo(ctx, "##pw_start_folder", polywav_start_folder_idx - 1, combo_str)
        if changed_s then polywav_start_folder_idx = new_s + 1 end
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    local button_width = (ImGui.GetContentRegionAvail(ctx) - 8) / 2

    local can_import = channel_count and not mismatch and groups and cap_ok
    if not can_import then ImGui.BeginDisabled(ctx) end
    if ImGui.Button(ctx, "Import", button_width, 30) then
        local target_folder_count = polywav_folder_count
        if polywav_distribution_mode == 2 then
            target_folder_count = scan.total_existing_folders() - polywav_start_folder_idx + 1
        end

        placement.disable_ripple()
        local _, errors = polywav.run({
            sessions             = polywav_sessions,
            session_names        = polywav_session_names,
            composition_pattern  = polywav_pattern_text,
            workflow              = polywav_workflow,
            distribution_mode     = polywav_distribution_mode,
            target_folder_count   = target_folder_count,
            start_folder_idx      = polywav_start_folder_idx,
            start_pos             = GetCursorPosition(),
        })
        finish_import(errors)
        polywav_committed = true
        track_order_open  = false
        dialog_open       = false
    end
    if not can_import then ImGui.EndDisabled(ctx) end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Cancel", button_width, 30) then
        track_order_open = false
        dialog_open       = false
    end
end

function show_track_order_dialog(needed_names)
    track_order_slots = scan.count_blank_mixer_tracks()

    track_order_list   = {}
    track_order_unused = {}
    for i, entry in ipairs(needed_names) do
        local dest = (i <= track_order_slots) and track_order_list or track_order_unused
        table.insert(dest, { base_name = entry.base_name, display_name = entry.display_name })
    end

    track_order_open      = true
    track_order_confirmed = false
    track_order_cancelled = false

    local function loop()
        if not track_order_open then return end
        draw_track_order_dialog()
        if track_order_open then defer(loop) end
    end

    loop()
end

function draw_track_order_dialog()
    local FLT_MAX  = select(2, ImGui.NumericLimits_Float())
    local two_col  = #track_order_unused > 0
    local min_w    = two_col and 500 or 260
    ImGui.SetNextWindowSizeConstraints(ctx, min_w, 200, FLT_MAX, FLT_MAX)

    local visible, open = ImGui.Begin(ctx, "Track Name Order", true,
        ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize)
    track_order_open = open

    if not visible then return end

    local has_polywav_tab = #polywav_available_candidates > 0
    local show_named_content = true

    if has_polywav_tab then
        if not ImGui.BeginTabBar(ctx, "SmartImportTabs") then
            ImGui.End(ctx)
            return
        end
        show_named_content = ImGui.BeginTabItem(ctx, "Named Tracks")
    end

    if show_named_content then

    local slots_used = #track_order_list
    local col_w      = 220

    if two_col then
        ImGui.Text(ctx, string.format("To be named  (%d / %d slots)", slots_used, track_order_slots))
        ImGui.SameLine(ctx)
        ImGui.SetCursorPosX(ctx, 280)
        ImGui.Text(ctx, "Not used this run")
    else
        ImGui.Text(ctx, "Drag rows to set the order in which names")
        ImGui.Text(ctx, "will be assigned to mixer tracks.")
    end
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    local pending = nil

    ImGui.BeginGroup(ctx)

    for i, entry in ipairs(track_order_list) do
        ImGui.PushID(ctx, "active_" .. i)

        ImGui.Selectable(ctx, string.format("  ≡  %s", entry.display_name), false,
            ImGui.SelectableFlags_None, col_w, ImGui.GetTextLineHeight(ctx))

        if ImGui.BeginDragDropSource(ctx, ImGui.DragDropFlags_None) then
            ImGui.SetDragDropPayload(ctx, "RC_TRACK", "active:" .. i)
            ImGui.Text(ctx, entry.display_name)
            ImGui.EndDragDropSource(ctx)
        end

        if ImGui.BeginDragDropTarget(ctx) then
            local ok, payload = ImGui.AcceptDragDropPayload(ctx, "RC_TRACK")
            if ok and payload then
                local src_list, src_idx = payload:match("^(%a+):(%d+)$")
                src_idx = tonumber(src_idx)
                if src_list == "active" and src_idx ~= i then
                    pending = { op = "reorder", list = "active", src = src_idx, before = i }
                elseif src_list == "unused" and slots_used < track_order_slots then
                    pending = { op = "transfer", from = "unused", src = src_idx,
                                to_list = "active", before = i }
                end
            end
            ImGui.EndDragDropTarget(ctx)
        end

        ImGui.PopID(ctx)
    end

    ImGui.PushID(ctx, "active_tail")
    ImGui.Dummy(ctx, col_w, 8)
    if ImGui.BeginDragDropTarget(ctx) then
        local ok, payload = ImGui.AcceptDragDropPayload(ctx, "RC_TRACK")
        if ok and payload then
            local src_list, src_idx = payload:match("^(%a+):(%d+)$")
            src_idx = tonumber(src_idx)
            if src_list == "active" then
                pending = { op = "reorder", list = "active", src = src_idx,
                            before = #track_order_list + 1 }
            elseif src_list == "unused" and slots_used < track_order_slots then
                pending = { op = "transfer", from = "unused", src = src_idx,
                            to_list = "active", before = #track_order_list + 1 }
            end
        end
        ImGui.EndDragDropTarget(ctx)
    end
    ImGui.PopID(ctx)

    ImGui.EndGroup(ctx)

    if two_col then
        ImGui.SameLine(ctx)
        ImGui.SetCursorPosX(ctx, 260)
        ImGui.BeginGroup(ctx)

        for i, entry in ipairs(track_order_unused) do
            ImGui.PushID(ctx, "unused_" .. i)

            ImGui.Selectable(ctx, string.format("  ≡  %s", entry.display_name), false,
                ImGui.SelectableFlags_None, col_w, ImGui.GetTextLineHeight(ctx))

            if ImGui.BeginDragDropSource(ctx, ImGui.DragDropFlags_None) then
                ImGui.SetDragDropPayload(ctx, "RC_TRACK", "unused:" .. i)
                ImGui.Text(ctx, entry.display_name)
                ImGui.EndDragDropSource(ctx)
            end

            if ImGui.BeginDragDropTarget(ctx) then
                local ok, payload = ImGui.AcceptDragDropPayload(ctx, "RC_TRACK")
                if ok and payload then
                    local src_list, src_idx = payload:match("^(%a+):(%d+)$")
                    src_idx = tonumber(src_idx)
                    if src_list == "unused" and src_idx ~= i then
                        pending = { op = "reorder", list = "unused", src = src_idx, before = i }
                    elseif src_list == "active" then
                        pending = { op = "transfer", from = "active", src = src_idx,
                                    to_list = "unused", before = i }
                    end
                end
                ImGui.EndDragDropTarget(ctx)
            end

            ImGui.PopID(ctx)
        end

        ImGui.PushID(ctx, "unused_tail")
        ImGui.Dummy(ctx, col_w, 8)
        if ImGui.BeginDragDropTarget(ctx) then
            local ok, payload = ImGui.AcceptDragDropPayload(ctx, "RC_TRACK")
            if ok and payload then
                local src_list, src_idx = payload:match("^(%a+):(%d+)$")
                src_idx = tonumber(src_idx)
                if src_list == "unused" then
                    pending = { op = "reorder", list = "unused", src = src_idx,
                                before = #track_order_unused + 1 }
                elseif src_list == "active" then
                    pending = { op = "transfer", from = "active", src = src_idx,
                                to_list = "unused", before = #track_order_unused + 1 }
                end
            end
            ImGui.EndDragDropTarget(ctx)
        end
        ImGui.PopID(ctx)

        ImGui.EndGroup(ctx)
    end

    if pending then
        if pending.op == "reorder" then
            local lst = (pending.list == "active") and track_order_list or track_order_unused
            local item = lst[pending.src]
            table.remove(lst, pending.src)
            local insert_at = (pending.src < pending.before)
                and (pending.before - 1) or pending.before
            insert_at = math.max(1, math.min(#lst + 1, insert_at))
            table.insert(lst, insert_at, item)
        elseif pending.op == "transfer" then
            local src_lst = (pending.from    == "active") and track_order_list or track_order_unused
            local dst_lst = (pending.to_list == "active") and track_order_list or track_order_unused
            local item    = src_lst[pending.src]
            table.remove(src_lst, pending.src)
            local insert_at = math.max(1, math.min(#dst_lst + 1, pending.before))
            table.insert(dst_lst, insert_at, item)
        end

        slots_used = #track_order_list
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    local btn_w = (ImGui.GetContentRegionAvail(ctx) - 8) / 2

    if ImGui.Button(ctx, "Confirm", btn_w, 0) then
        track_order_confirmed = true
        track_order_open      = false
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Cancel", btn_w, 0) then
        track_order_cancelled = true
        track_order_open      = false
    end

    if has_polywav_tab then ImGui.EndTabItem(ctx) end
    end

    if has_polywav_tab then
        if ImGui.BeginTabItem(ctx, "Polywav") then
            draw_polywav_tab()
            ImGui.EndTabItem(ctx)
        end
        ImGui.EndTabBar(ctx)
    end

    ImGui.End(ctx)
end

function show_import_dialog(sessions, session_names, workflow)
    if not ImGui then
        package.path = ImGui_GetBuiltinPath() .. '/?.lua'
        ImGui = require 'imgui' '0.10'
        ctx = ImGui.CreateContext('ReaClassical Smart Import')
    end

    cached_sessions      = sessions
    cached_session_names = session_names
    cached_workflow      = workflow

    cached_total_takes = 0
    local max_takes_per_session = 0
    for _, session_data in pairs(sessions) do
        local n = 0
        for _ in pairs(session_data) do
            cached_total_takes = cached_total_takes + 1
            n = n + 1
        end
        if n > max_takes_per_session then max_takes_per_session = n end
    end
    cached_max_takes_per_session = max_takes_per_session

    local current_folders = scan.count_source_folders()

    local _, mode_str        = GetProjExtState(0, "ReaClassical", "ImportDistributionMode")
    local _, count_str       = GetProjExtState(0, "ReaClassical", "ImportFolderCount")
    local _, start_folder_str = GetProjExtState(0, "ReaClassical", "ImportStartFolder")

    distribution_mode   = (mode_str ~= "")  and (tonumber(mode_str) or 0)                             or 0
    target_folder_count = (count_str ~= "") and (tonumber(count_str) or math.max(1, current_folders)) or math.max(1, current_folders)
    start_folder_idx    = (start_folder_str ~= "") and tonumber(start_folder_str) or 2
    start_folder_idx    = math.max(1, math.min(scan.total_existing_folders(), start_folder_idx))

    if distribution_mode == 0 then
        target_folder_count = max_takes_per_session
    elseif distribution_mode == 2 then
        target_folder_count = scan.total_existing_folders() - start_folder_idx + 1
    end
    target_folder_count = math.max(1, math.min(cached_max_takes_per_session, target_folder_count))

    filter_session_text = ""
    filter_takes_text   = ""

    dialog_open      = true
    import_confirmed = false
    import_cancelled = false

    local function dialog_loop()
        if not dialog_open then return end
        draw_import_dialog()
        if dialog_open then defer(dialog_loop) end
    end

    dialog_loop()
    return nil
end

function draw_import_dialog()
    local is_vertical = cached_workflow == "Vertical"
    local current_folders = scan.count_source_folders()
    local FLT_MAX = select(2, ImGui.NumericLimits_Float())
    ImGui.SetNextWindowSizeConstraints(ctx, 500, is_vertical and 400 or 260, FLT_MAX, FLT_MAX)

    local visible, open = ImGui.Begin(ctx, "ReaClassical Smart Import", true,
        ImGui.WindowFlags_NoCollapse)
    dialog_open = open

    if visible then

    local has_polywav_tab = #polywav_available_candidates > 0
    local show_named_content = not polywav_only

    if has_polywav_tab then
        if not ImGui.BeginTabBar(ctx, "SmartImportTabs") then
            ImGui.End(ctx)
            return
        end
        if not polywav_only then
            show_named_content = ImGui.BeginTabItem(ctx, "Named Tracks")
        end
    end

    if show_named_content then
        ImGui.Text(ctx, "Workflow: " .. cached_workflow)
        ImGui.Text(ctx, string.format("New files found: %d takes (%d session%s)",
            cached_total_takes, #cached_session_names,
            #cached_session_names == 1 and "" or "s"))
        if is_vertical then
            ImGui.Text(ctx, "Current folders: " .. current_folders)
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        ImGui.Text(ctx, "Import only these takes (optional):")

        ImGui.SetNextItemWidth(ctx, 180)
        local changed_sf, new_sf = ImGui.InputText(ctx, "Session name##filter_session",
            filter_session_text)
        if changed_sf then filter_session_text = new_sf end

        ImGui.SetNextItemWidth(ctx, 180)
        local changed_tf, new_tf = ImGui.InputText(ctx, "Takes, e.g. 1-3,5,11-15##filter_takes",
            filter_takes_text)
        if changed_tf then filter_takes_text = new_tf end

        local take_set = scan.parse_take_range(filter_takes_text)
        local filter_active = take_set ~= nil or filter_session_text ~= ""
        local active_sessions, active_session_names, active_total_takes, active_max_takes
        if filter_active then
            active_sessions, active_session_names, active_total_takes, active_max_takes =
                scan.filter_sessions_for_import(cached_sessions, cached_session_names,
                    filter_session_text, take_set)
        else
            active_sessions, active_session_names = cached_sessions, cached_session_names
            active_total_takes, active_max_takes = cached_total_takes, cached_max_takes_per_session
        end

        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x88CCFFFF)
        if filter_active then
            ImGui.Text(ctx, string.format("Will import: %d takes (%d session%s), inserted at the edit cursor (%.1fs)",
                active_total_takes, #active_session_names,
                #active_session_names == 1 and "" or "s", GetCursorPosition()))
        else
            ImGui.Text(ctx, string.format("Inserted at the edit cursor (%.1fs)", GetCursorPosition()))
        end
        ImGui.PopStyleColor(ctx)

        if is_vertical then
            if distribution_mode == 0 then
                target_folder_count = math.max(1, active_max_takes)
            elseif distribution_mode == 1 then
                target_folder_count = math.max(1, math.min(math.max(1, active_max_takes), target_folder_count))
            end
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        if active_total_takes == 0 then
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
            ImGui.Text(ctx, "No takes match this filter.")
            ImGui.PopStyleColor(ctx)
        end

        if is_vertical then
            ImGui.Text(ctx, "Distribution Mode:")

            local changed_mode, new_mode = ImGui.RadioButtonEx(ctx,
                "One folder per take", distribution_mode, 0)
            if changed_mode then
                distribution_mode   = new_mode
                target_folder_count = math.max(1, active_max_takes)
            end

            changed_mode, new_mode = ImGui.RadioButtonEx(ctx,
                "Use current folder count", distribution_mode, 2)
            if changed_mode then
                distribution_mode   = new_mode
                target_folder_count = scan.total_existing_folders() - start_folder_idx + 1
            end

            changed_mode, new_mode = ImGui.RadioButtonEx(ctx,
                "Round-robin across custom number of folders", distribution_mode, 1)
            if changed_mode then distribution_mode = new_mode end

            ImGui.Spacing(ctx)

            if distribution_mode ~= 1 then ImGui.BeginDisabled(ctx) end

            ImGui.Text(ctx, "Number of folders:")
            ImGui.SetNextItemWidth(ctx, -1)
            local changed_count, new_count = ImGui.SliderInt(ctx, "##folder_count",
                target_folder_count, 1, math.max(1, active_max_takes))
            if changed_count then target_folder_count = new_count end

            if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
                ImGui.SetTooltip(ctx, distribution_mode == 1
                    and "Right-click to type value"
                    or  "Only available in custom round-robin mode")
            end

            if distribution_mode == 1 and ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
                ImGui.OpenPopup(ctx, "folder_count_input")
            end

            if ImGui.BeginPopup(ctx, "folder_count_input") then
                ImGui.Text(ctx, "Enter folder count:")
                ImGui.SetNextItemWidth(ctx, 100)
                local rv, input = ImGui.InputText(ctx, "##folderinput",
                    string.format("%d", target_folder_count),
                    ImGui.InputTextFlags_EnterReturnsTrue)
                if rv then
                    local val = tonumber(input)
                    if val then
                        target_folder_count = math.max(1, math.min(math.max(1, active_max_takes), val))
                    end
                    ImGui.CloseCurrentPopup(ctx)
                end
                ImGui.EndPopup(ctx)
            end

            if distribution_mode ~= 1 then ImGui.EndDisabled(ctx) end

            ImGui.Spacing(ctx)

            local folder_options = {}
            for i = 1, scan.total_existing_folders() do
                folder_options[#folder_options + 1] = scan.folder_label_for_index(i)
            end
            local combo_str = table.concat(folder_options, "\0") .. "\0"

            ImGui.Text(ctx, "Starting folder:")
            ImGui.SetNextItemWidth(ctx, 120)
            local changed_start, new_start = ImGui.Combo(ctx, "##start_folder",
                start_folder_idx - 1, combo_str)
            if changed_start then
                start_folder_idx = new_start + 1
                if distribution_mode == 2 then
                    target_folder_count = scan.total_existing_folders() - start_folder_idx + 1
                end
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx,
                    "Distribution starts at this folder, working through the folders "
                    .. "below it (and creating new ones as needed)")
            end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)
        end

        ImGui.Text(ctx, "Preview:")

        if is_vertical then
            local highest_needed_idx = start_folder_idx + target_folder_count - 1
            local folders_to_create  = highest_needed_idx - 1 - current_folders
            if folders_to_create and folders_to_create > 0 then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAA44FF)
                ImGui.Text(ctx, string.format("⚠ Will create %d new folder%s",
                    folders_to_create, folders_to_create == 1 and "" or "s"))
                ImGui.PopStyleColor(ctx)
            end
        end

        local _, avail_height = ImGui.GetContentRegionAvail(ctx)
        ImGui.BeginChild(ctx, "PreviewScroll", 0, avail_height - 40)
        generate_preview_ui(active_sessions, active_session_names,
            is_vertical and (distribution_mode == 0 and nil or target_folder_count) or nil,
            start_folder_idx, cached_workflow)
        ImGui.EndChild(ctx)

        ImGui.Spacing(ctx)

        local button_width = (ImGui.GetContentRegionAvail(ctx) - 8) / 2

        if active_total_takes == 0 then ImGui.BeginDisabled(ctx) end
        if ImGui.Button(ctx, "Import", button_width, 30) then
            import_confirmed = true
            dialog_open      = false
            if is_vertical then
                SetProjExtState(0, "ReaClassical", "ImportDistributionMode", tostring(distribution_mode))
                SetProjExtState(0, "ReaClassical", "ImportFolderCount",       tostring(target_folder_count))
                SetProjExtState(0, "ReaClassical", "ImportStartFolder",       tostring(start_folder_idx))
            end
        end
        if active_total_takes == 0 then ImGui.EndDisabled(ctx) end

        ImGui.SameLine(ctx)

        if ImGui.Button(ctx, "Cancel", button_width, 30) then
            import_cancelled = true
            dialog_open      = false
        end

        if has_polywav_tab then ImGui.EndTabItem(ctx) end
    end

    if has_polywav_tab then
        if ImGui.BeginTabItem(ctx, "Polywav") then
            draw_polywav_tab()
            ImGui.EndTabItem(ctx)
        end
        ImGui.EndTabBar(ctx)
    end

        ImGui.End(ctx)
    end
end

function generate_preview_ui(sessions, session_names, folder_count, start_folder_idx, workflow)
    local take_column_x = 60

    if workflow == "Horizontal" then
        for _, session_name in ipairs(session_names) do
            local session_data = sessions[session_name]
            local take_nums = {}
            for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
            table.sort(take_nums)

            local display_name = session_name == "default" and "No Session Name" or session_name
            ImGui.Text(ctx, string.format("Session: %s (%d takes)", display_name, #take_nums))

            for _, take_num in ipairs(take_nums) do
                ImGui.Bullet(ctx)
                ImGui.SameLine(ctx)
                ImGui.Text(ctx, string.format("T%03d", take_num))
            end
            ImGui.Spacing(ctx)
        end
        return
    end

    if not folder_count then
        for _, session_name in ipairs(session_names) do
            local session_data = sessions[session_name]
            local take_nums = {}
            for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
            table.sort(take_nums)

            local display_name = session_name == "default" and "No Session Name" or session_name
            ImGui.Text(ctx, string.format("Session: %s (%d takes)", display_name, #take_nums))

            for idx, take_num in ipairs(take_nums) do
                local folder_label = scan.folder_label_for_index(start_folder_idx + idx - 1)
                ImGui.Bullet(ctx)
                ImGui.SameLine(ctx)
                ImGui.Text(ctx, folder_label)
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, take_column_x)
                ImGui.Text(ctx, string.format("T%03d", take_num))
            end
            ImGui.Spacing(ctx)
        end
    else
        for _, session_name in ipairs(session_names) do
            local session_data = sessions[session_name]
            local take_nums = {}
            for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
            table.sort(take_nums)

            local distribution = placement.calculate_round_robin_distribution(take_nums, folder_count)
            local display_name = session_name == "default" and "No Session Name" or session_name
            ImGui.Text(ctx, string.format("Session: %s (%d takes)", display_name, #take_nums))

            for folder_idx = 1, folder_count do
                local takes = distribution[folder_idx] or {}
                if #takes > 0 then
                    local folder_label = scan.folder_label_for_index(start_folder_idx + folder_idx - 1)
                    ImGui.Bullet(ctx)
                    ImGui.SameLine(ctx)
                    ImGui.Text(ctx, folder_label)
                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, take_column_x)
                    for i, take_num in ipairs(takes) do
                        ImGui.Text(ctx, string.format("T%03d", take_num))
                        if i < #takes then ImGui.SameLine(ctx) end
                    end
                    ImGui.SameLine(ctx)
                    ImGui.Text(ctx, string.format(" (%d take%s)", #takes, #takes == 1 and "" or "s"))
                end
            end
            ImGui.Spacing(ctx)
        end
    end
end

function import_vertical_round_robin(sessions, session_names, tracks, errors,
                                      folder_count, start_folder_idx, start_pos)
    local source_folders_needed = (start_folder_idx + folder_count - 1) - 1
    placement.create_folders_if_needed(source_folders_needed)

    tracks = scan.get_tracks("Vertical")
    local folder_tracks = placement.build_folder_track_map(tracks)

    start_pos = start_pos or 0
    local scratch_start = math.max(start_pos, scan.get_project_end_position() + 10)
    local pos = scratch_start
    local all_items = {}
    local touched_tracks, touched_seen = {}, {}

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]
        local take_nums = {}
        for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
        table.sort(take_nums)

        local distribution     = placement.calculate_round_robin_distribution(take_nums, folder_count)
        local folder_positions = {}
        for i = 1, folder_count do folder_positions[i] = pos end
        local max_end_position = pos

        for take_idx, take_num in ipairs(take_nums) do
            local folder_idx        = ((take_idx - 1) % folder_count) + 1
            local take_data         = session_data[take_num]
            local actual_folder_idx = start_folder_idx + folder_idx - 1
            local folder_track_list = folder_tracks[actual_folder_idx]

            if not folder_track_list then
                table.insert(errors, string.format(
                    "Could not find source folder %d for take T%03d", folder_idx, take_num))
            else
                local take_max_len = 0

                if take_idx > folder_count and folder_idx == 1 then
                    local next_round_start = max_end_position + 2
                    for i = 1, folder_count do folder_positions[i] = next_round_start end
                end

                local take_items = {}
                for track_obj, filepath in pairs(take_data) do
                    local target_track = placement.find_track_in_folder_list(folder_track_list, track_obj.base_name)
                    if target_track then
                        SetOnlyTrackSelected(target_track.track)
                        local item = placement.insert_media_get_item(target_track.track, filepath)
                        if item then
                            if not touched_seen[target_track.track] then
                                touched_seen[target_track.track] = true
                                touched_tracks[#touched_tracks + 1] = target_track.track
                            end
                            SetMediaItemInfo_Value(item, "D_POSITION", folder_positions[folder_idx])
                            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                            if len > take_max_len then take_max_len = len end
                            local take = GetActiveTake(item)
                            if take then
                                local item_name = session_name == "default"
                                    and string.format("%03d", take_num)
                                    or  session_name .. "_T" .. string.format("%03d", take_num)
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
                            end
                            table.insert(take_items, item)
                            table.insert(all_items, item)
                        end
                    else
                        table.insert(errors, string.format(
                            "Could not find track '%s' in source folder %d for take T%03d",
                            track_obj.base_name, folder_idx, take_num))
                    end
                end
                if #take_items > 1 then
                    local min_len = math.huge
                    for _, it in ipairs(take_items) do
                        local l = GetMediaItemInfo_Value(it, "D_LENGTH")
                        if l < min_len then min_len = l end
                    end
                    for _, it in ipairs(take_items) do
                        SetMediaItemInfo_Value(it, "D_LENGTH", min_len)
                    end
                end

                local take_end = folder_positions[folder_idx] + take_max_len
                if take_end > max_end_position then max_end_position = take_end end
            end
        end

        pos = max_end_position + 10
    end

    local delta = scratch_start - start_pos
    if delta > 0.0001 then
        local skip_set = {}
        for _, item in ipairs(all_items) do skip_set[item] = true end
        placement.make_room(touched_tracks, start_pos, placement.content_end_of(all_items) - scratch_start, skip_set)
        for _, item in ipairs(all_items) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p - delta))
        end
    end
end

function import_horizontal(sessions, session_names, tracks, errors, start_pos)
    start_pos = start_pos or 0
    local scratch_start = math.max(start_pos, scan.get_project_end_position() + 10)
    local pos = scratch_start
    local all_items = {}
    local touched_tracks, touched_set = {}, {}

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]
        local take_nums = {}
        for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
        table.sort(take_nums)

        local tracks_in_session = {}
        for _, take_num in ipairs(take_nums) do
            for track_obj in pairs(session_data[take_num]) do
                tracks_in_session[track_obj] = true
            end
        end
        for track_obj in pairs(tracks_in_session) do
            if not touched_set[track_obj.track] then
                touched_set[track_obj.track] = true
                touched_tracks[#touched_tracks + 1] = track_obj.track
            end
        end

        for _, take_num in ipairs(take_nums) do
            local take_data = session_data[take_num]
            local max_len   = 0
            local take_items = {}

            for track_obj, filepath in pairs(take_data) do
                SetOnlyTrackSelected(track_obj.track)
                local item = placement.insert_media_get_item(track_obj.track, filepath)
                if item then
                    SetMediaItemInfo_Value(item, "D_POSITION", pos)
                    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                    if len > max_len then max_len = len end
                    local take = GetActiveTake(item)
                    if take then
                        local item_name = session_name == "default"
                            and string.format("%03d", take_num)
                            or  session_name .. "_T" .. string.format("%03d", take_num)
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
                    end
                    table.insert(take_items, item)
                    table.insert(all_items, item)
                end
            end
            if #take_items > 1 then
                local min_len = math.huge
                for _, it in ipairs(take_items) do
                    local l = GetMediaItemInfo_Value(it, "D_LENGTH")
                    if l < min_len then min_len = l end
                end
                for _, it in ipairs(take_items) do
                    SetMediaItemInfo_Value(it, "D_LENGTH", min_len)
                end
            end

            for track_obj in pairs(tracks_in_session) do
                if not take_data[track_obj] then
                    table.insert(errors, string.format(
                        "Missing take T%03d for track '%s' in session '%s'",
                        take_num, track_obj.display_name, session_name))
                end
            end

            pos = pos + max_len + 2
        end

        pos = pos + 10
    end

    local delta = scratch_start - start_pos
    if delta > 0.0001 then
        local skip_set = {}
        for _, item in ipairs(all_items) do skip_set[item] = true end
        placement.make_room(touched_tracks, start_pos, placement.content_end_of(all_items) - scratch_start, skip_set)
        for _, item in ipairs(all_items) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p - delta))
        end
    end
end

function import_vertical(sessions, session_names, tracks, errors, start_folder_idx, start_pos)
    local max_takes = 0
    for _, session_name in ipairs(session_names) do
        local count = 0
        for _ in pairs(sessions[session_name]) do count = count + 1 end
        if count > max_takes then max_takes = count end
    end

    local source_folders_needed = (start_folder_idx + max_takes - 1) - 1
    local current_folders       = scan.count_source_folders()

    if source_folders_needed > current_folders then
        local track_one = GetTrack(0, 0)
        for _ = 1, source_folders_needed - current_folders do
            SetOnlyTrackSelected(track_one)
            Main_OnCommand(40340, 0)
            Main_OnCommand(40062, 0)
            placement.select_children_of_selected_folders()
            Main_OnCommand(40421, 0)
            placement.delete_items()
            placement.unselect_folder_children()
        end
        _G.RC_SUPPRESS_UNDO = true
        dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
        _G.RC_SUPPRESS_UNDO = nil
        Main_OnCommand(40297, 0)
    end

    tracks = scan.get_tracks("Vertical")
    local folder_tracks = placement.build_folder_track_map(tracks)

    start_pos = start_pos or 0
    local scratch_start = math.max(start_pos, scan.get_project_end_position() + 10)
    local pos = scratch_start
    local all_items = {}
    local touched_tracks, touched_seen = {}, {}

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]
        local take_nums = {}
        for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
        table.sort(take_nums)

        local max_len = 0

        for take_idx, take_num in ipairs(take_nums) do
            local take_data         = session_data[take_num]
            local folder_idx        = start_folder_idx + take_idx - 1
            local folder_track_list = folder_tracks[folder_idx]

            if not folder_track_list then
                table.insert(errors, string.format(
                    "Could not find source folder %d for take T%03d", take_idx, take_num))
            else
                local take_items = {}
                for track_obj, filepath in pairs(take_data) do
                    local target_track = placement.find_track_in_folder_list(folder_track_list, track_obj.base_name)
                    if target_track then
                        SetOnlyTrackSelected(target_track.track)
                        local item = placement.insert_media_get_item(target_track.track, filepath)
                        if item then
                            if not touched_seen[target_track.track] then
                                touched_seen[target_track.track] = true
                                touched_tracks[#touched_tracks + 1] = target_track.track
                            end
                            SetMediaItemInfo_Value(item, "D_POSITION", pos)
                            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                            if len > max_len then max_len = len end
                            local take = GetActiveTake(item)
                            if take then
                                local item_name = session_name == "default"
                                    and string.format("%03d", take_num)
                                    or  session_name .. "_T" .. string.format("%03d", take_num)
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
                            end
                            table.insert(take_items, item)
                            table.insert(all_items, item)
                        end
                    else
                        table.insert(errors, string.format(
                            "Could not find track '%s' in source folder %d for take T%03d",
                            track_obj.base_name, take_idx, take_num))
                    end
                end
                if #take_items > 1 then
                    local min_len = math.huge
                    for _, it in ipairs(take_items) do
                        local l = GetMediaItemInfo_Value(it, "D_LENGTH")
                        if l < min_len then min_len = l end
                    end
                    for _, it in ipairs(take_items) do
                        SetMediaItemInfo_Value(it, "D_LENGTH", min_len)
                    end
                end
            end
        end

        pos = pos + max_len + 10
    end

    local delta = scratch_start - start_pos
    if delta > 0.0001 then
        local skip_set = {}
        for _, item in ipairs(all_items) do skip_set[item] = true end
        placement.make_room(touched_tracks, start_pos, placement.content_end_of(all_items) - scratch_start, skip_set)
        for _, item in ipairs(all_items) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p - delta))
        end
    end
end

main()
