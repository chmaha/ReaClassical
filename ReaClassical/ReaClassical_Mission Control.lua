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

-- Folder browser section builds upon Sexan's ImGui FileManager
-- Original: https://github.com/GoranKovac/ReaScripts/blob/master/ImGui_Tools/FileManager.lua
-- Extended with folder creation/deletion/rename for recording path management
-- License: GPL v3

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, color_to_native, generate_input_options
local reset_pan_on_double_click, get_special_tracks, get_mixer_sends
local get_tracks_from_first_folder, create_mixer_table
local get_current_input_info, apply_input_selection, rename_tracks
local format_pan, sync, auto_assign, reorder_track, delete_mixer_track
local add_mixer_track, init, draw_track_controls, draw_folder_browser
local get_directories, normalize_path, get_parent_path, split_path
local consolidate_folders_to_first

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

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

local initial_project = EnumProjects(-1, "")
local is_valid_project = false
local show_hardware_names = true
local input_dropdown_width = 80

local show_folder_browser = false
local folder_browser_type = nil -- "primary" or "secondary"
local folder_browser_path = ""
local folder_browser_dirs = {}
local os_separator = package.config:sub(1, 1)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('ReaClassical Mission Control')

local MAX_INPUTS = GetNumAudioInputs()
local TRACKS_PER_TAB = 8

set_action_options(2)

-- State storage
local mixer_tracks = {}
local d_tracks = {}                -- D: tracks from first folder (one per mixer)
local aux_submix_tracks = {}       -- Aux and submix tracks
local aux_submix_names = {}        -- Display names for aux/submix tracks
local aux_submix_pans = {}         -- Pan values for aux/submix tracks
local mixer_sends = {}             -- Track which aux/submix each mixer sends to
local pending_routing_changes = {} -- Track routing changes to apply when popup closes
local input_channels = {}          -- Store selected input channel index
local input_channels_mono = {}     -- Remember mono selection when switching to stereo
local input_channels_stereo = {}   -- Remember stereo selection when switching to mono
local mono_has_been_set = {}       -- Track if user has manually set mono
local stereo_has_been_set = {}     -- Track if user has manually set stereo
local is_stereo = {}               -- Store stereo checkbox state
local pan_values = {}              -- Store pan values for each track
local track_names = {}             -- Store mixer track names (without M: prefix)
local track_has_hyphen = {}        -- Track if mixer track name ends with hyphen
local volume_values = {}           -- Volume values for mixer tracks
local aux_volume_values = {}       -- Volume values for special tracks
local current_tab = 0
local selected_track = nil         -- Currently selected track index
local sync_needed = false          -- Flag to trigger sync at end of frame
local pan_reset = {}               -- Track double-click reset for pan sliders
local new_track_name = ""          -- Name for new mixer track
local focus_track_input = nil      -- Track which input should get focus next frame
local focus_special_input = nil    -- Track which special track input should get focus next frame

-- Word lists for auto input assignment
local pair_words = {
    "2ch", "pair", "paire", "paar", "coppia", "par", "пара", "对", "ペア",
    "쌍", "زوج", "pari", "пар", "πάρoς", "двойка", "קבוצה", "çift",
    "pár", "pāris", "pora", "jozi", "जोड़ी", "คู่", "pasang", "cặp",
    "stereo", "stéréo", "estéreo", "立体声", "ステレオ", "스테레오",
    "ستيريو", "στερεοφωνικός", "סטריאו", "stereotipas", "स्टीरियो",
    "สเตอริโอ", "âm thanh nổi", "paarig", "doppel", "duo"
}

local left_words = {
    "l", "left", "gauche", "sinistra", "izquierda", "esquerda", "ліворуч", "слева", "vlevo", "balra", "vänster",
    "vasakule", "venstre", "vänstra", "levý", "левый", "lijevo", "stânga", "sol", "kushoto", "ซ้าย", "बाएँ", "बायां",
    "links", "linke"
}

local right_words = {
    "r", "right", "droite", "destra", "derecha", "direita", "праворуч", "справа", "vpravo", "jobbra", "höger",
    "paremale", "høyre", "högra", "pravý", "правый", "desno", "dreapta", "sağ", "kulia", "ขวา", "दाएँ", "दायां",
    "rechts", "rechte"
}

-- Generate input options
local mono_options = {}
local stereo_options = {}
local track_num_format = "%d" -- Will be set based on number of tracks

---------------------------------------------------------------------

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    -- Add this project change detection code:
    local current_project = EnumProjects(-1, "")
    if current_project ~= initial_project then
        initial_project = current_project

        -- Reinitialize with new project
        selected_track = nil
        focus_track_input = nil
        focus_special_input = nil
        new_track_name = ""
        init()
    end

    -- Only validate tracks if we have a valid project
    if is_valid_project and #mixer_tracks > 0 then
        -- Validate first track is still valid
        if not ValidatePtr(mixer_tracks[1].mixer_track, "MediaTrack*") then
            init()
        end
    end

    -- Update all track states from REAPER (pan, volume, mute, solo)
    -- This keeps the UI in sync if user changes things in REAPER's mixer
    if is_valid_project then
        for i = 1, #mixer_tracks do
            local track_info = mixer_tracks[i]
            pan_values[i] = GetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN")
            volume_values[i] = GetMediaTrackInfo_Value(track_info.mixer_track, "D_VOL")
        end

        for i, aux_info in ipairs(aux_submix_tracks) do
            aux_submix_pans[i] = GetMediaTrackInfo_Value(aux_info.track, "D_PAN")
            aux_volume_values[i] = GetMediaTrackInfo_Value(aux_info.track, "D_VOL")
        end
    end
    ImGui.SetNextWindowSize(ctx, 600, 0, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, 'ReaClassical Mission Control', true, ImGui.WindowFlags_AlwaysAutoResize)

    if visible then
        if not is_valid_project then
            ImGui.Text(ctx, "This is not a ReaClassical project.")
            ImGui.Text(ctx, "")
            ImGui.Text(ctx, "Please create one via F7 or F8 then click refresh.")
            ImGui.Text(ctx, "")

            -- Refresh button
            if ImGui.Button(ctx, "⟳ Refresh") then
                init()
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Refresh after creating ReaClassical project")
            end

            ImGui.End(ctx)
            if open then
                defer(main)
            end
            return -- Exit early, don't draw normal UI
        end

        local num_tabs = math.ceil(#mixer_tracks / TRACKS_PER_TAB)

        if num_tabs > 1 then
            if ImGui.BeginTabBar(ctx, "##tabs") then
                for tab = 0, num_tabs - 1 do
                    local start_idx = tab * TRACKS_PER_TAB + 1
                    local end_idx = math.min(start_idx + TRACKS_PER_TAB - 1, #mixer_tracks)
                    local tab_label = string.format("Tracks %d-%d", start_idx, end_idx)

                    if ImGui.BeginTabItem(ctx, tab_label) then
                        current_tab = tab
                        draw_track_controls(start_idx, end_idx)
                        ImGui.EndTabItem(ctx)
                    end
                end
                ImGui.EndTabBar(ctx)
            end
        else
            draw_track_controls(1, #mixer_tracks)
        end

        -- Add button at the bottom
        ImGui.Separator(ctx)

        -- Up arrow button
        if ImGui.Button(ctx, "↑") and selected_track and selected_track > 1 then
            reorder_track(selected_track, selected_track - 1)
            selected_track = selected_track - 1
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Move selected track up")
        end

        -- Down arrow button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "↓") and selected_track and selected_track < #mixer_tracks then
            reorder_track(selected_track, selected_track + 1)
            selected_track = selected_track + 1
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Move selected track down")
        end

        -- Add mixer track button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "+") then
            new_track_name = "" -- Reset the name
            ImGui.OpenPopup(ctx, "Add Mixer Track")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Add track to all folders")
        end

        -- Convert Workflow
        ImGui.SameLine(ctx)
        if workflow == "Horizontal" then
            if ImGui.Button(ctx, "Convert") then
                ImGui.OpenPopup(ctx, "Convert to Vertical?")
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Convert to Vertical Workflow")
            end

            if ImGui.BeginPopupModal(ctx, "Convert to Vertical?", nil, ImGui.WindowFlags_AlwaysAutoResize) then
                ImGui.Text(ctx, "Are you sure you want to convert to Vertical workflow?")
                ImGui.Separator(ctx)

                -- Center the buttons
                local button_width = 60
                local spacing = 10
                local total_width = (button_width * 2) + spacing
                local window_width = ImGui.GetWindowWidth(ctx)
                ImGui.SetCursorPosX(ctx, (window_width - total_width) / 2)

                if ImGui.Button(ctx, "Yes", button_width, 0) then
                    local vert_convert = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
                    Main_OnCommand(vert_convert, 0)
                    init()
                    local whole_view = NamedCommandLookup("_RS63665092232578f8c8d10c5936ca5013a9ecab51")
                    Main_OnCommand(whole_view, 0)
                    ImGui.CloseCurrentPopup(ctx)
                end

                ImGui.SameLine(ctx, 0, spacing)

                if ImGui.Button(ctx, "Cancel", button_width, 0) then
                    ImGui.CloseCurrentPopup(ctx)
                end

                ImGui.EndPopup(ctx)
            end
        else
            if ImGui.Button(ctx, "Convert") then
                ImGui.OpenPopup(ctx, "Convert to Horizontal?")
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Convert to Horizontal Workflow")
            end

            if ImGui.BeginPopupModal(ctx, "Convert to Horizontal?", nil, ImGui.WindowFlags_AlwaysAutoResize) then
                ImGui.Text(ctx, "Are you sure you want to convert to Horizontal workflow?")
                ImGui.Separator(ctx)

                -- Center the buttons
                local button_width = 60
                local spacing = 10
                local total_width = (button_width * 2) + spacing
                local window_width = ImGui.GetWindowWidth(ctx)
                ImGui.SetCursorPosX(ctx, (window_width - total_width) / 2)

                if ImGui.Button(ctx, "Yes", button_width, 0) then
                    consolidate_folders_to_first()
                    local horiz_convert = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
                    Main_OnCommand(horiz_convert, 0)
                    init()
                    ImGui.CloseCurrentPopup(ctx)
                end

                ImGui.SameLine(ctx, 0, spacing)

                if ImGui.Button(ctx, "Cancel", button_width, 0) then
                    ImGui.CloseCurrentPopup(ctx)
                end

                ImGui.EndPopup(ctx)
            end
        end

        -- Add mixer track popup dialog
        if ImGui.BeginPopup(ctx, "Add Mixer Track") then
            ImGui.Text(ctx, "Enter track name:")
            ImGui.Separator(ctx)

            ImGui.SetNextItemWidth(ctx, 200)
            if ImGui.IsWindowAppearing(ctx) then
                ImGui.SetKeyboardFocusHere(ctx)
            end

            -- InputText needs the value passed in and returns the new value
            local rv, buf = ImGui.InputText(ctx, "##trackname", new_track_name)
            if rv then
                new_track_name = buf
            end

            -- Check for Enter key after editing (but before separator/buttons)
            local enter_pressed = ImGui.IsItemDeactivatedAfterEdit(ctx)

            ImGui.Separator(ctx)

            if enter_pressed then
                add_mixer_track(new_track_name)
                new_track_name = ""
                ImGui.CloseCurrentPopup(ctx)
            end

            if ImGui.Button(ctx, "OK", 80, 0) then
                add_mixer_track(new_track_name)
                new_track_name = ""
                ImGui.CloseCurrentPopup(ctx)
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Cancel", 80, 0) then
                new_track_name = ""
                ImGui.CloseCurrentPopup(ctx)
            end

            ImGui.EndPopup(ctx)
        end

        -- Refresh button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "⟳") then
            init()
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Refresh (useful after undo)")
        end

        -- Disconnect all from RCMASTER button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "✕ RCM") then
            for i = 1, #mixer_tracks do
                if not track_has_hyphen[i] then
                    track_has_hyphen[i] = true
                    local track_info = mixer_tracks[i]
                    rename_tracks(track_info, track_names[i], true)
                end
            end
            sync_needed = true
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Disconnect all mixer tracks from RCMASTER")
        end

        -- Connect all to RCMASTER button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "✓ RCM") then
            for i = 1, #mixer_tracks do
                if track_has_hyphen[i] then
                    track_has_hyphen[i] = false
                    local track_info = mixer_tracks[i]
                    rename_tracks(track_info, track_names[i], false)
                end
            end
            sync_needed = true
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Connect all mixer tracks to RCMASTER")
        end

        -- Auto assign inputs button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Auto") then
            auto_assign()
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx,
                "Auto-assign inputs based on track names\n(pair/stereo = stereo, left/right = mono with pan)")
        end

        -- Hardware names toggle button
        ImGui.SameLine(ctx)
        local btn_label = show_hardware_names and "Ch #" or "HW"
        if ImGui.Button(ctx, btn_label) then
            show_hardware_names = not show_hardware_names
            generate_input_options() -- Regenerate options with new setting
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Toggle hardware names / channel numbers")
        end

        -- Invisible button to fill remaining space and clear selection
        ImGui.SameLine(ctx)
        local remaining_width = ImGui.GetContentRegionAvail(ctx)
        ImGui.InvisibleButton(ctx, "##clearselect", remaining_width, ImGui.GetTextLineHeight(ctx))
        if ImGui.IsItemClicked(ctx) then
            selected_track = nil
        end

        -- Special Tracks section
        if #aux_submix_tracks > 0 then
            ImGui.Separator(ctx)
            local expanded
            expanded, show_aux_section = ImGui.CollapsingHeader(ctx, "Special Tracks", nil,
                ImGui.TreeNodeFlags_DefaultOpen)

            if expanded then
                for idx, aux_info in ipairs(aux_submix_tracks) do
                    local _, aux_guid = GetSetMediaTrackInfo_String(aux_info.track, "GUID", "", false)
                    ImGui.PushID(ctx, idx .. "_special_" .. aux_guid)

                    -- Track type indicator with color
                    local display_prefix = ""
                    local prefix_color = 0xFFFFFFFF -- Default white

                    if aux_info.type == "aux" then
                        display_prefix = "@"
                        prefix_color = color_to_native(200, 140, 135) -- Brightened reddish-brown
                    elseif aux_info.type == "submix" then
                        display_prefix = "#"
                        prefix_color = color_to_native(135, 195, 200) -- Brightened blue-grey
                    elseif aux_info.type == "roomtone" then
                        display_prefix = "RT"
                        prefix_color = color_to_native(200, 160, 110) -- Brightened tan/brown
                    elseif aux_info.type == "reference" then
                        display_prefix = "REF"
                        prefix_color = color_to_native(180, 180, 180) -- Brightened grey
                    elseif aux_info.type == "live" then
                        display_prefix = "LIVE"
                        prefix_color = color_to_native(255, 200, 200) -- Brightened pink
                    elseif aux_info.type == "rcmaster" then
                        display_prefix = "RCM"
                        prefix_color = color_to_native(80, 200, 80) -- Brightened green
                    end

                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, prefix_color)
                    ImGui.Text(ctx, display_prefix)
                    ImGui.PopStyleColor(ctx)

                    -- Track name input (only for tracks that can be renamed)
                    local can_rename = (aux_info.type == "aux" or aux_info.type == "submix" or aux_info.type == "reference")

                    -- Set cursor position for name input column (aligned)
                    local name_col_x = 60
                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, name_col_x)

                    if can_rename then
                        ImGui.SetNextItemWidth(ctx, 180)

                        -- Set focus if this is the special track that should receive focus
                        if focus_special_input == idx then
                            ImGui.SetKeyboardFocusHere(ctx)
                            focus_special_input = nil
                        end

                        local placeholder = (idx == 1 and aux_info.type == "aux") and "Enter names..." or ""
                        local changed_name, new_name = ImGui.InputTextWithHint(ctx, "##specialname" .. idx, placeholder,
                            aux_submix_names[idx])
                        if changed_name then
                            aux_submix_names[idx] = new_name
                            -- Update track name with prefix
                            local full_name
                            if aux_info.type == "aux" then
                                full_name = "@" .. new_name
                            elseif aux_info.type == "submix" then
                                full_name = "#" .. new_name
                            elseif aux_info.type == "reference" and new_name ~= "" then
                                full_name = "REF:" .. new_name
                            elseif aux_info.type == "reference" and new_name == "" then
                                full_name = "REF"
                            end

                            GetSetMediaTrackInfo_String(aux_info.track, "P_NAME", full_name, true)
                            aux_info.name = new_name
                            aux_info.full_name = full_name
                        end

                        -- Handle TAB key to move to next/previous renameable special track input
                        if ImGui.IsItemActive(ctx) then
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and not ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                -- TAB: Find next renameable track
                                local next_idx = nil
                                for i = idx + 1, #aux_submix_tracks do
                                    local next_aux = aux_submix_tracks[i]
                                    if next_aux.type == "aux" or next_aux.type == "submix" or next_aux.type == "reference" then
                                        next_idx = i
                                        break
                                    end
                                end
                                if next_idx then
                                    focus_special_input = next_idx
                                end
                            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                -- Shift+TAB: Find previous renameable track
                                local prev_idx = nil
                                for i = idx - 1, 1, -1 do
                                    local prev_aux = aux_submix_tracks[i]
                                    if prev_aux.type == "aux" or prev_aux.type == "submix" or prev_aux.type == "reference" then
                                        prev_idx = i
                                        break
                                    end
                                end
                                if prev_idx then
                                    focus_special_input = prev_idx
                                end
                            end
                        end
                    else
                        -- Add spacing to align with tracks that have name inputs
                        ImGui.Dummy(ctx, 180, ImGui.GetTextLineHeight(ctx))
                    end

                    -- Set cursor position for pan slider column (aligned)
                    local pan_col_x = name_col_x + 190
                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, pan_col_x)

                    -- Mute button (before pan)
                    local is_muted = GetMediaTrackInfo_Value(aux_info.track, "B_MUTE") == 1
                    if is_muted then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF0000FF)        -- Red when muted (RGBA)
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFF3333FF) -- Lighter red on hover
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCC0000FF)  -- Darker red when clicked
                        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)          -- White text
                    end
                    if ImGui.Button(ctx, "M##auxmute" .. idx, 25, 0) then
                        SetMediaTrackInfo_Value(aux_info.track, "B_MUTE", is_muted and 0 or 1)
                    end
                    if is_muted then
                        ImGui.PopStyleColor(ctx, 4) -- Pop all 4 colors
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Mute")
                    end

                    -- Solo button
                    ImGui.SameLine(ctx)
                    local is_soloed = GetMediaTrackInfo_Value(aux_info.track, "I_SOLO") > 0
                    if is_soloed then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFFFF00FF)        -- Yellow when soloed (RGBA)
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFFFF66FF) -- Lighter yellow on hover
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCCCC00FF)  -- Darker yellow when clicked
                        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x000000FF)          -- Black text
                    end
                    if ImGui.Button(ctx, "S##auxsolo" .. idx, 25, 0) then
                        SetMediaTrackInfo_Value(aux_info.track, "I_SOLO", is_soloed and 0 or 1)
                    end
                    if is_soloed then
                        ImGui.PopStyleColor(ctx, 4) -- Pop all 4 colors
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Solo")
                    end

                    -- Pan slider
                    ImGui.SameLine(ctx)
                    ImGui.SetNextItemWidth(ctx, 150)
                    local changed_pan, new_pan = ImGui.SliderDouble(ctx, "##specialpan" .. idx, aux_submix_pans[idx],
                        -1.0, 1.0, format_pan(aux_submix_pans[idx]))

                    -- Check for double-click reset to center
                    new_pan = reset_pan_on_double_click("##specialpan" .. idx, new_pan, 0.0)

                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Pan (double-click center, right-click to type)")
                    end

                    if changed_pan or new_pan ~= aux_submix_pans[idx] then
                        aux_submix_pans[idx] = new_pan
                        SetMediaTrackInfo_Value(aux_info.track, "D_PAN", new_pan)
                    end

                    -- Right-click popup for typing pan value
                    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
                        ImGui.OpenPopup(ctx, "auxpan_input##" .. idx)
                    end

                    if ImGui.BeginPopup(ctx, "auxpan_input##" .. idx) then
                        ImGui.Text(ctx, "Enter pan (C, L, R, 45L, 34R, etc.):")
                        ImGui.SetNextItemWidth(ctx, 100)
                        local pan_input_buf = format_pan(aux_submix_pans[idx])
                        local rv, buf = ImGui.InputText(ctx, "##auxpaninput", pan_input_buf,
                            ImGui.InputTextFlags_EnterReturnsTrue)
                        if rv then
                            local pan_val = 0.0
                            local input = buf:gsub("%s+", "") -- Remove spaces but keep original case
                            local input_upper = input:upper()

                            if input_upper == "C" or input == "" then
                                pan_val = 0.0
                            elseif input_upper == "L" then
                                pan_val = -1.0
                            elseif input_upper == "R" then
                                pan_val = 1.0
                            else
                                -- Try to parse number followed by L or R (case insensitive)
                                local num, side = input:match("^(%d+%.?%d*)([LlRr])$")
                                if num and side then
                                    local amount = tonumber(num)
                                    if amount then
                                        amount = math.min(100, amount) / 100
                                        pan_val = (side == "L" or side == "l") and -amount or amount
                                    end
                                end
                            end

                            aux_submix_pans[idx] = pan_val
                            SetMediaTrackInfo_Value(aux_info.track, "D_PAN", pan_val)
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        ImGui.EndPopup(ctx)
                    end

                    -- Volume knob
                    ImGui.SameLine(ctx)
                    ImGui.SetNextItemWidth(ctx, 200)
                    -- Convert linear volume to dB for display
                    local volume_db = 20 *
                        math.log(aux_volume_values[idx] > 0.0000001 and aux_volume_values[idx] or 0.0000001, 10)
                    -- Use logarithmic scale with more resolution near 0dB
                    local fader_pos = 0.0
                    if volume_db <= -60 then
                        fader_pos = 0.0
                    elseif volume_db >= 12 then
                        fader_pos = 1.0
                    else
                        if volume_db < 0 then
                            fader_pos = 0.75 * (volume_db + 60) / 60
                        else
                            fader_pos = 0.75 + 0.25 * (volume_db / 12)
                        end
                    end

                    local changed_fader, new_fader_pos = ImGui.SliderDouble(ctx, "##auxvol" .. idx, fader_pos, 0.0, 1.0,
                        string.format("%.1f dB", volume_db))

                    -- Check for double-click reset to 0dB
                    if ImGui.IsItemDeactivated(ctx) and pan_reset["auxvol" .. idx] then
                        new_fader_pos = 0.75
                        changed_fader = true
                        pan_reset["auxvol" .. idx] = nil
                    elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
                        pan_reset["auxvol" .. idx] = true
                    end

                    if changed_fader then
                        -- Convert fader position back to dB
                        local new_db
                        if new_fader_pos <= 0.75 then
                            new_db = -60 + (new_fader_pos / 0.75) * 60
                        else
                            new_db = ((new_fader_pos - 0.75) / 0.25) * 12
                        end
                        -- Convert dB to linear
                        local new_vol = 10 ^ (new_db / 20)
                        aux_volume_values[idx] = new_vol
                        SetMediaTrackInfo_Value(aux_info.track, "D_VOL", new_vol)
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Volume (double-click for 0dB, right-click to type dB)")
                    end

                    -- Right-click popup for typing dB value
                    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
                        ImGui.OpenPopup(ctx, "auxvol_input##" .. idx)
                    end

                    if ImGui.BeginPopup(ctx, "auxvol_input##" .. idx) then
                        ImGui.Text(ctx, "Enter volume (dB):")
                        ImGui.SetNextItemWidth(ctx, 100)
                        local volume_db_current = 20 *
                            math.log(aux_volume_values[idx] > 0.0000001 and aux_volume_values[idx] or 0.0000001, 10)
                        local vol_input_buf = string.format("%.1f", volume_db_current)
                        local rv, buf = ImGui.InputText(ctx, "##auxdbinput", vol_input_buf,
                            ImGui.InputTextFlags_EnterReturnsTrue)
                        if rv then
                            local db_val = tonumber(buf)
                            if db_val then
                                -- Clamp to -60 to +12 dB
                                db_val = math.max(-60, math.min(12, db_val))
                                local new_vol = 10 ^ (db_val / 20)
                                aux_volume_values[idx] = new_vol
                                SetMediaTrackInfo_Value(aux_info.track, "D_VOL", new_vol)
                            end
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        ImGui.EndPopup(ctx)
                    end

                    -- Routing button (only for aux and submix) or disabled button for alignment
                    ImGui.SameLine(ctx)
                    if aux_info.has_routing then
                        if ImGui.Button(ctx, "Routing##routing") then
                            ImGui.OpenPopup(ctx, "special_routing_popup")
                        end
                        if ImGui.IsItemHovered(ctx) then
                            ImGui.SetTooltip(ctx, "Route to RCMASTER and other Aux/Submix tracks")
                        end

                        -- Routing popup for this aux/submix
                        if ImGui.BeginPopup(ctx, "special_routing_popup") then
                            -- Read fresh P_EXT state when popup opens
                            local _, rcm_disconnect = GetSetMediaTrackInfo_String(aux_info.track, "P_EXT:rcm_disconnect",
                                "", false)
                            local current_rcm_state = (rcm_disconnect ~= "y") -- Convert to boolean

                            -- Get fresh sends
                            local fresh_aux_sends = {}
                            local num_sends = GetTrackNumSends(aux_info.track, 0)
                            for j = 0, num_sends - 1 do
                                local dest_track = GetTrackSendInfo_Value(aux_info.track, 0, j, "P_DESTTRACK")
                                if dest_track then
                                    fresh_aux_sends[dest_track] = true
                                end
                            end

                            ImGui.Text(ctx,
                                "Route " .. (aux_info.name ~= "" and aux_info.name or display_prefix) .. " to:")
                            ImGui.Separator(ctx)

                            -- Initialize pending changes with FRESH data ONLY on first open
                            local popup_id = "special_" .. aux_info.index
                            if not pending_routing_changes[popup_id] then
                                pending_routing_changes[popup_id] = {
                                    rcm_changed = false,
                                    rcm_state = current_rcm_state,
                                    sends = {}
                                }
                            end

                            -- RCMASTER checkbox (checked when track name does NOT end with hyphen)
                            local changed_rcm, new_rcm_state = ImGui.Checkbox(ctx, "RCMASTER",
                                pending_routing_changes[popup_id].rcm_state)
                            if changed_rcm then
                                pending_routing_changes[popup_id].rcm_changed = true
                                pending_routing_changes[popup_id].rcm_state = new_rcm_state
                            end

                            ImGui.Separator(ctx)

                            -- Show checkboxes for other aux/submix tracks (only those with routing)
                            local has_destinations = false
                            for _, dest_aux in ipairs(aux_submix_tracks) do
                                if dest_aux.track ~= aux_info.track and dest_aux.has_routing then
                                    has_destinations = true

                                    -- Use pending state if available, otherwise FRESH state
                                    local current_state = pending_routing_changes[popup_id].sends[dest_aux.track]
                                    if current_state == nil then
                                        current_state = fresh_aux_sends[dest_aux.track] or false -- Fresh data
                                    end

                                    local changed, new_state = ImGui.Checkbox(ctx, dest_aux.full_name, current_state)

                                    if changed then
                                        pending_routing_changes[popup_id].sends[dest_aux.track] = new_state
                                    end
                                end
                            end

                            if not has_destinations then
                                ImGui.Text(ctx, "(No other Aux/Submix tracks available)")
                            end

                            ImGui.EndPopup(ctx)
                        else
                            -- Popup just closed - apply all pending changes
                            local popup_id = "special_" .. aux_info.index
                            if pending_routing_changes[popup_id] then
                                local changes = pending_routing_changes[popup_id]

                                -- Apply RCMASTER routing change
                                if changes.rcm_changed then
                                    -- Update P_EXT state
                                    GetSetMediaTrackInfo_String(aux_info.track, "P_EXT:rcm_disconnect",
                                        changes.rcm_state and "" or "y", true)

                                    -- Remove trailing hyphen from name if present
                                    -- Update track name with or without hyphen based on connection state
                                    local base_name = aux_info.full_name:gsub("%-$", "")
                                    local new_name = changes.rcm_state and base_name or (base_name .. "-")
                                    GetSetMediaTrackInfo_String(aux_info.track, "P_NAME", new_name, true)

                                    aux_info.has_hyphen = not changes.rcm_state
                                    aux_info.full_name = new_name
                                    sync_needed = true
                                end

                                -- Apply aux/submix send changes
                                for dest_track, new_state in pairs(changes.sends) do
                                    -- Get FRESH sends again to compare
                                    local fresh_aux_sends_now = {}
                                    local num_sends_now = GetTrackNumSends(aux_info.track, 0)
                                    for j = 0, num_sends_now - 1 do
                                        local dest = GetTrackSendInfo_Value(aux_info.track, 0, j, "P_DESTTRACK")
                                        if dest then
                                            fresh_aux_sends_now[dest] = true
                                        end
                                    end

                                    local current_state = fresh_aux_sends_now[dest_track] or false
                                    if new_state ~= current_state then
                                        if new_state then
                                            CreateTrackSend(aux_info.track, dest_track)
                                        else
                                            -- Remove send
                                            for j = 0, num_sends_now - 1 do
                                                local dest = GetTrackSendInfo_Value(aux_info.track, 0, j, "P_DESTTRACK")
                                                if dest == dest_track then
                                                    RemoveTrackSend(aux_info.track, 0, j)
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end

                                -- Clear pending changes
                                pending_routing_changes[popup_id] = nil
                            end
                        end
                    else
                        -- Disabled routing button for tracks without routing (RT, LIVE, REF)
                        ImGui.BeginDisabled(ctx)
                        ImGui.Button(ctx, "Routing##routing_disabled")
                        ImGui.EndDisabled(ctx)
                    end

                    -- FX button
                    ImGui.SameLine(ctx)
                    if ImGui.Button(ctx, "FX##specialfx") then
                        -- Open FX chain window for this track
                        TrackFX_Show(aux_info.track, 0, 1)
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Open FX chain")
                    end

                    -- Delete button (disabled for RCMASTER)
                    ImGui.SameLine(ctx)
                    if aux_info.type == "rcmaster" then
                        ImGui.BeginDisabled(ctx)
                        ImGui.Button(ctx, "✕##specialdelete_disabled")
                        ImGui.EndDisabled(ctx)
                        if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
                            ImGui.SetTooltip(ctx, "RCMASTER cannot be deleted")
                        end
                    else
                        if ImGui.Button(ctx, "✕##specialdelete") then
                            DeleteTrack(aux_info.track)
                            -- Reinitialize to refresh the list
                            init()
                            ImGui.PopID(ctx)
                            break
                        end
                        if ImGui.IsItemHovered(ctx) then
                            ImGui.SetTooltip(ctx, "Delete this track")
                        end
                    end

                    ImGui.PopID(ctx)
                end
            end
        end

        -- Add special track button (always show, even if no tracks exist)
        ImGui.Separator(ctx)
        if ImGui.Button(ctx, "+ Add Special Track") then
            ImGui.OpenPopup(ctx, "add_special_track_popup")
        end

        local system = GetOS()
        local is_mac = string.find(system, "^OSX") or string.find(system, "^macOS")
        local ctrl_key = is_mac and "Cmd" or "Ctrl"
        local alt_key = is_mac and "Opt" or "Alt"

        -- Utility buttons
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "RC Prefs") then
            local rc_prefs = NamedCommandLookup("_RS297f985b12528ad436bc2a06e940e9378bbd10c7")
            Main_OnCommand(rc_prefs, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open ReaClassical Preferences (F5)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "MeterBridge") then
            local meterbridge = NamedCommandLookup("_RS811f88198ce41bd0c0ec7bb43673b94b4b1ae5b5")
            Main_OnCommand(meterbridge, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open MeterBridge (B)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Record Panel") then
            local record_panel = NamedCommandLookup("_RSbd41ad183cae7b18bccb86b087f719e945278160")
            Main_OnCommand(record_panel, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Record Panel (".. ctrl_key .. "+Enter)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Notes") then
            local notes = NamedCommandLookup("_RS45476b33951f282ccd1f1421a9615817226fc676")
            Main_OnCommand(notes, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Notes (N)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "S-D Editing Toolbar") then
            local editing = NamedCommandLookup("_RSdcbfd5e17e15e31f892e3fefdb1969b81d22b6df")
            Main_OnCommand(editing, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open S-D Editing Toolbar (F6)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Source Audition") then
            local source_audition = NamedCommandLookup("_RSde9495791cb6413268f7d42af6d0ca5b6923d282")
            Main_OnCommand(source_audition, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Source Audition (Z)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Mixer Snapshots") then
            local snapshots = NamedCommandLookup("_RS631257e69658396cd29f22227a610c8f5a8f8e06")
            Main_OnCommand(snapshots, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Mixer Snapshots (Shift+M)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Metadata Editor") then
            local metadata_edit = NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")
            Main_OnCommand(metadata_edit, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Metadata Editor for selected album folder (Y)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Render") then
            Main_OnCommand(40015, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Render dialog (R)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Calc") then
            local calc = NamedCommandLookup("_RSfb6903ab56db07d4bb262cdee9c84b8bb74d101e")
            Main_OnCommand(calc, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Calculator (Shift+H)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Statistics") then
            local stats = NamedCommandLookup("_RScc9d70f4ec5aeb05f992cbe0686cfe1ad6ff5c1d")
            Main_OnCommand(stats, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open Project Statistics (F1)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Help") then
            local help = NamedCommandLookup("_RSf03944e159952885b66c7c1be2754e2b3c7d4b07")
            Main_OnCommand(help, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open ReaClassical Help (H)")
        end

        -- Add special track popup
        if ImGui.BeginPopup(ctx, "add_special_track_popup") then
            ImGui.Text(ctx, "Add Special Track:")
            ImGui.Separator(ctx)

            if ImGui.MenuItem(ctx, "Aux") then
                local add_aux = NamedCommandLookup("_RS1938b67a195fd37423806f2647e26c3c212ce111")
                Main_OnCommand(add_aux, 0)
                init()
            end

            if ImGui.MenuItem(ctx, "Submix") then
                local add_submix = NamedCommandLookup("_RSdbfe4281d2bd56a7afc1c5e3967219c9f1c2095c")
                Main_OnCommand(add_submix, 0)
                init()
            end

            -- Check if RoomTone already exists
            local has_roomtone = false
            for _, track_info in ipairs(aux_submix_tracks) do
                if track_info.type == "roomtone" then
                    has_roomtone = true
                    break
                end
            end

            if not has_roomtone then
                if ImGui.MenuItem(ctx, "Room Tone") then
                    local add_roomtone = NamedCommandLookup("_RS3798d5ce6052ef404cd99dacf481f2befed4eacc")
                    Main_OnCommand(add_roomtone, 0)
                    init()
                end
            else
                ImGui.BeginDisabled(ctx)
                ImGui.MenuItem(ctx, "Room Tone (already exists)")
                ImGui.EndDisabled(ctx)
            end

            if ImGui.MenuItem(ctx, "Reference") then
                local add_ref = NamedCommandLookup("_RS00c2ccc67c644739aa15a0c93eea2c755554b30d")
                Main_OnCommand(add_ref, 0)
                init()
            end

            -- Check if Live already exists
            local has_live = false
            for _, track_info in ipairs(aux_submix_tracks) do
                if track_info.type == "live" then
                    has_live = true
                    break
                end
            end

            if not has_live then
                if ImGui.MenuItem(ctx, "Live Bounce") then
                    local add_livebounce = NamedCommandLookup("_RS3f8d9e9a5731c664bc87eb08923a2450aef06537")
                    Main_OnCommand(add_livebounce, 0)
                    init()
                end
            else
                ImGui.BeginDisabled(ctx)
                ImGui.MenuItem(ctx, "Live Bounce (already exists)")
                ImGui.EndDisabled(ctx)
            end

            ImGui.EndPopup(ctx)
        end

        -- Recording Paths section
        ImGui.Separator(ctx)
        local expanded_paths
        expanded_paths, show_paths_section = ImGui.CollapsingHeader(ctx, "Recording Paths", nil,
            ImGui.TreeNodeFlags_DefaultOpen)

        if expanded_paths then
            -- Get current paths
            local _, primary_path = GetSetProjectInfo_String(0, "RECORD_PATH", "", false)
            local _, secondary_path = GetSetProjectInfo_String(0, "RECORD_PATH_SECONDARY", "", false)

            -- Primary path
            ImGui.Text(ctx, "Primary:")
            ImGui.SameLine(ctx)
            ImGui.SetCursorPosX(ctx, 100)
            ImGui.SetNextItemWidth(ctx, 370)
            local changed_primary, new_primary = ImGui.InputText(ctx, "##primary_path", primary_path)
            if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                GetSetProjectInfo_String(0, "RECORD_PATH", new_primary, true)
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Browse##primary", 80, 0) then
                if primary_path == "" then
                    -- Use default recording path as starting point
                    local _, default_path = reaper.get_config_var_string("defrecpath")
                    folder_browser_path = default_path ~= "" and default_path or GetProjectPath("")
                    selected_folder = nil
                else
                    -- Check if it's a relative path (no separator)
                    local is_relative = not primary_path:find(os_separator, 1, true)

                    if is_relative then
                        -- For relative paths, strip it from the end of GetProjectPath
                        local project_path = GetProjectPath("")
                        -- Remove trailing separator and the relative folder name
                        local pattern = os_separator .. primary_path .. "$"
                        folder_browser_path = project_path:gsub(pattern, "")
                        selected_folder = primary_path
                    else
                        -- For absolute paths, open at parent
                        local resolved = normalize_path(primary_path)
                        folder_browser_path = get_parent_path(resolved)
                        -- Extract last folder name
                        local parts = split_path(resolved)
                        selected_folder = parts[#parts]
                    end
                end
                folder_browser_dirs = get_directories(folder_browser_path)
                folder_browser_type = "primary"
                show_folder_browser = true
                ImGui.OpenPopup(ctx, "Select Primary Recording Folder")
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Browse for folder")
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Default##primary", 80, 0) then
                GetSetProjectInfo_String(0, "RECORD_PATH", "media", true)
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Use project directory (leave blank)")
            end

            -- Secondary path
            ImGui.Text(ctx, "Secondary:")
            ImGui.SameLine(ctx)
            ImGui.SetCursorPosX(ctx, 100)
            ImGui.SetNextItemWidth(ctx, 370)
            local changed_secondary, new_secondary = ImGui.InputText(ctx, "##secondary_path", secondary_path)
            if ImGui.IsItemDeactivatedAfterEdit(ctx) then
                GetSetProjectInfo_String(0, "RECORD_PATH_SECONDARY", new_secondary, true)
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Browse##secondary", 80, 0) then
                if secondary_path == "" then
                    -- Use default recording path as starting point
                    local _, default_path = reaper.get_config_var_string("defrecpath")
                    folder_browser_path = default_path ~= "" and default_path or GetProjectPath("")
                    selected_folder = nil
                else
                    -- Check if it's a relative path (no separator)
                    local is_relative = not secondary_path:find(os_separator, 1, true)

                    if is_relative then
                        -- For relative paths, strip it from the end of GetProjectPath
                        local project_path = GetProjectPath("")
                        -- Remove trailing separator and the relative folder name
                        local pattern = os_separator .. secondary_path .. "$"
                        folder_browser_path = project_path:gsub(pattern, "")
                        selected_folder = secondary_path
                    else
                        -- For absolute paths, open at parent
                        local resolved = normalize_path(secondary_path)
                        folder_browser_path = get_parent_path(resolved)
                        -- Extract last folder name
                        local parts = split_path(resolved)
                        selected_folder = parts[#parts]
                    end
                end
                folder_browser_dirs = get_directories(folder_browser_path)
                folder_browser_type = "secondary"
                show_folder_browser = true
                ImGui.OpenPopup(ctx, "Select Secondary Recording Folder")
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Browse for folder")
            end



            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Clear##secondary", 80, 0) then
                GetSetProjectInfo_String(0, "RECORD_PATH_SECONDARY", "", true)
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Clear secondary path")
            end
        end

        -- Call folder browser dialog
        draw_folder_browser()

        ImGui.End(ctx)
    end

    -- Run sync after ImGui frame is complete if flag is set
    if sync_needed then
        sync_needed = false
        sync()
    end

    if open then
        defer(main)
    end
end

---------------------------------------------------------------------

function color_to_native(r, g, b)
    return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

---------------------------------------------------------------------

function generate_input_options()
    mono_options = {}
    stereo_options = {}
    table.insert(mono_options, "None")
    table.insert(stereo_options, "None")

    local max_chars = 4 -- Start with "None" length

    -- Generate mono options
    for i = 1, MAX_INPUTS do
        local option_text
        if show_hardware_names then
            local hw_name = GetInputChannelName(i - 1) -- 0-indexed API
            if hw_name and hw_name ~= "" then
                -- Show just the hardware name
                option_text = hw_name
            else
                -- Fallback to just number if no name available
                option_text = tostring(i)
            end
        else
            option_text = tostring(i)
        end
        table.insert(mono_options, option_text)
        max_chars = math.max(max_chars, #option_text)
    end

    -- Generate stereo options
    for i = 1, MAX_INPUTS - 1 do
        local option_text
        if show_hardware_names then
            local hw_name1 = GetInputChannelName(i - 1) -- 0-indexed
            local hw_name2 = GetInputChannelName(i)

            if hw_name1 and hw_name1 ~= "" and hw_name2 and hw_name2 ~= "" then
                -- Try to detect if they're a stereo pair with matching base name
                local base1 = hw_name1:match("^(.+)%s+%d+$") or hw_name1
                local base2 = hw_name2:match("^(.+)%s+%d+$") or hw_name2

                if base1 == base2 then
                    -- Same device/interface, show single name
                    option_text = string.format("%s+%s", hw_name1, hw_name2)
                else
                    -- Different devices, show both names
                    option_text = string.format("%s/%s", hw_name1, hw_name2)
                end
            else
                -- Fallback to just numbers if no names available
                option_text = string.format("%d+%d", i, i + 1)
            end
        else
            option_text = string.format("%d+%d", i, i + 1)
        end
        table.insert(stereo_options, option_text)
        max_chars = math.max(max_chars, #option_text)
    end

    -- Calculate dropdown width based on max characters
    -- Approximate 7 pixels per character + 30 for dropdown arrow/padding
    input_dropdown_width = math.max(80, (max_chars * 7) + 30)
end

---------------------------------------------------------------------

function reset_pan_on_double_click(id, value, default)
    if ImGui.IsItemDeactivated(ctx) and pan_reset[id] then
        pan_reset[id] = nil
        return default
    elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
        pan_reset[id] = true
    end

    return value
end

---------------------------------------------------------------------

function get_special_tracks()
    local tracks = {}

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y" or live_state == "y" or rcmaster_state == "y" then
            local track_type = "other"
            local has_routing = false

            if aux_state == "y" then
                track_type = "aux"
                has_routing = true
            elseif submix_state == "y" then
                track_type = "submix"
                has_routing = true
            elseif rt_state == "y" then
                track_type = "roomtone"
            elseif ref_state == "y" then
                track_type = "reference"
            elseif live_state == "y" then
                track_type = "live"
            elseif rcmaster_state == "y" then
                track_type = "rcmaster"
            end

            -- Get RCMASTER connection state from P_EXT
            local _, rcm_disconnect = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
            local has_hyphen = (rcm_disconnect == "y")

            local display_name = ""

            -- Extract display name based on track type
            if track_type == "aux" or track_type == "submix" then
                display_name = name:gsub("^[@#]:?", ""):gsub("%-$", "")
            elseif track_type == "reference" then
                display_name = name:gsub("^REF:?", ""):gsub("%-$", "")
            elseif track_type == "roomtone" then
                -- RoomTone has no additional name
                display_name = ""
            elseif track_type == "live" then
                -- LIVE has no additional name
                display_name = ""
            elseif track_type == "rcmaster" then
                -- RCMASTER has no additional name
                display_name = ""
            else
                display_name = name:gsub("%-$", "")
            end

            table.insert(tracks, {
                track = track,
                name = display_name,
                full_name = name,
                type = track_type,
                has_hyphen = has_hyphen,
                has_routing = has_routing,
                index = i
            })
        end
    end

    -- Sort tracks by type priority: aux, submix, roomtone, rcmaster, live, reference
    local type_priority = {
        aux = 1,
        submix = 2,
        roomtone = 3,
        rcmaster = 4,
        live = 5,
        reference = 6
    }

    table.sort(tracks, function(a, b)
        local priority_a = type_priority[a.type] or 99
        local priority_b = type_priority[b.type] or 99
        if priority_a ~= priority_b then
            return priority_a < priority_b
        else
            -- If same type, maintain original track order
            return a.index < b.index
        end
    end)

    return tracks
end

---------------------------------------------------------------------

function get_mixer_sends(mixer_track)
    local sends = {}
    local num_sends = GetTrackNumSends(mixer_track, 0)

    for i = 0, num_sends - 1 do
        local dest_track = GetTrackSendInfo_Value(mixer_track, 0, i, "P_DESTTRACK")
        if dest_track then
            local _, aux_state = GetSetMediaTrackInfo_String(dest_track, "P_EXT:aux", "", false)
            local _, submix_state = GetSetMediaTrackInfo_String(dest_track, "P_EXT:submix", "", false)

            if aux_state == "y" or submix_state == "y" then
                sends[dest_track] = true
            end
        end
    end

    return sends
end

---------------------------------------------------------------------

function get_tracks_from_first_folder()
    local tracks = {}
    local first_folder_idx = nil

    -- Find the first folder
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then
            first_folder_idx = i
            break
        end
    end

    if not first_folder_idx then return tracks end

    -- Get all tracks in the first folder
    -- The folder track is the first one
    table.insert(tracks, GetTrack(0, first_folder_idx))

    -- Continue adding tracks until we hit the end of the folder
    local i = first_folder_idx + 1
    local depth = 1

    while i < CountTracks(0) and depth > 0 do
        local track = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        -- Add track before checking depth (so we include the last track)
        if depth > 0 then
            table.insert(tracks, track)
        end

        -- Update depth after adding
        depth = depth + folder_change
        i = i + 1
    end

    return tracks
end

---------------------------------------------------------------------

function create_mixer_table()
    local tracks = {}

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            table.insert(tracks, {
                mixer_track = track,
                mixer_index = i
            })
        end
    end
    return tracks
end

---------------------------------------------------------------------

function get_current_input_info(d_track)
    local recInput = GetMediaTrackInfo_Value(d_track, "I_RECINPUT")
    local is_stereo_input = false
    local channel_index = 0

    if recInput < 0 then
        -- None
        channel_index = 0
        is_stereo_input = false
    elseif recInput >= 1024 then
        -- Stereo pair
        local ch = recInput - 1024
        channel_index = ch + 1 -- +1 because index 0 is now "None"
        is_stereo_input = true
    else
        -- Mono
        channel_index = recInput + 1 -- +1 because index 0 is "None"
        is_stereo_input = false
    end

    return channel_index, is_stereo_input
end

---------------------------------------------------------------------

function apply_input_selection(d_track, is_stereo_input, channel_index)
    local recInput

    if not is_stereo_input then
        -- Mono
        if channel_index == 0 then
            recInput = -1                -- None
        else
            recInput = channel_index - 1 -- -1 because index 0 is "None"
        end
    else
        -- Stereo
        if channel_index == 0 then
            recInput = -1                         -- None
        else
            recInput = 1024 + (channel_index - 1) -- -1 because index 0 is "None"
        end
    end

    SetMediaTrackInfo_Value(d_track, "I_RECINPUT", recInput)
end

---------------------------------------------------------------------

function rename_tracks(track_info, new_name, disconnect_rcm)
    -- Store RCMASTER disconnect state in P_EXT
    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect", disconnect_rcm and "y" or "", true)

    -- Remove any trailing hyphen from the name (we no longer use it)
    local clean_name = new_name:gsub("%-$", "")

    -- Rename mixer track with M: prefix (no hyphen)
    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_NAME", "M:" .. clean_name, true)

    -- Get the mixer track's position in the list (1-based)
    local mixer_position = nil
    for idx, info in ipairs(mixer_tracks) do
        if info.mixer_track == track_info.mixer_track then
            mixer_position = idx
            break
        end
    end

    if not mixer_position then return end

    -- Find all folder tracks in the project
    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        -- If this is a folder track (depth == 1)
        if folder_depth == 1 then
            folder_number = folder_number + 1

            -- The folder track itself is the first track (mixer_position 1)
            -- So for mixer_position 1, we want track at index i
            -- For mixer_position 2, we want track at index i+1, etc.
            local track_index = i + (mixer_position - 1)
            local target_track = GetTrack(0, track_index)

            if target_track then
                -- Store RCMASTER disconnect state in P_EXT for this track too
                GetSetMediaTrackInfo_String(target_track, "P_EXT:rcm_disconnect", disconnect_rcm and "y" or "", true)

                -- Determine prefix based on workflow and folder number
                local prefix = ""
                if workflow == "Vertical" then
                    if folder_number == 1 then
                        prefix = "D:"
                    else
                        prefix = "S" .. (folder_number - 1) .. ":"
                    end
                end

                -- Rename the track without hyphen
                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. clean_name, true)
            end
        end
    end
end

---------------------------------------------------------------------

function format_pan(panVal)
    if math.abs(panVal) < 0.01 then
        return "C"
    elseif panVal < 0 then
        return tostring(math.floor(-panVal * 100 + 0.5)) .. "L"
    else
        return tostring(math.floor(panVal * 100 + 0.5)) .. "R"
    end
end

---------------------------------------------------------------------

function sync()
    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    elseif workflow == "Horizontal" then
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end
end

---------------------------------------------------------------------

function auto_assign()
    local input_channel = 0

    for i = 1, #mixer_tracks do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i]
        local track_name = track_names[i]
        local lower_name = track_name:lower()

        -- Check if track name ENDS with pair words (stereo)
        local is_pair = false
        for _, word in ipairs(pair_words) do
            if lower_name:match("%s" .. word .. "$") or lower_name:match(word .. "$") then
                is_pair = true
                break
            end
        end

        -- Check for left/right in name for panning
        local is_left = false
        local is_right = false

        for _, word in ipairs(left_words) do
            if lower_name:match("%s" .. word .. "$") or lower_name:match("^" .. word .. "%s") then
                is_left = true
                break
            end
        end
        if not is_left then
            for _, word in ipairs(right_words) do
                if lower_name:match("%s" .. word .. "$") or lower_name:match("^" .. word .. "%s") then
                    is_right = true
                    break
                end
            end
        end

        -- Set pan only for explicit left/right (don't touch pair/stereo pan)
        if is_left then
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", -1.0)
        elseif is_right then
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", 1.0)
        end

        -- Assign inputs
        if input_channel < MAX_INPUTS then
            if is_pair and (input_channel + 1 < MAX_INPUTS) then
                -- Assign stereo input
                SetMediaTrackInfo_Value(d_track, "I_RECINPUT", 1024 + input_channel)
                is_stereo[i] = true
                input_channels[i] = input_channel + 1 -- +1 for "None" offset
                input_channels_stereo[i] = input_channel + 1
                stereo_has_been_set[i] = true
                input_channel = input_channel + 2
            else
                -- Assign mono input
                SetMediaTrackInfo_Value(d_track, "I_RECINPUT", input_channel)
                is_stereo[i] = false
                input_channels[i] = input_channel + 1 -- +1 for "None" offset
                input_channels_mono[i] = input_channel + 1
                mono_has_been_set[i] = true
                input_channel = input_channel + 1
            end
        else
            -- Beyond max hardware inputs, set to None
            SetMediaTrackInfo_Value(d_track, "I_RECINPUT", -1)
            input_channels[i] = 0 -- None
            if is_stereo[i] then
                input_channels_stereo[i] = 0
            else
                input_channels_mono[i] = 0
            end
        end
    end

    -- Sync if vertical workflow
    if workflow == "Vertical" then
        sync()
    end

    -- Refresh state
    init()
end

---------------------------------------------------------------------

function reorder_track(from_idx, to_idx)
    if from_idx == to_idx then return end

    -- Get the mixer track to move
    local from_track = mixer_tracks[from_idx].mixer_track

    -- Get the target position (which mixer track it should be before)
    local before_track
    if to_idx < from_idx then
        -- Moving up - place before the to_idx track
        before_track = mixer_tracks[to_idx].mixer_track
    else
        -- Moving down - place before the track after to_idx (or at end if last)
        if to_idx < #mixer_tracks then
            before_track = mixer_tracks[to_idx + 1].mixer_track
        else
            -- Moving to end - use the track count
            before_track = nil
        end
    end

    -- Select only the from_track
    Main_OnCommand(40297, 0) -- Unselect all tracks
    SetTrackSelected(from_track, true)

    -- Get the track index to move before (0-based)
    local before_track_idx
    if before_track then
        before_track_idx = GetMediaTrackInfo_Value(before_track, "IP_TRACKNUMBER") - 1
    else
        -- Move to end
        before_track_idx = CountTracks(0)
    end

    -- Reorder the track
    ReorderSelectedTracks(before_track_idx, 0)

    -- Sync based on workflow
    sync()

    -- Completely reinitialize
    init()
end

---------------------------------------------------------------------

function delete_mixer_track(track_info)
    -- Unselect all tracks
    Main_OnCommand(40297, 0) -- Track: Unselect all tracks

    -- Select only this mixer track
    SetTrackSelected(track_info.mixer_track, true)

    -- Run the delete mixer command
    local delete_mixer = NamedCommandLookup("_RS3e0eac1c51cbab48f6c385d7f39529ad5f16f961")
    Main_OnCommand(delete_mixer, 0)

    -- Completely reinitialize
    selected_track = nil
    init()
end

---------------------------------------------------------------------

function add_mixer_track(name)
    if name == "" then return end

    Undo_BeginBlock()

    -- Get folder and child count
    local num_of_tracks = CountTracks(0)
    local folder_count = 0
    local child_count = 0

    for i = 0, num_of_tracks - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local patterns = { "^M:", "^@", "^#", "^RCMASTER", "^RoomTone", "^REF", "^LIVE" }
        local bus = false
        for _, pattern in ipairs(patterns) do
            if string.match(track_name, pattern) then
                bus = true
                break
            end
        end
        if depth == 1 then
            folder_count = folder_count + 1
        elseif depth ~= 1 and folder_count == 1 and not bus then
            child_count = child_count + 1
        end
    end

    if folder_count == 0 then
        MB("Add one or more folders before running.", "Add Track To All Groups", 0)
        Undo_EndBlock("Add Track to Folder", -1)
        return
    end

    -- Save all rec inputs before doing anything
    local saved_rec_inputs = {}
    for i = 0, num_of_tracks - 1 do
        local track = GetTrack(0, i)
        local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
        local recInput = GetMediaTrackInfo_Value(track, "I_RECINPUT")
        saved_rec_inputs[guid] = recInput
    end

    PreventUIRefresh(1)

    -- Add new track to penultimate position
    local current_track_count = CountTracks(0)
    for i = 0, current_track_count - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth == 1 then
            -- Get color from this specific folder
            local folder_color = GetTrackColor(track)

            -- If folder doesn't have color, try first child
            if folder_color == 0 and i + 1 < CountTracks(0) then
                local child_track = GetTrack(0, i + 1)
                folder_color = GetTrackColor(child_track)
            end

            -- Insert the new track
            InsertTrackAtIndex(i + child_count, 1)

            -- Apply the folder's color to the newly inserted track
            if folder_color ~= 0 then
                local new_track_in_folder = GetTrack(0, i + child_count)
                SetTrackColor(new_track_in_folder, folder_color)
            end
        end
        if depth == -1 then
            -- Switch with last track in folder
            SetOnlyTrackSelected(track)
            ReorderSelectedTracks(i - 1, 0)
        end
    end

    -- Add new mixer track
    local tracks_per_folder = child_count + 2
    local index = (folder_count * tracks_per_folder) + tracks_per_folder - 1
    InsertTrackAtIndex(index, 1)
    local new_track = GetTrack(0, index)
    GetSetMediaTrackInfo_String(new_track, "P_NAME", "M:" .. name, true)
    GetSetMediaTrackInfo_String(new_track, "P_EXT:mix_order", index, true)
    GetSetMediaTrackInfo_String(new_track, "P_EXT:mixer", "y", true)

    -- Run sync based on workflow
    if folder_count > 1 then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    else
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end

    -- Restore rec inputs after sync
    local new_num_tracks = CountTracks(0)
    for i = 0, new_num_tracks - 1 do
        local track = GetTrack(0, i)
        local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
        if saved_rec_inputs[guid] then
            SetMediaTrackInfo_Value(track, "I_RECINPUT", saved_rec_inputs[guid])
        end
    end

    PreventUIRefresh(-1)
    Undo_EndBlock("Add Track to Folder", -1)

    -- Completely reinitialize from scratch
    selected_track = nil
    init()
end

---------------------------------------------------------------------

function init()
    generate_input_options()

    -- Check if current project is a ReaClassical project
    local _, current_workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = current_workflow
    if current_workflow == "" then
        is_valid_project = false
        return false
    end

    -- Get D: tracks from first folder
    d_tracks = get_tracks_from_first_folder()

    -- Get mixer tracks
    mixer_tracks = create_mixer_table()

    -- Get aux and submix tracks
    aux_submix_tracks = get_special_tracks()

    -- Initialize aux/submix names and pan values
    aux_submix_names = {}
    aux_submix_pans = {}
    for i, aux_info in ipairs(aux_submix_tracks) do
        aux_submix_names[i] = aux_info.name
        aux_submix_pans[i] = GetMediaTrackInfo_Value(aux_info.track, "D_PAN")
    end

    if #mixer_tracks == 0 then
        -- MB("No mixer tracks found.", "Error", 0)
        return false
    end

    if #d_tracks < #mixer_tracks then
        -- MB("Not enough D: tracks in first folder for all mixers.", "Error", 0)
        return false
    end

    -- Calculate zero padding for track numbers
    local num_digits = #tostring(#mixer_tracks)
    track_num_format = "%0" .. num_digits .. "d"

    -- Clear all state
    input_channels = {}
    input_channels_mono = {}
    input_channels_stereo = {}
    mono_has_been_set = {}
    stereo_has_been_set = {}
    is_stereo = {}
    pan_values = {}
    track_names = {}
    track_has_hyphen = {}
    mixer_sends = {}
    volume_values = {}

    -- Initialize by reading from D: tracks (first folder)
    for i = 1, #mixer_tracks do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i] -- Corresponding D: track

        local ch, stereo = get_current_input_info(d_track)
        input_channels[i] = ch
        is_stereo[i] = stereo

        -- Initialize both mono and stereo memory
        if stereo then
            input_channels_stereo[i] = ch
            input_channels_mono[i] = 0    -- Default mono to "None"
            stereo_has_been_set[i] = true -- Current value was set
            mono_has_been_set[i] = false
        else
            input_channels_mono[i] = ch
            input_channels_stereo[i] = 0 -- Default stereo to first pair
            mono_has_been_set[i] = true  -- Current value was set
            stereo_has_been_set[i] = false
        end

        pan_values[i] = GetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN")
        volume_values[i] = GetMediaTrackInfo_Value(track_info.mixer_track, "D_VOL")

        -- Get mixer track name without M: prefix and remove any trailing hyphen
        local _, mixer_name = GetTrackName(track_info.mixer_track)
        local name_without_prefix = mixer_name:gsub("^M:?", ""):gsub("%-$", "")

        -- Read RCMASTER connection state from P_EXT instead of checking hyphen
        local _, rcm_disconnect = GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect", "", false)
        track_has_hyphen[i] = (rcm_disconnect == "y")

        track_names[i] = name_without_prefix

        -- Get sends to aux/submix
        mixer_sends[i] = get_mixer_sends(track_info.mixer_track)
    end

    -- Initialize special tracks volume
    aux_volume_values = {}
    for i, aux_info in ipairs(aux_submix_tracks) do
        aux_volume_values[i] = GetMediaTrackInfo_Value(aux_info.track, "D_VOL")
    end
    is_valid_project = true
    return true
end

---------------------------------------------------------------------

function draw_track_controls(start_idx, end_idx)
    for i = start_idx, end_idx do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i]

        -- Use track GUID for unique ID instead of index
        local _, track_guid = GetSetMediaTrackInfo_String(track_info.mixer_track, "GUID", "", false)
        ImGui.PushID(ctx, i .. "_" .. track_guid)

        -- Draw background highlight if selected (pastel blue)
        local is_selected = (selected_track == i)
        if is_selected then
            local draw_list = ImGui.GetWindowDrawList(ctx)
            local cursor_screen_x, cursor_screen_y = ImGui.GetCursorScreenPos(ctx)
            local window_width = ImGui.GetWindowWidth(ctx)
            local item_height = ImGui.GetTextLineHeightWithSpacing(ctx)
            ImGui.DrawList_AddRectFilled(draw_list, cursor_screen_x, cursor_screen_y,
                cursor_screen_x + window_width, cursor_screen_y + item_height,
                0xADD8E688) -- Pastel blue (RGBA)
        end

        -- Track number
        ImGui.Text(ctx, string.format(track_num_format, i))

        -- Check if this row should be selected (clicking on track number)
        if ImGui.IsItemClicked(ctx) then
            selected_track = i
        end

        -- Track name input
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 220)

        -- Set focus if this is the track that should receive focus
        if focus_track_input == i then
            ImGui.SetKeyboardFocusHere(ctx)
            focus_track_input = nil
        end

        local placeholder = (i == 1) and "Enter track names..." or ""
        local changed_name, new_name = ImGui.InputTextWithHint(ctx, "##name" .. i, placeholder, track_names[i])
        if changed_name then
            track_names[i] = new_name
            rename_tracks(track_info, new_name, track_has_hyphen[i])
        end

        -- Handle TAB key to move to next track name input
        if ImGui.IsItemActive(ctx) then
            if ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and not ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                -- TAB: Move forward to next track
                if i < end_idx then
                    focus_track_input = i + 1
                elseif i == end_idx and current_tab < math.ceil(#mixer_tracks / TRACKS_PER_TAB) - 1 then
                    -- Last track in current tab - switch to next tab
                    current_tab = current_tab + 1
                    focus_track_input = end_idx + 1
                end
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                -- Shift+TAB: Move backwards to previous track
                if i > start_idx then
                    focus_track_input = i - 1
                elseif i == start_idx and current_tab > 0 then
                    -- First track in current tab - switch to previous tab
                    current_tab = current_tab - 1
                    local prev_tab_end = current_tab * TRACKS_PER_TAB + TRACKS_PER_TAB
                    focus_track_input = math.min(prev_tab_end, #mixer_tracks)
                end
            end
        end

        -- Mono/Stereo radio buttons
        ImGui.SameLine(ctx)
        local changed_to_mono = ImGui.RadioButton(ctx, "Mono##mono", not is_stereo[i])
        ImGui.SameLine(ctx)
        local changed_to_stereo = ImGui.RadioButton(ctx, "Stereo##stereo", is_stereo[i])

        if changed_to_mono and is_stereo[i] then
            -- Save current stereo value and switch to mono
            input_channels_stereo[i] = input_channels[i]
            stereo_has_been_set[i] = true
            is_stereo[i] = false

            -- On first switch, use channel 1 if available, otherwise None
            if not mono_has_been_set[i] then
                if MAX_INPUTS >= 1 then
                    input_channels[i] = 1 -- Channel 1 (index 1 in mono_options)
                else
                    input_channels[i] = 0 -- None
                end
                input_channels_mono[i] = input_channels[i]
                mono_has_been_set[i] = true
            else
                input_channels[i] = input_channels_mono[i]
            end

            apply_input_selection(d_track, is_stereo[i], input_channels[i])

            -- Set flag if vertical workflow
            if workflow == "Vertical" then
                sync_needed = true
            end
        elseif changed_to_stereo and not is_stereo[i] then
            -- Save current mono value and switch to stereo
            input_channels_mono[i] = input_channels[i]
            mono_has_been_set[i] = true
            is_stereo[i] = true

            -- On first switch, use 1+2 if available, otherwise None
            if not stereo_has_been_set[i] then
                if MAX_INPUTS >= 2 then
                    input_channels[i] = 1 -- 1+2 (index 1 in stereo_options)
                else
                    input_channels[i] = 0 -- None
                end
                input_channels_stereo[i] = input_channels[i]
                stereo_has_been_set[i] = true
            else
                input_channels[i] = input_channels_stereo[i]
            end

            apply_input_selection(d_track, is_stereo[i], input_channels[i])

            -- Set flag if vertical workflow
            if workflow == "Vertical" then
                sync_needed = true
            end
        end

        -- Input dropdown
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, input_dropdown_width)
        local options = is_stereo[i] and stereo_options or mono_options
        local options_str = table.concat(options, "\0") .. "\0"
        local changed_input, new_input = ImGui.Combo(ctx, "##input", input_channels[i], options_str)
        if changed_input then
            input_channels[i] = new_input

            -- Save to appropriate memory and mark as set
            if is_stereo[i] then
                input_channels_stereo[i] = new_input
                stereo_has_been_set[i] = true
            else
                input_channels_mono[i] = new_input
                mono_has_been_set[i] = true
            end

            apply_input_selection(d_track, is_stereo[i], input_channels[i])

            -- Set flag if vertical workflow
            if workflow == "Vertical" then
                sync_needed = true
            end
        end

        -- Mute button
        ImGui.SameLine(ctx)
        local is_muted = GetMediaTrackInfo_Value(track_info.mixer_track, "B_MUTE") == 1
        if is_muted then
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF0000FF)        -- Red when muted (RGBA)
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFF3333FF) -- Lighter red on hover
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCC0000FF)  -- Darker red when clicked
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)          -- White text
        end
        if ImGui.Button(ctx, "M##mute" .. i, 25, 0) then
            SetMediaTrackInfo_Value(track_info.mixer_track, "B_MUTE", is_muted and 0 or 1)
        end
        if is_muted then
            ImGui.PopStyleColor(ctx, 4) -- Pop all 4 colors
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Mute")
        end

        -- Solo button
        ImGui.SameLine(ctx)
        local is_soloed = GetMediaTrackInfo_Value(track_info.mixer_track, "I_SOLO") > 0
        if is_soloed then
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFFFF00FF)        -- Yellow when soloed (RGBA)
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFFFF66FF) -- Lighter yellow on hover
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCCCC00FF)  -- Darker yellow when clicked
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x000000FF)          -- Black text
        end
        if ImGui.Button(ctx, "S##solo" .. i, 25, 0) then
            SetMediaTrackInfo_Value(track_info.mixer_track, "I_SOLO", is_soloed and 0 or 1)
        end
        if is_soloed then
            ImGui.PopStyleColor(ctx, 4) -- Pop all 4 colors
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Solo")
        end

        -- Pan slider
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 150)
        local changed_pan, new_pan = ImGui.SliderDouble(ctx, "##pan" .. i, pan_values[i], -1.0, 1.0,
            format_pan(pan_values[i]))

        -- Check for double-click reset to center
        new_pan = reset_pan_on_double_click("##pan" .. i, new_pan, 0.0)

        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Pan (double-click center, right-click to type)")
        end

        if changed_pan or new_pan ~= pan_values[i] then
            pan_values[i] = new_pan
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", new_pan)
        end

        -- Right-click popup for typing pan value
        if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
            ImGui.OpenPopup(ctx, "pan_input##" .. i)
        end

        if ImGui.BeginPopup(ctx, "pan_input##" .. i) then
            ImGui.Text(ctx, "Enter pan (C, L, R, 45L, 34R, etc.):")
            ImGui.SetNextItemWidth(ctx, 100)
            local pan_input_buf = format_pan(pan_values[i])
            local rv, buf = ImGui.InputText(ctx, "##paninput", pan_input_buf, ImGui.InputTextFlags_EnterReturnsTrue)
            if rv then
                local pan_val = 0.0
                local input = buf:gsub("%s+", "") -- Remove spaces but keep original case
                local input_upper = input:upper() -- Uppercase version for comparison

                if input_upper == "C" or input == "" then
                    pan_val = 0.0
                elseif input_upper == "L" then
                    pan_val = -1.0
                elseif input_upper == "R" then
                    pan_val = 1.0
                else
                    -- Try to parse number followed by L or R (case insensitive)
                    local num, side = input:match("^(%d+%.?%d*)([LlRr])$")
                    if num and side then
                        local amount = tonumber(num)
                        if amount then
                            amount = math.min(100, amount) / 100 -- Clamp to 100 and convert to 0-1
                            pan_val = (side == "L" or side == "l") and -amount or amount
                        end
                    end
                end

                pan_values[i] = pan_val
                SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", pan_val)
                ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
        end

        -- Volume knob (as slider for now)
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 200)
        -- Convert linear volume to dB for display
        local volume_db = 20 * math.log(volume_values[i] > 0.0000001 and volume_values[i] or 0.0000001, 10)
        -- Use logarithmic scale: map -60dB to 12dB non-linearly
        -- More resolution near 0dB (unity gain)
        local fader_pos = 0.0
        if volume_db <= -60 then
            fader_pos = 0.0
        elseif volume_db >= 12 then
            fader_pos = 1.0
        else
            -- Logarithmic mapping with more resolution near 0dB
            -- Below 0dB: spread -60 to 0 over 0.0 to 0.75
            -- Above 0dB: spread 0 to 12 over 0.75 to 1.0
            if volume_db < 0 then
                fader_pos = 0.75 * (volume_db + 60) / 60
            else
                fader_pos = 0.75 + 0.25 * (volume_db / 12)
            end
        end

        local changed_fader, new_fader_pos = ImGui.SliderDouble(ctx, "##vol" .. i, fader_pos, 0.0, 1.0,
            string.format("%.1f dB", volume_db))

        -- Check for double-click reset to 0dB (1.0 linear)
        if ImGui.IsItemDeactivated(ctx) and pan_reset["vol" .. i] then
            new_fader_pos = 0.75 -- 0dB position
            changed_fader = true
            pan_reset["vol" .. i] = nil
        elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
            pan_reset["vol" .. i] = true
        end

        if changed_fader then
            -- Convert fader position back to dB
            local new_db
            if new_fader_pos <= 0.75 then
                -- -60dB to 0dB range
                new_db = -60 + (new_fader_pos / 0.75) * 60
            else
                -- 0dB to 12dB range
                new_db = ((new_fader_pos - 0.75) / 0.25) * 12
            end
            -- Convert dB to linear
            local new_vol = 10 ^ (new_db / 20)
            volume_values[i] = new_vol
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_VOL", new_vol)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Volume (double-click for 0dB, right-click to type dB)")
        end

        -- Right-click popup for typing dB value
        if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
            ImGui.OpenPopup(ctx, "vol_input##" .. i)
        end

        if ImGui.BeginPopup(ctx, "vol_input##" .. i) then
            ImGui.Text(ctx, "Enter volume (dB):")
            ImGui.SetNextItemWidth(ctx, 100)
            local volume_db_current = 20 * math.log(volume_values[i] > 0.0000001 and volume_values[i] or 0.0000001, 10)
            local vol_input_buf = string.format("%.1f", volume_db_current)
            local rv, buf = ImGui.InputText(ctx, "##dbinput", vol_input_buf, ImGui.InputTextFlags_EnterReturnsTrue)
            if rv then
                local db_val = tonumber(buf)
                if db_val then
                    -- Clamp to -60 to +12 dB
                    db_val = math.max(-60, math.min(12, db_val))
                    local new_vol = 10 ^ (db_val / 20)
                    volume_values[i] = new_vol
                    SetMediaTrackInfo_Value(track_info.mixer_track, "D_VOL", new_vol)
                end
                ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
        end

        -- Aux routing button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Routing##" .. i) then
            ImGui.OpenPopup(ctx, "aux_routing##" .. i)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Route to RCMASTER and Aux/Submix tracks")
        end

        -- Aux routing popup
        if ImGui.BeginPopup(ctx, "aux_routing##" .. i) then
            -- Read fresh P_EXT state when popup opens
            local _, rcm_disconnect = GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect", "",
                false)
            local current_rcm_state = (rcm_disconnect ~= "y") -- Convert to boolean (true = connected)

            -- Get fresh sends data
            local fresh_sends = get_mixer_sends(track_info.mixer_track)

            ImGui.Text(ctx, "Route " .. track_names[i] .. " to:")
            ImGui.Separator(ctx)

            -- Initialize pending changes with FRESH data ONLY on first open
            if not pending_routing_changes[i] then
                pending_routing_changes[i] = {
                    rcm_changed = false,
                    rcm_state = current_rcm_state,
                    sends = {}
                }
            end

            -- RCMASTER checkbox (checked when track name does NOT end with hyphen)
            local changed_rcm, new_rcm_state = ImGui.Checkbox(ctx, "RCMASTER", pending_routing_changes[i].rcm_state)
            if changed_rcm then
                pending_routing_changes[i].rcm_changed = true
                pending_routing_changes[i].rcm_state = new_rcm_state
            end

            ImGui.Separator(ctx)

            if #aux_submix_tracks == 0 then
                ImGui.Text(ctx, "(No Aux/Submix tracks available)")
            else
                for _, aux_info in ipairs(aux_submix_tracks) do
                    -- Only show aux/submix tracks with routing in mixer routing popups
                    if aux_info.has_routing then
                        -- Use pending state if available, otherwise FRESH state
                        local current_state = pending_routing_changes[i].sends[aux_info.track]
                        if current_state == nil then
                            current_state = fresh_sends[aux_info.track] or false -- Use fresh data
                        end

                        local changed, new_state = ImGui.Checkbox(ctx, aux_info.full_name .. "##aux" .. i, current_state)

                        if changed then
                            pending_routing_changes[i].sends[aux_info.track] = new_state
                        end
                    end
                end
            end

            ImGui.EndPopup(ctx)
        else
            -- Popup just closed - apply all pending changes
            if pending_routing_changes[i] then
                local changes = pending_routing_changes[i]

                -- Apply RCMASTER routing change
                if changes.rcm_changed then
                    -- Update P_EXT state
                    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect",
                        changes.rcm_state and "" or "y", true)

                    track_has_hyphen[i] = not changes.rcm_state
                    rename_tracks(track_info, track_names[i], track_has_hyphen[i])
                    sync_needed = true
                end

                -- Apply aux/submix send changes
                for aux_track, new_state in pairs(changes.sends) do
                    -- Get FRESH sends again to compare
                    local fresh_sends_now = get_mixer_sends(track_info.mixer_track)
                    local current_state = fresh_sends_now[aux_track] or false
                    if new_state ~= current_state then
                        if new_state then
                            -- Create send
                            CreateTrackSend(track_info.mixer_track, aux_track)
                        else
                            -- Remove send
                            local num_sends = GetTrackNumSends(track_info.mixer_track, 0)
                            for j = 0, num_sends - 1 do
                                local dest = GetTrackSendInfo_Value(track_info.mixer_track, 0, j, "P_DESTTRACK")
                                if dest == aux_track then
                                    RemoveTrackSend(track_info.mixer_track, 0, j)
                                    break
                                end
                            end
                        end
                        -- Update state
                        mixer_sends[i][aux_track] = new_state
                    end
                end

                -- Clear pending changes
                pending_routing_changes[i] = nil
            end
        end

        -- FX button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "FX##fx" .. i) then
            -- Open FX chain window for this track
            TrackFX_Show(track_info.mixer_track, 0, 1)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open FX chain")
        end

        -- Delete button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "✕##delete" .. i) then
            delete_mixer_track(track_info)
            -- Break out of the loop since we've modified the tracks array
            ImGui.PopID(ctx)
            return
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Delete this track from all folders")
        end

        -- Invisible button to fill the rest of the row and make it clickable
        ImGui.SameLine(ctx)
        local remaining_width = ImGui.GetContentRegionAvail(ctx)
        ImGui.InvisibleButton(ctx, "##rowclick", remaining_width, ImGui.GetTextLineHeight(ctx))
        if ImGui.IsItemClicked(ctx) then
            selected_track = i
        end

        ImGui.PopID(ctx)
    end
end

---------------------------------------------------------------------

function get_directories(path)
    local dirs = {}
    local i = 0
    repeat
        local dir = reaper.EnumerateSubdirectories(path, i)
        if dir and dir:sub(1, 1) ~= '.' then
            table.insert(dirs, dir)
        end
        i = i + 1
    until not dir
    table.sort(dirs, function(a, b) return a:lower() < b:lower() end)
    return dirs
end

---------------------------------------------------------------------

function normalize_path(path)
    -- Remove trailing slash
    if path:sub(-1) == os_separator then
        path = path:sub(1, -2)
    end
    return path
end

---------------------------------------------------------------------

function get_parent_path(path)
    path = normalize_path(path)
    -- Build pattern dynamically based on os_separator
    local pattern
    if os_separator == "\\" then
        -- On Windows, need to escape the backslash
        pattern = "^(.+)\\[^\\]+$"
    else
        pattern = "^(.+)/[^/]+$"
    end
    local parent = path:match(pattern)
    return parent or path
end

---------------------------------------------------------------------


function split_path(path)
    local parts = {}
    local current = ""

    for i = 1, #path do
        local char = path:sub(i, i)
        if char == os_separator then
            if current ~= "" then
                table.insert(parts, current)
                current = ""
            end
        else
            current = current .. char
        end
    end

    -- Add the last part
    if current ~= "" then
        table.insert(parts, current)
    end

    return parts
end

---------------------------------------------------------------------

function draw_folder_browser()
    if not show_folder_browser then return end

    local center_x, center_y = ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))
    ImGui.SetNextWindowPos(ctx, center_x, center_y, ImGui.Cond_Appearing, 0.5, 0.5)
    ImGui.SetNextWindowSize(ctx, 600, 450, ImGui.Cond_Appearing)

    local title = folder_browser_type == "primary" and "Select Primary Recording Folder" or
        "Select Secondary Recording Folder"

    if ImGui.BeginPopupModal(ctx, title, true, ImGui.WindowFlags_NoResize) then
        -- Path breadcrumb buttons
        ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x00000000)

        -- For absolute paths on Unix, add root
        local is_absolute = folder_browser_path:sub(1, 1) == "/"
        if is_absolute then
            if ImGui.Button(ctx, "/" .. "##0") then
                folder_browser_path = "/"
                folder_browser_dirs = get_directories(folder_browser_path)
                selected_folder = nil
            end
            ImGui.SameLine(ctx)
        end

        local path_parts = split_path(folder_browser_path)

        for i, part in ipairs(path_parts) do
            -- Reconstruct path up to this point
            local new_path = ""
            if is_absolute then
                new_path = "/"
            end

            for j = 1, i do
                if j > 1 or is_absolute then
                    new_path = new_path .. path_parts[j]
                    if j < i then
                        new_path = new_path .. os_separator
                    end
                else
                    new_path = path_parts[j]
                end
            end

            if ImGui.Button(ctx, part .. " " .. os_separator .. "##" .. i) then
                folder_browser_path = new_path
                folder_browser_dirs = get_directories(folder_browser_path)
                selected_folder = nil
            end

            if i < #path_parts then
                ImGui.SameLine(ctx)
            end
        end
        ImGui.PopStyleColor(ctx)

        ImGui.Separator(ctx)

        -- Folder list
        if ImGui.BeginChild(ctx, "##folders", -1, -80) then
            -- Parent directory option
            local can_go_up = #path_parts > 0 and not (is_absolute and #path_parts == 0)
            if can_go_up then
                local is_parent_selected = selected_folder == ".."
                if ImGui.Selectable(ctx, ".. (Parent Directory)", is_parent_selected, ImGui.SelectableFlags_AllowDoubleClick) then
                    if ImGui.IsMouseDoubleClicked(ctx, 0) then
                        folder_browser_path = get_parent_path(folder_browser_path)
                        folder_browser_dirs = get_directories(folder_browser_path)
                        selected_folder = nil
                    else
                        selected_folder = ".."
                    end
                end
            end

            -- Directory list
            if #folder_browser_dirs > 0 then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x55D8FFFF)
                for _, dir in ipairs(folder_browser_dirs) do
                    local is_selected = (selected_folder == dir)
                    if ImGui.Selectable(ctx, dir, is_selected, ImGui.SelectableFlags_AllowDoubleClick) then
                        if ImGui.IsMouseDoubleClicked(ctx, 0) then
                            -- Double-click: navigate into folder
                            local base = normalize_path(folder_browser_path)
                            if base == "" or base == "/" then
                                folder_browser_path = "/" .. dir
                            else
                                folder_browser_path = base .. os_separator .. dir
                            end
                            folder_browser_dirs = get_directories(folder_browser_path)
                            selected_folder = nil
                        else
                            -- Single-click: just select it (don't change path yet)
                            selected_folder = dir
                        end
                    end
                end
                ImGui.PopStyleColor(ctx)
            else
                ImGui.TextDisabled(ctx, "(No subdirectories)")
            end

            ImGui.EndChild(ctx)
        end

        ImGui.Separator(ctx)

        -- Current path display (show what will be selected)
        local display_path = folder_browser_path
        if selected_folder and selected_folder ~= ".." then
            local base = normalize_path(folder_browser_path)
            if base == "" or base == "/" then
                display_path = "/" .. selected_folder
            else
                display_path = base .. os_separator .. selected_folder
            end
        end
        ImGui.Text(ctx, "Selected: " .. display_path)

        -- New Folder button
        if ImGui.Button(ctx, "New Folder", 95, 0) then
            new_folder_name = ""
            ImGui.OpenPopup(ctx, "new_folder_popup")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Create a new subfolder")
        end

        -- Rename button (only enabled if a folder is selected and not parent)
        ImGui.SameLine(ctx)
        if not selected_folder or selected_folder == ".." then
            ImGui.BeginDisabled(ctx)
        end
        if ImGui.Button(ctx, "Rename", 95, 0) then
            rename_folder_name = selected_folder or ""
            ImGui.OpenPopup(ctx, "rename_folder_popup")
        end
        if not selected_folder or selected_folder == ".." then
            ImGui.EndDisabled(ctx)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Rename selected folder")
        end

        -- Delete button (only enabled if a folder is selected and not parent and is empty)
        ImGui.SameLine(ctx)

        -- Check if selected folder contains files
        local folder_has_files = false
        if selected_folder and selected_folder ~= ".." then
            local check_path = normalize_path(folder_browser_path) .. os_separator .. selected_folder
            local file_idx = 0
            repeat
                local file = reaper.EnumerateFiles(check_path, file_idx)
                if file then
                    folder_has_files = true
                    break
                end
                file_idx = file_idx + 1
            until not file
        end

        local should_disable = not selected_folder or selected_folder == ".." or folder_has_files

        if should_disable then
            ImGui.BeginDisabled(ctx)
        end

        if ImGui.Button(ctx, "Delete", 95, 0) then
            local delete_path = normalize_path(folder_browser_path) .. os_separator .. selected_folder

            -- Use OS command to delete
            local cmd
            if os_separator == "\\" then
                cmd = string.format('rmdir "%s"', delete_path) -- No /s flag - only deletes if empty
            else
                cmd = string.format('rmdir "%s"', delete_path) -- Only deletes if empty
            end
            os.execute(cmd)

            -- Refresh directory list
            folder_browser_dirs = get_directories(folder_browser_path)
            selected_folder = nil
        end

        if should_disable then
            ImGui.EndDisabled(ctx)
        end

        if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
            if folder_has_files then
                ImGui.SetTooltip(ctx, "Can't delete: folder contains files")
            elseif not selected_folder or selected_folder == ".." then
                ImGui.SetTooltip(ctx, "Select a folder to delete")
            else
                ImGui.SetTooltip(ctx, "Delete empty folder")
            end
        end

        -- New folder popup
        if ImGui.BeginPopup(ctx, "new_folder_popup") then
            ImGui.Text(ctx, "Create new folder in:")
            ImGui.TextDisabled(ctx, folder_browser_path)
            ImGui.Separator(ctx)

            ImGui.Text(ctx, "Folder name:")
            ImGui.SetNextItemWidth(ctx, 250)
            if ImGui.IsWindowAppearing(ctx) then
                ImGui.SetKeyboardFocusHere(ctx)
            end

            local rv, buf = ImGui.InputText(ctx, "##newfoldername", new_folder_name)
            if rv then
                new_folder_name = buf
            end

            local enter_pressed = ImGui.IsItemDeactivatedAfterEdit(ctx)

            ImGui.Separator(ctx)

            local can_create = new_folder_name ~= "" and new_folder_name:match("^[%w%s_%-]+$")

            if not can_create and new_folder_name ~= "" then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0000FF)
                ImGui.Text(ctx, "Invalid characters (use only letters, numbers, spaces, - and _)")
                ImGui.PopStyleColor(ctx)
            end

            if not can_create then
                ImGui.BeginDisabled(ctx)
            end

            if (enter_pressed or ImGui.Button(ctx, "Create", 80, 0)) and can_create then
                -- Create the new folder
                local new_path = normalize_path(folder_browser_path) .. os_separator .. new_folder_name
                local success = reaper.RecursiveCreateDirectory(new_path, 0)
                if success then
                    -- Refresh directory list and select new folder
                    folder_browser_dirs = get_directories(folder_browser_path)
                    selected_folder = new_folder_name
                    new_folder_name = ""
                    ImGui.CloseCurrentPopup(ctx)
                end
            end

            if not can_create then
                ImGui.EndDisabled(ctx)
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Cancel", 80, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                new_folder_name = ""
                ImGui.CloseCurrentPopup(ctx)
            end

            ImGui.EndPopup(ctx)
        end

        -- Rename folder popup
        if ImGui.BeginPopup(ctx, "rename_folder_popup") then
            ImGui.Text(ctx, "Rename folder:")
            ImGui.Separator(ctx)

            ImGui.SetNextItemWidth(ctx, 250)
            if ImGui.IsWindowAppearing(ctx) then
                ImGui.SetKeyboardFocusHere(ctx)
            end

            local rv, buf = ImGui.InputText(ctx, "##renamefoldername", rename_folder_name)
            if rv then
                rename_folder_name = buf
            end

            local enter_pressed = ImGui.IsItemDeactivatedAfterEdit(ctx)

            ImGui.Separator(ctx)

            local can_rename = rename_folder_name ~= "" and rename_folder_name:match("^[%w%s_%-]+$") and
                rename_folder_name ~= selected_folder

            if not can_rename and rename_folder_name ~= "" then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF0000FF)
                if rename_folder_name == selected_folder then
                    ImGui.Text(ctx, "Name unchanged")
                else
                    ImGui.Text(ctx, "Invalid characters")
                end
                ImGui.PopStyleColor(ctx)
            end

            if not can_rename then
                ImGui.BeginDisabled(ctx)
            end

            if (enter_pressed or ImGui.Button(ctx, "Rename", 80, 0)) and can_rename then
                local old_path = normalize_path(folder_browser_path) .. os_separator .. selected_folder
                local new_path = normalize_path(folder_browser_path) .. os_separator .. rename_folder_name

                -- Use OS command to rename
                local cmd
                if os_separator == "\\" then
                    cmd = string.format('move "%s" "%s"', old_path, new_path)
                else
                    cmd = string.format('mv "%s" "%s"', old_path, new_path)
                end
                os.execute(cmd)

                -- Refresh directory list
                folder_browser_dirs = get_directories(folder_browser_path)
                selected_folder = rename_folder_name
                rename_folder_name = ""
                ImGui.CloseCurrentPopup(ctx)
            end

            if not can_rename then
                ImGui.EndDisabled(ctx)
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Cancel", 80, 0) or ImGui.IsKeyPressed(ctx, ImGui.Key_Escape) then
                rename_folder_name = ""
                ImGui.CloseCurrentPopup(ctx)
            end

            ImGui.EndPopup(ctx)
        end

        -- Select and Cancel buttons
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Select", 95, 0) then
            -- Use the display path (current path + selected folder if any)
            local final_path = display_path

            -- Get the actual project file directory (not recording path)
            local retval, project_file_path = reaper.EnumProjects(-1, "")
            local project_dir
            if project_file_path and project_file_path ~= "" then
                -- Extract directory from project file path using split_path
                local parts = split_path(project_file_path)
                -- Remove the filename (last part) to get directory
                table.remove(parts, #parts)
                -- Reconstruct the directory path
                if #parts > 0 then
                    project_dir = table.concat(parts, os_separator)
                    -- Add leading separator for absolute paths on Unix
                    if project_file_path:sub(1, 1) == "/" then
                        project_dir = os_separator .. project_dir
                    end
                end
            end

            if project_dir then
                local normalized_project = normalize_path(project_dir)
                local normalized_final = normalize_path(final_path)

                -- Check if final_path starts with project file directory
                if normalized_final:sub(1, #normalized_project) == normalized_project then
                    -- It's inside project directory - make it relative
                    local relative_part = normalized_final:sub(#normalized_project + 1)
                    -- Remove leading separator
                    if relative_part:sub(1, 1) == os_separator then
                        relative_part = relative_part:sub(2)
                    end
                    final_path = relative_part
                end
            end

            if folder_browser_type == "primary" then
                GetSetProjectInfo_String(0, "RECORD_PATH", final_path, true)
            else
                GetSetProjectInfo_String(0, "RECORD_PATH_SECONDARY", final_path, true)
            end
            show_folder_browser = false
            selected_folder = nil
            ImGui.CloseCurrentPopup(ctx)
        end

        ImGui.EndPopup(ctx)
    end
end

---------------------------------------------------------------------

function consolidate_folders_to_first()
    local num_tracks = CountTracks(0)
    local folders = {}

    -- Collect all folder parent tracks and their children
    local i = 0
    while i < num_tracks do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if folder_depth == 1 then
            local folder_info = { parent = track, children = {} }
            table.insert(folders, folder_info)

            -- Collect children of this folder
            i = i + 1
            local current_depth = 1
            while i < num_tracks and current_depth > 0 do
                local child_track = GetTrack(0, i)
                local child_depth = GetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH")

                table.insert(folder_info.children, child_track)
                current_depth = current_depth + child_depth

                if current_depth <= 0 then
                    break
                end
                i = i + 1
            end
        end
        i = i + 1
    end

    if #folders < 2 then return end

    -- Collect items from each folder (only from tracks within folders)
    for folder_idx, folder in ipairs(folders) do
        local all_folder_tracks = { folder.parent }
        for _, child in ipairs(folder.children) do
            table.insert(all_folder_tracks, child)
        end

        local items_by_group = {}
        local ungrouped_items = {}

        for _, track in ipairs(all_folder_tracks) do
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")

                if group_id > 0 then
                    if not items_by_group[group_id] then
                        items_by_group[group_id] = {}
                    end
                    table.insert(items_by_group[group_id], item)
                else
                    table.insert(ungrouped_items, item)
                end
            end
        end

        folder.items_by_group = items_by_group
        folder.ungrouped_items = ungrouped_items
    end

    -- Find the latest item end time in first folder
    local first_folder = folders[1]
    local latest_end = 0

    for group_id, items in pairs(first_folder.items_by_group) do
        for _, item in ipairs(items) do
            local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                GetMediaItemInfo_Value(item, "D_LENGTH")
            if item_end > latest_end then
                latest_end = item_end
            end
        end
    end

    for _, item in ipairs(first_folder.ungrouped_items) do
        local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
            GetMediaItemInfo_Value(item, "D_LENGTH")
        if item_end > latest_end then
            latest_end = item_end
        end
    end

    -- Get first folder's tracks for moving items to
    local first_folder_tracks = { first_folder.parent }
    for _, child in ipairs(first_folder.children) do
        table.insert(first_folder_tracks, child)
    end

    -- Move items from subsequent folders to first folder
    local current_position = latest_end + 10 -- 10 second gap between folders

    for folder_idx = 2, #folders do
        local source_folder = folders[folder_idx]

        -- Find the earliest position in this entire folder to calculate offset
        local folder_earliest = math.huge

        for group_id, items in pairs(source_folder.items_by_group) do
            for _, item in ipairs(items) do
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                if pos < folder_earliest then
                    folder_earliest = pos
                end
            end
        end

        for _, item in ipairs(source_folder.ungrouped_items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if pos < folder_earliest then
                folder_earliest = pos
            end
        end

        -- Calculate time offset for this entire folder
        local folder_offset = current_position - folder_earliest

        -- Process grouped items - maintain their relative positions within the folder
        for group_id, items in pairs(source_folder.items_by_group) do
            for _, item in ipairs(items) do
                local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local new_pos = original_pos + folder_offset

                -- Find appropriate track in first folder (match relative track position)
                local source_track = GetMediaItem_Track(item)

                -- Find source track's position within its folder
                local source_folder_tracks = { source_folder.parent }
                for _, child in ipairs(source_folder.children) do
                    table.insert(source_folder_tracks, child)
                end

                local source_track_pos = nil
                for idx, folder_track in ipairs(source_folder_tracks) do
                    if folder_track == source_track then
                        source_track_pos = idx
                        break
                    end
                end

                -- Map to corresponding track in first folder
                if source_track_pos and source_track_pos <= #first_folder_tracks then
                    local dest_track = first_folder_tracks[source_track_pos]
                    MoveMediaItemToTrack(item, dest_track)
                    SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
                end
            end
        end

        -- Process ungrouped items - maintain their relative positions within the folder
        for _, item in ipairs(source_folder.ungrouped_items) do
            local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local new_pos = original_pos + folder_offset

            local source_track = GetMediaItem_Track(item)

            -- Find source track's position within its folder
            local source_folder_tracks = { source_folder.parent }
            for _, child in ipairs(source_folder.children) do
                table.insert(source_folder_tracks, child)
            end

            local source_track_pos = nil
            for idx, folder_track in ipairs(source_folder_tracks) do
                if folder_track == source_track then
                    source_track_pos = idx
                    break
                end
            end

            -- Map to corresponding track in first folder
            if source_track_pos and source_track_pos <= #first_folder_tracks then
                local dest_track = first_folder_tracks[source_track_pos]
                MoveMediaItemToTrack(item, dest_track)
                SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
            end
        end

        -- Find the end of all items in this folder to set next folder's position
        local folder_end = 0
        for group_id, items in pairs(source_folder.items_by_group) do
            for _, item in ipairs(items) do
                local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                    GetMediaItemInfo_Value(item, "D_LENGTH")
                if item_end > folder_end then
                    folder_end = item_end
                end
            end
        end

        for _, item in ipairs(source_folder.ungrouped_items) do
            local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                GetMediaItemInfo_Value(item, "D_LENGTH")
            if item_end > folder_end then
                folder_end = item_end
            end
        end

        current_position = folder_end + 10 -- 10 second gap before next folder
    end

    -- Delete only empty folders (2 onwards) - check if folder has no items
    Main_OnCommand(40297, 0) -- Unselect all
    for folder_idx = 2, #folders do
        local folder = folders[folder_idx]
        local has_items = false

        -- Check if folder parent has items
        if CountTrackMediaItems(folder.parent) > 0 then
            has_items = true
        end

        -- Check if any children have items
        if not has_items then
            for _, child in ipairs(folder.children) do
                if CountTrackMediaItems(child) > 0 then
                    has_items = true
                    break
                end
            end
        end

        -- Only delete if folder is completely empty
        if not has_items then
            SetTrackSelected(folder.parent, true)
            for _, child in ipairs(folder.children) do
                SetTrackSelected(child, true)
            end
        end
    end

    Main_OnCommand(40005, 0) -- Remove selected tracks
    Main_OnCommand(40297, 0) -- Unselect all
end

---------------------------------------------------------------------

if init() then
    defer(main)
end
