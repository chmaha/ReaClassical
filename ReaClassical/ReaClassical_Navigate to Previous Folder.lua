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

local main, is_special_track, get_folder_parent, get_rc_folders, solo
local format_peak, format_input, format_mute_solo, announce_track, get_feed_track

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
if input ~= "" then
    local t = {}
    for entry in input:gmatch('([^,]+)') do t[#t + 1] = entry end
    if t[7] then ref_is_guide = tonumber(t[7]) or 0 end
end

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

function format_mute_solo(track)
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    if muted and soloed then return "muted and soloed" end
    if muted then return "muted" end
    if soloed then return "soloed" end
    return nil
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

function is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }
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
        local _, playback_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
            or ref_state == "y" or listenback_state == "y" or playback_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or listenback_state == "y" or rcmaster_state == "y" or playback_state == "y") then
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

-- Selects the item on track whose span is closest to the edit cursor
-- (0 if the cursor falls inside it), so switching folders lands on
-- something relevant instead of leaving the previous folder's items
-- selected or none at all.
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
    end
end

---------------------------------------------------------------------

function main()
    local folders = get_rc_folders()
    if #folders == 0 then
        say("No ReaClassical folders found.")
        return
    end

    local selected = GetSelectedTrack(0, 0)
    local current_pos = nil

    if selected then
        local parent = get_folder_parent(selected)
        if parent then
            for i, f in ipairs(folders) do
                if f.track == parent then
                    current_pos = i
                    break
                end
            end
        end
    end

    local prev_pos = current_pos and (current_pos - 1) or #folders

    if prev_pos < 1 then
        say("At top of project.")
        return
    end

    local prev_folder = folders[prev_pos]
    PreventUIRefresh(1)
    SetOnlyTrackSelected(prev_folder.track)
    solo()
    Main_OnCommand(40289, 0) -- Item: Unselect all items
    select_nearest_item_to_cursor(prev_folder.track)
    PreventUIRefresh(-1)
    TrackList_AdjustWindows(false)
    UpdateArrange()
    UpdateTimeline()
    announce_track(prev_folder.track)
end

---------------------------------------------------------------------

main()
