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

local main, get_color_table, get_path
local get_selected_media_item_at
---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
    local fade_editor_state = GetToggleCommandState(fade_editor_toggle)
    if fade_editor_state ~= 1 then
        MB('This ReaClassical function only works while in the fade editor (F)',
            "Edit Classical Crossfade",
            0)
        return
    end
    local item_one, item_two, color, prev_item, next_item, curpos, diff

    item_one = get_selected_media_item_at(0)
    item_two = get_selected_media_item_at(1)
    if not item_one and not item_two then
        MB("Please select at least one of the items involved in the crossfade",
            "Edit Classical Crossfade", 0)
        return
    elseif item_one and not item_two then
        local colors = get_color_table()
        color = GetMediaItemInfo_Value(item_one, "I_CUSTOMCOLOR")
        if color == colors.xfade_green then
            item_two = item_one
            prev_item = NamedCommandLookup("_SWS_SELPREVITEM")
            Main_OnCommand(prev_item, 0)
            item_one = get_selected_media_item_at(0)
        else
            next_item = NamedCommandLookup("_SWS_SELNEXTITEM")
            Main_OnCommand(next_item, 0)
            item_two = get_selected_media_item_at(0)
        end
    end
    local one_pos = GetMediaItemInfo_Value(item_one, "D_POSITION")
    local one_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
    local two_pos = GetMediaItemInfo_Value(item_two, "D_POSITION")
    BR_GetMouseCursorContext()
    local mouse_pos = BR_GetMouseCursorContext_Position()

    Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
    local end_of_one = one_pos + one_length

    if mouse_pos < two_pos then
        SetEditCurPos(mouse_pos, false, false)
        curpos = GetCursorPosition()
        SetMediaItemSelected(item_two, true)
        Main_OnCommand(41305, 0) -- extend item left
        SetMediaItemSelected(item_two, false)
        SetMediaItemSelected(item_one, true)
        diff = end_of_one - curpos
        SetEditCurPos(end_of_one + diff, false, false)
        Main_OnCommand(41991, 0) -- toggle ripple-all OFF
        Main_OnCommand(41311, 0) -- extend item right
        Main_OnCommand(41991, 0) -- toggle ripple-all ON
    elseif mouse_pos > two_pos then
        SetEditCurPos(mouse_pos, false, false)
        SetMediaItemSelected(item_one, true)
        Main_OnCommand(41991, 0) -- toggle ripple-all OFF
        Main_OnCommand(41311, 0) -- extend item right
        SetMediaItemSelected(item_one, false)
        SetMediaItemSelected(item_two, true)
        one_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
        end_of_one = one_pos + one_length
        diff = end_of_one - two_pos
        SetEditCurPos(two_pos - diff, false, false)
        Main_OnCommand(41305, 0) -- extend item left
        Main_OnCommand(41991, 0) -- toggle ripple-all ON
    end

    SetMediaItemSelected(item_one, false)
    SetMediaItemSelected(item_two, false)
    two_pos = GetMediaItemInfo_Value(item_two, "D_POSITION")
    one_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
    local one_end = one_pos + one_length
    SetEditCurPos(two_pos + ((one_end - two_pos) / 2), false, false)
    Undo_EndBlock('Edit Classical Crossfade', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
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
