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
You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, trim_prefix, folder_check, trackname_check, assign_input

local pair_words = {
    "2ch", "pair", "paire", "paar", "coppia", "par", "пара", "对", "ペア",
     "쌍", "زوج", "pari", "пар", "πάρoς", "двойка", "קבוצה", "çift",
     "pár", "pāris", "pora", "jozi", "जोड़ी", "คู่", "pasang", "cặp",
     "stereo", "stéréo", "estéreo", "立体声", "ステレオ", "스테레오", 
     "ستيريو", "στερεοφωνικός", "סטריאו", "stereotipas", "स्टीरियो", 
     "สเตอริโอ", "âm thanh nổi"
 } 
 

---------------------------------------------------------------------
local MAX_INPUTS = GetNumAudioInputs() -- Retrieve hardware inputs

function main()
    local num_tracks = CountTracks(0)
    if num_tracks == 0 then
        MB("Set up your ReaClassical project via F7 or F8 first!", "Auto Set Recording Inputs", 0)
        return
    end

    local input_channel = 0
    local track_index = 0

    local tracks_per_group = folder_check()

    local no_input_tracks = {}
    local previous_inputs = {}
    while track_index < tracks_per_group do
        local track = GetTrack(0, track_index)
        local current_input = GetMediaTrackInfo_Value(track, "I_RECINPUT")
        previous_inputs[track_index + 1] = current_input
        track_index = track_index + 1
    end

    track_index = 0
    local assignments = {}

    while track_index < tracks_per_group do
        local track = GetTrack(0, track_index)
        local _, track_name = GetTrackName(track)

        track_name = trim_prefix(track_name)

        local is_pair = false
        for _, word in ipairs(pair_words) do
            if track_name:lower():find(word) then
                is_pair = true
                break
            end
        end

        if input_channel < MAX_INPUTS then
            new_input_channel = assign_input(track, is_pair, input_channel)
            if new_input_channel then
                input_channel = new_input_channel
                local channel_info = is_pair and string.format("%d/%d", input_channel - 1, input_channel) or
                    string.format("%d", input_channel)
                local channel_type = is_pair and "(stereo)" or "(mono)"

                assignments[#assignments + 1] = string.format("%s: %s %s", channel_info, track_name, channel_type)
            end
        else
            if input_channel < tracks_per_group then
                -- Beyond max hardware inputs, set input to none
                SetMediaTrackInfo_Value(track, "I_RECINPUT", -1)
                no_input_tracks[#no_input_tracks + 1] = track_name
            end
        end

        track_index = track_index + 1
    end

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local assignment_message
    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
        assignment_message = "New Recording Inputs (synced across all folders):\n\n" .. table.concat(assignments, "\n")
    else
        assignment_message = "New Recording Inputs:\n\n" .. table.concat(assignments, "\n")
    end

    if #no_input_tracks > 0 then
        assignment_message = assignment_message .. "\n\nNon-Recording Tracks:\n\n" .. table.concat(no_input_tracks, "\n")
    end

    assignment_message = "Number of Hardware Inputs: " .. MAX_INPUTS .. "\n\n" .. assignment_message

    local user_response = ShowMessageBox(
        assignment_message .. "\n\nKeep these settings?\n(Answering \"No\" will revert to previous assignments)",
        "Auto Set Recording Inputs", 4)

    if user_response == 7 then
        -- Revert to previous inputs
        for i, track in ipairs(previous_inputs) do
            local revert_track = GetTrack(0, i - 1)
            SetMediaTrackInfo_Value(revert_track, "I_RECINPUT", track)
        end
    end
end

---------------------------------------------------------------------

function trim_prefix(track_name)
    return (track_name:match("^%s*D:%s*(.*)%s*$") or track_name:match("^%s*(.-)%s*$"))
end

---------------------------------------------------------------------

function folder_check()
    local folders = 0
    local tracks_per_group = 1
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local mix = trackname_check(track, "^M:")
        local rcm = trackname_check(track, "^RCMASTER")
        local send = trackname_check(track, "^@")
        local bus = trackname_check(track, "^#")
        local rt = trackname_check(track, "^RoomTone")
        local ref = trackname_check(track, "^REF")
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        elseif folders == 1 and not (mix or rcm or send or bus or rt or ref) then
            tracks_per_group = tracks_per_group + 1
        end
    end
    return tracks_per_group
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function assign_input(track, is_pair, input_channel)
    if is_pair and (input_channel + 1 < MAX_INPUTS) then
        -- Assign stereo input
        SetMediaTrackInfo_Value(track, "I_RECINPUT", 1024 + input_channel)
        return input_channel + 2
    elseif is_pair then
        return nil -- Indicate an error
    else
        -- Assign mono input
        SetMediaTrackInfo_Value(track, "I_RECINPUT", input_channel)
        return input_channel + 1
    end
end

---------------------------------------------------------------------

main()