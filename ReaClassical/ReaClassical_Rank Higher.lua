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
local main, modify_item_name, process_items, get_color_table, get_path
local get_selected_media_item_at, count_selected_media_items
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
    Undo_EndBlock("Rank Take Higher", -1)
    UpdateArrange()
end

---------------------------------------------------------------------

function modify_item_name(item)
    local take = GetActiveTake(item)
    if take ~= nil then
        local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

        local count_minus = item_name:match("%-*$")
        count_minus = count_minus and #count_minus or 0
        local count_plus = 0
        if count_minus > 0 then
            item_name = item_name:sub(1, #item_name - 1)
            count_minus = count_minus - 1
            if count_minus == 0 then
                item_name = item_name:gsub("  $", "")
            end
        else
            count_plus = item_name:match("%+*$")
            count_plus = count_plus and #count_plus or 0

            if count_plus < 3 then
                -- Ensure two spaces before adding the first '+'
                if count_plus == 0 and not item_name:find("  +$") then
                    item_name = item_name:gsub("%s*$", "") .. "  +"
                else
                    item_name = item_name .. "+"
                end
                count_plus = count_plus + 1
            end
        end

        GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)
        local colors = get_color_table()
        local rank = count_plus - count_minus
        local color_item = {
            [3] = function()
                return colors.rank_excellent
            end,
            [2] = function()
                return colors.rank_very_good
            end,
            [1] = function()
                return colors.rank_good
            end,
            [0] = function()
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

                -- If no GUID color, use folder-based logic
                if not color_to_use then
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
                    for t = track_idx - 1, 0, -1 do
                        local track = GetTrack(0, t)
                        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
                        if depth > 0 then
                            parent_folder = track
                            break
                        end
                    end

                    -- Compute pastel index: second folder → index 0
                    local folder_index = 0
                    local colors = get_color_table()
                    if parent_folder then
                        for i, track in ipairs(folder_tracks) do
                            if track == parent_folder then
                                folder_index = i - 1 -- subtract 1 so second folder → 0
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
            end,
            [-1] = function()
                return colors.rank_below_average
            end,
            [-2] = function()
                return colors.rank_poor
            end,
            [-3] = function()
                return colors.rank_unusable
            end,
        }

        local color = color_item[rank] and color_item[rank]() or 0

        SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", color)

        local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")

        local count_items = CountMediaItems(0)
        for i = 0, count_items - 1 do
            local other_item = GetMediaItem(0, i)
            local other_group_id = GetMediaItemInfo_Value(other_item, "I_GROUPID")
            if other_group_id == group_id then
                SetMediaItemInfo_Value(other_item, "I_CUSTOMCOLOR", color)
            end
        end
    end
end

---------------------------------------------------------------------

function process_items()
    local count_selected = count_selected_media_items()

    if count_selected > 0 then
        for i = 0, count_selected - 1 do
            local item = get_selected_media_item_at(i)
            modify_item_name(item)
        end
    else
        local _, recorded_item_guid = GetProjExtState(0, "ReaClassical", "LastRecordedItem")
        if recorded_item_guid ~= "" then
            local recorded_item = BR_GetMediaItemByGUID(0, recorded_item_guid)
            if recorded_item then
                modify_item_name(recorded_item)
            else
                MB("The previously recorded item no longer exists.", "ReaClassical Take Ranking", 0)
                SetProjExtState(0, "ReaClassical", "LastRecordedItem", "")
            end
        end
    end
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

main()
