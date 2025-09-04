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
local main, assign_input, parse_input_pan, create_mixer_table
local get_current_input_pan

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

local MAX_INPUTS = GetNumAudioInputs()
local TRACKS_PER_PAGE = 16

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local mixer_table = create_mixer_table()
    if #mixer_table == 0 then
        MB("No mixer tracks found.", "Error", 0)
        return
    end

    Undo_BeginBlock()

    -- Save previous settings for potential revert
    local previous_settings = {}
    for i = 0, #mixer_table - 1 do
        local input_track = GetTrack(0, i)
        local mixer_track = mixer_table[i + 1]
        previous_settings[i + 1] = {
            input = GetMediaTrackInfo_Value(input_track, "I_RECINPUT"),
            pan = GetMediaTrackInfo_Value(mixer_track, "D_PAN")
        }
    end

    local success = true
    for start_idx = 0, #mixer_table - 1, TRACKS_PER_PAGE do
        local end_idx = math.min(start_idx + TRACKS_PER_PAGE - 1, #mixer_table - 1)
        local labels, defaults = {}, {}
        for i = start_idx, end_idx do
            local input_track = GetTrack(0, i)
            local mixer_track = mixer_table[i + 1]
            local _, name = GetTrackName(mixer_track)
            name = name:gsub("^M:?", "")
            labels[#labels + 1] = (i + 1) .. ": " .. name
            defaults[#defaults + 1] = get_current_input_pan(input_track, mixer_track)
        end

        local ret, input = GetUserInputs(
            string.format("Tracks %d-%d: input:pan", start_idx + 1, end_idx + 1),
            #labels,
            table.concat(labels, ","),
            table.concat(defaults, ",")
        )

        if not ret then
            success = false
            break
        end

        local entries = {}
        for val in input:gmatch("[^,]+") do
            entries[#entries + 1] = val:match("^%s*(.-)%s*$")
        end

        for idx, entry in ipairs(entries) do
            local track_idx = start_idx + idx - 1
            local input_track = GetTrack(0, track_idx)
            local mixer_track = mixer_table[track_idx + 1]

            local recInput, panVal, err = parse_input_pan(entry)
            if err then
                MB("Track " .. (track_idx + 1) .. ": " .. err, "Input Error", 0)
                success = false
                break
            end

            local is_pair = false
            if recInput >= 1024 then
                is_pair = true
                recInput = recInput - 1024
            end

            local new_input = assign_input(input_track, is_pair, recInput)
            if not new_input and is_pair then
                MB("Cannot assign stereo input for track " .. (track_idx + 1), "Input Error", 0)
                success = false
                break
            end

            SetMediaTrackInfo_Value(mixer_track, "D_PAN", panVal)
        end

        if not success then break end
    end

    if not success then
        -- revert if cancelled or error
        for i = 0, #mixer_table - 1 do
            local input_track = GetTrack(0, i)
            local mixer_track = mixer_table[i + 1]
            SetMediaTrackInfo_Value(input_track, "I_RECINPUT", previous_settings[i + 1].input)
            SetMediaTrackInfo_Value(mixer_track, "D_PAN", previous_settings[i + 1].pan)
        end
    end

    Undo_EndBlock('Recording Input and Panning', 0)
end

---------------------------------------------------------------------

function assign_input(track, is_pair, input_channel)
    if is_pair and (input_channel + 1 < MAX_INPUTS) then
        SetMediaTrackInfo_Value(track, "I_RECINPUT", 1024 + input_channel)
        return input_channel + 2
    elseif is_pair then
        return nil
    else
        SetMediaTrackInfo_Value(track, "I_RECINPUT", input_channel)
        return input_channel + 1
    end
end

---------------------------------------------------------------------

function parse_input_pan(entry)
    if not entry or entry:match("^%s*$") then
        return nil, nil, "Empty input not allowed"
    end

    local inputPart, panPart = entry:match("([^:]+):(.+)")
    if not inputPart or not panPart then
        return nil, nil, "Invalid format. Use input:pan (e.g. 1:50L, 3/4:C, N:C)"
    end

    inputPart = inputPart:upper()
    panPart = panPart:upper()

    local recInput
    if inputPart == "N" then
        recInput = -1
    else
        -- Handle mono or stereo (accept decimals)
        local inputStart, inputEnd = inputPart:match("([%d%.]+)%s*/%s*([%d%.]+)")
        if inputStart then
            inputStart = math.floor(tonumber(inputStart))
            inputEnd = math.floor(tonumber(inputEnd))
        else
            inputStart = math.floor(tonumber(inputPart))
            inputEnd = inputStart
        end

        if not inputStart or inputStart < 1 or inputEnd < 1 then
            return nil, nil, "Invalid input number"
        end
        if inputStart > MAX_INPUTS or inputEnd > MAX_INPUTS then
            return nil, nil, "Input number exceeds available hardware inputs"
        end

        if inputStart == inputEnd then
            recInput = inputStart - 1
        else
            recInput = 1024 + (inputStart - 1)
        end
    end

    local panVal
    if panPart == "C" then
        panVal = 0
    elseif panPart:match("^(%d+)([LR])$") then
        local amt, side = panPart:match("^(%d+)([LR])$")
        amt = tonumber(amt)
        if amt < 0 or amt > 100 then
            return nil, nil, "Pan percentage must be 0–100"
        end
        panVal = (side == "L") and -amt / 100 or amt / 100
    else
        return nil, nil, "Pan must be C, L, or R"
    end

    return recInput, panVal, nil
end

---------------------------------------------------------------------

function create_mixer_table()
    local mixer_tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            table.insert(mixer_tracks, track)
        end
    end
    return mixer_tracks
end

---------------------------------------------------------------------

function get_current_input_pan(input_track, mixer_track)
    local recInput = GetMediaTrackInfo_Value(input_track, "I_RECINPUT")
    local panVal = GetMediaTrackInfo_Value(mixer_track, "D_PAN")
    local inputStr

    if recInput < 0 then
        inputStr = "N"
    elseif recInput >= 1024 then
        local ch = recInput - 1024
        inputStr = tostring(math.floor(ch + 1)) .. "/" .. tostring(math.floor(ch + 2))
    else
        inputStr = tostring(math.floor(recInput + 1))
    end

    local panStr
    if math.abs(panVal) < 0.01 then
        panStr = "C"
    elseif panVal < 0 then
        panStr = tostring(math.floor(-panVal * 100 + 0.5)) .. "L"
    else
        panStr = tostring(math.floor(panVal * 100 + 0.5)) .. "R"
    end

    return inputStr .. ":" .. panStr
end

---------------------------------------------------------------------

main()
