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
local xfu = require("ReaClassical_XFM_Utils")
local sd_xfade = require("ReaClassical_SD_Crossfade_Utils")
local scan = require("ReaClassical_Smart_Import_Scan")
local placement = require("ReaClassical_Import_Placement")

local M = {}

local function is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

function M.resolve_folder(item)
    local track = GetMediaItemTrack(item)
    if not track then return nil end
    if xfu.is_folder_track(track) and not is_special_track(track) then
        return track
    end
    local parent = xfu.get_parent_folder(track)
    if parent and not is_special_track(parent) then
        return parent
    end
    return nil
end

function M.find_group_starts(folder_track)
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

function M.group_range_for_item(folder_track, item)
    local group_starts = M.find_group_starts(folder_track)
    if #group_starts == 0 then return nil end

    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local project_end = GetProjectLength(0) + 10
    local eps = 0.001

    for i = #group_starts, 1, -1 do
        local gpos = GetMediaItemInfo_Value(group_starts[i], "D_POSITION")
        if item_pos >= gpos - eps or i == 1 then
            local right = group_starts[i + 1]
                and GetMediaItemInfo_Value(group_starts[i + 1], "D_POSITION")
                or project_end
            return gpos, right
        end
    end
end

function M.resolve_selection()
    local count = CountSelectedMediaItems(0)
    if count == 0 then
        return nil, nil, nil, "Please select an item within the crossfade group you want to fix."
    end

    local first_item = GetSelectedMediaItem(0, 0)
    local folder_track = M.resolve_folder(first_item)
    if not folder_track then
        return nil, nil, nil, "Please select an item within a ReaClassical folder."
    end

    local left, right = M.group_range_for_item(folder_track, first_item)
    if not left then
        return nil, nil, nil, "This folder has no crossfade groups to fix."
    end

    local eps = 0.001
    for i = 1, count - 1 do
        local item = GetSelectedMediaItem(0, i)
        local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
        if M.resolve_folder(item) ~= folder_track or item_pos < left - eps or item_pos >= right - eps then
            return nil, nil, nil, "Please select items within a single crossfade group only."
        end
    end

    return folder_track, left, right, nil
end

function M.folder_track_list(folder_track)
    local list = {}
    for _, t in ipairs(xfu.get_folder_tracks(folder_track)) do
        local _, name = GetTrackName(t)
        table.insert(list, { track = t, name = name })
    end
    return list
end

function M.build_file_index()
    local media_path = scan.get_project_media_path()
    local files = media_path and scan.scan_media_folder_recursive(media_path) or {}
    local index = {}
    for _, filepath in ipairs(files) do
        local info = scan.parse_canonical_filename(filepath)
        if info then
            index[info.track_name] = index[info.track_name] or {}
            index[info.track_name][info.take_num] = index[info.track_name][info.take_num] or {}
            table.insert(index[info.track_name][info.take_num], {
                filepath = filepath,
                session_name = info.session_name,
            })
        end
    end
    return index
end

function M.find_file_for_track(file_index, base_name, take_num, preferred_session)
    local by_take = file_index[base_name]
    local candidates = by_take and by_take[take_num]
    if not candidates then return nil end
    if preferred_session then
        for _, c in ipairs(candidates) do
            if c.session_name == preferred_session then return c.filepath end
        end
    end
    return candidates[1] and candidates[1].filepath or nil
end

local function base_name_for_track(track, workflow)
    for _, t in ipairs(scan.get_tracks(workflow)) do
        if t.track == track then return t.base_name end
    end
    return nil
end

local function delete_items_in_range(track, left, right)
    local eps = 0.0001
    local removed = {}
    for i = CountTrackMediaItems(track) - 1, 0, -1 do
        local item = GetTrackMediaItem(track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos + len > left + eps and pos < right - eps then
            table.insert(removed, {
                pos   = pos,
                len   = len,
                color = GetMediaItemInfo_Value(item, "I_CUSTOMCOLOR"),
            })
            DeleteTrackMediaItem(track, item)
        end
    end
    return removed
end

local function color_for_position(removed, pos, len)
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    for _, r in ipairs(removed) do
        if mid >= (r.pos - tolerance) and mid <= (r.pos + r.len + tolerance) then
            return r.color
        end
    end
    return nil
end

function M.replace_track_range(target_track, good_items, left, right, file_index, workflow)
    local warnings = {}
    local fixed = 0

    local base_name = base_name_for_track(target_track, workflow)
    if not base_name then
        local _, track_name = GetTrackName(target_track)
        table.insert(warnings, "Could not resolve '" .. track_name .. "' to a known track role")
        return fixed, warnings
    end

    local plan = {}
    for _, good_item in ipairs(good_items) do
        local good_take = GetActiveTake(good_item)
        local good_source = good_take and GetMediaItemTake_Source(good_take)
        local good_filepath = good_source and GetMediaSourceFileName(good_source, "")
        local info = good_filepath and scan.parse_canonical_filename(good_filepath)

        if not info then
            table.insert(warnings, string.format(
                "Could not read the reference track's source filename at position %.2f",
                GetMediaItemInfo_Value(good_item, "D_POSITION")))
        else
            local filepath = M.find_file_for_track(file_index, base_name, info.take_num, info.session_name)
            if not filepath then
                table.insert(warnings, string.format(
                    "No matching file found for '%s' take %d", base_name, info.take_num))
            else
                table.insert(plan, { good_item = good_item, good_take = good_take, filepath = filepath, info = info })
            end
        end
    end

    if #plan == 0 then
        if #good_items > 0 then
            table.insert(warnings, "'" .. base_name .. "' left untouched: none of the reference track's items "
                .. "could be matched to a file (unsupported filename format?)")
        end
        return fixed, warnings
    end

    local removed = delete_items_in_range(target_track, left, right)

    for _, entry in ipairs(plan) do
        local good_item, good_take, filepath, info = entry.good_item, entry.good_take, entry.filepath, entry.info
        local new_item = placement.insert_media_get_item(target_track, filepath)
        if not new_item then
            table.insert(warnings, "Could not create item from " .. filepath)
        else
            local new_pos = GetMediaItemInfo_Value(good_item, "D_POSITION")
            local new_len = GetMediaItemInfo_Value(good_item, "D_LENGTH")
            SetMediaItemInfo_Value(new_item, "D_POSITION", new_pos)
            SetMediaItemInfo_Value(new_item, "D_LENGTH", new_len)
            SetMediaItemInfo_Value(new_item, "D_FADEINLEN", GetMediaItemInfo_Value(good_item, "D_FADEINLEN"))
            SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", GetMediaItemInfo_Value(good_item, "D_FADEOUTLEN"))
            SetMediaItemInfo_Value(new_item, "D_FADEINLEN_AUTO",
                GetMediaItemInfo_Value(good_item, "D_FADEINLEN_AUTO"))
            SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN_AUTO",
                GetMediaItemInfo_Value(good_item, "D_FADEOUTLEN_AUTO"))
            SetMediaItemInfo_Value(new_item, "C_FADEINSHAPE", GetMediaItemInfo_Value(good_item, "C_FADEINSHAPE"))
            SetMediaItemInfo_Value(new_item, "C_FADEOUTSHAPE",
                GetMediaItemInfo_Value(good_item, "C_FADEOUTSHAPE"))
            SetMediaItemInfo_Value(new_item, "B_MUTE", GetMediaItemInfo_Value(good_item, "B_MUTE"))

            local restored_color = color_for_position(removed, new_pos, new_len)
            if restored_color then
                SetMediaItemInfo_Value(new_item, "I_CUSTOMCOLOR", restored_color)
                GetSetMediaItemInfo_String(new_item, "P_EXT:saved_color", tostring(restored_color), true)
            end

            local new_take = GetActiveTake(new_item)
            SetMediaItemTakeInfo_Value(new_take, "D_STARTOFFS",
                GetMediaItemTakeInfo_Value(good_take, "D_STARTOFFS"))
            SetMediaItemTakeInfo_Value(new_take, "D_PLAYRATE",
                GetMediaItemTakeInfo_Value(good_take, "D_PLAYRATE"))

            local item_name = info.session_name == "default"
                and string.format("%03d", info.take_num)
                or  info.session_name .. "_T" .. string.format("%03d", info.take_num)
            GetSetMediaItemTakeInfo_String(new_take, "P_NAME", item_name, true)
            GetSetMediaItemInfo_String(new_item, "P_EXT:item_take_num", tostring(info.take_num), true)

            fixed = fixed + 1
        end
    end

    return fixed, warnings
end

function M.run_fix(folder_track, good_track, left, right)
    local tracks = xfu.get_folder_tracks(folder_track)
    sd_xfade.remove_extra_overlaps(tracks, left, right)

    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    local file_index = M.build_file_index()

    local good_items = {}
    local eps = 0.0001
    for i = 0, CountTrackMediaItems(good_track) - 1 do
        local item = GetTrackMediaItem(good_track, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        if pos >= left - eps and pos < right - eps then
            table.insert(good_items, item)
        end
    end

    local total_fixed = 0
    local all_warnings = {}
    for _, target_track in ipairs(tracks) do
        if target_track ~= good_track then
            local fixed, warnings = M.replace_track_range(target_track, good_items, left, right, file_index, workflow)
            total_fixed = total_fixed + fixed
            for _, w in ipairs(warnings) do table.insert(all_warnings, w) end
        end
    end

    return total_fixed, all_warnings
end

return M
