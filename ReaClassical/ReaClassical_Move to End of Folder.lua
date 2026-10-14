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
local say = require("ReaClassical_Announce")

local main, is_special_track, get_folder_parent, get_folder_tracks, get_humanized_name

function is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

function get_folder_parent(track)
    if not track then return nil, nil end
    local idx = math.floor(GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1)
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        if not is_special_track(track) then return track, idx end
        return nil, nil
    end
    for i = idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
            if not is_special_track(t) then return t, i end
            return nil, nil
        end
    end
    return nil, nil
end

function get_folder_tracks(parent_track, parent_idx)
    local tracks = { parent_track }
    local num_tracks = CountTracks(0)
    local j = parent_idx + 1
    local depth = 1
    while j < num_tracks and depth > 0 do
        local ch = GetTrack(0, j)
        local d = GetMediaTrackInfo_Value(ch, "I_FOLDERDEPTH")
        if not is_special_track(ch) then
            table.insert(tracks, ch)
        end
        depth = depth + d
        j = j + 1
    end
    return tracks
end

function get_humanized_name(item)
    local take = GetActiveTake(item)
    local name = ""
    if take then
        _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    end
    if name == "" then return nil end
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        return prefix .. " take " .. tonumber(take_num)
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        return "take " .. tonumber(only_num)
    end
    return name
end

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

    local last_item, last_end
    for _, t in ipairs(tracks) do
        for i = 0, CountTrackMediaItems(t) - 1 do
            local item = GetTrackMediaItem(t, i)
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local end_pos = pos + len
            if not last_end or end_pos > last_end then
                last_end = end_pos
                last_item = item
            end
        end
    end

    if not last_item then
        say("No items in folder.")
        return
    end

    Main_OnCommand(40289, 0)
    SetMediaItemSelected(last_item, true)
    Main_OnCommand(40034, 0)
    SetEditCurPos(last_end, true, true)
    UpdateArrange()
    local human_name = get_humanized_name(last_item)
    if human_name then
        say("Moved to end of folder, " .. human_name)
    else
        say("Moved to end of folder")
    end
end

main()
