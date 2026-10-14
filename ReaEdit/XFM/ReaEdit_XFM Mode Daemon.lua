--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "../lib/?.lua;"
local say = require("ReaEdit_Announce")
local xfu = require("ReaEdit_XFM_Utils")
local XFM_SECTION_OVERRIDE_ACTION = require("ReaEdit_XFM_Keys").OVERRIDE_ACTION

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

    local ref_track = GetMediaItemTrack(sel)

    local xf = {
        item1 = prev, item2 = sel,
        pos1  = pos1, len1  = len1, end1 = end1,
        pos2  = pos2, len2  = GetMediaItemInfo_Value(sel, "D_LENGTH"),
        overlap = end1 - pos2,
        center  = (pos2 + end1) * 0.5,
    }
    return xf, ref_track, nil
end

local xf, ref_track, fail_reason = find_xfade_at_selection()
if not xf then
    say(fail_reason == "none" and "No items selected" or "No crossfade to the left of this item")
    return
end

if GetToggleCommandState(40310) ~= 1 then
    Main_OnCommand(40310, 0)
end

Main_OnCommand(24800, 0)
Main_OnCommand(XFM_SECTION_OVERRIDE_ACTION, 0)
SetExtState("ReaEdit", "XFadeMode", "1", false)
xfu.focus_crossfade(ref_track, xf)

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
    SetExtState("ReaEdit", "XFadeMode",      "", false)
    SetExtState("ReaEdit", "XFadeSelection", "", false)
    SetExtState("ReaEdit", "XFadeCenter",    "", false)
    SetExtState("ReaEdit", "XFadeTrackIdx", "", false)
    local cur = GetToggleCommandState(40310)
    if prev_ripple == 0 and cur == 1 then Main_OnCommand(40310, 0) end
    if prev_ripple == 1 and cur == 0 then Main_OnCommand(40310, 0) end
    SetToggleCommandState(section_id, cmd_id, 0)
    say("Crossfade mode off")
end

atexit(at_exit)
defer(main)
