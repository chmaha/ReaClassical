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
local folder_check, get_track_prefix
local find_item_across_projects_by_guid, find_item_across_projects_by_source
local get_workflow_for_project

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()

    local current_project = EnumProjects(-1, "") -- current tab

    local _, workflow = GetProjExtState(current_project, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier .. "+N.", "Error", 0)
        return
    end

    local _, input = GetProjExtState(current_project, "ReaClassical", "Preferences")
    local auto_color_pref = 0
    if input ~= "" then
        local t = {}
        for entry in input:gmatch('([^,]+)') do t[#t + 1] = entry end
        if t[5] then auto_color_pref = tonumber(t[5]) or 0 end
    end

    local edit_item = get_selected_media_item_at(0)
    if not edit_item then
        MB("No items selected.", "Error", 0)
        return
    end

    local _, saved_guid = GetSetMediaItemInfo_String(edit_item, "P_EXT:src_guid", "", false)

    local source_item, source_project

    if saved_guid ~= "" then
        source_item, source_project = find_item_across_projects_by_guid(saved_guid)
    end

    local found_via_fallback = false

    if not source_item then
        local take = GetActiveTake(edit_item)
        if not take then
            MB("No active take.", "Error", 0)
            return
        end

        local src = GetMediaItemTake_Source(take)
        local filename = GetMediaSourceFileName(src, "")

        local startoffs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
        local len = GetMediaItemInfo_Value(edit_item, "D_LENGTH")
        local rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

        local req_start = startoffs
        local req_end = startoffs + (len * rate)

        source_item, source_project =
            find_item_across_projects_by_source(filename, req_start, req_end, edit_item)

        if not source_item then
            MB("Source not found in any open project.", "Error", 0)
            return
        end

        found_via_fallback = true
    end

    if source_project ~= current_project then
        SelectProjectInstance(source_project)
    end

    if found_via_fallback then
        local source_take = GetActiveTake(source_item)
        local source_color = GetDisplayedMediaItemColor2(source_item, source_take)

        local _, source_guid = GetSetMediaItemInfo_String(source_item, "GUID", "", false)

        if auto_color_pref == 0 then
            SetMediaItemInfo_Value(edit_item, "I_CUSTOMCOLOR", source_color)
        end

        GetSetMediaItemInfo_String(edit_item, "P_EXT:src_guid", source_guid, true)
    end

    local src_start = GetMediaItemInfo_Value(source_item, "D_POSITION")
    local src_len = GetMediaItemInfo_Value(source_item, "D_LENGTH")
    local src_startoffs = GetMediaItemTakeInfo_Value(GetActiveTake(source_item), "D_STARTOFFS")

    local take = GetActiveTake(edit_item)
    local edit_startoffs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local edit_len = GetMediaItemInfo_Value(edit_item, "D_LENGTH")
    local playrate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

    local offset_diff = edit_startoffs - src_startoffs
    local pos_in = src_start + offset_diff
    local pos_out = pos_in + (edit_len * playrate)

    local i = 0
    while true do
        local proj = EnumProjects(i)
        if not proj then break end
        DeleteProjectMarker(proj, 998, false)
        DeleteProjectMarker(proj, 999, false)
        i = i + 1
    end

    local source_track = GetMediaItemTrack(source_item)
    local color = GetTrackColor(source_track) or 0
    local prefix = get_track_prefix(source_track)

    local source_workflow = get_workflow_for_project(source_project)

    local in_label, out_label
    if source_workflow == "Horizontal" then
        in_label = "SOURCE-IN"
        out_label = "SOURCE-OUT"
    else
        in_label = prefix .. ":SOURCE-IN"
        out_label = prefix .. ":SOURCE-OUT"
    end

    AddProjectMarker2(source_project, false, pos_in, 0, in_label, 998, color)
    AddProjectMarker2(source_project, false, pos_out, 0, out_label, 999, color)

    SetOnlyTrackSelected(source_track)

    local cmd = NamedCommandLookup("_RS7316313701a4b3bdc2e4c32420a84204827b0ae9")
    if cmd then Main_OnCommand(cmd, 0) end

    Undo_EndBlock("Find Source Material (multi-tab)", 0)
    PreventUIRefresh(-1)
    UpdateArrange()
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

function folder_check()
    local folders = 0
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        end
    end
    return folders
end

---------------------------------------------------------------------

function get_track_prefix(track)
    if not track then track = GetSelectedTrack(0, 0) end
    if folder_check() == 0 or track == nil then
        return "1"
    end
    local folder
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        folder = track
    else
        folder = GetParentTrack(track)
    end
    if folder then
        local _, name = GetTrackName(folder)
        local prefix = name:match("^(.-):")
        if prefix then return prefix end
    end
    return tostring(math.floor(GetMediaTrackInfo_Value(folder or track, "IP_TRACKNUMBER")))
end

---------------------------------------------------------------------

function find_item_across_projects_by_guid(guid)
    if not guid or guid == "" then return nil, nil end

    local i = 0
    while true do
        local proj = EnumProjects(i)
        if not proj then break end

        local item = get_item_by_guid(proj, guid)
        if item then
            return item, proj
        end

        i = i + 1
    end

    return nil, nil
end

---------------------------------------------------------------------

function find_item_across_projects_by_source(filename, required_start, required_end, exclude_item)
    local i = 0
    while true do
        local proj = EnumProjects(i)
        if not proj then break end

        local item = find_item_by_source_file(proj, filename, required_start, required_end, exclude_item)
        if item then
            return item, proj
        end

        i = i + 1
    end

    return nil, nil
end

---------------------------------------------------------------------

function get_workflow_for_project(proj)
    local _, wf = GetProjExtState(proj, "ReaClassical", "Workflow")
    return wf or ""
end

main()
