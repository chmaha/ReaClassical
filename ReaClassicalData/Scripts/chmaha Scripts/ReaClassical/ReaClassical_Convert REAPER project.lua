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
local main, duplicate_project_in_new_tab, flatten_all_folders
local make_all_tracks_one_folder, delete_empty_tracks, reset_all_routing
local add_rc_ext_state

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "" then
        MB("This is already a ReaClassical project.", "ReaClassical Conversion", 0)
        return
    end

    local ret = duplicate_project_in_new_tab()
    if ret == -1 then return end
    flatten_all_folders()
    delete_empty_tracks()
    reset_all_routing()
    make_all_tracks_one_folder()
    add_rc_ext_state()
    local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
    Main_OnCommand(F7_sync, 0)
    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)
    Main_SaveProject(0, false)
    MB("Your project has been converted.\n\n"
        .. "Any folders have been flattened, empty tracks removed"
        .. "and a single folder created for horizontal workflow.\n"
        .. "Any regular track FX from your original project have been"
        .. "placed onto the ReaClassical mixer tracks.\n"
        .. "Recreate any custom routing and bus FX using ReaClassical special tracks via # shortcut."
        , "ReaClassical Conversion", 0)
end

---------------------------------------------------------------------

function duplicate_project_in_new_tab()
    -- Get current project path
    local _, proj_path = EnumProjects(-1, "")
    local isdirty = IsProjectDirty(0)
    if not proj_path or proj_path == "" or not proj_path:lower():match("%.rpp$") or isdirty == 1 then
        MB("Please save the project before duplicating.", "Project Not Saved", 0)
        return -1
    end

    -- Open a new empty project tab
    Main_OnCommand(40859, 0) -- File: New project tab

    -- Now open the saved project in the new tab (which is currently active)
    Main_openProject(proj_path)

    -- Extract filename and extension
    local current_filename, ext = proj_path:match("([^\\/]-)%.([Rr][Pp][Pp])$")
    current_filename = current_filename or "Untitled"
    ext = ext or "RPP"

    -- Extract directory path
    local dir = proj_path:match("^(.*)[\\/][^\\/]-%.([Rr][Pp][Pp])$") or GetProjectPath("")

    -- Build new filename keeping original extension case
    local new_filename = current_filename .. "_converted." .. ext
    local new_filepath = dir .. "/" .. new_filename

    -- Save current project as the new file
    Main_SaveProjectEx(0, new_filepath, 8) -- false = no prompt
end

---------------------------------------------------------------------

function flatten_all_folders()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        -- Set folder depth to 0 (no folder or child)
        SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
    end
end

---------------------------------------------------------------------

function make_all_tracks_one_folder()
    local num_tracks = CountTracks(0)
    if num_tracks < 2 then
        Undo_EndBlock("Make all tracks one folder", -1)
        return -- nothing to do if only one or zero tracks
    end

    -- First track becomes the folder parent
    local first_track = GetTrack(0, 0)
    SetMediaTrackInfo_Value(first_track, "I_FOLDERDEPTH", 1)

    -- Set all intermediate tracks to normal children
    for i = 1, num_tracks - 2 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
    end

    -- Last track closes the folder
    local last_track = GetTrack(0, num_tracks - 1)
    SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", -1)
end

---------------------------------------------------------------------

function delete_empty_tracks()
    local num_tracks = CountTracks(0)

    -- Iterate in reverse to safely delete
    for i = num_tracks - 1, 0, -1 do
        local track = GetTrack(0, i)
        local item_count = CountTrackMediaItems(track)
        if item_count == 0 then
            DeleteTrack(track)
        end
    end

    -- After deleting, check how many tracks are left
    local remaining_tracks = CountTracks(0)
    if remaining_tracks == 1 then
        -- Add a second empty track
        InsertTrackAtIndex(1, true)
    end
end

---------------------------------------------------------------------

function reset_all_routing()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)

        -- Remove all sends
        local send_count = GetTrackNumSends(track, 0)
        for s = send_count - 1, 0, -1 do
            RemoveTrackSend(track, 0, s)
        end

        -- Remove all receives
        local receive_count = GetTrackNumSends(track, -1)
        for r = receive_count - 1, 0, -1 do
            RemoveTrackSend(track, -1, r)
        end

        -- Remove all hardware outputs
        local hwout_count = GetTrackNumSends(track, 1)
        for h = hwout_count - 1, 0, -1 do
            RemoveTrackSend(track, 1, h)
        end

        -- Ensure track sends audio to master/parent
        SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
    end
end

---------------------------------------------------------------------

function add_rc_ext_state()
    SetProjExtState(0, "ReaClassical", "RCProject", "y")
    local creation_date = os.date("%Y-%m-%d %H:%M:%S", os.time())
    SetProjExtState(0, "ReaClassical", "CreationDate", creation_date)
end

---------------------------------------------------------------------

main()
