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

local M = {}

local SPECIAL_PEXTS = {
    "mixer", "aux", "submix", "roomtone", "rcref", "live", "listenback", "rcmaster", "playback",
}

function M.is_special_track(t)
    if not t then return false, nil end
    for _, pext in ipairs(SPECIAL_PEXTS) do
        local _, v = GetSetMediaTrackInfo_String(t, "P_EXT:" .. pext, "", false)
        if v == "y" then return true, pext end
    end
    return false, nil
end

function M.get_feed_track(track)
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

function M.format_peak(track)
    local peak = -150.0
    local num_chans = math.min(GetMediaTrackInfo_Value(track, "I_NCHAN"), 2)
    for ch = 0, num_chans - 1 do
        local val = Track_GetPeakHoldDB(track, ch, false) * 100
        if val > peak then peak = val end
    end
    if peak <= -150.0 then return "silence" end
    return string.format("%.1f dB", peak)
end

function M.format_mute_solo(track)
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    if muted and soloed then return "muted and soloed" end
    if muted then return "muted" end
    if soloed then return "soloed" end
    return nil
end

function M.announce_special(t, pext)
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
    elseif pext == "playback" then
        label = "playback"
    elseif pext == "rcmaster" then
        label = "RC Master"
    else
        label = name ~= "" and name or pext
    end

    local parts = { label, M.format_peak(t) }
    local mute_solo_info = M.format_mute_solo(t)
    if mute_solo_info then parts[#parts + 1] = mute_solo_info end
    say(table.concat(parts, ", "))
end

function M.announce_folder_track(t, fallback_label)
    local _, name = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
    local label = name ~= "" and name or fallback_label
    local meter_track = M.get_feed_track(t)
    local parts = { label, M.format_peak(meter_track) }
    local mute_solo_info = M.format_mute_solo(meter_track)
    if mute_solo_info then parts[#parts + 1] = mute_solo_info end
    say(table.concat(parts, ", "))
end

function M.apply_solo_for_special(t, pext)
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

function M.clear_solo_for_special(t, pext)
    if pext == "rcref" or pext == "live" then
        Main_OnCommand(40340, 0)
        SetMediaTrackInfo_Value(t, "B_MUTE", 1)
    end
end

function M.ensure_special_visible()
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        for _, pext in ipairs(SPECIAL_PEXTS) do
            local _, v = GetSetMediaTrackInfo_String(t, "P_EXT:" .. pext, "", false)
            if v == "y" then
                if pext ~= "listenback" and pext ~= "playback" then
                    SetMediaTrackInfo_Value(t, "B_SHOWINTCP", 1)
                end
                break
            end
        end
    end
end

function M.enter_special_tracks()
    local current = GetSelectedTrack(0, 0)
    if current and not M.is_special_track(current) then
        local idx = math.floor(GetMediaTrackInfo_Value(current, "IP_TRACKNUMBER") - 1)
        SetProjExtState(0, "ReaClassical", "LastFolderTrackIdx", tostring(idx))
    end

    if APIExists("clara_outputMessage") then
        M.ensure_special_visible()
    end

    local _, sidx_str = GetProjExtState(0, "ReaClassical", "LastSpecialTrackIdx")
    local sidx = tonumber(sidx_str)
    if sidx then
        local t = GetTrack(0, sidx)
        if t then
            local spec, pext = M.is_special_track(t)
            if spec and GetMediaTrackInfo_Value(t, "B_SHOWINTCP") == 1 then
                SetOnlyTrackSelected(t)
                TrackList_AdjustWindows(false)
                M.apply_solo_for_special(t, pext)
                M.announce_special(t, pext)
                return true
            end
        end
    end

    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetMediaTrackInfo_Value(t, "B_SHOWINTCP") == 1 then
            local spec, pext = M.is_special_track(t)
            if spec then
                SetOnlyTrackSelected(t)
                TrackList_AdjustWindows(false)
                M.apply_solo_for_special(t, pext)
                M.announce_special(t, pext)
                return true
            end
        end
    end
    say("No special tracks found")
    return false
end

function M.enter_regular_tracks()
    local current = GetSelectedTrack(0, 0)
    local on_special, pext_type = false, nil
    if current then on_special, pext_type = M.is_special_track(current) end

    if on_special then
        local special_idx = math.floor(GetMediaTrackInfo_Value(current, "IP_TRACKNUMBER") - 1)
        SetProjExtState(0, "ReaClassical", "LastSpecialTrackIdx", tostring(special_idx))
        M.clear_solo_for_special(current, pext_type)
    end

    local _, idx_str = GetProjExtState(0, "ReaClassical", "LastFolderTrackIdx")
    local idx = tonumber(idx_str)
    if idx then
        local t = GetTrack(0, idx)
        if t and not M.is_special_track(t) then
            SetOnlyTrackSelected(t)
            TrackList_AdjustWindows(false)
            SetMediaTrackInfo_Value(t, "I_SOLO", 2)
            M.announce_folder_track(t, "Track " .. (idx + 1))
            return true
        end
    end

    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetMediaTrackInfo_Value(t, "B_SHOWINTCP") == 1 and not M.is_special_track(t) then
            SetOnlyTrackSelected(t)
            TrackList_AdjustWindows(false)
            SetMediaTrackInfo_Value(t, "I_SOLO", 2)
            M.announce_folder_track(t, "Track " .. (i + 1))
            return true
        end
    end
    say("No folder tracks found")
    return false
end

return M
