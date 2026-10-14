--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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

local main, display_prefs, load_prefs, save_prefs, pref_check

local default_values = '35,5,5'
local NUM_OF_ENTRIES = select(2, default_values:gsub(",", ",")) + 1
local labels = {
    'S-D Crossfade length (ms)',
    'XFM nudge (ms)',
    'XFM x modifier multiplier'
}

function main()
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

function display_prefs()
    local saved = load_prefs(NUM_OF_ENTRIES)
    local input_labels = table.concat(labels, ',')
    local ret, input = GetUserInputs('ReaEdit Preferences', NUM_OF_ENTRIES, input_labels, saved)
    return ret, input
end

function load_prefs()
    local _, saved = GetProjExtState(0, "ReaEdit", "Preferences")
    if saved == "" then return default_values end

    local saved_entries = {}

    for entry in saved:gmatch('([^,]+)') do
        saved_entries[#saved_entries + 1] = entry
    end

    if #saved_entries > NUM_OF_ENTRIES and saved_entries[1] then
        saved_entries = { saved_entries[1] }
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

function save_prefs(input)
    SetProjExtState(0, "ReaEdit", "Preferences", input)
end

function pref_check(input)
    local pass = true
    local table = {}
    local invalid_msg = ""
    for entry in input:gmatch('([^,]*)') do
        table[#table + 1] = entry
        if entry == "" or tonumber(entry) == nil or tonumber(entry) < 0 then
            pass = false
            invalid_msg = "Entries should not be strings or left empty."
        end
    end

    local count_error_msg = ""
    if #table ~= NUM_OF_ENTRIES then
        count_error_msg = "Please enter three numbers.\n"
        pass = false
    end

    local error_msg = count_error_msg .. invalid_msg

    if not pass then
        MB(error_msg, "Error", 0)
    end

    return pass
end

main()
