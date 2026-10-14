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
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")

local main, solo
local format_peak, format_input, format_mute_solo, announce_track, get_feed_track

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
if input ~= "" then
    local t = {}
    for entry in input:gmatch('([^,]+)') do t[#t + 1] = entry end
    if t[7] then ref_is_guide = tonumber(t[7]) or 0 end
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

function format_mute_solo(track)
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    if muted and soloed then return "muted and soloed" end
    if muted then return "muted" end
    if soloed then return "soloed" end
    return nil
end

function announce_track(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local meter_track = get_feed_track(track)
    local parts = { humanize_track_name(name), format_peak(meter_track) }
    local input_info = format_input(track)
    if input_info then parts[#parts + 1] = input_info end
    local mute_solo_info = format_mute_solo(meter_track)
    if mute_solo_info then parts[#parts + 1] = mute_solo_info end
    say(table.concat(parts, ", "))
end

function solo(cache)
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

function select_nearest_item_to_cursor(track)
    local cursor = GetCursorPosition()
    local best_item, best_dist
    for i = 0, CountTrackMediaItems(track) - 1 do
        local item = GetTrackMediaItem(track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local dist
        if cursor >= pos and cursor <= pos + len then
            dist = 0
        else
            dist = math.min(math.abs(cursor - pos), math.abs(cursor - (pos + len)))
        end
        if not best_dist or dist < best_dist then
            best_dist = dist
            best_item = item
        end
    end
    if best_item then
        SetMediaItemSelected(best_item, true)
        Main_OnCommand(40034, 0)
    end
end

function main()
    local cache = track_scan.build()
    local folders = cache.folders
    if #folders == 0 then
        say("No ReaClassical folders found.")
        return
    end

    local selected = GetSelectedTrack(0, 0)
    local current_pos = nil

    if selected then
        local parent = cache.parent[selected]
        if parent then
            for i, f in ipairs(folders) do
                if f.track == parent then
                    current_pos = i
                    break
                end
            end
        end
    end

    local next_pos = current_pos and (current_pos + 1) or 1

    if next_pos > #folders then
        say("At bottom of project.")
        return
    end

    local next_folder = folders[next_pos]
    PreventUIRefresh(1)
    SetOnlyTrackSelected(next_folder.track)
    solo(cache)
    Main_OnCommand(40289, 0)
    select_nearest_item_to_cursor(next_folder.track)
    PreventUIRefresh(-1)
    TrackList_AdjustWindows(false)
    UpdateArrange()
    UpdateTimeline()
    announce_track(next_folder.track)
end

main()
