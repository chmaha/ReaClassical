--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

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
local sync_based_on_workflow, move_destination_folder_to_top
local prepare_takes, rename_all_items, load_defaults

-- Check for ReaImGui
local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local year = os.date("%Y")
local default_values = '35,200,3,7,0,500,0,0,0.75,' .. year .. ',WAV,0,0,0'
local NUM_OF_ENTRIES = select(2, default_values:gsub(",", ",")) + 1
local labels = {
    'S-D Crossfade Length (ms)',
    'CD Track Offset (ms)',
    'INDEX0 Length (s) (>= 1)',
    'Album Lead-out Time (s)',
    'No Item Coloring',
    'S-D Marker Check (ms)',
    'REF = Overdub Guide',
    'Add S-D Markers at Mouse Hover',
    'Alt Audition Playback Rate',
    'Year of Production',
    'CUE Audio Format',
    'Floating Destination Folder',
    'Find Takes Using Item Names',
    'Show Only Item Take Numbers'
}

-- Binary option indices (1-based)
local binary_options = { 5, 7, 8, 12, 13, 14 }

-- ImGui Context
local ctx = ImGui.CreateContext('ReaClassical Preferences')
local visible = true
local open = true
local apply_clicked = false
local reset_clicked = false
local prefs = {}
local error_message = "" -- Store validation error message

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    -- Load preferences into table on first run
    if not prefs[1] then
        load_prefs()
    end

    -- Handle reset button
    if reset_clicked then
        load_defaults()
        error_message = "" -- Clear any error message
        reset_clicked = false
        -- Don't close window, stay open to show reset values
    end

    -- Run ImGui display
    display_prefs()

    if apply_clicked then
        -- Validate and save
        local pass, corrected_prefs, new_floating, new_color, new_item_naming, error_msg = pref_check()

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
            local orig_item_naming = tonumber(saved_entries[14]) or 0

            save_prefs(corrected_prefs)

            if new_color ~= orig_color then
                prepare_takes()
            end
            if new_floating ~= orig_floating and new_floating == 0 then
                move_destination_folder_to_top()
                sync_based_on_workflow(workflow)
            elseif new_floating ~= orig_floating and new_floating == 1 then
                MB("When the floating destination folder is active, " ..
                    "DEST-IN and DEST-OUT markers are always associated with the \"D:\" folder.", "ReaClassical", 0)
            end
            if new_item_naming ~= orig_item_naming then
                rename_all_items(new_item_naming)
            end
            open = false -- Close window on success
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
        ImGui.TableSetupColumn(ctx, "labels", ImGui.TableColumnFlags_WidthFixed, 200)
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
                    local formats = { "WAV", "FLAC", "AIFF", "MP3" }
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
    if ImGui.Button(ctx, "Apply", 80, 0) then
        error_message = "" -- Clear any previous error
        apply_clicked = true
        -- Don't set open = false here, let validation decide
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Reset", 80, 0) then
        error_message = "" -- Clear any error
        reset_clicked = true
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Cancel", 80, 0) then
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

function load_defaults()
    -- Load default values into prefs table
    local default_entries = {}
    
    for entry in default_values:gmatch('([^,]+)') do
        default_entries[#default_entries + 1] = entry
    end
    
    for i = 1, #labels do
        if i == 11 then
            prefs[i] = default_entries[i] or "WAV"
        else
            prefs[i] = tonumber(default_entries[i]) or 0
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
        local num_5        = tonumber(t[5])
        local num_7        = tonumber(t[7])
        local num_8        = tonumber(t[8])
        local num_12       = tonumber(t[12])
        local num_13       = tonumber(t[13])
        local num_14       = tonumber(t[14])

        -- normalize audio format and store it back into t[11]
        t[11]              = tostring(t[11]):upper()
        local audio_format = t[11]

        if (num_5 and num_5 > 1) or
            (num_7 and num_7 > 1) or
            (num_8 and num_8 > 1) or
            (num_12 and num_12 > 1) or
            (num_13 and num_13 > 1) or
            (num_14 and num_14 > 1) then
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
    return pass, t, tonumber(t[12]), tonumber(t[5]), tonumber(t[14]), error_msg
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
    local prepare_takes_command = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes_command, 0)
end

-----------------------------------------------------------------------

function rename_all_items(use_take_numbers)
    Undo_BeginBlock()

    -- Get workflow to determine filename pattern
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")

    local item_count = CountMediaItems(0)

    for i = 0, item_count - 1 do
        local item = GetMediaItem(0, i)
        if item then
            local take = GetActiveTake(item)
            if take then
                local source = GetMediaItemTake_Source(take)
                if source then
                    local filename = GetMediaSourceFileName(source, "")
                    -- Extract just the filename without path and extension
                    local name = filename:match("([^/\\]+)$") or filename
                    name = name:match("(.+)%..+$") or name

                    if use_take_numbers == 1 then
                        -- Use just take numbers: look for _T#### at the end
                        local take_number = name:match("_T(%d+[^_]*)$")

                        if take_number then
                            -- Found ReaClassical format, use just padded number
                            GetSetMediaItemTakeInfo_String(take, "P_NAME", take_number, true)
                        else
                            -- Try find take patterns: (###)[chan X] or ### [chan X] or (###) or ###
                            local take_num = tonumber(
                                name:match("(%d+)%)?%s*%[chan%s*%d+%]$")
                                or name:match("(%d+)%)?$")
                            )

                            if take_num then
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", string.format("%04d", take_num), true)
                            else
                                -- No recognizable pattern, use full filename
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
                            end
                        end
                    else
                        -- Use session name + take number (or full filename if not ReaClassical)
                        local session_name, take_number

                        -- Detect format from filename structure
                        -- Vertical format has D_ or S#_ pattern: session_D_trackname_T### or session_S1_trackname_T###
                        -- Horizontal format: session_trackname_T###

                        -- First check if file ends with _T###
                        take_number = name:match("_(T%d+[^_]*)$")

                        if take_number then
                            -- It's a ReaClassical file, now determine if Vertical or Horizontal
                            -- Check for Vertical pattern: has _D_ or _S(number)_ before the take number
                            if name:match("_[DS]%d?_[^_]+_T%d+") then
                                -- Vertical format: extract session before first underscore
                                session_name = name:match("^([^_]+)_[DS]%d?_")
                            elseif name:match("^[DS]%d?_[^_]+_T%d+") then
                                -- Vertical format without session: starts with D_ or S#_
                                session_name = nil
                            else
                                -- Horizontal format or no session
                                -- Use the two-underscore pattern
                                session_name = name:match("^(.-)_[^_]+_T%d+")
                            end

                            if session_name and session_name ~= "" then
                                -- Has session name
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", session_name .. "_" .. take_number, true)
                            else
                                -- No session name, just padded number without T
                                local num_only = take_number:match("T(%d+[^_]*)")
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", num_only, true)
                            end
                        else
                            -- Not ReaClassical format, try find take patterns
                            local take_num = tonumber(
                                name:match("(%d+)%)?%s*%[chan%s*%d+%]$")
                                or name:match("(%d+)%)?$")
                            )

                            if take_num then
                                -- Found a take number at the end, extract everything before it as potential session
                                local prefix = name:match("^(.-)%d+%)?%s*%[?chan")
                                    or name:match("^(.-)%d+%)?$")

                                if prefix and prefix ~= "" and prefix ~= "(" then
                                    -- Remove trailing separators/spaces from prefix
                                    prefix = prefix:match("^(.-)[ _%-%(]+$") or prefix
                                    -- Has session-like prefix, add T
                                    GetSetMediaItemTakeInfo_String(take, "P_NAME",
                                        prefix .. "_T" .. string.format("%04d", take_num), true)
                                else
                                    -- No prefix, just padded number
                                    GetSetMediaItemTakeInfo_String(take, "P_NAME", string.format("%04d", take_num), true)
                                end
                            else
                                -- No recognizable pattern, use full filename without extension
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
                            end
                        end
                    end
                end
            end
        end
    end

    UpdateArrange()
    Undo_EndBlock("Rename all items based on preference", -1)
end

-----------------------------------------------------------------------

main()