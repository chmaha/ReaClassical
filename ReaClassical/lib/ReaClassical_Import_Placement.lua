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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say  = require("ReaClassical_Announce")
local xfu  = require("ReaClassical_XFM_Utils")
local scan = require("ReaClassical_Smart_Import_Scan")

local root_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path

local saved_ripple_state = "off"

function M.disable_ripple()
    if GetToggleCommandState(40311) == 1 then
        saved_ripple_state = "all"
    elseif GetToggleCommandState(40310) == 1 then
        saved_ripple_state = "per"
    else
        saved_ripple_state = "off"
    end
    Main_OnCommand(40309, 0)
end

function M.restore_ripple()
    Main_OnCommand(40309, 0)
    if saved_ripple_state == "all" then
        Main_OnCommand(40311, 0)
    elseif saved_ripple_state == "per" then
        Main_OnCommand(40310, 0)
    end
end

function M.make_room(tracks, pos, amount, skip_set)
    if amount <= 0 then return end

    local member_tracks, seen_track, seen_folder = {}, {}, {}
    for _, track in ipairs(tracks) do
        local folder_track = xfu.is_folder_track(track) and track or xfu.get_parent_folder(track)
        if folder_track then
            if not seen_folder[folder_track] then
                seen_folder[folder_track] = true
                for _, t in ipairs(xfu.get_folder_tracks(folder_track)) do
                    if not seen_track[t] then
                        seen_track[t] = true
                        member_tracks[#member_tracks + 1] = t
                    end
                end
            end
        elseif not seen_track[track] then
            seen_track[track] = true
            member_tracks[#member_tracks + 1] = track
        end
    end

    local candidates = {}
    local boundary = pos
    for _, t in ipairs(member_tracks) do
        local n = CountTrackMediaItems(t)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(t, i)
            if not (skip_set and skip_set[item]) then
                local ip = GetMediaItemInfo_Value(item, "D_POSITION")
                local il = GetMediaItemInfo_Value(item, "D_LENGTH")
                candidates[#candidates + 1] = { item = item, pos = ip }
                if ip < pos - 0.0001 and ip + il > pos + 0.0001 and ip < boundary then
                    boundary = ip
                end
            end
        end
    end

    local straddle = pos - boundary > 0.0001
    local effective_amount = amount + math.max(0, pos - boundary) + (straddle and 1 or 0)

    for _, c in ipairs(candidates) do
        if c.pos > boundary - 0.001 then
            SetMediaItemInfo_Value(c.item, "D_POSITION", math.max(0, c.pos + effective_amount))
        end
    end
end

function M.content_end_of(items)
    local last_end = 0
    for _, item in ipairs(items) do
        local p = GetMediaItemInfo_Value(item, "D_POSITION")
        local l = GetMediaItemInfo_Value(item, "D_LENGTH")
        if p + l > last_end then last_end = p + l end
    end
    return last_end
end

function M.insert_media_get_item(track, filepath)
    local src = PCM_Source_CreateFromFile(filepath)
    if not src then return nil end
    local item = AddMediaItemToTrack(track)
    local take = AddTakeToMediaItem(item)
    SetMediaItemTake_Source(take, src)
    local src_len = GetMediaSourceLength(src)
    SetMediaItemInfo_Value(item, "D_LENGTH", src_len)
    local fn = GetMediaSourceFileName(src, "")
    GetSetMediaItemTakeInfo_String(take, "P_NAME", fn:match("([^/\\]+)$") or fn, true)
    return item
end

function M.calculate_round_robin_distribution(take_nums, folder_count)
    local distribution = {}
    for i = 1, folder_count do distribution[i] = {} end
    for idx, take_num in ipairs(take_nums) do
        local folder_idx = ((idx - 1) % folder_count) + 1
        table.insert(distribution[folder_idx], take_num)
    end
    return distribution
end

function M.select_children_of_selected_folders()
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) and GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
            local j = i + 1
            while j < track_count do
                local ch_tr = GetTrack(0, j)
                SetTrackSelected(ch_tr, true)
                if GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH") == -1 then break end
                j = j + 1
            end
        end
    end
end

function M.unselect_folder_children()
    local num_tracks    = CountTracks(0)
    local depth         = 0
    local unselect_mode = false

    for i = 0, num_tracks - 1 do
        local tr            = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if IsTrackSelected(tr) and folder_change == 1 then
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        depth = depth + folder_change
        if depth <= 0 then
            unselect_mode = false
            depth         = 0
        end
    end
end

function M.delete_items()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_SELECTED") == 1 then
            while CountTrackMediaItems(track) > 0 do
                DeleteTrackMediaItem(track, GetTrackMediaItem(track, 0))
            end
        end
    end
end

function M.create_folders_if_needed(target_count)
    local current_folders = scan.count_source_folders()
    if target_count > current_folders then
        local track_one = GetTrack(0, 0)
        for _ = 1, target_count - current_folders do
            SetOnlyTrackSelected(track_one)
            Main_OnCommand(40340, 0)
            Main_OnCommand(40062, 0)
            M.select_children_of_selected_folders()
            Main_OnCommand(40421, 0)
            M.delete_items()
            M.unselect_folder_children()
        end
        _G.RC_SUPPRESS_UNDO = true
        dofile(root_path .. "lib/ReaClassical_Vertical Workflow.lua")
        _G.RC_SUPPRESS_UNDO = nil
        Main_OnCommand(40297, 0)
    end
end

function M.build_folder_track_map(tracks)
    local folder_tracks  = {}
    local current_folder = 0
    local in_folder      = false

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if depth == 1 then
            current_folder = current_folder + 1
            folder_tracks[current_folder] = {}
            in_folder = true
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
        elseif depth == -1 then
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
            in_folder = false
        elseif in_folder then
            for _, track_obj in ipairs(tracks) do
                if track_obj.track == track then
                    table.insert(folder_tracks[current_folder], track_obj)
                    break
                end
            end
        end
    end

    return folder_tracks
end

function M.find_track_in_folder_list(folder_track_list, base_name)
    for _, track_obj in ipairs(folder_track_list) do
        if track_obj.base_name == base_name then return track_obj end
    end
    return nil
end

function M.rename_tracks(track_info, new_name, disconnect_rcm, workflow)
    if not workflow then
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
    end

    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_EXT:rcm_disconnect",
        disconnect_rcm and "y" or "", true)

    local clean_name = new_name:gsub("%-$", "")
    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_NAME", "M:" .. clean_name, true)

    local mixer_position = nil
    local mixer_index    = 0
    for i = 0, CountTracks(0) - 1 do
        local tr = GetTrack(0, i)
        local _, ms = GetSetMediaTrackInfo_String(tr, "P_EXT:mixer", "", false)
        if ms == "y" then
            mixer_index = mixer_index + 1
            if tr == track_info.mixer_track then
                mixer_position = mixer_index
                break
            end
        end
    end

    if not mixer_position then return end

    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folder_number = folder_number + 1

            local target_track = GetTrack(0, i + (mixer_position - 1))
            if target_track then
                GetSetMediaTrackInfo_String(target_track, "P_EXT:rcm_disconnect",
                    disconnect_rcm and "y" or "", true)

                local prefix = ""
                if workflow == "Vertical" then
                    prefix = (folder_number == 1)
                        and "D:"
                        or  ("S" .. (folder_number - 1) .. ":")
                end

                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. clean_name, true)
            end
        end
    end
end

function M.ensure_tracks_exist(ordered_names, workflow)
    local existing_tracks = scan.get_tracks(workflow)
    local existing = {}
    for _, t in ipairs(existing_tracks) do
        if t.base_name ~= "" then
            existing[t.base_name] = true
        end
    end

    for _, entry in ipairs(ordered_names) do
        if not existing[entry.base_name] then
            for i = 0, CountTracks(0) - 1 do
                local track = GetTrack(0, i)
                local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
                if mixer_state == "y" then
                    local _, current_name = GetTrackName(track)
                    local stripped = current_name:gsub("^M:?", ""):gsub("^%s*(.-)%s*$", "%1")
                    if stripped == "" then
                        M.rename_tracks({ mixer_track = track }, entry.display_name, false, workflow)
                        existing[entry.base_name] = true
                        break
                    end
                end
            end
        end
    end
end

function M.finish_import_tail(opts)
    M.restore_ripple()

    Undo_EndBlock(opts.undo_label or "Import Audio", -1)

    PreventUIRefresh(-1)

    local errors = opts.errors or {}
    if #errors > 0 then
        if opts.announce then
            say("Import issues: " .. table.concat(errors, "; "))
        else
            MB("The following issues were found:\n\n" .. table.concat(errors, "\n"), "Import Errors", 0)
        end
    elseif opts.announce and opts.success_message then
        say(opts.success_message)
    end

    dofile(opts.script_path .. "ReaClassical_Auto-color project.lua")

    UpdateArrange()
    UpdateTimeline()
end

return M
