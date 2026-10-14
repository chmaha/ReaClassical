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
local special_track_nav = require("ReaClassical_Special_Track_Nav")
local xfu = require("ReaClassical_XFM_Utils")
local say = require("ReaClassical_Announce")

local M = {}

local RIPPLE_PER_TRACK_CMD = 40310
local RIPPLE_ALL_TRACKS_CMD = 40311

local TIMELINE_COLOR_KEYS = { "ts_lane_bg", "marker_lane_bg", "region_lane_bg" }
local AUTOMATION_MODE_COLOR = ColorToNative(60, 90, 120) | 0x1000000

local function set_timeline_color(engaged)
    for _, key in ipairs(TIMELINE_COLOR_KEYS) do
        SetThemeColor(key, engaged and AUTOMATION_MODE_COLOR or -1)
    end
    UpdateTimeline()
end

function M.is_engaged()
    local _, val = GetProjExtState(0, "ReaClassical", "AutomationModeEngaged")
    return val == "1"
end

local function get_source_folder_tracks()
    local sources = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            local _, is_dest = GetSetMediaTrackInfo_String(track, "P_EXT:destination", "", false)
            if is_dest ~= "y" and not special_track_nav.is_special_track(track) then
                sources[#sources + 1] = track
            end
        end
    end
    return sources
end

local function set_source_items_locked(locked)
    for _, folder_track in ipairs(get_source_folder_tracks()) do
        local tracks = { folder_track }
        for _, child in ipairs(xfu.get_folder_children(folder_track)) do
            tracks[#tracks + 1] = child
        end
        for _, track in ipairs(tracks) do
            local n = CountTrackMediaItems(track)
            for i = 0, n - 1 do
                local item = GetTrackMediaItem(track, i)
                SetMediaItemInfo_Value(item, "C_LOCK", locked and 1 or 0)
            end
        end
    end
end

function M.engage()
    if M.is_engaged() then return end

    set_source_items_locked(true)
    if GetToggleCommandState(RIPPLE_ALL_TRACKS_CMD) ~= 1 then
        Main_OnCommand(RIPPLE_ALL_TRACKS_CMD, 0)
    end
    UpdateArrange()
    set_timeline_color(true)

    SetProjExtState(0, "ReaClassical", "AutomationModeEngaged", "1")
    say("Automation mode on")
end

function M.disengage()
    if not M.is_engaged() then return end

    set_source_items_locked(false)
    if GetToggleCommandState(RIPPLE_PER_TRACK_CMD) ~= 1 then
        Main_OnCommand(RIPPLE_PER_TRACK_CMD, 0)
    end
    UpdateArrange()
    set_timeline_color(false)

    SetProjExtState(0, "ReaClassical", "AutomationModeEngaged", "0")
    say("Automation mode off")
end

function M.toggle()
    if M.is_engaged() then
        M.disengage()
    else
        M.engage()
    end
end

function M.ensure_engaged()
    if not M.is_engaged() then
        M.engage()
    end
end

return M
