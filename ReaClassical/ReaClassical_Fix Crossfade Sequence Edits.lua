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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local core = require("ReaClassical_Crossfade_Fix_Core")

local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()
if _clara_or_debug then
    dofile(script_path .. "lib/ReaClassical_Accessible Fix Crossfade Sequence Edits.lua")
    return
end

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end
set_action_options(2)
package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local _, workflow_check = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow_check == "" then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

local folder_track, left, right, selection_err = core.resolve_selection()
if selection_err then
    MB(selection_err, "ReaClassical - Fix Crossfade Sequence Edits", 0)
    return
end

local track_list = core.folder_track_list(folder_track)

local function run_and_report(good_track)
    Undo_BeginBlock()
    PreventUIRefresh(1)
    local fixed, warnings = core.run_fix(folder_track, good_track, left, right)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
    Undo_EndBlock('Fix Crossfade Sequence Edits', -1)

    if #warnings > 0 then
        MB(string.format("Fixed %d item(s).\n\n%d issue(s):\n%s",
            fixed, #warnings, table.concat(warnings, "\n")),
            "ReaClassical - Fix Crossfade Sequence Edits", 0)
    else
        say(string.format("Fixed %d item%s", fixed, fixed == 1 and "" or "s"))
    end
end

local ctx = ImGui.CreateContext("ReaClassical Fix Crossfade Sequence Edits")
local window_open = true
local frame_count = 0

local function main()
    local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize

    if frame_count == 0 then
        local viewport_center_x, viewport_center_y = ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))
        ImGui.SetNextWindowPos(ctx, viewport_center_x, viewport_center_y, ImGui.Cond_Appearing, 0.5, 0.5)
    end
    frame_count = frame_count + 1

    local opened, open_ref = ImGui.Begin(ctx, "ReaClassical - Fix Crossfade Sequence Edits", true, window_flags)
    window_open = open_ref

    if opened then
        ImGui.Text(ctx, "Which track has the correct edits for this crossfade group?")
        ImGui.Spacing(ctx)
        for _, entry in ipairs(track_list) do
            if ImGui.Selectable(ctx, entry.name, false) then
                window_open = false
                run_and_report(entry.track)
            end
        end
        ImGui.Spacing(ctx)
        if ImGui.Button(ctx, "Cancel") then
            window_open = false
        end
        if gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end
        ImGui.End(ctx)
    end

    if window_open then
        defer(main)
    end
end

defer(main)
