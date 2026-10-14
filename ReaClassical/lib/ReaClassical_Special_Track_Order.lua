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

local function ext(track, key)
    local _, value = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
    return value
end

local function classify(track)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if name:match("^RCMASTER") or ext(track, "rcmaster") == "y" then
        return "rcmaster"
    elseif ext(track, "live") == "y" or name:match("^LIVE") then
        return "live"
    elseif ext(track, "rcref") == "y" or name:match("^REF") then
        return "ref"
    elseif ext(track, "mixer") == "y" then
        return "mixer"
    elseif ext(track, "aux") == "y" or name:match("^@") then
        return "aux"
    elseif ext(track, "submix") == "y" or name:match("^#") then
        return "submix"
    elseif ext(track, "roomtone") == "y" or name:match("^RoomTone") then
        return "roomtone"
    elseif ext(track, "listenback") == "y" or name:match("^LISTENBACK") then
        return "listenback"
    elseif ext(track, "playback") == "y" or name:match("^PLAYBACK") then
        return "playback"
    end
    return nil
end

function M.get_routing_tracks()
    local list = {}
    local counts = { aux = 0, submix = 0 }
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local kind = classify(track)
        if kind == "aux" or kind == "submix" then
            counts[kind] = counts[kind] + 1
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            local display = name:gsub("^[@#]:?", ""):gsub("%-$", "")
            list[#list + 1] = { track = track, type = kind, number = counts[kind], name = display }
        end
    end
    return list
end

function M.reorder()
    local num_tracks = CountTracks(0)
    if num_tracks == 0 then return end

    local rcmaster_track = nil
    local m_tracks, routing_tracks, roomtone_tracks = {}, {}, {}
    local live_tracks, ref_tracks, listenback_tracks, playback_tracks = {}, {}, {}, {}

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local kind = classify(track)
        if kind == "rcmaster" then
            rcmaster_track = track
        elseif kind == "live" then
            live_tracks[#live_tracks + 1] = track
        elseif kind == "ref" then
            ref_tracks[#ref_tracks + 1] = track
        elseif kind == "mixer" then
            m_tracks[#m_tracks + 1] = track
        elseif kind == "aux" or kind == "submix" then
            routing_tracks[#routing_tracks + 1] = track
        elseif kind == "roomtone" then
            roomtone_tracks[#roomtone_tracks + 1] = track
        elseif kind == "listenback" then
            listenback_tracks[#listenback_tracks + 1] = track
        elseif kind == "playback" then
            playback_tracks[#playback_tracks + 1] = track
        end
    end

    local function select_and_reorder(tracks)
        if #tracks == 0 then return end
        Main_OnCommand(40297, 0)
        for _, t in ipairs(tracks) do SetTrackSelected(t, true) end
        local index = rcmaster_track and GetMediaTrackInfo_Value(rcmaster_track, "IP_TRACKNUMBER") - 1 or 0
        ReorderSelectedTracks(index, 0)
        Main_OnCommand(40297, 0)
    end

    select_and_reorder(m_tracks)
    select_and_reorder(routing_tracks)
    select_and_reorder(roomtone_tracks)

    if rcmaster_track then
        Main_OnCommand(40297, 0)
        for _, t in ipairs(live_tracks) do SetTrackSelected(t, true) end
        local live_index = GetMediaTrackInfo_Value(rcmaster_track, "IP_TRACKNUMBER")
        ReorderSelectedTracks(live_index, 0)
        Main_OnCommand(40297, 0)
    else
        local start_index = #m_tracks + #routing_tracks + #roomtone_tracks
        Main_OnCommand(40297, 0)
        for _, t in ipairs(live_tracks) do SetTrackSelected(t, true) end
        ReorderSelectedTracks(start_index, 0)
        Main_OnCommand(40297, 0)
    end

    Main_OnCommand(40297, 0)
    for _, t in ipairs(ref_tracks) do SetTrackSelected(t, true) end
    ReorderSelectedTracks(CountTracks(0), 0)
    Main_OnCommand(40297, 0)

    Main_OnCommand(40297, 0)
    for _, t in ipairs(listenback_tracks) do SetTrackSelected(t, true) end
    ReorderSelectedTracks(CountTracks(0), 0)
    Main_OnCommand(40297, 0)

    Main_OnCommand(40297, 0)
    for _, t in ipairs(playback_tracks) do SetTrackSelected(t, true) end
    ReorderSelectedTracks(CountTracks(0), 0)
    Main_OnCommand(40297, 0)

    if APIExists("clara_outputMessage") then
        local visible_groups = { m_tracks, routing_tracks, roomtone_tracks,
                                 live_tracks, ref_tracks }
        for _, group in ipairs(visible_groups) do
            for _, t in ipairs(group) do
                SetMediaTrackInfo_Value(t, "B_SHOWINTCP", 1)
            end
        end
    end
end

function M.move_routing_track(track, delta)
    local list = M.get_routing_tracks()
    local pos
    for i, info in ipairs(list) do
        if info.track == track then pos = i break end
    end
    if not pos then return false, "not_found" end

    local target = pos + delta
    if target < 1 then return false, "top" end
    if target > #list then return false, "bottom" end

    local neighbour = list[target].track
    local neighbour_idx = GetMediaTrackInfo_Value(neighbour, "IP_TRACKNUMBER") - 1

    local saved = {}
    for i = 0, CountSelectedTracks(0) - 1 do
        saved[#saved + 1] = GetSelectedTrack(0, i)
    end

    Main_OnCommand(40297, 0)
    SetTrackSelected(track, true)
    ReorderSelectedTracks(delta < 0 and neighbour_idx or neighbour_idx + 1, 0)
    Main_OnCommand(40297, 0)
    for _, t in ipairs(saved) do SetTrackSelected(t, true) end

    return true, target, #list
end

return M
