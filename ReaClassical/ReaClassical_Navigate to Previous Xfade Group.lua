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

local main, is_folder_track, is_special_track, get_parent_folder
local find_group_starts, announce_name

---------------------------------------------------------------------

function is_folder_track(track)
    if not track then return false end
    return GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
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

function get_parent_folder(track)
    if not track then return nil end
    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
    for i = track_idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
    end
    return nil
end

---------------------------------------------------------------------

-- Returns an ordered list of the first item of each xfade group on
-- folder_track. Groups are identified by gaps: items within a group
-- overlap (crossfades); a new group starts whenever an item begins
-- after the running end of all previous items by at least 1 ms.
function find_group_starts(folder_track)
    local group_starts = {}
    local num_items = GetTrackNumMediaItems(folder_track)
    local running_end = -math.huge
    local eps = 0.001

    for i = 0, num_items - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")

        if pos >= running_end + eps then
            table.insert(group_starts, item)
            running_end = pos + len
        else
            running_end = math.max(running_end, pos + len)
        end
    end

    return group_starts
end

---------------------------------------------------------------------

function announce_name(take_name)
    local name = take_name:match("^(.-)%s*|") or take_name
    name = name:gsub("^[#!]", ""):match("^%s*(.-)%s*$")
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        say(prefix .. " take " .. tonumber(take_num))
        return
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        say("Take " .. tonumber(only_num))
        return
    end
    say(name ~= "" and name or "(unnamed)")
end

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    if GetToggleCommandState(1156) ~= 1 then
        Main_OnCommand(1156, 0)
    end

    local selected_track = GetSelectedTrack(0, 0)
    local folder_track = nil
    if selected_track then
        if is_folder_track(selected_track) and not is_special_track(selected_track) then
            folder_track = selected_track
        else
            local parent = get_parent_folder(selected_track)
            if parent and not is_special_track(parent) then
                folder_track = parent
            end
        end
    end

    if not folder_track then
        say("Please select a track within a ReaClassical folder")
        return
    end

    local cursor_pos = GetCursorPosition()
    local group_starts = find_group_starts(folder_track)
    local best = nil
    local eps = 0.001

    for _, item in ipairs(group_starts) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        if pos >= cursor_pos - eps then break end
        best = item
    end

    if not best then
        say("At first group")
        return
    end

    local target_pos = GetMediaItemInfo_Value(best, "D_POSITION")
    local take = GetActiveTake(best)
    local take_name = take and select(2, GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)) or ""

    PreventUIRefresh(1)
    Main_OnCommand(40289, 0)
    SetOnlyTrackSelected(folder_track)
    SetMediaItemSelected(best, true)
    Main_OnCommand(40034, 0)
    SetEditCurPos(target_pos, true, false)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
    announce_name(take_name)
end

---------------------------------------------------------------------

main()
