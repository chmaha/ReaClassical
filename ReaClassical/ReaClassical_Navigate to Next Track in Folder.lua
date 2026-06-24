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
local humanize_track_name = require("ReaClassical_Track_Naming")
local say = require("ReaClassical_Announce")

local main, is_special_track, get_folder_parent, get_folder_tracks
local format_peak, format_mute_solo, announce_track, get_feed_track

---------------------------------------------------------------------

---------------------------------------------------------------------

function get_feed_track(track)
    -- Each source/folder track sends to its own dedicated channel-strip
    -- track tagged P_EXT:mixer ("M:<name>", see create_single_mixer in the
    -- Workflow scripts). That's the track Meterbridge displays a peak for.
    local num_sends = GetTrackNumSends(track, 0)
    for i = 0, num_sends - 1 do
        local dest = GetTrackSendInfo_Value(track, 0, i, "P_DESTTRACK")
        if dest and ValidatePtr(dest, "MediaTrack*") then
            local _, mixer_state = GetSetMediaTrackInfo_String(dest, "P_EXT:mixer", "", false)
            if mixer_state == "y" then return dest end
        end
    end
    return track
end

---------------------------------------------------------------------

function format_peak(track)
    -- Matches ReaClassical_Meterbridge.lua's numeric display: peak hold,
    -- not cleared (clearing would also reset the visible meter's hold line).
    local peak = -150.0
    local num_chans = math.min(GetMediaTrackInfo_Value(track, "I_NCHAN"), 2)
    for ch = 0, num_chans - 1 do
        local val = Track_GetPeakHoldDB(track, ch, false) * 100
        if val > peak then peak = val end
    end
    if peak <= -150.0 then return "silence" end
    return string.format("%.1f dB", peak)
end

---------------------------------------------------------------------

function format_mute_solo(track)
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    if muted and soloed then return "muted and soloed" end
    if muted then return "muted" end
    if soloed then return "soloed" end
    return nil
end

---------------------------------------------------------------------

-- position is the track's 1-based slot within its folder (parent track is
-- 1, children follow), so "track 9" in an 8-track-per-folder project reads
-- as "1" once it's the first track of the next folder.
function announce_track(track, position)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local meter_track = get_feed_track(track)
    local label = position and (position .. " " .. humanize_track_name(name)) or humanize_track_name(name)
    local parts = { label, format_peak(meter_track) }
    local mute_solo_info = format_mute_solo(meter_track)
    if mute_solo_info then parts[#parts + 1] = mute_solo_info end
    say(table.concat(parts, ", "))
end

---------------------------------------------------------------------

function is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

---------------------------------------------------------------------

function get_folder_parent(track)
    if not track then return nil, nil end
    local idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        if not is_special_track(track) then
            return track, idx
        else
            return nil, nil
        end
    end
    for i = idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        local d = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
        if d == 1 then
            if not is_special_track(t) then
                return t, i
            else
                return nil, nil
            end
        end
    end
    return nil, nil
end

---------------------------------------------------------------------

function get_folder_tracks(parent_track, parent_idx)
    local tracks = { { track = parent_track, idx = parent_idx } }
    local num_tracks = CountTracks(0)
    local j = parent_idx + 1
    local depth = 1
    while j < num_tracks and depth > 0 do
        local ch = GetTrack(0, j)
        local d = GetMediaTrackInfo_Value(ch, "I_FOLDERDEPTH")
        if not is_special_track(ch) then
            table.insert(tracks, { track = ch, idx = j })
        end
        depth = depth + d
        j = j + 1
    end
    return tracks
end

---------------------------------------------------------------------

function main()
    local selected = GetSelectedTrack(0, 0)
    if not selected then
        say("No track selected.")
        return
    end

    local parent, parent_idx = get_folder_parent(selected)
    if not parent then
        say("Not in a ReaClassical folder.")
        return
    end

    local tracks = get_folder_tracks(parent, parent_idx)
    local current_pos = nil
    for i, t in ipairs(tracks) do
        if t.track == selected then
            current_pos = i
            break
        end
    end

    if not current_pos then
        say("Not in a ReaClassical folder.")
        return
    end

    if current_pos >= #tracks then
        say("At bottom of folder.")
        return
    end

    local next_track = tracks[current_pos + 1]
    SetOnlyTrackSelected(next_track.track)
    TrackList_AdjustWindows(false)
    announce_track(next_track.track, current_pos + 1)
end

---------------------------------------------------------------------

main()
