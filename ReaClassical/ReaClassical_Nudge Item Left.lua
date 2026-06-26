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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

local main, nudge_items
local get_selected_media_items, is_folder_track, get_parent_folder
local get_folder_children, get_items_at_midpoint, get_all_items_at_midpoints

---------------------------------------------------------------------

function main()
    if xfu.is_xfade_mode() then
        say("Use XFM Nudge Left in crossfade mode")
        return
    end

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

    local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
    local ms = tonumber(stored) or 5
    local amount = -(ms / 1000)

    local moved = nudge_items(amount)
    if moved == 0 then
        say("No items selected")
    else
        say(moved .. " item group" .. (moved ~= 1 and "s" or "") .. " nudged " .. ms .. " milliseconds left")
    end
end

---------------------------------------------------------------------

function is_folder_track(track)
    if not track then return false end
    return GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
end

---------------------------------------------------------------------

function get_parent_folder(track)
    if not track then return nil end
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = track_idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
    end
    return nil
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

function get_selected_media_items()
    local result = {}
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then result[#result + 1] = item end
    end
    return result
end

---------------------------------------------------------------------

-- Resolves the folder track range (0-based indices) that contains ref_item.
local function get_folder_range_for_item(ref_item)
    local track = GetMediaItem_Track(ref_item)
    local track_num = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local start_search = track_num
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
    local folder_start, folder_end = nil, nil
    for t = start_search, num_tracks - 1 do
        local tt = GetTrack(0, t)
        if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    return folder_start, folder_end
end

-- Returns all items in the same folder as ref_item whose span contains
-- ref_item's midpoint. Scoped to the folder -- never crosses into other folders.
function get_items_at_midpoint(ref_item)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    local folder_start, folder_end = get_folder_range_for_item(ref_item)
    if not folder_start then return result end
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

-- For every item in base_items, collect it and all folder-scoped midpoint peers.
-- De-duplicated.
function get_all_items_at_midpoints(base_items)
    local seen = {}
    local result = {}
    for _, ref_item in ipairs(base_items) do
        if not seen[ref_item] then
            local peers = get_items_at_midpoint(ref_item)
            for _, peer in ipairs(peers) do
                if not seen[peer] then
                    seen[peer] = true
                    result[#result + 1] = peer
                end
            end
        end
    end
    return result
end

---------------------------------------------------------------------

-- Shifts the selected items (and their folder-scoped midpoint peers) by
-- `amount` seconds, then ripples every later item in the same folder(s) by
-- the same amount so everything downstream stays in sync -- the same
-- midpoint-peer/ripple approach used by ReaClassical_Set Item Playback Rate.lua.
-- Returns the number of item groups nudged (a group = a selected item plus
-- its synced peers across tracks in the same folder, counted once).
function nudge_items(amount)
    Undo_BeginBlock()
    PreventUIRefresh(1)

    local sel_items = get_selected_media_items()
    if #sel_items == 0 then
        PreventUIRefresh(-1)
        Undo_EndBlock("Nudge items (no-op)", -1)
        return 0
    end

    -- Count distinct item groups without double-counting child-track peers.
    local seen_for_count = {}
    local group_count = 0
    for _, ref_item in ipairs(sel_items) do
        if not seen_for_count[ref_item] then
            for _, peer in ipairs(get_items_at_midpoint(ref_item)) do
                seen_for_count[peer] = true
            end
            group_count = group_count + 1
        end
    end

    local all_target_items = get_all_items_at_midpoints(sel_items)
    local target_set = {}
    for _, ti in ipairs(all_target_items) do target_set[ti] = true end

    -- Group the directly-selected items by folder, tracking each folder's
    -- earliest original position -- the ripple boundary for that folder.
    local folder_bounds = {}
    local folder_order = {}
    for _, item in ipairs(sel_items) do
        local track = GetMediaItemTrack(item)
        local folder_track = is_folder_track(track) and track or get_parent_folder(track)
        if folder_track then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if not folder_bounds[folder_track] then
                folder_order[#folder_order + 1] = folder_track
                folder_bounds[folder_track] = pos
            elseif pos < folder_bounds[folder_track] then
                folder_bounds[folder_track] = pos
            end
        end
    end

    -- Move the directly-nudged items.
    for _, item in ipairs(all_target_items) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, pos + amount))
    end

    -- Ripple every later item in each affected folder by the same amount.
    for _, folder_track in ipairs(folder_order) do
        local ref_pos = folder_bounds[folder_track]
        local folder_track_set = { [folder_track] = true }
        for _, child in ipairs(get_folder_children(folder_track)) do
            folder_track_set[child] = true
        end

        local total_items = CountMediaItems(0)
        local to_move_set = {}
        local to_move = {}

        for i = 0, total_items - 1 do
            local it = GetMediaItem(0, i)
            if not target_set[it] and folder_track_set[GetMediaItemTrack(it)] then
                local ipos = GetMediaItemInfo_Value(it, "D_POSITION")
                if ipos > ref_pos + 0.0001 then
                    to_move_set[it] = true
                    to_move[#to_move + 1] = it
                end
            end
        end

        local extra = {}
        for _, it in ipairs(to_move) do
            local peers = get_items_at_midpoint(it)
            for _, peer in ipairs(peers) do
                if not target_set[peer] and not to_move_set[peer]
                    and folder_track_set[GetMediaItemTrack(peer)] then
                    local ipos = GetMediaItemInfo_Value(peer, "D_POSITION")
                    if ipos > ref_pos + 0.0001 then
                        to_move_set[peer] = true
                        extra[#extra + 1] = peer
                    end
                end
            end
        end
        for _, it in ipairs(extra) do to_move[#to_move + 1] = it end

        for _, it in ipairs(to_move) do
            local ipos = GetMediaItemInfo_Value(it, "D_POSITION")
            SetMediaItemInfo_Value(it, "D_POSITION", math.max(0, ipos + amount))
        end
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock("Nudge items left", -1)
    return group_count
end

---------------------------------------------------------------------

main()
