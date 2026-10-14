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
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")

local M = {}

local function ref_is_guide()
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input == "" then return false end
    local i = 0
    for entry in input:gmatch('([^,]+)') do
        i = i + 1
        if i == 7 then return (tonumber(entry) or 0) == 1 end
    end
    return false
end

function M.set_active(folder_track)
    if not folder_track then return end

    for i = 0, CountTracks(0) - 1 do
        SetTrackSelected(GetTrack(0, i), false)
    end
    SetTrackSelected(folder_track, true)

    local guide = ref_is_guide()
    local cache = track_scan.build()
    local set_track_value = track_write.set_track_value
    local set_send_value = track_write.set_send_value

    Main_OnCommand(40491, 0)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if cache.tags[track].listenback then
            set_track_value(track, "I_RECARM", 1)
        end
    end

    local selected_track = GetSelectedTrack(0, 0)
    local parent = selected_track and GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH") or 0

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local t = cache.tags[track]
        local mixer_state = t.mixer
        local aux_state = t.aux
        local submix_state = t.submix
        local rt_state = t.roomtone
        local ref_state = t.rcref
        local listenback_state = t.listenback
        local rcmaster_state = t.rcmaster
        local playback_state = t.playback

        if mixer_state or aux_state or submix_state or rt_state
            or ref_state or listenback_state or playback_state then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                set_send_value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state or aux_state or submix_state or rt_state
                or ref_state or listenback_state or rcmaster_state or playback_state) then
            if IsTrackSelected(track) and parent ~= 1 then
                set_track_value(track, "I_SOLO", 2)
                set_track_value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                set_track_value(track, "I_SOLO", 0)
                set_track_value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                set_track_value(track, "B_MUTE", 1)
                set_track_value(track, "I_SOLO", 0)
            else
                set_track_value(track, "B_MUTE", 0)
                set_track_value(track, "I_SOLO", 0)
            end
        end

        if rt_state then
            if IsTrackSelected(track) then
                set_track_value(track, "B_MUTE", 0)
                set_track_value(track, "I_SOLO", 0)
            end
        end

        if ref_state then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0)
                mute_state = 0
                solo_state = 1
            elseif guide then
                mute_state = 0
                solo_state = 0
            end

            set_track_value(track, "B_MUTE", mute_state)
            set_track_value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state then
            set_track_value(track, "B_MUTE", 0)
            set_track_value(track, "I_SOLO", 0)
        end
    end
end

return M
