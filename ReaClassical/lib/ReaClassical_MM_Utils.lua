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
local track_rename = require("ReaClassical_Track_Rename")

local M = {}

local SPECIAL_PEXTS = {
    "mixer", "aux", "submix", "roomtone", "rcref", "live", "listenback", "rcmaster", "playback",
}

local FIXED_TYPES = {
    rcmaster = true, roomtone = true, live = true, listenback = true, playback = true,
}

local TYPE_LABELS = {
    mixer = "Mixer", rcmaster = "RCMASTER", aux = "Aux", submix = "Submix",
    reference = "Reference", roomtone = "RoomTone", live = "Live",
    listenback = "Listenback", playback = "Playback",
}

function M.is_special_track(t)
    if not t then return false end
    for _, pext in ipairs(SPECIAL_PEXTS) do
        local _, v = GetSetMediaTrackInfo_String(t, "P_EXT:" .. pext, "", false)
        if v == "y" then return true end
    end
    return false
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

function M.get_special_tracks_list()
    local list = {}
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        local _, spare_state = GetSetMediaTrackInfo_String(t, "P_EXT:spare", "", false)
        if M.is_special_track(t) and spare_state ~= "y" then
            list[#list + 1] = t
        end
    end
    return list
end

function M.find_track_by_guid(guid)
    if not guid or guid == "" then return nil end
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        local _, tguid = GetSetMediaTrackInfo_String(t, "GUID", "", false)
        if tguid == guid then return t end
    end
    return nil
end

function M.set_current_target(track)
    local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
    SetExtState("ReaClassical", "MixerModeTargetGUID", guid, false)
end

function M.get_current_target()
    local guid = GetExtState("ReaClassical", "MixerModeTargetGUID")
    if guid ~= "" then
        local t = M.find_track_by_guid(guid)
        if t and M.is_special_track(t) then return t end
    end

    local fallback = nil
    local selected = GetSelectedTrack(0, 0)
    if selected then
        if M.is_special_track(selected) then
            fallback = selected
        else
            local fed = M.get_feed_track(selected)
            if M.is_special_track(fed) then fallback = fed end
        end
    end
    if not fallback then
        fallback = M.get_special_tracks_list()[1]
    end
    if fallback then M.set_current_target(fallback) end
    return fallback
end

local function classify(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    name = name or ""
    local checks = {
        { "mixer",      "mixer" },
        { "aux",        "aux" },
        { "submix",     "submix" },
        { "roomtone",   "roomtone" },
        { "rcref",      "reference" },
        { "live",       "live" },
        { "listenback", "listenback" },
        { "rcmaster",   "rcmaster" },
        { "playback",   "playback" },
    }
    for _, c in ipairs(checks) do
        local _, v = GetSetMediaTrackInfo_String(track, "P_EXT:" .. c[1], "", false)
        if v == "y" then return c[2], name end
    end
    return nil, name
end

function M.get_type(track)
    return (classify(track))
end

function M.is_routable(track)
    local ptype = M.get_type(track)
    return ptype == "mixer" or ptype == "aux" or ptype == "submix"
end

local function mixer_position(track)
    local mixer_n = 0
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(t, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            mixer_n = mixer_n + 1
            if t == track then return mixer_n end
        end
    end
    return mixer_n
end

function M.get_label(track)
    local ptype, name = classify(track)
    if not ptype then
        return name ~= "" and name or "Track " .. math.floor(GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
    end
    if FIXED_TYPES[ptype] then
        return TYPE_LABELS[ptype]
    end
    local label
    if ptype == "mixer" then
        label = track_rename.get_mixer_base_name(track)
    elseif ptype == "aux" or ptype == "submix" then
        label = name:gsub("^[@#]:?", ""):gsub("%-$", "")
    elseif ptype == "reference" then
        label = name:gsub("^REF:?", ""):gsub("%-$", "")
    else
        label = ""
    end
    label = label ~= "" and label or "unnamed"
    if ptype == "mixer" then
        return mixer_position(track) .. " " .. TYPE_LABELS[ptype] .. " " .. label
    end
    return TYPE_LABELS[ptype] .. " " .. label
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

function M.status_suffix(track)
    local bits = {}
    if GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then bits[#bits + 1] = "Soloed" end
    if GetMediaTrackInfo_Value(track, "B_MUTE") > 0 then bits[#bits + 1] = "Muted" end
    if #bits == 0 then return "" end
    return ", " .. table.concat(bits, ", ")
end

local function get_input_source_track(mixer_track)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        for s = 0, GetTrackNumSends(t, 0) - 1 do
            if GetTrackSendInfo_Value(t, 0, s, "P_DESTTRACK") == mixer_track then
                return t
            end
        end
    end
    return nil
end

local function input_status_text(mixer_track)
    local source = get_input_source_track(mixer_track) or mixer_track
    local rec_input = math.floor(GetMediaTrackInfo_Value(source, "I_RECINPUT"))
    if rec_input == -1 or rec_input == 4096 then return "no input" end
    if (rec_input & 4096) ~= 0 and rec_input > 4096 then return "MIDI input" end
    local is_stereo = (rec_input & 1024) ~= 0
    local base_ch = is_stereo and (rec_input - 1024) or rec_input
    local hw_name1 = GetInputChannelName(base_ch)
    if is_stereo then
        local hw_name2 = GetInputChannelName(base_ch + 1)
        if hw_name1 and hw_name1 ~= "" and hw_name2 and hw_name2 ~= "" then
            return string.format("%s and %s, stereo", hw_name1, hw_name2)
        end
        return string.format("input %d and %d, stereo", base_ch + 1, base_ch + 2)
    end
    if hw_name1 and hw_name1 ~= "" then
        return string.format("%s, mono", hw_name1)
    end
    return string.format("input %d, mono", base_ch + 1)
end

M.input_status_text = input_status_text

function M.full_status_text(track)
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    local phase = GetMediaTrackInfo_Value(track, "B_PHASE") == 1
    local pan = M.format_pan(GetMediaTrackInfo_Value(track, "D_PAN"))
    local db = M.linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL"))

    local ptype = classify(track)
    local rcm_part = ""
    if ptype == "mixer" or ptype == "aux" or ptype == "submix" then
        local _, disconnect_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
        local connected = disconnect_state ~= "y"
        rcm_part = " RCMASTER " .. (connected and "connected" or "disconnected") .. "."
    end
    local input_part = ""
    if ptype == "mixer" then
        input_part = " " .. input_status_text(track):gsub("^%l", string.upper) .. "."
    end

    return string.format("%s. Solo %s. Mute %s. Polarity %s. Pan %s. Fader %.1f dB.%s%s",
        M.get_label(track), soloed and "on" or "off", muted and "on" or "off",
        phase and "inverted" or "normal", pan, db, input_part, rcm_part)
end

function M.clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

function M.format_pan(pan_val)
    if math.abs(pan_val) < 0.01 then
        return "center"
    elseif pan_val < 0 then
        return tostring(math.floor(-pan_val * 100 + 0.5)) .. " left"
    else
        return tostring(math.floor(pan_val * 100 + 0.5)) .. " right"
    end
end

function M.linear_to_db(val)
    if val <= 0.0000000298023223876953125 then
        return -150.0
    end
    return 20 * math.log(val, 10)
end

function M.db_to_linear(db)
    if db <= -150 then
        return 0.0
    end
    return 10 ^ (db / 20)
end

function M.modifier_factor()
    local _, stored = GetProjExtState(0, "ReaClassical", "ModifierFactor")
    return tonumber(stored) or 5
end

return M
