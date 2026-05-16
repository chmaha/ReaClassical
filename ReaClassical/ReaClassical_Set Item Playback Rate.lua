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

local main
local get_selected_media_items, count_selected_media_items
local apply_rate_change, apply_pitch_change
local get_folder_children, get_all_items_at_midpoints
local get_items_at_midpoint
local is_folder_track, get_parent_folder

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
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

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('ReaClassical Playrate and Pitch Adjuster')
local window_open = true

local DEFAULT_W = 320
local DEFAULT_H = 420

local rate_str = "5.0"
local is_relative = true
local pitch_str = "0.0"

local message_text = ""
local message_timer = 0
local message_duration = 3.0

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

function count_selected_media_items()
    local selected_count = 0
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then selected_count = selected_count + 1 end
    end
    return selected_count
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
-- ref_item's midpoint. Scoped to the folder — never crosses into other folders.
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

function reset_to_normal()
    apply_rate_change(0, false)
end

---------------------------------------------------------------------

function apply_rate_change(new_rate_val, relative_mode)
    Undo_BeginBlock()
    PreventUIRefresh(1)

    local sel_items = get_selected_media_items()
    if #sel_items == 0 then
        PreventUIRefresh(-1)
        message_text = "No items selected."
        message_timer = ImGui.GetTime(ctx)
        Undo_EndBlock("RC Time Stretch (no-op)", -1)
        return
    end

    -- Only one folder track item may be selected
    local folder_item = nil
    local folder_item_count = 0
    for _, item in ipairs(sel_items) do
        local track = GetMediaItemTrack(item)
        if is_folder_track(track) then
            folder_item = item
            folder_item_count = folder_item_count + 1
        end
    end
    if folder_item_count > 1 then
        PreventUIRefresh(-1)
        message_text = "Please select only one item at a time."
        message_timer = ImGui.GetTime(ctx)
        Undo_EndBlock("RC Time Stretch (no-op)", -1)
        return
    end
    if not folder_item then folder_item = sel_items[1] end

    -- Expand selected items to all folder-scoped midpoint peers
    local all_target_items = get_all_items_at_midpoints(sel_items)

    local target_set = {}
    for _, ti in ipairs(all_target_items) do target_set[ti] = true end

    -- Compute rate/length from the folder item only
    local folder_take = GetActiveTake(folder_item)
    if not folder_take then
        PreventUIRefresh(-1)
        message_text = "Selected item has no take."
        message_timer = ImGui.GetTime(ctx)
        Undo_EndBlock("RC Time Stretch (no-op)", -1)
        return
    end

    local folder_pos = GetMediaItemInfo_Value(folder_item, "D_POSITION")
    local old_len    = GetMediaItemInfo_Value(folder_item, "D_LENGTH")
    local old_rate   = GetMediaItemTakeInfo_Value(folder_take, "D_PLAYRATE")

    local new_rate
    if relative_mode then
        new_rate = old_rate * (1.0 + new_rate_val / 100.0)
    else
        new_rate = 1.0 + new_rate_val / 100.0
    end
    new_rate = math.max(0.01, math.min(100.0, new_rate))
    local new_len = old_len * (old_rate / new_rate)
    new_len = math.max(0.001, new_len)
    local delta = new_len - old_len

    -- Apply rate + length to all target items
    for _, item in ipairs(all_target_items) do
        local take = GetActiveTake(item)
        if take then
            SetMediaItemTakeInfo_Value(take, "B_PPITCH", 1)
            SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", new_rate)
            SetMediaItemInfo_Value(item, "D_LENGTH", new_len)
        end
    end

    -- Build folder track set — only items on these tracks should be rippled
    local folder_track = GetMediaItemTrack(folder_item)
    local folder_track_set = { [folder_track] = true }
    for _, child in ipairs(get_folder_children(folder_track)) do
        folder_track_set[child] = true
    end

    -- Ripple items within the same folder that start after folder_pos
    local total_delta = delta
    if math.abs(delta) > 0.0001 then
        local total_items = CountMediaItems(0)
        local to_move_set = {}
        local to_move = {}

        -- First pass: items in this folder after folder_pos
        for i = 0, total_items - 1 do
            local it = GetMediaItem(0, i)
            if not target_set[it] and folder_track_set[GetMediaItemTrack(it)] then
                local ipos = GetMediaItemInfo_Value(it, "D_POSITION")
                if ipos > folder_pos + 0.0001 and not to_move_set[it] then
                    to_move_set[it] = true
                    to_move[#to_move + 1] = it
                end
            end
        end

        -- Second pass: folder-scoped midpoint peers of items to move
        local extra = {}
        for _, it in ipairs(to_move) do
            local peers = get_items_at_midpoint(it)
            for _, peer in ipairs(peers) do
                if not target_set[peer] and not to_move_set[peer]
                        and folder_track_set[GetMediaItemTrack(peer)] then
                    local ipos = GetMediaItemInfo_Value(peer, "D_POSITION")
                    if ipos > folder_pos + 0.0001 then
                        to_move_set[peer] = true
                        extra[#extra + 1] = peer
                    end
                end
            end
        end
        for _, it in ipairs(extra) do to_move[#to_move + 1] = it end

        for _, it in ipairs(to_move) do
            local ipos = GetMediaItemInfo_Value(it, "D_POSITION")
            SetMediaItemInfo_Value(it, "D_POSITION", ipos + delta)
        end
    end

    UpdateArrange()
    PreventUIRefresh(-1)

    local mode_str = relative_mode and string.format("%.2f%% relative", new_rate_val)
                                    or string.format("%.4fs absolute", new_rate_val)
    message_text = string.format("Time-stretched (%s) on %d item(s)\nRippled by %.4fs.",
        mode_str, #all_target_items, total_delta)
    message_timer = ImGui.GetTime(ctx)

    Undo_EndBlock(string.format("RC Time Stretch (%s)", mode_str), -1)
end

---------------------------------------------------------------------

function apply_pitch_change(semitones)
    Undo_BeginBlock()
    PreventUIRefresh(1)

    local sel_items = get_selected_media_items()
    if #sel_items == 0 then
        PreventUIRefresh(-1)
        message_text = "No items selected."
        message_timer = ImGui.GetTime(ctx)
        Undo_EndBlock("RC Pitch Adjust (no-op)", -1)
        return
    end

    local folder_item = nil
    local folder_item_count = 0
    for _, item in ipairs(sel_items) do
        if is_folder_track(GetMediaItemTrack(item)) then
            folder_item = item
            folder_item_count = folder_item_count + 1
        end
    end
    if folder_item_count > 1 then
        PreventUIRefresh(-1)
        message_text = "Please select only one item at a time."
        message_timer = ImGui.GetTime(ctx)
        Undo_EndBlock("RC Pitch Adjust (no-op)", -1)
        return
    end
    if not folder_item then folder_item = sel_items[1] end

    local all_target_items = get_all_items_at_midpoints(sel_items)

    for _, item in ipairs(all_target_items) do
        local take = GetActiveTake(item)
        if take then
            SetMediaItemTakeInfo_Value(take, "D_PITCH", semitones)
        end
    end

    UpdateArrange()
    PreventUIRefresh(-1)
    message_text = string.format("Pitch set to %.2f semitones on %d item(s).",
        semitones, #all_target_items)
    message_timer = ImGui.GetTime(ctx)
    Undo_EndBlock(string.format("RC Pitch Adjust (%.2f semitones)", semitones), -1)
end

---------------------------------------------------------------------

function main()
    if window_open then
        ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, math.huge, math.huge)
        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Playrate and Pitch Adjuster", window_open)
        window_open = open_ref

        if opened then
            local avail_w = ImGui.GetContentRegionAvail(ctx)

            local sel_count = count_selected_media_items()
            ImGui.Text(ctx, string.format("Selected items: %d", sel_count))
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            local rv_abs, new_abs = ImGui.Checkbox(ctx, "Absolute rate (%)", not is_relative)
            if rv_abs then is_relative = not new_abs end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            if is_relative then
                ImGui.Text(ctx, "Rate change (%):  relative to current rate")
            else
                ImGui.Text(ctx, "Rate (%):  absolute from normal speed")
            end
            ImGui.SetNextItemWidth(ctx, avail_w)
            local rv, new_str = ImGui.InputText(ctx, "##rate_input", rate_str)
            if rv then rate_str = new_str end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            local can_apply = sel_count > 0 and tonumber(rate_str) ~= nil
            if not can_apply then ImGui.BeginDisabled(ctx) end

            if ImGui.Button(ctx, 'Apply & Ripple', avail_w, 35) then
                local val = tonumber(rate_str)
                if val then
                    apply_rate_change(val, is_relative)
                else
                    message_text = "Invalid rate value."
                    message_timer = ImGui.GetTime(ctx)
                end
            end

            if not can_apply then ImGui.EndDisabled(ctx) end

            ImGui.Spacing(ctx)

            if sel_count == 0 then ImGui.BeginDisabled(ctx) end
            if ImGui.Button(ctx, 'Reset to Normal Speed', avail_w, 30) then
                reset_to_normal()
            end
            if sel_count == 0 then ImGui.EndDisabled(ctx) end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            ImGui.Text(ctx, "Pitch Adjustment (semitones):")
            ImGui.SetNextItemWidth(ctx, avail_w)
            local rv_p, new_p = ImGui.InputText(ctx, "##pitch_input", pitch_str)
            if rv_p then pitch_str = new_p end
            ImGui.Spacing(ctx)
            ImGui.TextDisabled(ctx, "0 = normal  |  positive = higher  |  negative = lower")
            ImGui.Spacing(ctx)

            local can_pitch = sel_count > 0 and tonumber(pitch_str) ~= nil
            if not can_pitch then ImGui.BeginDisabled(ctx) end

            if ImGui.Button(ctx, 'Apply Pitch', avail_w, 30) then
                local val = tonumber(pitch_str)
                if val then
                    apply_pitch_change(val)
                else
                    message_text = "Invalid pitch value."
                    message_timer = ImGui.GetTime(ctx)
                end
            end

            if not can_pitch then ImGui.EndDisabled(ctx) end

            ImGui.Spacing(ctx)

            if sel_count == 0 then ImGui.BeginDisabled(ctx) end
            if ImGui.Button(ctx, 'Reset Pitch', avail_w, 30) then
                apply_pitch_change(0.0)
            end
            if sel_count == 0 then ImGui.EndDisabled(ctx) end

            ImGui.Spacing(ctx)

            do
                local current_time = ImGui.GetTime(ctx)
                if message_text ~= "" and current_time - message_timer < message_duration then
                    local time_left = message_duration - (current_time - message_timer)
                    local alpha = math.min(1.0, time_left / 0.5)
                    ImGui.PushStyleColor(ctx, ImGui.Col_Text,
                        ImGui.ColorConvertDouble4ToU32(0.2, 0.8, 0.2, alpha))
                    ImGui.TextWrapped(ctx, message_text)
                    ImGui.PopStyleColor(ctx)
                    if current_time - message_timer >= message_duration then
                        message_text = ""
                    end
                else
                    ImGui.Text(ctx, " ")
                    ImGui.Text(ctx, " ")
                    message_text = ""
                end
            end

            if ImGui.IsWindowFocused(ctx) and ImGui.IsKeyPressed(ctx, ImGui.Key_K, false) then
                window_open = false
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

defer(main)