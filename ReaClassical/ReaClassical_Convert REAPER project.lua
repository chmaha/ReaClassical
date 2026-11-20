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
local convert = require("ReaClassical_Convert_Core")

local _clara_or_debug = not _G.RC_SCRIPT_ARGS and gui_mode.accessible()
if _clara_or_debug then
    dofile(_gm_path .. "lib/ReaClassical_Accessible Convert REAPER Project.lua")
    return
end

if not APIExists("ImGui_GetVersion") then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

set_action_options(2)
package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local WINDOW_TITLE = "ReaClassical Conversion"
local MISSION_CONTROL_CMD = "_RScaa05755eb1dca4cec87c8ba9fe0ddf6570ce73c"
local WINDOW_WIDTH = 520
local LEAVE_LABEL = "Leave in place"

local OPTIONS = {
    {
        label = "Microphones of one recording",
        sequential = false,
        detail = "The tracks become one folder with a track per microphone. "
            .. "Existing markers and regions stay where they are.",
    },
    {
        label = "Separate material",
        sequential = true,
        detail = "Each track holds different material (separate pieces, takes or versions). "
            .. "The tracks are placed one after another, left to right, in a single-track folder, "
            .. "with a marker named after each original track. "
            .. "Track FX and automation are kept from the first track only.",
    },
}

local ctx = ImGui.CreateContext(WINDOW_TITLE)
local window_open = true
local frame_count = 0

local state, message
local pending = nil
local converted = false
local tracks_with_items, has_markers, tracks, marker_choice

local function marker_choice_label(n)
    return tracks[n] and tracks[n].name or LEAVE_LABEL
end

local function start_conversion(sequential, marker_track_index)
    local ok, msg = convert.run(sequential, marker_track_index)
    if ok then
        converted = true
        window_open = false
    else
        state, message = "error", msg
    end
end

if convert.is_rc_project() then
    state, message = "error", "This is already a ReaClassical project."
elseif convert.save_problem() then
    state, message = "error", convert.save_problem()
else
    tracks_with_items = convert.count_tracks_with_items()
    has_markers = convert.has_markers()
    tracks = convert.tracks_with_items()
    marker_choice = has_markers and convert.default_marker_track(tracks) or 1
    state = "choose"
end

local function draw_wrapped(text)
    ImGui.TextWrapped(ctx, text)
end

local function queue(sequential, marker_track_index)
    pending = { sequential = sequential, marker_track_index = marker_track_index, frame = frame_count }
    state, message = "working", "Converting..."
end

local function draw_choose()
    draw_wrapped(convert.INFO)
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)
    if tracks_with_items < 2 then
        if ImGui.Button(ctx, "Convert", 120, 0) then queue(false) end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Cancel", 80, 0) then window_open = false end
        return
    end
    draw_wrapped("This project has " .. tracks_with_items .. " tracks with items. What do they contain?")
    ImGui.Spacing(ctx)
    for _, option in ipairs(OPTIONS) do
        if ImGui.Button(ctx, option.label, 260, 0) then
            local marker_track_index = nil
            if option.sequential and tracks[marker_choice] then
                marker_track_index = tracks[marker_choice].index
            end
            queue(option.sequential, marker_track_index)
        end
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, ImGui.GetStyleColor(ctx, ImGui.Col_TextDisabled))
        ImGui.TextWrapped(ctx, option.detail)
        ImGui.PopStyleColor(ctx)
        if option.sequential and has_markers then
            ImGui.AlignTextToFramePadding(ctx)
            ImGui.Text(ctx, "Existing markers and regions belong to:")
            ImGui.SameLine(ctx)
            ImGui.SetNextItemWidth(ctx, 200)
            if ImGui.BeginCombo(ctx, "##marker_track", marker_choice_label(marker_choice)) then
                for n = 1, #tracks + 1 do
                    if ImGui.Selectable(ctx, marker_choice_label(n), marker_choice == n) then
                        marker_choice = n
                    end
                end
                ImGui.EndCombo(ctx)
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, "They move with this track's material")
            end
        end
        ImGui.Spacing(ctx)
    end
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "Cancel", 80, 0) then window_open = false end
end

local function draw_message()
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
    draw_wrapped(message)
    ImGui.PopStyleColor(ctx)
    ImGui.Spacing(ctx)
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, "OK", 80, 0) then window_open = false end
end

local function main()
    if frame_count == 0 then
        local viewport = ImGui.GetMainViewport(ctx)
        if ImGui.ValidatePtr(viewport, 'ImGui_Viewport*') then
            local center_x, center_y = ImGui.Viewport_GetCenter(viewport)
            ImGui.SetNextWindowPos(ctx, center_x, center_y, ImGui.Cond_Appearing, 0.5, 0.5)
        end
    end
    frame_count = frame_count + 1

    ImGui.SetNextWindowSizeConstraints(ctx, WINDOW_WIDTH, 0, WINDOW_WIDTH, math.huge)
    local window_flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize
    local opened, open_ref = ImGui.Begin(ctx, WINDOW_TITLE, true, window_flags)
    window_open = open_ref

    if opened then
        if state == "choose" then
            draw_choose()
        elseif state == "working" then
            ImGui.Text(ctx, message)
        else
            draw_message()
        end
        if gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end
        ImGui.End(ctx)
    end

    if state == "working" and pending and frame_count > pending.frame then
        local job = pending
        pending = nil
        start_conversion(job.sequential, job.marker_track_index)
    end

    if window_open then
        defer(main)
    elseif converted then
        Main_OnCommand(NamedCommandLookup(MISSION_CONTROL_CMD), 0)
    end
end

defer(main)
