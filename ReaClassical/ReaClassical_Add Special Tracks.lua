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

local main, display_prefs, pref_check, create_mixer_table, sync_based_on_workflow

local starting_values = '0,0,0,0,1'
local NUM_OF_ENTRIES = select(2, starting_values:gsub(",", ",")) + 1
local labels = {
    'Aux',
    'Submix',
    'Room Tone',
    'Reference',
    'Maintain Mixer => RCMASTER?'
}

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local pass, table
    local input
    repeat
        local ret
        ret, input = display_prefs()
        if not ret then return end
        if ret then pass, table = pref_check(input) end
    until pass

    -- Add special tracks
    local add_aux = NamedCommandLookup("_RS1938b67a195fd37423806f2647e26c3c212ce111")
    local add_submix = NamedCommandLookup("_RSdbfe4281d2bd56a7afc1c5e3967219c9f1c2095c")
    local add_roomtone = NamedCommandLookup("_RS3798d5ce6052ef404cd99dacf481f2befed4eacc")
    local add_ref = NamedCommandLookup("_RS00c2ccc67c644739aa15a0c93eea2c755554b30d")
    local aux_num = tonumber(table[1])
    local submix_num = tonumber(table[2])
    local roomtone_num = tonumber(table[3])
    local ref_num = tonumber(table[4])
    local mixer_connections = tonumber(table[5])

    PreventUIRefresh(1)
    if aux_num > 0 then
        for _ = 1, aux_num do
            Main_OnCommand(add_aux, 0)
        end
    end

    if submix_num > 0 then
        for _ = 1, submix_num do
            Main_OnCommand(add_submix, 0)
        end
    end

    if roomtone_num == 1 then
        Main_OnCommand(add_roomtone, 0)
    end

    if ref_num > 0 then
        for _ = 1, ref_num do
            Main_OnCommand(add_ref, 0)
        end
    end

    if mixer_connections == 0 then
        local mixer_table = create_mixer_table()

        for _, track in ipairs(mixer_table) do
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if not track_name:match("-$") then
                GetSetMediaTrackInfo_String(track, "P_NAME", track_name .. "-", true)
            end
        end

        -- run F7 or F8 sync
        sync_based_on_workflow(workflow)
    end
    PreventUIRefresh(-1)
    Undo_EndBlock("Add Special Tracks", 0)
end

-----------------------------------------------------------------------

function display_prefs()
    local input_labels = table.concat(labels, ',')
    local ret, input = GetUserInputs('Add Special Tracks', NUM_OF_ENTRIES, input_labels, starting_values)
    return ret, input
end

-----------------------------------------------------------------------

function pref_check(input)
    local pass = true
    local table = {}
    local invalid_err = ""
    for entry in input:gmatch('([^,]*)') do
        table[#table + 1] = entry
        if entry == "" or tonumber(entry) == nil or tonumber(entry) < 0 then
            pass = false
            invalid_err = "Entries should not be strings or left empty."
        end
    end

    local roomtone_err = ""
    local connection_err = ""
    -- separate check for binary options
    if #table == NUM_OF_ENTRIES then
        local num_3 = tonumber(table[3])
        local num_5 = tonumber(table[5])
        if (num_3 and num_3 > 1) then
            roomtone_err = "You can only add one room tone track per project.\n"
            pass = false
        end
        if (num_5 and num_5 > 1) then
            connection_err = "Set \"Mixer Tracks to RCMASTER?\" = 0 to disconnect for custom routing.\n"
            pass = false
        end
    end

    local error_msg = roomtone_err .. connection_err .. invalid_err

    if not pass then
        MB(error_msg, "Error", 0)
    end

    return pass, table
end

-----------------------------------------------------------------------

function create_mixer_table()
    local num_of_tracks = CountTracks(0)
    local mixer_tracks = {}
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if mixer_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", true)
            local mod_name = string.match(name, "M?:?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. mod_name, true)
            table.insert(mixer_tracks, track)
        end
    end
    return mixer_tracks
end

-----------------------------------------------------------------------

function sync_based_on_workflow(workflow)
    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    elseif workflow == "Horizontal" then
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end
end

-----------------------------------------------------------------------


main()
