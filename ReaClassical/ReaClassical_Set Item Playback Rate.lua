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
local apply_rate_change
local get_folder_children, get_all_items_in_groups_for_items
local collect_automation, restore_automation
local is_folder_track, get_parent_folder, is_in_child_track

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

-- UI state
local rate_input_buf = reaper.new_array and nil  -- handled via string
local rate_str = "5.0"  -- relative % change by default
local is_relative = true        -- true = relative %, false = absolute rate value
local pitch_str = "0.0"         -- semitones input

-- Message state
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
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
            return t
        end
    end
    return nil
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
        if IsMediaItemSelected(item) then
            selected_count = selected_count + 1
        end
    end
    return selected_count
end

---------------------------------------------------------------------

function get_selected_media_items()
    local result = {}
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            result[#result + 1] = item
        end
    end
    return result
end

---------------------------------------------------------------------

-- Returns all items that share a group with any item in the provided list,
-- plus the provided items themselves. De-duplicated.
function get_all_items_in_groups_for_items(base_items)
    local group_ids = {}
    local seen = {}
    local result = {}

    for _, item in ipairs(base_items) do
        seen[item] = true
        result[#result + 1] = item
        local gid = GetMediaItemInfo_Value(item, "I_GROUPID")
        if gid and gid > 0 then
            group_ids[gid] = true
        end
    end

    if next(group_ids) then
        local total_items = CountMediaItems(0)
        for i = 0, total_items - 1 do
            local item = GetMediaItem(0, i)
            if not seen[item] then
                local gid = GetMediaItemInfo_Value(item, "I_GROUPID")
                if gid and gid > 0 and group_ids[gid] then
                    seen[item] = true
                    result[#result + 1] = item
                end
            end
        end
    end

    return result
end

---------------------------------------------------------------------

-- Collect automation envelope points and automation items for a set of items
-- (covering the union of their time spans), relative to track_start.
-- Points are deleted from envelopes so they can be reinserted at new positions.
function collect_automation(items_list, track_start, tracks_list)
    local range_start = math.huge
    local range_end   = 0
    for _, item in ipairs(items_list) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        range_start = math.min(range_start, pos)
        range_end   = math.max(range_end, pos + len)
    end
    if range_start == math.huge then return {} end

    local snapshot = {}
    for _, track in ipairs(tracks_list) do
        local track_data = { track = track, envs = {} }
        local num_envs = CountTrackEnvelopes(track)
        for e = 0, num_envs - 1 do
            local env = GetTrackEnvelope(track, e)
            local env_data = { env = env, points = {}, ai = {} }

            -- Collect + delete envelope points in range
            local num_points = CountEnvelopePoints(env)
            local p = 0
            while p < num_points do
                local _, time, value, shape, tension, sel = GetEnvelopePoint(env, p)
                if time >= range_start and time <= range_end then
                    table.insert(env_data.points, {
                        rel     = time - track_start,
                        value   = value, shape = shape,
                        tension = tension, sel = sel
                    })
                    DeleteEnvelopePointRange(env, time - 0.00005, time + 0.00005)
                    num_points = CountEnvelopePoints(env)
                    -- don't advance p, same index is now the next point
                else
                    p = p + 1
                end
            end
            Envelope_SortPoints(env)

            -- Collect automation items in range
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

function restore_automation(snapshot, new_track_start)
    for _, track_data in ipairs(snapshot) do
        for _, env_data in ipairs(track_data.envs) do
            local env = env_data.env
            for _, pt in ipairs(env_data.points) do
                InsertEnvelopePoint(env, new_track_start + pt.rel, pt.value,
                    pt.shape, pt.tension, pt.sel, true)
            end
            Envelope_SortPoints(env)
            local num_ai = CountAutomationItems(env)
            for ai = 0, num_ai - 1 do
                local ai_len = GetSetAutomationItemInfo(env, ai, "D_LENGTH", 0, false)
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

-- Find all items that start at or after right_boundary and are not in the
-- target set. Then expand to include group-mates -- BUT only add a group-mate
-- if it also starts at or after right_boundary, so we never accidentally
-- drag a left-side item into the ripple move.
function get_items_to_ripple(selected_and_group, right_boundary)
    -- Build a fast lookup for the target set
    local target_set = {}
    for _, si in ipairs(selected_and_group) do
        target_set[si] = true
    end

    -- First pass: items that start at/after boundary and are not target items
    local group_ids = {}
    local seen = {}
    local result = {}
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if not target_set[item] then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if pos >= right_boundary - 0.0001 then
                if not seen[item] then
                    seen[item] = true
                    result[#result + 1] = item
                end
                local gid = GetMediaItemInfo_Value(item, "I_GROUPID")
                if gid and gid > 0 then
                    group_ids[gid] = true
                end
            end
        end
    end

    -- Second pass: add group-mates that are ALSO at/after the boundary
    -- (never pull in items from the left side of the boundary)
    if next(group_ids) then
        for i = 0, total_items - 1 do
            local item = GetMediaItem(0, i)
            if not target_set[item] and not seen[item] then
                local gid = GetMediaItemInfo_Value(item, "I_GROUPID")
                if gid and gid > 0 and group_ids[gid] then
                    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                    if pos >= right_boundary - 0.0001 then
                        seen[item] = true
                        result[#result + 1] = item
                    end
                end
            end
        end
    end

    return result
end

---------------------------------------------------------------------

function reset_to_normal()
    -- 0 in absolute mode = 1.0x (normal speed)
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

    -- Only one folder track item may be selected. Multiple would each need
    -- their own delta and would interfere with each other's ripple.
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
    -- Fallback: use first selected item if none found on folder track
    if not folder_item then folder_item = sel_items[1] end

    -- Expand to all grouped items (stereo pair, child tracks etc.)
    local all_target_items = get_all_items_in_groups_for_items(sel_items)

    -- Build target_set for ripple exclusion
    local target_set = {}
    for _, ti in ipairs(all_target_items) do target_set[ti] = true end

    -- Step 1: Compute rate/length from the folder item only
    local folder_take = GetActiveTake(folder_item)
    if not folder_take then
        PreventUIRefresh(-1)
        message_text = "Selected item has no take."
        message_timer = ImGui.GetTime(ctx)
        Undo_EndBlock("RC Time Stretch (no-op)", -1)
        return
    end

    local folder_pos  = GetMediaItemInfo_Value(folder_item, "D_POSITION")
    local old_len     = GetMediaItemInfo_Value(folder_item, "D_LENGTH")
    local old_rate    = GetMediaItemTakeInfo_Value(folder_take, "D_PLAYRATE")

    local new_rate
    if relative_mode then
        -- 5 = 5% faster than current rate
        new_rate = old_rate * (1.0 + new_rate_val / 100.0)
    else
        -- 5 = 5% faster than normal (1.0x), i.e. always relative to 1.0
        new_rate = 1.0 + new_rate_val / 100.0
    end
    new_rate = math.max(0.01, math.min(100.0, new_rate))
    local new_len = old_len * (old_rate / new_rate)
    new_len = math.max(0.001, new_len)
    local delta = new_len - old_len

    -- Step 2: Apply rate+length to ALL grouped items (folder + all children)
    for _, item in ipairs(all_target_items) do
        local take = GetActiveTake(item)
        if take then
            -- Explicitly set B_PPITCH in both directions so toggling the
            -- checkbox always takes effect, even on previously stretched items.
            SetMediaItemTakeInfo_Value(take, "B_PPITCH", 1)  -- always preserve pitch when time-stretching
            SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", new_rate)
            SetMediaItemInfo_Value(item, "D_LENGTH", new_len)
        end
    end

    -- Step 3: Build a set of tracks that belong to the selected item's folder.
    -- Only items on these tracks should be rippled — items in other folders
    -- must not be affected.
    local folder_track = GetMediaItemTrack(folder_item)
    local folder_track_set = { [folder_track] = true }
    for _, child in ipairs(get_folder_children(folder_track)) do
        folder_track_set[child] = true
    end

    -- Ripple once, using the folder item's position as boundary.
    -- Only items within the same folder and starting after folder_pos are moved.
    local total_delta = delta
    if math.abs(delta) > 0.0001 then
        local total_items = CountMediaItems(0)
        local to_move_set = {}
        local to_move     = {}
        local move_group_ids = {}

        for i = 0, total_items - 1 do
            local it = GetMediaItem(0, i)
            if not target_set[it] and folder_track_set[GetMediaItemTrack(it)] then
                local ipos = GetMediaItemInfo_Value(it, "D_POSITION")
                if ipos > folder_pos + 0.0001 then
                    if not to_move_set[it] then
                        to_move_set[it] = true
                        to_move[#to_move + 1] = it
                    end
                    local gid = GetMediaItemInfo_Value(it, "I_GROUPID")
                    if gid and gid > 0 then move_group_ids[gid] = true end
                end
            end
        end

        -- Group-mates must also be within the folder
        if next(move_group_ids) then
            for i = 0, total_items - 1 do
                local it = GetMediaItem(0, i)
                if not target_set[it] and not to_move_set[it]
                        and folder_track_set[GetMediaItemTrack(it)] then
                    local gid = GetMediaItemInfo_Value(it, "I_GROUPID")
                    if gid and gid > 0 and move_group_ids[gid] then
                        local ipos = GetMediaItemInfo_Value(it, "D_POSITION")
                        if ipos > folder_pos + 0.0001 then
                            to_move_set[it] = true
                            to_move[#to_move + 1] = it
                        end
                    end
                end
            end
        end

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

    -- Find folder item and expand to grouped items
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

    local all_target_items = get_all_items_in_groups_for_items(sel_items)

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

            -- Selected item count
            local sel_count = count_selected_media_items()
            ImGui.Text(ctx, string.format("Selected items: %d", sel_count))
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            -- Absolute checkbox
            local rv_abs, new_abs = ImGui.Checkbox(ctx, "Absolute rate (%)", not is_relative)
            if rv_abs then is_relative = not new_abs end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            -- Value input
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

            -- Apply button
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

            -- Reset button
            if sel_count == 0 then ImGui.BeginDisabled(ctx) end
            if ImGui.Button(ctx, 'Reset to Normal Speed', avail_w, 30) then
                reset_to_normal()
            end
            if sel_count == 0 then ImGui.EndDisabled(ctx) end

            ImGui.Spacing(ctx)
            ImGui.Separator(ctx)
            ImGui.Spacing(ctx)

            -- Pitch adjustment section
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

            -- Status / feedback message — always reserve the same space so the
            -- window never grows and gets a scrollbar.
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
                    -- Empty placeholder — same height as two lines of text
                    ImGui.Text(ctx, " ")
                    ImGui.Text(ctx, " ")
                    message_text = ""
                end
            end

            -- Close on K
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