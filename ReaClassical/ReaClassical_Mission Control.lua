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
    dofile(script_path .. "lib/ReaClassical_Accessible Track Setup.lua")
    return
end

local main, color_to_native, generate_input_options
local reset_pan_on_double_click, get_special_tracks, get_mixer_sends
local get_tracks_from_first_folder, create_mixer_table
local get_current_input_info, apply_input_selection, rename_tracks
local format_pan, sync, auto_assign, reorder_track, delete_mixer_track
local add_mixer_track, init, draw_track_controls
local consolidate_folders_to_first, get_hardware_outputs
local check_dolby_atmos_beam_available, get_track_num_channels
local get_items_at_midpoint

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
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

local initial_project = EnumProjects(-1, "")
local is_valid_project = false
local show_hardware_names = true
local input_dropdown_width = 80

local show_folder_browser = false
local folder_browser_type = nil
local folder_browser_path = ""
local folder_browser_dirs = {}

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('ReaClassical Mission Control')

local MAX_INPUTS = GetNumAudioInputs()
local TRACKS_PER_TAB = 8

local aux_submix_tcp_visible = {}
local folder_tracks = {}
local folder_tcp_visible = {}
local mixer_tcp_visible = {}
local pending_hw_routing_changes = {}
local has_dolby_atmos_beam = false
local dolby_atmos_beam_fx_name = nil
local add_special_counts = {}

local selected_folder
local new_folder_name
local rename_folder_name
local auto_assign_start = 1

set_action_options(2)

local mixer_tracks = {}
local d_tracks = {}
local aux_submix_tracks = {}
local pending_special_move = nil
local aux_submix_names = {}
local aux_submix_pans = {}
local pending_routing_changes = {}
local input_channels = {}
local input_channels_mono = {}
local input_channels_stereo = {}
local mono_has_been_set = {}
local stereo_has_been_set = {}
local is_stereo = {}
local input_disabled = {}
local pan_values = {}
local track_names = {}
local track_has_hyphen = {}
local volume_values = {}
local aux_volume_values = {}
local current_tab = 0
local pending_tab_switch = nil
local selected_track = nil
local selected_special = nil
local sync_needed = false
local pan_reset = {}
local new_track_name = ""
local focus_track_input = nil
local focus_special_input = nil

local function maybe_autofocus_track1()
    if #mixer_tracks > 0 and track_names[1] == "" then
        focus_track_input = 1
    end
end

local pair_words = {
    "2ch", "pair", "paire", "paar", "coppia", "par", "para", "пара", "对", "ペア",
    "쌍", "زوج", "pari", "пар", "πάρoς", "двойка", "קבוצה", "çift",
    "pár", "pāris", "pora", "jozi", "जोड़ी", "คู่", "pasang", "cặp",
    "stereo", "stéréo", "estéreo", "立体声", "ステレオ", "스테레오",
    "ستيريو", "στερεοφωνικός", "סטריאו", "stereotipas", "स्टीरियो",
    "สเตอริโอ", "âm thanh nổi", "paarig", "doppel", "duo"
}

local left_words = {
    "l", "left", "gauche", "sinistra", "izquierda", "esquerda", "ліворуч", "слева", "vlevo", "balra", "vänster",
    "vasakule", "venstre", "vänstra", "levý", "левый", "lijevo", "stânga", "sol", "kushoto", "ซ้าย", "बाएँ", "बायां",
    "links", "linke", "lewa", "lewy", "lewe", "lewo"
}

local right_words = {
    "r", "right", "droite", "destra", "derecha", "direita", "праворуч", "справа", "vpravo", "jobbra", "höger",
    "paremale", "høyre", "högra", "pravý", "правый", "desno", "dreapta", "sağ", "kulia", "ขวา", "दाएँ", "दायां",
    "rechts", "rechte", "prawa", "prawy", "prawe", "prawo"
}

local mono_options = {}
local stereo_options = {}
local track_num_format = "%d"

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local special_track_order = dofile(script_path .. "lib/ReaClassical_Special_Track_Order.lua")
local spare_track = dofile(script_path .. "lib/ReaClassical_Spare_Track.lua")

local function row_select_area(ctx, label, end_x, is_selected)
    local sx, sy = ImGui.GetCursorScreenPos(ctx)
    local width = end_x - ImGui.GetCursorPosX(ctx)
    local spacing_x = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing) or 8
    local hit_width = width - (spacing_x - math.floor(spacing_x / 2))
    ImGui.PushStyleColor(ctx, ImGui.Col_Header, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, 0)
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, 0)
    local clicked = ImGui.Selectable(ctx, label, false, ImGui.SelectableFlags_None, hit_width, 0)
    ImGui.PopStyleColor(ctx, 3)
    if not is_selected and ImGui.IsItemHovered(ctx) then
        ImGui.DrawList_AddRectFilled(ImGui.GetWindowDrawList(ctx), sx, sy,
            sx + width, sy + ImGui.GetTextLineHeightWithSpacing(ctx), 0xADD8E644)
    end
    return clicked
end

local LISTENBACK_JSFX_NAME = "ListenbackMicMonitor"
local LISTENBACK_TRACK_NAME = "LISTENBACK"
local listenback_input_channel = 0
local listenback_is_stereo = false
local playback_hw_channel = 0

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    if gui_mode.accessible() then
        if sync_needed then
            sync_needed = false
            sync()
        end
        gui_mode.switch_window("ReaClassical_Mission Control.lua")
        return
    end

    local current_project = EnumProjects(-1, "")
    if current_project ~= initial_project then
        initial_project = current_project

        selected_track = nil
        focus_track_input = nil
        focus_special_input = nil
        new_track_name = ""
        init()
        maybe_autofocus_track1()
    end

    if is_valid_project and #mixer_tracks > 0 then
        if not ValidatePtr(mixer_tracks[1].mixer_track, "MediaTrack*") then
            init()
        end
    end

    if pending_special_move then
        local move = pending_special_move
        pending_special_move = nil
        Undo_BeginBlock()
        special_track_order.move_routing_track(move.track, move.delta)
        Undo_EndBlock("Reorder Aux/Submix", -1)
        TrackList_AdjustWindows(false)
        UpdateArrange()
        init()
    end

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

    local flags =
        ImGui.WindowFlags_AlwaysAutoResize |
        ImGui.WindowFlags_NoDocking

    local visible, open = ImGui.Begin(ctx, 'ReaClassical Mission Control', true, flags)

    if visible then
        if not is_valid_project then
            ImGui.Text(ctx, "This is not a ReaClassical project.")
            ImGui.Text(ctx, "")
            local os_name = GetOS()
            local modifier = (os_name:find("^OSX") or os_name:find("^macOS")) and "Cmd" or "Ctrl"
            ImGui.Text(ctx, "Please create one via " .. modifier .. "+N then click refresh.")
            ImGui.Text(ctx, "")

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
            return
        end

        local num_tabs = math.ceil(#mixer_tracks / TRACKS_PER_TAB)

        if num_tabs > 1 then
            if ImGui.BeginTabBar(ctx, "##tabs") then
                local target_tab = pending_tab_switch
                pending_tab_switch = nil

                for tab = 0, num_tabs - 1 do
                    local start_idx = tab * TRACKS_PER_TAB + 1
                    local end_idx = math.min(start_idx + TRACKS_PER_TAB - 1, #mixer_tracks)
                    local tab_label = string.format("Tracks %d-%d", start_idx, end_idx)

                    local tab_flags = ImGui.TabItemFlags_None
                    if target_tab ~= nil and target_tab == tab then
                        tab_flags = ImGui.TabItemFlags_SetSelected
                    end

                    if ImGui.BeginTabItem(ctx, tab_label, nil, tab_flags) then
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

        ImGui.Separator(ctx)

        if ImGui.Button(ctx, "↑") and selected_track and selected_track > 1 then
            reorder_track(selected_track, selected_track - 1)
            selected_track = selected_track - 1
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Move selected track up")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "↓") and selected_track and selected_track < #mixer_tracks then
            reorder_track(selected_track, selected_track + 1)
            selected_track = selected_track + 1
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Move selected track down")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Add Track") then
            new_track_name = ""
            ImGui.OpenPopup(ctx, "Add Mixer Track")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Add track to all folders")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Add Empty Folder") then
            local calc = NamedCommandLookup("_RS2c6e13d20ab617b8de2c95a625d6df2fde4265ff")
            Main_OnCommand(calc, 0)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Add Empty Folder")
        end

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

                local button_width = 60
                local spacing = 10
                local total_width = (button_width * 2) + spacing
                local window_width = ImGui.GetWindowWidth(ctx)
                ImGui.SetCursorPosX(ctx, (window_width - total_width) / 2)

                if ImGui.Button(ctx, "Yes", button_width, 0) then
                    DeleteProjectMarker(nil, 996, false)
                    DeleteProjectMarker(nil, 997, false)
                    DeleteProjectMarker(nil, 998, false)
                    DeleteProjectMarker(nil, 999, false)
                    dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
                    init()
                    local whole_view = NamedCommandLookup("_RS63665092232578f8c8d10c5936ca5013a9ecab51")
                    Main_OnCommand(whole_view, 0)
                    ImGui.CloseCurrentPopup(ctx)
                    dofile(script_path .. "ReaClassical_Auto-color project.lua")
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

                local button_width = 60
                local spacing = 10
                local total_width = (button_width * 2) + spacing
                local window_width = ImGui.GetWindowWidth(ctx)
                ImGui.SetCursorPosX(ctx, (window_width - total_width) / 2)

                if ImGui.Button(ctx, "Yes", button_width, 0) then
                    consolidate_folders_to_first()
                    DeleteProjectMarker(nil, 996, false)
                    DeleteProjectMarker(nil, 997, false)
                    DeleteProjectMarker(nil, 998, false)
                    DeleteProjectMarker(nil, 999, false)
                    dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
                    init()
                    ImGui.CloseCurrentPopup(ctx)
                    dofile(script_path .. "ReaClassical_Auto-color project.lua")
                end

                ImGui.SameLine(ctx, 0, spacing)

                if ImGui.Button(ctx, "Cancel", button_width, 0) then
                    ImGui.CloseCurrentPopup(ctx)
                end

                ImGui.EndPopup(ctx)
            end
        end

        if ImGui.BeginPopup(ctx, "Add Mixer Track") then
            ImGui.Text(ctx, "Enter track name:")
            ImGui.Separator(ctx)

            ImGui.SetNextItemWidth(ctx, 200)
            if ImGui.IsWindowAppearing(ctx) then
                ImGui.SetKeyboardFocusHere(ctx)
            end

            local rv, buf = ImGui.InputText(ctx, "##trackname", new_track_name)
            if rv then
                new_track_name = buf
            end

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

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Refresh") then
            init()
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Refresh (useful after undo)")
        end

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

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Auto Rec Inputs") then
            ImGui.OpenPopup(ctx, "Auto Rec Inputs Popup")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx,
                "Auto-assign inputs based on track names\n(pair/stereo = stereo, left/right = mono with pan)")
        end
        if ImGui.BeginPopupModal(ctx, "Auto Rec Inputs Popup", true, ImGui.WindowFlags_AlwaysAutoResize) then
            ImGui.Text(ctx, "Start assignment at hardware input:")
            ImGui.Separator(ctx)
            ImGui.SetNextItemWidth(ctx, 100)
            if ImGui.IsWindowAppearing(ctx) then
                ImGui.SetKeyboardFocusHere(ctx)
            end
            local changed, new_val = ImGui.InputInt(ctx, "##auto_start", auto_assign_start)
            if changed then
                auto_assign_start = math.max(1, math.min(MAX_INPUTS, new_val))
            end
            ImGui.Separator(ctx)
            if ImGui.Button(ctx, "OK", 80, 0) then
                auto_assign(auto_assign_start)
                ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Cancel", 80, 0) then
                ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "HW Outputs") then
            ImGui.OpenPopup(ctx, "HW Outputs Selection")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Route mixer tracks directly to hardware outputs")
        end

        if ImGui.BeginPopupModal(ctx, "HW Outputs Selection", true, ImGui.WindowFlags_AlwaysAutoResize) then
            ImGui.Text(ctx, "Route mixer tracks directly to hardware outputs:")
            ImGui.Separator(ctx)

            local max_hw_outs = GetNumAudioOutputs()

            local max_dropdown_width = 100

            local function estimate_option_width(text)
                return (#text * 7) + 30
            end

            for ch = 0, max_hw_outs - 1 do
                local label
                if show_hardware_names then
                    label = GetOutputChannelName(ch)
                    if not label or label == "" then
                        label = tostring(ch + 1)
                    end
                else
                    label = tostring(ch + 1)
                end
                max_dropdown_width = math.max(max_dropdown_width, estimate_option_width(label))
            end

            for ch = 0, max_hw_outs - 2, 2 do
                local label
                if show_hardware_names then
                    local hw1 = GetOutputChannelName(ch)
                    local hw2 = GetOutputChannelName(ch + 1)
                    if hw1 and hw1 ~= "" and hw2 and hw2 ~= "" then
                        label = string.format("%s+%s", hw1, hw2)
                    else
                        label = string.format("%d+%d", ch + 1, ch + 2)
                    end
                else
                    label = string.format("%d+%d", ch + 1, ch + 2)
                end
                max_dropdown_width = math.max(max_dropdown_width, estimate_option_width(label))
            end

            for _, aux_info in ipairs(aux_submix_tracks) do
                if aux_info.type == "aux" or aux_info.type == "submix" or
                    aux_info.type == "roomtone" or aux_info.type == "reference" or
                    aux_info.type == "rcmaster" or aux_info.type == "live" or aux_info.type == "listenback" or
                    aux_info.type == "playback" then
                    local num_channels = get_track_num_channels(aux_info.track)

                    for ch = 0, max_hw_outs - num_channels, num_channels do
                        local label
                        if show_hardware_names then
                            local hw_names = {}
                            local all_have_names = true
                            for c = ch, ch + num_channels - 1 do
                                local hw_name = GetOutputChannelName(c)
                                if hw_name and hw_name ~= "" then
                                    table.insert(hw_names, hw_name)
                                else
                                    all_have_names = false
                                    break
                                end
                            end

                            if all_have_names then
                                if num_channels == 2 then
                                    label = string.format("%s+%s", hw_names[1], hw_names[2])
                                else
                                    label = string.format("%s-%s", hw_names[1], hw_names[num_channels])
                                end
                            else
                                if num_channels == 2 then
                                    label = string.format("%d+%d", ch + 1, ch + 2)
                                else
                                    label = string.format("%d-%d", ch + 1, ch + num_channels)
                                end
                            end
                        else
                            if num_channels == 2 then
                                label = string.format("%d+%d", ch + 1, ch + 2)
                            else
                                label = string.format("%d-%d", ch + 1, ch + num_channels)
                            end
                        end
                        max_dropdown_width = math.max(max_dropdown_width, estimate_option_width(label))
                    end
                end
            end

            if not pending_hw_routing_changes.manual then
                pending_hw_routing_changes.manual = {}
                pending_hw_routing_changes.special = {}
                pending_hw_routing_changes.current_tab = 0
                for i = 1, #mixer_tracks do
                    local fresh_hw = get_hardware_outputs(mixer_tracks[i].mixer_track)
                    pending_hw_routing_changes.manual[i] = {
                        hw_channel = -1
                    }
                    local first_hw = next(fresh_hw)
                    if first_hw then
                        if first_hw >= 1024 then
                            pending_hw_routing_changes.manual[i].hw_channel = first_hw - 1024
                        else
                            pending_hw_routing_changes.manual[i].hw_channel = first_hw
                        end
                    end
                end
                for idx, aux_info in ipairs(aux_submix_tracks) do
                    if aux_info.type == "aux" or aux_info.type == "submix" or
                        aux_info.type == "roomtone" or aux_info.type == "reference" or
                        aux_info.type == "rcmaster" or aux_info.type == "live" or aux_info.type == "listenback" or
                        aux_info.type == "playback" then
                        local fresh_hw = get_hardware_outputs(aux_info.track)
                        local num_channels = get_track_num_channels(aux_info.track)
                        if aux_info.type == "listenback" then
                            num_channels = 1
                        end

                        pending_hw_routing_changes.special[idx] = {
                            hw_channel = -1,
                            num_channels = num_channels
                        }
                        local first_hw = next(fresh_hw)
                        if first_hw then
                            if first_hw >= 1024 then
                                pending_hw_routing_changes.special[idx].hw_channel = first_hw - 1024
                            else
                                pending_hw_routing_changes.special[idx].hw_channel = first_hw
                            end
                        end
                    end
                end
            end

            local non_disabled_tracks = {}
            for i = 1, #mixer_tracks do
                if not input_disabled[i] then
                    table.insert(non_disabled_tracks, i)
                end
            end

            local num_tabs = math.ceil(#non_disabled_tracks / TRACKS_PER_TAB)

            if num_tabs > 1 then
                if ImGui.BeginTabBar(ctx, "##hw_tabs") then
                    for tab = 0, num_tabs - 1 do
                        local start_idx = tab * TRACKS_PER_TAB + 1
                        local end_idx = math.min(start_idx + TRACKS_PER_TAB - 1, #non_disabled_tracks)
                        local tab_label = string.format("Tracks %d-%d",
                            non_disabled_tracks[start_idx],
                            non_disabled_tracks[end_idx])

                        if ImGui.BeginTabItem(ctx, tab_label) then
                            pending_hw_routing_changes.current_tab = tab

                            for idx = start_idx, end_idx do
                                local i = non_disabled_tracks[idx]
                                ImGui.PushID(ctx, "hw_out_" .. i)

                                ImGui.Text(ctx, string.format(track_num_format .. ": %s", i, track_names[i]))
                                ImGui.SameLine(ctx)

                                local type_label = is_stereo[i] and "[Stereo]" or "[Mono]"
                                ImGui.TextColored(ctx, 0xAAAAAAAA, type_label)

                                ImGui.SameLine(ctx)
                                ImGui.SetCursorPosX(ctx, 350)

                                local options = { "None" }
                                local current_selection = 0

                                if is_stereo[i] then
                                    for ch = 0, max_hw_outs - 2, 2 do
                                        local label
                                        if show_hardware_names then
                                            local hw1 = GetOutputChannelName(ch)
                                            local hw2 = GetOutputChannelName(ch + 1)
                                            if hw1 and hw1 ~= "" and hw2 and hw2 ~= "" then
                                                label = string.format("%s+%s", hw1, hw2)
                                            else
                                                label = string.format("%d+%d", ch + 1, ch + 2)
                                            end
                                        else
                                            label = string.format("%d+%d", ch + 1, ch + 2)
                                        end
                                        table.insert(options, label)

                                        if pending_hw_routing_changes.manual[i].hw_channel == ch then
                                            current_selection = #options - 1
                                        end
                                    end
                                else
                                    for ch = 0, max_hw_outs - 1 do
                                        local label
                                        if show_hardware_names then
                                            label = GetOutputChannelName(ch)
                                            if not label or label == "" then
                                                label = tostring(ch + 1)
                                            end
                                        else
                                            label = tostring(ch + 1)
                                        end
                                        table.insert(options, label)

                                        if pending_hw_routing_changes.manual[i].hw_channel == ch then
                                            current_selection = #options - 1
                                        end
                                    end
                                end
                                ImGui.SetNextItemWidth(ctx, max_dropdown_width)
                                local options_str = table.concat(options, "\0") .. "\0"
                                local changed, new_selection = ImGui.Combo(ctx, "##hw_combo", current_selection,
                                    options_str)

                                if changed then
                                    if new_selection == 0 then
                                        pending_hw_routing_changes.manual[i].hw_channel = -1
                                    else
                                        if is_stereo[i] then
                                            pending_hw_routing_changes.manual[i].hw_channel = (new_selection - 1) * 2
                                        else
                                            pending_hw_routing_changes.manual[i].hw_channel = new_selection - 1
                                        end
                                    end
                                end

                                ImGui.PopID(ctx)
                            end

                            ImGui.EndTabItem(ctx)
                        end
                    end
                    ImGui.EndTabBar(ctx)
                end
            else
                for idx = 1, #non_disabled_tracks do
                    local i = non_disabled_tracks[idx]
                    ImGui.PushID(ctx, "hw_out_" .. i)

                    ImGui.Text(ctx, string.format(track_num_format .. ": %s", i, track_names[i]))
                    ImGui.SameLine(ctx)

                    local type_label = is_stereo[i] and "[Stereo]" or "[Mono]"
                    ImGui.TextColored(ctx, 0xAAAAAAAA, type_label)

                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, 350)

                    local options = { "None" }
                    local current_selection = 0

                    if is_stereo[i] then
                        for ch = 0, max_hw_outs - 2, 2 do
                            local label
                            if show_hardware_names then
                                local hw1 = GetOutputChannelName(ch)
                                local hw2 = GetOutputChannelName(ch + 1)
                                if hw1 and hw1 ~= "" and hw2 and hw2 ~= "" then
                                    label = string.format("%s+%s", hw1, hw2)
                                else
                                    label = string.format("%d+%d", ch + 1, ch + 2)
                                end
                            else
                                label = string.format("%d+%d", ch + 1, ch + 2)
                            end
                            table.insert(options, label)

                            if pending_hw_routing_changes.manual[i].hw_channel == ch then
                                current_selection = #options - 1
                            end
                        end
                    else
                        for ch = 0, max_hw_outs - 1 do
                            local label
                            if show_hardware_names then
                                label = GetOutputChannelName(ch)
                                if not label or label == "" then
                                    label = tostring(ch + 1)
                                end
                            else
                                label = tostring(ch + 1)
                            end
                            table.insert(options, label)

                            if pending_hw_routing_changes.manual[i].hw_channel == ch then
                                current_selection = #options - 1
                            end
                        end
                    end

                    ImGui.SetNextItemWidth(ctx, max_dropdown_width)
                    local options_str = table.concat(options, "\0") .. "\0"
                    local changed, new_selection = ImGui.Combo(ctx, "##hw_combo", current_selection, options_str)

                    if changed then
                        if new_selection == 0 then
                            pending_hw_routing_changes.manual[i].hw_channel = -1
                        else
                            if is_stereo[i] then
                                pending_hw_routing_changes.manual[i].hw_channel = (new_selection - 1) * 2
                            else
                                pending_hw_routing_changes.manual[i].hw_channel = new_selection - 1
                            end
                        end
                    end

                    ImGui.PopID(ctx)
                end
            end

            ImGui.Separator(ctx)

            if ImGui.Button(ctx, "Auto Assign Mixer Tracks", 180, 0) then
                local used_channels = {}

                for i = 1, #mixer_tracks do
                    if not input_disabled[i] then
                        local assigned = false

                        if is_stereo[i] then
                            for ch = 0, max_hw_outs - 2, 2 do
                                if not used_channels[ch] and not used_channels[ch + 1] then
                                    pending_hw_routing_changes.manual[i].hw_channel = ch
                                    used_channels[ch] = true
                                    used_channels[ch + 1] = true
                                    assigned = true
                                    break
                                end
                            end
                        else
                            for ch = 0, max_hw_outs - 1 do
                                if not used_channels[ch] then
                                    pending_hw_routing_changes.manual[i].hw_channel = ch
                                    used_channels[ch] = true
                                    assigned = true
                                    break
                                end
                            end
                        end

                        if not assigned then
                            pending_hw_routing_changes.manual[i].hw_channel = -1
                        end
                    end
                end
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Auto-assign mixer tracks to hardware outputs in order")
            end

            ImGui.Separator(ctx)

            ImGui.Text(ctx, "Special Tracks:")

            for idx, aux_info in ipairs(aux_submix_tracks) do
                if aux_info.type == "aux" or aux_info.type == "submix" or
                    aux_info.type == "roomtone" or aux_info.type == "reference" or
                    aux_info.type == "rcmaster" or aux_info.type == "live" or aux_info.type == "listenback" or
                    aux_info.type == "playback" then
                    ImGui.PushID(ctx, "hw_special_" .. idx)

                    local display_prefix = ""
                    local prefix_color = 0xFFFFFFFF

                    if aux_info.type == "aux" then
                        display_prefix = "@"
                        prefix_color = color_to_native(200, 140, 135)
                    elseif aux_info.type == "submix" then
                        display_prefix = "#"
                        prefix_color = color_to_native(135, 195, 200)
                    elseif aux_info.type == "roomtone" then
                        display_prefix = "RT"
                        prefix_color = color_to_native(200, 160, 110)
                    elseif aux_info.type == "reference" then
                        display_prefix = "REF"
                        prefix_color = color_to_native(180, 180, 180)
                    elseif aux_info.type == "rcmaster" then
                        display_prefix = "RCM"
                        prefix_color = color_to_native(80, 200, 80)
                    elseif aux_info.type == "live" then
                        display_prefix = "LIVE"
                        prefix_color = color_to_native(255, 200, 200)
                    elseif aux_info.type == "listenback" then
                        display_prefix = "LB"
                        prefix_color = color_to_native(170, 200, 255)
                    elseif aux_info.type == "playback" then
                        display_prefix = "PB"
                        prefix_color = color_to_native(80, 200, 180)
                    end

                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, prefix_color)
                    ImGui.Text(ctx, display_prefix)
                    ImGui.PopStyleColor(ctx)

                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, 60)
                    ImGui.Text(ctx, aux_info.name ~= "" and aux_info.name or display_prefix)

                    local num_channels = pending_hw_routing_changes.special[idx].num_channels

                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, 240)
                    local channel_label = string.format("[%dch]", num_channels)
                    ImGui.TextColored(ctx, 0xAAAAAAAA, channel_label)

                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, 350)

                    local options = { "None" }
                    local current_selection = 0

                    for ch = 0, max_hw_outs - num_channels, num_channels do
                        local label
                        if show_hardware_names then
                            local hw_names = {}
                            local all_have_names = true
                            for c = ch, ch + num_channels - 1 do
                                local hw_name = GetOutputChannelName(c)
                                if hw_name and hw_name ~= "" then
                                    table.insert(hw_names, hw_name)
                                else
                                    all_have_names = false
                                    break
                                end
                            end

                            if all_have_names then
                                if num_channels == 1 then
                                    label = hw_names[1]
                                elseif num_channels == 2 then
                                    label = string.format("%s+%s", hw_names[1], hw_names[2])
                                else
                                    label = string.format("%s-%s", hw_names[1], hw_names[num_channels])
                                end
                            else
                                if num_channels == 1 then
                                    label = tostring(ch + 1)
                                elseif num_channels == 2 then
                                    label = string.format("%d+%d", ch + 1, ch + 2)
                                else
                                    label = string.format("%d-%d", ch + 1, ch + num_channels)
                                end
                            end
                        else
                            if num_channels == 2 then
                                label = string.format("%d+%d", ch + 1, ch + 2)
                            else
                                label = string.format("%d-%d", ch + 1, ch + num_channels)
                            end
                        end
                        table.insert(options, label)

                        if pending_hw_routing_changes.special[idx] and
                            pending_hw_routing_changes.special[idx].hw_channel == ch then
                            current_selection = #options - 1
                        end
                    end

                    ImGui.SetNextItemWidth(ctx, max_dropdown_width)
                    local options_str = table.concat(options, "\0") .. "\0"
                    local changed, new_selection = ImGui.Combo(ctx, "##hw_special_combo", current_selection,
                        options_str)

                    if changed then
                        if new_selection == 0 then
                            pending_hw_routing_changes.special[idx].hw_channel = -1
                        else
                            pending_hw_routing_changes.special[idx].hw_channel = (new_selection - 1) * num_channels
                        end
                    end

                    ImGui.PopID(ctx)
                end
            end

            ImGui.Separator(ctx)

            if ImGui.Button(ctx, "Clear All", 120, 0) then
                for i = 1, #mixer_tracks do
                    pending_hw_routing_changes.manual[i].hw_channel = -1
                end
                for idx in ipairs(aux_submix_tracks) do
                    if pending_hw_routing_changes.special[idx] then
                        pending_hw_routing_changes.special[idx].hw_channel = -1
                    end
                end
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Clear all hardware output assignments")
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Apply", 120, 0) then
                for i = 1, #mixer_tracks do
                    local track_info = mixer_tracks[i]
                    local changes = pending_hw_routing_changes.manual[i]

                    local num_hw_sends = GetTrackNumSends(track_info.mixer_track, 1)
                    for j = num_hw_sends - 1, 0, -1 do
                        RemoveTrackSend(track_info.mixer_track, 1, j)
                    end

                    if changes.hw_channel >= 0 then
                        local send_idx = CreateTrackSend(track_info.mixer_track, nil)

                        if is_stereo[i] then
                            SetTrackSendInfo_Value(track_info.mixer_track, 1, send_idx, "I_DSTCHAN",
                                changes.hw_channel)
                            SetTrackSendInfo_Value(track_info.mixer_track, 1, send_idx, "I_SRCCHAN", 0)
                        else
                            SetTrackSendInfo_Value(track_info.mixer_track, 1, send_idx, "I_DSTCHAN",
                                changes.hw_channel | 1024)
                            SetTrackSendInfo_Value(track_info.mixer_track, 1, send_idx, "I_SRCCHAN", 0)
                        end
                    end
                end

                for idx, aux_info in ipairs(aux_submix_tracks) do
                    if pending_hw_routing_changes.special[idx] then
                        local changes = pending_hw_routing_changes.special[idx]

                        local num_hw_sends = GetTrackNumSends(aux_info.track, 1)
                        for j = num_hw_sends - 1, 0, -1 do
                            RemoveTrackSend(aux_info.track, 1, j)
                        end

                        if changes.hw_channel >= 0 then
                            local send_idx = CreateTrackSend(aux_info.track, nil)

                            SetTrackSendInfo_Value(aux_info.track, 1, send_idx, "I_DSTCHAN",
                                changes.hw_channel)
                            SetTrackSendInfo_Value(aux_info.track, 1, send_idx, "I_SRCCHAN", 0)
                        end
                    end
                end
                sync_needed = true
                pending_hw_routing_changes.manual = nil
                init()
                ImGui.CloseCurrentPopup(ctx)
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Apply changes and close")
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Cancel", 120, 0) then
                pending_hw_routing_changes.manual = nil
                pending_hw_routing_changes.special = nil
                ImGui.CloseCurrentPopup(ctx)
            end

            ImGui.EndPopup(ctx)
        else
            if pending_hw_routing_changes.manual or pending_hw_routing_changes.special then
                pending_hw_routing_changes.manual = nil
                pending_hw_routing_changes.special = nil
            end
        end

        if has_dolby_atmos_beam then
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Enable Atmos") then
                for i = 1, #mixer_tracks do
                    local track_info = mixer_tracks[i]
                    local track = track_info.mixer_track

                    local fx_count = TrackFX_GetCount(track)
                    local rcfader_idx = nil
                    local fiedler_idx = nil

                    for fx_idx = 0, fx_count - 1 do
                        local _, fx_name = TrackFX_GetFXName(track, fx_idx, "")
                        if fx_name:match("RCFader") then
                            rcfader_idx = fx_idx
                        elseif fx_name:lower():match("dolby atmos beam") then
                            fiedler_idx = fx_idx
                        end
                    end

                    local needs_rcfader_action = false
                    if not rcfader_idx then
                        needs_rcfader_action = true
                    elseif fiedler_idx and rcfader_idx > fiedler_idx then
                        needs_rcfader_action = true
                        TrackFX_Delete(track, rcfader_idx)
                    end

                    if needs_rcfader_action then
                        fx_count = TrackFX_GetCount(track)
                        fiedler_idx = nil

                        for fx_idx = 0, fx_count - 1 do
                            local _, fx_name = TrackFX_GetFXName(track, fx_idx, "")
                            if fx_name:lower():match("dolby atmos beam") then
                                fiedler_idx = fx_idx
                                break
                            end
                        end

                        if fiedler_idx then
                            TrackFX_AddByName(track, "JS:RCFader", false, -1000 - fiedler_idx)
                        else
                            TrackFX_AddByName(track, "JS:RCFader", false, -1)
                        end
                    end

                    fx_count = TrackFX_GetCount(track)
                    rcfader_idx = nil
                    fiedler_idx = nil

                    for fx_idx = 0, fx_count - 1 do
                        local _, fx_name = TrackFX_GetFXName(track, fx_idx, "")
                        if fx_name:match("RCFader") then
                            rcfader_idx = fx_idx
                        elseif fx_name:lower():match("dolby atmos beam") then
                            fiedler_idx = fx_idx
                        end
                    end

                    if not fiedler_idx then
                        if rcfader_idx then
                            TrackFX_AddByName(track, dolby_atmos_beam_fx_name, false,
                                -1000 - (rcfader_idx + 1))
                        else
                            TrackFX_AddByName(track, dolby_atmos_beam_fx_name, false, -1)
                        end
                    end
                end

                for i = 1, #mixer_tracks do
                    local track_info = mixer_tracks[i]
                    local track = track_info.mixer_track

                    local fx_count = TrackFX_GetCount(track)
                    for fx_idx = 0, fx_count - 1 do
                        local _, fx_name = TrackFX_GetFXName(track, fx_idx, "")

                        if fx_name:match("RCFader") then
                            local vol_linear = GetMediaTrackInfo_Value(track, "D_VOL")
                            local vol_db

                            if vol_linear < 0.00000001 then
                                vol_db = -150
                            else
                                vol_db = 20 * math.log(vol_linear, 10)
                            end

                            vol_db = math.max(-150, math.min(12, vol_db))

                            vol_db = math.floor(vol_db * 100 + 0.5) / 100

                            TrackFX_SetParam(track, fx_idx, 0, vol_db)

                            TrackFX_SetEnabled(track, fx_idx, true)
                        elseif fx_name:lower():match("dolby atmos beam") then
                            TrackFX_SetEnabled(track, fx_idx, true)
                        end
                    end
                end

                sync_needed = true
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Setup RCFader→Dolby Atmos Beam, sync fader values, and enable plugins")
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Disable Atmos") then
                for i = 1, #mixer_tracks do
                    local track = mixer_tracks[i].mixer_track
                    local fx_count = TrackFX_GetCount(track)

                    for fx_idx = 0, fx_count - 1 do
                        local _, fx_name = TrackFX_GetFXName(track, fx_idx, "")
                        if fx_name:match("RCFader") or fx_name:lower():match("dolby atmos beam") then
                            TrackFX_SetEnabled(track, fx_idx, false)
                        end
                    end
                end
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Disable RCFader and Dolby Atmos Beam on all mixer tracks")
            end
        end
        ImGui.SameLine(ctx)
        local btn_label = show_hardware_names and "Ch #" or "HW"
        if ImGui.Button(ctx, btn_label) then
            show_hardware_names = not show_hardware_names
            generate_input_options()
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Toggle hardware names / channel numbers")
        end

        if workflow == "Vertical" and #folder_tracks > 0 then
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Folder Visibility") then
                ImGui.OpenPopup(ctx, "folders_visibility_popup")
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Show/hide folders in TCP")
            end

            if ImGui.BeginPopup(ctx, "folders_visibility_popup") then
                ImGui.Text(ctx, "Show folders in TCP:")
                ImGui.Separator(ctx)

                for i, folder_info in ipairs(folder_tracks) do
                    local changed, new_state = ImGui.Checkbox(ctx, folder_info.prefix, folder_tcp_visible[i])

                    if changed then
                        folder_tcp_visible[i] = new_state

                        SetMediaTrackInfo_Value(folder_info.track, "B_SHOWINTCP", new_state and 1 or 0)

                        local folder_idx = folder_info.index
                        local child_idx = folder_idx + 1
                        local depth = 1

                        while child_idx < CountTracks(0) and depth > 0 do
                            local child_track = GetTrack(0, child_idx)
                            local child_depth = GetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH")

                            SetMediaTrackInfo_Value(child_track, "B_SHOWINTCP", new_state and 1 or 0)

                            depth = depth + child_depth
                            child_idx = child_idx + 1
                        end

                        TrackList_AdjustWindows(false)
                        UpdateArrange()

                        SetProjExtState(0, "ReaClassical_MissionControl", "folder_tcp_visible_" .. folder_info.guid,
                            new_state and "1" or "0")
                    end
                end

                ImGui.EndPopup(ctx)
            end
        end

        ImGui.SameLine(ctx)
        local remaining_width = ImGui.GetContentRegionAvail(ctx)
        ImGui.InvisibleButton(ctx, "##clearselect", remaining_width, ImGui.GetTextLineHeight(ctx))
        if ImGui.IsItemClicked(ctx) then
            selected_track = nil
        end

        if #aux_submix_tracks > 0 then
            ImGui.Separator(ctx)
            local expanded
            expanded = ImGui.CollapsingHeader(ctx, "Special Tracks", nil,
                ImGui.TreeNodeFlags_DefaultOpen)

            if expanded then
                for idx, aux_info in ipairs(aux_submix_tracks) do
                    local _, aux_guid = GetSetMediaTrackInfo_String(aux_info.track, "GUID", "", false)
                    ImGui.PushID(ctx, idx .. "_special_" .. aux_guid)

                    local display_prefix = ""
                    local prefix_color = 0xFFFFFFFF

                    if aux_info.type == "aux" then
                        display_prefix = "@"
                        prefix_color = color_to_native(200, 140, 135)
                    elseif aux_info.type == "submix" then
                        display_prefix = "#"
                        prefix_color = color_to_native(135, 195, 200)
                    elseif aux_info.type == "roomtone" then
                        display_prefix = "RT"
                        prefix_color = color_to_native(200, 160, 110)
                    elseif aux_info.type == "reference" then
                        display_prefix = "REF"
                        prefix_color = color_to_native(180, 180, 180)
                    elseif aux_info.type == "live" then
                        display_prefix = "LIVE"
                        prefix_color = color_to_native(255, 200, 200)
                    elseif aux_info.type == "rcmaster" then
                        display_prefix = "RCM"
                        prefix_color = color_to_native(80, 200, 80)
                    elseif aux_info.type == "listenback" then
                        display_prefix = "LB"
                        prefix_color = color_to_native(170, 200, 255)
                    elseif aux_info.type == "playback" then
                        display_prefix = "PB"
                        prefix_color = color_to_native(80, 200, 180)
                    end

                    if selected_special == aux_info.track then
                        local draw_list = ImGui.GetWindowDrawList(ctx)
                        local sx, sy = ImGui.GetCursorScreenPos(ctx)
                        ImGui.DrawList_AddRectFilled(draw_list, sx, sy,
                            sx + ImGui.GetWindowWidth(ctx), sy + ImGui.GetTextLineHeightWithSpacing(ctx),
                            0xADD8E688)
                    end

                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, prefix_color)
                    if row_select_area(ctx, display_prefix, 60,
                            selected_special == aux_info.track) then
                        selected_special = aux_info.track
                        selected_track = nil
                    end
                    ImGui.PopStyleColor(ctx)

                    local can_rename = (aux_info.type == "aux" or aux_info.type == "submix" or aux_info.type == "reference")

                    local name_col_x = 60
                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, name_col_x)

                    if can_rename then
                        ImGui.SetNextItemWidth(ctx, 180)

                        if focus_special_input == idx then
                            ImGui.SetKeyboardFocusHere(ctx)
                            focus_special_input = nil
                        end

                        local placeholder = (idx == 1 and aux_info.type == "aux") and "Enter names..." or ""
                        local changed_name, new_name = ImGui.InputTextWithHint(ctx, "##specialname" .. idx, placeholder,
                            aux_submix_names[idx])
                        if changed_name then
                            aux_submix_names[idx] = new_name
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

                        if ImGui.IsItemActive(ctx) then
                            if ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and not ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                if idx < #aux_submix_tracks then
                                    focus_special_input = idx + 1
                                else
                                    focus_special_input = 1
                                end
                            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                                if idx > 1 then
                                    focus_special_input = idx - 1
                                else
                                    focus_special_input = #aux_submix_tracks
                                end
                            end
                        end
                    elseif aux_info.type == "listenback" then
                        ImGui.SetNextItemWidth(ctx, 180)
                        local lb_options = is_stereo and stereo_options or mono_options
                        local lb_mono_opts = {}
                        if listenback_input_channel == 0 then
                            table.insert(lb_mono_opts, "Select Ch")
                        else
                            table.insert(lb_mono_opts, "None")
                        end
                        for ch_idx = 1, MAX_INPUTS do
                            local opt_text
                            if show_hardware_names then
                                local hw_name = GetInputChannelName(ch_idx - 1)
                                if hw_name and hw_name ~= "" then
                                    opt_text = hw_name
                                else
                                    opt_text = tostring(ch_idx)
                                end
                            else
                                opt_text = tostring(ch_idx)
                            end
                            table.insert(lb_mono_opts, opt_text)
                        end
                        local lb_opts_str = table.concat(lb_mono_opts, "\0") .. "\0"
                        local lb_changed, lb_new_input = ImGui.Combo(ctx, "##lb_input" .. idx, listenback_input_channel,
                            lb_opts_str)
                        if lb_changed then
                            listenback_input_channel = lb_new_input
                            local rec_input
                            if lb_new_input == 0 then
                                rec_input = -1
                            else
                                rec_input = (lb_new_input - 1)
                            end
                            SetMediaTrackInfo_Value(aux_info.track, "I_RECINPUT", rec_input)
                        end
                    elseif aux_info.type == "playback" then
                        ImGui.SetNextItemWidth(ctx, 180)
                        local pb_opts = {}
                        if playback_hw_channel == 0 then
                            table.insert(pb_opts, "Select pair")
                        else
                            table.insert(pb_opts, "None")
                        end
                        local num_hw_outs = GetNumAudioOutputs()
                        for ch = 0, num_hw_outs - 2, 2 do
                            local opt_text
                            if show_hardware_names then
                                local hw1 = GetOutputChannelName(ch)
                                local hw2 = GetOutputChannelName(ch + 1)
                                if hw1 and hw1 ~= "" and hw2 and hw2 ~= "" then
                                    opt_text = hw1 .. "+" .. hw2
                                else
                                    opt_text = string.format("%d+%d", ch + 1, ch + 2)
                                end
                            else
                                opt_text = string.format("%d+%d", ch + 1, ch + 2)
                            end
                            table.insert(pb_opts, opt_text)
                        end
                        local pb_opts_str = table.concat(pb_opts, "\0") .. "\0"
                        local pb_changed, pb_new_sel = ImGui.Combo(ctx, "##pb_hw" .. idx, playback_hw_channel,
                            pb_opts_str)
                        if pb_changed then
                            playback_hw_channel = pb_new_sel
                            if pb_new_sel == 0 then
                                if GetTrackNumSends(aux_info.track, 1) > 0 then
                                    SetTrackSendInfo_Value(aux_info.track, 1, 0, "I_DSTCHAN", -1)
                                end
                            else
                                local dst_ch = (pb_new_sel - 1) * 2
                                if GetTrackNumSends(aux_info.track, 1) == 0 then
                                    CreateTrackSend(aux_info.track, nil)
                                end
                                SetTrackSendInfo_Value(aux_info.track, 1, 0, "I_DSTCHAN", dst_ch)
                                SetTrackSendInfo_Value(aux_info.track, 1, 0, "I_SRCCHAN", 0)
                            end
                        end
                    else
                        ImGui.Dummy(ctx, 180, ImGui.GetTextLineHeight(ctx))
                    end

                    local pan_col_x = name_col_x + 190
                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, pan_col_x)

                    local is_muted = GetMediaTrackInfo_Value(aux_info.track, "B_MUTE") == 1
                    if is_muted then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF0000FF)
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFF3333FF)
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCC0000FF)
                        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)
                    end
                    if ImGui.Button(ctx, "M##auxmute" .. idx, 25, 0) then
                        SetMediaTrackInfo_Value(aux_info.track, "B_MUTE", is_muted and 0 or 1)
                    end
                    if is_muted then
                        ImGui.PopStyleColor(ctx, 4)
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Mute")
                    end

                    ImGui.SameLine(ctx)
                    local is_soloed = GetMediaTrackInfo_Value(aux_info.track, "I_SOLO") > 0
                    if is_soloed then
                        ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFFFF00FF)
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFFFF66FF)
                        ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCCCC00FF)
                        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x000000FF)
                    end
                    if ImGui.Button(ctx, "S##auxsolo" .. idx, 25, 0) then
                        SetMediaTrackInfo_Value(aux_info.track, "I_SOLO", is_soloed and 0 or 2)
                    end
                    if is_soloed then
                        ImGui.PopStyleColor(ctx, 4)
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Solo")
                    end

                    ImGui.SameLine(ctx)
                    ImGui.SetNextItemWidth(ctx, 150)
                    local changed_pan, new_pan = ImGui.SliderDouble(ctx, "##specialpan" .. idx, aux_submix_pans[idx],
                        -1.0, 1.0, format_pan(aux_submix_pans[idx]))

                    new_pan = reset_pan_on_double_click("##specialpan" .. idx, new_pan, 0.0)

                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Pan (double-click center, right-click to type)")
                    end

                    if changed_pan or new_pan ~= aux_submix_pans[idx] then
                        aux_submix_pans[idx] = new_pan
                        SetMediaTrackInfo_Value(aux_info.track, "D_PAN", new_pan)
                    end

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
                            local input = buf:gsub("%s+", "")
                            local input_upper = input:upper()

                            if input_upper == "C" or input == "" then
                                pan_val = 0.0
                            elseif input_upper == "L" then
                                pan_val = -1.0
                            elseif input_upper == "R" then
                                pan_val = 1.0
                            else
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

                    ImGui.SameLine(ctx)
                    ImGui.SetNextItemWidth(ctx, 200)
                    local volume_db = 20 *
                        math.log(aux_volume_values[idx] > 0.0000001 and aux_volume_values[idx] or 0.0000001, 10)
                    local fader_pos
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

                    if ImGui.IsItemDeactivated(ctx) and pan_reset["auxvol" .. idx] then
                        new_fader_pos = 0.75
                        changed_fader = true
                        pan_reset["auxvol" .. idx] = nil
                    elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
                        pan_reset["auxvol" .. idx] = true
                    end

                    if changed_fader then
                        local new_db
                        if new_fader_pos <= 0.75 then
                            new_db = -60 + (new_fader_pos / 0.75) * 60
                        else
                            new_db = ((new_fader_pos - 0.75) / 0.25) * 12
                        end
                        local new_vol = 10 ^ (new_db / 20)
                        aux_volume_values[idx] = new_vol
                        SetMediaTrackInfo_Value(aux_info.track, "D_VOL", new_vol)
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Volume (double-click for 0dB, right-click to type dB)")
                    end

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
                                db_val = math.max(-60, math.min(12, db_val))
                                local new_vol = 10 ^ (db_val / 20)
                                aux_volume_values[idx] = new_vol
                                SetMediaTrackInfo_Value(aux_info.track, "D_VOL", new_vol)
                            end
                            ImGui.CloseCurrentPopup(ctx)
                        end
                        ImGui.EndPopup(ctx)
                    end

                    ImGui.SameLine(ctx)
                    if aux_info.type == "listenback" or aux_info.type == "playback" then
                        ImGui.BeginDisabled(ctx)
                    end
                    local changed_tcp, new_tcp = ImGui.Checkbox(ctx, "TCP##tcp" .. idx, aux_submix_tcp_visible[idx])
                    if changed_tcp then
                        aux_submix_tcp_visible[idx] = new_tcp
                        SetMediaTrackInfo_Value(aux_info.track, "B_SHOWINTCP", new_tcp and 1 or 0)
                        TrackList_AdjustWindows(false)
                        UpdateArrange()
                        SetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. aux_guid,
                            new_tcp and "1" or "0")
                    end
                    if aux_info.type == "listenback" or aux_info.type == "playback" then
                        ImGui.EndDisabled(ctx)
                    end
                    if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
                        if aux_info.type == "listenback" then
                            ImGui.SetTooltip(ctx, "Listenback is MCP only")
                        elseif aux_info.type == "playback" then
                            ImGui.SetTooltip(ctx, "Playback is MCP only")
                        else
                            ImGui.SetTooltip(ctx, "Show in TCP")
                        end
                    end

                    ImGui.SameLine(ctx)
                    if aux_info.has_routing then
                        if ImGui.Button(ctx, "Routing##routing") then
                            ImGui.OpenPopup(ctx, "special_routing_popup")
                        end
                        if ImGui.IsItemHovered(ctx) then
                            ImGui.SetTooltip(ctx, "Route to RCMASTER and other Aux/Submix tracks")
                        end

                        if ImGui.BeginPopup(ctx, "special_routing_popup") then
                            local _, rcm_disconnect = GetSetMediaTrackInfo_String(aux_info.track, "P_EXT:rcm_disconnect",
                                "", false)
                            local current_rcm_state = (rcm_disconnect ~= "y")

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

                            local popup_id = "special_" .. aux_info.index
                            if not pending_routing_changes[popup_id] then
                                pending_routing_changes[popup_id] = {
                                    rcm_changed = false,
                                    rcm_state = current_rcm_state,
                                    sends = {}
                                }
                            end

                            local changed_rcm, new_rcm_state = ImGui.Checkbox(ctx, "RCMASTER",
                                pending_routing_changes[popup_id].rcm_state)
                            if changed_rcm then
                                pending_routing_changes[popup_id].rcm_changed = true
                                pending_routing_changes[popup_id].rcm_state = new_rcm_state
                            end

                            ImGui.Separator(ctx)

                            local has_destinations = false
                            for _, dest_aux in ipairs(aux_submix_tracks) do
                                if dest_aux.track ~= aux_info.track and dest_aux.has_routing then
                                    has_destinations = true

                                    local current_state = pending_routing_changes[popup_id].sends[dest_aux.track]
                                    if current_state == nil then
                                        current_state = fresh_aux_sends[dest_aux.track] or false
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
                            local popup_id = "special_" .. aux_info.index
                            if pending_routing_changes[popup_id] then
                                local changes = pending_routing_changes[popup_id]

                                if changes.rcm_changed then
                                    GetSetMediaTrackInfo_String(aux_info.track, "P_EXT:rcm_disconnect",
                                        changes.rcm_state and "" or "y", true)

                                    local base_name = aux_info.full_name:gsub("%-$", "")
                                    GetSetMediaTrackInfo_String(aux_info.track, "P_NAME", base_name, true)

                                    aux_info.has_hyphen = not changes.rcm_state
                                    aux_info.full_name = base_name
                                    sync_needed = true
                                end

                                for dest_track, new_state in pairs(changes.sends) do
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

                                pending_routing_changes[popup_id] = nil
                            end
                        end
                    else
                        ImGui.BeginDisabled(ctx)
                        ImGui.Button(ctx, "Routing##routing_disabled")
                        ImGui.EndDisabled(ctx)
                    end

                    ImGui.SameLine(ctx)
                    if ImGui.Button(ctx, "FX##specialfx") then
                        TrackFX_Show(aux_info.track, 0, 1)
                    end
                    if ImGui.IsItemHovered(ctx) then
                        ImGui.SetTooltip(ctx, "Open FX chain")
                    end

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

        ImGui.Separator(ctx)

        if selected_special and not ValidatePtr(selected_special, "MediaTrack*") then
            selected_special = nil
        end
        local sel_pos
        for i, info in ipairs(aux_submix_tracks) do
            if info.track == selected_special then sel_pos = i break end
        end
        local sel_is_routing = sel_pos ~= nil and aux_submix_tracks[sel_pos].has_routing
        local prev_info = sel_pos and aux_submix_tracks[sel_pos - 1]
        local next_info = sel_pos and aux_submix_tracks[sel_pos + 1]
        local can_move_up = sel_is_routing and prev_info ~= nil and prev_info.has_routing
        local can_move_down = sel_is_routing and next_info ~= nil and next_info.has_routing

        if not can_move_up then ImGui.BeginDisabled(ctx) end
        if ImGui.Button(ctx, "↑##specialup") then
            pending_special_move = { track = selected_special, delta = -1 }
        end
        if not can_move_up then ImGui.EndDisabled(ctx) end
        if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
            ImGui.SetTooltip(ctx, sel_is_routing and "Move selected aux/submix earlier (left in the mixer)"
                or "Select an aux or submix (click its @ / # marker) to move it")
        end

        ImGui.SameLine(ctx)
        if not can_move_down then ImGui.BeginDisabled(ctx) end
        if ImGui.Button(ctx, "↓##specialdown") then
            pending_special_move = { track = selected_special, delta = 1 }
        end
        if not can_move_down then ImGui.EndDisabled(ctx) end
        if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_AllowWhenDisabled) then
            ImGui.SetTooltip(ctx, sel_is_routing and "Move selected aux/submix later (right in the mixer)"
                or "Select an aux or submix (click its @ / # marker) to move it")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Add Special Tracks") then
            ImGui.OpenPopup(ctx, "Add Special Tracks:")
        end

        if ImGui.BeginPopupModal(ctx, "Add Special Tracks:", true, ImGui.WindowFlags_AlwaysAutoResize) then
            local has_roomtone = false
            local has_live = false
            local has_listenback = false
            local has_playback = false
            for _, track_info in ipairs(aux_submix_tracks) do
                if track_info.type == "roomtone" then has_roomtone = true end
                if track_info.type == "live" then has_live = true end
                if track_info.type == "listenback" then has_listenback = true end
                if track_info.type == "playback" then has_playback = true end
            end

            if ImGui.IsWindowAppearing(ctx) then
                add_special_counts = {
                    aux = 0,
                    submix = 0,
                    roomtone = 0,
                    reference = 0,
                    live = 0,
                    listenback = 0,
                    playback_hw = 0
                }
            end

            ImGui.Text(ctx, "Aux:")
            ImGui.SameLine(ctx)
            ImGui.SetCursorPosX(ctx, 150)
            ImGui.SetNextItemWidth(ctx, 100)
            local changed, new_val = ImGui.InputInt(ctx, "##aux", add_special_counts.aux)
            if changed then
                add_special_counts.aux = math.max(0, math.min(99, new_val))
            end

            ImGui.Text(ctx, "Submix:")
            ImGui.SameLine(ctx)
            ImGui.SetCursorPosX(ctx, 150)
            ImGui.SetNextItemWidth(ctx, 100)
            local changed, new_val = ImGui.InputInt(ctx, "##submix", add_special_counts.submix)
            if changed then
                add_special_counts.submix = math.max(0, math.min(99, new_val))
            end

            if has_roomtone then
                ImGui.BeginDisabled(ctx)
                ImGui.Text(ctx, "Room Tone:")
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, 150)
                ImGui.TextDisabled(ctx, "(already exists)")
                ImGui.EndDisabled(ctx)
            else
                ImGui.Text(ctx, "Room Tone:")
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, 150)
                ImGui.SetNextItemWidth(ctx, 100)
                local changed, new_val = ImGui.InputInt(ctx, "##roomtone", add_special_counts.roomtone)
                if changed then
                    add_special_counts.roomtone = math.max(0, math.min(1, new_val))
                end
            end

            ImGui.Text(ctx, "Reference:")
            ImGui.SameLine(ctx)
            ImGui.SetCursorPosX(ctx, 150)
            ImGui.SetNextItemWidth(ctx, 100)
            local changed, new_val = ImGui.InputInt(ctx, "##reference", add_special_counts.reference)
            if changed then
                add_special_counts.reference = math.max(0, math.min(99, new_val))
            end

            if workflow == "Horizontal" then
                if has_live then
                    ImGui.BeginDisabled(ctx)
                    ImGui.Text(ctx, "Live Bounce:")
                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, 150)
                    ImGui.TextDisabled(ctx, "(already exists)")
                    ImGui.EndDisabled(ctx)
                else
                    ImGui.Text(ctx, "Live Bounce:")
                    ImGui.SameLine(ctx)
                    ImGui.SetCursorPosX(ctx, 150)
                    ImGui.SetNextItemWidth(ctx, 100)
                    local changed, new_val = ImGui.InputInt(ctx, "##live", add_special_counts.live)
                    if changed then
                        add_special_counts.live = math.max(0, math.min(1, new_val))
                    end
                end
            end

            if has_listenback then
                ImGui.BeginDisabled(ctx)
                ImGui.Text(ctx, "Listenback:")
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, 150)
                ImGui.TextDisabled(ctx, "(already exists)")
                ImGui.EndDisabled(ctx)
            else
                ImGui.Text(ctx, "Listenback:")
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, 150)
                ImGui.SetNextItemWidth(ctx, 100)
                local changed, new_val = ImGui.InputInt(ctx, "##listenback", add_special_counts.listenback)
                if changed then
                    add_special_counts.listenback = math.max(0, math.min(1, new_val))
                end
            end

            if has_playback then
                ImGui.BeginDisabled(ctx)
                ImGui.Text(ctx, "Playback:")
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, 150)
                ImGui.TextDisabled(ctx, "(already exists)")
                ImGui.EndDisabled(ctx)
            else
                ImGui.Text(ctx, "Playback:")
                ImGui.SameLine(ctx)
                ImGui.SetCursorPosX(ctx, 150)
                ImGui.SetNextItemWidth(ctx, 100)
                local changed, new_val = ImGui.InputInt(ctx, "##playback_hw", add_special_counts.playback_hw)
                if changed then
                    add_special_counts.playback_hw = math.max(0, math.min(1, new_val))
                end
            end

            ImGui.Separator(ctx)

            if ImGui.Button(ctx, "OK", 100, 0) then
                for i = 1, add_special_counts.aux do
                    dofile(script_path .. "lib/ReaClassical_Add Aux.lua")
                end

                for i = 1, add_special_counts.submix do
                    dofile(script_path .. "lib/ReaClassical_Add Submix.lua")
                end

                if not has_roomtone and add_special_counts.roomtone > 0 then
                    dofile(script_path .. "lib/ReaClassical_Add RoomTone Track.lua")
                end

                for i = 1, add_special_counts.reference do
                    dofile(script_path .. "lib/ReaClassical_Add Ref Track.lua")
                end

                if not has_listenback and add_special_counts.listenback > 0 then
                    Undo_BeginBlock()
                    PreventUIRefresh(1)

                    local insert_pos = CountTracks(0)
                    InsertTrackAtIndex(insert_pos, false)
                    local lb_track = GetTrack(0, insert_pos)

                    GetSetMediaTrackInfo_String(lb_track, "P_EXT:listenback", "y", true)
                    GetSetMediaTrackInfo_String(lb_track, "P_NAME", "LISTENBACK", true)

                    SetMediaTrackInfo_Value(lb_track, "I_RECINPUT", -1)
                    SetMediaTrackInfo_Value(lb_track, "I_RECMON", 1)
                    SetMediaTrackInfo_Value(lb_track, "I_RECARM", 1)
                    SetMediaTrackInfo_Value(lb_track, "I_RECMODE", 2)
                    SetMediaTrackInfo_Value(lb_track, "B_MAINSEND", 1)
                    SetMediaTrackInfo_Value(lb_track, "B_SHOWINTCP", 0)
                    SetMediaTrackInfo_Value(lb_track, "B_SHOWINMIXER", 1)
                    SetMediaTrackInfo_Value(lb_track, "D_VOL", 1.0)

                    local fx_idx = TrackFX_AddByName(lb_track, LISTENBACK_JSFX_NAME, false, -1)
                    if fx_idx < 0 then
                        TrackFX_AddByName(lb_track, "JS:" .. LISTENBACK_JSFX_NAME, false, -1)
                    end

                    PreventUIRefresh(-1)
                    Undo_EndBlock("Add Listenback Track", -1)
                end

                if not has_live and add_special_counts.live > 0 then
                    dofile(script_path .. "lib/ReaClassical_Add Live Bounce Track.lua")
                end

                if not has_playback and add_special_counts.playback_hw > 0 then
                    local rcmaster_track
                    local rcmaster_idx_pos
                    for i = 0, CountTracks(0) - 1 do
                        local t = GetTrack(0, i)
                        local _, rcm_state = GetSetMediaTrackInfo_String(t, "P_EXT:rcmaster", "", false)
                        local _, t_name = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
                        if rcm_state == "y" or t_name == "RCMASTER" then
                            rcmaster_track = t
                            rcmaster_idx_pos = i
                            break
                        end
                    end
                    if rcmaster_track then
                        Undo_BeginBlock()
                        InsertTrackAtIndex(rcmaster_idx_pos + 1, true)
                        local pb_track = GetTrack(0, rcmaster_idx_pos + 1)
                        GetSetMediaTrackInfo_String(pb_track, "P_NAME", "PLAYBACK", true)
                        GetSetMediaTrackInfo_String(pb_track, "P_EXT:playback", "y", true)
                        CreateTrackSend(rcmaster_track, pb_track)
                        SetMediaTrackInfo_Value(pb_track, "B_MAINSEND", 0)
                        SetMediaTrackInfo_Value(pb_track, "B_MUTE", 1)
                        SetTrackColor(pb_track, require("ReaClassical_Colors_Table").playback)
                        SetMediaTrackInfo_Value(pb_track, "B_SHOWINTCP", 0)
                        SetMediaTrackInfo_Value(pb_track, "B_SHOWINMIXER", 1)
                        if workflow == "Vertical" then
                            dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
                        else
                            dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
                        end
                        Undo_EndBlock("Add Playback Track", -1)
                    end
                end

                init()
                ImGui.CloseCurrentPopup(ctx)
            end

            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Cancel", 100, 0) then
                ImGui.CloseCurrentPopup(ctx)
            end

            ImGui.EndPopup(ctx)
        end

        local system = GetOS()
        local is_mac = string.find(system, "^OSX") or string.find(system, "^macOS")
        local ctrl_key = is_mac and "Cmd" or "Ctrl"

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
            ImGui.SetTooltip(ctx, "Open Record Panel (" .. ctrl_key .. "+Enter)")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Auto-color project") then
            dofile(script_path .. "ReaClassical_Auto-color project.lua")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Auto-color Project")
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
            local source_audition = NamedCommandLookup("_RS238a7e78cb257490252b3dde18274d00f9a1cf10")
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

        if gui_mode.imgui_shortcut(ImGui, ctx) then gui_mode.toggle_and_announce() end
        if gui_mode.imgui_close_shortcut(ImGui, ctx) then open = false end
        ImGui.End(ctx)
    end

    if sync_needed then
        sync_needed = false
        sync()
    end

    if open then
        defer(main)
    end
end

function color_to_native(r, g, b)
    return (r << 24) | (g << 16) | (b << 8) | 0xFF
end

function generate_input_options()
    mono_options = {}
    stereo_options = {}
    table.insert(mono_options, "None")
    table.insert(stereo_options, "None")

    local max_chars = 4

    for i = 1, MAX_INPUTS do
        local option_text
        if show_hardware_names then
            local hw_name = GetInputChannelName(i - 1)
            if hw_name and hw_name ~= "" then
                option_text = hw_name
            else
                option_text = tostring(i)
            end
        else
            option_text = tostring(i)
        end
        table.insert(mono_options, option_text)
        max_chars = math.max(max_chars, #option_text)
    end

    for i = 1, MAX_INPUTS - 1 do
        local option_text
        if show_hardware_names then
            local hw_name1 = GetInputChannelName(i - 1)
            local hw_name2 = GetInputChannelName(i)

            if hw_name1 and hw_name1 ~= "" and hw_name2 and hw_name2 ~= "" then
                local base1 = hw_name1:match("^(.+)%s+%d+$") or hw_name1
                local base2 = hw_name2:match("^(.+)%s+%d+$") or hw_name2

                if base1 == base2 then
                    option_text = string.format("%s+%s", hw_name1, hw_name2)
                else
                    option_text = string.format("%s/%s", hw_name1, hw_name2)
                end
            else
                option_text = string.format("%d+%d", i, i + 1)
            end
        else
            option_text = string.format("%d+%d", i, i + 1)
        end
        table.insert(stereo_options, option_text)
        max_chars = math.max(max_chars, #option_text)
    end

    input_dropdown_width = math.max(80, (max_chars * 7) + 30)
end

function reset_pan_on_double_click(id, value, default)
    if ImGui.IsItemDeactivated(ctx) and pan_reset[id] then
        pan_reset[id] = nil
        return default
    elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
        pan_reset[id] = true
    end

    return value
end

function get_special_tracks()
    local tracks = {}

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, playback_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y"
            or live_state == "y" or rcmaster_state == "y" or listenback_state == "y"
            or playback_state == "y" then
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
            elseif listenback_state == "y" then
                track_type = "listenback"
            elseif rcmaster_state == "y" then
                track_type = "rcmaster"
            elseif playback_state == "y" then
                track_type = "playback"
            end

            local _, rcm_disconnect = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
            local has_hyphen = (rcm_disconnect == "y")

            local display_name

            if track_type == "aux" or track_type == "submix" then
                display_name = name:gsub("^[@#]:?", ""):gsub("%-$", "")
            elseif track_type == "reference" then
                display_name = name:gsub("^REF:?", ""):gsub("%-$", "")
            elseif track_type == "roomtone" then
                display_name = ""
            elseif track_type == "live" then
                display_name = ""
            elseif track_type == "listenback" then
                display_name = ""
            elseif track_type == "rcmaster" then
                display_name = ""
            elseif track_type == "playback" then
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

    local type_priority = {
        aux = 1,
        submix = 1,
        roomtone = 3,
        rcmaster = 4,
        live = 5,
        reference = 6,
        listenback = 7,
        playback = 8
    }

    table.sort(tracks, function(a, b)
        local priority_a = type_priority[a.type] or 99
        local priority_b = type_priority[b.type] or 99
        if priority_a ~= priority_b then
            return priority_a < priority_b
        else
            return a.index < b.index
        end
    end)

    return tracks
end

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

function get_tracks_from_first_folder()
    local tracks = {}
    local first_folder_idx = nil

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then
            first_folder_idx = i
            break
        end
    end

    if not first_folder_idx then return tracks end

    table.insert(tracks, GetTrack(0, first_folder_idx))

    local i = first_folder_idx + 1
    local depth = 1

    while i < CountTracks(0) and depth > 0 do
        local track = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        local _, spare_state = GetSetMediaTrackInfo_String(track, "P_EXT:spare", "", false)
        if depth > 0 and spare_state ~= "y" then
            table.insert(tracks, track)
        end

        depth = depth + folder_change
        i = i + 1
    end

    return tracks
end

function create_mixer_table()
    local tracks = {}

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, spare_state = GetSetMediaTrackInfo_String(track, "P_EXT:spare", "", false)
        if mixer_state == "y" and spare_state ~= "y" then
            table.insert(tracks, {
                mixer_track = track,
                mixer_index = i
            })
        end
    end
    return tracks
end

function get_current_input_info(d_track)
    local recInput = GetMediaTrackInfo_Value(d_track, "I_RECINPUT")
    local is_stereo_input
    local channel_index

    if recInput < 0 then
        channel_index = 0
        is_stereo_input = false
    elseif recInput >= 1024 then
        local ch = recInput - 1024
        channel_index = ch + 1
        is_stereo_input = true
    else
        channel_index = recInput + 1
        is_stereo_input = false
    end

    return channel_index, is_stereo_input
end

function apply_input_selection(d_track, is_stereo_input, channel_index)
    local recInput

    if not is_stereo_input then
        if channel_index == 0 then
            recInput = -1
        else
            recInput = channel_index - 1
        end
    else
        if channel_index == 0 then
            recInput = -1
        else
            recInput = 1024 + (channel_index - 1)
        end
    end

    SetMediaTrackInfo_Value(d_track, "I_RECINPUT", recInput)
end

function rename_tracks(track_info, new_name, disconnect_rcm)
    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect", disconnect_rcm and "y" or "", true)

    local clean_name = new_name:gsub("%-$", "")

    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_NAME", "M:" .. clean_name, true)

    local mixer_position = nil
    for idx, info in ipairs(mixer_tracks) do
        if info.mixer_track == track_info.mixer_track then
            mixer_position = idx
            break
        end
    end

    if not mixer_position then return end

    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if folder_depth == 1 then
            folder_number = folder_number + 1

            local track_index = i + (mixer_position - 1)
            local target_track = GetTrack(0, track_index)

            if target_track then
                GetSetMediaTrackInfo_String(target_track, "P_EXT:rcm_disconnect", disconnect_rcm and "y" or "", true)

                local prefix = ""
                if workflow == "Vertical" then
                    if folder_number == 1 then
                        prefix = "D:"
                    else
                        prefix = "S" .. (folder_number - 1) .. ":"
                    end
                end

                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. clean_name, true)
            end
        end
    end
end

function format_pan(panVal)
    if math.abs(panVal) < 0.01 then
        return "C"
    elseif panVal < 0 then
        return tostring(math.floor(-panVal * 100 + 0.5)) .. "L"
    else
        return tostring(math.floor(panVal * 100 + 0.5)) .. "R"
    end
end

function sync()
    if workflow == "Vertical" then
        dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
    elseif workflow == "Horizontal" then
        dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
    end
end

function auto_assign(start_input)
    start_input = start_input or 1
    local input_channel = start_input - 1

    for i = 1, #mixer_tracks do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i]
        local track_name = track_names[i]
        local lower_name = track_name:lower()

        local is_pair = false
        for _, word in ipairs(pair_words) do
            if lower_name:match("%s" .. word .. "$") or lower_name:match(word .. "$") then
                is_pair = true
                break
            end
        end

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

        if is_left then
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", -1.0)
        elseif is_right then
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", 1.0)
        elseif is_pair then
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", 0.0)
        end

        if input_channel < MAX_INPUTS then
            if is_pair and (input_channel + 1 < MAX_INPUTS) then
                SetMediaTrackInfo_Value(d_track, "I_RECINPUT", 1024 + input_channel)
                is_stereo[i] = true
                input_channels[i] = input_channel + 1
                input_channels_stereo[i] = input_channel + 1
                stereo_has_been_set[i] = true
                input_channel = input_channel + 2
            else
                SetMediaTrackInfo_Value(d_track, "I_RECINPUT", input_channel)
                is_stereo[i] = false
                input_channels[i] = input_channel + 1
                input_channels_mono[i] = input_channel + 1
                mono_has_been_set[i] = true
                input_channel = input_channel + 1
            end
        else
            SetMediaTrackInfo_Value(d_track, "I_RECINPUT", -1)
            input_channels[i] = 0
            if is_stereo[i] then
                input_channels_stereo[i] = 0
            else
                input_channels_mono[i] = 0
            end
        end
    end

    if workflow == "Vertical" then
        sync()
    end

    init()
end

function reorder_track(from_idx, to_idx)
    if from_idx == to_idx then return end

    local from_track = mixer_tracks[from_idx].mixer_track

    local before_track
    if to_idx < from_idx then
        before_track = mixer_tracks[to_idx].mixer_track
    else
        if to_idx < #mixer_tracks then
            before_track = mixer_tracks[to_idx + 1].mixer_track
        else
            before_track = nil
        end
    end

    Main_OnCommand(40297, 0)
    SetTrackSelected(from_track, true)

    local before_track_idx
    if before_track then
        before_track_idx = GetMediaTrackInfo_Value(before_track, "IP_TRACKNUMBER") - 1
    else
        before_track_idx = CountTracks(0)
    end

    ReorderSelectedTracks(before_track_idx, 0)

    sync()

    init()
end

function delete_mixer_track(track_info)
    Main_OnCommand(40297, 0)

    SetTrackSelected(track_info.mixer_track, true)

    dofile(script_path .. "lib/ReaClassical_Delete Track From All Groups.lua")

    selected_track = nil
    init()
end

function add_mixer_track(name)
    if name == "" then return end

    Undo_BeginBlock()

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

    local saved_rec_inputs = {}
    for i = 0, num_of_tracks - 1 do
        local track = GetTrack(0, i)
        local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
        local recInput = GetMediaTrackInfo_Value(track, "I_RECINPUT")
        saved_rec_inputs[guid] = recInput
    end

    PreventUIRefresh(1)

    if spare_track.activate(name) then
        if folder_count > 1 then
            dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
        else
            dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
        end
        for i = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, i)
            local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
            if saved_rec_inputs[guid] then
                SetMediaTrackInfo_Value(track, "I_RECINPUT", saved_rec_inputs[guid])
            end
        end
        PreventUIRefresh(-1)
        Undo_EndBlock("Add Track to Folder", -1)
        selected_track = nil
        init()
        return
    end

    local folder_indices = {}
    local folder_colors = {}
    local folder_seen = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth == 1 then
            folder_seen = folder_seen + 1
            local folder_color = GetTrackColor(track)
            if folder_color == 0 and i + 1 < CountTracks(0) then
                local child_track = GetTrack(0, i + 1)
                folder_color = GetTrackColor(child_track)
            end
            table.insert(folder_indices, i)
            table.insert(folder_colors, folder_color)
        end
    end

    for f = #folder_indices, 1, -1 do
        local i = folder_indices[f]
        InsertTrackAtIndex(i + child_count, 1)
        local new_track_in_folder = GetTrack(0, i + child_count)
        SetMediaTrackInfo_Value(new_track_in_folder, "I_RECINPUT", -1)
        if folder_colors[f] ~= 0 then
            SetTrackColor(new_track_in_folder, folder_colors[f])
        end
        if f == 1 then
            GetSetMediaTrackInfo_String(new_track_in_folder, "P_EXT:Destination", "y", true)
        else
            GetSetMediaTrackInfo_String(new_track_in_folder, "P_EXT:Source", "y", true)
        end
    end

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth == -1 then
            SetOnlyTrackSelected(track)
            ReorderSelectedTracks(i - 1, 0)
        end
    end

    local tracks_per_folder = child_count + 2
    local index = (folder_count * tracks_per_folder) + tracks_per_folder - 1
    InsertTrackAtIndex(index, 1)
    local new_track = GetTrack(0, index)
    SetMediaTrackInfo_Value(new_track, "I_RECINPUT", -1)
    GetSetMediaTrackInfo_String(new_track, "P_NAME", "M:" .. name, true)
    GetSetMediaTrackInfo_String(new_track, "P_EXT:mix_order", index, true)
    GetSetMediaTrackInfo_String(new_track, "P_EXT:mixer", "y", true)

    if folder_count > 1 then
        dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
    else
        dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
    end

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

    selected_track = nil
    init()
end

function init()
    generate_input_options()

    local _, current_workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = current_workflow
    if current_workflow == "" then
        is_valid_project = false
        return false
    end

    d_tracks = get_tracks_from_first_folder()

    mixer_tracks = create_mixer_table()

    aux_submix_tracks = get_special_tracks()

    aux_submix_names = {}
    aux_submix_pans = {}
    aux_submix_tcp_visible = {}
    for i, aux_info in ipairs(aux_submix_tracks) do
        aux_submix_names[i] = aux_info.name
        aux_submix_pans[i] = GetMediaTrackInfo_Value(aux_info.track, "D_PAN")

        local current_tcp_state = GetMediaTrackInfo_Value(aux_info.track, "B_SHOWINTCP")
        aux_submix_tcp_visible[i] = (current_tcp_state == 1)

        local _, guid = GetSetMediaTrackInfo_String(aux_info.track, "GUID", "", false)
        SetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid, (current_tcp_state == 1) and "1" or "0")
    end

    for i, aux_info in ipairs(aux_submix_tracks) do
        if aux_info.type == "listenback" then
            local rec_input = GetMediaTrackInfo_Value(aux_info.track, "I_RECINPUT")
            if rec_input < 0 then
                listenback_input_channel = 0
            elseif rec_input >= 1024 then
                listenback_input_channel = (rec_input - 1024) + 1
            else
                listenback_input_channel = rec_input + 1
            end
            break
        end
    end

    for i, aux_info in ipairs(aux_submix_tracks) do
        if aux_info.type == "playback" then
            if GetTrackNumSends(aux_info.track, 1) > 0 then
                local dst = math.floor(GetTrackSendInfo_Value(aux_info.track, 1, 0, "I_DSTCHAN"))
                playback_hw_channel = math.floor(dst / 2) + 1
            else
                playback_hw_channel = 0
            end
            break
        end
    end

    folder_tracks = {}
    folder_tcp_visible = {}
    if workflow == "Vertical" then
        local folder_count = 0
        for i = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, i)
            local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

            if folder_depth == 1 then
                folder_count = folder_count + 1
                local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
                local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)

                local prefix = track_name:match("^([^:]+):")
                if not prefix then prefix = "Folder " .. folder_count end

                local current_tcp_state = GetMediaTrackInfo_Value(track, "B_SHOWINTCP")

                table.insert(folder_tracks, {
                    track = track,
                    prefix = prefix,
                    guid = guid,
                    index = i
                })

                table.insert(folder_tcp_visible, current_tcp_state == 1)

                SetProjExtState(0, "ReaClassical_MissionControl", "folder_tcp_visible_" .. guid,
                    (current_tcp_state == 1) and "1" or "0")
            end
        end
    end

    if #mixer_tracks == 0 then
        return false
    end

    if #d_tracks < #mixer_tracks then
        return false
    end

    mixer_tcp_visible = {}
    for i = 1, #mixer_tracks do
        local track_info = mixer_tracks[i]
        local _, guid = GetSetMediaTrackInfo_String(track_info.mixer_track, "GUID", "", false)

        local current_tcp_state = GetMediaTrackInfo_Value(track_info.mixer_track, "B_SHOWINTCP")
        mixer_tcp_visible[i] = (current_tcp_state == 1)

        SetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. guid,
            (current_tcp_state == 1) and "1" or "0")
    end

    local num_digits = #tostring(#mixer_tracks)
    track_num_format = "%0" .. num_digits .. "d"

    input_channels = {}
    input_channels_mono = {}
    input_channels_stereo = {}
    mono_has_been_set = {}
    stereo_has_been_set = {}
    is_stereo = {}
    input_disabled = {}
    pan_values = {}
    track_names = {}
    track_has_hyphen = {}
    volume_values = {}

    for i = 1, #mixer_tracks do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i]

        local ch, stereo = get_current_input_info(d_track)
        input_channels[i] = ch
        is_stereo[i] = stereo

        local _, disabled_state = GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:input_disabled", "", false)
        input_disabled[i] = (disabled_state == "y")

        if stereo then
            input_channels_stereo[i] = ch
            input_channels_mono[i] = 0
            stereo_has_been_set[i] = true
            mono_has_been_set[i] = false
        else
            input_channels_mono[i] = ch
            input_channels_stereo[i] = 0
            mono_has_been_set[i] = true
            stereo_has_been_set[i] = false
        end

        pan_values[i] = GetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN")
        volume_values[i] = GetMediaTrackInfo_Value(track_info.mixer_track, "D_VOL")

        local _, mixer_name = GetTrackName(track_info.mixer_track)
        local name_without_prefix = mixer_name:gsub("^M:?", ""):gsub("%-$", "")

        local _, rcm_disconnect = GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect", "", false)
        track_has_hyphen[i] = (rcm_disconnect == "y")

        track_names[i] = name_without_prefix
    end

    aux_volume_values = {}
    for i, aux_info in ipairs(aux_submix_tracks) do
        aux_volume_values[i] = GetMediaTrackInfo_Value(aux_info.track, "D_VOL")
    end
    is_valid_project = true
    has_dolby_atmos_beam, dolby_atmos_beam_fx_name = check_dolby_atmos_beam_available()
    return true
end

function draw_track_controls(start_idx, end_idx)
    for i = start_idx, end_idx do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i]

        local _, track_guid = GetSetMediaTrackInfo_String(track_info.mixer_track, "GUID", "", false)
        ImGui.PushID(ctx, i .. "_" .. track_guid)

        local is_selected = (selected_track == i)
        if is_selected then
            local draw_list = ImGui.GetWindowDrawList(ctx)
            local cursor_screen_x, cursor_screen_y = ImGui.GetCursorScreenPos(ctx)
            local window_width = ImGui.GetWindowWidth(ctx)
            local item_height = ImGui.GetTextLineHeightWithSpacing(ctx)
            ImGui.DrawList_AddRectFilled(draw_list, cursor_screen_x, cursor_screen_y,
                cursor_screen_x + window_width, cursor_screen_y + item_height,
                0xADD8E688)
        end

        if row_select_area(ctx, string.format(track_num_format, i) .. "##selmixer", 30, is_selected) then
            selected_track = i
            selected_special = nil
        end

        ImGui.SameLine(ctx, 30)
        ImGui.SetNextItemWidth(ctx, 220)

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

        if ImGui.IsItemActive(ctx) then
            if ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and not ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                if i < end_idx then
                    focus_track_input = i + 1
                elseif i == end_idx and current_tab < math.ceil(#mixer_tracks / TRACKS_PER_TAB) - 1 then
                    pending_tab_switch = current_tab + 1
                    focus_track_input = end_idx + 1
                elseif i == end_idx and i == #mixer_tracks then
                    pending_tab_switch = 0
                    focus_track_input = 1
                end
            elseif ImGui.IsKeyPressed(ctx, ImGui.Key_Tab) and ImGui.IsKeyDown(ctx, ImGui.Mod_Shift) then
                if i > start_idx then
                    focus_track_input = i - 1
                elseif i == start_idx and current_tab > 0 then
                    pending_tab_switch = current_tab - 1
                    local prev_tab_end = (current_tab - 1) * TRACKS_PER_TAB + TRACKS_PER_TAB
                    focus_track_input = math.min(prev_tab_end, #mixer_tracks)
                end
            end
        end

        ImGui.SameLine(ctx)
        local changed_to_mono = ImGui.RadioButton(ctx, "Mono##mono", not is_stereo[i])
        ImGui.SameLine(ctx)
        local changed_to_stereo = ImGui.RadioButton(ctx, "Stereo##stereo", is_stereo[i])

        if changed_to_mono and is_stereo[i] then
            input_channels_stereo[i] = input_channels[i]
            stereo_has_been_set[i] = true
            is_stereo[i] = false

            if not mono_has_been_set[i] then
                if MAX_INPUTS >= 1 then
                    input_channels[i] = 1
                else
                    input_channels[i] = 0
                end
                input_channels_mono[i] = input_channels[i]
                mono_has_been_set[i] = true
            else
                input_channels[i] = input_channels_mono[i]
            end

            apply_input_selection(d_track, is_stereo[i], input_channels[i])

            if workflow == "Vertical" then
                sync_needed = true
            end
        elseif changed_to_stereo and not is_stereo[i] then
            input_channels_mono[i] = input_channels[i]
            mono_has_been_set[i] = true
            is_stereo[i] = true

            if not stereo_has_been_set[i] then
                if MAX_INPUTS >= 2 then
                    input_channels[i] = 1
                else
                    input_channels[i] = 0
                end
                input_channels_stereo[i] = input_channels[i]
                stereo_has_been_set[i] = true
            else
                input_channels[i] = input_channels_stereo[i]
            end

            apply_input_selection(d_track, is_stereo[i], input_channels[i])

            if workflow == "Vertical" then
                sync_needed = true
            end
        end

        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, input_dropdown_width)
        local options = is_stereo[i] and stereo_options or mono_options
        local options_str = table.concat(options, "\0") .. "\0"
        local changed_input, new_input = ImGui.Combo(ctx, "##input", input_channels[i], options_str)
        if changed_input then
            input_channels[i] = new_input

            if is_stereo[i] then
                input_channels_stereo[i] = new_input
                stereo_has_been_set[i] = true
            else
                input_channels_mono[i] = new_input
                mono_has_been_set[i] = true
            end

            apply_input_selection(d_track, is_stereo[i], input_channels[i])

            if workflow == "Vertical" then
                sync_needed = true
            end
        end

        ImGui.SameLine(ctx)
        local changed_disabled, new_disabled = ImGui.Checkbox(ctx, "Rec Disabled##disabled" .. i, input_disabled[i])
        if changed_disabled then
            input_disabled[i] = new_disabled
            GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:input_disabled", new_disabled and "y" or "", true)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "When checked, this track will not be rec-armed")
        end

        ImGui.SameLine(ctx)
        local is_muted = GetMediaTrackInfo_Value(track_info.mixer_track, "B_MUTE") == 1
        if is_muted then
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFF0000FF)
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFF3333FF)
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCC0000FF)
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFFFFFFF)
        end
        if ImGui.Button(ctx, "M##mute" .. i, 25, 0) then
            SetMediaTrackInfo_Value(track_info.mixer_track, "B_MUTE", is_muted and 0 or 1)
        end
        if is_muted then
            ImGui.PopStyleColor(ctx, 4)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Mute")
        end

        ImGui.SameLine(ctx)
        local is_soloed = GetMediaTrackInfo_Value(track_info.mixer_track, "I_SOLO") > 0
        if is_soloed then
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0xFFFF00FF)
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0xFFFF66FF)
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0xCCCC00FF)
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x000000FF)
        end
        if ImGui.Button(ctx, "S##solo" .. i, 25, 0) then
            SetMediaTrackInfo_Value(track_info.mixer_track, "I_SOLO", is_soloed and 0 or 2)
        end
        if is_soloed then
            ImGui.PopStyleColor(ctx, 4)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Solo")
        end

        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 150)
        local changed_pan, new_pan = ImGui.SliderDouble(ctx, "##pan" .. i, pan_values[i], -1.0, 1.0,
            format_pan(pan_values[i]))

        new_pan = reset_pan_on_double_click("##pan" .. i, new_pan, 0.0)

        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Pan (double-click center, right-click to type)")
        end

        if changed_pan or new_pan ~= pan_values[i] then
            pan_values[i] = new_pan
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", new_pan)
        end

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
                local input = buf:gsub("%s+", "")
                local input_upper = input:upper()

                if input_upper == "C" or input == "" then
                    pan_val = 0.0
                elseif input_upper == "L" then
                    pan_val = -1.0
                elseif input_upper == "R" then
                    pan_val = 1.0
                else
                    local num, side = input:match("^(%d+%.?%d*)([LlRr])$")
                    if num and side then
                        local amount = tonumber(num)
                        if amount then
                            amount = math.min(100, amount) / 100
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

        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 200)
        local volume_db = 20 * math.log(volume_values[i] > 0.0000001 and volume_values[i] or 0.0000001, 10)
        local fader_pos
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

        local changed_fader, new_fader_pos = ImGui.SliderDouble(ctx, "##vol" .. i, fader_pos, 0.0, 1.0,
            string.format("%.1f dB", volume_db))

        if ImGui.IsItemDeactivated(ctx) and pan_reset["vol" .. i] then
            new_fader_pos = 0.75
            changed_fader = true
            pan_reset["vol" .. i] = nil
        elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
            pan_reset["vol" .. i] = true
        end

        if changed_fader then
            local new_db
            if new_fader_pos <= 0.75 then
                new_db = -60 + (new_fader_pos / 0.75) * 60
            else
                new_db = ((new_fader_pos - 0.75) / 0.25) * 12
            end
            local new_vol = 10 ^ (new_db / 20)
            volume_values[i] = new_vol
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_VOL", new_vol)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Volume (double-click for 0dB, right-click to type dB)")
        end

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
                    db_val = math.max(-60, math.min(12, db_val))
                    local new_vol = 10 ^ (db_val / 20)
                    volume_values[i] = new_vol
                    SetMediaTrackInfo_Value(track_info.mixer_track, "D_VOL", new_vol)
                end
                ImGui.CloseCurrentPopup(ctx)
            end
            ImGui.EndPopup(ctx)
        end

        ImGui.SameLine(ctx)
        local _, track_guid = GetSetMediaTrackInfo_String(track_info.mixer_track, "GUID", "", false)
        local changed_tcp, new_tcp = ImGui.Checkbox(ctx, "TCP##tcp" .. i, mixer_tcp_visible[i])
        if changed_tcp then
            mixer_tcp_visible[i] = new_tcp

            SetMediaTrackInfo_Value(track_info.mixer_track, "B_SHOWINTCP", new_tcp and 1 or 0)

            TrackList_AdjustWindows(false)
            UpdateArrange()
            SetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. track_guid,
                new_tcp and "1" or "0")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Show in TCP")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Routing##" .. i) then
            ImGui.OpenPopup(ctx, "aux_routing##" .. i)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Route to RCMASTER and Aux/Submix tracks")
        end

        if ImGui.BeginPopup(ctx, "aux_routing##" .. i) then
            local _, rcm_disconnect = GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect", "",
                false)
            local current_rcm_state = (rcm_disconnect ~= "y")

            local fresh_sends = get_mixer_sends(track_info.mixer_track)

            ImGui.Text(ctx, "Route " .. track_names[i] .. " to:")
            ImGui.Separator(ctx)

            if not pending_routing_changes[i] then
                pending_routing_changes[i] = {
                    rcm_changed = false,
                    rcm_state = current_rcm_state,
                    sends = {}
                }
            end

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
                    if aux_info.has_routing then
                        local current_state = pending_routing_changes[i].sends[aux_info.track]
                        if current_state == nil then
                            current_state = fresh_sends[aux_info.track] or false
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
            if pending_routing_changes[i] then
                local changes = pending_routing_changes[i]

                if changes.rcm_changed then
                    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect",
                        changes.rcm_state and "" or "y", true)

                    track_has_hyphen[i] = not changes.rcm_state
                    rename_tracks(track_info, track_names[i], track_has_hyphen[i])
                    sync_needed = true
                end

                for aux_track, new_state in pairs(changes.sends) do
                    local fresh_sends_now = get_mixer_sends(track_info.mixer_track)
                    local current_state = fresh_sends_now[aux_track] or false
                    if new_state ~= current_state then
                        if new_state then
                            CreateTrackSend(track_info.mixer_track, aux_track)
                        else
                            local num_sends = GetTrackNumSends(track_info.mixer_track, 0)
                            for j = 0, num_sends - 1 do
                                local dest = GetTrackSendInfo_Value(track_info.mixer_track, 0, j, "P_DESTTRACK")
                                if dest == aux_track then
                                    RemoveTrackSend(track_info.mixer_track, 0, j)
                                    break
                                end
                            end
                        end
                    end
                end

                pending_routing_changes[i] = nil
            end
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "FX##fx" .. i) then
            TrackFX_Show(track_info.mixer_track, 0, 1)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Open FX chain")
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "✕##delete" .. i) then
            delete_mixer_track(track_info)
            ImGui.PopID(ctx)
            return
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Delete this track from all folders")
        end

        ImGui.SameLine(ctx)
        local remaining_width = ImGui.GetContentRegionAvail(ctx)
        ImGui.InvisibleButton(ctx, "##rowclick", remaining_width, ImGui.GetTextLineHeight(ctx))
        if ImGui.IsItemClicked(ctx) then
            selected_track = i
            selected_special = nil
        end

        ImGui.PopID(ctx)
    end
end

function get_hardware_outputs(mixer_track)
    local outputs = {}
    local num_hw_sends = GetTrackNumSends(mixer_track, 1)

    for i = 0, num_hw_sends - 1 do
        local hw_out = GetTrackSendInfo_Value(mixer_track, 1, i, "I_DSTCHAN")
        if hw_out >= 0 then
            outputs[hw_out] = true
        end
    end

    return outputs
end

function check_dolby_atmos_beam_available()
    local index = 0
    local fallback_name = nil
    while true do
        local retval, name = EnumInstalledFX(index)
        if not retval then
            break
        end
        local lower_name = name:lower()
        if lower_name:match("dolby atmos beam") then
            if lower_name:match("^vst3:") then
                return true, name
            end
            fallback_name = fallback_name or name
        end
        index = index + 1
    end
    if fallback_name then
        return true, fallback_name
    end
    return false, nil
end

function get_track_num_channels(track)
    local num_channels = GetMediaTrackInfo_Value(track, "I_NCHAN")
    if num_channels == 0 then
        num_channels = 2
    end
    return num_channels
end

function get_items_at_midpoint(ref_item, folder_start, folder_end)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

function consolidate_folders_to_first()
    local num_tracks = CountTracks(0)
    local folders = {}

    local i = 0
    while i < num_tracks do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if folder_depth == 1 then
            local folder_info = { parent = track, children = {} }
            table.insert(folders, folder_info)

            i = i + 1
            local current_depth = 1
            while i < num_tracks and current_depth > 0 do
                local child_track = GetTrack(0, i)
                local child_depth = GetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH")
                table.insert(folder_info.children, child_track)
                current_depth = current_depth + child_depth
                if current_depth <= 0 then break end
                i = i + 1
            end
        end
        i = i + 1
    end

    if #folders < 2 then return end

    for _, folder in ipairs(folders) do
        local all_folder_tracks = { folder.parent }
        for _, child in ipairs(folder.children) do
            table.insert(all_folder_tracks, child)
        end

        local folder_item_set = {}
        for _, track in ipairs(all_folder_tracks) do
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                folder_item_set[item] = true
            end
        end

        local midpoint_groups = {}
        local seen = {}

        local folder_start_idx = GetMediaTrackInfo_Value(folder.parent, "IP_TRACKNUMBER") - 1
        local folder_end_idx = folder_start_idx
        for _, child in ipairs(folder.children) do
            folder_end_idx = GetMediaTrackInfo_Value(child, "IP_TRACKNUMBER") - 1
        end

        local parent_item_count = CountTrackMediaItems(folder.parent)
        for j = 0, parent_item_count - 1 do
            local ref_item = GetTrackMediaItem(folder.parent, j)
            if not seen[ref_item] then
                local peers = get_items_at_midpoint(ref_item, folder_start_idx, folder_end_idx)

                local group_items = {}
                for _, peer in ipairs(peers) do
                    if folder_item_set[peer] then
                        group_items[#group_items + 1] = peer
                        seen[peer] = true
                    end
                end
                local ref_pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
                table.insert(midpoint_groups, { items = group_items, ref_pos = ref_pos })
            end
        end

        local ungrouped_items = {}
        for _, track in ipairs(all_folder_tracks) do
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                if not seen[item] then
                    seen[item] = true
                    table.insert(ungrouped_items, item)
                end
            end
        end

        folder.midpoint_groups = midpoint_groups
        folder.ungrouped_items = ungrouped_items
    end

    local first_folder = folders[1]
    local first_folder_earliest = math.huge
    local latest_end = 0

    for _, group in ipairs(first_folder.midpoint_groups) do
        for _, item in ipairs(group.items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
            if pos < first_folder_earliest then first_folder_earliest = pos end
            if item_end > latest_end then latest_end = item_end end
        end
    end
    for _, item in ipairs(first_folder.ungrouped_items) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos < first_folder_earliest then first_folder_earliest = pos end
        if item_end > latest_end then latest_end = item_end end
    end

    if first_folder_earliest ~= 0 and first_folder_earliest ~= math.huge then
        local shift = -first_folder_earliest
        for _, group in ipairs(first_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                SetMediaItemInfo_Value(item, "D_POSITION", pos + shift)
            end
        end
        for _, item in ipairs(first_folder.ungrouped_items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", pos + shift)
        end
        latest_end = latest_end + shift
    end

    local first_folder_tracks = { first_folder.parent }
    for _, child in ipairs(first_folder.children) do
        table.insert(first_folder_tracks, child)
    end

    local current_position = (latest_end > 0) and (latest_end + 10) or 0

    for folder_idx = 2, #folders do
        local source_folder = folders[folder_idx]

        local folder_earliest = math.huge
        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                if pos < folder_earliest then folder_earliest = pos end
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if pos < folder_earliest then folder_earliest = pos end
        end

        local folder_offset = current_position - folder_earliest

        local source_folder_tracks = { source_folder.parent }
        for _, child in ipairs(source_folder.children) do
            table.insert(source_folder_tracks, child)
        end

        local function move_item_to_first_folder(item, new_pos)
            local source_track = GetMediaItem_Track(item)
            local source_track_pos = nil
            for idx, folder_track in ipairs(source_folder_tracks) do
                if folder_track == source_track then
                    source_track_pos = idx; break
                end
            end
            if source_track_pos and source_track_pos <= #first_folder_tracks then
                local dest_track = first_folder_tracks[source_track_pos]
                MoveMediaItemToTrack(item, dest_track)
                SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
            end
        end

        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                move_item_to_first_folder(item, original_pos + folder_offset)
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            move_item_to_first_folder(item, original_pos + folder_offset)
        end

        local folder_end = 0
        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                    GetMediaItemInfo_Value(item, "D_LENGTH")
                if item_end > folder_end then folder_end = item_end end
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                GetMediaItemInfo_Value(item, "D_LENGTH")
            if item_end > folder_end then folder_end = item_end end
        end

        current_position = folder_end + 10
    end

    Main_OnCommand(40297, 0)
    for folder_idx = 2, #folders do
        local folder = folders[folder_idx]
        local has_items = CountTrackMediaItems(folder.parent) > 0
        if not has_items then
            for _, child in ipairs(folder.children) do
                if CountTrackMediaItems(child) > 0 then
                    has_items = true; break
                end
            end
        end
        if not has_items then
            SetTrackSelected(folder.parent, true)
            for _, child in ipairs(folder.children) do
                SetTrackSelected(child, true)
            end
        end
    end

    Main_OnCommand(40005, 0)
    Main_OnCommand(40297, 0)
end

if GetToggleCommandState(1156) ~= 1 then
    Main_OnCommand(1156, 0)
end

sync()
if init() then
    maybe_autofocus_track1()
    defer(main)
end
