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
local main, count_selected_media_items, get_selected_media_item_at
local get_item_by_guid

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
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    local edit_item = get_selected_media_item_at(0)
    if not edit_item then
        MB("No items selected.", "Error", 0)
        return
    end

    local _, saved_guid = GetSetMediaItemInfo_String(edit_item, "P_EXT:src_guid", "", false)
    if saved_guid == "" then
        MB("Error: No source GUID stored for this item.", "Error", 0)
        return
    end

    local source_item = get_item_by_guid(0, saved_guid)
    if not source_item then
        MB("Error: Source item no longer exists!", "Error", 0)
        return
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
    if pos_in < src_start or pos_out > src_start + src_len then
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

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local edit_item = GetMediaItem(0, i)
        if IsMediaItemSelected(edit_item) then
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

    local numItems = reaper.CountMediaItems(project)
    for i = 0, numItems - 1 do
        local item = reaper.GetMediaItem(project, i)
        local retval, itemGUID = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
        if retval and itemGUID == guid then
            return item
        end
    end

    return nil -- not found
end

---------------------------------------------------------------------

main()
