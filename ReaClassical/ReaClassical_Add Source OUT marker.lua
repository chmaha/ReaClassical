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

local main, folder_check, get_track_number, other_source_marker_check
local get_path, get_color_table
local convert_pair_to_take_marker, find_source_marker
local project_pos_to_source_pos, get_item_at_position
local set_take_marker_with_length

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

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
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local sdmousehover = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[9] then sdmousehover = tonumber(table[9]) or 0 end
    end

    local to_takemarkers = false -- placeholder: add proper logic later

    local selected_track = GetSelectedTrack(0, 0)

    local cur_pos, track
    if sdmousehover == 1 then
        cur_pos = BR_PositionAtMouseCursor(false)
        local screen_x, screen_y = GetMousePosition()
        track = GetTrackFromPoint(screen_x, screen_y)
    else
        cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    end

    if cur_pos ~= -1 then
        local track_number = math.floor(get_track_number(track))

        if not to_takemarkers then
            -- Only convert if a matching pair exists; otherwise just delete old marker
            convert_pair_to_take_marker(999, "SOURCE-OUT", cur_pos, track_number)
        else
            local i = 0
            while true do
                local project, _ = EnumProjects(i)
                if project == nil then break
                else DeleteProjectMarker(project, 999, false) end
                i = i + 1
            end
        end

        local other_source_marker = other_source_marker_check()

        local color_track = track or selected_track
        local colors = get_color_table()

        local marker_color
        if workflow == "Horizontal" then
            marker_color = colors.source_marker
        else
            marker_color = color_track and GetTrackColor(color_track) or colors.source_marker
        end

        AddProjectMarker2(0, false, cur_pos, 0, track_number .. ":SOURCE-OUT", 999, marker_color)

        if other_source_marker and other_source_marker ~= track_number then
            MB("Warning: Source OUT marker group does not match Source IN!", "Add Source Marker OUT", 0)
        end
    end
    PreventUIRefresh(-1)
end

---------------------------------------------------------------------

function convert_pair_to_take_marker(marker_id, marker_type, new_pos, new_track_number)
    local black_color = ColorToNative(0, 0, 0) | 0x1000000

    local proj = EnumProjects(-1)
    if not proj then return end

    local _, num_markers, num_regions = CountProjectMarkers(proj)
    local marker_pos = nil
    local marker_track_num = nil

    for i = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, _, raw_label, markrgnindexnumber = EnumProjectMarkers2(proj, i)
        if not isrgn and markrgnindexnumber == marker_id then
            local number, label = raw_label:match("(%d+):(.+)")
            if label and label == marker_type then
                marker_pos = pos
                marker_track_num = tonumber(number)
            end
            break
        end
    end

    if not marker_pos then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break
            else DeleteProjectMarker(project, marker_id, false) end
            i = i + 1
        end
        return
    end

    -- Check for matching partner marker
    local other_id = (marker_type == "SOURCE-OUT") and 998 or 999
    local other_type = (marker_type == "SOURCE-OUT") and "SOURCE-IN" or "SOURCE-OUT"
    local other_pos, other_track_num = find_source_marker(proj, other_id, other_type)

    local is_pair = other_pos and other_track_num and
        marker_track_num and other_track_num == marker_track_num

    if not is_pair then
        -- No pair: just delete old marker, do NOT convert singles
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break
            else DeleteProjectMarker(project, marker_id, false) end
            i = i + 1
        end
        return
    end

    -- Determine IN and OUT positions
    local in_pos, out_pos
    if marker_type == "SOURCE-IN" then
        in_pos = marker_pos
        out_pos = other_pos
    else
        in_pos = other_pos
        out_pos = marker_pos
    end

    -- Guard: do not convert if pair is backwards (OUT before IN)
    if in_pos >= out_pos then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break
            else DeleteProjectMarker(project, marker_id, false) end
            i = i + 1
        end
        return
    end

    -- Find the item the existing pair lives in
    local item_in, take_in = get_item_at_position(in_pos, marker_track_num)
    local item_out, _ = get_item_at_position(out_pos, marker_track_num)

    -- Guard: do not convert if IN and OUT span multiple items
    if not item_in or not item_out or item_in ~= item_out then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break
            else DeleteProjectMarker(project, marker_id, false) end
            i = i + 1
        end
        return
    end

    -- Guard: if the new marker is in the same item as the existing pair,
    -- the user is just repositioning — skip conversion, just delete old marker
    local item_new, _ = get_item_at_position(new_pos, new_track_number)
    if item_new and item_new == item_in then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break
            else DeleteProjectMarker(project, marker_id, false) end
            i = i + 1
        end
        return
    end

    -- Guard: do not convert if the target item already has an S-AUD take marker
    local _, existing_chunk = GetItemStateChunk(item_in, "", false)
    if existing_chunk and existing_chunk:find("\n%s*TKM%s+%-?[%d%.e%+%-]+%s+S%-AUD%s+") then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then break
            else DeleteProjectMarker(project, marker_id, false) end
            i = i + 1
        end
        return
    end

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

function other_source_marker_check()
    local proj = EnumProjects(-1)
    if not proj then return nil end

    local _, num_markers, num_regions = CountProjectMarkers(proj)

    for i = 0, num_markers + num_regions - 1 do
        local _, _, _, _, raw_label, _ = EnumProjectMarkers2(proj, i)
        local number, label = raw_label:match("(%d+):(.+)")

        if label and (label == "SOURCE-IN" or label == "SOURCE-OUT") then
            return tonumber(number)
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