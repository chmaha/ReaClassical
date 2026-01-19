--[[
@noindex
This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.
Copyright (C) 2022–2026 chmaha
MODIFIED VERSION - Ensures all items with same group ID are colored together
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

local main, get_selected_media_item_at, count_selected_media_items
local apply_color_to_items, remove_custom_coloring, get_all_items_in_groups

---------------------------------------------------------------------

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
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

-- Read preferences for auto_color_pref
local auto_color_pref = 0
local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[5] then auto_color_pref = tonumber(table[5]) or 0 end
end

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('ReaClassical Colorizer')
local window_open = true

local DEFAULT_W = 350
local DEFAULT_H = 435

-- Color state in 0xXXRRGGBB format (XX is ignored)
local selected_color_rgb = 0x00FF8000 -- Orange color (00RRGGBB)

-- Message state for ImGui-based messages
local message_text = ""
local message_timer = 0
local message_duration = 3.0 -- seconds

---------------------------------------------------------------------

function main()
    if window_open then
        -- Set minimum window size constraints instead of AlwaysAutoResize
        ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, math.huge, math.huge)
        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Colorizer", window_open)
        window_open = open_ref

        if opened then
            local avail_w = ImGui.GetContentRegionAvail(ctx)

            -- Get selection info
            local sel_count = count_selected_media_items()

            ImGui.Text(ctx, string.format("Selected items: %d", sel_count))
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            -- Color picker
            ImGui.Text(ctx, "Choose Color:")

            -- ColorPicker4 with NoAlpha flag to show full picker immediately (uses 0xXXRRGGBB format)
            local flags = ImGui.ColorEditFlags_NoAlpha | ImGui.ColorEditFlags_PickerHueWheel |
            ImGui.ColorEditFlags_DisplayRGB
            local changed, new_color = ImGui.ColorPicker4(ctx, '##color', selected_color_rgb, flags)

            if changed then
                selected_color_rgb = new_color
            end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            -- Apply button
            if ImGui.Button(ctx, 'Apply Color to Selected Items', avail_w, 30) then
                if sel_count > 0 then
                    -- Convert ImGui color (0xXXRRGGBB) to REAPER color (0xBBGGRR with custom flag)
                    local r = (selected_color_rgb >> 16) & 0xFF
                    local g = (selected_color_rgb >> 8) & 0xFF
                    local b = selected_color_rgb & 0xFF
                    local reaper_color = b | (g << 8) | (r << 16) | 0x1000000
                    apply_color_to_items(reaper_color)
                else
                    message_text = "Please select one or more items first."
                    message_timer = ImGui.GetTime(ctx)
                end
            end

            ImGui.Spacing(ctx)

            -- Remove coloring button
            if ImGui.Button(ctx, 'Remove Custom Coloring', avail_w, 30) then
                if sel_count > 0 then
                    remove_custom_coloring()
                else
                    message_text = "Please select one or more items first."
                    message_timer = ImGui.GetTime(ctx)
                end
            end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            -- Display message if active
            if message_text ~= "" then
                local current_time = ImGui.GetTime(ctx)
                if current_time - message_timer < message_duration then
                    -- Calculate fade out alpha
                    local time_left = message_duration - (current_time - message_timer)
                    local alpha = math.min(1.0, time_left / 0.5) -- Fade out in last 0.5 seconds

                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, ImGui.ColorConvertDouble4ToU32(0.2, 0.8, 0.2, alpha))
                    ImGui.TextWrapped(ctx, message_text)
                    ImGui.PopStyleColor(ctx)
                else
                    message_text = "" -- Clear message after duration
                end
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end
    return nil
end

---------------------------------------------------------------------

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            selected_count = selected_count + 1
        end
    end
    return selected_count
end

---------------------------------------------------------------------

function get_all_items_in_groups()
    local group_ids = {}
    local items_to_process = {}
    local processed = {}

    -- First pass: collect all group IDs from selected items
    local sel_count = count_selected_media_items()
    for i = 0, sel_count - 1 do
        local item = get_selected_media_item_at(i)
        if item then
            local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
            if group_id > 0 then
                group_ids[group_id] = true
            end
            -- Also include the selected item itself (even if no group)
            processed[item] = true
            table.insert(items_to_process, item)
        end
    end

    -- Second pass: collect all items that belong to these groups
    if next(group_ids) then
        local total_items = CountMediaItems(0)
        for i = 0, total_items - 1 do
            local item = GetMediaItem(0, i)
            if not processed[item] then
                local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
                if group_id > 0 and group_ids[group_id] then
                    processed[item] = true
                    table.insert(items_to_process, item)
                end
            end
        end
    end

    return items_to_process
end

---------------------------------------------------------------------

function apply_color_to_items(color)
    Undo_BeginBlock()
    PreventUIRefresh(1)

    local sel_count = count_selected_media_items()
    if sel_count == 0 then
        PreventUIRefresh(-1)
        message_text = "No items selected."
        message_timer = ImGui.GetTime(ctx)
        return
    end

    -- MODIFIED: Get all items including grouped items
    local items_to_color = get_all_items_in_groups()

    if #items_to_color == 0 then
        PreventUIRefresh(-1)
        message_text = "No items to process."
        message_timer = ImGui.GetTime(ctx)
        return
    end

    -- Save original colors and apply new color
    for _, item in ipairs(items_to_color) do
        if item then
            -- Save original color if not already saved
            local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
            if saved_color == "" then
                local original_color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
                GetSetMediaItemInfo_String(item, "P_EXT:saved_color", tostring(original_color), true)
            end

            -- Apply new color
            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)

            -- Mark as colorized
            GetSetMediaItemInfo_String(item, "P_EXT:colorized", "y", true)
        end
    end

    message_text = string.format("Applied color to %d item(s).", #items_to_color)
    message_timer = ImGui.GetTime(ctx)

    UpdateArrange()
    PreventUIRefresh(-1)
    Undo_EndBlock("ReaClassical Colorize Items", 0)
end

---------------------------------------------------------------------

function remove_custom_coloring()
    Undo_BeginBlock()
    PreventUIRefresh(1)

    local sel_count = count_selected_media_items()
    if sel_count == 0 then
        PreventUIRefresh(-1)
        message_text = "No items selected."
        message_timer = ImGui.GetTime(ctx)
        return
    end

    -- MODIFIED: Get all items including grouped items
    local items_to_restore = get_all_items_in_groups()

    if #items_to_restore == 0 then
        PreventUIRefresh(-1)
        message_text = "No items to process."
        message_timer = ImGui.GetTime(ctx)
        return
    end

    local restored_count = 0

    -- Restore original colors
    for _, item in ipairs(items_to_restore) do
        if item then
            local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
            if saved_color ~= "" then
                local original_color
                
                -- Check auto_color_pref setting
                if auto_color_pref == 1 then
                    -- When auto_color_pref is enabled, restore to default color (0)
                    original_color = 0
                else
                    -- When auto_color_pref is disabled, restore to saved color
                    original_color = tonumber(saved_color) or 0
                end
                
                SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", original_color)

                -- Clear saved color
                GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", true)

                -- Clear colorized flag
                GetSetMediaItemInfo_String(item, "P_EXT:colorized", "", true)

                restored_count = restored_count + 1
            end
        end
    end

    UpdateArrange()
    PreventUIRefresh(-1)
    Undo_EndBlock("ReaClassical Remove Custom Coloring", 0)

    if restored_count > 0 then
        message_text = string.format("Restored original colors for %d item(s).", restored_count)
        message_timer = ImGui.GetTime(ctx)
    else
        message_text = "No items with saved colors found."
        message_timer = ImGui.GetTime(ctx)
    end
end

---------------------------------------------------------------------

defer(main)