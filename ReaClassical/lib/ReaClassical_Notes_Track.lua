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

local lib_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")

local M = {}

function M.is_notes_track(track)
    if not track then return false end
    local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:notes", "", false)
    return state == "y"
end

function M.find()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if M.is_notes_track(track) then return track end
    end
    return nil
end

local function strip_audio_paths(track)
    for i = GetTrackNumSends(track, 0) - 1, 0, -1 do RemoveTrackSend(track, 0, i) end
    for i = GetTrackNumSends(track, 1) - 1, 0, -1 do RemoveTrackSend(track, 1, i) end
    for i = GetTrackNumSends(track, -1) - 1, 0, -1 do RemoveTrackSend(track, -1, i) end
    if GetMediaTrackInfo_Value(track, "B_MAINSEND") ~= 0 then SetMediaTrackInfo_Value(track, "B_MAINSEND", 0) end
    if GetMediaTrackInfo_Value(track, "I_RECARM") ~= 0 then SetMediaTrackInfo_Value(track, "I_RECARM", 0) end
    if GetMediaTrackInfo_Value(track, "I_RECINPUT") ~= -1 then SetMediaTrackInfo_Value(track, "I_RECINPUT", -1) end
    if GetMediaTrackInfo_Value(track, "B_SHOWINMIXER") ~= 0 then SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0) end
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") ~= 0 then SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", 0) end
end

function M.create()
    local existing = M.find()
    if existing then return existing end

    local insert_idx = CountTracks(0)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, rcm_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if rcm_state == "y" or name:match("^RCMASTER") then
            insert_idx = i + 1
            break
        end
    end

    InsertTrackAtIndex(insert_idx, false)
    local track = GetTrack(0, insert_idx)
    GetSetMediaTrackInfo_String(track, "P_EXT:notes", "y", true)
    GetSetMediaTrackInfo_String(track, "P_NAME", "NOTES", true)
    SetTrackColor(track, dofile(lib_path .. "ReaClassical_Colors_Table.lua").notes)
    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
    strip_audio_paths(track)
    return track
end

function M.enforce(show_message)
    local to_remove = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if M.is_notes_track(track) then
            strip_audio_paths(track)
            for j = 0, CountTrackMediaItems(track) - 1 do
                local item = GetTrackMediaItem(track, j)
                if CountTakes(item) > 0 then
                    to_remove[#to_remove + 1] = { track = track, item = item }
                end
            end
        end
    end
    local removed = #to_remove
    if removed > 0 then
        Undo_BeginBlock()
        for _, entry in ipairs(to_remove) do
            DeleteTrackMediaItem(entry.track, entry.item)
        end
        Undo_EndBlock("Remove audio items from NOTES track", -1)
        UpdateArrange()
        if show_message then
            MB(string.format("%d item%s containing audio or MIDI %s removed from the NOTES track.\n" ..
                "The NOTES track is for empty note items only.",
                removed, removed == 1 and "" or "s", removed == 1 and "was" or "were"), "ReaClassical", 0)
        end
    end
    return removed
end

return M
