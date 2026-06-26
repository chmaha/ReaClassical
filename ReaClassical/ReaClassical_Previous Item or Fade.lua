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

local main, move_to_item, get_selected_media_item_at, announce_current_item
local navigate_xfade
local get_envelope_stops, get_selected_stop_index, select_only_stop
local announce_envelope_stop, move_envelope, clear_all_envelope_selections

---------------------------------------------------------------------

-- Builds a single time-ordered list of "stops" along the selected
-- envelope's lane: every automation item (as one stop at its start time)
-- plus every point on the main lane (autoitem_idx -1). Lets Next/Previous
-- step through whichever kind comes next, regardless of type.
function get_envelope_stops(env)
    local stops = {}

    local ai_count = CountAutomationItems(env)
    for i = 0, ai_count - 1 do
        local pos = GetSetAutomationItemInfo(env, i, "D_POSITION", 0, false)
        stops[#stops + 1] = { time = pos, kind = "ai", idx = i }
    end

    local pt_count = CountEnvelopePointsEx(env, -1)
    for i = 0, pt_count - 1 do
        local ok, time, value = GetEnvelopePointEx(env, -1, i)
        if ok then
            stops[#stops + 1] = { time = time, kind = "point", idx = i, value = value }
        end
    end

    table.sort(stops, function(a, b) return a.time < b.time end)
    return stops
end

---------------------------------------------------------------------

function get_selected_stop_index(env, stops)
    for i, s in ipairs(stops) do
        if s.kind == "point" then
            local ok, _, _, _, _, selected = GetEnvelopePointEx(env, -1, s.idx)
            if ok and selected then return i end
        else
            local selected = GetSetAutomationItemInfo(env, s.idx, "D_UISEL", 0, false)
            if selected and selected > 0 then return i end
        end
    end
    return nil
end

---------------------------------------------------------------------

-- Deselects every point and automation item on every track/master envelope
-- in the project, so navigating on one lane can't leave a stale selection
-- lit up on another lane.
function clear_all_envelope_selections()
    local function clear_envelope(env)
        local pt_count = CountEnvelopePointsEx(env, -1)
        for i = 0, pt_count - 1 do
            SetEnvelopePointEx(env, -1, i, nil, nil, nil, nil, false, true)
        end
        Envelope_SortPointsEx(env, -1)

        local ai_count = CountAutomationItems(env)
        for i = 0, ai_count - 1 do
            GetSetAutomationItemInfo(env, i, "D_UISEL", 0, true)
        end
    end

    local master = GetMasterTrack(0)
    if master then
        for e = 0, CountTrackEnvelopes(master) - 1 do
            clear_envelope(GetTrackEnvelope(master, e))
        end
    end

    for t = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, t)
        for e = 0, CountTrackEnvelopes(track) - 1 do
            clear_envelope(GetTrackEnvelope(track, e))
        end
    end
end

---------------------------------------------------------------------

function select_only_stop(env, stops, target_index)
    clear_all_envelope_selections()
    local target = stops[target_index]
    if target.kind == "point" then
        SetEnvelopePointEx(env, -1, target.idx, nil, nil, nil, nil, true, true)
        Envelope_SortPointsEx(env, -1)
    else
        GetSetAutomationItemInfo(env, target.idx, "D_UISEL", 1, true)
    end
end

---------------------------------------------------------------------

-- boundary_word is nil for a normal move, or "First"/"Last" when this stop
-- is the one landed on because there was nowhere further to go.
function announce_envelope_stop(env, stops, target_index, boundary_word)
    local target = stops[target_index]
    local _, env_name = GetEnvelopeName(env, "")
    local pos_str = format_timestr_pos(target.time, "", -1)
    local kind_word = (target.kind == "ai") and "automation item" or "point"
    local prefix = boundary_word and (boundary_word .. " ") or ""

    local ordinal, total = 0, 0
    for i, s in ipairs(stops) do
        if s.kind == target.kind then
            total = total + 1
            if i == target_index then ordinal = total end
        end
    end

    if target.kind == "ai" then
        say(string.format("%s%s %s %d of %d at %s", prefix, env_name, kind_word, ordinal, total, pos_str))
    else
        say(string.format("%s%s %s %d of %d at %s, value %.2f",
            prefix, env_name, kind_word, ordinal, total, pos_str, target.value))
    end
end

---------------------------------------------------------------------

-- direction: 1 for next, -1 for previous. Steps from whichever stop is
-- currently selected on this envelope, or from the edit cursor if none is.
-- When stepping from a known, exact stop (cur_idx set), the search is
-- strict so repeated presses always move to a different stop. When
-- starting fresh on this envelope (e.g. just switched lanes), the search
-- is inclusive of a stop sitting exactly at the reference time, since the
-- edit cursor may coincidentally already be sitting on one (left there by
-- navigation on a different lane) and that should still count.
function move_envelope(env, direction)
    local stops = get_envelope_stops(env)
    if #stops == 0 then
        say("No envelope points")
        return
    end

    local cur_idx = get_selected_stop_index(env, stops)
    local ref_time = cur_idx and stops[cur_idx].time or GetCursorPosition()
    local inclusive = (cur_idx == nil)
    local eps = 0.0000001

    local target_index
    if direction > 0 then
        for i, s in ipairs(stops) do
            if (inclusive and s.time >= ref_time - eps) or (not inclusive and s.time > ref_time + eps) then
                target_index = i
                break
            end
        end
    else
        for i = #stops, 1, -1 do
            if (inclusive and stops[i].time <= ref_time + eps)
                or (not inclusive and stops[i].time < ref_time - eps) then
                target_index = i
                break
            end
        end
    end

    -- Nowhere further to go: snap-select the actual first/last stop (it may
    -- not already be selected, e.g. fresh focus on this lane) and say so,
    -- rather than silently doing nothing.
    if not target_index then
        target_index = (direction > 0) and #stops or 1
        select_only_stop(env, stops, target_index)
        SetEditCurPos(stops[target_index].time, true, false)
        announce_envelope_stop(env, stops, target_index, (direction > 0) and "Last" or "First")
        return
    end

    select_only_stop(env, stops, target_index)
    SetEditCurPos(stops[target_index].time, true, false)
    announce_envelope_stop(env, stops, target_index)
end

---------------------------------------------------------------------

function announce_current_item()
    local item = get_selected_media_item_at(0)
    if not item then return end
    local take = GetActiveTake(item)
    local name = ""
    if take then
        _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    end
    if name == "" then
        say("(unnamed)")
        return
    end
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        say(prefix .. " take " .. tonumber(take_num))
        return
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        say("Take " .. tonumber(only_num))
        return
    end
    say(name)
end

---------------------------------------------------------------------

function navigate_xfade(direction)
    local idx    = tonumber(GetExtState("ReaClassical", "XFadeFolderIdx"))
    local center = tonumber(GetExtState("ReaClassical", "XFadeCenter"))
    if not idx or not center then say("No crossfade context"); return end

    local folder_track = GetTrack(0, idx)
    if not folder_track then say("No crossfade context"); return end

    local xfades = xfu.find_crossfades(folder_track)
    if #xfades == 0 then say("No crossfades found"); return end

    local cur_i = 1
    local best_dist
    for i, xf in ipairs(xfades) do
        local d = math.abs(xf.center - center)
        if not best_dist or d < best_dist then
            cur_i = i; best_dist = d
        end
    end

    local next_i = cur_i + direction
    local boundary
    if next_i < 1 then
        next_i = 1; boundary = "First"
    elseif next_i > #xfades then
        next_i = #xfades; boundary = "Last"
    end

    local target = xfades[next_i]
    xfu.set_xfade_state(folder_track, target.center)
    xfu.set_selection("both")

    local mid1   = target.pos1 + target.len1 * 0.5
    local mid2   = target.pos2 + GetMediaItemInfo_Value(target.item2, "D_LENGTH") * 0.5
    local group1 = xfu.get_items_at_midpoint(folder_track, mid1)
    local group2 = xfu.get_items_at_midpoint(folder_track, mid2)
    local all    = {}
    for _, it in ipairs(group1) do all[#all + 1] = it end
    for _, it in ipairs(group2) do all[#all + 1] = it end
    xfu.select_items(all)
    SetEditCurPos(target.center, true, false)

    local prefix = boundary and (boundary .. " crossfade") or
        ("Crossfade " .. next_i .. " of " .. #xfades)
    say(prefix)
end

---------------------------------------------------------------------

function main()
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

    if xfu.is_xfade_mode() then
        navigate_xfade(-1)
        UpdateArrange()
        UpdateTimeline()
        return
    end

    local env = GetSelectedEnvelope(0)
    if env then
        move_envelope(env, -1)
        UpdateArrange()
        UpdateTimeline()
        return
    end

    move_to_item()

    UpdateArrange()
    UpdateTimeline()
    announce_current_item()
end

---------------------------------------------------------------------

function move_to_item()
    local item = get_selected_media_item_at(0)
    local item_start
    if item then
        item_start = GetMediaItemInfo_Value(item, "D_POSITION")
    end
    local cursor_position = GetCursorPosition()
    if item_start and cursor_position > item_start then
        Main_OnCommand(40416, 0)     -- Select and move to prev item
        Main_OnCommand(40416, 0)     -- Select and move to prev item
    else
        Main_OnCommand(40416, 0)     -- Select and move to prev item
    end
    Main_OnCommand(40034, 0)         -- Item grouping: Select all items in group(s)
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

main()
