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

-- Crossfade Mode daemon: F-key toggle for keyboard-driven xfade editing.
-- Finds the nearest crossfade to the edit cursor on any folder track, selects
-- both items and all their folder-scoped peers, then keeps the mode active
-- until pressed again (set_action_options(1) toggles on second press).

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

set_action_options(1)

local _, _, section_id, cmd_id = get_action_context()

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")

---------------------------------------------------------------------

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

-- Save ripple-per-track state to restore on exit.
local prev_ripple = GetToggleCommandState(40310)

---------------------------------------------------------------------

local function find_nearest_xfade()
    local cursor   = GetCursorPosition()
    local best, best_dist, best_folder
    local num = CountTracks(0)
    for ti = 0, num - 1 do
        local track = GetTrack(0, ti)
        if xfu.is_folder_track(track) then
            for _, xf in ipairs(xfu.find_crossfades(track)) do
                local d = math.abs(xf.center - cursor)
                if not best_dist or d < best_dist then
                    best = xf; best_dist = d; best_folder = track
                end
            end
        end
    end
    return best, best_folder
end

---------------------------------------------------------------------

local xf, folder_track = find_nearest_xfade()
if not xf then
    say("No crossfade found")
    return
end

-- Enable ripple per-track while in xfade mode.
if GetToggleCommandState(40310) ~= 1 then
    Main_OnCommand(40310, 0)
end

Main_OnCommand(24800, 0)  -- clear any section override
Main_OnCommand(24803, 0)  -- switch to alt-1 keymap section
SetExtState("ReaClassical", "XFadeMode", "1", false)
xfu.set_xfade_state(folder_track, xf.center)
xfu.set_selection("both")

local mid1   = xf.pos1 + xf.len1 * 0.5
local mid2   = xf.pos2 + GetMediaItemInfo_Value(xf.item2, "D_LENGTH") * 0.5
local group1 = xfu.get_items_at_midpoint(folder_track, mid1)
local group2 = xfu.get_items_at_midpoint(folder_track, mid2)
local all    = {}
for _, it in ipairs(group1) do all[#all + 1] = it end
for _, it in ipairs(group2) do all[#all + 1] = it end
xfu.select_items(all)
SetEditCurPos(xf.center, true, false)

UpdateArrange()
UpdateTimeline()
say("Crossfade mode on")

---------------------------------------------------------------------

local function main()
    SetToggleCommandState(section_id, cmd_id, 1)
    defer(main)
end

local function at_exit()
    Main_OnCommand(24800, 0)  -- clear back to main keymap section
    local ctx = xfu.get_xfade_context()
    if ctx then xfu.select_items(ctx.group2) end
    SetExtState("ReaClassical", "XFadeMode",      "", false)
    SetExtState("ReaClassical", "XFadeSelection", "", false)
    SetExtState("ReaClassical", "XFadeCenter",    "", false)
    SetExtState("ReaClassical", "XFadeFolderIdx", "", false)
    -- Restore ripple state.
    local cur = GetToggleCommandState(40310)
    if prev_ripple == 0 and cur == 1 then Main_OnCommand(40310, 0) end
    if prev_ripple == 1 and cur == 0 then Main_OnCommand(40310, 0) end
    SetToggleCommandState(section_id, cmd_id, 0)
    say("Crossfade mode off")
end

atexit(at_exit)
defer(main)
