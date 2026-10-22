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

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()
if _clara_or_debug then
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    dofile(script_path .. "lib/ReaClassical_Accessible Preferences.lua")
    return
end

local main, display_prefs, load_prefs, save_prefs, pref_check
local sync_based_on_workflow, move_destination_folder_to_top
local prepare_takes, rename_all_items, load_defaults, is_mastering_phase

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local year = os.date("%Y")
local default_values = '35,200,3,7,0,0,0,0,0.75,' .. year .. ',WAV,0,0,0,0,0'
local NUM_OF_ENTRIES = select(2, default_values:gsub(",", ",")) + 1
local labels = {
    'S-D Crossfade Length (ms)',
    'CD Track Offset (ms)',
    'INDEX0 Length (s) (>= 1)',
    'Album Lead-out Time (s)',
    'No Auto Item Coloring',
    'No Ranking Color',
    'REF = Overdub Guide',
    'Add S-D Markers at Mouse Hover',
    'Alt Audition Playback Rate',
    'Year of Production',
    'CUE Audio Format',
    'Floating Destination Folder',
    'Find Takes Using Item Names',
    'Show Only Item Take Numbers',
    'Source Audition Mode',
    'Marker Offset During Rec/Play (s)'
}

local binary_options = { 5, 6, 7, 8, 12, 13, 14, 15 }

local ctx = ImGui.CreateContext('ReaClassical Preferences')
local visible = true
local open = true
local apply_clicked = false
local reset_clicked = false
local prefs = {}
local error_message = ""

set_action_options(2)

function is_mastering_phase()
    local _, run = GetProjExtState(0, "ReaClassical", "CreateCDMarkersRun?")
    return run == "yes"
end

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    if gui_mode.accessible() then
        gui_mode.switch_window("ReaClassical_Preferences.lua")
        return
    end

    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    if not prefs[1] then
        load_prefs()
    end

    if reset_clicked then
        load_defaults()
        error_message = ""
        reset_clicked = false
    end

    display_prefs()

    if apply_clicked then
        local pass, corrected_prefs, new_floating, new_color, new_ranking_color, new_item_naming, error_msg = pref_check()

        if pass then
            local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
            local saved_entries = {}
            if saved ~= "" then
                for entry in saved:gmatch('([^,]+)') do
                    saved_entries[#saved_entries + 1] = entry
                end
            end
            local orig_floating = tonumber(saved_entries[12]) or 0
            local orig_color = tonumber(saved_entries[5]) or 0
            local orig_ranking_color = tonumber(saved_entries[6]) or 0
            local orig_item_naming = tonumber(saved_entries[14]) or 0

            save_prefs(corrected_prefs)

            if new_color ~= orig_color then
                prepare_takes()
            end
            if new_ranking_color ~= orig_ranking_color then
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
            open = false
        else
            error_message = error_msg or "Invalid input detected."
            load_prefs()
            apply_clicked = false
        end
    end

    if open and visible then
        defer(main)
    end
end

function display_prefs()
    local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize

    visible, open = ImGui.Begin(ctx, 'ReaClassical Project Preferences', true, window_flags)

    if not visible then
        ImGui.End(ctx)
        return
    end

    if gui_mode.imgui_shortcut(ImGui, ctx) then gui_mode.toggle_and_announce() end

    local mastering = is_mastering_phase()

    if ImGui.BeginTable(ctx, "prefs_table", 2, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg) then
        ImGui.TableSetupColumn(ctx, "labels", ImGui.TableColumnFlags_WidthFixed, 200)
        ImGui.TableSetupColumn(ctx, "inputs", ImGui.TableColumnFlags_WidthFixed, 80)

        for i = 1, #labels do
            ImGui.TableNextRow(ctx)
            ImGui.TableSetColumnIndex(ctx, 0)
            ImGui.AlignTextToFramePadding(ctx)
            ImGui.Text(ctx, labels[i] .. ":")
            ImGui.TableSetColumnIndex(ctx, 1)

            if not prefs[i] then
                prefs[i] = 0
            end

            local is_binary = false
            for _, idx in ipairs(binary_options) do
                if idx == i then
                    is_binary = true
                    break
                end
            end

            if is_binary then
                local disabled = (i == 14 and mastering)
                if disabled then
                    ImGui.BeginDisabled(ctx)
                end
                local checked = (tonumber(prefs[i]) == 1)
                local rv, val = ImGui.Checkbox(ctx, "##pref" .. i, checked)
                if rv then
                    prefs[i] = val and 1 or 0
                end
                if disabled then
                    ImGui.EndDisabled(ctx)
                    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
                        ImGui.SetTooltip(ctx, "Not available during album mastering phase")
                    end
                end
            elseif i == 11 then
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
                ImGui.SetNextItemWidth(ctx, 60)
                local rv, val = ImGui.InputText(ctx, "##pref" .. i, tostring(prefs[i]))
                if rv then
                    prefs[i] = val
                end
            end
        end

        ImGui.EndTable(ctx)
    end

    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    if error_message ~= "" then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF3333FF)
        ImGui.TextWrapped(ctx, error_message)
        ImGui.PopStyleColor(ctx)
        ImGui.Spacing(ctx)
    end

    if ImGui.Button(ctx, "Apply", 80, 0) then
        error_message = ""
        apply_clicked = true
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Reset", 80, 0) then
        error_message = ""
        reset_clicked = true
    end

    ImGui.SameLine(ctx)

    if ImGui.Button(ctx, "Cancel", 80, 0) then
        open = false
    end

    if gui_mode.imgui_close_shortcut(ImGui, ctx) then open = false end
    ImGui.End(ctx)
end

function load_prefs()
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")

    if saved ~= "" then
        local count = select(2, saved:gsub(",", ",")) + 1
        if count == NUM_OF_ENTRIES - 1 then
            saved = saved .. ",2"
        elseif count ~= NUM_OF_ENTRIES then
            saved = default_values
        end
    else
        saved = default_values
    end

    local saved_entries = {}
    for entry in saved:gmatch('([^,]+)') do
        saved_entries[#saved_entries + 1] = entry
    end

    for i = 1, #labels do
        if i == 11 then
            prefs[i] = saved_entries[i] or "WAV"
        else
            prefs[i] = tonumber(saved_entries[i]) or 0
        end
    end
end

function load_defaults()
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

function save_prefs(corrected_prefs)
    local values = {}
    for i = 1, #labels do
        values[i] = tostring(corrected_prefs[i])
    end
    local input = table.concat(values, ',')
    SetProjExtState(0, "ReaClassical", "Preferences", input)
end

function pref_check()
    local pass = true
    local t = {}
    local invalid_msg = ""

    for i = 1, #labels do
        t[i] = prefs[i]
    end

    for i = 1, #labels do
        if i == 11 then
            t[i] = tostring(t[i]):upper()
        else
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
            elseif i ~= 9 and i ~= 16 and num ~= math.floor(num) then
                pass = false
                invalid_msg = "Numeric entries (except Alt Audition Rate and Marker Offset) must be integers.\n"
                break
            end
        end
    end

    local binary_error_msg = ""
    local ext_error_msg = ""

    if pass then
        local num_5  = tonumber(t[5])
        local num_6  = tonumber(t[6])
        local num_7  = tonumber(t[7])
        local num_8  = tonumber(t[8])
        local num_12 = tonumber(t[12])
        local num_13 = tonumber(t[13])
        local num_14 = tonumber(t[14])
        local num_15 = tonumber(t[15])

        t[11]              = tostring(t[11]):upper()
        local audio_format = t[11]

        if (num_5  and num_5  > 1) or
            (num_6  and num_6  > 1) or
            (num_7  and num_7  > 1) or
            (num_8  and num_8  > 1) or
            (num_12 and num_12 > 1) or
            (num_13 and num_13 > 1) or
            (num_14 and num_14 > 1) or
            (num_15 and num_15 > 1) then
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

    return pass, t, tonumber(t[12]), tonumber(t[5]), tonumber(t[6]), tonumber(t[14]), error_msg
end

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

function sync_based_on_workflow(workflow)
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    if workflow == "Vertical" then
        dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
    elseif workflow == "Horizontal" then
        dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
    end
end

function prepare_takes()
    local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
    dofile(script_path .. "ReaClassical_Auto-color project.lua")
end

function rename_all_items(use_take_numbers)
    Undo_BeginBlock()

    local item_count = CountMediaItems(0)

    for i = 0, item_count - 1 do
        local item = GetMediaItem(0, i)
        if item then
            local take = GetActiveTake(item)
            if take then
                local source = GetMediaItemTake_Source(take)
                if source then
                    local filename = GetMediaSourceFileName(source, "")
                    local name = filename:match("([^/\\]+)$") or filename
                    name = name:match("(.+)%..+$") or name

                    if use_take_numbers == 1 then
                        local take_number = name:match("_T(%d+[^_]*)$")

                        if take_number then
                            GetSetMediaItemTakeInfo_String(take, "P_NAME", take_number, true)
                        else
                            local take_num = tonumber(
                                name:match("(%d+)%)?%s*%[chan%s*%d+%]$")
                                or name:match("(%d+)%)?$")
                            )

                            if take_num then
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", string.format("%03d", take_num), true)
                            else
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
                            end
                        end
                    else
                        local session_name, take_number

                        take_number = name:match("_(T%d+[^_]*)$")

                        if take_number then
                            if name:match("_[DS]%d?_[^_]+_T%d+") then
                                session_name = name:match("^(.-)_[DS]%d?_")
                            elseif name:match("^[DS]%d?_[^_]+_T%d+") then
                                session_name = nil
                            else
                                session_name = name:match("^(.-)_[^_]+_T%d+")
                            end

                            if session_name and session_name ~= "" then
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", session_name .. "_" .. take_number, true)
                            else
                                local num_only = take_number:match("T(%d+[^_]*)")
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", num_only, true)
                            end
                        else
                            local take_num = tonumber(
                                name:match("(%d+)%)?%s*%[chan%s*%d+%]$")
                                or name:match("(%d+)%)?$")
                            )

                            if take_num then
                                local prefix = name:match("^(.-)%d+%)?%s*%[?chan")
                                    or name:match("^(.-)%d+%)?$")

                                if prefix and prefix ~= "" and prefix ~= "(" then
                                    prefix = prefix:match("^(.-)[ _%-%(]+$") or prefix
                                    GetSetMediaItemTakeInfo_String(take, "P_NAME",
                                        prefix .. "_T" .. string.format("%03d", take_num), true)
                                else
                                    GetSetMediaItemTakeInfo_String(take, "P_NAME", string.format("%03d", take_num), true)
                                end
                            else
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

main()
