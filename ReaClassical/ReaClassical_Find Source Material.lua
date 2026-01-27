--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2026 chmaha

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
local main, get_selected_media_item_at
local get_item_by_guid, find_item_by_source_file


---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()

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

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local auto_color_pref = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[5] then auto_color_pref = tonumber(table[5]) or 0 end
    end

    local edit_item = get_selected_media_item_at(0)
    if not edit_item then
        MB("No items selected.", "Error", 0)
        return
    end

    local _, saved_guid = GetSetMediaItemInfo_String(edit_item, "P_EXT:src_guid", "", false)

    local source_item = nil

    -- Try to find by GUID first
    if saved_guid ~= "" then
        source_item = get_item_by_guid(0, saved_guid)
    end

    -- Fallback: search by source file
    local found_via_fallback = false
    if not source_item then
        local edit_take = GetActiveTake(edit_item)
        if not edit_take then
            MB("Error: No active take on selected item.", "Error", 0)
            return
        end

        local edit_source = GetMediaItemTake_Source(edit_take)
        if not edit_source then
            MB("Error: No media source on selected item.", "Error", 0)
            return
        end

        local edit_filename = GetMediaSourceFileName(edit_source, "")

        -- Calculate the required range based on edit item
        local edit_startoffs = GetMediaItemTakeInfo_Value(edit_take, "D_STARTOFFS")
        local edit_len = GetMediaItemInfo_Value(edit_item, "D_LENGTH")
        local playrate = GetMediaItemTakeInfo_Value(edit_take, "D_PLAYRATE")

        local required_start = edit_startoffs
        local required_end = edit_startoffs + (edit_len * playrate)

        source_item = find_item_by_source_file(0, edit_filename, required_start, required_end, edit_item)

        if not source_item then
            MB("Error: Could not find source item by GUID or matching source file.", "Error", 0)
            return
        end

        found_via_fallback = true
    end

    -- If found via fallback, match colors and store GUID
    if found_via_fallback then
        local source_take = GetActiveTake(source_item)
        local source_color = GetDisplayedMediaItemColor2(source_item, source_take)
        local edit_group_id = GetMediaItemInfo_Value(edit_item, "I_GROUPID")

        -- Get the source item's GUID
        local _, source_guid = GetSetMediaItemInfo_String(source_item, "GUID", "", false)

        -- Set color and GUID for the edit item

        if auto_color_pref == 0 then
            SetMediaItemInfo_Value(edit_item, "I_CUSTOMCOLOR", source_color)
        end
        GetSetMediaItemInfo_String(edit_item, "P_EXT:src_guid", source_guid, true)

        -- Set color and GUID for all items in the same group
        if edit_group_id ~= 0 then
            local numItems = CountMediaItems(0)
            for i = 0, numItems - 1 do
                local item = GetMediaItem(0, i)
                local group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
                if group_id == edit_group_id then
                    SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", source_color)
                    GetSetMediaItemInfo_String(item, "P_EXT:src_guid", source_guid, true)
                end
            end
        end
    end

    -- --- Gather key values ---
    local src_start      = GetMediaItemInfo_Value(source_item, "D_POSITION")
    local src_len        = GetMediaItemInfo_Value(source_item, "D_LENGTH")
    local src_startoffs  = GetMediaItemTakeInfo_Value(GetActiveTake(source_item), "D_STARTOFFS")

    local take           = GetActiveTake(edit_item)
    local edit_startoffs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local edit_len       = GetMediaItemInfo_Value(edit_item, "D_LENGTH")
    local playrate       = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")


    -- --- Compute difference between source and edited start offsets ---
    local offset_diff = edit_startoffs - src_startoffs
    local pos_in      = src_start + offset_diff
    local pos_out     = pos_in + (edit_len * playrate)

    -- Safety: ensure both IN and OUT markers fit within the source item
    -- Allow small tolerance for floating-point precision issues
    local tolerance   = 0.001 -- 1 millisecond tolerance
    if pos_in < src_start - tolerance or pos_out > src_start + src_len + tolerance then
        MB("Error: Edited section exceeds the source item boundaries.", "Error", 0)
        return
    end

    -- --- Remove existing 998/999 markers ---
    local i = 0
    while true do
        local proj = EnumProjects(i)
        if not proj then break end
        DeleteProjectMarker(proj, 998, false)
        DeleteProjectMarker(proj, 999, false)
        i = i + 1
    end

    -- --- Add markers ---
    local marker_color = GetTrackColor(GetMediaItemTrack(source_item)) or 0
    AddProjectMarker2(0, false, pos_in, 0, "SOURCE-IN", 998, marker_color)
    AddProjectMarker2(0, false, pos_out, 0, "SOURCE-OUT", 999, marker_color)

    -- --- Optionally move to IN marker ---
    local move_to_src_in = NamedCommandLookup("_RS7316313701a4b3bdc2e4c32420a84204827b0ae9")
    if move_to_src_in then Main_OnCommand(move_to_src_in, 0) end

    SetOnlyTrackSelected(GetMediaItemTrack(source_item))

    Undo_EndBlock('Find Source Material (simplified)', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local edit_item = GetMediaItem(0, i)
        if IsMediaItemSelected(edit_item) then
            if selected_count == index then
                return edit_item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

---------------------------------------------------------------------

function get_item_by_guid(project, guid)
    if not guid or guid == "" then return nil end
    project = project or 0 -- default to current project if nil

    local numItems = CountMediaItems(project)
    for i = 0, numItems - 1 do
        local item = GetMediaItem(project, i)
        local retval, itemGUID = GetSetMediaItemInfo_String(item, "GUID", "", false)
        if retval and itemGUID == guid then
            return item
        end
    end

    return nil -- not found
end

---------------------------------------------------------------------

function find_item_by_source_file(project, filename, required_start, required_end, exclude_item)
    if not filename or filename == "" then return nil end
    project = project or 0

    -- Get the group ID of the exclude_item (edit item)
    local exclude_group_id = nil
    if exclude_item then
        exclude_group_id = GetMediaItemInfo_Value(exclude_item, "I_GROUPID")
    end

    local numItems = CountMediaItems(project)
    for i = 0, numItems - 1 do
        local item = GetMediaItem(project, i)

        -- Skip if this is the item we want to exclude (the edit item)
        if item ~= exclude_item then
            -- Skip if this item has the same group ID as the edit item (and group ID is not 0)
            local item_group_id = GetMediaItemInfo_Value(item, "I_GROUPID")
            local same_group = (exclude_group_id ~= 0 and item_group_id == exclude_group_id)

            if not same_group then
                local take = GetActiveTake(item)

                if take then
                    local source = GetMediaItemTake_Source(take)
                    if source then
                        local item_filename = GetMediaSourceFileName(source, "")

                        -- Check if filenames match
                        if item_filename == filename then
                            -- Check if this item's audio range covers the required range
                            local item_startoffs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
                            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                            local item_playrate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

                            local item_audio_start = item_startoffs
                            local item_audio_end = item_startoffs + (item_len * item_playrate)

                            -- Check if the item contains the required audio range
                            if item_audio_start <= required_start and item_audio_end >= required_end then
                                return item
                            end
                        end
                    end
                end
            end
        end
    end

    return nil -- not found
end

---------------------------------------------------------------------

main()
