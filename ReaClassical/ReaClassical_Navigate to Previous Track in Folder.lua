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
local humanize_track_name = require("ReaClassical_Track_Naming")
local say = require("ReaClassical_Announce")
local folder_scan = require("ReaClassical_Folder_Scan")
local spare_track = require("ReaClassical_Spare_Track")

local main
local format_peak, format_mute_solo, announce_track, get_feed_track
local get_visible_special_tracks, announce_special_track, apply_solo_for_special

local SPECIAL_PEXTS = { "mixer", "aux", "submix", "roomtone", "rcref", "live", "listenback", "rcmaster", "playback" }

function get_visible_special_tracks()
    local list = {}
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetMediaTrackInfo_Value(t, "B_SHOWINTCP") == 1 then
            for _, pext in ipairs(SPECIAL_PEXTS) do
                local _, v = GetSetMediaTrackInfo_String(t, "P_EXT:" .. pext, "", false)
                if v == "y" then
                    list[#list + 1] = { track = t, pext = pext }
                    break
                end
            end
        end
    end
    return list
end

function announce_special_track(t, pext)
    local _, name = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
    local label
    if pext == "mixer" then
        local s = name:match("^M:(.+)") or ""
        label = s ~= "" and ("mixer " .. s) or "mixer"
    elseif pext == "aux" then
        local s = name:match("^@(.+)") or ""
        label = s ~= "" and (s .. " auxiliary") or "auxiliary"
    elseif pext == "submix" then
        local s = name:match("^#(.+)") or ""
        label = s ~= "" and (s .. " submix") or "submix"
    elseif pext == "rcref" then
        local s = name:match("^REF:(.+)") or ""
        label = s ~= "" and (s .. " reference") or "reference"
    elseif pext == "live" then
        label = "live"
    elseif pext == "roomtone" then
        label = "room tone"
    elseif pext == "listenback" then
        label = "listenback"
    elseif pext == "rcmaster" then
        label = "RC Master"
    else
        label = name ~= "" and name or pext
    end

    local parts = { label, format_peak(t) }
    local mute_solo_info = format_mute_solo(t)
    if mute_solo_info then parts[#parts + 1] = mute_solo_info end
    say(table.concat(parts, ", "))
end

function apply_solo_for_special(t, pext)
    if pext == "rcref" then
        Main_OnCommand(40340, 0)
        SetMediaTrackInfo_Value(t, "B_MUTE", 0)
        SetMediaTrackInfo_Value(t, "I_SOLO", 1)
    elseif pext == "live" then
        Main_OnCommand(40340, 0)
        SetMediaTrackInfo_Value(t, "B_MUTE", 0)
        SetMediaTrackInfo_Value(t, "I_SOLO", 2)
    end
end

local function clear_solo_if_special(t, pext)
    if pext == "rcref" or pext == "live" then
        Main_OnCommand(40340, 0)
        SetMediaTrackInfo_Value(t, "B_MUTE", 1)
    end
end

function get_feed_track(track)
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

function format_peak(track)
    local peak = -150.0
    local num_chans = math.min(GetMediaTrackInfo_Value(track, "I_NCHAN"), 2)
    for ch = 0, num_chans - 1 do
        local val = Track_GetPeakHoldDB(track, ch, false) * 100
        if val > peak then peak = val end
    end
    if peak <= -150.0 then return "silence" end
    return string.format("%.1f dB", peak)
end

function format_mute_solo(track)
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    if muted and soloed then return "muted and soloed" end
    if muted then return "muted" end
    if soloed then return "soloed" end
    return nil
end

function announce_track(track, position)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local meter_track = get_feed_track(track)
    local label = position and (position .. " " .. humanize_track_name(name)) or humanize_track_name(name)
    local parts = { label, format_peak(meter_track) }
    local mute_solo_info = format_mute_solo(meter_track)
    if mute_solo_info then parts[#parts + 1] = mute_solo_info end
    say(table.concat(parts, ", "))
end

function main()
    local selected = GetSelectedTrack(0, 0)
    if not selected then
        say("No track selected.")
        return
    end

    if folder_scan.is_special_track(selected) then
        local specials = get_visible_special_tracks()
        local current_pos = nil
        for i, s in ipairs(specials) do
            if s.track == selected then current_pos = i break end
        end
        if not current_pos then
            say("Not in a ReaClassical folder.")
            return
        end
        if current_pos <= 1 then
            say("First special track")
            return
        end
        clear_solo_if_special(specials[current_pos].track, specials[current_pos].pext)
        local prev_s = specials[current_pos - 1]
        SetOnlyTrackSelected(prev_s.track)
        TrackList_AdjustWindows(false)
        apply_solo_for_special(prev_s.track, prev_s.pext)
        announce_special_track(prev_s.track, prev_s.pext)
        return
    end

    local parent, parent_idx = folder_scan.get_folder_parent(selected)
    if not parent then
        say("Not in a ReaClassical folder.")
        return
    end

    if spare_track.is_spare_folder(parent) then
        dofile(script_path .. "ReaClassical_Navigate to Previous Folder.lua")
        return
    end

    local tracks = folder_scan.get_folder_tracks(parent, parent_idx)
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

    if current_pos <= 1 then
        say("At top of folder.")
        return
    end

    local prev_track = tracks[current_pos - 1]
    SetOnlyTrackSelected(prev_track.track)
    TrackList_AdjustWindows(false)
    announce_track(prev_track.track, current_pos - 1)
end

main()
