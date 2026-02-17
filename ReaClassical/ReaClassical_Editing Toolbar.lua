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

local main, load_icon, run_action

---------------------------------------------------------------------

set_action_options(2)

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

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('S-D Editing Toolbar')
local window_open = true

-- Layout options
local layout_options = {
    { name = "18 × 1 (horizontal)", cols = 18, rows = 1 },
    { name = "9 × 2",               cols = 9,  rows = 2 },
    { name = "6 × 3",               cols = 6,  rows = 3 },
    { name = "3 × 6",               cols = 3,  rows = 6 },
    { name = "2 × 9",               cols = 2,  rows = 9 },
    { name = "1 × 18 (vertical)",   cols = 1,  rows = 18 }
}
local selected_layout = 2 -- Default to 9x2

-- Zoom options
local zoom_options = {
    { name = "0.5× zoom",  scale = 0.5 },
    { name = "0.75× zoom", scale = 0.75 },
    { name = "1× zoom",    scale = 1.0 },
    { name = "1.5× zoom",  scale = 1.5 },
    { name = "2× zoom",    scale = 2.0 }
}
local selected_zoom = 3 -- Default to 1x

-- Detect OS and set modifier keys
local system = GetOS()
local is_mac = string.find(system, "^OSX") or string.find(system, "^macOS")
local ctrl_key = is_mac and "Cmd" or "Ctrl"
local alt_key = is_mac and "Opt" or "Alt"

local TOOLBAR_ITEMS = {
    { icon = "Dest IN.png",                          action = "_RS031d589795343cd585a36b488d1979a2da61641f", tooltip = "Add Destination IN marker (1)" },
    { icon = "Dest OUT.png",                         action = "_RS5d87205205af827b4ef805777edcf5d6ba6dea1d", tooltip = "Add Destination OUT Marker (2)" },
    { icon = "source IN.png",                        action = "_RS0505890a43ab5e3f1a87aea5318f4ec1f6e2b658", tooltip = "Add Source IN marker (3)" },
    { icon = "source OUT.png",                       action = "_RS0a405e899518bea92ade6794a4ec1b8c07615285", tooltip = "Add Source OUT marker (4)" },
    { icon = "Delete SD Markers.png",                action = "_RSd32029a4c48abc25116b94e4b25a322a187d48b5", tooltip = "Delete All S-D markers (" .. ctrl_key .. "+Delete)" },
    { icon = "SD Edit.png",                          action = "_RS9f29e53917d53d84820659200ed1882f94a0dddb", tooltip = "S-D Edit (5)" },
    { icon = "assembly.png",                         action = "_RSf67395a4d2f6166a72c461079ab511673f842c95", tooltip = "3-point Insert Edit (F3)" },
    { icon = "Insert with timestretching.png",       action = "_RS80d337effa4b34bfbf896a4f3e0b85a7a93254ec", tooltip = "Insert with timestretching (F4)" },
    { icon = "toolbar_tool_erase_delete_remove.png", action = "_RS3f45cdfed62f63857f2a222cfd64c8c277b8d3f5", tooltip = "Heal Edit (" .. ctrl_key .. "+H)" },
    { icon = "delete with ripple.png",               action = "_RS85a54e40656d9858d893dd178e347be59d49d90e", tooltip = "Delete With Ripple (Backspace)" },
    { icon = "delete leaving silence.png",           action = "_RSe8d03b09dbdb5424af5ee4587891eb36be04c131", tooltip = "Delete Leaving Silence (" .. ctrl_key .. "+Backspace)" },
    { icon = "Set_Dest_Proj.png",                    action = "_RS489fd1dcc50945369356b227013316c40ac79f5a", tooltip = "Set Dest Project Marker (" .. ctrl_key .. "+" .. alt_key .. "+1)" },
    { icon = "Set_Source_Proj.png",                  action = "_RS87eed66e1b44a87ee25614426c9fe1e38c95a5d9", tooltip = "Set Source Project Marker (" .. ctrl_key .. "+" .. alt_key .. "+3)" },
    { icon = "Delete SD Project Markers.png",        action = "_RS27a4866ba0d3ed7cb29468e052abaab4bd53054b", tooltip = "Delete S-D Project Markers (Shift+Delete)" },
    { icon = "copy_dest_material.png",               action = "_RS85774ff66e984d0643de45016ab3e056823661a8", tooltip = "Copy Destination Material to Source (" .. ctrl_key .. "+" .. alt_key .. "+C)" },
    { icon = "move_dest_material.png",               action = "_RS4556a37485a2e4b6cd5a0b2d8b1f9126b2f6f4ff", tooltip = "Move Destination Material to Source (" .. ctrl_key .. "+" .. alt_key .. "+M)" },
    { icon = "promote to dest.png",                  action = "_RSa7237af01802429b3a0036fef9ca05429a16f33c", tooltip = "Promote Source to Destination (" .. ctrl_key .. "+" .. alt_key .. "+P)" },
    { icon = "toolbar_zoom_selected.png",            action = "_RSdd8eb28df48002e61663cce1f177c24df69f581b", tooltip = "Find Source Material (" .. ctrl_key .. "+F)" },
}

-- Cache for loaded textures
local textures = {}
local BUTTON_SIZE = 32

function main()
    if window_open then
        local window_flags = ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoResize
        local opened, open_ref = ImGui.Begin(ctx, "S-D Editing Toolbar", window_open, window_flags)
        window_open = open_ref

        if opened then
            -- Use selected layout
            local buttons_per_row = layout_options[selected_layout].cols

            -- Right-click context menu for layout selection
            if ImGui.BeginPopupContextWindow(ctx) then
                ImGui.Text(ctx, "Layout:")
                ImGui.Separator(ctx)
                for i, layout in ipairs(layout_options) do
                    if ImGui.Selectable(ctx, layout.name, selected_layout == i) then
                        selected_layout = i
                    end
                end

                ImGui.Spacing(ctx)
                ImGui.Text(ctx, "Zoom:")
                ImGui.Separator(ctx)
                for i, zoom in ipairs(zoom_options) do
                    if ImGui.Selectable(ctx, zoom.name, selected_zoom == i) then
                        selected_zoom = i
                    end
                end

                ImGui.EndPopup(ctx)
            end

            local button_count = 0

            -- Calculate scaled button size based on zoom
            local scaled_button_size = BUTTON_SIZE * zoom_options[selected_zoom].scale

            for i, item in ipairs(TOOLBAR_ITEMS) do
                local texture = load_icon(item.icon)

                -- Make button backgrounds fully transparent
                ImGui.PushStyleColor(ctx, ImGui.Col_Button, 0x00000000)
                ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, 0x00000000)
                ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, 0x00000000)
                ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0x00000000)

                -- Validate texture before using
                if texture and ImGui.ValidatePtr(texture, 'ImGui_Image*') then
                    -- UV coordinates: show only leftmost third (first click state)
                    -- uv0 = (0, 0), uv1 = (1/3, 1)
                    if ImGui.ImageButton(ctx, "##btn" .. i, texture, scaled_button_size, scaled_button_size,
                            0, 0, 1 / 3, 1) then
                        run_action(item.action)
                    end
                else
                    -- If texture is invalid, clear it from cache and reload
                    if texture then
                        textures[item.icon] = nil
                        texture = load_icon(item.icon)
                    end

                    -- Try again with reloaded texture
                    if texture and ImGui.ValidatePtr(texture, 'ImGui_Image*') then
                        if ImGui.ImageButton(ctx, "##btn" .. i, texture, scaled_button_size, scaled_button_size,
                                0, 0, 1 / 3, 1) then
                            run_action(item.action)
                        end
                    else
                        -- Final fallback if icon still doesn't load
                        if ImGui.Button(ctx, "##btn" .. i, scaled_button_size, scaled_button_size) then
                            run_action(item.action)
                        end
                    end
                end

                ImGui.PopStyleColor(ctx, 4)

                -- Tooltip
                if ImGui.IsItemHovered(ctx) then
                    ImGui.SetTooltip(ctx, item.tooltip)
                end

                button_count = button_count + 1

                -- Add same line for all but last in row
                if button_count % buttons_per_row ~= 0 and i < #TOOLBAR_ITEMS then
                    ImGui.SameLine(ctx)
                end
            end
            -- keyboard shortcut capture
            if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_F6, false) then
                window_open = false
            end
            ImGui.End(ctx)
        end

        defer(main)
    end
end

local _, prepared = GetProjExtState(0, "ReaClassical", "Prepared_Takes")
if prepared == "" then
    local prepare_takes = NamedCommandLookup("_RS11b4fc93fee68b53e4133563a4eb1ec4c2f2b4c1")
    Main_OnCommand(prepare_takes, 0)
end

---------------------------------------------------------------------

function load_icon(icon_name)
    if textures[icon_name] then
        return textures[icon_name]
    end

    local resource_path = GetResourcePath()
    local pathseparator = package.config:sub(1, 1)
    local icon_path = resource_path .. pathseparator .. "Data" .. pathseparator ..
        "toolbar_icons" .. pathseparator .. icon_name

    local texture = ImGui.CreateImage(icon_path)
    if texture then
        textures[icon_name] = texture
    end

    return texture
end

---------------------------------------------------------------------

function run_action(action_string)
    -- Extract just the command ID (everything before the first space)
    local action_id = action_string:match("^(%S+)")

    -- For ReaScript actions with _RS prefix, we need to look up the command ID
    local cmd_id = NamedCommandLookup(action_id)
    if cmd_id and cmd_id ~= 0 then
        Main_OnCommand(cmd_id, 0)
    end
end

---------------------------------------------------------------------

defer(main)
