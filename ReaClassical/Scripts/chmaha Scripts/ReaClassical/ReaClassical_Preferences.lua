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
local sync_based_on_workflow, move_destination_folder_to_top
local prepare_takes

-- Check for ReaImGui
local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local year = os.date("%Y")
local default_values = '35,200,3,7,0,500,0,0,0.75,' .. year .. ',WAV,0,0'
local NUM_OF_ENTRIES = select(2, default_values:gsub(",", ",")) + 1
local labels = {
    'S-D Crossfade length (ms)',
    'CD track offset (ms)',
    'INDEX0 length (s) (>= 1)',
    'Album lead-out time (s)',
    'Unedited Items = Default Color',
    'S-D Marker Check (ms)',
    'REF = Overdub Guide',
    'Add S-D Markers at Mouse Hover',
    'Alt Audition Playback Rate',
    'Year of Production',
    'CUE audio format',
    'Floating Destination Folder',
    'Find takes using item names'
}

-- Binary option indices (1-based)
local binary_options = {5, 7, 8, 12, 13}

-- ImGui Context
local ctx = ImGui.CreateContext('ReaClassical Preferences')
local visible = true
local open = true
local apply_clicked = false
local prefs = {}
local error_message = "" -- Store validation error message

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end
    
    -- Load preferences into table on first run
    if not prefs[1] then
        load_prefs()
    end
    
    -- Run ImGui display
    display_prefs()
    
    if apply_clicked then
        -- Validate and save
        local pass, corrected_prefs, new_floating, new_color, error_msg = pref_check()
        
        if pass then
            -- Get original saved values before applying changes
            local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
            local saved_entries = {}
            if saved ~= "" then
                for entry in saved:gmatch('([^,]+)') do
                    saved_entries[#saved_entries + 1] = entry
                end
            end
            local orig_floating = tonumber(saved_entries[12]) or 0
            local orig_color = tonumber(saved_entries[5]) or 0
            
            save_prefs(corrected_prefs)
            
            if new_floating ~= orig_floating and new_floating == 0 then
                move_destination_folder_to_top()
                sync_based_on_workflow(workflow)
            elseif new_floating ~= orig_floating and new_floating == 1 then
                MB("When the floating destination folder is active, " ..
                    "DEST-IN and DEST-OUT markers are always associated with the \"D:\" folder.", "ReaClassical", 0)
            end
            if new_color ~= orig_color then
                prepare_takes()
            end
            open = false -- Close window on success
            return -- Exit after applying
        else
            -- Validation failed, revert to last saved values and show error
            error_message = error_msg or "Invalid input detected."
            load_prefs() -- Reload the last valid values
            apply_clicked = false
            -- Window stays open
        end
    end
    
    if open and visible then
        defer(main)
    end
end

-----------------------------------------------------------------------

function display_prefs()
    -- Auto-resize window to fit content
    local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize
    
    visible, open = ImGui.Begin(ctx, 'ReaClassical Project Preferences', true, window_flags)
    
    if not visible then
        ImGui.End(ctx)
        return
    end
    
    -- Create table for aligned layout
    if ImGui.BeginTable(ctx, "prefs_table", 2, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg) then
        ImGui.TableSetupColumn(ctx, "labels", ImGui.TableColumnFlags_WidthFixed, 280)
        ImGui.TableSetupColumn(ctx, "inputs", ImGui.TableColumnFlags_WidthFixed, 80)
        
        for i = 1, #labels do
            ImGui.TableNextRow(ctx)
            ImGui.TableSetColumnIndex(ctx, 0)
            ImGui.AlignTextToFramePadding(ctx)
            ImGui.Text(ctx, labels[i] .. ":")
            ImGui.TableSetColumnIndex(ctx, 1)
            
            -- Ensure prefs[i] exists
            if not prefs[i] then
                prefs[i] = 0
            end
            
            -- Check if this is a binary option (checkbox)
            local is_binary = false
            for _, idx in ipairs(binary_options) do
                if idx == i then
                    is_binary = true
                    break
                end
            end
            
            if is_binary then
                -- Checkbox for binary options
                local checked = (tonumber(prefs[i]) == 1)
                local rv, val = ImGui.Checkbox(ctx, "##pref" .. i, checked)
                if rv then
                    prefs[i] = val and 1 or 0
                end
            elseif i == 11 then
                -- CUE audio format - dropdown
                ImGui.SetNextItemWidth(ctx, 80)
                if ImGui.BeginCombo(ctx, "##pref" .. i, tostring(prefs[i])) then
                    local formats = {"WAV", "FLAC", "AIFF", "MP3"}
                    for _, format in ipairs(formats) do
                        local is_selected = (prefs[i] == format)
                        if ImGui.Selectable(ctx, format, is_selected) then
                            prefs[i] = format
                        end
                        if is_selected then
                            ImGui.SetItemDefaultFocus(ctx)
                        end
                    end
                    ImGui.EndCombo(ctx)
                end
            else
                -- Numeric input using InputText (no +/- buttons)
                ImGui.SetNextItemWidth(ctx, 60)
                local rv, val = ImGui.InputText(ctx, "##pref" .. i, tostring(prefs[i]))
                if rv then
                    -- Store the value as-is, validation happens on Apply
                    prefs[i] = val
                end
            end
        end
        
        ImGui.EndTable(ctx)
    end
    
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)
    
    -- Display error message if validation failed
    if error_message ~= "" then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF3333FF) -- Red text (RGBA)
        ImGui.TextWrapped(ctx, error_message)
        ImGui.PopStyleColor(ctx)
        ImGui.Spacing(ctx)
    end
    
    -- Buttons
    if ImGui.Button(ctx, "Apply", 120, 0) then
        error_message = "" -- Clear any previous error
        apply_clicked = true
        -- Don't set open = false here, let validation decide
    end
    
    ImGui.SameLine(ctx)
    
    if ImGui.Button(ctx, "Cancel", 120, 0) then
        open = false
    end
    
    ImGui.End(ctx)
end

-----------------------------------------------------------------------

function load_prefs()
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
    if saved == "" then saved = default_values end

    local saved_entries = {}

    for entry in saved:gmatch('([^,]+)') do
        saved_entries[#saved_entries + 1] = entry
    end

    if #saved_entries < #labels then
        local i = 1
        for entry in default_values:gmatch("([^,]+)") do
            if i == #saved_entries + 1 then
                saved_entries[i] = entry
            end
            i = i + 1
        end
    elseif #saved_entries > #labels then
        local j = 1
        for entry in default_values:gmatch("([^,]+)") do
            saved_entries[j] = entry
            j = j + 1
        end
    end
    
    -- Load into prefs table
    for i = 1, #labels do
        if i == 11 then
            prefs[i] = saved_entries[i] or "WAV"
        else
            prefs[i] = tonumber(saved_entries[i]) or 0
        end
    end
end

-----------------------------------------------------------------------

function save_prefs(corrected_prefs)
    -- Convert table back to comma-separated string
    local values = {}
    for i = 1, #labels do
        values[i] = tostring(corrected_prefs[i])
    end
    local input = table.concat(values, ',')
    SetProjExtState(0, "ReaClassical", "Preferences", input)
end

-----------------------------------------------------------------------

function pref_check()
    local pass = true
    local t = {}
    local invalid_msg = ""

    -- Copy prefs to t
    for i = 1, #labels do
        t[i] = prefs[i]
    end

    -- Validate entries
    for i = 1, #labels do
        if i == 11 then
            -- Audio format - string validation
            t[i] = tostring(t[i]):upper()
        else
            -- Numeric validation
            local num = tonumber(t[i])
            if num == nil then
                pass = false
                invalid_msg = "Numeric entries must be valid numbers.\n"
                break
            elseif num < 0 then
                pass = false
                invalid_msg = "Numeric entries should not be negative.\n"
                break
            elseif i == 3 and num < 1 then
                pass = false
                invalid_msg = "INDEX0 length must be greater than or equal to 1.\n"
                break
            elseif i ~= 9 and num ~= math.floor(num) then
                -- All fields except #9 (Alt Audition Playback Rate) must be integers
                pass = false
                invalid_msg = "Numeric entries (except Alt Audition Rate) must be integers.\n"
                break
            end
        end
    end

    local binary_error_msg = ""
    local ext_error_msg = ""

    if pass then
        local num_5  = tonumber(t[5])
        local num_7  = tonumber(t[7])
        local num_8  = tonumber(t[8])
        local num_12 = tonumber(t[12])
        local num_13 = tonumber(t[13])

        -- normalize audio format and store it back into t[11]
        t[11] = tostring(t[11]):upper()
        local audio_format = t[11]

        if (num_5  and num_5  > 1) or
           (num_7  and num_7  > 1) or
           (num_8  and num_8  > 1) or
           (num_12 and num_12 > 1) or
           (num_13 and num_13 > 1) then
            binary_error_msg = "Binary option entries must be set to 0 or 1.\n"
            pass = false
        end

        local valid_formats = {
            WAV = true,
            FLAC = true,
            MP3 = true,
            AIFF = true
        }

        if not valid_formats[audio_format] then
            ext_error_msg = "CUE audio format should be set to WAV, FLAC, AIFF or MP3."
            pass = false
        end
    end

    local error_msg = binary_error_msg .. invalid_msg .. ext_error_msg

    -- Return error message instead of showing MB dialog
    return pass, t, tonumber(t[12]), tonumber(t[5]), error_msg
end

-----------------------------------------------------------------------

function move_destination_folder_to_top()
    local destination_folder = nil
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            if track_name:find("^D:") and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
                destination_folder = track
                break
            end
        end
    end

    if not destination_folder then return end

    local destination_index = GetMediaTrackInfo_Value(destination_folder, "IP_TRACKNUMBER") - 1
    if destination_index > 0 then
        SetOnlyTrackSelected(destination_folder)
        ReorderSelectedTracks(0, 0)
    end
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

function prepare_takes()
    SetProjExtState(0, "ReaClassical", "prepare_silent", "y")
    local prepare_takes_command = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes_command, 0)
    SetProjExtState(0, "ReaClassical", "prepare_silent", "")
end

-----------------------------------------------------------------------

main()