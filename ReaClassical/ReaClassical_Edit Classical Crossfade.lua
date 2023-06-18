--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
    local fade_editor_state = GetToggleCommandState(fade_editor_toggle)
    if fade_editor_state ~= 1 then
        ShowMessageBox('This ReaClassical script only works while in the fade editor (F)', "Edit Classical Crossfade", 0)
        return
    end
    local item_one, item_two, color, prev_item, next_item, curpos, diff

    item_one = GetSelectedMediaItem(0, 0)
    item_two = GetSelectedMediaItem(0, 1)
    if not item_one and not item_two then
        ShowMessageBox("Please select at least one of the items involved in the crossfade", "Edit Classical Crossfade", 0)
        return
    elseif item_one and not item_two then
        color = GetMediaItemInfo_Value(item_one, "I_CUSTOMCOLOR")
        if color == 20967993 then
            item_two = item_one
            prev_item = NamedCommandLookup("_SWS_SELPREVITEM")
            Main_OnCommand(prev_item, 0)
            item_one = GetSelectedMediaItem(0, 0)
        else
            next_item = NamedCommandLookup("_SWS_SELNEXTITEM")
            Main_OnCommand(next_item, 0)
            item_two = GetSelectedMediaItem(0, 0)
        end
    end
    local one_pos = GetMediaItemInfo_Value(item_one, "D_POSITION")
    local one_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
    local two_pos = GetMediaItemInfo_Value(item_two, "D_POSITION")
    Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
    BR_GetMouseCursorContext()
    local mouse_pos = BR_GetMouseCursorContext_Position()
    local item_hover = BR_GetMouseCursorContext_Item()
    local end_of_one = one_pos + one_length
    local overlap = end_of_one - two_pos
    local mouse_to_item_two = two_pos - mouse_pos
    local total_time = 2 * mouse_to_item_two + overlap

    if not item_hover and mouse_pos < two_pos then
        SetMediaItemInfo_Value(item_one, "C_LOCK", 0) --unlock item 1
        SetEditCurPos(mouse_pos, false, false)
        curpos = GetCursorPosition()
        SetMediaItemSelected(item_two, true)
        Main_OnCommand(41305, 0) -- extend item left
        SetMediaItemSelected(item_two, false)
        SetMediaItemSelected(item_one, true)
        diff = end_of_one - curpos
        SetEditCurPos(end_of_one + diff, false, false)
        Main_OnCommand(41991, 0)                      -- toggle ripple-all OFF
        Main_OnCommand(41311, 0)                      -- extend item right
        Main_OnCommand(41991, 0)                      -- toggle ripple-all ON
        SetMediaItemInfo_Value(item_one, "C_LOCK", 1) --lock item 1
    elseif not item_hover and mouse_pos > two_pos then
        SetMediaItemInfo_Value(item_one, "C_LOCK", 0) --unlock item 1
        SetEditCurPos(mouse_pos, false, false)
        curpos = GetCursorPosition()
        SetMediaItemSelected(item_one, true)
        Main_OnCommand(41991, 0)                      -- toggle ripple-all OFF
        Main_OnCommand(41311, 0)                      -- extend item right
        SetMediaItemSelected(item_one, false)
        SetMediaItemInfo_Value(item_one, "C_LOCK", 1) --lock item 1
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

main()
