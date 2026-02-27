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
local calculate_round_robin_distribution, generate_preview_text
local show_import_dialog, import_vertical_round_robin
local create_folders_if_needed

---------------------------------------------------------------------
-- ImGui and Dialog State
---------------------------------------------------------------------

set_action_options(2)

local imgui_exists = APIExists("ImGui_GetVersion")
local ImGui = nil
local ctx = nil

-- Dialog state
local dialog_open = false
local distribution_mode = 0       -- 0 = one per take, 1 = round-robin custom, 2 = round-robin current
local target_folder_count = 1
local include_destination = false -- NEW: whether to include D: folder in round-robin
local import_confirmed = false
local import_cancelled = false

-- Cached data
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
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    -- Determine start position: if items exist, start after the last item with a gap
    local project_end = get_project_end_position()
    local start_pos = 0
    local has_existing_items = CountMediaItems(0) > 0
    if has_existing_items then
        start_pos = project_end + 10 -- 10 second gap after existing content
    end

    -- Collect source files already used in the project
    local used_files = get_used_source_files()

    local all_files = scan_media_folder_recursive(get_project_media_path())

    -- Filter out files already in use
    local files = {}
    for _, filepath in ipairs(all_files) do
        local normalized = filepath:gsub("\\", "/")
        if not used_files[normalized] then
            table.insert(files, filepath)
        end
    end

    -- Show error if no new audio files found
    if #all_files == 0 then
        MB("No audio files were found in the project recording path. Please add audio files and try again.",
            "Import Aborted", 0)
        return
    end

    if #files == 0 then
        -- all_files is non-empty but files is empty, meaning every file was already in use
        MB("No unused audio files were found in the project recording path. All files are already in the project.",
            "Import Aborted", 0)
        return
    end

    local tracks = get_tracks(workflow)
    local errors = {}
    local sessions = {} -- sessions[session_name][take_num][track_obj] = filepath

    -- Parse all files
    for _, filepath in ipairs(files) do
        local info = parse_canonical_filename(filepath)

        if not info then
            table.insert(errors, filepath:match("([^/\\]+)$") .. " (invalid filename format)")
        else
            local track_obj = find_track_by_name(tracks, info.track_name)

            if not track_obj then
                table.insert(errors, info.filename .. " (no track match for '" .. info.track_name .. "')")
            else
                -- Initialize session structure
                if not sessions[info.session_name] then
                    sessions[info.session_name] = {}
                end
                if not sessions[info.session_name][info.take_num] then
                    sessions[info.session_name][info.take_num] = {}
                end

                -- Store file info
                sessions[info.session_name][info.take_num][track_obj] = filepath
            end
        end
    end

    -- Sort sessions alphabetically with "default" first
    local session_names = {}
    for session_name, _ in pairs(sessions) do
        table.insert(session_names, session_name)
    end
    table.sort(session_names, function(a, b)
        -- "default" always comes first
        if a == "default" then return true end
        if b == "default" then return false end
        -- Otherwise sort alphabetically
        return a < b
    end)

    -- Check if any files were successfully parsed into sessions
    if #session_names == 0 then
        MB("Audio files were found but none matched the expected naming pattern.\n"
            .. "Files should be named like: trackname_T001.wav\n\n"
            .. "The following issues were found:\n\n" .. table.concat(errors, "\n"),
            "Import Aborted", 0)
        return
    end

    -- Import based on workflow
    if workflow == "Vertical" then
        -- Show dialog if ImGui is available
        if imgui_exists then
            -- Initialize dialog and start showing it
            show_import_dialog(sessions, session_names, workflow, has_existing_items, start_pos)

            -- Wait for dialog to close via defer loop
            local function wait_for_dialog()
                if dialog_open then
                    defer(wait_for_dialog)
                    return
                end

                -- Dialog closed, now perform import
                if not import_confirmed then
                    Undo_EndBlock("Import Audio (Cancelled)", -1)
                    PreventUIRefresh(-1)
                    UpdateArrange()
                    return
                end

                -- Perform the actual import
                if distribution_mode == 1 or distribution_mode == 2 then
                    -- Round-robin distribution (mode 1 = custom, mode 2 = current folder count)
                    import_vertical_round_robin(sessions, session_names, tracks, errors, target_folder_count,
                        include_destination, start_pos)
                else
                    -- Original behavior (one folder per take)
                    import_vertical(sessions, session_names, tracks, errors, include_destination, start_pos)
                end

                Undo_EndBlock("Import Audio", -1)

                -- Prepare Takes
                local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
                Main_OnCommand(prepare_takes, 0)

                PreventUIRefresh(-1)

                -- Zoom to all items horizontally
                local zoom_horizontally = NamedCommandLookup("_RSe4ae3f4797f2fb7f209512fc22ad6ef9854ca770")
                Main_OnCommand(zoom_horizontally, 0)

                if #errors > 0 then
                    MB("The following issues were found:\n\n" .. table.concat(errors, "\n"), "Import Errors", 0)
                else
                    MB("Files imported successfully!", "ReaClassical Smart Import", 0)
                end

                UpdateArrange()
                UpdateTimeline()
            end

            wait_for_dialog()
            return
        else
            -- No ImGui, use original behavior
            import_vertical(sessions, session_names, tracks, errors, false, start_pos)
        end
    else -- Horizontal
        import_horizontal(sessions, session_names, tracks, errors, start_pos)
    end

    Undo_EndBlock("Import Audio", -1)

    -- Prepare Takes
    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)

    PreventUIRefresh(-1)

    -- Zoom to all items horizontally
    local zoom_horizontally = NamedCommandLookup("_RSe4ae3f4797f2fb7f209512fc22ad6ef9854ca770")
    Main_OnCommand(zoom_horizontally, 0)

    if #errors > 0 then
        MB("The following issues were found:\n\n" .. table.concat(errors, "\n"), "Import Errors", 0)
    end

    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function show_import_dialog(sessions, session_names, workflow, has_existing_items, start_pos)
    -- Initialize ImGui if not already done
    if not ImGui then
        package.path = ImGui_GetBuiltinPath() .. '/?.lua'
        ImGui = require 'imgui' '0.10'
        ctx = ImGui.CreateContext('ReaClassical Smart Import')
    end

    -- Cache data
    cached_sessions = sessions
    cached_session_names = session_names
    cached_workflow = workflow
    cached_has_existing_items = has_existing_items or false
    cached_start_pos = start_pos or 0

    -- Calculate total takes and max takes in any single session
    cached_total_takes = 0
    local max_takes_per_session = 0
    for _, session_data in pairs(sessions) do
        local session_take_count = 0
        for _ in pairs(session_data) do
            cached_total_takes = cached_total_takes + 1
            session_take_count = session_take_count + 1
        end
        if session_take_count > max_takes_per_session then
            max_takes_per_session = session_take_count
        end
    end

    -- Store max takes per session for use in slider and warnings
    cached_max_takes_per_session = max_takes_per_session

    -- Get current folder count
    local current_folders = count_source_folders()

    -- Load saved preferences
    local _, mode_str = GetProjExtState(0, "ReaClassical", "ImportDistributionMode")
    local _, count_str = GetProjExtState(0, "ReaClassical", "ImportFolderCount")
    local _, include_dest_str = GetProjExtState(0, "ReaClassical", "ImportIncludeDestination")

    if mode_str ~= "" then
        distribution_mode = tonumber(mode_str) or 0
    else
        distribution_mode = 0
    end

    if count_str ~= "" then
        target_folder_count = tonumber(count_str) or math.max(1, current_folders)
    else
        target_folder_count = math.max(1, current_folders)
    end

    if include_dest_str ~= "" then
        include_destination = (include_dest_str == "true")
    else
        include_destination = false
    end

    -- Adjust target_folder_count based on the loaded mode
    if distribution_mode == 0 then
        -- Mode 0: one folder per take
        target_folder_count = max_takes_per_session
    elseif distribution_mode == 2 then
        -- Mode 2: use current folder count
        target_folder_count = include_destination and (current_folders + 1) or current_folders
    end
    -- Mode 1 keeps the saved target_folder_count

    -- Clamp folder count to valid range
    target_folder_count = math.max(1, math.min(cached_max_takes_per_session, target_folder_count))

    -- Reset state
    dialog_open = true
    import_confirmed = false
    import_cancelled = false

    -- Run dialog loop with defer
    local function dialog_loop()
        if not dialog_open then
            -- Dialog closed, return result
            if import_confirmed then
                return true, target_folder_count, distribution_mode
            else
                return false, 0, 0
            end
        end

        draw_import_dialog()

        if dialog_open then
            defer(dialog_loop)
        end
    end

    -- Start the dialog loop
    dialog_loop()

    -- This function now returns immediately, actual result handled in main()
    return nil
end

---------------------------------------------------------------------

function draw_import_dialog()
    local current_folders = count_source_folders()

    local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()
    ImGui.SetNextWindowSizeConstraints(ctx, 500, 400, FLT_MAX, FLT_MAX)

    local visible, open = ImGui.Begin(ctx, "ReaClassical Smart Import", true, ImGui.WindowFlags_NoCollapse)
    dialog_open = open

    if visible then
        -- Header info
        ImGui.Text(ctx, "Workflow: " .. cached_workflow)
        if cached_has_existing_items then
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x88CCFFFF)
            ImGui.Text(ctx, string.format("Appending to existing project (starting at %.1fs)", cached_start_pos))
            ImGui.PopStyleColor(ctx)
        end
        ImGui.Text(ctx, string.format("New files to import: %d takes (%d session%s)",
            cached_total_takes,
            #cached_session_names,
            #cached_session_names == 1 and "" or "s"))
        ImGui.Text(ctx, "Current folders: " .. current_folders)

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Distribution mode
        ImGui.Text(ctx, "Distribution Mode:")
        local changed_mode, new_mode = ImGui.RadioButtonEx(ctx, "One folder per take", distribution_mode, 0)
        if changed_mode then
            distribution_mode = new_mode
            -- In mode 0, we need max takes in any session
            target_folder_count = cached_max_takes_per_session
        end

        changed_mode, new_mode = ImGui.RadioButtonEx(ctx, "Use current folder count", distribution_mode, 2)
        if changed_mode then
            distribution_mode = new_mode
            -- Use all source folders, plus D: if destination is included
            target_folder_count = include_destination and (current_folders + 1) or current_folders
        end

        changed_mode, new_mode = ImGui.RadioButtonEx(ctx, "Round-robin across custom number of folders",
            distribution_mode, 1)
        if changed_mode then
            distribution_mode = new_mode
        end

        ImGui.Spacing(ctx)

        -- Folder count slider (only enabled in custom round-robin mode)
        if distribution_mode ~= 1 then
            ImGui.BeginDisabled(ctx)
        end

        ImGui.Text(ctx, "Number of folders:")
        ImGui.SetNextItemWidth(ctx, -1)
        local changed_count, new_count = ImGui.SliderInt(ctx, "##folder_count",
            target_folder_count, 1, cached_max_takes_per_session)

        if changed_count then
            target_folder_count = new_count
        end

        if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
            if distribution_mode == 1 then
                ImGui.SetTooltip(ctx, "Right-click to type value")
            else
                ImGui.SetTooltip(ctx, "Only available in custom round-robin mode")
            end
        end

        -- Right-click popup for typing value
        if distribution_mode == 1 and ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
            ImGui.OpenPopup(ctx, "folder_count_input")
        end

        if ImGui.BeginPopup(ctx, "folder_count_input") then
            ImGui.Text(ctx, "Enter folder count:")
            ImGui.SetNextItemWidth(ctx, 100)
            local buf = string.format("%d", target_folder_count)
            local rv, input = ImGui.InputText(ctx, "##folderinput", buf, ImGui.InputTextFlags_EnterReturnsTrue)
            if rv then
                local val = tonumber(input)
                if val then
                    target_folder_count = math.max(1, math.min(cached_max_takes_per_session, val))
                end
                ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
        end

        if distribution_mode ~= 1 then
            ImGui.EndDisabled(ctx)
        end

        ImGui.Spacing(ctx)

        -- Checkbox to include destination folder (enabled for all modes)
        local changed_dest, new_dest = ImGui.Checkbox(ctx, "Include destination folder (D:) in distribution",
            include_destination)
        if changed_dest then
            include_destination = new_dest
            -- If in "use current folder count" mode, adjust the count when toggling destination
            if distribution_mode == 2 then
                if include_destination then
                    target_folder_count = current_folders + 1 -- D: + all source folders
                else
                    target_folder_count = current_folders     -- Just all source folders
                end
            end
        end

        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "When enabled, D: folder is used as the first folder in the distribution sequence")
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Preview section
        ImGui.Text(ctx, "Preview:")

        -- Check if new folders will be created and show warning
        local preview_folder_count = target_folder_count

        if distribution_mode == 0 then
            -- Check if new folders will be created for one-folder-per-take mode
            local folders_needed = cached_max_takes_per_session
            local folders_to_create = include_destination and (folders_needed - 1 - current_folders) or
                (folders_needed - current_folders)
            if folders_to_create > 0 then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAA44FF)
                ImGui.Text(ctx, string.format("⚠ Will create %d new folder%s",
                    folders_to_create,
                    folders_to_create == 1 and "" or "s"))
                ImGui.PopStyleColor(ctx)
            end
        else
            -- Mode 1 or 2 (both use round-robin)
            local folders_to_create = include_destination and (preview_folder_count - 1 - current_folders) or
                (preview_folder_count - current_folders)
            if folders_to_create > 0 then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAA44FF)
                ImGui.Text(ctx, string.format("⚠ Will create %d new folder%s",
                    folders_to_create,
                    folders_to_create == 1 and "" or "s"))
                ImGui.PopStyleColor(ctx)
            end
        end

        -- Scrollable preview
        local avail_w, avail_height = ImGui.GetContentRegionAvail(ctx)
        ImGui.BeginChild(ctx, "PreviewScroll", 0, avail_height - 40)

        -- Generate preview using ImGui columns for alignment
        -- Mode 0 uses nil to show one folder per take, modes 1 & 2 use target_folder_count
        generate_preview_ui(cached_sessions, cached_session_names,
            distribution_mode == 0 and nil or target_folder_count,
            include_destination)

        ImGui.EndChild(ctx)

        ImGui.Spacing(ctx)

        -- Buttons
        local button_width = (ImGui.GetContentRegionAvail(ctx) - 8) / 2

        if ImGui.Button(ctx, "Import", button_width, 30) then
            import_confirmed = true
            dialog_open = false

            -- Save preferences
            SetProjExtState(0, "ReaClassical", "ImportDistributionMode", tostring(distribution_mode))
            SetProjExtState(0, "ReaClassical", "ImportFolderCount", tostring(target_folder_count))
            SetProjExtState(0, "ReaClassical", "ImportIncludeDestination", tostring(include_destination))
        end

        ImGui.SameLine(ctx)

        if ImGui.Button(ctx, "Cancel", button_width, 30) then
            import_cancelled = true
            dialog_open = false
        end

        ImGui.End(ctx)
    end
end

---------------------------------------------------------------------

function generate_preview_ui(sessions, session_names, folder_count, include_destination)
    local take_column_x = 60 -- X position where takes should start

    if not folder_count then
        -- One folder per take mode
        for _, session_name in ipairs(session_names) do
            local session_data = sessions[session_name]

            -- Get take numbers
            local take_nums = {}
            for take_num, _ in pairs(session_data) do
                table.insert(take_nums, take_num)
            end
            table.sort(take_nums)

            -- Session header
            local display_name = session_name == "default" and "No Session Name" or session_name
            ImGui.Text(ctx, string.format("Session: %s (%d takes)", display_name, #take_nums))

            -- One folder per take
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
        -- Round-robin mode
        for _, session_name in ipairs(session_names) do
            local session_data = sessions[session_name]

            -- Get take numbers
            local take_nums = {}
            for take_num, _ in pairs(session_data) do
                table.insert(take_nums, take_num)
            end
            table.sort(take_nums)

            -- Calculate distribution
            local distribution = calculate_round_robin_distribution(take_nums, folder_count)

            -- Session header
            local display_name = session_name == "default" and "No Session Name" or session_name
            ImGui.Text(ctx, string.format("Session: %s (%d takes)", display_name, #take_nums))

            -- Show distribution (only non-empty folders)
            for folder_idx = 1, folder_count do
                local takes = distribution[folder_idx] or {}
                if #takes > 0 then
                    -- Determine folder label
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

                    -- Show takes with spacing
                    for i, take_num in ipairs(takes) do
                        ImGui.Text(ctx, string.format("T%03d", take_num))
                        if i < #takes then
                            ImGui.SameLine(ctx)
                        end
                    end

                    -- Show count
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

    -- Initialize folder arrays
    for i = 1, folder_count do
        distribution[i] = {}
    end

    -- Distribute takes round-robin
    for idx, take_num in ipairs(take_nums) do
        local folder_idx = ((idx - 1) % folder_count) + 1
        table.insert(distribution[folder_idx], take_num)
    end

    return distribution
end

---------------------------------------------------------------------

function import_vertical_round_robin(sessions, session_names, tracks, errors, folder_count, use_destination, start_pos)
    -- Ensure we have enough folders
    -- If using destination, we need (folder_count - 1) source folders since D: is folder 1
    local source_folders_needed = use_destination and (folder_count - 1) or folder_count
    create_folders_if_needed(source_folders_needed)

    -- Re-get tracks after folder creation
    tracks = get_tracks("Vertical")

    -- Build folder structure
    local folder_tracks = build_folder_track_map(tracks)

    local pos = start_pos or 0

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]

        -- Sort takes numerically
        local take_nums = {}
        for take_num, _ in pairs(session_data) do
            table.insert(take_nums, take_num)
        end
        table.sort(take_nums)

        -- Calculate round-robin distribution for this session
        local distribution = calculate_round_robin_distribution(take_nums, folder_count)

        -- Track the current position for each folder separately
        local folder_positions = {}
        for i = 1, folder_count do
            folder_positions[i] = pos
        end

        local max_end_position = pos

        -- Process takes in round-robin order (not by folder)
        for take_idx, take_num in ipairs(take_nums) do
            -- Calculate which folder this take goes to (round-robin)
            local folder_idx = ((take_idx - 1) % folder_count) + 1
            local take_data = session_data[take_num]

            -- Determine actual folder index in folder_tracks
            -- If use_destination is true: folder 1 = D: (index 1), folder 2 = S1: (index 2), etc.
            -- If use_destination is false: folder 1 = S1: (index 2), folder 2 = S2: (index 3), etc.
            local actual_folder_idx
            if use_destination then
                actual_folder_idx = folder_idx     -- Direct mapping: 1=D:, 2=S1:, 3=S2:, etc.
            else
                actual_folder_idx = folder_idx + 1 -- Skip D:, start at S1: (index 2)
            end

            local folder_track_list = folder_tracks[actual_folder_idx]

            if not folder_track_list then
                table.insert(errors,
                    string.format("Could not find source folder %d for take T%03d",
                        folder_idx, take_num))
            else
                local take_max_len = 0

                -- Before placing this take, if we've cycled back to folder 1,
                -- we need to advance all folder positions to 2 seconds past the longest item
                if take_idx > folder_count and folder_idx == 1 then
                    local next_round_start = max_end_position + 2
                    for i = 1, folder_count do
                        folder_positions[i] = next_round_start
                    end
                end

                -- Import files for this take at the current folder position
                for track_obj, filepath in pairs(take_data) do
                    -- Find matching track in this folder
                    local target_track = find_track_in_folder_list(folder_track_list, track_obj.base_name)

                    if target_track then
                        SetOnlyTrackSelected(target_track.track)
                        InsertMedia(filepath, 0)
                        local item = GetTrackMediaItem(target_track.track, CountTrackMediaItems(target_track.track) - 1)
                        if item then
                            SetMediaItemInfo_Value(item, "D_POSITION", folder_positions[folder_idx])
                            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                            if len > take_max_len then take_max_len = len end

                            -- Rename item: session_T### or just ###
                            local take = GetActiveTake(item)
                            if take then
                                local item_name
                                if session_name == "default" then
                                    item_name = string.format("%03d", take_num)
                                else
                                    item_name = session_name .. "_T" .. string.format("%03d", take_num)
                                end
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
                            end
                        end
                    else
                        table.insert(errors,
                            string.format("Could not find track '%s' in source folder %d for take T%03d",
                                track_obj.base_name, folder_idx, take_num))
                    end
                end

                -- Calculate the end position of this take
                local take_end_position = folder_positions[folder_idx] + take_max_len

                -- Track the maximum end position across ALL folders in this round
                if take_end_position > max_end_position then
                    max_end_position = take_end_position
                end

                -- Don't advance this folder's position yet - we'll do it when cycling back
            end
        end

        pos = max_end_position + 10 -- Move to next session (10 second gap)
    end
end

---------------------------------------------------------------------

function create_folders_if_needed(target_count)
    local current_folders = count_source_folders()
    local folders_needed = target_count

    if folders_needed > current_folders then
        local track_one = GetTrack(0, 0) -- Track 1 in project
        for i = 1, folders_needed - current_folders do
            SetOnlyTrackSelected(track_one)
            Main_OnCommand(40340, 0)
            Main_OnCommand(40062, 0) -- Duplicate track
            select_children_of_selected_folders()
            Main_OnCommand(40421, 0) -- Item: Select all items in track
            delete_items()
            unselect_folder_children()
        end
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        Main_OnCommand(40297, 0) -- Unselect all tracks
    end
end

---------------------------------------------------------------------

function import_horizontal(sessions, session_names, tracks, errors, start_pos)
    local pos = start_pos or 0

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]

        -- Sort takes numerically
        local take_nums = {}
        for take_num, _ in pairs(session_data) do
            table.insert(take_nums, take_num)
        end
        table.sort(take_nums)

        -- Collect all tracks used in this session (across all takes)
        local tracks_in_session = {}
        for _, take_num in ipairs(take_nums) do
            for track_obj, _ in pairs(session_data[take_num]) do
                tracks_in_session[track_obj] = true
            end
        end

        -- Import each take
        for _, take_num in ipairs(take_nums) do
            local take_data = session_data[take_num]
            local max_len = 0

            -- Import files for this take
            for track_obj, filepath in pairs(take_data) do
                SetOnlyTrackSelected(track_obj.track)
                InsertMedia(filepath, 0)
                local item = GetTrackMediaItem(track_obj.track, CountTrackMediaItems(track_obj.track) - 1)
                if item then
                    SetMediaItemInfo_Value(item, "D_POSITION", pos)
                    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                    if len > max_len then max_len = len end

                    -- Rename item: session_T### or just ###
                    local take = GetActiveTake(item)
                    if take then
                        local item_name
                        if session_name == "default" then
                            -- No session name, just padded number
                            item_name = string.format("%03d", take_num)
                        else
                            -- Has session name
                            item_name = session_name .. "_T" .. string.format("%03d", take_num)
                        end
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
                    end
                end
            end

            -- Check for missing tracks in this take (compared to other takes in same session)
            for track_obj, _ in pairs(tracks_in_session) do
                if not take_data[track_obj] then
                    table.insert(errors,
                        string.format("Missing take T%03d for track '%s' in session '%s'",
                            take_num, track_obj.display_name, session_name))
                end
            end

            pos = pos + max_len + 2
        end

        pos = pos + 10 -- Gap between sessions
    end
end

---------------------------------------------------------------------

function import_vertical(sessions, session_names, tracks, errors, use_destination, start_pos)
    -- Determine maximum number of takes needed across all sessions
    local max_takes = 0
    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]
        local take_count = 0
        for _ in pairs(session_data) do
            take_count = take_count + 1
        end
        if take_count > max_takes then
            max_takes = take_count
        end
    end

    -- Create all needed folders upfront
    local current_folders = count_source_folders()
    local folders_needed = max_takes

    -- If using destination, we need (folders_needed - 1) source folders since D: counts as one
    local source_folders_needed = use_destination and (folders_needed - 1) or folders_needed

    if source_folders_needed > current_folders then
        local track_one = GetTrack(0, 0) -- Track 1 in project
        for i = 1, source_folders_needed - current_folders do
            SetOnlyTrackSelected(track_one)
            Main_OnCommand(40340, 0)
            Main_OnCommand(40062, 0) -- Duplicate track
            select_children_of_selected_folders()
            Main_OnCommand(40421, 0) -- Item: Select all items in track
            delete_items()
            unselect_folder_children()
        end
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        Main_OnCommand(40297, 0) -- Unselect all tracks
    end

    -- Re-get tracks after folder creation
    tracks = get_tracks("Vertical")

    -- Build folder structure once
    local folder_tracks = build_folder_track_map(tracks)

    local pos = start_pos or 0

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]

        -- Sort takes numerically
        local take_nums = {}
        for take_num, _ in pairs(session_data) do
            table.insert(take_nums, take_num)
        end
        table.sort(take_nums)

        local max_len = 0

        -- Import each take into its corresponding folder
        for take_idx, take_num in ipairs(take_nums) do
            local take_data = session_data[take_num]

            -- Determine actual folder index in folder_tracks
            -- If use_destination is true: take 1 = D: (index 1), take 2 = S1: (index 2), etc.
            -- If use_destination is false: take 1 = S1: (index 2), take 2 = S2: (index 3), etc.
            local folder_idx
            if use_destination then
                folder_idx = take_idx     -- Direct mapping: 1=D:, 2=S1:, 3=S2:, etc.
            else
                folder_idx = take_idx + 1 -- Skip D:, start at S1: (index 2)
            end

            local folder_track_list = folder_tracks[folder_idx]

            if not folder_track_list then
                table.insert(errors,
                    string.format("Could not find source folder %d for take T%03d",
                        take_idx, take_num))
            else
                -- Import files for this take
                for track_obj, filepath in pairs(take_data) do
                    -- Find matching track in this folder
                    local target_track = find_track_in_folder_list(folder_track_list, track_obj.base_name)

                    if target_track then
                        SetOnlyTrackSelected(target_track.track)
                        InsertMedia(filepath, 0)
                        local item = GetTrackMediaItem(target_track.track, CountTrackMediaItems(target_track.track) - 1)
                        if item then
                            SetMediaItemInfo_Value(item, "D_POSITION", pos)
                            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                            if len > max_len then max_len = len end

                            -- Rename item: session_T### or just ###
                            local take = GetActiveTake(item)
                            if take then
                                local item_name
                                if session_name == "default" then
                                    -- No session name, just padded number
                                    item_name = string.format("%03d", take_num)
                                else
                                    -- Has session name
                                    item_name = session_name .. "_T" .. string.format("%03d", take_num)
                                end
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
                            end
                        end
                    else
                        table.insert(errors,
                            string.format("Could not find track '%s' in source folder %d for take T%03d",
                                track_obj.base_name, take_idx, take_num))
                    end
                end
            end
        end

        pos = pos + max_len + 10 -- Move to next session
    end
end

---------------------------------------------------------------------

function count_source_folders()
    -- Count folders that have "S#:" prefix (source folders)
    -- Destination folder is "D:", source folders are "S1:", "S2:", etc.
    local count = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            local _, name = GetTrackName(track)
            if name:match("^S%d+:") then
                count = count + 1
            end
        end
    end
    return count
end

---------------------------------------------------------------------

function build_folder_track_map(tracks)
    -- Build a map: folder_tracks[folder_number] = {list of track objects in that folder}
    -- Folder 1 = D: (destination), Folder 2 = S1:, Folder 3 = S2:, etc.
    local folder_tracks = {}
    local current_folder = 0
    local in_folder = false

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        local _, name = GetTrackName(track)

        if depth == 1 then
            -- This is a folder parent track
            current_folder = current_folder + 1
            folder_tracks[current_folder] = {}
            in_folder = true

            -- Include the parent track itself (it's used as a normal track in ReaClassical)
            -- Find the matching track_obj from our tracks table
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
        elseif depth == -1 then
            -- This is the last child track (folder end marker)
            -- Add this track to the folder, then mark folder as ended
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
            in_folder = false
        elseif in_folder then
            -- This is a child track within the folder (depth == 0)
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
    -- Find a track with matching base_name in the given folder's track list
    for _, track_obj in ipairs(folder_track_list) do
        if track_obj.base_name == base_name then
            return track_obj
        end
    end
    return nil
end

---------------------------------------------------------------------

function parse_canonical_filename(filepath)
    -- Extract just the filename from the path
    local filename = filepath:match("([^/\\]+)$")
    if not filename then return nil end

    -- Remove extension
    local name_no_ext = filename:match("(.+)%.[^.]+$")
    if not name_no_ext then return nil end

    -- Extract take number: _T### at the end
    local take_str = name_no_ext:match("_T(%d+)$")
    if not take_str then return nil end

    -- Remove the take number from the name
    local name_without_take = name_no_ext:gsub("_T%d+$", "")

    -- Now we have something like: "session_track" or just "track"
    -- OR in vertical workflow: "session_D_track" or "session_S1_track"
    -- We need to split on underscores and identify the track name (last part)
    -- and potentially a folder prefix (second-to-last part)

    local parts = {}
    for part in name_without_take:gmatch("[^_]+") do
        table.insert(parts, part)
    end

    if #parts == 0 then return nil end

    local track_name, session_name

    if #parts == 1 then
        -- Just track name, no session
        track_name = parts[1]
        session_name = "default"
    elseif #parts == 2 then
        -- Could be "session_track" OR "prefix_track" (vertical with no session)
        -- Check if first part is a folder prefix
        if parts[1]:match("^D$") or parts[1]:match("^S%d+$") then
            -- It's a prefix without session: "D_track" or "S1_track"
            track_name = parts[2]
            session_name = "default"
        else
            -- Normal: "session_track"
            session_name = parts[1]
            track_name = parts[2]
        end
    else
        -- 3+ parts: could be "session_prefix_track" or "part1_part2_..._track"
        -- Check if second-to-last part is a folder prefix
        local potential_prefix = parts[#parts - 1]
        if potential_prefix:match("^D$") or potential_prefix:match("^S%d+$") then
            -- It's a vertical workflow file: "session_D_track" or "session_S1_track"
            track_name = parts[#parts]
            table.remove(parts, #parts) -- remove track
            table.remove(parts, #parts) -- remove prefix
            session_name = table.concat(parts, "_")
        else
            -- Normal multi-part session: "part1_part2_track"
            track_name = parts[#parts]
            table.remove(parts, #parts)
            session_name = table.concat(parts, "_")
        end
    end

    return {
        filename = filename,
        session_name = session_name,
        track_name = track_name:lower(),
        take_num = tonumber(take_str)
    }
end

---------------------------------------------------------------------

function get_tracks(workflow)
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        local _, name = GetTrackName(tr)
        name = name:gsub("^%s*(.-)%s*$", "%1") -- strip whitespace

        local base_name = name
        local is_folder_parent = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1

        -- In vertical workflow, strip prefix like "D:", "S1:", "S2:" etc.
        -- In horizontal workflow, there are no prefixes
        if workflow == "Vertical" then
            -- Match patterns: "D:", "S1:", "S2:", etc.
            local stripped = name:match("^[DS]%d*:%s*(.+)$")
            if stripped then
                base_name = stripped
            end
        end

        table.insert(tracks, {
            track = tr,
            display_name = name,
            base_name = base_name:lower(),
            is_folder_parent = is_folder_parent
        })
    end
    return tracks
end

---------------------------------------------------------------------

function find_track_by_name(tracks, track_name)
    track_name = track_name:lower()
    for _, track_obj in ipairs(tracks) do
        if track_obj.base_name == track_name then
            return track_obj
        end
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

    -- Enumerate files
    while true do
        local file = EnumerateFiles(path, i)
        if not file then break end
        if file:lower():match("%.wav$") or file:lower():match("%.flac$") or file:lower():match("%.aif") then
            table.insert(files, path .. "/" .. file)
        end
        i = i + 1
    end

    -- Enumerate subdirectories
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
    -- Find the end position of the last item on the timeline
    local max_end = 0
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = pos + len
        if item_end > max_end then
            max_end = item_end
        end
    end
    return max_end
end

---------------------------------------------------------------------

function get_used_source_files()
    -- Collect the full paths of all source audio files already used in the project
    local used = {}
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        local take = GetActiveTake(item)
        if take then
            local source = GetMediaItemTake_Source(take)
            if source then
                local filepath = GetMediaSourceFileName(source)
                if filepath and filepath ~= "" then
                    -- Normalize path separators for consistent comparison
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
        if IsTrackSelected(tr) then
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if depth == 1 then -- folder parent
                local j = i + 1
                while j < track_count do
                    local ch_tr = GetTrack(0, j)
                    SetTrackSelected(ch_tr, true) -- select child track

                    local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
                    if ch_depth == -1 then
                        break -- end of folder children
                    end

                    j = j + 1
                end
            end
        end
    end
end

---------------------------------------------------------------------

function unselect_folder_children()
    local num_tracks = CountTracks(0)
    local depth = 0
    local unselect_mode = false

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if IsTrackSelected(tr) and folder_change == 1 then
            -- We found a selected folder parent
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        -- Adjust folder depth
        if folder_change > 0 then
            depth = depth + folder_change
        elseif folder_change < 0 then
            depth = depth + folder_change
            if depth <= 0 then
                unselect_mode = false
                depth = 0
            end
        end
    end
end

---------------------------------------------------------------------

function delete_items()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            -- Delete items from this track until none remain
            while CountTrackMediaItems(track) > 0 do
                local item = GetTrackMediaItem(track, 0)
                DeleteTrackMediaItem(track, item)
            end
        end
    end
end

---------------------------------------------------------------------

main()
