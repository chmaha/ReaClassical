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

local main, display_prefs, load_prefs, save_prefs, pref_check

local year = os.date("%Y")
local default_values = '35,200,3,7,0,500,0,0,0.75,' .. year .. ',WAV,0'
local NUM_OF_ENTRIES = select(2, default_values:gsub(",", ",")) + 1
local labels = {
    'S-D Crossfade length (ms)',
    'CD track offset (ms)',
    'INDEX0 length (s) (>= 1)',
    'Album lead-out time (s)',
    'Prepare Takes: Random colors',
    'S-D Marker Check (ms)',
    'REF = Overdub Guide',
    'Add S-D Markers at Mouse Hover',
    'Alt Audition Playback Rate',
    'Year of Production',
    'CUE audio format',
    'Floating Destination Group'
}

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local pass
    local input
    repeat
        local ret
        ret, input = display_prefs()
        if not ret then return end
        if ret then pass = pref_check(input) end
    until pass

    save_prefs(input)
end

-----------------------------------------------------------------------

function display_prefs()
    local saved = load_prefs(NUM_OF_ENTRIES)
    local input_labels = table.concat(labels, ',')
    local ret, input = GetUserInputs('ReaClassical Project Preferences', NUM_OF_ENTRIES, input_labels, saved)
    return ret, input
end

-----------------------------------------------------------------------

function load_prefs()
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
    if saved == "" then return default_values end

    local saved_entries = {}

    for entry in saved:gmatch('([^,]+)') do
        saved_entries[#saved_entries + 1] = entry
    end

    if #saved_entries < NUM_OF_ENTRIES then
        local i = 1
        for entry in default_values:gmatch("([^,]+)") do
            if i == #saved_entries + 1 then
                saved_entries[i] = entry
            end
            i = i + 1
        end
    elseif #saved_entries > NUM_OF_ENTRIES then
        local j = 1
        for entry in default_values:gmatch("([^,]+)") do
            saved_entries[j] = entry
            j = j + 1
        end
    end

    saved = table.concat(saved_entries, ',')

    return saved
end

-----------------------------------------------------------------------

function save_prefs(input)
    SetProjExtState(0, "ReaClassical", "Preferences", input)
end

-----------------------------------------------------------------------

function pref_check(input)
    local pass = true
    local table = {}
    local invalid_msg = ""
    local i = 0
    for entry in input:gmatch("([^,]*)") do
        i = i + 1
        table[i] = entry
        if entry == "" or (i ~= 11 and (tonumber(entry) == nil or tonumber(entry) < 0)) then
            pass = false
            invalid_msg = "Entries should not be strings or left empty."
        end
    end

    local binary_error_msg = ""
    local ext_error_msg = ""

    if #table == NUM_OF_ENTRIES then
        local num_5 = tonumber(table[5])
        local num_7 = tonumber(table[7])
        local num_8 = tonumber(table[8])
        local num_12 = tonumber(table[12])
        local audio_format = tostring(table[11])
        if (num_5 and num_5 > 1) or (num_7 and num_7 > 1) or (num_8 and num_8 > 1) or (num_12 and num_12 > 1) then
            binary_error_msg = "Binary option entries must be set to 0 or 1.\n"
            pass = false
        end
        local valid_formats = { WAV = true, FLAC = true, MP3 = true, AIFF = true }
        if not valid_formats[audio_format] then
            ext_error_msg = "CUE audio format should be set to WAV, FLAC, AIFF or MP3."
            pass = false
        end
    end

    local error_msg = binary_error_msg .. invalid_msg .. ext_error_msg

    if not pass then
        MB(error_msg, "Error", 0)
    end

    return pass
end

-----------------------------------------------------------------------

main()
