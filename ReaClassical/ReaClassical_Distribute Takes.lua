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
    dofile(script_path .. "lib/ReaClassical_Accessible Distribute Takes.lua")
    return
end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local region_export = require("ReaClassical_Region_Export")
local global_take = require("ReaClassical_Global_Take")

local rs = region_export.load_render_settings()

local main, run_distribute, collect_regions_for_track
local get_item_take_num, parse_take_list, build_take_filter

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists and not _G.RC_SCRIPT_ARGS then
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

local ImGui, ctx
local window_open = true

if not _G.RC_SCRIPT_ARGS then
    package.path = ImGui_GetBuiltinPath() .. '/?.lua'
    ImGui = require 'imgui' '0.10'
    ctx = ImGui.CreateContext('ReaClassical Distribute Takes')
end

local TAKE_MODES = {
    { key = "all",      label = "All takes",      tooltip = "Export every take" },
    { key = "list",     label = "Take list",      tooltip = "Export takes by number, e.g. 1,4-6,7" },
    { key = "selected", label = "Selected items", tooltip = "Export selected parent items" },
    { key = "time",     label = "Time selection", tooltip = "Export takes overlapping the time selection" },
}

local take_mode = "all"
local take_list_text = ""
local include_rank = GetExtState("ReaClassical", "DistributeTakesIncludeRank") == "1"

function get_item_take_num(item)
    local _, stored = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
    local num = tonumber(stored)
    if num then return num end
    local take = GetActiveTake(item)
    if not take then return nil end
    local filename = GetMediaSourceFileName(GetMediaItemTake_Source(take), "")
    num = tonumber(filename:match("_T?(%d+)%.[^%.]+$"))
    if num then return num end
    local _, raw_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    local clean = (raw_name:match("^(.-)%s*|") or raw_name):match("^%s*(.-)%s*$")
    return tonumber(clean:match("_T?(%d+)$") or clean:match("^(%d+)$"))
end

function parse_take_list(text)
    local set = {}
    local any = false
    for part in text:gmatch("[^,]+") do
        part = part:match("^%s*(.-)%s*$")
        if part ~= "" then
            local a, b = part:match("^(%d+)%s*%-%s*(%d+)$")
            if a then
                a, b = tonumber(a), tonumber(b)
                if a > b then a, b = b, a end
                for n = a, b do set[n] = true end
                any = true
            elseif part:match("^%d+$") then
                set[tonumber(part)] = true
                any = true
            else
                return nil, "Invalid take list entry: \"" .. part .. "\".\nUse numbers and ranges, e.g. 1,4-6,7"
            end
        end
    end
    if not any then return nil, "Please enter at least one take number, e.g. 1,4-6,7" end
    return set
end

function build_take_filter(mode, list_text)
    if mode == "list" then
        local set, err = parse_take_list(list_text or "")
        if not set then return nil, err end
        return function(item)
            local num = get_item_take_num(item)
            return num ~= nil and set[num] == true
        end
    elseif mode == "selected" then
        if CountSelectedMediaItems(0) == 0 then
            return nil, "Please select one or more parent items to export."
        end
        return function(item) return IsMediaItemSelected(item) end
    elseif mode == "time" then
        local ts_start, ts_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
        if ts_end <= ts_start then
            return nil, "Please make a time selection covering the takes to export."
        end
        return function(item)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            return pos < ts_end and pos + len > ts_start
        end
    end
    return function() return true end
end

function collect_regions_for_track(folder_track, filter, keep_rank)
    local use_global = global_take.enabled()
    local regions = {}
    for i = 0, GetTrackNumMediaItems(folder_track) - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        if take and filter(item) then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local _, raw_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local name = region_export.clean_take_name(raw_name, keep_rank)
            local global_num = use_global and global_take.get(item)
            if global_num and name ~= "" then
                name = string.format("G%03d_%s", global_num, name)
            end
            if name ~= "" then
                regions[#regions + 1] = { start = pos, finish = pos + len, name = name }
            end
        end
    end
    return regions
end

function run_distribute(format, mode, list_text, keep_rank)
    if GetProjectPath() == "" then
        return false, "Please save the project before distributing takes."
    end

    local filter, filter_err = build_take_filter(mode or "all", list_text)
    if not filter then return false, filter_err end
    local none_msg = (mode == nil or mode == "all") and "No items with takes found" or "No matching takes found"

    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    if wf ~= "Horizontal" and wf ~= "Vertical" then return true, "Unknown workflow" end

    local folders = region_export.get_rc_folders()
    if #folders == 0 then return true, "No ReaClassical folders found" end
    if wf == "Horizontal" then folders = { folders[1] } end

    local groups = {}
    for _, folder_track in ipairs(folders) do
        groups[#groups + 1] = {
            folder = wf == "Vertical" and folder_track or nil,
            regions = collect_regions_for_track(folder_track, filter, keep_rank),
        }
    end

    local total, base_rel = region_export.render_groups({
        format = format,
        settings = rs,
        dir_name = "Distribute_Takes",
        undo_label = "Distribute Takes",
        groups = groups,
    })
    if not total then return false, base_rel end
    if total == 0 then return true, none_msg end
    return true, total .. " take" .. (total == 1 and "" or "s") .. " distributed to " .. base_rel
end

function main()
    if not window_open then return end

    ImGui.SetNextWindowSizeConstraints(ctx, 480, 0, math.huge, math.huge)
    local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Distribute Takes", window_open,
        ImGui.WindowFlags_AlwaysAutoResize)
    window_open = open_ref

    if opened then
        region_export.draw_render_settings(ImGui, ctx, rs)

        ImGui.Dummy(ctx, 0, 10)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 5)

        ImGui.Text(ctx, "Takes:")
        ImGui.SameLine(ctx)
        for i, m in ipairs(TAKE_MODES) do
            if i > 1 then ImGui.SameLine(ctx) end
            if ImGui.RadioButton(ctx, m.label, take_mode == m.key) then
                take_mode = m.key
            end
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, m.tooltip)
            end
        end
        local list_disabled = take_mode ~= "list"
        if list_disabled then ImGui.BeginDisabled(ctx) end
        ImGui.SetNextItemWidth(ctx, -1)
        local _, new_text = ImGui.InputTextWithHint(ctx, "##take_list", "e.g. 1,4-6,7", take_list_text)
        take_list_text = new_text
        if list_disabled then ImGui.EndDisabled(ctx) end

        local rank_changed, new_rank = ImGui.Checkbox(ctx, "Include ranking in filenames", include_rank)
        if rank_changed then
            include_rank = new_rank
            SetExtState("ReaClassical", "DistributeTakesIncludeRank", include_rank and "1" or "0", true)
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Keep take rankings (e.g. Excellent, Poor) in exported filenames")
        end

        ImGui.Dummy(ctx, 0, 5)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 5)

        local fmt = region_export.draw_format_buttons(ImGui, ctx, "Export takes as ")
        if fmt then
            local ok, msg = run_distribute(fmt, take_mode, take_list_text, include_rank)
            if ok then
                say(msg)
            else
                MB(msg, "ReaClassical Error", 0)
            end
        end

        if not ImGui.IsAnyItemActive(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_Escape, false) then
            window_open = false
        end
        if gui_mode.imgui_close_shortcut(ImGui, ctx) then window_open = false end

        ImGui.End(ctx)
    end

    if window_open then
        defer(main)
    end
end

if _G.RC_SCRIPT_ARGS then
    local args = _G.RC_SCRIPT_ARGS
    if args.action == "distribute" then
        local ok, msg = run_distribute(args.format, args.mode, args.takes, args.include_rank)
        say(msg)
        if not ok then return end
    end
    return
end

defer(main)
