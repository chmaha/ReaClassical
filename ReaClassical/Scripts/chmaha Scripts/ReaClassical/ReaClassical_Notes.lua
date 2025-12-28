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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, get_take_number, rgba_to_native, get_color_table
local pastel_color, update_take_name, get_item_color, apply_rank_color

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
    return
end

set_action_options(2)

package.path        = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui         = require 'imgui' '0.10'

local ctx           = ImGui.CreateContext('ReaClassical Notes Window')
local window_open   = true

local DEFAULT_W     = 350
local DEFAULT_H     = 375

local MIN_H_PROJECT = 60
local MIN_H_TRACK   = 80
local MIN_H_ITEM    = 80

local track_note    = ""
local item_note     = ""
local item_rank     = 9 -- Default to "No Rank"
local item_take_num = ""

local editing_track = nil
local editing_item  = nil

-- Rank color options (matching SAI marker manager)
local RANKS         = {
    { name = "Excellent",     rgba = 0x39FF1499, prefix = "Excellent" },
    { name = "Very Good",     rgba = 0x32CD3299, prefix = "Very Good" },
    { name = "Good",          rgba = 0x00AD8399, prefix = "Good" },
    { name = "OK",            rgba = 0xFFFFAA99, prefix = "OK" },
    { name = "Below Average", rgba = 0xFFBF0099, prefix = "Below Average" },
    { name = "Poor",          rgba = 0xFF753899, prefix = "Poor" },
    { name = "Unusable",      rgba = 0xDC143C99, prefix = "Unusable" },
    { name = "False Start",   rgba = 0x2A2A2AFF, prefix = "False Start" },
    { name = "No Rank",       rgba = 0x00000000, prefix = "" }
}

---------------------------------------------------------------------

function main()
    local item         = GetSelectedMediaItem(0, 0)
    local track        = GetSelectedTrack(0, 0)
    local proj         = 0

    local project_note = GetSetProjectNotes(proj, false, "")

    -- Safety: check if last edited item/track still exists
    if editing_item and not ValidatePtr2(0, editing_item, "MediaItem*") then
        editing_item = nil
        item_note = ""
        item_rank = 9
        item_take_num = ""
    end

    if editing_track and not ValidatePtr2(0, editing_track, "MediaTrack*") then
        editing_track = nil
        track_note = ""
    end

    if editing_track ~= track then
        ImGui.SetWindowFocus(ctx)
        if editing_track then
            GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
        end

        editing_track = track
        if track then
            local _, note = GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", "", false)
            track_note = note
        end
    end

    if editing_item ~= item then
        -- Clear keyboard focus to prevent InputText from retaining old value
        ImGui.SetWindowFocus(ctx)
        if editing_item then
            GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_rank", tostring(item_rank), true)
            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_take_num", item_take_num, true)
        end

        editing_item = item
        if item then
            local _, note = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
            item_note = note

            local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
            item_rank = tonumber(rank_str) or 9

            -- Load take number - use stored value or default to filename
            local _, item_take_num_stored = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
            item_take_num = item_take_num_stored ~= "" and item_take_num_stored or get_take_number(item)
        else
            item_rank = 9
            item_take_num = ""
            item_note = ""
        end
    end

    if window_open then
        local _, FLT_MAX = ImGui.NumericLimits_Float()
        ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)
        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Notes", window_open)
        window_open = open_ref

        if opened then
            local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

            local static_height    = 4 * ImGui.GetTextLineHeightWithSpacing(ctx) + 50
            local dynamic_h        = math.max(0, avail_h - static_height)

            local base_total       = MIN_H_PROJECT + MIN_H_TRACK + MIN_H_ITEM
            local extra            = math.max(0, dynamic_h - base_total)

            local h_project        = math.max(MIN_H_PROJECT, MIN_H_PROJECT + extra * 0.2)
            local h_track          = math.max(MIN_H_TRACK, MIN_H_TRACK + extra * 0.4)
            local h_item           = math.max(MIN_H_ITEM, MIN_H_ITEM + extra * 0.4)

            ImGui.Text(ctx, "Project Note:")
            local changed_project
            changed_project, project_note = ImGui.InputTextMultiline(ctx, "##project_note", project_note, avail_w,
                h_project)
            if changed_project then
                GetSetProjectNotes(proj, true, project_note)
            end

            ImGui.Text(ctx, "Track Note:")
            local changed_track
            changed_track, track_note = ImGui.InputTextMultiline(ctx, "##track_note", track_note, avail_w, h_track)
            if changed_track and editing_track then
                GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
            end

            if editing_item then
                local half_w = (avail_w - ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)) / 2

                ImGui.BeginGroup(ctx)
                ImGui.Text(ctx, "Item Rank:")
                ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, RANKS[item_rank].rgba)
                ImGui.SetNextItemWidth(ctx, half_w)
                if ImGui.BeginCombo(ctx, "##item_rank", RANKS[item_rank].name) then
                    for i, rank in ipairs(RANKS) do
                        ImGui.PushStyleColor(ctx, ImGui.Col_Header, rank.rgba)
                        local is_selected = (item_rank == i)
                        if ImGui.Selectable(ctx, rank.name, is_selected) then
                            item_rank = i
                            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_rank", tostring(item_rank), true)
                            -- Apply color to item and group
                            apply_rank_color(editing_item, item_rank)
                        end
                        if is_selected then
                            ImGui.SetItemDefaultFocus(ctx)
                        end
                        ImGui.PopStyleColor(ctx)
                    end
                    ImGui.EndCombo(ctx)
                end
                ImGui.PopStyleColor(ctx)
                ImGui.EndGroup(ctx)

                ImGui.SameLine(ctx)
                ImGui.BeginGroup(ctx)
                ImGui.Text(ctx, "Take Number:")

                ImGui.SetNextItemWidth(ctx, half_w - 30)
                local changed_take_num
                local item_id = tostring(editing_item):sub(-8)
                ImGui.PushID(ctx, item_id)
                changed_take_num, item_take_num = ImGui.InputText(ctx, "##item_take_num", item_take_num)
                if changed_take_num and editing_item then
                    GetSetMediaItemInfo_String(editing_item, "P_EXT:item_take_num", item_take_num, true)
                end

                ImGui.SameLine(ctx)
                if ImGui.Button(ctx, "↻##reset_take", 25, 0) then
                    item_take_num = get_take_number(editing_item)
                    GetSetMediaItemInfo_String(editing_item, "P_EXT:item_take_num", item_take_num, true)
                end
                if ImGui.IsItemHovered(ctx) then
                    ImGui.SetTooltip(ctx, "Reset to filename take number")
                end

                ImGui.EndGroup(ctx)

                ImGui.Text(ctx, "Item Note:")
                local changed_item
                changed_item, item_note = ImGui.InputTextMultiline(ctx, "##item_note", item_note, avail_w, h_item)
                if changed_item and editing_item then
                    GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
                end
                ImGui.PopID(ctx)
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

function get_take_number(item)
    local take = GetActiveTake(item)
    if not take then return "" end

    local src = GetMediaItemTake_Source(take)
    local filename = GetMediaSourceFileName(src, "")

    -- Try to extract take number from filename
    -- Case: (###)[chan X].wav or ### [chan X].wav (with or without space)
    local take_num = tonumber(
        filename:match("(%d+)%)?%s*%[chan%s*%d+%]%.[^%.]+$")
        -- Case: (###).wav or ###.wav
        or filename:match("(%d+)%)?%.[^%.]+$")
    )

    return take_num and tostring(take_num) or ""
end

---------------------------------------------------------------------

function rgba_to_native(rgba)
    local r = (rgba >> 24) & 0xFF
    local g = (rgba >> 16) & 0xFF
    local b = (rgba >> 8) & 0xFF
    -- Use REAPER's ColorToNative function
    return ColorToNative(r, g, b)
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local pathseparator = package.config:sub(1, 1)
    local relative_path = table.concat({ "", "Scripts", "chmaha Scripts", "ReaClassical", "" }, pathseparator)
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function pastel_color(index)
    local golden_ratio_conjugate = 0.61803398875
    local hue                    = (index * golden_ratio_conjugate) % 1.0

    -- Subtle variation in saturation/lightness
    local saturation             = 0.45 + 0.15 * math.sin(index * 1.7)
    local lightness              = 0.70 + 0.1 * math.cos(index * 1.1)

    local function h2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1 / 6 then return p + (q - p) * 6 * t end
        if t < 1 / 2 then return q end
        if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
        return p
    end

    local q = lightness < 0.5 and (lightness * (1 + saturation))
        or (lightness + saturation - lightness * saturation)
    local p = 2 * lightness - q

    local r = h2rgb(p, q, hue + 1 / 3)
    local g = h2rgb(p, q, hue)
    local b = h2rgb(p, q, hue - 1 / 3)

    local color_int = ColorToNative(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )

    return color_int | 0x1000000
end

---------------------------------------------------------------------

function update_take_name(item, rank)
    local take = GetActiveTake(item)
    if not take then return end

    local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

    -- Remove any existing rank prefixes (full names)
    local all_prefixes = { "Excellent", "Very Good", "Good", "OK", "Below Average", "Poor", "Unusable", "False Start" }
    for _, prefix in ipairs(all_prefixes) do
        item_name = item_name:gsub("^" .. prefix .. "%-", "")
        item_name = item_name:gsub("^" .. prefix .. "$", "")
    end

    -- Add new rank prefix if not "No Rank"
    if rank ~= 9 and RANKS[rank].prefix ~= "" then
        if item_name ~= "" then
            item_name = RANKS[rank].prefix .. "-" .. item_name
        else
            item_name = RANKS[rank].prefix
        end
    end

    GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
end

---------------------------------------------------------------------

function get_item_color(item)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local colors = get_color_table()

    -- Determine color to use
    local color_to_use = nil
    local _, saved_guid = GetSetMediaItemInfo_String(item, "P_EXT:src_guid", "", false)

    -- Check GUID first
    if saved_guid ~= "" then
        local referenced_item = nil
        local total_items = CountMediaItems(0)
        for i = 0, total_items - 1 do
            local test_item = GetMediaItem(0, i)
            local _, test_guid = GetSetMediaItemInfo_String(test_item, "GUID", "", false)
            if test_guid == saved_guid then
                referenced_item = test_item
                break
            end
        end

        if referenced_item then
            color_to_use = GetMediaItemInfo_Value(referenced_item, "I_CUSTOMCOLOR")
        end
    end

    if workflow == "Horizontal" then
        local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
        if saved_color ~= "" then
            color_to_use = tonumber(saved_color)
        else
            color_to_use = colors.dest_items
        end
        -- If no GUID color, use folder-based logic
    elseif not color_to_use then
        local item_track = GetMediaItemTrack(item)
        local folder_tracks = {}
        local num_tracks = CountTracks(0)

        -- Build list of folder tracks in project order
        for t = 0, num_tracks - 1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth > 0 then
                table.insert(folder_tracks, track)
            end
        end

        -- Find parent folder track of the item
        local parent_folder = nil
        local track_idx = GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER") - 1
        for t = track_idx, 0, -1 do
            local track = GetTrack(0, t)
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth > 0 then
                parent_folder = track
                break
            end
        end

        -- Compute pastel index: second folder → index 0
        local folder_index = 0

        if parent_folder then
            for i, track in ipairs(folder_tracks) do
                if track == parent_folder then
                    folder_index = i - 2 -- account for dest
                    break
                end
            end
            -- First folder special case
            if folder_index < 0 then
                color_to_use = colors.dest_items -- use default color for first folder
            else
                color_to_use = pastel_color(folder_index)
            end
        else
            -- No folder: fallback to dest_items
            color_to_use = colors.dest_items
        end
    end

    return color_to_use
end

---------------------------------------------------------------------

function apply_rank_color(item, rank)
    local color_to_use

    if rank == 9 then
        -- No Rank selected - restore original color
        color_to_use = get_item_color(item)
    else
        -- Get the color for this rank
        color_to_use = rgba_to_native(RANKS[rank].rgba) | 0x1000000
    end

    -- Apply color to the item
    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color_to_use)

    -- Update take name with rank abbreviation
    update_take_name(item, rank)

    -- Get the group ID of this item
    local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")

    -- If item is in a group, apply color and rank to all items in the same group
    if group_id ~= 0 then
        local track_count = CountTracks(0)
        for i = 0, track_count - 1 do
            local track = GetTrack(0, i)
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local current_item = GetTrackMediaItem(track, j)
                local current_group_id = GetMediaItemInfo_Value(current_item, "I_GROUPID")
                if current_group_id == group_id and current_item ~= item then
                    if rank == 9 then
                        -- No Rank - restore original color for each item in group
                        local current_color = get_item_color(current_item)
                        SetMediaItemInfo_Value(current_item, "I_CUSTOMCOLOR", current_color)
                    else
                        SetMediaItemInfo_Value(current_item, "I_CUSTOMCOLOR", color_to_use)
                    end
                    -- Update take name for grouped items too
                    update_take_name(current_item, rank)
                    -- Store the rank for grouped items
                    GetSetMediaItemInfo_String(current_item, "P_EXT:item_rank", tostring(rank), true)
                end
            end
        end
    end

    UpdateArrange()
end

---------------------------------------------------------------------

defer(main)
