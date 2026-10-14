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
    dofile(script_path .. "lib/ReaClassical_Accessible Show Statistics.lua")
    return
end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local stats_info = require("ReaClassical_Stats_Info")

local main

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

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('ReaClassical Stats')
local window_open = true

local stats = {}

function calculate_stats()
    stats = stats_info.calculate()
end

function reset_session_timer()
    stats_info.reset_session_timer()
    calculate_stats()
end

function main()
    if window_open and gui_mode.accessible() then
        window_open = false
        gui_mode.switch_window("ReaClassical_Show Statistics.lua")
        return
    end

    if window_open then
        local viewport = ImGui.GetMainViewport(ctx)
        local work_x, work_y = ImGui.Viewport_GetWorkPos(viewport)
        local work_w, work_h = ImGui.Viewport_GetWorkSize(viewport)

        local estimated_w = 200
        local estimated_h = 500

        local center_x = work_x + (work_w - estimated_w) / 2
        local center_y = work_y + (work_h - estimated_h) / 2

        ImGui.SetNextWindowPos(ctx, center_x, center_y, ImGui.Cond_Once)

        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Project Statistics", window_open,
            ImGui.WindowFlags_AlwaysAutoResize)
        window_open = open_ref

        if opened then
            local version_text = stats_info.version_text(stats)
            ImGui.Text(ctx, version_text)
            ImGui.SameLine(ctx)
            if ImGui.SmallButton(ctx, "Copy Ver") then
                ImGui.SetClipboardText(ctx, version_text)
            end
            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "Album Stats:")
            ImGui.Text(ctx, "- Final album length: " .. stats.album_end)
            ImGui.Text(ctx, "- Number of CD markers: " .. tostring(stats.num_cd_markers))
            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "Project Stats:")
            ImGui.Text(ctx, "- Project age: " .. stats.project_age)
            ImGui.Text(ctx, "- Session time: " .. stats.session_time)
            ImGui.SameLine(ctx)
            if ImGui.SmallButton(ctx, "Reset") then
                reset_session_timer()
            end
            ImGui.Text(ctx, "- Total project length: " .. stats.total_project_length)
            ImGui.Text(ctx, "- Total length of all source material: " .. stats.total_source_length)
            ImGui.Text(ctx, "- Total number of items: " .. tostring(stats.num_items))
            ImGui.Text(ctx, "- Number of track folders: " .. tostring(stats.folder_count))
            ImGui.Text(ctx, "- Number of tracks per group: " .. tostring(stats.tracks_per_group))
            ImGui.Text(ctx, "- Number of special tracks: " .. tostring(stats.special_tracks))
            ImGui.Text(ctx, "- Number of regions: " .. tostring(stats.num_regions))
            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "Edit Stats:")
            ImGui.Text(ctx, "- Number of dest S-D edits: " .. tostring(stats.num_sd_edits))
            ImGui.Text(ctx, "- Number of dest item splits: " .. tostring(stats.num_splits))
            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "FX & Automation:")
            ImGui.Text(ctx, "- Total FX count: " .. tostring(stats.num_fx))
            ImGui.Text(ctx, "- Total automation lanes: " .. tostring(stats.num_automation_lanes))
            ImGui.Spacing(ctx)

            if ImGui.Button(ctx, "Refresh", 80, 0) then
                calculate_stats()
            end
            ImGui.SameLine(ctx)
            if ImGui.Button(ctx, "Copy Statistics", 110, 0) then
                ImGui.SetClipboardText(ctx, stats_info.stats_text(stats))
            end
            if gui_mode.imgui_shortcut(ImGui, ctx) then gui_mode.toggle_and_announce() end
            if ImGui.IsWindowFocused(ctx) and gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end
            ImGui.End(ctx)
        end

        defer(main)
    end
end

PreventUIRefresh(1)
calculate_stats()
PreventUIRefresh(-1)
UpdateArrange()
UpdateTimeline()
defer(main)
