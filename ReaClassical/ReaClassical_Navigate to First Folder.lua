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

local main, is_special_track, get_rc_folders, solo, say
local format_peak, format_input, announce_track, get_feed_track

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
if input ~= "" then
    local t = {}
    for entry in input:gmatch('([^,]+)') do t[#t + 1] = entry end
    if t[7] then ref_is_guide = tonumber(t[7]) or 0 end
end

---------------------------------------------------------------------

function say(msg)
    if osara_outputMessage then
        osara_outputMessage(tostring(msg))
    end
end

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
    return string.format("peak %.1f dB", peak)
end

---------------------------------------------------------------------

function format_input(track)
    if GetMediaTrackInfo_Value(track, "I_RECARM") ~= 1 then return nil end
    local rec_input = GetMediaTrackInfo_Value(track, "I_RECINPUT")
    if rec_input < 0 then return "armed, no input" end
    if rec_input & 4096 ~= 0 then
        local midi_chan = rec_input & 31
        return midi_chan == 0 and "armed, MIDI all channels" or ("armed, MIDI channel " .. midi_chan)
    end
    local chan = (rec_input & 1023) + 1
    if rec_input & 1024 ~= 0 then
        return "armed, inputs " .. chan .. " and " .. (chan + 1)
    end
    return "armed, input " .. chan
end

---------------------------------------------------------------------

function announce_track(track, label)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local meter_track = get_feed_track(track)
    local parts = { label .. ": " .. humanize_track_name(name), format_peak(meter_track) }
    local input_info = format_input(track)
    if input_info then parts[#parts + 1] = input_info end
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

function get_rc_folders()
    local folders = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 and not is_special_track(track) then
            table.insert(folders, { track = track, idx = i })
        end
    end
    return folders
end

function solo()
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, lb_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        if lb_state == "y" then
            SetMediaTrackInfo_Value(track, "I_RECARM", 1)
        end
    end
    local selected_track = GetSelectedTrack(0, 0)
    local parent = selected_track and GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH") or 0

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
            or ref_state == "y" or listenback_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or listenback_state == "y" or rcmaster_state == "y") then
            if IsTrackSelected(track) and parent ~= 1 then
                SetMediaTrackInfo_Value(track, "I_SOLO", 2)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if rt_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if ref_state == "y" then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0) -- unsolo all tracks
                mute_state = 0
                solo_state = 1
            elseif ref_is_guide == 1 then
                mute_state = 0
                solo_state = 0
            end

            SetMediaTrackInfo_Value(track, "B_MUTE", mute_state)
            SetMediaTrackInfo_Value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

function main()
    local folders = get_rc_folders()
    if #folders == 0 then
        say("No ReaClassical folders found.")
        return
    end

    local first_folder = folders[1]
    PreventUIRefresh(1)
    SetOnlyTrackSelected(first_folder.track)
    solo()
    PreventUIRefresh(-1)
    TrackList_AdjustWindows(false)
    UpdateArrange()
    UpdateTimeline()
    announce_track(first_folder.track, "Folder")
end

---------------------------------------------------------------------

main()
