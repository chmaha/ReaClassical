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
local main, swap_selected_dest_copy_with_destination

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    swap_selected_dest_copy_with_destination()

    Undo_EndBlock('Make Dest Copy Destination', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function swap_selected_dest_copy_with_destination()
    local track_count = CountTracks(0)
    if track_count == 0 then return end

    -- Get the first selected track
    local sel_track = GetSelectedTrack(0, 0)
    if not sel_track then return end

    -- If the selected track is not a parent (folder depth != 1), find its parent
    local parent_track = sel_track
    if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") ~= 1 then
        local idx = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
        while idx >= 0 do
            local t = GetTrack(0, idx)
            if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
                parent_track = t
                break
            end
            idx = idx - 1
        end
    end

    -- Check if parent_track is a dest_copy
    local _, is_copy = GetSetMediaTrackInfo_String(parent_track, "P_EXT:dest_copy", "", false)
    if is_copy ~= "y" then
        MB("Selected track (or its parent) is not a dest_copy.", "Swap Failed", 0)
        return
    end

    local selected_dest_copy = parent_track

    -- Find the destination folder
    local destination_folder = nil
    for i = 0, track_count - 1 do
        local t = GetTrack(0, i)
        local _, is_dest = GetSetMediaTrackInfo_String(t, "P_EXT:destination", "", false)
        if is_dest == "y" and GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
            destination_folder = t
            break
        end
    end
    if not destination_folder then
        MB("No destination folder found.", "Swap Failed", 0)
        return
    end

    -- Swap the p_ext markers
    GetSetMediaTrackInfo_String(destination_folder, "P_EXT:destination", "", true)
    GetSetMediaTrackInfo_String(destination_folder, "P_EXT:dest_copy", "y", true)
    GetSetMediaTrackInfo_String(selected_dest_copy, "P_EXT:dest_copy", "", true)
    GetSetMediaTrackInfo_String(selected_dest_copy, "P_EXT:destination", "y", true)

    local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
    Main_OnCommand(F8_sync, 0)
end

---------------------------------------------------------------------

main()
