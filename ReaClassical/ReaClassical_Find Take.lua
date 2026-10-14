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
local rank_info = require("ReaClassical_Rank_Info")
local track_scan = require("ReaClassical_Track_Scan")
local track_write = require("ReaClassical_Track_Write")

local main, select_midpoint_peers, session_matches, get_folder_label, solo, sync_playhead

function get_folder_label(track)
    if not track then return "" end
    local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
    local folder = (depth == 1) and track or GetParentTrack(track)
    if not folder then return "" end
    local _, name = GetTrackName(folder)
    local prefix = name:match("^(.-):") or name
    if prefix:match("^D") then return "Destination" end
    local snum = prefix:match("^S(%d+)$")
    if snum then return "Source " .. snum end
    return prefix
end

local function humanize_take_phrase(take_name, fallback_num)
    if take_name and take_name ~= "" then
        take_name = rank_info.strip_rank_prefix(take_name)
    end
    if take_name and take_name ~= "" then
        local prefix, take_num = take_name:match("^(.+)_T(%d+)$")
        if take_num then
            return prefix .. " take " .. tonumber(take_num)
        end
        local only_num = take_name:match("^(%d+)$")
        if only_num then
            return "Take " .. tonumber(only_num)
        end
    end
    return fallback_num and ("Take " .. fallback_num) or "Take"
end

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

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local find_takes_using_items = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[13] then find_takes_using_items = tonumber(table[13]) or 0 end
    end

    local take_choice
    local found_take_num
    local found_item
    local _, session_name = GetProjExtState(0, "ReaClassical", "SessionNameSearch")

    local num_of_items = CountMediaItems(0)

    local function search(ignore_edit)
        for i = 0, num_of_items - 1 do
            local item = GetMediaItem(0, i)
            local _, stored_take_num = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)

            if stored_take_num and stored_take_num ~= "" then
                local take_num = tonumber(stored_take_num)
                if take_num == take_choice then
                    local session_match = true
                    if session_name and session_name ~= "" then
                        local take = GetActiveTake(item)
                        if take then
                            if find_takes_using_items == 0 then
                                local src = GetMediaItemTake_Source(take)
                                local filename = GetMediaSourceFileName(src, "")
                                session_match = session_matches(filename, session_name)
                            else
                                local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                                if not take_name:find("_") then
                                    session_match = false
                                else
                                    session_match = session_matches(take_name, session_name)
                                end
                            end
                        end
                    end

                    local edit, _ = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)

                    if session_match and (ignore_edit or not edit) then
                        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                        SetEditCurPos(item_start, true, false)
                        Main_OnCommand(40769, 0)
                        SetMediaItemSelected(item, true)
                        select_midpoint_peers(GetMediaItemTrack(item))
                        found_take_num = take_num
                        found_item = item
                        return true
                    end
                end
            end
        end

        if find_takes_using_items == 0 then
            for i = 0, num_of_items - 1, 1 do
                local item = GetMediaItem(0, i)
                local take = GetActiveTake(item)
                if take then
                    local src = GetMediaItemTake_Source(take)
                    local filename = GetMediaSourceFileName(src, "")
                    local take_capture = tonumber(filename:match("_T?(%d+)%.[^%.]+$"))

                    local session_match = true
                    if session_name and session_name ~= "" then
                        session_match = session_matches(filename, session_name)
                    end

                    local edit, _ = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)

                    if take_capture == take_choice and session_match and (ignore_edit or not edit) then
                        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                        SetEditCurPos(item_start, true, false)
                        Main_OnCommand(40769, 0)
                        SetMediaItemSelected(item, true)
                        select_midpoint_peers(GetMediaItemTrack(item))
                        found_take_num = take_capture
                        found_item = item
                        return true
                    end
                end
            end
        else
            for i = 0, num_of_items - 1 do
                local item = GetMediaItem(0, i)
                local take = GetActiveTake(item)
                if take then
                    local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    local session_match = true
                    if session_name and session_name ~= "" then
                        if not take_name:find("_") then
                            session_match = false
                        else
                            session_match = session_matches(take_name, session_name)
                        end
                    end

                    if take_name and session_match then
                        local item_found = false
                        local take_num = tonumber(take_name:match("_T?(%d+)$") or take_name:match("^(%d+)$"))
                        if take_choice then
                            if take_num == take_choice then item_found = true end
                        else
                            item_found = true
                        end

                        if item_found then
                            local edit, _ = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
                            if ignore_edit or not edit then
                                local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                                SetEditCurPos(item_start, true, false)
                                Main_OnCommand(40769, 0)
                                SetMediaItemSelected(item, true)
                                select_midpoint_peers(GetMediaItemTrack(item))
                                found_take_num = take_num
                                found_item = item
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    while true do
        local retval, inputs = GetUserInputs(
            'Find Take', 2, 'Take Number:,Session Name (optional):', ',' .. session_name)
        if not retval then return end

        take_choice, session_name = inputs:match("([^,]*),([^,]*)")
        take_choice = tonumber(take_choice)
        if not take_choice and session_name ~= "" then take_choice = 1 end

        session_name = session_name:match("^%s*(.-)%s*$")
        SetProjExtState(0, "ReaClassical", "SessionNameSearch", session_name)

        local found = search(false) or search(true)

        if not found and (take_choice or session_name ~= "") then
            say("Take not found")
            local response = MB("Take not found. Try again?", "Find Take", 4)
            if response ~= 6 then
                break
            end
        else
            if found then
                solo()
                sync_playhead()
                local found_track = GetSelectedTrack(0, 0)
                local label = get_folder_label(found_track)
                local take = found_item and GetActiveTake(found_item)
                local take_name
                if take then
                    _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                end
                say(humanize_take_phrase(take_name, found_take_num) .. rank_info.rank_announce_suffix(found_item)
                    .. " found" .. (label ~= "" and (" in " .. label) or ""))
            end
            break
        end
    end
end

function select_midpoint_peers(sel_track)
    if not sel_track then return end
    local track_num = GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local folder_start, folder_end = nil, nil
    local start_search = track_num
    if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") ~= 1 then
        for t = track_num - 1, 0, -1 do
            local tt = GetTrack(0, t)
            if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
                start_search = t; break
            end
        end
    end
    for t = start_search, num_tracks - 1 do
        local tt = GetTrack(0, t)
        if GetMediaTrackInfo_Value(tt, "I_FOLDERDEPTH") == 1 then
            folder_start = t; folder_end = t
            local x = t + 1
            while x < num_tracks do
                local d = GetMediaTrackInfo_Value(GetTrack(0, x), "I_FOLDERDEPTH")
                folder_end = x
                if d < 0 then break end
                x = x + 1
            end
            break
        end
    end
    if not folder_start then return end
    local seed_items = {}
    local num_sel = CountSelectedMediaItems(0)
    for i = 0, num_sel - 1 do
        seed_items[#seed_items + 1] = GetSelectedMediaItem(0, i)
    end
    for _, ref_item in ipairs(seed_items) do
        local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
        local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
        local mid = pos + len * 0.5
        local tolerance = 0.0001
        for t = folder_start, folder_end do
            local track = GetTrack(0, t)
            local n = CountTrackMediaItems(track)
            for i = 0, n - 1 do
                local item = GetTrackMediaItem(track, i)
                local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
                local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
                if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                    SetMediaItemSelected(item, true)
                end
            end
        end
    end
    Main_OnCommand(40297, 0)
    SetTrackSelected(GetTrack(0, folder_start), true)
end

function solo()
    local cache = track_scan.build()
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

function sync_playhead()
    if GetPlayState() & 1 == 1 then
        SetEditCurPos(GetCursorPosition(), false, true)
    end
end

function session_matches(text, sname)
    local segments = {}
    for seg in text:lower():gmatch("([^_]+)") do
        segments[#segments + 1] = seg
    end
    if #segments < 2 then return false end
    return segments[1]:find(sname:lower(), 1, true) ~= nil
end

main()
