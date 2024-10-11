--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

local main, folder_check, show_track_name_dialog, add_rcmaster
local create_mixer_table

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local folders = folder_check()
    if folders > 0 then
        MB("You can either import your media on one regular track for horizontal editing \z
                        or on multiple regular tracks for a vertical workflow.\n\z
                        The function will automatically create the required folder group(s).\z
                    \nTo explode multi-channel after editing has started, \z
                    please use on an empty project tab and copy across.", "Error: Folders detected!", 0)
        return
    end
    SetProjExtState(0, "ReaClassical", "RCProject", "y")

    for i = CountTracks(0) - 1, 0, -1 do
        local track = GetTrack(0, i)
        if CountTrackMediaItems(track) == 0 then
            reaper.DeleteTrack(track)
        end
    end

    Main_OnCommand(40182, 0) -- select all items
    local num = CountSelectedMediaItems(0, 0)

    local takes = {}
    local items = {}
    --local track_number
    for i = 0, num - 1 do
        local item = GetSelectedMediaItem(0, i)
        items[#items + 1] = item
        local take = GetActiveTake(item)
        takes[#takes + 1] = take
    end

    -- Item: Explode multichannel audio or MIDI to new one-channel items
    Main_OnCommand(40894, 0)

    local int = MB("Do you want to treat the first two iso tracks as interleaved stereo?",
        "Multi-channel Explode", 4)
    if int == 6 then
        local prev_track_number
        for _, item in pairs(items) do
            local item_track = GetMediaItem_Track(item)
            local track_number = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER")
            if track_number == prev_track_number then goto continue end
            local second_track = GetTrack(0, track_number)
            local third_track = GetTrack(0, track_number + 1)
            DeleteTrack(second_track)
            DeleteTrack(third_track)
            prev_track_number = track_number
            ::continue::
        end

        for _, take in pairs(takes) do
            SetMediaItemTakeInfo_Value(take, "I_CHANMODE", 67)
        end

        for _, item in pairs(items) do
            SetMediaItemInfo_Value(item, "B_MUTE_ACTUAL", 0)
        end
    else
        for _, item in pairs(items) do
            local item_track = GetMediaItemTrack(item)
            DeleteTrackMediaItem(item_track, item)
        end
    end
    Main_OnCommand(40769, 0) -- unselect all items

    add_rcmaster()
    local updated_folders = folder_check()
    local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
    local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")

    if updated_folders == 1 then -- run F7
        Main_OnCommand(F7_sync, 0)
    else                         -- run F8
        Main_OnCommand(F8_sync, 0)
    end

    local mixer_tracks = create_mixer_table()
    show_track_name_dialog(mixer_tracks)

    if updated_folders == 1 then -- run F7
        Main_OnCommand(F7_sync, 0)
    else                         -- run F8
        Main_OnCommand(F8_sync, 0)
    end

    Undo_EndBlock("Explode multi-channel audio", 0)
end

---------------------------------------------------------------------

function folder_check()
    local folders = 0
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        end
    end
    return folders
end

---------------------------------------------------------------------

function show_track_name_dialog(mixer_tracks)
    local max_inputs_per_dialog = 8
    local success = true
    local track_names = {}

    -- Loop to handle all tracks in chunks
    for start_track = 1, #mixer_tracks, max_inputs_per_dialog do
        local end_track = math.min(start_track + max_inputs_per_dialog - 1, #mixer_tracks)
        local input_string = ""

        for i = start_track, end_track do
            input_string = input_string .. "Track " .. i .. " :,"
        end

        local ret, input = GetUserInputs("Enter Track Names " .. start_track .. "-" .. end_track,
            end_track - start_track + 1,
            input_string .. ",extrawidth=100", "")
        if not ret then
            return false
        end

        local inputs_track_table = {}
        for input_value in string.gmatch(input, "[^,]+") do
            table.insert(inputs_track_table, input_value:match("^%s*(.-)%s*$"))
        end

        for i = 1, #inputs_track_table do
            track_names[start_track + i - 1] = inputs_track_table[i]
        end
    end

    for i, track in ipairs(mixer_tracks) do
        if track then
            local ret = GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. (track_names[i] or ""), true)
            if not ret then
                success = false
            end
        else
            success = false
        end
    end

    return success
end

---------------------------------------------------------------------

function add_rcmaster()
    local num_of_tracks = CountTracks(0)
    InsertTrackAtIndex(num_of_tracks, true) -- add RCMASTER
    local rcmaster = GetTrack(0, num_of_tracks)
    GetSetMediaTrackInfo_String(rcmaster, "P_EXT:rcmaster", "y", 1)
    GetSetMediaTrackInfo_String(rcmaster, "P_NAME", "RCMASTER", 1)
    return rcmaster
end

---------------------------------------------------------------------

function create_mixer_table()
    local num_of_tracks = CountTracks(0)
    local mixer_tracks = {}
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", 0)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", 0)
        if mixer_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", 1)
            local mod_name = string.match(name, "M?:?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. mod_name, 1)
            table.insert(mixer_tracks, track)
        end
    end
    return mixer_tracks
end

---------------------------------------------------------------------

main()
