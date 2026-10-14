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
    dofile(script_path .. "lib/ReaClassical_Accessible Create Project.lua")
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow ~= "" then
    MB("You can only use this function on an empty REAPER project", "ReaClassical Error", 0)
    return
end

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('Workflow Selector')
local window_open = true

local WINDOW_W = 310
local WINDOW_H = 260

local track_count = 10
local source_folder_count = 6
local workflow_type = 0
local first_frame = true
local show_min_message = false
local message_timer = 0
local should_focus_input = true

local function main()
    if window_open then
        if first_frame then
            local viewport = ImGui.GetMainViewport(ctx)
            local work_x, work_y = ImGui.Viewport_GetWorkPos(viewport)
            local work_w, work_h = ImGui.Viewport_GetWorkSize(viewport)
            local center_x = work_x + (work_w - WINDOW_W) / 2
            local center_y = work_y + (work_h - WINDOW_H) / 2
            ImGui.SetNextWindowPos(ctx, center_x, center_y, ImGui.Cond_Appearing)
            first_frame = false
        end

        if show_min_message then
            message_timer = message_timer + 1
            if message_timer > 120 then
                show_min_message = false
                message_timer = 0
            end
        end

        ImGui.SetNextWindowSize(ctx, WINDOW_W, WINDOW_H, ImGui.Cond_Always)
        local window_flags = ImGui.WindowFlags_NoResize
        local opened, open_ref = ImGui.Begin(ctx, "Create ReaClassical Project", window_open, window_flags)
        window_open = open_ref

        if opened then
            local label_w = ImGui.CalcTextSize(ctx, "Number of tracks per folder:") + 14

            if ImGui.BeginTable(ctx, "tracks_row", 2, ImGui.TableFlags_None) then
                ImGui.TableSetupColumn(ctx, "label1", ImGui.TableColumnFlags_WidthFixed, label_w)
                ImGui.TableSetupColumn(ctx, "controls1", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableNextRow(ctx)
                ImGui.TableSetColumnIndex(ctx, 0)
                ImGui.AlignTextToFramePadding(ctx)
                ImGui.Text(ctx, "Number of tracks per folder:")
                ImGui.TableSetColumnIndex(ctx, 1)

                if ImGui.Button(ctx, "-", 30, 0) then
                    track_count = math.max(1, track_count - 1)
                end

                ImGui.SameLine(ctx)

                if should_focus_input then
                    ImGui.SetKeyboardFocusHere(ctx)
                    should_focus_input = false
                end

                ImGui.SetNextItemWidth(ctx, 40)
                local changed, new_count = ImGui.InputInt(ctx, "##track_count", track_count, 0, 0)
                if changed then
                    if new_count < 1 then
                        track_count = 1
                        show_min_message = true
                        message_timer = 0
                    else
                        track_count = new_count
                        show_min_message = false
                    end
                end

                ImGui.SameLine(ctx)

                if ImGui.Button(ctx, "+", 30, 0) then
                    track_count = track_count + 1
                    show_min_message = false
                end

                ImGui.EndTable(ctx)
            end

            if show_min_message then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAAAAFF)
                ImGui.Text(ctx, "Minimum of 1 track per folder required")
                ImGui.PopStyleColor(ctx)
            else
                ImGui.Dummy(ctx, 0, ImGui.GetTextLineHeight(ctx))
            end

            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "Workflow Type:")

            if ImGui.RadioButton(ctx, "Horizontal", workflow_type == 0) then
                workflow_type = 0
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Recorded or imported takes are arranged left-to-right in a single folder.")
            end

            if ImGui.RadioButton(ctx, "Vertical", workflow_type == 1) then
                workflow_type = 1
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "Designed for recorded takes of similar material to be stacked vertically.")
            end

            local vertical_selected = workflow_type == 1
            ImGui.Spacing(ctx)

            if not vertical_selected then
                ImGui.BeginDisabled(ctx, true)
            end

            if ImGui.BeginTable(ctx, "folders_row", 2, ImGui.TableFlags_None) then
                ImGui.TableSetupColumn(ctx, "label2", ImGui.TableColumnFlags_WidthFixed, label_w)
                ImGui.TableSetupColumn(ctx, "controls2", ImGui.TableColumnFlags_WidthStretch)
                ImGui.TableNextRow(ctx)
                ImGui.TableSetColumnIndex(ctx, 0)
                ImGui.AlignTextToFramePadding(ctx)
                ImGui.Text(ctx, "Number of source folders:")
                ImGui.TableSetColumnIndex(ctx, 1)

                if ImGui.Button(ctx, "-##folder_minus", 30, 0) then
                    source_folder_count = math.max(1, source_folder_count - 1)
                end

                ImGui.SameLine(ctx)

                ImGui.SetNextItemWidth(ctx, 40)
                local folder_changed, new_folder_count = ImGui.InputInt(ctx, "##source_folder_count",
                    source_folder_count, 0, 0)
                if folder_changed then
                    source_folder_count = math.max(1, new_folder_count)
                end

                ImGui.SameLine(ctx)

                if ImGui.Button(ctx, "+##folder_plus", 30, 0) then
                    source_folder_count = source_folder_count + 1
                end

                ImGui.EndTable(ctx)
            end

            if not vertical_selected then
                ImGui.EndDisabled(ctx)
            end

            ImGui.Spacing(ctx)
            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            local button_w = 100
            local button_spacing = 10

            if ImGui.Button(ctx, "OK", button_w, 30) then
                if track_count == 1 then
                    SetProjExtState(0, "ReaClassical", "TrackCount", "2")
                    SetProjExtState(0, "ReaClassical", "SingleTrack", "1")
                else
                    SetProjExtState(0, "ReaClassical", "TrackCount", tostring(track_count))
                    SetProjExtState(0, "ReaClassical", "SingleTrack", "")
                end
                local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
                if workflow_type == 0 then
                    dofile(script_path .. "lib/ReaClassical_Horizontal Workflow.lua")
                else
                    SetProjExtState(0, "ReaClassical", "SourceFolderCount", tostring(source_folder_count))
                    dofile(script_path .. "lib/ReaClassical_Vertical Workflow.lua")
                end
                if APIExists("SNM_SetIntConfigVar") then SNM_SetIntConfigVar("scrubmode", 1) end
                ImGui.End(ctx)
                return
            end

            ImGui.SameLine(ctx, 0, button_spacing)

            if ImGui.Button(ctx, "Cancel", button_w, 30) then
                ImGui.End(ctx)
                return
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

defer(main)
