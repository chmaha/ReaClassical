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

local main, folder_check, show_track_name_dialog, add_rcmaster
local create_mixer_table, check_channel_count

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "" then
        MB("Please use this function in a vanilla REAPER project.\n" ..
            "You can either import your media on one regular track for horizontal editing " ..
            "or on multiple regular tracks for a vertical workflow.\n" ..
            "The function will automatically create the required folder group(s) " ..
            "and convert the project for use in ReaClassical."
            , "ReaClassical Error", 0)
        return
    end

    local folders = folder_check()
    local num_of_items = CountMediaItems(0)

    local error_message = "Error: You can either import your media on one regular track for horizontal editing " ..
        "or on multiple regular tracks for a vertical workflow.\n" ..
        "The function will automatically create the required folder group(s).\n" ..
        "To explode multi-channel after editing has started, " ..
        "please use on an empty project tab and copy across."

    if folders > 0 or num_of_items == 0 then
        MB(error_message, "Explode Multi-Channel", 0)
        return
    end

    -- if num_of_items == 0 then
    --     MB(error_message, "Explode Multi-Channel", 0)
    --     return
    -- end

    -- if num_of_items == 0 then return false end

    local return_code, channel_count = check_channel_count(num_of_items)
    if return_code == -2 then
        MB("Error! The item channel counts don't match!", "Explode Multi-Channel", 0)
        return
    elseif return_code == -1 then
        MB("Error! The minimum channel count is 3 or more", "Explode Multi-Channel", 0)
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
        "Explode Multi-channel", 4)

    if int == 6 then
        local prev_track_number
        for _, item in pairs(items) do
            local item_track = GetMediaItem_Track(item)
            local track_number = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER")
            if track_number == prev_track_number then goto continue end
            local second_track = GetTrack(0, track_number)
            local third_track = GetTrack(0, track_number + 1)
            if channel_count == 2 then
                if GetMediaTrackInfo_Value(item_track, "I_FOLDERDEPTH") == 1 then
                    InsertTrackAtIndex(track_number + 2, true)
                    local new_track = GetTrack(0, track_number + 2)
                    SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", -1)
                end
            end
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

        for i = CountTracks(0) - 1, 0, -1 do
            local track = GetTrack(0, i)
            if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                local second_track = GetTrack(0, i + 1)
                if second_track then
                    DeleteTrack(track)
                    SetMediaTrackInfo_Value(second_track, "I_FOLDERDEPTH", 1)
                end
            end
        end
    end

    Main_OnCommand(40769, 0)    -- unselect all items
    PreventUIRefresh(1)
    Main_OnCommand(40296, 0)    -- select all tracks
    local collapse = NamedCommandLookup("_SWS_COLLAPSE")
    Main_OnCommand(collapse, 0) -- collapse all tracks
    Main_OnCommand(40939, 0)    -- select track 1
    local show = NamedCommandLookup("_SWS_FOLDSMALL")
    Main_OnCommand(show, 0)     -- show child tracks

    add_rcmaster()
    local updated_folders = folder_check()
    local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
    local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")

    if updated_folders == 1 then -- run F7
        Main_OnCommand(F7_sync, 0)
    else                         -- run F8
        Main_OnCommand(F8_sync, 0)
    end

    if int == 6 and channel_count == 2 then
        MB("The interleaved stereo has been placed on the folder track.\n" ..
            "Leave the empty child track in place so that ReaClassical can function as intended.",
            "Explode Multi-channel", 0)
    end

    local mixer_tracks = create_mixer_table()
    show_track_name_dialog(mixer_tracks)
    
    PreventUIRefresh(-1)
    local response = MB("Would you like to add any special tracks (aux, submix, room tone, reference)?",
        "Explode Multi-Channel", 4)
    if response == 6 then
        local add_special_tracks = NamedCommandLookup("_RS9c0fa5c1aae86bf8559df83dd6516c0aa35e264f")
        Main_OnCommand(add_special_tracks, 0)
    end


    if updated_folders == 1 then -- run F7 again
        Main_OnCommand(F7_sync, 0)
    else                         -- run F8 again
        Main_OnCommand(F8_sync, 0)
    end

    
    local fit_project_vertically = NamedCommandLookup("_RS444f747139500db030a1c4e03b8a0805ac502dfe")
    Main_OnCommand(fit_project_vertically, 0)
    
    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)
    
    Undo_EndBlock("Explode Multi-channel", 0)
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

function check_channel_count(num_of_items)
    local first_item = GetMediaItem(0, 0)
    local first_take = GetMediaItemTake(first_item, 0)
    local first_source = GetMediaItemTake_Source(first_take)
    local first_channel_count = GetMediaSourceNumChannels(first_source)
    if first_channel_count < 2 then return -1 end
    for i = 1, num_of_items - 1, 1 do
        local item = GetMediaItem(0, i)
        local take = GetMediaItemTake(item, 0)
        local source = GetMediaItemTake_Source(take)
        local channel_count = GetMediaSourceNumChannels(source)
        if channel_count ~= first_channel_count then return -2 end
    end
    return 0, first_channel_count
end

---------------------------------------------------------------------

main()
