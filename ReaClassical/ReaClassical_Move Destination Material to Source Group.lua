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
local main, duplicate_first_folder, sync_based_on_workflow
local delete_first_group_items

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    -- PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "Vertical" then
        MB("This function requires a vertical ReaClassical project. " ..
            "Please create one or convert your existing ReaClassical project using F8.", "ReaClassical Error", 0)
        return
    end

    local first_track = duplicate_first_folder()
    delete_first_group_items()
    sync_based_on_workflow(workflow)
    -- prepare_takes()
    SetOnlyTrackSelected(first_track)
    Main_OnCommand(40289, 0) -- unselect all items

    Undo_EndBlock('Move Destination Material to Source', 0)
    -- PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function duplicate_first_folder()
    local first_track = GetTrack(0, 0)
    if not first_track then return end
    SetOnlyTrackSelected(first_track)

    Main_OnCommand(40062, 0) -- Track: Duplicate tracks
    return first_track
end

---------------------------------------------------------------------

function sync_based_on_workflow(workflow)
    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    elseif workflow == "Horizontal" then
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end
end

---------------------------------------------------------------------

function delete_first_group_items()
    local num_tracks = CountTracks(0)
    if num_tracks == 0 then return end

    local first_track = GetTrack(0, 0)
    if not first_track then return end

    local track_count = 1
    for i = 1, num_tracks - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        track_count = track_count + 1
        if depth < 0 then break end
    end

    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local num_items = CountTrackMediaItems(track)
            for j = num_items - 1, 0, -1 do
                local item = GetTrackMediaItem(track, j)
                DeleteTrackMediaItem(track, item)
            end
        end
    end
end

---------------------------------------------------------------------

main()
