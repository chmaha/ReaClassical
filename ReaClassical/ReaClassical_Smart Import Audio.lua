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
local abort_if_items_exist, delete_items
local select_children_of_selected_folders, unselect_folder_children

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

    local items = abort_if_items_exist()
    if items then return end

    local files = scan_media_folder_recursive(get_project_media_path())

    -- Show error if no audio files found
    if #files == 0 then
        MB("No audio files were found in the 'media' folder. Please add audio files and try again.",
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

    -- Sort sessions alphabetically
    local session_names = {}
    for session_name, _ in pairs(sessions) do
        table.insert(session_names, session_name)
    end
    table.sort(session_names)

    -- Import based on workflow
    if workflow == "Vertical" then
        import_vertical(sessions, session_names, tracks, errors)
    else -- Horizontal
        import_horizontal(sessions, session_names, tracks, errors)
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

---------------------------------------------------------------------

function import_horizontal(sessions, session_names, tracks, errors)
    local pos = 0

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

function import_vertical(sessions, session_names, tracks, errors)
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
        local sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(sync, 0)
        Main_OnCommand(40297, 0) -- Unselect all tracks
    end

    -- Re-get tracks after folder creation
    tracks = get_tracks("Vertical")

    -- Build folder structure once
    local folder_tracks = build_folder_track_map(tracks)

    local pos = 0

    for _, session_name in ipairs(session_names) do
        local session_data = sessions[session_name]

        -- Sort takes numerically
        local take_nums = {}
        for take_num, _ in pairs(session_data) do
            table.insert(take_nums, take_num)
        end
        table.sort(take_nums)

        local max_len = 0

        -- Import each take into its corresponding source folder
        for take_idx, take_num in ipairs(take_nums) do
            local take_data = session_data[take_num]

            -- Source folders start at index 2 (1 is destination "D:")
            -- So take 1 goes to S1: (folder_tracks[2]), take 2 to S2: (folder_tracks[3]), etc.
            local folder_idx = take_idx + 1
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
    local _, projfn = EnumProjects(-1, '')
    local projpath = projfn:match("^(.*)[/\\]")
    if not projpath then return nil end
    return projpath .. "/media"
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
        if file:match("%.wav$") or file:match("%.flac$") or file:match("%.aif") then
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

function abort_if_items_exist()
    if CountMediaItems(0) > 0 then
        MB("Project already contains items. Please run on an empty project.", "Import Aborted", 0)
        return true
    end
    return false
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
