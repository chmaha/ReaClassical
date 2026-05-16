--[[
@noindex
This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.
Copyright (C) 2022–2026 chmaha
MODIFIED VERSION - Ensures all items with same midpoint are colored together
ADDED: Color preset saving and recall functionality
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
local apply_color_to_items, remove_custom_coloring, get_all_items_at_midpoints
local load_presets, save_presets, get_items_at_midpoint
local get_folder_range_for_item

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
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
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

local DEFAULT_W = 337
local DEFAULT_H = 530

-- Color state in 0xXXRRGGBB format (XX is ignored)
local selected_color_rgb = 0x00FF8000 -- Orange color (00RRGGBB)

-- Message state for ImGui-based messages
local message_text = ""
local message_timer = 0
local message_duration = 3.0 -- seconds

-- Color presets (up to 13 slots)
local MAX_PRESETS = 13
local color_presets = {}

-- Initialize presets with default colors
local function init_presets()
    local defaults = {
        0x00F44336, -- Red 500
        0x00FF9800, -- Orange 500
        0x00FFEB3B, -- Yellow 500
        0x00CDDC39, -- Lime 500
        0x004CAF50, -- Green 500
        0x002196F3, -- Blue 500
        0x009C27B0, -- Purple 500
        0x00E91E63, -- Pink 500
        0x0000BCD4, -- Cyan 500
        0x00FF5722, -- Deep Orange 500
        0x00673AB7, -- Deep Purple 500
        0x00009688, -- Teal 500
        0x00795548, -- Brown 500
    }
    for i = 1, MAX_PRESETS do
        color_presets[i] = defaults[i] or 0x00C0C0C0
    end
end

---------------------------------------------------------------------

function load_presets()
    local saved_data = GetExtState("ReaClassical", "ColorizerPresets")
    if saved_data ~= "" then
        local idx = 1
        for color_str in saved_data:gmatch('([^,]+)') do
            if idx <= MAX_PRESETS then
                local color = tonumber(color_str)
                if color then color_presets[idx] = color end
                idx = idx + 1
            end
        end
    end
end

---------------------------------------------------------------------

function save_presets()
    local preset_string = ""
    for i = 1, MAX_PRESETS do
        if i > 1 then preset_string = preset_string .. "," end
        preset_string = preset_string .. tostring(color_presets[i])
    end
    SetExtState("ReaClassical", "ColorizerPresets", preset_string, true)
end

---------------------------------------------------------------------

-- Resolves the folder track range (0-based indices) that contains ref_item.
function get_folder_range_for_item(ref_item)
    local track = GetMediaItem_Track(ref_item)
    local track_num = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local start_search = track_num
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
    local folder_start, folder_end = nil, nil
    for t = start_search, num_tracks - 1 do
        local tt = GetTrack(0, t)
        if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    return folder_start, folder_end
end

---------------------------------------------------------------------

function get_items_at_midpoint(ref_item)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    local folder_start, folder_end = get_folder_range_for_item(ref_item)
    if not folder_start then return result end
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

---------------------------------------------------------------------

-- For every selected item, collect it and all project items sharing its
-- midpoint. De-duplicated.
function get_all_items_at_midpoints()
    local seen = {}
    local result = {}
    local sel_count = count_selected_media_items()
    for i = 0, sel_count - 1 do
        local sel_item = get_selected_media_item_at(i)
        if sel_item and not seen[sel_item] then
            local peers = get_items_at_midpoint(sel_item)
            for _, peer in ipairs(peers) do
                if not seen[peer] then
                    seen[peer] = true
                    result[#result + 1] = peer
                end
            end
        end
    end
    return result
end

---------------------------------------------------------------------

function main()
    if window_open then
        ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, math.huge, math.huge)
        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Colorizer", window_open)
        window_open = open_ref

        if opened then
            local avail_w = ImGui.GetContentRegionAvail(ctx)

            local sel_count = count_selected_media_items()

            ImGui.Text(ctx, string.format("Selected items: %d", sel_count))
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "Choose Color:")

            local flags = ImGui.ColorEditFlags_NoAlpha | ImGui.ColorEditFlags_PickerHueWheel |
                ImGui.ColorEditFlags_DisplayRGB
            local changed, new_color = ImGui.ColorPicker4(ctx, '##color', selected_color_rgb, flags)

            if changed then
                selected_color_rgb = new_color
            end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "Color Presets:")
            ImGui.Spacing(ctx)

            local preset_size = 20
            local spacing = 5

            for i = 1, MAX_PRESETS do
                if i > 1 then
                    ImGui.SameLine(ctx, 0, spacing)
                end

                ImGui.PushID(ctx, i)

                local preset_color = color_presets[i]

                if ImGui.ColorButton(ctx, '##preset' .. i, preset_color,
                        ImGui.ColorEditFlags_NoAlpha | ImGui.ColorEditFlags_NoBorder,
                        preset_size, preset_size) then
                    selected_color_rgb = preset_color
                    message_text = string.format("Loaded preset #%d", i)
                    message_timer = ImGui.GetTime(ctx)
                end

                if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
                    color_presets[i] = selected_color_rgb
                    save_presets()
                    message_text = string.format("Saved to preset #%d", i)
                    message_timer = ImGui.GetTime(ctx)
                end

                if ImGui.IsItemHovered(ctx) then
                    ImGui.SetTooltip(ctx, "Left-click: Load\nRight-click: Save current color")
                end

                ImGui.PopID(ctx)
            end

            ImGui.Spacing(ctx)

            if ImGui.Button(ctx, 'Reset Palette to Default Colors', avail_w, 25) then
                init_presets()
                save_presets()
                message_text = "Palette reset to default colors."
                message_timer = ImGui.GetTime(ctx)
            end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            if ImGui.Button(ctx, 'Apply Color to Selected Items', avail_w, 30) then
                if sel_count > 0 then
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

            if message_text ~= "" then
                local current_time = ImGui.GetTime(ctx)
                if current_time - message_timer < message_duration then
                    local time_left = message_duration - (current_time - message_timer)
                    local alpha = math.min(1.0, time_left / 0.5)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text, ImGui.ColorConvertDouble4ToU32(0.2, 0.8, 0.2, alpha))
                    ImGui.TextWrapped(ctx, message_text)
                    ImGui.PopStyleColor(ctx)
                else
                    message_text = ""
                end
            end

            if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_K, false) then
                window_open = false
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
            if selected_count == index then return item end
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
        if IsMediaItemSelected(item) then selected_count = selected_count + 1 end
    end
    return selected_count
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

    local items_to_color = get_all_items_at_midpoints()

    if #items_to_color == 0 then
        PreventUIRefresh(-1)
        message_text = "No items to process."
        message_timer = ImGui.GetTime(ctx)
        return
    end

    for _, item in ipairs(items_to_color) do
        if item then
            local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
            if saved_color == "" then
                local original_color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR")
                GetSetMediaItemInfo_String(item, "P_EXT:saved_color", tostring(original_color), true)
            end
            SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)
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

    local items_to_restore = get_all_items_at_midpoints()

    if #items_to_restore == 0 then
        PreventUIRefresh(-1)
        message_text = "No items to process."
        message_timer = ImGui.GetTime(ctx)
        return
    end

    local restored_count = 0

    for _, item in ipairs(items_to_restore) do
        if item then
            local _, saved_color = GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", false)
            if saved_color ~= "" then
                local original_color
                if auto_color_pref == 1 then
                    original_color = 0
                else
                    original_color = tonumber(saved_color) or 0
                end
                SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", original_color)
                GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", true)
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

init_presets()
load_presets()

defer(main)