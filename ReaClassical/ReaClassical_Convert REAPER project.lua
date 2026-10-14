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
local main, duplicate_project_in_new_tab, flatten_all_folders
local make_all_tracks_one_folder, delete_empty_tracks, reset_all_routing
local add_rc_ext_state, tag_source_tracks

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "" then
        MB("This is already a ReaClassical project.", "ReaClassical Conversion", 0)
        return
    end
    PreventUIRefresh(1)
    local ret = duplicate_project_in_new_tab()
    if ret == -1 then return end
    flatten_all_folders()
    delete_empty_tracks()
    reset_all_routing()
    make_all_tracks_one_folder()
    tag_source_tracks()
    add_rc_ext_state()
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
    dofile(script_path .. "ReaClassical_Auto-color project.lua")
    Main_SaveProject(0, false)
    PreventUIRefresh(-1)
    MB("Your project has been converted.\n\n"
        .. "Any folders have been flattened, empty tracks removed "
        .. "and a single folder created for horizontal workflow.\n"
        .. "Any regular track FX from your original project have been "
        .. "placed onto the ReaClassical mixer tracks.\n"
        .. "Recreate any custom routing and bus FX using ReaClassical's Mission Control."
        , "ReaClassical Conversion", 0)
    if not gui_mode.accessible() then
        local mission_control = NamedCommandLookup("_RScaa05755eb1dca4cec87c8ba9fe0ddf6570ce73c")
        Main_OnCommand(mission_control, 0)
    end
end

function duplicate_project_in_new_tab()
    local _, proj_path = EnumProjects(-1, "")
    local isdirty = IsProjectDirty(0)
    if not proj_path or proj_path == "" or not proj_path:lower():match("%.rpp$") or isdirty == 1 then
        MB("Please save the project before duplicating.", "Project Not Saved", 0)
        return -1
    end

    Main_OnCommand(40859, 0)

    Main_openProject(proj_path)

    local current_filename, ext = proj_path:match("([^\\/]-)%.([Rr][Pp][Pp])$")
    current_filename = current_filename or "Untitled"
    ext = ext or "RPP"

    local dir = proj_path:match("^(.*)[\\/][^\\/]-%.([Rr][Pp][Pp])$") or GetProjectPath("")

    local new_filename = current_filename .. "_converted." .. ext
    local new_filepath = dir .. "/" .. new_filename

    Main_SaveProjectEx(0, new_filepath, 8)
end

function flatten_all_folders()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
    end
end

function make_all_tracks_one_folder()
    local num_tracks = CountTracks(0)
    if num_tracks < 2 then
        Undo_EndBlock("Make all tracks one folder", -1)
        return
    end

    local first_track = GetTrack(0, 0)
    SetMediaTrackInfo_Value(first_track, "I_FOLDERDEPTH", 1)

    for i = 1, num_tracks - 2 do
        local track = GetTrack(0, i)
        SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0)
    end

    local last_track = GetTrack(0, num_tracks - 1)
    SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", -1)
end

function delete_empty_tracks()
    local num_tracks = CountTracks(0)

    for i = num_tracks - 1, 0, -1 do
        local track = GetTrack(0, i)
        local item_count = CountTrackMediaItems(track)
        if item_count == 0 then
            DeleteTrack(track)
        end
    end

    local remaining_tracks = CountTracks(0)
    if remaining_tracks == 1 then
        InsertTrackAtIndex(1, true)
    end
end

function reset_all_routing()
    local num_tracks = CountTracks(0)

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)

        local send_count = GetTrackNumSends(track, 0)
        for s = send_count - 1, 0, -1 do
            RemoveTrackSend(track, 0, s)
        end

        local receive_count = GetTrackNumSends(track, -1)
        for r = receive_count - 1, 0, -1 do
            RemoveTrackSend(track, -1, r)
        end

        local hwout_count = GetTrackNumSends(track, 1)
        for h = hwout_count - 1, 0, -1 do
            RemoveTrackSend(track, 1, h)
        end

        SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
    end
end

function add_rc_ext_state()
    SetProjExtState(0, "ReaClassical", "RCProject", "y")
    local creation_date = os.date("%Y-%m-%d %H:%M:%S", os.time())
    SetProjExtState(0, "ReaClassical", "CreationDate", creation_date)
end

function tag_source_tracks()
    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        GetSetMediaTrackInfo_String(track, "P_EXT:Source", "y", true)
    end
end

main()
