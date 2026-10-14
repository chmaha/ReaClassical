--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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

local main, select_check, check_next_item_overlap, get_selected_media_item_at

local _, debug_announce = GetProjExtState(0, "ReaEdit", "DebugAnnounce")
if APIExists("osara_outputMessage") or debug_announce == "on" then
    local setup = require("ReaEdit_XFM_Setup")
    if setup.keys_present(script_path) == false then
        local answer = MB("ReaEdit's crossfade mode keys are not installed yet.\n\n"
            .. "They go in REAPER's last alternate keyboard section, Main (alt-16). If you have shortcuts of your own "
            .. "there, back them up first (the manual explains how).\n\n"
            .. "Yes: create the key file now (you then import it once from the Action List).\n"
            .. "No: start crossfade mode anyway (you will be asked again next time until the keys are installed).\n"
            .. "Cancel: do nothing.", "ReaEdit Crossfade Mode", 3)
        if answer == 6 then
            dofile(script_path .. "XFM" .. package.config:sub(1, 1) .. "ReaEdit_Set Up Crossfade Mode Keys.lua")
            return
        elseif answer == 2 then
            return
        end
    end
    if APIExists("AddRemoveReaScript") then
        local sep = package.config:sub(1, 1)
        local daemon_cid = AddRemoveReaScript(true, 0,
            script_path .. "XFM" .. sep .. "ReaEdit_XFM Mode Daemon.lua", true)
        if daemon_cid ~= 0 then
            Main_OnCommand(daemon_cid, 0)
        end
    end
    return
end

function main()
    Undo_BeginBlock()
    PreventUIRefresh(1)

    local reaper_xfade_toggle = GetToggleCommandState(41827)
    if reaper_xfade_toggle == 0 or reaper_xfade_toggle == -1 then
        local _, item1 = select_check()
        if item1 and check_next_item_overlap(item1) then
            Main_OnCommand(40310, 0)
            Main_OnCommand(41827, 0)
        else
            MB("Please select the right item of a crossfaded pair", "Crossfade Editor", 0)
        end
        local lock_fade = GetToggleCommandStateEx(32065, 43592)
        if lock_fade == 0 and APIExists("CrossfadeEditor_OnCommand") then CrossfadeEditor_OnCommand(43592) end
    elseif reaper_xfade_toggle == 1 then
        Main_OnCommand(41827, 0)
    end

    PreventUIRefresh(-1)
    Undo_EndBlock('Crossfade Editor', 0)
    UpdateArrange()
    UpdateTimeline()
end

function select_check()
    local selected_item = get_selected_media_item_at(0)

    if not selected_item then
        return false
    end

    local track = GetMediaItemTrack(selected_item)

    local current_item_index = GetMediaItemInfo_Value(selected_item, "IP_ITEMNUMBER")
    local prev_item = GetTrackMediaItem(track, current_item_index - 1)

    return prev_item and selected_item, prev_item or false
end

function check_next_item_overlap(current_item)
    local track = GetMediaItemTrack(current_item)
    if not track then
        return false
    end
    local current_item_index = GetMediaItemInfo_Value(current_item, "IP_ITEMNUMBER")

    local next_item = GetTrackMediaItem(track, current_item_index + 1)

    if not next_item then
        return false
    end

    local current_item_position = GetMediaItemInfo_Value(current_item, "D_POSITION")
    local current_item_length = GetMediaItemInfo_Value(current_item, "D_LENGTH")
    local current_item_end = current_item_position + current_item_length
    local next_item_position = GetMediaItemInfo_Value(next_item, "D_POSITION")

    if next_item_position >= current_item_end then
        return false
    end
    return true
end

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

main()
