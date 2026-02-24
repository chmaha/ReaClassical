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

local main, folder_check, get_track_number
local get_path, get_color_table
local source_pos_to_project_pos, project_pos_to_source_pos
local find_saud_take_marker_at_cursor, remove_take_marker_by_chunk
local find_source_marker, get_item_at_position, set_take_marker_with_length
local convert_existing_pair_to_take_marker

local to_takemarkers = false

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

if to_takemarkers then return end

local _, opened_string = GetProjExtState(0, "ReaClassical", "toolbaropened")

if opened_string ~= "y" then
    local editing_toolbar = reaper.NamedCommandLookup("_RSdcbfd5e17e15e31f892e3fefdb1969b81d22b6df")
    Main_OnCommand(editing_toolbar, 0)
    SetProjExtState(0, "ReaClassical", "toolbaropened", "y")
end

function main()
    PreventUIRefresh(1)
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

    local selected_item = GetSelectedMediaItem(0, 0)
    if not selected_item then
        MB("Please select an item containing take markers.", "ReaClassical Error", 0)
        return
    end

    local take = GetActiveTake(selected_item)
    if not take then
        MB("No active take found on selected item.", "ReaClassical Error", 0)
        return
    end

    local cur_pos = GetCursorPosition()

    -- Find S-AUD take marker (with length) surrounding the edit cursor
    local marker_info = find_saud_take_marker_at_cursor(selected_item, take, cur_pos)

    if not marker_info then
        MB("Edit cursor is not inside an S-AUD take marker region on the selected item.",
            "ReaClassical Error", 0)
        return
    end

    -- Get the track number for the marker labels
    local item_track = GetMediaItem_Track(selected_item)
    local track_number = math.floor(get_track_number(item_track))

    -- Get marker color
    local colors = get_color_table()
    local marker_color
    if workflow == "Horizontal" then
        marker_color = colors.source_marker
    else
        marker_color = item_track and GetTrackColor(item_track) or colors.source_marker
    end

    -- Before placing new project markers, convert any existing pair to a take marker
    local proj = EnumProjects(-1)
    convert_existing_pair_to_take_marker(proj)

    -- Add real project markers
    AddProjectMarker2(0, false, marker_info.in_proj_pos, 0,
        track_number .. ":SOURCE-IN", 998, marker_color)
    AddProjectMarker2(0, false, marker_info.out_proj_pos, 0,
        track_number .. ":SOURCE-OUT", 999, marker_color)

    -- Remove the S-AUD take marker via chunk manipulation
    remove_take_marker_by_chunk(selected_item, marker_info.src_start, "S-AUD")

    PreventUIRefresh(-1)
end

---------------------------------------------------------------------

function convert_existing_pair_to_take_marker(proj)
    local black_color = ColorToNative(0, 0, 0) | 0x1000000

    local in_pos, in_track_num = find_source_marker(proj, 998, "SOURCE-IN")
    local out_pos, out_track_num = find_source_marker(proj, 999, "SOURCE-OUT")

    -- No pair or mismatched track numbers: just delete both
    if not in_pos or not out_pos or not in_track_num or not out_track_num
        or in_track_num ~= out_track_num then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    -- Guard: backwards pair
    if in_pos >= out_pos then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    -- Guard: must be in the same item
    local item_in, take_in = get_item_at_position(in_pos, in_track_num)
    local item_out, _ = get_item_at_position(out_pos, in_track_num)

    if not item_in or not item_out or item_in ~= item_out then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    -- Guard: target item already has an S-AUD take marker
    local _, existing_chunk = GetItemStateChunk(item_in, "", false)
    if existing_chunk and existing_chunk:find("\n%s*TKM%s+%-?[%d%.e%+%-]+%s+S%-AUD%s+") then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break end
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
            i = i + 1
        end
        return
    end

    -- Convert pair to take marker
    if take_in then
        local src_in = project_pos_to_source_pos(take_in, item_in, in_pos)
        local src_out = project_pos_to_source_pos(take_in, item_in, out_pos)
        if src_in and src_out then
            set_take_marker_with_length(item_in, src_in, src_out, "S-AUD", black_color)
        end
    end

    -- Delete both project markers across all tabs
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then break end
        DeleteProjectMarker(project, 998, false)
        DeleteProjectMarker(project, 999, false)
        i = i + 1
    end
end

---------------------------------------------------------------------

function find_saud_take_marker_at_cursor(item, take, cursor_pos)
    -- Parse item chunk to find TKM lines with a length (time selection style)
    -- Chunk format: TKM srcpos name color length
    local _, chunk = GetItemStateChunk(item, "", false)
    if not chunk or chunk == "" then return nil end

    for src_start_str, name, _, length_str in
        chunk:gmatch('TKM%s+(%-?[%d%.e%+%-]+)%s+(%S+)%s+(%S+)%s+(%-?[%d%.e%+%-]+)')
    do
        if name == "S-AUD" then
            local src_start = tonumber(src_start_str)
            local length = tonumber(length_str)
            if src_start and length and length > 0 then
                local src_end = src_start + length
                local proj_start = source_pos_to_project_pos(take, item, src_start)
                local proj_end = source_pos_to_project_pos(take, item, src_end)
                if proj_start and proj_end and
                    cursor_pos >= proj_start and cursor_pos <= proj_end then
                    return {
                        in_proj_pos = proj_start,
                        out_proj_pos = proj_end,
                        src_start = src_start,
                        src_end = src_end
                    }
                end
            end
        end
    end

    return nil
end

---------------------------------------------------------------------

function remove_take_marker_by_chunk(item, src_start, name)
    local _, chunk = GetItemStateChunk(item, "", false)
    if not chunk or chunk == "" then return end

    -- Match TKM lines: TKM srcpos name color [length]
    local new_lines = {}
    local removed = false
    for line in chunk:gmatch("[^\n]+") do
        if not removed then
            local tm_src, tm_name = line:match(
                '%s*TKM%s+(%-?[%d%.e%+%-]+)%s+(%S+)'
            )
            if tm_name == name and tm_src then
                local tm_pos = tonumber(tm_src)
                if tm_pos and math.abs(tm_pos - src_start) < 0.0001 then
                    removed = true
                    goto continue
                end
            end
        end
        new_lines[#new_lines + 1] = line
        ::continue::
    end

    if removed then
        SetItemStateChunk(item, table.concat(new_lines, "\n"), false)
    end
end

---------------------------------------------------------------------

function set_take_marker_with_length(item, src_start, src_end, name, color)
    -- Use chunk manipulation since SetTakeMarker API lacks length parameter
    -- Chunk format: TKM srcpos name color length
    local _, chunk = GetItemStateChunk(item, "", false)
    if not chunk or chunk == "" then return end

    local length = src_end - src_start
    local marker_line = string.format(
        '    TKM %.14g %s %d %.14g',
        src_start, name, color, length
    )

    -- Insert before the closing ">" of the ITEM chunk
    local insert_pos = chunk:find("\n>%s*$")
    if insert_pos then
        chunk = chunk:sub(1, insert_pos - 1) .. "\n" .. marker_line .. chunk:sub(insert_pos)
    else
        chunk = chunk:gsub("(>)%s*$", marker_line .. "\n>")
    end

    SetItemStateChunk(item, chunk, false)
end

---------------------------------------------------------------------

function find_source_marker(proj, marker_id, marker_type)
    local _, num_markers, num_regions = CountProjectMarkers(proj)

    for i = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, _, raw_label, markrgnindexnumber = EnumProjectMarkers2(proj, i)
        if not isrgn and markrgnindexnumber == marker_id then
            local number, label = raw_label:match("(%d+):(.+)")
            if label and label == marker_type then
                return pos, tonumber(number)
            end
        end
    end

    return nil, nil
end

---------------------------------------------------------------------

function get_item_at_position(proj_pos, track_number)
    local tr = GetTrack(0, track_number - 1)
    if not tr then return nil, nil end

    local tracks_to_check = { tr }
    if GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
        local depth = 1
        local idx = track_number
        while depth > 0 and idx < CountTracks(0) do
            local child = GetTrack(0, idx)
            if child then
                tracks_to_check[#tracks_to_check + 1] = child
                depth = depth + GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH")
            end
            idx = idx + 1
        end
    end

    for _, check_tr in ipairs(tracks_to_check) do
        local num_items = CountTrackMediaItems(check_tr)
        for j = 0, num_items - 1 do
            local item = GetTrackMediaItem(check_tr, j)
            if item then
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                if proj_pos >= item_pos and proj_pos <= item_pos + item_len then
                    local take = GetActiveTake(item)
                    if take then return item, take end
                end
            end
        end
    end

    return nil, nil
end

---------------------------------------------------------------------

function source_pos_to_project_pos(take, item, src_pos)
    if not take or not item then return nil end
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local take_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local take_rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if take_rate == 0 then return nil end
    return item_pos + (src_pos - take_offset) / take_rate
end

---------------------------------------------------------------------

function project_pos_to_source_pos(take, item, proj_pos)
    if not take or not item then return nil end
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local take_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local take_rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    return take_offset + (proj_pos - item_pos) * take_rate
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

function get_track_number(track)
    if not track then track = GetSelectedTrack(0, 0) end
    if folder_check() == 0 or track == nil then
        return 1
    elseif GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        return GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
    else
        local folder = GetParentTrack(track)
        return GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER")
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