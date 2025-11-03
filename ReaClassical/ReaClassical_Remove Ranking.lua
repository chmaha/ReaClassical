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
local main, modify_item_name, process_items, pastel_color
local get_selected_media_item_at, count_selected_media_items
local get_color_table, get_path
---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end


function main()
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    PreventUIRefresh(1)
    process_items()
    PreventUIRefresh(-1)
    Undo_EndBlock("Remove Take Ranking", -1)
    UpdateArrange()
end

---------------------------------------------------------------------

function modify_item_name(item)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local colors = get_color_table()
    local take = GetActiveTake(item)
    if take ~= nil then
        local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

        -- Clean up item name
        item_name = item_name:gsub("[%+%-]+$", "")
        item_name = item_name:gsub("  $", "")
        GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)

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
                color_to_use = saved_color
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

            -- Count all dest_copy tracks in the project
            local dest_copy_count = 0
            for _, track in ipairs(folder_tracks) do
                local _, dest = GetSetMediaTrackInfo_String(track, "P_EXT:dest_copy", "y", false)
                if dest ~= "" then
                    dest_copy_count = dest_copy_count + 1
                end
            end

            if parent_folder then
                for i, track in ipairs(folder_tracks) do
                    if track == parent_folder then
                        folder_index = i - (2 + dest_copy_count) -- account for dest and dest copies
                        break
                    end
                end
                -- -- First folder special case
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
        -- Apply color to item and all items in its item group
        local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
        local count_items = CountMediaItems(0)
        for i = 0, count_items - 1 do
            local other_item = GetMediaItem(0, i)
            local other_group_id = GetMediaItemInfo_Value(other_item, "I_GROUPID")
            if other_item == item or (group_id ~= 0 and other_group_id == group_id) then
                SetMediaItemInfo_Value(other_item, "I_CUSTOMCOLOR", color_to_use)
                -- GetSetMediaItemInfo_String(item, "P_EXT:saved_color", "", true)
            end
        end
    end
end

---------------------------------------------------------------------

function process_items()
    -- Step 1: Collect all selected items first
    local selected_items = {}
    local count_selected = count_selected_media_items()
    for i = 0, count_selected - 1 do
        local item = get_selected_media_item_at(i)
        if item then
            table.insert(selected_items, item)
        end
    end

    -- Step 2: Deselect any items not on a parent track
    local items_to_process = {}
    for _, item in ipairs(selected_items) do
        local track = GetMediaItem_Track(item)
        if track and GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") > 0 then
            table.insert(items_to_process, item)       -- keep for processing
        else
            SetMediaItemInfo_Value(item, "B_UISEL", 0) -- deselect
        end
    end

    -- Step 3: Process only the items on parent tracks
    for _, item in ipairs(items_to_process) do
        GetSetMediaItemInfo_String(item, "P_EXT:ranked", "", true)
        modify_item_name(item)
    end
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
function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

main()
