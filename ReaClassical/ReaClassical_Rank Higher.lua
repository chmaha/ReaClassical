--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    Undo_BeginBlock()
    process_items()
    Undo_EndBlock("Add '+' suffix to item name", -1)
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
        else
            count_plus = item_name:match("%+*$")
            count_plus = count_plus and #count_plus or 0

            if count_plus < 3 then
                item_name = item_name .. "+"
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
                return 0 -- Default color
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
    local count_selected = CountSelectedMediaItems(0)

    if count_selected > 0 then
        for i = 0, count_selected - 1 do
            local item = GetSelectedMediaItem(0, i)
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

main()