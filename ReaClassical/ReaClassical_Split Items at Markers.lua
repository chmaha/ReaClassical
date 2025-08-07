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
local main, split_items_at_markers, clear_item_names_from_selected

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    split_items_at_markers()
    Undo_EndBlock('ReaClassical Split Items at Markers', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function split_items_at_markers()
    local cursor_pos = GetCursorPosition() -- Save current edit cursor position

    -- Collect all regular (non-region) markers and their names
    local marker_data = {}
    local _, num_markers, _ = CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, _, name, markrgnindex = EnumProjectMarkers(i)
        if retval and not isrgn then
            local label = name ~= "" and name or ("Marker " .. tostring(markrgnindex))
            table.insert(marker_data, {pos = pos, name = label})
        end
    end

    for _, marker in ipairs(marker_data) do
        SetEditCurPos(marker.pos, false, false)
        Main_OnCommand(40289, 0) -- Unselect all items

        local item_count = CountMediaItems(0)
        for i = 0, item_count - 1 do
            local item = GetMediaItem(0, i)
            local track = GetMediaItemTrack(item)
            local track_index = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
            if track_index == 1 then
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len

                if marker.pos > item_pos and marker.pos < item_end then
                    SetMediaItemSelected(item, true)
                    Main_OnCommand(40034, 0) -- Select all items in group
                    Main_OnCommand(40012, 0) -- Split at timeline markers

                    clear_item_names_from_selected()

                    local new_item_count = CountMediaItems(0)
                    for j = 0, new_item_count - 1 do
                        local new_item = GetMediaItem(0, j)
                        local new_track = GetMediaItemTrack(new_item)
                        local new_track_index = GetMediaTrackInfo_Value(new_track, "IP_TRACKNUMBER")
                        local new_item_pos = GetMediaItemInfo_Value(new_item, "D_POSITION")

                        if new_track_index == 1 and math.abs(new_item_pos - marker.pos) < 0.0001 then
                            local take = GetActiveTake(new_item)
                            if take then
                                GetSetMediaItemTakeInfo_String(take, "P_NAME", marker.name, true)
                                break
                            end
                        end
                    end

                    break -- Only process one group per marker
                end
            end
        end
    end

    SetEditCurPos(cursor_pos, false, false) -- Restore cursor position
end

---------------------------------------------------------------------

function clear_item_names_from_selected()
    local selected_item_count = CountSelectedMediaItems(0)
    for i = 0, selected_item_count - 1 do
        local item = GetSelectedMediaItem(0, i)
        if item then
            local take = GetActiveTake(item)
            if take then
                GetSetMediaItemTakeInfo_String(take, "P_NAME", "", true)
            end
        end
    end
end

---------------------------------------------------------------------

main()

