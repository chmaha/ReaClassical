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
local main, count_selected_media_items, get_selected_media_item_at
local get_color_table, get_path
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
    -- Safety check 1: Exactly one item selected
    local sel_count = count_selected_media_items(0)
    if sel_count ~= 1 then
        MB("Error: Please select exactly one item.", "Error", 0)
        return
    end

    local item = get_selected_media_item_at(0)

    -- Safety check 2: Ensure it's on the first track
    local track = GetMediaItemTrack(item)
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    if track_idx ~= 1 then
        MB("Error: The selected item must be on the first track.", "Error", 0)
        return
    end

    local _, saved_data = GetSetMediaItemInfo_String(item, "P_EXT:src_details", "", false)
    local saved_guid, offset_src_in, offset_src_out, track_number
    if saved_data ~= "" then
        local src_details = {}
        for entry in saved_data:gmatch('([^,]+)') do src_details[#src_details + 1] = entry end
        if src_details[1] then saved_guid = src_details[1] or nil end
        if src_details[2] then offset_src_in = src_details[2] or nil end
        if src_details[3] then offset_src_out = src_details[3] or nil end
        if src_details[4] then track_number = src_details[4] or nil end
    end

    if not saved_guid or not offset_src_in or not offset_src_out or not track_number then
        MB("Error: No S-D edit data for this item.", "Error", 0)
        return
    end

    local off_998 = tonumber(offset_src_in)
    local off_999 = tonumber(offset_src_out)

    -- Compare GUID
    local source_item = BR_GetMediaItemByGUID(0, saved_guid)
    if not source_item then
        MB("Error: Source item no longer exists!", "Error", 0)
        return
    end

    -- Compute marker positions relative to current item start
    local item_start = GetMediaItemInfo_Value(source_item, "D_POSITION")
    local item_len   = GetMediaItemInfo_Value(source_item, "D_LENGTH")
    local pos_998    = item_start + off_998
    local pos_999    = item_start + off_999

    -- Check that markers fall within item boundaries
    if pos_998 < item_start or pos_998 > item_start + item_len
        or pos_999 < item_start or pos_999 > item_start + item_len then
        MB("Error: One or both markers fall outside the item bounds.", "Error", 0)
        return
    end

    -- Delete any existing markers 998 or 999 before creating new ones
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then
            break
        else
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
        end
        i = i + 1
    end

    -- Create the markers
    local color_track = GetMediaItemTrack(source_item)
    local marker_color = color_track and GetTrackColor(color_track) or 0
    AddProjectMarker2(0, false, pos_998, 0, track_number .. ":SOURCE-IN", 998, marker_color)
    AddProjectMarker2(0, false, pos_999, 0, track_number .. ":SOURCE-OUT", 999, marker_color)
    local move_to_src_in = NamedCommandLookup("_RS7316313701a4b3bdc2e4c32420a84204827b0ae9")
    Main_OnCommand(move_to_src_in, 0)
    SetOnlyTrackSelected(color_track)

    Undo_EndBlock('Find Source Material', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
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
