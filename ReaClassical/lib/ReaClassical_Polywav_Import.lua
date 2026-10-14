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
local scan      = require("ReaClassical_Smart_Import_Scan")
local placement = require("ReaClassical_Import_Placement")

function M.scan_candidates()
    local used_files = scan.get_used_source_files()
    local all_files  = scan.scan_media_folder_recursive(scan.get_project_media_path())

    local candidates = {}
    for _, filepath in ipairs(all_files) do
        local normalized = filepath:gsub("\\", "/")
        if not used_files[normalized] then
            local src = PCM_Source_CreateFromFile(filepath)
            if src then
                local channel_count = GetMediaSourceNumChannels(src)
                PCM_Source_Destroy(src)
                if channel_count > 2 then
                    candidates[#candidates + 1] = {
                        filepath      = filepath,
                        display_name  = filepath:match("([^/\\]+)$") or filepath,
                        channel_count = channel_count,
                    }
                end
            end
        end
    end

    table.sort(candidates, function(a, b) return a.display_name < b.display_name end)
    return candidates
end

function M.parse_polywav_filename(filepath)
    local filename = filepath:match("([^/\\]+)$")
    if not filename then return nil end
    local name_no_ext = filename:match("(.+)%.[^.]+$")
    if not name_no_ext then return nil end

    local session_name, take_str = name_no_ext:match("^(.-)_T(%d+)$")
    if not take_str then
        session_name, take_str = name_no_ext:match("^(.-)_(%d+)$")
    end
    if not take_str then
        take_str = name_no_ext:match("^T(%d+)$")
        session_name = ""
    end
    if not take_str then
        take_str = name_no_ext:match("^(%d+)$")
        session_name = ""
    end
    if not take_str then return nil end

    return {
        filename     = filename,
        session_name = (session_name ~= "" and session_name) or "default",
        take_num     = tonumber(take_str),
    }
end

function M.build_sessions(candidates)
    local sessions = {}
    local errors = {}

    for _, c in ipairs(candidates) do
        local info = M.parse_polywav_filename(c.filepath)
        if not info then
            errors[#errors + 1] = c.display_name
                .. " (invalid filename -- expected [SessionName_]T###.ext)"
        else
            if not sessions[info.session_name] then sessions[info.session_name] = {} end
            if sessions[info.session_name][info.take_num] then
                errors[#errors + 1] = c.display_name .. string.format(
                    " (duplicate take T%03d for session '%s')", info.take_num, info.session_name)
            else
                c.filename     = info.filename
                c.session_name = info.session_name
                c.take_num     = info.take_num
                sessions[info.session_name][info.take_num] = c
            end
        end
    end

    local session_names = {}
    for session_name in pairs(sessions) do
        table.insert(session_names, session_name)
    end
    table.sort(session_names, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a < b
    end)

    return sessions, session_names, errors
end

function M.parse_composition_pattern(pattern_str)
    if not pattern_str or pattern_str == "" then
        return nil, "Enter a composition pattern, e.g. 1, 2, 21, or 221."
    end

    local digits = {}
    for ch in pattern_str:gmatch(".") do
        local d = tonumber(ch)
        if not d then
            return nil, "Composition pattern must contain only digits."
        end
        if d ~= 1 and d ~= 2 then
            return nil, "Composition pattern digits must be 1 (mono) or 2 (stereo) -- "
                .. "REAPER tracks don't support wider channel groups."
        end
        digits[#digits + 1] = d
    end

    return digits
end

function M.compose_channels(channel_count, digits)
    if not digits or #digits == 0 then
        return nil, "Enter a composition pattern, e.g. 1, 2, 21, or 221."
    end

    local groups = {}
    local remaining = channel_count

    for _, d in ipairs(digits) do
        if remaining <= 0 then break end
        if d > remaining then
            return nil, string.format(
                "Composition pattern needs more channels (%d) than this file has (%d).",
                (function() local s = 0 for _, dd in ipairs(digits) do s = s + dd end return s end)(),
                channel_count)
        end
        groups[#groups + 1] = d
        remaining = remaining - d
    end

    if remaining > 0 then
        local repeat_digit = digits[#digits]
        while remaining >= repeat_digit do
            groups[#groups + 1] = repeat_digit
            remaining = remaining - repeat_digit
        end
        while remaining > 0 do
            groups[#groups + 1] = 1
            remaining = remaining - 1
        end
    end

    return groups
end

function M.compute_composition(channel_count, pattern_str)
    local digits, perr = M.parse_composition_pattern(pattern_str)
    if not digits then return nil, nil, perr end

    local groups, cerr = M.compose_channels(channel_count, digits)
    if not groups then return nil, nil, cerr end

    local ordered_names = {}
    local ch = 1
    for i, size in ipairs(groups) do
        if size == 2 then
            ordered_names[i] = { base_name = "ch" .. ch, display_name = string.format("Ch %d-%d (Stereo)", ch, ch + 1) }
        else
            ordered_names[i] = { base_name = "ch" .. ch, display_name = "Ch " .. ch }
        end
        ch = ch + size
    end

    return groups, ordered_names
end

function M.validate_capacity(needed_track_slots, workflow)
    local folder_tracks = placement.build_folder_track_map(scan.get_tracks(workflow))
    local per_folder = folder_tracks[1] and #folder_tracks[1] or 0
    if needed_track_slots > per_folder then
        return false, string.format(
            "This split needs %d track%s per folder, but each folder only has %d track%s present.",
            needed_track_slots, needed_track_slots == 1 and "" or "s",
            per_folder, per_folder == 1 and "" or "s")
    end
    return true, nil
end

local function chanmode_for_group(start_channel, size)
    if size == 2 then
        return 66 + start_channel
    end
    return 2 + start_channel
end

function M.place_take_items(filepath, groups, target_tracks)
    local items = {}
    local ch = 1
    for i, size in ipairs(groups) do
        local target_track = target_tracks[i]
        if target_track then
            local item = placement.insert_media_get_item(target_track, filepath)
            if not item then
                return nil, "Could not read the audio at " .. filepath
            end
            local take = GetActiveTake(item)
            SetMediaItemTakeInfo_Value(take, "I_CHANMODE", chanmode_for_group(ch, size))
            items[i] = item
        end
        ch = ch + size
    end
    return items
end

local function prepare(sessions, session_names, pattern_str, workflow)
    if not session_names or #session_names == 0 then
        return nil, nil, nil, { "No polywav takes found." }
    end

    local channel_count
    for _, session_name in ipairs(session_names) do
        for _, candidate in pairs(sessions[session_name]) do
            if not channel_count then
                channel_count = candidate.channel_count
            elseif candidate.channel_count ~= channel_count then
                return nil, nil, nil, { "Selected polywav files have differing channel counts -- "
                    .. "all files in one import must match." }
            end
        end
    end

    local groups, ordered_names, comp_err = M.compute_composition(channel_count, pattern_str)
    if not groups then
        return nil, nil, nil, { comp_err }
    end

    local cap_ok, cap_msg = M.validate_capacity(#groups, workflow)
    if not cap_ok then
        return nil, nil, nil, { cap_msg }
    end

    local base_names = {}
    for _, n in ipairs(ordered_names) do base_names[#base_names + 1] = n.base_name end

    return groups, ordered_names, base_names, nil
end

local function record_item(item, pos, take_num, take_len, all_items, touched_tracks)
    SetMediaItemInfo_Value(item, "D_POSITION", pos)
    local take = GetActiveTake(item)
    if take then
        GetSetMediaItemTakeInfo_String(take, "P_NAME", string.format("%03d", take_num), true)
    end
    local len = GetMediaItemInfo_Value(item, "D_LENGTH")
    if len > take_len then take_len = len end
    all_items[#all_items + 1] = item

    local track = GetMediaItem_Track(item)
    local seen = false
    for _, tt in ipairs(touched_tracks) do
        if tt == track then seen = true break end
    end
    if not seen then touched_tracks[#touched_tracks + 1] = track end

    return take_len
end

function M.run(opts)
    local groups, ordered_names, base_names, errors =
        prepare(opts.sessions, opts.session_names, opts.composition_pattern, opts.workflow)
    if not groups then
        return false, errors
    end

    placement.ensure_tracks_exist(ordered_names, opts.workflow)

    errors = {}
    local is_vertical    = opts.workflow == "Vertical"
    local start_pos      = opts.start_pos or 0
    local scratch_start  = math.max(start_pos, scan.get_project_end_position() + 10)
    local pos            = scratch_start
    local all_items      = {}
    local touched_tracks = {}

    local folder_tracks
    local horiz_target_tracks
    local round_robin = is_vertical and (opts.distribution_mode == 1 or opts.distribution_mode == 2)

    if is_vertical then
        local max_takes = 0
        for _, session_name in ipairs(opts.session_names) do
            local n = 0
            for _ in pairs(opts.sessions[session_name]) do n = n + 1 end
            if n > max_takes then max_takes = n end
        end

        local folders_needed = round_robin
            and (opts.start_folder_idx + opts.target_folder_count - 1) - 1
            or  (opts.start_folder_idx + max_takes - 1) - 1
        placement.create_folders_if_needed(folders_needed)

        local tracks = scan.get_tracks("Vertical")
        folder_tracks = placement.build_folder_track_map(tracks)
    else
        local tracks = scan.get_tracks("Horizontal")
        horiz_target_tracks = {}
        for i, base_name in ipairs(base_names) do
            local t = scan.find_track_by_name(tracks, base_name)
            horiz_target_tracks[i] = t and t.track or nil
            if horiz_target_tracks[i] then touched_tracks[#touched_tracks + 1] = horiz_target_tracks[i] end
        end
    end

    for _, session_name in ipairs(opts.session_names) do
        local session_data = opts.sessions[session_name]
        local take_nums = {}
        for take_num in pairs(session_data) do table.insert(take_nums, take_num) end
        table.sort(take_nums)

        local folder_positions, max_end_position
        if round_robin then
            folder_positions = {}
            for i = 1, opts.target_folder_count do folder_positions[i] = pos end
            max_end_position = pos
        end

        local session_max_len = 0

        for take_idx, take_num in ipairs(take_nums) do
            local candidate = session_data[take_num]

            local target_tracks = {}
            if is_vertical then
                local folder_idx = round_robin
                    and (((take_idx - 1) % opts.target_folder_count) + 1)
                    or  take_idx
                local actual_folder_idx = opts.start_folder_idx + folder_idx - 1
                local folder_track_list = folder_tracks[actual_folder_idx]

                if not folder_track_list then
                    table.insert(errors, string.format(
                        "Could not find source folder %d for %s T%03d",
                        actual_folder_idx, session_name, take_num))
                    goto continue
                end

                for i, base_name in ipairs(base_names) do
                    local t = placement.find_track_in_folder_list(folder_track_list, base_name)
                    target_tracks[i] = t and t.track or nil
                end

                if round_robin and take_idx > opts.target_folder_count and folder_idx == 1 then
                    local next_round_start = max_end_position + 2
                    for i = 1, opts.target_folder_count do folder_positions[i] = next_round_start end
                end
            else
                target_tracks = horiz_target_tracks
            end

            do
                local items, place_err = M.place_take_items(candidate.filepath, groups, target_tracks)
                if not items then
                    table.insert(errors, candidate.filename .. ": " .. (place_err or "could not place audio"))
                else
                    local take_len = 0
                    local take_pos
                    if round_robin then
                        take_pos = folder_positions[((take_idx - 1) % opts.target_folder_count) + 1]
                    else
                        take_pos = pos
                    end
                    for i, item in ipairs(items) do
                        if item then
                            take_len = record_item(item, take_pos, take_num, take_len, all_items, touched_tracks)
                        elseif target_tracks[i] == nil then
                            table.insert(errors, string.format(
                                "%s T%03d: no track for %s", session_name, take_num, ordered_names[i].display_name))
                        end
                    end

                    if round_robin then
                        local folder_idx = ((take_idx - 1) % opts.target_folder_count) + 1
                        local take_end = folder_positions[folder_idx] + take_len
                        if take_end > max_end_position then max_end_position = take_end end
                    elseif is_vertical then
                        if take_len > session_max_len then session_max_len = take_len end
                    else
                        pos = pos + take_len + 2
                    end
                end
            end

            ::continue::
        end

        if round_robin then
            pos = max_end_position + 10
        elseif is_vertical then
            pos = pos + session_max_len + 10
        else
            pos = pos + 10
        end
    end

    local delta = scratch_start - start_pos
    if delta > 0.0001 and #all_items > 0 then
        local skip_set = {}
        for _, item in ipairs(all_items) do skip_set[item] = true end
        placement.make_room(touched_tracks, start_pos, placement.content_end_of(all_items) - scratch_start, skip_set)
        for _, item in ipairs(all_items) do
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", math.max(0, p - delta))
        end
    end

    return #errors == 0, errors
end

return M
