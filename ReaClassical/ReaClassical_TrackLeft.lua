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

local main, get_selected_cd_track_item, is_cd_track_start, is_folder_track
local get_cd_track_items, get_prev_cd_track_item, get_next_cd_track_item
local move_items, get_folder_children, collect_automation, restore_automation
local is_in_child_track, get_parent_folder

---------------------------------------------------------------------

function main()
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

    local selected_item, folder_track = get_selected_cd_track_item()
    if not selected_item then
        MB('Please select an item that starts a CD track', "Select CD track start", 0)
        return
    end

    local prev_item = get_prev_cd_track_item(selected_item, folder_track)
    if not prev_item then
        MB('The selected track is already in first position', "Select CD track start", 0)
        return
    end

    local next_item = get_next_cd_track_item(selected_item, folder_track)

    local selected_items = get_cd_track_items(selected_item, folder_track)
    local prev_items = get_cd_track_items(prev_item, folder_track)

    local selected_start = GetMediaItemInfo_Value(selected_item, "D_POSITION")
    local prev_start = GetMediaItemInfo_Value(prev_item, "D_POSITION")

    -- How far Selected moves left: distance from Selected start to Prev start
    local prev_span = selected_start - prev_start

    -- How far Prev moves right: distance from Selected start to next CD track start
    -- (or end of Selected's last item + 4s postgap if it is the last track)
    local selected_span
    if next_item then
        local next_start = GetMediaItemInfo_Value(next_item, "D_POSITION")
        selected_span = next_start - selected_start
    else
        local last_end = 0
        for _, it in ipairs(selected_items) do
            local p = GetMediaItemInfo_Value(it, "D_POSITION")
            local l = GetMediaItemInfo_Value(it, "D_LENGTH")
            last_end = math.max(last_end, p + l)
        end
        selected_span = last_end - selected_start + 4
    end

    PreventUIRefresh(1)

    -- Snapshot automation for both CD tracks relative to their start positions,
    -- then clear it — before any items are moved
    local selected_automation = collect_automation(selected_items, selected_start, folder_track)
    local prev_automation = collect_automation(prev_items, prev_start, folder_track)

    -- Move items
    move_items(selected_items, folder_track, -prev_span)
    move_items(prev_items, folder_track, selected_span)

    -- Restore automation at new positions
    -- Selected moved left by prev_span, so new start = selected_start - prev_span = prev_start
    restore_automation(selected_automation, prev_start, folder_track)
    -- Prev moved right by selected_span, so new start = prev_start + selected_span
    restore_automation(prev_automation, prev_start + selected_span, folder_track)

    Main_OnCommand(40769, 0) -- unselect all
    SetOnlyTrackSelected(folder_track)
    SetMediaItemSelected(selected_item, true)
    PreventUIRefresh(-1)
    Undo_EndBlock("Move Track Left", -1)
end

---------------------------------------------------------------------

function is_cd_track_start(take_name)
    return take_name ~= "" and not take_name:match("^@")
end

---------------------------------------------------------------------

function is_folder_track(track)
    if not track then return false end
    return GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
end

---------------------------------------------------------------------

function is_in_child_track(item)
    if not item then return false end
    local track = GetMediaItemTrack(item)
    if not track then return false end
    if is_folder_track(track) then return false end
    return get_parent_folder(track) ~= nil
end

---------------------------------------------------------------------

function get_parent_folder(track)
    if not track then return nil end
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = track_idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
            return t
        end
    end
    return nil
end

---------------------------------------------------------------------

function get_selected_cd_track_item()
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            local take = GetActiveTake(item)
            if not take then return nil, nil end
            local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if not is_cd_track_start(take_name) then return nil, nil end
            local track = GetMediaItemTrack(item)
            if not is_folder_track(track) then return nil, nil end
            if is_in_child_track(item) then return nil, nil end
            return item, track
        end
    end
    return nil, nil
end

---------------------------------------------------------------------

function get_cd_track_items(start_item, folder_track)
    local items = {}
    local start_number = GetMediaItemInfo_Value(start_item, "IP_ITEMNUMBER")
    local num_items = GetTrackNumMediaItems(folder_track)
    table.insert(items, start_item)
    for i = start_number + 1, num_items - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if is_cd_track_start(take_name) then
            break
        end
        table.insert(items, item)
    end
    return items
end

---------------------------------------------------------------------

function get_prev_cd_track_item(selected_item, folder_track)
    local item_number = GetMediaItemInfo_Value(selected_item, "IP_ITEMNUMBER")
    for i = item_number - 1, 0, -1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if is_cd_track_start(take_name) then
            return item
        end
    end
    return nil
end

---------------------------------------------------------------------

function get_next_cd_track_item(selected_item, folder_track)
    local item_number = GetMediaItemInfo_Value(selected_item, "IP_ITEMNUMBER")
    local num_items = GetTrackNumMediaItems(folder_track)
    local i = item_number + 1
    while i < num_items do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if is_cd_track_start(take_name) then
            return item
        end
        i = i + 1
    end
    return nil
end

---------------------------------------------------------------------

function collect_automation(folder_items, track_start, folder_track)
    -- Determine the time range covered by this CD track's folder items
    local range_start = math.huge
    local range_end = 0
    for _, item in ipairs(folder_items) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        range_start = math.min(range_start, pos)
        range_end = math.max(range_end, pos + len)
    end

    -- Collect all tracks in the folder
    local tracks_to_check = { folder_track }
    local children = get_folder_children(folder_track)
    for _, child in ipairs(children) do
        table.insert(tracks_to_check, child)
    end

    -- For each track, collect envelope points and automation items
    -- within the time range, storing positions relative to track_start
    local snapshot = {}
    for _, track in ipairs(tracks_to_check) do
        local track_data = { track = track, envs = {} }
        local num_envs = CountTrackEnvelopes(track)
        for e = 0, num_envs - 1 do
            local env = GetTrackEnvelope(track, e)
            local env_data = { env = env, points = {}, ai = {} }

            -- Collect envelope points within range
            local num_points = CountEnvelopePoints(env)
            for p = 0, num_points - 1 do
                local _, time, value, shape, tension, sel = GetEnvelopePoint(env, p)
                if time >= range_start and time <= range_end then
                    table.insert(env_data.points, {
                        rel = time - track_start,
                        value = value, shape = shape,
                        tension = tension, sel = sel
                    })
                    -- Delete the point so we can reinsert at correct position later
                    DeleteEnvelopePointRange(env, time - 0.00005, time + 0.00005)
                    -- Recount since we just deleted
                    num_points = CountEnvelopePoints(env)
                    p = p - 1
                end
            end
            Envelope_SortPoints(env)

            -- Collect automation items within range
            local num_ai = CountAutomationItems(env)
            for ai = 0, num_ai - 1 do
                local ai_pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
                local ai_len = GetSetAutomationItemInfo(env, ai, "D_LENGTH", 0, false)
                if ai_pos < range_end and (ai_pos + ai_len) > range_start then
                    table.insert(env_data.ai, {
                        rel = ai_pos - track_start,
                        len = ai_len
                    })
                end
            end

            table.insert(track_data.envs, env_data)
        end
        table.insert(snapshot, track_data)
    end
    return snapshot
end

---------------------------------------------------------------------

function restore_automation(snapshot, new_track_start, folder_track)
    for _, track_data in ipairs(snapshot) do
        for _, env_data in ipairs(track_data.envs) do
            local env = env_data.env
            -- Reinsert envelope points at new absolute positions
            for _, pt in ipairs(env_data.points) do
                InsertEnvelopePoint(env, new_track_start + pt.rel, pt.value,
                    pt.shape, pt.tension, pt.sel, true)
            end
            Envelope_SortPoints(env)
            -- Reposition automation items
            local num_ai = CountAutomationItems(env)
            for ai = 0, num_ai - 1 do
                local ai_pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
                local ai_len = GetSetAutomationItemInfo(env, ai, "D_LENGTH", 0, false)
                -- Match by length and approximate original position
                for _, saved_ai in ipairs(env_data.ai) do
                    if math.abs(ai_len - saved_ai.len) < 0.0001 then
                        GetSetAutomationItemInfo(env, ai, "D_POSITION",
                            new_track_start + saved_ai.rel, true)
                        break
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------

function move_items(folder_items, folder_track, delta)
    -- Collect group IDs from all folder track items
    local group_ids = {}
    for _, item in ipairs(folder_items) do
        local gid = GetMediaItemInfo_Value(item, "I_GROUPID")
        if gid and gid > 0 then
            group_ids[gid] = true
        end
    end

    -- Build full list: start with folder items, then add any project item
    -- sharing a group ID with them
    local items_to_move = {}
    local seen = {}
    for _, item in ipairs(folder_items) do
        items_to_move[#items_to_move + 1] = item
        seen[item] = true
    end

    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if not seen[item] then
            local gid = GetMediaItemInfo_Value(item, "I_GROUPID")
            if gid and gid > 0 and group_ids[gid] then
                items_to_move[#items_to_move + 1] = item
                seen[item] = true
            end
        end
    end

    -- Move all items
    for _, item in ipairs(items_to_move) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        SetMediaItemInfo_Value(item, "D_POSITION", pos + delta)
    end
end

---------------------------------------------------------------------

function get_folder_children(parent_track)
    local children = {}
    if not parent_track then return children end
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end
        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        table.insert(children, tr)
        depth = depth + folder_depth
        if depth <= 0 then break end
        idx = idx + 1
    end
    return children
end

---------------------------------------------------------------------

main()