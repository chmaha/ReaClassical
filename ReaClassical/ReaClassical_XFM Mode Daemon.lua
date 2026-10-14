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

set_action_options(1)

local _, _, section_id, cmd_id = get_action_context()

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local xfu = require("ReaClassical_XFM_Utils")
local active_folder = require("ReaClassical_Active_Folder")

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

local prev_ripple = GetToggleCommandState(40310)

local function find_xfade_at_selection()
    local sel = GetSelectedMediaItem(0, 0)
    if not sel then return nil, nil, "none" end

    local prev = xfu.get_previous_on_track(sel)
    if not prev then return nil, nil, "no_crossfade" end

    local pos1 = GetMediaItemInfo_Value(prev, "D_POSITION")
    local len1 = GetMediaItemInfo_Value(prev, "D_LENGTH")
    local pos2 = GetMediaItemInfo_Value(sel, "D_POSITION")
    local end1 = pos1 + len1
    if pos2 >= end1 - 0.0001 then return nil, nil, "no_crossfade" end

    local track = GetMediaItemTrack(sel)
    local folder_track = xfu.is_folder_track(track) and track or xfu.get_parent_folder(track)
    if not folder_track then return nil, nil, "no_crossfade" end

    local xf = {
        item1 = prev, item2 = sel,
        pos1  = pos1, len1  = len1, end1 = end1,
        pos2  = pos2, len2  = GetMediaItemInfo_Value(sel, "D_LENGTH"),
        overlap = end1 - pos2,
        center  = (pos2 + end1) * 0.5,
    }
    return xf, folder_track, nil
end

local xf, folder_track, fail_reason = find_xfade_at_selection()
if not xf then
    say(fail_reason == "none" and "No items selected" or "No crossfade to the left of this item")
    return
end

if GetToggleCommandState(40310) ~= 1 then
    Main_OnCommand(40310, 0)
end

Main_OnCommand(24800, 0)
Main_OnCommand(24803, 0)
SetExtState("ReaClassical", "XFadeMode", "1", false)
active_folder.set_active(folder_track)
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

local function main()
    SetToggleCommandState(section_id, cmd_id, 1)
    defer(main)
end

local function at_exit()
    Main_OnCommand(24800, 0)
    local ctx = xfu.get_xfade_context()
    if ctx then xfu.select_items(ctx.group2) end
    SetExtState("ReaClassical", "XFadeMode",      "", false)
    SetExtState("ReaClassical", "XFadeSelection", "", false)
    SetExtState("ReaClassical", "XFadeCenter",    "", false)
    SetExtState("ReaClassical", "XFadeFolderIdx", "", false)
    local cur = GetToggleCommandState(40310)
    if prev_ripple == 0 and cur == 1 then Main_OnCommand(40310, 0) end
    if prev_ripple == 1 and cur == 0 then Main_OnCommand(40310, 0) end
    SetToggleCommandState(section_id, cmd_id, 0)
    say("Crossfade mode off")
end

atexit(at_exit)
defer(main)
