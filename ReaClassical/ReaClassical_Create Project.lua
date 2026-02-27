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

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow ~= "" then
    MB("You can only use this function on an empty REAPER project", "ReaClassical Error", 0)
    return
end

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('Workflow Selector')
local window_open = true

local WINDOW_W = 300
local WINDOW_H = 225

local track_count = 10
local workflow_type = 0 -- 0 = Horizontal, 1 = Vertical
local first_frame = true
local show_min_message = false
local message_timer = 0
local should_focus_input = true

---------------------------------------------------------------------

local function main()
    if window_open then
        -- Center window on first frame
        if first_frame then
            local viewport = ImGui.GetMainViewport(ctx)
            local work_x, work_y = ImGui.Viewport_GetWorkPos(viewport)
            local work_w, work_h = ImGui.Viewport_GetWorkSize(viewport)
            local center_x = work_x + (work_w - WINDOW_W) / 2
            local center_y = work_y + (work_h - WINDOW_H) / 2
            ImGui.SetNextWindowPos(ctx, center_x, center_y, ImGui.Cond_Appearing)
            first_frame = false
        end

        -- Update message timer
        if show_min_message then
            message_timer = message_timer + 1
            if message_timer > 120 then -- Hide after ~2 seconds (at 60fps)
                show_min_message = false
                message_timer = 0
            end
        end

        ImGui.SetNextWindowSize(ctx, WINDOW_W, WINDOW_H, ImGui.Cond_Always)
        local window_flags = ImGui.WindowFlags_NoResize
        local opened, open_ref = ImGui.Begin(ctx, "Create ReaClassical Project", window_open, window_flags)
        window_open = open_ref

        if opened then
            -- Number of tracks section
            ImGui.Text(ctx, "Number of tracks per folder:")
            ImGui.SameLine(ctx)

            -- Minus button
            if ImGui.Button(ctx, "-", 30, 0) then
                track_count = math.max(2, track_count - 1)
            end

            ImGui.SameLine(ctx)

            -- Track count input
            if should_focus_input then
                ImGui.SetKeyboardFocusHere(ctx)
                should_focus_input = false
            end

            ImGui.SetNextItemWidth(ctx, 40)
            local changed, new_count = ImGui.InputInt(ctx, "##track_count", track_count, 0, 0)
            if changed then
                if new_count < 2 then
                    track_count = 2
                    show_min_message = true
                    message_timer = 0
                else
                    track_count = new_count
                    show_min_message = false
                end
            end

            ImGui.SameLine(ctx)

            -- Plus button
            if ImGui.Button(ctx, "+", 30, 0) then
                track_count = track_count + 1
                show_min_message = false
            end

            -- Show gentle message if minimum not met (fixed space to prevent resizing)
            if show_min_message then
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFFAAAAFF) -- Gentle red/pink
                ImGui.Text(ctx, "Minimum of 2 tracks per folder required")
                ImGui.PopStyleColor(ctx)
            else
                ImGui.Dummy(ctx, 0, ImGui.GetTextLineHeight(ctx)) -- Reserve space for message
            end

            ImGui.Spacing(ctx)

            -- Workflow type section
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

            ImGui.Spacing(ctx)
            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            -- OK and Cancel buttons
            local button_w = 100
            local button_spacing = 10

            if ImGui.Button(ctx, "OK", button_w, 30) then
                -- Store track count in project extended state
                SetProjExtState(0, "ReaClassical", "TrackCount", tostring(track_count))
                local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
                -- Run appropriate command based on workflow type
                if workflow_type == 0 then
                    dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
                else
                    dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
                end
                ImGui.End(ctx)
                return -- Exit immediately
            end

            ImGui.SameLine(ctx, 0, button_spacing)

            if ImGui.Button(ctx, "Cancel", button_w, 30) then
                ImGui.End(ctx)
                return -- Exit immediately
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

defer(main)
