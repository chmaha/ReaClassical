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

if not _G.RC_SCRIPT_ARGS and gui_mode.accessible() then
    dofile(script_path .. "lib/ReaClassical_Accessible Mixer Track Grouping.lua")
    return
end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")

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

if not APIExists("ImGui_GetVersion") then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua;' .. script_path .. 'lib/?.lua;'
local ImGui = require 'imgui' '0.10'
local mm = require 'ReaClassical_MM_Utils'
local mmg = require 'ReaClassical_MM_Groups'

local ctx = ImGui.CreateContext("ReaClassical Mixer Track Grouping")
local window_open = true
local counts_cache = {}
local counts_dirty = true

local WINDOW_W, WINDOW_H = 700, 680
local MATRIX_H = 280
local GROUPS_PER_TAB = 8
local NUM_TABS = math.floor(mmg.MAX_NATIVE_SLOTS / GROUPS_PER_TAB)

local ASPECT_COL_W = 30
local ASPECT_BLOCK_W = #mmg.ASPECTS * ASPECT_COL_W
local ASPECT_TIPS = {
    mute       = "Mute",
    solo       = "Solo",
    pan        = "Pan",
    fader      = "Fader (volume)",
    automation = "Automation",
    polarity   = "Polarity (phase invert)",
}

local function recount_counts(owners)
    counts_cache = {}
    for _, slot in pairs(owners) do
        if slot then counts_cache[slot] = (counts_cache[slot] or 0) + 1 end
    end
    counts_dirty = false
end

local function draw_clear_all_popup()
    if ImGui.BeginPopupModal(ctx, "confirm_clear_all_groups", true, ImGui.WindowFlags_AlwaysAutoResize) then
        ImGui.Text(ctx, "Remove every group, in every tab? This cannot be undone.")
        ImGui.Separator(ctx)
        if ImGui.Button(ctx, "Yes, Clear All", 120, 0) then
            mmg.remove_all_groups()
            counts_dirty = true
            ImGui.CloseCurrentPopup(ctx)
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Cancel", 120, 0) then
            ImGui.CloseCurrentPopup(ctx)
        end
        ImGui.EndPopup(ctx)
    end
end

local function draw_matrix(tracks, groups, base_slot, owners)
    local col_count = 1 + GROUPS_PER_TAB
    local flags = ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg | ImGui.TableFlags_Resizable
    if ImGui.BeginTable(ctx, "GroupMatrix" .. base_slot, col_count, flags) then
        ImGui.TableSetupColumn(ctx, "Track", ImGui.TableColumnFlags_WidthFixed, 200)
        for s = base_slot, base_slot + GROUPS_PER_TAB - 1 do
            local g = mmg.group_for_slot(s, groups)
            ImGui.TableSetupColumn(ctx, tostring(s) .. (g and g.disabled and "*" or ""),
                ImGui.TableColumnFlags_WidthFixed, 50)
        end
        ImGui.TableHeadersRow(ctx)

        for ti, track in ipairs(tracks) do
            ImGui.TableNextRow(ctx)
            ImGui.TableSetColumnIndex(ctx, 0)
            ImGui.Text(ctx, mm.get_label(track))

            local owner_slot = owners[track]
            local col = 1
            for s = base_slot, base_slot + GROUPS_PER_TAB - 1 do
                ImGui.TableSetColumnIndex(ctx, col)
                local changed, new_val = ImGui.Checkbox(ctx, "##cell_" .. ti .. "_" .. s, owner_slot == s)
                if changed then
                    groups = mmg.set_track_native_slot(track, new_val and s or nil)
                    counts_dirty = true
                    local owner = mmg.find_group_for_track(track, groups)
                    owner_slot = owner and owner.native or nil
                    owners[track] = owner_slot
                end
                col = col + 1
            end
        end
        ImGui.EndTable(ctx)
    end
    return groups
end

local function draw_slot_list(groups, base_slot, aspect_base_x, owners)
    if counts_dirty then recount_counts(owners) end
    for s = base_slot, base_slot + GROUPS_PER_TAB - 1 do
        ImGui.PushID(ctx, s)
        local g = mmg.group_for_slot(s, groups)

        ImGui.Text(ctx, string.format("%02d", s))
        ImGui.SameLine(ctx, 30)

        ImGui.SetNextItemWidth(ctx, 180)
        local hint = g and g.name or ("Group " .. s)
        local changed_name, new_name = ImGui.InputTextWithHint(ctx, "##name", hint, g and g.name or "")
        if changed_name then
            groups = mmg.rename_slot(s, new_name)
            counts_dirty = true
        end

        ImGui.SameLine(ctx)
        if not g then ImGui.BeginDisabled(ctx) end
        local changed_en = ImGui.Checkbox(ctx, "Enabled", not (g and g.disabled))
        if changed_en and g then
            groups = mmg.toggle_slot_disabled(s)
            counts_dirty = false
        end
        if not g then ImGui.EndDisabled(ctx) end

        ImGui.SameLine(ctx)
        if not g then ImGui.BeginDisabled(ctx) end
        if ImGui.Button(ctx, "Clear") then
            groups = mmg.clear_slot(s)
            counts_dirty = true
        end
        if not g then ImGui.EndDisabled(ctx) end

        ImGui.SameLine(ctx)
        local count = counts_cache[s] or 0
        if g and g.disabled then ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x999999FF) end
        ImGui.Text(ctx, string.format("(%d track%s)", count, count == 1 and "" or "s"))
        if g and g.disabled then ImGui.PopStyleColor(ctx) end

        for k, aspect in ipairs(mmg.ASPECTS) do
            ImGui.SameLine(ctx, aspect_base_x + (k - 1) * ASPECT_COL_W)
            if not g then ImGui.BeginDisabled(ctx) end
            local changed_a, checked = ImGui.Checkbox(ctx,
                "##asp_" .. s .. "_" .. aspect.key, not g or (g.aspects[aspect.key] ~= false))
            if changed_a and g then
                groups = mmg.set_group_aspect(s, aspect.key, checked)
            end
            if not g then ImGui.EndDisabled(ctx) end
        end

        ImGui.PopID(ctx)
    end
    return groups
end

local function draw_tab(tracks, base_slot)
    local groups = mmg.load_groups()
    local owners = mmg.owner_slot_map(groups, tracks)
    if ImGui.BeginChild(ctx, "matrix" .. base_slot, 0, MATRIX_H, ImGui.ChildFlags_Borders) then
        groups = draw_matrix(tracks, groups, base_slot, owners)
        ImGui.EndChild(ctx)
    end

    ImGui.Dummy(ctx, 0, 8)
    ImGui.Separator(ctx)
    local base_x = ImGui.GetWindowWidth(ctx) - ASPECT_BLOCK_W
    ImGui.Text(ctx, "Groups")
    local box_w = ImGui.GetFrameHeight(ctx)
    for k, aspect in ipairs(mmg.ASPECTS) do
        local letter_w = ImGui.CalcTextSize(ctx, aspect.letter)
        ImGui.SameLine(ctx, base_x + (k - 1) * ASPECT_COL_W + (box_w - letter_w) / 2)
        ImGui.Text(ctx, aspect.letter)
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, ASPECT_TIPS[aspect.key] or aspect.key)
        end
    end
    draw_slot_list(groups, base_slot, base_x, owners)
end

local function draw_UI()
    local tracks = mm.get_special_tracks_list()

    local changed_g, enabled = ImGui.Checkbox(ctx, "Enable grouping", not mmg.is_globally_disabled())
    if changed_g then mmg.set_globally_disabled(not enabled) end

    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Clear All Groups") then
        ImGui.OpenPopup(ctx, "confirm_clear_all_groups")
    end
    draw_clear_all_popup()

    ImGui.Separator(ctx)

    if #tracks == 0 then
        ImGui.Text(ctx, "No mixer/special tracks in this project yet.")
        return
    end

    if ImGui.BeginTabBar(ctx, "##group_tabs") then
        for tab = 0, NUM_TABS - 1 do
            local base_slot = tab * GROUPS_PER_TAB + 1
            local tab_label = string.format("Groups %d-%d", base_slot, base_slot + GROUPS_PER_TAB - 1)
            if ImGui.BeginTabItem(ctx, tab_label) then
                draw_tab(tracks, base_slot)
                ImGui.EndTabItem(ctx)
            end
        end
        ImGui.EndTabBar(ctx)
    end
end

local function main()
    if window_open then
        ImGui.SetNextWindowSize(ctx, WINDOW_W, WINDOW_H, ImGui.Cond_Always)
        local window_flags = ImGui.WindowFlags_NoResize
        local visible, open_ref = ImGui.Begin(ctx, "ReaClassical Mixer Track Grouping", true, window_flags)
        window_open = open_ref
        if visible then
            draw_UI()
            if gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end
            ImGui.End(ctx)
        end
        defer(main)
    end
end

defer(main)
