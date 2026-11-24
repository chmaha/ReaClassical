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

local M = {}

function M.is_talkback_track(track)
    if not track then return false end
    local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:talkback", "", false)
    if state == "y" then return true end
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return name:match("^TALKBACK") ~= nil
end

function M.find()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if M.is_talkback_track(track) then return track end
    end
    return nil
end

function M.set_input(track, input_ch)
    SetMediaTrackInfo_Value(track, "I_RECINPUT", input_ch or -1)
end

function M.get_output(track)
    if GetTrackNumSends(track, 1) == 0 then return nil end
    local dst = math.floor(GetTrackSendInfo_Value(track, 1, 0, "I_DSTCHAN"))
    if dst < 0 then return nil end
    return dst & 1023
end

function M.set_output(track, output_ch)
    for i = GetTrackNumSends(track, 1) - 1, 0, -1 do
        RemoveTrackSend(track, 1, i)
    end
    if output_ch and output_ch >= 0 then
        local send_idx = CreateTrackSend(track, nil)
        SetTrackSendInfo_Value(track, 1, send_idx, "I_SRCCHAN", 1024)
        SetTrackSendInfo_Value(track, 1, send_idx, "I_DSTCHAN", output_ch | 1024)
    end
end

function M.enforce(track)
    GetSetMediaTrackInfo_String(track, "P_EXT:talkback", "y", true)
    GetSetMediaTrackInfo_String(track, "P_NAME", "TALKBACK", true)
    SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
    SetMediaTrackInfo_Value(track, "B_SOLO_DEFEAT", 1)
    SetMediaTrackInfo_Value(track, "I_RECMON", 1)
    SetMediaTrackInfo_Value(track, "I_RECMODE", 2)
    SetMediaTrackInfo_Value(track, "I_RECARM", 1)
    for i = GetTrackNumSends(track, 0) - 1, 0, -1 do
        RemoveTrackSend(track, 0, i)
    end
end

function M.create(input_ch, output_ch)
    local existing = M.find()
    if existing then return existing, false end

    local insert_idx = CountTracks(0)
    InsertTrackAtIndex(insert_idx, false)
    local track = GetTrack(0, insert_idx)

    M.enforce(track)
    M.set_input(track, input_ch)
    M.set_output(track, output_ch)
    SetMediaTrackInfo_Value(track, "B_MUTE", 1)
    SetMediaTrackInfo_Value(track, "D_VOL", 1.0)
    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
    SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
    SetTrackColor(track, require("ReaClassical_Colors_Table").talkback)

    return track, true
end

function M.toggle()
    local track = M.find()
    if not track then return nil end
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") == 1
    if muted then
        M.enforce(track)
    end
    SetMediaTrackInfo_Value(track, "B_MUTE", muted and 0 or 1)
    return muted
end

return M
