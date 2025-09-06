--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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
local scan_media_folder, get_tracks, get_markers, parse_filename
local find_track, find_marker, abort_if_items_exist
local get_session_name_from_filename

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local items = abort_if_items_exist()
    if items then return end
    local files = scan_media_folder()
    -- Show error if no audio files found
    if #files == 0 then
        ShowMessageBox("No audio files were found in the 'media' folder. Please add audio files and try again.",
            "Import Aborted", 0)
        return
    end
    local tracks = get_tracks()
    local markers = get_markers()
    local errors = {}
    local grid = {}
    local session_order = {}

    local use_marker_order = (#markers > 0)

    -- Organize files
    for _, file in ipairs(files) do
        local info = parse_filename(file)
        local tr, trname = find_track(tracks, info.track)
        if not tr then
            table.insert(errors, info.full .. " (no track match)")
        else
            local sessionkey

            if use_marker_order then
                -- Try to match to folder name first
                local folder = file:match("(.+)/[^/]+$") -- full folder path
                local folder_name = folder and folder:match(".+[/\\](.+)$") or nil
                if folder_name then
                    sessionkey = folder_name
                else
                    -- fallback to matching filename against markers
                    local _, name, _ = find_marker(markers, info.session)
                    sessionkey = name or info.session
                end
            else
                -- No user markers: use folder name if present
                local folder = file:match("(.+)/[^/]+$") -- full folder path
                local folder_name = folder and folder:match(".+[/\\](.+)$") or nil
                if folder_name then
                    sessionkey = folder_name
                else
                    -- fallback: extract session from filename
                    sessionkey = get_session_name_from_filename(info.full, tracks)
                end
            end

            if not grid[sessionkey] then
                grid[sessionkey] = { pos = nil, index = nil, takes = {}, tracksused = {} }
            end
            grid[sessionkey].takes[info.take] = grid[sessionkey].takes[info.take] or {}
            grid[sessionkey].takes[info.take][tr] = { file = file, trackname = trname }
            grid[sessionkey].tracksused[tr] = trname
        end
    end

    -- Determine session order
    if use_marker_order then
        for _, m in ipairs(markers) do
            table.insert(session_order, m.name)
        end
    else
        for k, _ in pairs(grid) do
            table.insert(session_order, k)
        end
        table.sort(session_order)
    end

    -- Delete empty markers if using markers
    if use_marker_order then
        for _, m in ipairs(markers) do
            local sname = m.name
            if not grid[sname] or next(grid[sname].takes) == nil then
                DeleteProjectMarker(0, m.index, false)
            else
                grid[sname].index = m.index
            end
        end
    end

    Undo_BeginBlock()
    local pos = 0

    for _, session in ipairs(session_order) do
        local block = grid[session]
        if not block or next(block.takes) == nil then goto continue end

        -- Always add markers, either from user or auto-generated
        if use_marker_order then
            if block.index then DeleteProjectMarker(0, block.index, false) end
            AddProjectMarker(0, false, pos, 0, session, -1)
        else
            -- auto-generated session marker
            AddProjectMarker(0, false, pos, 0, session, -1)
        end


        local takenums = {}
        for take, _ in pairs(block.takes) do table.insert(takenums, take) end
        table.sort(takenums)

        for _, take in ipairs(takenums) do
            local takegroup = block.takes[take]
            local max_len = 0
            for tr, data in pairs(takegroup) do
                SetOnlyTrackSelected(tr)
                InsertMedia(data.file, 0)
                local item = GetTrackMediaItem(tr, CountTrackMediaItems(tr) - 1)
                if item then
                    SetMediaItemInfo_Value(item, "D_POSITION", pos)
                    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
                    if len > max_len then max_len = len end
                end
            end
            for tr, trname in pairs(block.tracksused) do
                if not takegroup[tr] then
                    table.insert(errors,
                        string.format("Missing take T%03d for track '%s' in session '%s'", take, trname, session))
                end
            end
            pos = pos + max_len + 2
        end
        pos = pos + 10
        ::continue::
    end

    Undo_EndBlock("Import Audio", -1)

    SetProjExtState(0, "ReaClassical", "prepare_silent", "y")
    -- Prepare Takes
    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)
    SetProjExtState(0, "ReaClassical", "prepare_silent", "")
    PreventUIRefresh(-1)
    -- Zoom to all items horizontally
    local zoom_horizontally = NamedCommandLookup("_RSe4ae3f4797f2fb7f209512fc22ad6ef9854ca770")
    Main_OnCommand(zoom_horizontally, 0)

    if #errors > 0 then
        MB("The following issues were found:\n\n" .. table.concat(errors, "\n"), "Import Errors", 0)
    else
        MB("Files imported successfully!", "ReaClassical Smart Import", 0)
    end

    Undo_EndBlock('Smart Import Audio', 0)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function get_project_media_path()
    local _, projfn = EnumProjects(-1, "")
    if not projfn or projfn == "" then return nil end

    -- detect last path separator
    local projpath = projfn:match("^(.*)[/\\]")
    if not projpath then return nil end

    -- normalize separator for OS
    local sep = package.config:sub(1,1) -- "\" on Windows, "/" on Unix/Mac
    return projpath .. sep .. "media"
end

---------------------------------------------------------------------

function scan_media_folder_recursive(path, files)
    files = files or {}
    local i, j = 0, 0
    while true do
        local file = EnumerateFiles(path, i)
        if not file then break end
        if file:match("%.wav$") or file:match("%.flac$") or file:match("%.aif") then
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

function scan_media_folder()
    local path = get_project_media_path()
    if not path then return {} end
    return scan_media_folder_recursive(path)
end

---------------------------------------------------------------------

function get_tracks()
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        local _, name = GetTrackName(tr)
        tracks[#tracks + 1] = { name = name:lower(), tr = tr, rawname = name }
    end
    return tracks
end

---------------------------------------------------------------------

function get_markers()
    local markers = {}
    local idx = 0
    while true do
        local retval, isrgn, pos, _, name, index = EnumProjectMarkers(idx)
        if retval == 0 then break end
        if not isrgn then markers[#markers + 1] = { name = name:lower(), pos = pos, index = index } end
        idx = idx + 1
    end
    return markers
end

---------------------------------------------------------------------

function parse_filename(fname)
    local base = fname:match("([^/\\]+)$")
    local take = base:match("_T(%d+)")
    return {
        full = base,
        fname = fname,
        track = base:lower(),
        session = base:lower(),
        take = tonumber(take) or 1
    }
end

---------------------------------------------------------------------

function find_track(tracks, fname)
    for _, t in ipairs(tracks) do
        if fname:find(t.name, 1, true) then return t.tr, t.rawname end
    end
    return nil, nil
end

---------------------------------------------------------------------

function find_marker(markers, fname)
    for _, m in ipairs(markers) do
        if fname:find(m.name, 1, true) then return m.pos, m.name, m.index end
    end
    return nil, nil, nil
end

---------------------------------------------------------------------

function abort_if_items_exist()
    if CountMediaItems(0) > 0 then
        ShowMessageBox("Project already contains items. Please run on an empty project.", "Import Aborted", 0)
        return true
    end
    return false
end

---------------------------------------------------------------------

function get_session_name_from_filename(fname, tracks)
    local s = fname
    -- Strip file extension
    s = s:gsub("%.[^.]+$", "")
    -- Strip track names
    for _, t in ipairs(tracks) do s = s:gsub(t.name, "") end
    -- Strip take numbers: _T### or T### or take###
    s = s:gsub("[_-]?T%d+", "")
    s = s:gsub("[_-]?take%d+", "")
    -- Remove leading/trailing non-alphanumeric characters
    s = s:match("%w[%w]*")
    return s or "session"
end

---------------------------------------------------------------------

main()
