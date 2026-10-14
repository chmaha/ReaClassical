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
local say = require("ReaClassical_Announce")
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")
local enum_project_markers = require("ReaClassical_Marker_Enum")

local main, solo, announce_marker_at

function announce_marker_at(pos)
    local num_markers = GetNumRegionsOrMarkers(0)
    for idx = 0, num_markers - 1 do
        local retval, isrgn, mpos, _, name, num = enum_project_markers(0, idx)
        if retval and not isrgn and math.abs(mpos - pos) < 1e-6 then
            say(num .. ": " .. (name ~= "" and name or "(unnamed)"))
            return
        end
    end
end

function main()
    local playPos = GetPlayPosition()
    local editPos = GetCursorPosition()
    local sel_track = GetSelectedTrack(0, 0)
    local start_track_idx = sel_track and math.floor(GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER")) or 1
    local num_tracks = CountTracks(0)

    if GetPlayState() & 1 == 1 and playPos - editPos > 2 then
        SetEditCurPos(editPos, true, true)
        return
    end

    local track_markers = {}
    local num_markers = GetNumRegionsOrMarkers(0)
    for i = 0, num_markers - 1 do
        local _, isrgn, pos, _, name, idx = enum_project_markers(0, i)
        if not isrgn then
            local track_num = tonumber(name:match("^(%d+):"))
            if track_num and name:match("SAI") then
                track_markers[track_num] = track_markers[track_num] or {}
                table.insert(track_markers[track_num], { pos = pos, idx = idx, name = name })
            end
        end
    end

    if next(track_markers) == nil then
        Main_OnCommand(40289, 0)
        Main_OnCommand(40172, 0)
        announce_marker_at(GetCursorPosition())
        return
    end

    for offset = 0, num_tracks - 1 do
        local track_idx = ((start_track_idx - offset - 1 + num_tracks) % num_tracks) + 1
        local markers = track_markers[track_idx]
        if markers then
            table.sort(markers, function(a, b) return a.pos > b.pos end)
            for _, marker in ipairs(markers) do
                if offset > 0 or marker.pos < editPos - 1e-9 then
                    local track = GetTrack(0, track_idx - 1)
                    SetEditCurPos(marker.pos, true, true)
                    Main_OnCommand(40297, 0)
                    SetTrackSelected(track, true)
                    solo()
                    say(marker.idx .. ": " .. marker.name)
                    return
                end
            end
        end
    end
end

function solo()
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
            elseif ref_is_guide == 1 then
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

main()
