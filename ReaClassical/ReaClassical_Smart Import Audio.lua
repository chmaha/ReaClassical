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
local main, get_project_media_path, scan_media_folder_recursive
local parse_canonical_filename, get_tracks, find_track_by_name
local get_project_end_position, get_used_source_files, delete_items
local select_children_of_selected_folders, unselect_folder_children
local calculate_round_robin_distribution, generate_preview_ui
local show_import_dialog, import_vertical_round_robin
local create_folders_if_needed, ensure_tracks_exist, rename_tracks
local show_track_order_dialog, draw_track_order_dialog
local finish_import

---------------------------------------------------------------------
-- ImGui and Dialog State
---------------------------------------------------------------------

set_action_options(2)

local imgui_exists = APIExists("ImGui_GetVersion")
local ImGui = nil
local ctx = nil

-- Import dialog state
local dialog_open = false
local distribution_mode = 0
local target_folder_count = 1
local include_destination = false
local import_confirmed = false
local import_cancelled = false

-- Track order dialog state
local track_order_open      = false
local track_order_confirmed = false
local track_order_cancelled = false
local track_order_list      = {}   -- names that WILL be assigned (capped at blank slot count)
local track_order_unused    = {}   -- names that will NOT be assigned this run
local track_order_slots     = 0    -- number of blank mixer tracks available

-- Cached data for import dialog
local cached_sessions = nil
local cached_session_names = nil
local cached_total_takes = 0
local cached_max_takes_per_session = 0
local cached_workflow = ""
local cached_has_existing_items = false
local cached_start_pos = 0

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")

---------------------------------------------------------------------

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
        -- Non-empty project with no ReaClassical state
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
        -- If some mixer tracks are named but others are still blank, the project
        -- is in an ambiguous half-set-up state. Block and ask the user to finish
        -- naming via Mission Control before importing.
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

    local project_end = get_project_end_position()
    local start_pos = 0
    local has_existing_items = CountMediaItems(0) > 0
    if has_existing_items then
        start_pos = project_end + 10
    end
    if _G.RC_TERMINAL_ARGS and _G.RC_TERMINAL_ARGS.at_cursor then
        start_pos = GetCursorPosition()
    end

    local used_files = get_used_source_files()
    local all_files  = scan_media_folder_recursive(get_project_media_path())

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

    -- ── Pass 1: parse filenames only, collecting track names ─────────
    -- We cannot build sessions yet because the tracks they reference may
    -- not exist in the project until ensure_tracks_exist() runs.  So we
    -- first gather every unique track name from the filenames, let the
    -- user reorder them, apply them to blank mixer tracks, and only then
    -- do pass 2 to actually build the sessions table.

    local parsed_files = {}   -- list of info tables from parse_canonical_filename
    local name_seen   = {}   -- dedup for needed_names
    local needed_names = {}  -- ordered list of {base_name, display_name}

    for _, filepath in ipairs(files) do
        local info = parse_canonical_filename(filepath)
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

    -- If any files failed to parse, report them and stop — a filename mismatch
    -- is likely deliberate or a recording error and should be resolved before importing.
    if #errors > 0 then
        MB("Some files could not be matched to the expected naming pattern.\n"
            .. "Please fix or remove these files and try again:\n\n"
            .. table.concat(errors, "\n"),
            "Import Aborted", 0)
        return
    end

    -- Terminal hook: restrict to a specific take number/range and/or session
    -- name (e.g. "import=3,morning" or "import=4-7"), so a quick single-take
    -- import doesn't sweep in every other unused file.
    if _G.RC_TERMINAL_ARGS and _G.RC_TERMINAL_ARGS.filter then
        local f = _G.RC_TERMINAL_ARGS.filter
        local filtered_files = {}
        for _, pf in ipairs(parsed_files) do
            local info = pf.info
            if info.take_num >= f.take_min and info.take_num <= f.take_max
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

    -- Helper: build sessions table from parsed_files against current tracks.
    -- Called after ensure_tracks_exist() so all referenced tracks exist.
    local function build_sessions()
        local tracks = get_tracks(workflow)
        local sessions = {}

        -- Build a set of track names the user deliberately left unused,
        -- so we can skip their files silently rather than reporting errors.
        local unused_set = {}
        for _, entry in ipairs(track_order_unused) do
            unused_set[entry.base_name] = true
        end

        for _, pf in ipairs(parsed_files) do
            local info      = pf.info
            local track_obj = find_track_by_name(tracks, info.track_name)

            if not track_obj then
                -- Only report as an error if the user didn't intentionally
                -- leave this track name out of the naming dialog
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

        return sessions, session_names, get_tracks(workflow)
    end

    if imgui_exists and not _G.RC_TERMINAL_ARGS then
        -- Initialise ImGui once; all dialogs share the same context.
        if not ImGui then
            package.path = ImGui_GetBuiltinPath() .. '/?.lua'
            ImGui = require 'imgui' '0.10'
            ctx = ImGui.CreateContext('ReaClassical Smart Import')
        end

        -- Inner function: step 2 — build sessions then show the
        -- distribution dialog for Vertical, or import for Horizontal.
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

            if workflow == "Vertical" then
                show_import_dialog(sessions, session_names, workflow,
                    has_existing_items, start_pos)

                local function wait_for_import_dialog()
                    if dialog_open then
                        defer(wait_for_import_dialog)
                        return
                    end

                    if not import_confirmed then
                        Undo_EndBlock("Import Audio (Cancelled)", -1)
                        PreventUIRefresh(-1)
                        UpdateArrange()
                        return
                    end

                    if distribution_mode == 1 or distribution_mode == 2 then
                        import_vertical_round_robin(sessions, session_names, tracks, errors,
                            target_folder_count, include_destination, start_pos)
                    else
                        import_vertical(sessions, session_names, tracks, errors,
                            include_destination, start_pos)
                    end

                    finish_import(errors)
                end

                wait_for_import_dialog()
            else
                -- Horizontal workflow has no distribution dialog
                import_horizontal(sessions, session_names, tracks, errors, start_pos)
                finish_import(errors)
            end
        end

        -- Step 1 — show the drag-to-reorder dialog only when there are
        -- new track names to assign AND blank mixer slots to put them in;
        -- otherwise skip straight to step 2.
        local function do_track_order_then_import()
            if #needed_names > 0 and count_blank_mixer_tracks() > 0 then
                show_track_order_dialog(needed_names)

                local function after_track_order()
                    if track_order_open then
                        defer(after_track_order)
                        return
                    end

                    if track_order_cancelled or #track_order_list == 0 then
                        Undo_EndBlock("Import Audio (Cancelled)", -1)
                        PreventUIRefresh(-1)
                        UpdateArrange()
                        return
                    end

                    -- Apply names in the user-confirmed order then continue
                    ensure_tracks_exist(track_order_list, workflow)
                    do_import_dialog()
                end

                after_track_order()
            else
                -- No new names to assign, go straight to the import dialog
                do_import_dialog()
            end
        end

        -- Step 1 — show the drag-to-reorder dialog only when there are
        -- new track names to assign AND blank mixer slots to put them in;
        -- otherwise skip straight to step 2.
        do_track_order_then_import()

        return
    end

    -- ── No ImGui fallback: name tracks and import directly ───────────
    if #needed_names > 0 then
        ensure_tracks_exist(needed_names, workflow)
    end

    local sessions, session_names, tracks = build_sessions()

    if #session_names == 0 then
        MB("Audio files were found but none matched the expected naming pattern.\n"
            .. "Files should be named like: trackname_T001.wav\n\n"
            .. "The following issues were found:\n\n" .. table.concat(errors, "\n"),
            "Import Aborted", 0)
        return
    end

    if workflow == "Vertical" then
        if _G.RC_TERMINAL_ARGS and _G.RC_TERMINAL_ARGS.include_destination then
            include_destination = true
        end

        local robin_folder_count = _G.RC_TERMINAL_ARGS and _G.RC_TERMINAL_ARGS.robin_folder_count
        if robin_folder_count then
            if robin_folder_count == "current" then
                robin_folder_count = include_destination
                    and (count_source_folders() + 1) or count_source_folders()
            end
            robin_folder_count = math.max(1, robin_folder_count)
            import_vertical_round_robin(sessions, session_names, tracks, errors,
                robin_folder_count, include_destination, start_pos)
        else
            import_vertical(sessions, session_names, tracks, errors, include_destination, start_pos)
        end
    else
        import_horizontal(sessions, session_names, tracks, errors, start_pos)
    end

    finish_import(errors)
end

---------------------------------------------------------------------

function finish_import(errors)
    Undo_EndBlock("Import Audio", -1)

    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)

    PreventUIRefresh(-1)

    local zoom_horizontally = NamedCommandLookup("_RSe4ae3f4797f2fb7f209512fc22ad6ef9854ca770")
    Main_OnCommand(zoom_horizontally, 0)

    if #errors > 0 then
        if _G.RC_TERMINAL_ARGS then
            say("Import issues: " .. table.concat(errors, "; "))
        else
            MB("The following issues were found:\n\n" .. table.concat(errors, "\n"), "Import Errors", 0)
        end
    else
        if _G.RC_TERMINAL_ARGS then
            say("Files imported successfully")
        else
            MB("Files imported successfully!", "ReaClassical Smart Import", 0)
        end
    end

    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------
---------------------------------------------------------------------
-- Show the drag-to-reorder dialog.
-- needed_names: all new names found in filenames.
-- On confirmation, track_order_list holds the names to assign (in order)
-- and track_order_unused holds the names the user chose to skip.
---------------------------------------------------------------------

function count_blank_mixer_tracks()
    local count = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            local _, name = GetTrackName(track)
            local stripped = name:gsub("^M:?", ""):gsub("^%s*(.-)%s*$", "%1")
            if stripped == "" then count = count + 1 end
        end
    end
    return count
end

---------------------------------------------------------------------

function show_track_order_dialog(needed_names)
    track_order_slots = count_blank_mixer_tracks()

    -- Fill the "to be named" list up to the slot cap; overflow goes to unused
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

---------------------------------------------------------------------

function draw_track_order_dialog()
    local FLT_MAX  = select(2, ImGui.NumericLimits_Float())
    local two_col  = #track_order_unused > 0   -- only show second column when needed
    local min_w    = two_col and 500 or 260
    ImGui.SetNextWindowSizeConstraints(ctx, min_w, 200, FLT_MAX, FLT_MAX)

    local visible, open = ImGui.Begin(ctx, "Track Name Order", true,
        ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize)
    track_order_open = open

    if not visible then return end

    local slots_used = #track_order_list
    local col_w      = 220

    -- ── Header ────────────────────────────────────────────────────────
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

    -- Pending action — applied after all loops finish
    local pending = nil

    -- ── Left column: "To be named" ────────────────────────────────────
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

    -- Tail drop zone for the active list
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

    -- ── Right column: "Not used" — only when overflow exists ─────────
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

        -- Tail drop zone for the unused list
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

    -- ── Apply pending action ──────────────────────────────────────────
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

    -- ── Buttons ───────────────────────────────────────────────────────
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

    ImGui.End(ctx)
end

---------------------------------------------------------------------
-- Walk the confirmed ordered list and assign each name to the next
-- unnamed mixer track, using the same rename_tracks() logic that
-- Mission Control uses when the user types into the ##name field.
---------------------------------------------------------------------

function ensure_tracks_exist(ordered_names, workflow)
    local existing_tracks = get_tracks(workflow)
    local existing = {}
    for _, t in ipairs(existing_tracks) do
        if t.base_name ~= "" then
            existing[t.base_name] = true
        end
    end

    for _, entry in ipairs(ordered_names) do
        if not existing[entry.base_name] then
            for i = 0, CountTracks(0) - 1 do
                local track = GetTrack(0, i)
                local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
                if mixer_state == "y" then
                    local _, current_name = GetTrackName(track)
                    -- A mixer track is unnamed when stripping "M:" leaves an empty string
                    local stripped = current_name:gsub("^M:?", ""):gsub("^%s*(.-)%s*$", "%1")
                    if stripped == "" then
                        rename_tracks({ mixer_track = track }, entry.display_name, false, workflow)
                        existing[entry.base_name] = true
                        break
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- Mirrors Mission Control's rename_tracks() exactly:
-- sets "M:<name>" on the mixer track and propagates "D:<name>" /
-- "S1:<name>" / "S2:<name>" … to the corresponding track slot in
-- every folder.
---------------------------------------------------------------------

function rename_tracks(track_info, new_name, disconnect_rcm, workflow)
    if not workflow then
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
    end

    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect",
        disconnect_rcm and "y" or "", true)

    local clean_name = new_name:gsub("%-$", "")
    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_NAME", "M:" .. clean_name, true)

    -- Determine this mixer track's 1-based position among all mixer tracks
    local mixer_position = nil
    local mixer_index    = 0
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        local _, ms = GetSetMediaTrackInfo_String(tr, "P_EXT:mixer", "", false)
        if ms == "y" then
            mixer_index = mixer_index + 1
            if tr == track_info.mixer_track then
                mixer_position = mixer_index
                break
            end
        end
    end

    if not mixer_position then return end

    -- Propagate the name to the matching slot in every folder
    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folder_number = folder_number + 1

            local target_track = GetTrack(0, i + (mixer_position - 1))
            if target_track then
                GetSetMediaTrackInfo_String(target_track, "P_EXT:rcm_disconnect",
                    disconnect_rcm and "y" or "", true)

                local prefix = ""
                if workflow == "Vertical" then
                    prefix = (folder_number == 1)
                        and "D:"
                        or  ("S" .. (folder_number - 1) .. ":")
                end

                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. clean_name, true)
            end
        end
    end
end

---------------------------------------------------------------------

function show_import_dialog(sessions, session_names, workflow, has_existing_items, start_pos)
    if not ImGui then
        package.path = ImGui_GetBuiltinPath() .. '/?.lua'
        ImGui = require 'imgui' '0.10'
        ctx = ImGui.CreateContext('ReaClassical Smart Import')
    end

    cached_sessions           = sessions
    cached_session_names      = session_names
    cached_workflow           = workflow
    cached_has_existing_items = has_existing_items or false
    cached_start_pos          = start_pos or 0

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

    local current_folders = count_source_folders()

    local _, mode_str         = GetProjExtState(0, "ReaClassical", "ImportDistributionMode")
    local _, count_str        = GetProjExtState(0, "ReaClassical", "ImportFolderCount")
    local _, include_dest_str = GetProjExtState(0, "ReaClassical", "ImportIncludeDestination")

    distribution_mode   = (mode_str ~= "")         and (tonumber(mode_str) or 0)                             or 0
    target_folder_count = (count_str ~= "")         and (tonumber(count_str) or math.max(1, current_folders)) or math.max(1, current_folders)
    include_destination = (include_dest_str ~= "")  and (include_dest_str == "true")                         or false

    if distribution_mode == 0 then
        target_folder_count = max_takes_per_session
    elseif distribution_mode == 2 then
        target_folder_count = include_destination and (current_folders + 1) or current_folders
    end
    target_folder_count = math.max(1, math.min(cached_max_takes_per_session, target_folder_count))

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

---------------------------------------------------------------------

function draw_import_dialog()
    local current_folders = count_source_folders()
    local FLT_MAX = select(2, ImGui.NumericLimits_Float())
    ImGui.SetNextWindowSizeConstraints(ctx, 500, 400, FLT_MAX, FLT_MAX)

    local visible, open = ImGui.Begin(ctx, "ReaClassical Smart Import", true,
        ImGui.WindowFlags_NoCollapse)
    dialog_open = open

    if visible then
        ImGui.Text(ctx, "Workflow: " .. cached_workflow)
        if cached_has_existing_items then
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x88CCFFFF)
            ImGui.Text(ctx, string.format("Appending to existing project (starting at %.1fs)",
                cached_start_pos))
            ImGui.PopStyleColor(ctx)
        end
        ImGui.Text(ctx, string.format("New files to import: %d takes (%d session%s)",
            cached_total_takes, #cached_session_names,
            #cached_session_names == 1 and "" or "s"))
        ImGui.Text(ctx, "Current folders: " .. current_folders)

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        ImGui.Text(ctx, "Distribution Mode:")

        local changed_mode, new_mode = ImGui.RadioButtonEx(ctx,
            "One folder per take", distribution_mode, 0)
        if changed_mode then
            distribution_mode   = new_mode
            target_folder_count = cached_max_takes_per_session
        end

        changed_mode, new_mode = ImGui.RadioButtonEx(ctx,
            "Use current folder count", distribution_mode, 2)
        if changed_mode then
            distribution_mode   = new_mode
            target_folder_count = include_destination
                and (current_folders + 1) or current_folders
        end

        changed_mode, new_mode = ImGui.RadioButtonEx(ctx,
            "Round-robin across custom number of folders", distribution_mode, 1)
        if changed_mode then distribution_mode = new_mode end

        ImGui.Spacing(ctx)

        if distribution_mode ~= 1 then ImGui.BeginDisabled(ctx) end

        ImGui.Text(ctx, "Number of folders:")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_count, new_count = ImGui.SliderInt(ctx, "##folder_count",
            target_folder_count, 1, cached_max_takes_per_session)
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
                    target_folder_count = math.max(1, math.min(cached_max_takes_per_session, val))
                end
                ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
        end

        if distribution_mode ~= 1 then ImGui.EndDisabled(ctx) end

        ImGui.Spacing(ctx)

        local changed_dest, new_dest = ImGui.Checkbox(ctx,
            "Include destination folder (D:) in distribution", include_destination)
        if changed_dest then
            include_destination = new_dest
            if distribution_mode == 2 then
                target_folder_count = include_destination
                    and (current_folders + 1) or current_folders
            end
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx,
                "When enabled, D: folder is used as the first folder in the distribution sequence")
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        ImGui.Text(ctx, "Preview:")

        -- Folder creation warning
        local folders_to_create
        if distribution_mode == 0 then
            local needed = cached_max_takes_per_session
            folders_to_create = include_destination
                and (needed - 1 - current_folders) or (needed - current_folders)
        else
            folders_to_create = include_destination
                and (target_folder_count - 1 - current_folders)
                or  (target_folder_count - current_folders)
        end
        if folders_to_create and folders_to_create > 0 then
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAA44FF)
            ImGui.Text(ctx, string.format("⚠ Will create %d new folder%s",
                folders_to_create, folders_to_create == 1 and "" or "s"))
            ImGui.PopStyleColor(ctx)
        end

        local _, avail_height = ImGui.GetContentRegionAvail(ctx)
        ImGui.BeginChild(ctx, "PreviewScroll", 0, avail_height - 40)
        generate_preview_ui(cached_sessions, cached_session_names,
            distribution_mode == 0 and nil or target_folder_count,
            include_destination)
        ImGui.EndChild(ctx)

        ImGui.Spacing(ctx)

        local button_width = (ImGui.GetContentRegionAvail(ctx) - 8) / 2

        if ImGui.Button(ctx, "Import", button_width, 30) then
            import_confirmed = true
            dialog_open      = false
            SetProjExtState(0, "ReaClassical", "ImportDistributionMode", tostring(distribution_mode))
            SetProjExtState(0, "ReaClassical", "ImportFolderCount",       tostring(target_folder_count))
            SetProjExtState(0, "ReaClassical", "ImportIncludeDestination", tostring(include_destination))
        end

        ImGui.SameLine(ctx)

        if ImGui.Button(ctx, "Cancel", button_width, 30) then
            import_cancelled = true
            dialog_open      = false
        end

        ImGui.End(ctx)
    end
end

---------------------------------------------------------------------

function generate_preview_ui(sessions, session_names, folder_count, include_destination)
    local take_column_x = 60

    if not folder_count then
        for _, session_name in ipairs(session_names) do
            local session_data = sessions[session_name]
            local take_nums = {}
            for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
            table.sort(take_nums)

            local display_name = session_name == "default" and "No Session Name" or session_name
            ImGui.Text(ctx, string.format("Session: %s (%d takes)", display_name, #take_nums))

            for idx, take_num in ipairs(take_nums) do
                local folder_label
                if include_destination and idx == 1 then
                    folder_label = "D:"
                elseif include_destination then
                    folder_label = "S" .. (idx - 1) .. ":"
                else
                    folder_label = "S" .. idx .. ":"
                end
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

            local distribution = calculate_round_robin_distribution(take_nums, folder_count)
            local display_name = session_name == "default" and "No Session Name" or session_name
            ImGui.Text(ctx, string.format("Session: %s (%d takes)", display_name, #take_nums))

            for folder_idx = 1, folder_count do
                local takes = distribution[folder_idx] or {}
                if #takes > 0 then
                    local folder_label
                    if include_destination and folder_idx == 1 then
                        folder_label = "D:"
                    elseif include_destination then
                        folder_label = "S" .. (folder_idx - 1) .. ":"
                    else
                        folder_label = "S" .. folder_idx .. ":"
                    end
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

---------------------------------------------------------------------

function calculate_round_robin_distribution(take_nums, folder_count)
    local distribution = {}
    for i = 1, folder_count do distribution[i] = {} end
    for idx, take_num in ipairs(take_nums) do
        local folder_idx = ((idx - 1) % folder_count) + 1
        table.insert(distribution[folder_idx], take_num)
    end
    return distribution
end

---------------------------------------------------------------------

function import_vertical_round_robin(sessions, session_names, tracks, errors,
                                      folder_count, use_destination, start_pos)
    local source_folders_needed = use_destination and (folder_count - 1) or folder_count
    create_folders_if_needed(source_folders_needed)

    tracks = get_tracks("Vertical")
    local folder_tracks = build_folder_track_map(tracks)
    local pos = start_pos or 0

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]
        local take_nums = {}
        for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
        table.sort(take_nums)

        local distribution     = calculate_round_robin_distribution(take_nums, folder_count)
        local folder_positions = {}
        for i = 1, folder_count do folder_positions[i] = pos end
        local max_end_position = pos

        for take_idx, take_num in ipairs(take_nums) do
            local folder_idx        = ((take_idx - 1) % folder_count) + 1
            local take_data         = session_data[take_num]
            local actual_folder_idx = use_destination and folder_idx or (folder_idx + 1)
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

                for track_obj, filepath in pairs(take_data) do
                    local target_track = find_track_in_folder_list(folder_track_list, track_obj.base_name)
                    if target_track then
                        SetOnlyTrackSelected(target_track.track)
                        InsertMedia(filepath, 0)
                        local item = GetTrackMediaItem(target_track.track,
                            CountTrackMediaItems(target_track.track) - 1)
                        if item then
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
                        end
                    else
                        table.insert(errors, string.format(
                            "Could not find track '%s' in source folder %d for take T%03d",
                            track_obj.base_name, folder_idx, take_num))
                    end
                end

                local take_end = folder_positions[folder_idx] + take_max_len
                if take_end > max_end_position then max_end_position = take_end end
            end
        end

        pos = max_end_position + 10
    end
end

---------------------------------------------------------------------

function create_folders_if_needed(target_count)
    local current_folders = count_source_folders()
    if target_count > current_folders then
        local track_one = GetTrack(0, 0)
        for _ = 1, target_count - current_folders do
            SetOnlyTrackSelected(track_one)
            Main_OnCommand(40340, 0)
            Main_OnCommand(40062, 0)
            select_children_of_selected_folders()
            Main_OnCommand(40421, 0)
            delete_items()
            unselect_folder_children()
        end
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        Main_OnCommand(40297, 0)
    end
end

---------------------------------------------------------------------

function import_horizontal(sessions, session_names, tracks, errors, start_pos)
    local pos = start_pos or 0

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

        for _, take_num in ipairs(take_nums) do
            local take_data = session_data[take_num]
            local max_len   = 0

            for track_obj, filepath in pairs(take_data) do
                SetOnlyTrackSelected(track_obj.track)
                InsertMedia(filepath, 0)
                local item = GetTrackMediaItem(track_obj.track,
                    CountTrackMediaItems(track_obj.track) - 1)
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
end

---------------------------------------------------------------------

function import_vertical(sessions, session_names, tracks, errors, use_destination, start_pos)
    local max_takes = 0
    for _, session_name in ipairs(session_names) do
        local count = 0
        for _ in pairs(sessions[session_name]) do count = count + 1 end
        if count > max_takes then max_takes = count end
    end

    local source_folders_needed = use_destination and (max_takes - 1) or max_takes
    local current_folders       = count_source_folders()

    if source_folders_needed > current_folders then
        local track_one = GetTrack(0, 0)
        for _ = 1, source_folders_needed - current_folders do
            SetOnlyTrackSelected(track_one)
            Main_OnCommand(40340, 0)
            Main_OnCommand(40062, 0)
            select_children_of_selected_folders()
            Main_OnCommand(40421, 0)
            delete_items()
            unselect_folder_children()
        end
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        Main_OnCommand(40297, 0)
    end

    tracks = get_tracks("Vertical")
    local folder_tracks = build_folder_track_map(tracks)
    local pos = start_pos or 0

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]
        local take_nums = {}
        for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
        table.sort(take_nums)

        local max_len = 0

        for take_idx, take_num in ipairs(take_nums) do
            local take_data         = session_data[take_num]
            local folder_idx        = use_destination and take_idx or (take_idx + 1)
            local folder_track_list = folder_tracks[folder_idx]

            if not folder_track_list then
                table.insert(errors, string.format(
                    "Could not find source folder %d for take T%03d", take_idx, take_num))
            else
                for track_obj, filepath in pairs(take_data) do
                    local target_track = find_track_in_folder_list(folder_track_list, track_obj.base_name)
                    if target_track then
                        SetOnlyTrackSelected(target_track.track)
                        InsertMedia(filepath, 0)
                        local item = GetTrackMediaItem(target_track.track,
                            CountTrackMediaItems(target_track.track) - 1)
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
                        end
                    else
                        table.insert(errors, string.format(
                            "Could not find track '%s' in source folder %d for take T%03d",
                            track_obj.base_name, take_idx, take_num))
                    end
                end
            end
        end

        pos = pos + max_len + 10
    end
end

---------------------------------------------------------------------

function count_source_folders()
    local count = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            local _, name = GetTrackName(track)
            if name:match("^S%d+:") then count = count + 1 end
        end
    end
    return count
end

---------------------------------------------------------------------

function build_folder_track_map(tracks)
    local folder_tracks  = {}
    local current_folder = 0
    local in_folder      = false

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if depth == 1 then
            current_folder = current_folder + 1
            folder_tracks[current_folder] = {}
            in_folder = true
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
        elseif depth == -1 then
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
            in_folder = false
        elseif in_folder then
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
        end
    end

    return folder_tracks
end

---------------------------------------------------------------------

function find_track_in_folder_list(folder_track_list, base_name)
    for _, track_obj in ipairs(folder_track_list) do
        if track_obj.base_name == base_name then return track_obj end
    end
    return nil
end

---------------------------------------------------------------------

function parse_canonical_filename(filepath)
    local filename = filepath:match("([^/\\]+)$")
    if not filename then return nil end

    local name_no_ext = filename:match("(.+)%.[^.]+$")
    if not name_no_ext then return nil end

    -- Accept _T### or plain _### at the end
    local take_str = name_no_ext:match("_T(%d+)$") or name_no_ext:match("_(%d+)$")
    if not take_str then return nil end

    local name_without_take = name_no_ext:gsub("_T%d+$", ""):gsub("_%d+$", "")

    local parts = {}
    for part in name_without_take:gmatch("[^_]+") do
        table.insert(parts, part)
    end

    if #parts == 0 then return nil end

    local track_name, session_name

    if #parts == 1 then
        track_name   = parts[1]
        session_name = "default"
    elseif #parts == 2 then
        if parts[1]:match("^D$") or parts[1]:match("^S%d+$") then
            track_name   = parts[2]
            session_name = "default"
        else
            session_name = parts[1]
            track_name   = parts[2]
        end
    else
        local potential_prefix = parts[#parts - 1]
        if potential_prefix:match("^D$") or potential_prefix:match("^S%d+$") then
            track_name = parts[#parts]
            table.remove(parts, #parts)
            table.remove(parts, #parts)
            session_name = table.concat(parts, "_")
        else
            track_name = parts[#parts]
            table.remove(parts, #parts)
            session_name = table.concat(parts, "_")
        end
    end

    return {
        filename           = filename,
        session_name       = session_name,
        track_name         = track_name:lower(),  -- lowercased for matching
        track_name_display = track_name,           -- original case for naming
        take_num           = tonumber(take_str),
    }
end

---------------------------------------------------------------------

function get_tracks(workflow)
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        local _, name = GetTrackName(tr)
        name = name:gsub("^%s*(.-)%s*$", "%1")

        local base_name = name
        if workflow == "Vertical" then
            local stripped = name:match("^[DS]%d*:%s*(.+)$")
            if stripped then base_name = stripped end
        end

        table.insert(tracks, {
            track            = tr,
            display_name     = name,
            base_name        = base_name:lower(),
            is_folder_parent = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1,
        })
    end
    return tracks
end

---------------------------------------------------------------------

function find_track_by_name(tracks, track_name)
    track_name = track_name:lower()
    for _, track_obj in ipairs(tracks) do
        if track_obj.base_name == track_name then return track_obj end
    end
    return nil
end

---------------------------------------------------------------------

function get_project_media_path()
    return GetProjectPathEx(0)
end

---------------------------------------------------------------------

function scan_media_folder_recursive(path, files)
    if not path then return {} end
    files = files or {}
    local i, j = 0, 0

    while true do
        local file = EnumerateFiles(path, i)
        if not file then break end
        if file:lower():match("%.wav$")
        or file:lower():match("%.flac$")
        or file:lower():match("%.aif") then
            table.insert(files, path .. "/" .. file)
        end
        i = i + 1
    end

    while true do
        local sub = EnumerateSubdirectories(path, j)
        if not sub then break end
        scan_media_folder_recursive(path .. "/" .. sub, files)
        j = j + 1
    end

    return files
end

---------------------------------------------------------------------

function get_project_end_position()
    local max_end = 0
    for i = 0, CountMediaItems(0) - 1 do
        local item     = GetMediaItem(0, i)
        local item_end = GetMediaItemInfo_Value(item, "D_POSITION")
                       + GetMediaItemInfo_Value(item, "D_LENGTH")
        if item_end > max_end then max_end = item_end end
    end
    return max_end
end

---------------------------------------------------------------------

function get_used_source_files()
    local used = {}
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local take = GetActiveTake(item)
        if take then
            local source = GetMediaItemTake_Source(take)
            if source then
                local filepath = GetMediaSourceFileName(source)
                if filepath and filepath ~= "" then
                    used[filepath:gsub("\\", "/")] = true
                end
            end
        end
    end
    return used
end

---------------------------------------------------------------------

function select_children_of_selected_folders()
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) and GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
            local j = i + 1
            while j < track_count do
                local ch_tr = GetTrack(0, j)
                SetTrackSelected(ch_tr, true)
                if GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH") == -1 then break end
                j = j + 1
            end
        end
    end
end

---------------------------------------------------------------------

function unselect_folder_children()
    local num_tracks    = CountTracks(0)
    local depth         = 0
    local unselect_mode = false

    for i = 0, num_tracks - 1 do
        local tr            = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if IsTrackSelected(tr) and folder_change == 1 then
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        depth = depth + folder_change
        if depth <= 0 then
            unselect_mode = false
            depth         = 0
        end
    end
end

---------------------------------------------------------------------

function delete_items()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            while CountTrackMediaItems(track) > 0 do
                DeleteTrackMediaItem(track, GetTrackMediaItem(track, 0))
            end
        end
    end
end

---------------------------------------------------------------------

main()