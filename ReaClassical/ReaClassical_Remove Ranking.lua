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
local main, modify_item_name, process_items
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
    Undo_EndBlock("Remove Take Ranking", -1)
    UpdateArrange()
end

---------------------------------------------------------------------

function modify_item_name(item)
    local take = GetActiveTake(item)
    if take ~= nil then
        local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

        item_name = item_name:gsub("[%+%-]+$", "")
        item_name = item_name:gsub("  $", "") -- remove double space if present

        GetSetMediaItemTakeInfo_String(take, "P_NAME", item_name, true)

        SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", 0)

        local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")

        local count_items = CountMediaItems(0)
        for i = 0, count_items - 1 do
            local other_item = GetMediaItem(0, i)
            local other_group_id = GetMediaItemInfo_Value(other_item, "I_GROUPID")
            if other_group_id == group_id then
                SetMediaItemInfo_Value(other_item, "I_CUSTOMCOLOR", 0)
            end
        end
    end
end

---------------------------------------------------------------------

function process_items()
    local count_selected = count_selected_media_items()

    if count_selected > 0 then
        -- Process selected items
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
