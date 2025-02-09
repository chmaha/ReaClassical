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
You should have received a copy of the GNU General Public License along with this program.
If not, see <https://www.gnu.org/licenses/>.
]]

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, trim_prefix, assign_input, create_mixer_table

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
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local num_tracks = CountTracks(0)
    if num_tracks == 0 then
        MB("Set up your ReaClassical project via F7 or F8 first!", "Auto Set Recording Inputs", 0)
        return
    end

    local input_channel = 0
    local track_index = 0

    local mixer_table = create_mixer_table()

    local no_input_tracks = {}
    local previous_inputs = {}
    while track_index < #mixer_table do
        local track = GetTrack(0, track_index)
        local current_input = GetMediaTrackInfo_Value(track, "I_RECINPUT")
        previous_inputs[track_index + 1] = current_input
        track_index = track_index + 1
    end

    track_index = 1
    local assignments = {}

    while track_index <= #mixer_table do
        local mixer_track = mixer_table[track_index]
        local _, mixer_trackname = GetTrackName(mixer_track)

        mixer_trackname = trim_prefix(mixer_trackname)

        local is_pair = false
        for _, word in ipairs(pair_words) do
            if mixer_trackname:lower():find(word) then
                is_pair = true
                break
            end
        end

        local input_track = GetTrack(0, track_index - 1)

        if input_channel < MAX_INPUTS then
            local new_input_channel = assign_input(input_track, is_pair, input_channel)
            if new_input_channel then
                input_channel = new_input_channel
                local channel_info = is_pair and string.format("%d/%d", input_channel - 1, input_channel) or
                    string.format("%d", input_channel)
                local channel_type = is_pair and "(stereo)" or "(mono)"

                assignments[#assignments + 1] = string.format("%s: %s %s", channel_info, mixer_trackname, channel_type)
            end
        else
            if input_channel < #mixer_table then
                -- Beyond max hardware inputs, set input to none
                SetMediaTrackInfo_Value(input_track, "I_RECINPUT", -1)
                no_input_tracks[#no_input_tracks + 1] = mixer_trackname
            end
        end

        track_index = track_index + 1
    end

    local assignment_message
    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
        assignment_message = "New Recording Inputs (synced across all folders):\n\n" ..
            table.concat(assignments, "\n")
    else
        assignment_message = "New Recording Inputs:\n\n" .. table.concat(assignments, "\n")
    end

    if #no_input_tracks > 0 then
        assignment_message = assignment_message .. "\n\nNon-Recording Tracks:\n\n" ..
            table.concat(no_input_tracks, "\n")
    end

    assignment_message = "Number of Hardware Inputs: " .. MAX_INPUTS .. "\n\n" .. assignment_message

    local user_response = MB(
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

function trim_prefix(mixer_trackname)
    return mixer_trackname:match("^%s*M?:?%s*(.-)%s*%-?$")
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
