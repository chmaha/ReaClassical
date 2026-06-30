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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say              = require("ReaClassical_Announce")
local humanize_timestr  = require("ReaClassical_Time_Naming")
local au                = require("ReaClassical_Automation_Info")

local is_special_track = au.is_special_track
local find_env_info    = au.find_env_info
local get_track_label  = au.get_track_label

local main, move
local collect_special_envelopes, get_all_items, get_current_item_index
local clear_all_selections, select_only_item, cursor_pos_for, announce_item

---------------------------------------------------------------------

-- Every track/FX envelope on every special track (mixdown, RCMASTER, aux,
-- submix, roomtone, etc.), in a stable track-then-envelope order. Computed
-- once per invocation and reused for building the item list, finding the
-- currently selected item, and clearing selections, so the project isn't
-- walked three separate times.
function collect_special_envelopes()
    local list = {}
    for ti = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, ti)
        if is_special_track(t) then
            local envs = {}
            for ei = 0, CountTrackEnvelopes(t) - 1 do
                table.insert(envs, GetTrackEnvelope(t, ei))
            end
            for fx = 0, TrackFX_GetCount(t) - 1 do
                for p = 0, TrackFX_GetNumParams(t, fx) - 1 do
                    local fxe = GetFXEnvelope(t, fx, p, false)
                    if fxe then table.insert(envs, fxe) end
                end
            end
            for env_order, env in ipairs(envs) do
                local env_info = find_env_info(t, env)
                if env_info then
                    list[#list + 1] = {
                        track = t, track_order = ti,
                        env = env, env_order = env_order,
                        env_info = env_info,
                    }
                end
            end
        end
    end
    return list
end

---------------------------------------------------------------------

-- One time-ordered list of every automation item across every special-track
-- envelope. Sorted by time, then by track/envelope order, so that several
-- lanes with an item at the same time are visited one at a time rather than
-- grouped.
function get_all_items(envelopes)
    local items = {}

    for _, e in ipairs(envelopes) do
        local ai_count = CountAutomationItems(e.env)
        for i = 0, ai_count - 1 do
            local pos = GetSetAutomationItemInfo(e.env, i, "D_POSITION", 0, false)
            local len = GetSetAutomationItemInfo(e.env, i, "D_LENGTH",   0, false)
            items[#items + 1] = {
                time = pos, len = len, idx = i,
                track = e.track, track_order = e.track_order,
                env = e.env, env_order = e.env_order, env_info = e.env_info,
            }
        end
    end

    table.sort(items, function(a, b)
        if a.time ~= b.time then return a.time < b.time end
        if a.track_order ~= b.track_order then return a.track_order < b.track_order end
        return a.env_order < b.env_order
    end)

    return items
end

---------------------------------------------------------------------

function get_current_item_index(items)
    for i, it in ipairs(items) do
        local selected = GetSetAutomationItemInfo(it.env, it.idx, "D_UISEL", 0, false)
        if selected and selected > 0 then return i end
    end
    return nil
end

---------------------------------------------------------------------

-- Clears automation-item selection on every special-track envelope (not
-- project-wide) so a fresh Next/Previous press always starts from a clean
-- slate within this feature's own scope.
function clear_all_selections(envelopes)
    for _, e in ipairs(envelopes) do
        local ai_count = CountAutomationItems(e.env)
        for i = 0, ai_count - 1 do
            GetSetAutomationItemInfo(e.env, i, "D_UISEL", 0, true)
        end
    end
end

---------------------------------------------------------------------

function select_only_item(envelopes, items, target_index)
    clear_all_selections(envelopes)
    local target = items[target_index]
    GetSetAutomationItemInfo(target.env, target.idx, "D_UISEL", 1, true)
end

---------------------------------------------------------------------

function cursor_pos_for(it)
    return it.time + it.len / 2
end

---------------------------------------------------------------------

-- boundary_word is nil for a normal move, or "First"/"Last" when this item
-- is the one landed on because there was nowhere further to go.
function announce_item(items, target_index, boundary_word)
    local target = items[target_index]
    local ei = target.env_info
    local param_label = ei.type == "track"
        and ei.name
        or  (ei.fx_name .. ": " .. ei.name)
    local track_label = get_track_label(target.track)
    local pos_str = humanize_timestr(format_timestr_pos(cursor_pos_for(target), "", -1))
    local prefix = boundary_word and (boundary_word .. " ") or ""

    say(string.format("%s%s on %s, automation item %d of %d, at %s",
        prefix, param_label, track_label, target_index, #items, pos_str))
end

---------------------------------------------------------------------

-- direction: 1 for next, -1 for previous. Steps from whichever item is
-- currently selected, or from the edit cursor if none is. When stepping
-- from a known item, the move is a plain index step (not a time search) so
-- that several items sharing the same time on different lanes are visited
-- one at a time instead of being skipped as a group.
function move(direction)
    local envelopes = collect_special_envelopes()
    local items = get_all_items(envelopes)
    if #items == 0 then
        say("No automation items")
        return
    end

    local cur_idx = get_current_item_index(items)
    local target_index

    if cur_idx then
        target_index = cur_idx + direction
        if target_index < 1 or target_index > #items then target_index = nil end
    else
        local ref_time = GetCursorPosition()
        local eps = 0.0000001
        if direction > 0 then
            for i, it in ipairs(items) do
                if it.time >= ref_time - eps then target_index = i break end
            end
        else
            for i = #items, 1, -1 do
                if items[i].time <= ref_time + eps then target_index = i break end
            end
        end
    end

    if not target_index then
        target_index = (direction > 0) and #items or 1
        select_only_item(envelopes, items, target_index)
        SetEditCurPos(cursor_pos_for(items[target_index]), true, false)
        announce_item(items, target_index, (direction > 0) and "Last" or "First")
    else
        select_only_item(envelopes, items, target_index)
        SetEditCurPos(cursor_pos_for(items[target_index]), true, false)
        announce_item(items, target_index)
    end

    UpdateArrange()
    UpdateTimeline()
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

    move(-1)
end

---------------------------------------------------------------------

main()
