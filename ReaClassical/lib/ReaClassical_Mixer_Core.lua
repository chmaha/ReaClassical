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
local humanize_track_name = require("ReaClassical_Track_Naming")
local mm_groups = require("ReaClassical_MM_Groups")

local M = {}

function M.trackname_check(track, pattern)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(name, pattern)
end

function M.clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

function M.linear_to_db(val)
    if val <= 0.0000000298023223876953125 then
        return -150.0
    end
    return 20 * math.log(val, 10)
end

function M.db_to_linear(db)
    if db <= -150 then
        return 0.0
    end
    return 10 ^ (db / 20)
end

function M.format_pan(panVal)
    if math.abs(panVal) < 0.01 then
        return "C"
    elseif panVal < 0 then
        return tostring(math.floor(-panVal * 100 + 0.5)) .. "L"
    else
        return tostring(math.floor(panVal * 100 + 0.5)) .. "R"
    end
end

function M.pct_to_pan(str)
    local n = tonumber(str)
    if not n then return nil end
    return M.clamp(n / 100, -1, 1)
end

function M.format_track_peak(track)
    local peak = -150.0
    local num_chans = math.min(GetMediaTrackInfo_Value(track, "I_NCHAN"), 2)
    for ch = 0, num_chans - 1 do
        local val = Track_GetPeakHoldDB(track, ch, false) * 100
        if val > peak then peak = val end
    end
    if peak <= -150.0 then return "silence" end
    return string.format("%.1f dB", peak)
end

function M.get_rcmaster()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        if state == "y" or M.trackname_check(track, "^RCMASTER") then
            return track, i
        end
    end
    return nil
end

function M.get_mixer_tracks()
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, spare_state = GetSetMediaTrackInfo_String(track, "P_EXT:spare", "", false)
        if state == "y" and spare_state ~= "y" then
            table.insert(tracks, track)
        end
    end
    return tracks
end

function M.get_special_tracks()
    local tracks = {}

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, playback_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y"
            or live_state == "y" or rcmaster_state == "y" or listenback_state == "y"
            or playback_state == "y" then
            local track_type = "other"
            local has_routing = false

            if aux_state == "y" then
                track_type = "aux"
                has_routing = true
            elseif submix_state == "y" then
                track_type = "submix"
                has_routing = true
            elseif rt_state == "y" then
                track_type = "roomtone"
            elseif ref_state == "y" then
                track_type = "reference"
            elseif live_state == "y" then
                track_type = "live"
            elseif listenback_state == "y" then
                track_type = "listenback"
            elseif rcmaster_state == "y" then
                track_type = "rcmaster"
            elseif playback_state == "y" then
                track_type = "playback"
            end

            local _, rcm_disconnect = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
            local has_hyphen = (rcm_disconnect == "y")

            local display_name
            if track_type == "aux" or track_type == "submix" then
                display_name = name:gsub("^[@#]:?", ""):gsub("%-$", "")
            elseif track_type == "reference" then
                display_name = name:gsub("^REF:?", ""):gsub("%-$", "")
            elseif track_type == "roomtone" then
                display_name = ""
            elseif track_type == "live" then
                display_name = ""
            elseif track_type == "listenback" then
                display_name = ""
            elseif track_type == "rcmaster" then
                display_name = ""
            elseif track_type == "playback" then
                display_name = ""
            else
                display_name = name:gsub("%-$", "")
            end

            table.insert(tracks, {
                track = track,
                name = display_name,
                full_name = name,
                type = track_type,
                has_hyphen = has_hyphen,
                has_routing = has_routing,
                index = i
            })
        end
    end

    local type_priority = {
        aux = 1,
        submix = 1,
        roomtone = 3,
        rcmaster = 4,
        live = 5,
        reference = 6,
        listenback = 7,
        playback = 8
    }

    table.sort(tracks, function(a, b)
        local priority_a = type_priority[a.type] or 99
        local priority_b = type_priority[b.type] or 99
        if priority_a ~= priority_b then
            return priority_a < priority_b
        else
            return a.index < b.index
        end
    end)

    return tracks
end

function M.get_special_tracks_by_type(t)
    local result = {}
    for _, info in ipairs(M.get_special_tracks()) do
        if info.type == t then
            table.insert(result, info)
        end
    end
    return result
end

function M.resolve_special_index(list, num_str, type_label, num_prefix)
    if num_str ~= "" then
        local info = list[tonumber(num_str)]
        if info then return info end
        return nil, "No " .. type_label .. " track " .. num_prefix .. num_str
    end

    if #list == 0 then
        return nil, "No " .. type_label .. " track found"
    elseif #list == 1 then
        return list[1]
    end

    return nil, "Multiple " .. type_label .. " tracks in project. Add a number to specify which one to work on"
end

function M.build_track_table(is_empty)
    local track_table = {}
    local num_of_tracks = CountTracks(0)
    local rcmaster_index
    local j = 0
    local k = 1
    local prev_k = 1
    local groups_equal = true
    local mixer_tracks = {}
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, playback_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if parent == 1 then
            if j > 1 and k ~= prev_k then
                groups_equal = false
            end
            j = j + 1
            prev_k = k
            k = 1
            track_table[j] = { parent = track, tracks = {} }
            if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", tostring(k), true) end
        elseif M.trackname_check(track, "^M:") or mixer_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", true)
            local mod_name = string.match(name, "^M:(.*)") or name
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. mod_name, true)
            table.insert(mixer_tracks, track)
        elseif M.trackname_check(track, "^@") or aux_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:aux", "y", true)
            local mod_name = string.match(name, "@?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "@" .. mod_name, true)
        elseif M.trackname_check(track, "^#") or submix_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:submix", "y", true)
            local mod_name = string.match(name, "#?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "#" .. mod_name, true)
        elseif M.trackname_check(track, "^RoomTone") or rt_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "RoomTone", true)
        elseif M.trackname_check(track, "^LIVE") or live_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:live", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "LIVE", true)
        elseif M.trackname_check(track, "^REF") or ref_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "y", true)
            local mod_name = name:match("^REF:?(.*)") or name
            if name ~= "REF" then
                GetSetMediaTrackInfo_String(track, "P_NAME", "REF:" .. mod_name, true)
            end
        elseif M.trackname_check(track, "^LISTENBACK") or listenback_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "LISTENBACK", true)
        elseif M.trackname_check(track, "^PLAYBACK") or playback_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:playback", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "PLAYBACK", true)
        elseif M.trackname_check(track, "^RCMASTER") or rcmaster_state == "y" then
            rcmaster_index = i
        else
            if j > 0 then
                table.insert(track_table[j].tracks, track)
                if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", tostring(k + 1), true) end
            else
                groups_equal = false
            end
            k = k + 1
        end
    end
    if j > 1 and k ~= prev_k then
        groups_equal = false
    end
    return track_table, rcmaster_index, k, j, mixer_tracks, groups_equal
end

function M.get_track_table()
    local track_table, rcmaster_index, _, folder_count, mixer_tracks = M.build_track_table(false)
    local tracks_per_group = 1
    if track_table[1] then
        tracks_per_group = #track_table[1].tracks + 1
    end
    return track_table, rcmaster_index, folder_count, tracks_per_group, mixer_tracks
end

function M.route_to_track(src, dst)
    SetMediaTrackInfo_Value(src, "B_MAINSEND", 0)
    CreateTrackSend(src, dst)
end

function M.has_send_to(src, dst)
    local n = GetTrackNumSends(src, 0)
    for i = 0, n - 1 do
        if GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK") == dst then
            return true
        end
    end
    return false
end

function M.remove_send_to(src, dst)
    local n = GetTrackNumSends(src, 0)
    for i = n - 1, 0, -1 do
        if GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK") == dst then
            RemoveTrackSend(src, 0, i)
        end
    end
end

function M.find_send_index(src, dst)
    local n = GetTrackNumSends(src, 0)
    for i = 0, n - 1 do
        if GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK") == dst then
            return i
        end
    end
    return nil
end

function M.set_rcm_connection(track, connect)
    local rcmaster = M.get_rcmaster()
    if not rcmaster then return false end
    GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", connect and "" or "y", true)
    if connect then
        if not M.has_send_to(track, rcmaster) then
            M.route_to_track(track, rcmaster)
        end
    else
        M.remove_send_to(track, rcmaster)
    end
    return true
end

function M.set_hw_output(track, base_ch, mono)
    local num_hw_sends = GetTrackNumSends(track, 1)
    for j = num_hw_sends - 1, 0, -1 do
        RemoveTrackSend(track, 1, j)
    end
    if base_ch then
        local send_idx = CreateTrackSend(track, nil)
        SetTrackSendInfo_Value(track, 1, send_idx, "I_DSTCHAN", mono and (base_ch | 1024) or base_ch)
        SetTrackSendInfo_Value(track, 1, send_idx, "I_SRCCHAN", 0)
    end
end

function M.mixer_track_is_stereo(mixer_track)
    local source = M.get_source_for_mixer(mixer_track) or mixer_track
    local rec_input = math.floor(GetMediaTrackInfo_Value(source, "I_RECINPUT"))
    return (rec_input & 1024) ~= 0
end

function M.track_channel_width(track)
    local n = math.floor(GetMediaTrackInfo_Value(track, "I_NCHAN"))
    if n == 0 then n = 2 end
    return n
end

function M.resolve_target(token)
    if token == "rcm" then
        return M.get_rcmaster()
    end

    local aux_n = token:match("^@(%d*)$")
    if aux_n then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("aux"), aux_n, "aux", "@")
        return info and info.track, err
    end

    local sub_n = token:match("^#(%d*)$")
    if sub_n then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("submix"), sub_n, "submix", "#")
        return info and info.track, err
    end

    local mixer_n = token:match("^(%d+)$")
    if mixer_n then
        local mixer = M.get_mixer_tracks()
        return mixer[tonumber(mixer_n)]
    end

    local ref_n = token:match("^ref(%d*)$")
    if ref_n then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("reference"), ref_n, "reference", "ref")
        return info and info.track, err
    end

    if token == "rt" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("roomtone"), "", "RoomTone", "")
        return info and info.track, err
    end

    if token == "live" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("live"), "", "LIVE", "")
        return info and info.track, err
    end

    if token == "lb" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("listenback"), "", "Listenback", "")
        return info and info.track, err
    end

    if token == "pb" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("playback"), "", "Playback", "")
        return info and info.track, err
    end

    return nil
end

function M.expand_index_list(token, count)
    token = token:gsub("%s+", "")
    if token == "*" then
        local result = {}
        for n = 1, count do table.insert(result, n) end
        return result
    end

    local result = {}
    for part in token:gmatch("[^,]+") do
        local a, b = part:match("^(%d+)-(%d+)$")
        if a then
            for n = tonumber(a), tonumber(b) do table.insert(result, n) end
        else
            local n = tonumber(part)
            if n then table.insert(result, n) end
        end
    end
    return result
end

function M.parse_track_list(token)
    local mixer = M.get_mixer_tracks()
    local result = {}
    for _, n in ipairs(M.expand_index_list(token, #mixer)) do
        if mixer[n] then table.insert(result, mixer[n]) end
    end
    return result
end

function M.resolve_target_list(token)
    if token == "rcm" then
        local rcmaster = M.get_rcmaster()
        return rcmaster and { rcmaster } or {}
    end

    if token == "@" or token == "#" then
        local type_label = (token == "@") and "aux" or "submix"
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type(type_label), "", type_label, token)
        return info and { info.track } or {}, err
    end

    local aux_list = token:match("^@(.+)$")
    if aux_list then
        local specials = M.get_special_tracks_by_type("aux")
        local result = {}
        for _, n in ipairs(M.expand_index_list(aux_list, #specials)) do
            if specials[n] then table.insert(result, specials[n].track) end
        end
        return result
    end

    local sub_list = token:match("^#(.+)$")
    if sub_list then
        local specials = M.get_special_tracks_by_type("submix")
        local result = {}
        for _, n in ipairs(M.expand_index_list(sub_list, #specials)) do
            if specials[n] then table.insert(result, specials[n].track) end
        end
        return result
    end

    if token == "ref" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("reference"), "", "reference", "ref")
        return info and { info.track } or {}, err
    end

    local ref_list = token:match("^ref(.+)$")
    if ref_list then
        local specials = M.get_special_tracks_by_type("reference")
        local result = {}
        for _, n in ipairs(M.expand_index_list(ref_list, #specials)) do
            if specials[n] then table.insert(result, specials[n].track) end
        end
        return result
    end

    if token == "rt" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("roomtone"), "", "RoomTone", "")
        return info and { info.track } or {}, err
    end

    if token == "live" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("live"), "", "LIVE", "")
        return info and { info.track } or {}, err
    end

    if token == "lb" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("listenback"), "", "Listenback", "")
        return info and { info.track } or {}, err
    end

    if token == "pb" then
        local info, err = M.resolve_special_index(M.get_special_tracks_by_type("playback"), "", "Playback", "")
        return info and { info.track } or {}, err
    end

    return M.parse_track_list(token)
end

function M.split_word_target(cmd)
    local rest = cmd:match("^ref[%d,%*]*(.*)$")
    if rest then return cmd:sub(1, #cmd - #rest), rest end
    rest = cmd:match("^rcm(.*)$")
    if rest then return "rcm", rest end
    rest = cmd:match("^rt(.*)$")
    if rest then return "rt", rest end
    rest = cmd:match("^live(.*)$")
    if rest then return "live", rest end
    rest = cmd:match("^lb(.*)$")
    if rest then return "lb", rest end
    rest = cmd:match("^pb(.*)$")
    if rest then return "pb", rest end
    return nil, nil
end

function M.track_names_str(tracks)
    local names = {}
    for _, track in ipairs(tracks) do
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        table.insert(names, humanize_track_name(name))
    end
    return table.concat(names, ", ")
end

function M.expand_with_groups(tracks, aspect)
    local expanded, seen, group_names, seen_names = {}, {}, {}, {}
    for _, track in ipairs(tracks) do
        local targets, grouped, group_name = mm_groups.get_action_targets(track, aspect)
        for _, t in ipairs(targets) do
            if not seen[t] then
                seen[t] = true
                expanded[#expanded + 1] = t
            end
        end
        if grouped and not seen_names[group_name] then
            seen_names[group_name] = true
            group_names[#group_names + 1] = group_name
        end
    end
    return expanded, group_names
end

function M.group_names_suffix(group_names)
    if #group_names == 0 then return "" end
    if #group_names == 1 then return ", " .. group_names[1] .. " group" end
    return ", " .. table.concat(group_names, ", ") .. " groups"
end

function M.query_label(track, total)
    if total <= 1 then return "" end
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return humanize_track_name(name)
end

function M.label_prefix(label, sep)
    if label == "" then return "" end
    return label .. sep
end

function M.rename_mixer_position(mixer_tracks, position, new_name)
    local mixer_track = mixer_tracks[position]
    if not mixer_track then return false end

    local _, rcm_disconnect = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:rcm_disconnect", "", false)

    local clean_name = new_name:gsub("%-$", "")
    GetSetMediaTrackInfo_String(mixer_track, "P_NAME", "M:" .. clean_name, true)

    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then
            folder_number = folder_number + 1
            local track_index = i + (position - 1)
            local target_track = GetTrack(0, track_index)
            if target_track then
                GetSetMediaTrackInfo_String(target_track, "P_EXT:rcm_disconnect", rcm_disconnect, true)
                local prefix = ""
                local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
                if wf == "Vertical" then
                    if folder_number == 1 then
                        prefix = "D:"
                    else
                        prefix = "S" .. (folder_number - 1) .. ":"
                    end
                end
                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. clean_name, true)
            end
        end
    end
    return true
end

function M.get_items_at_midpoint(ref_item, folder_start, folder_end)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

function M.consolidate_folders_to_first()
    local num_tracks = CountTracks(0)
    local folders = {}

    local i = 0
    while i < num_tracks do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if folder_depth == 1 then
            local folder_info = { parent = track, children = {} }
            table.insert(folders, folder_info)

            i = i + 1
            local current_depth = 1
            while i < num_tracks and current_depth > 0 do
                local child_track = GetTrack(0, i)
                local child_depth = GetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH")
                table.insert(folder_info.children, child_track)
                current_depth = current_depth + child_depth
                if current_depth <= 0 then break end
                i = i + 1
            end
        end
        i = i + 1
    end

    if #folders < 2 then return end

    for _, folder in ipairs(folders) do
        local all_folder_tracks = { folder.parent }
        for _, child in ipairs(folder.children) do
            table.insert(all_folder_tracks, child)
        end

        local folder_item_set = {}
        for _, track in ipairs(all_folder_tracks) do
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                folder_item_set[item] = true
            end
        end

        local midpoint_groups = {}
        local seen = {}

        local folder_start_idx = GetMediaTrackInfo_Value(folder.parent, "IP_TRACKNUMBER") - 1
        local folder_end_idx = folder_start_idx
        for _, child in ipairs(folder.children) do
            folder_end_idx = GetMediaTrackInfo_Value(child, "IP_TRACKNUMBER") - 1
        end

        local parent_item_count = CountTrackMediaItems(folder.parent)
        for j = 0, parent_item_count - 1 do
            local ref_item = GetTrackMediaItem(folder.parent, j)
            if not seen[ref_item] then
                local peers = M.get_items_at_midpoint(ref_item, folder_start_idx, folder_end_idx)

                local group_items = {}
                for _, peer in ipairs(peers) do
                    if folder_item_set[peer] then
                        group_items[#group_items + 1] = peer
                        seen[peer] = true
                    end
                end
                local ref_pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
                table.insert(midpoint_groups, { items = group_items, ref_pos = ref_pos })
            end
        end

        local ungrouped_items = {}
        for _, track in ipairs(all_folder_tracks) do
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                if not seen[item] then
                    seen[item] = true
                    table.insert(ungrouped_items, item)
                end
            end
        end

        folder.midpoint_groups = midpoint_groups
        folder.ungrouped_items = ungrouped_items
    end

    local first_folder = folders[1]
    local first_folder_earliest = math.huge
    local latest_end = 0

    for _, group in ipairs(first_folder.midpoint_groups) do
        for _, item in ipairs(group.items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
            if pos < first_folder_earliest then first_folder_earliest = pos end
            if item_end > latest_end then latest_end = item_end end
        end
    end
    for _, item in ipairs(first_folder.ungrouped_items) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos < first_folder_earliest then first_folder_earliest = pos end
        if item_end > latest_end then latest_end = item_end end
    end

    if first_folder_earliest ~= 0 and first_folder_earliest ~= math.huge then
        local shift = -first_folder_earliest
        for _, group in ipairs(first_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                SetMediaItemInfo_Value(item, "D_POSITION", pos + shift)
            end
        end
        for _, item in ipairs(first_folder.ungrouped_items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", pos + shift)
        end
        latest_end = latest_end + shift
    end

    local first_folder_tracks = { first_folder.parent }
    for _, child in ipairs(first_folder.children) do
        table.insert(first_folder_tracks, child)
    end

    local current_position = (latest_end > 0) and (latest_end + 10) or 0

    for folder_idx = 2, #folders do
        local source_folder = folders[folder_idx]

        local folder_earliest = math.huge
        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                if pos < folder_earliest then folder_earliest = pos end
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if pos < folder_earliest then folder_earliest = pos end
        end

        local folder_offset = current_position - folder_earliest

        local source_folder_tracks = { source_folder.parent }
        for _, child in ipairs(source_folder.children) do
            table.insert(source_folder_tracks, child)
        end

        local function move_item_to_first_folder(item, new_pos)
            local source_track = GetMediaItem_Track(item)
            local source_track_pos = nil
            for idx, folder_track in ipairs(source_folder_tracks) do
                if folder_track == source_track then
                    source_track_pos = idx; break
                end
            end
            if source_track_pos and source_track_pos <= #first_folder_tracks then
                local dest_track = first_folder_tracks[source_track_pos]
                MoveMediaItemToTrack(item, dest_track)
                SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
            end
        end

        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                move_item_to_first_folder(item, original_pos + folder_offset)
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            move_item_to_first_folder(item, original_pos + folder_offset)
        end

        local folder_end = 0
        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                    GetMediaItemInfo_Value(item, "D_LENGTH")
                if item_end > folder_end then folder_end = item_end end
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                GetMediaItemInfo_Value(item, "D_LENGTH")
            if item_end > folder_end then folder_end = item_end end
        end

        current_position = folder_end + 10
    end

    Main_OnCommand(40297, 0)
    for folder_idx = 2, #folders do
        local folder = folders[folder_idx]
        local has_items = CountTrackMediaItems(folder.parent) > 0
        if not has_items then
            for _, child in ipairs(folder.children) do
                if CountTrackMediaItems(child) > 0 then
                    has_items = true; break
                end
            end
        end
        if not has_items then
            SetTrackSelected(folder.parent, true)
            for _, child in ipairs(folder.children) do
                SetTrackSelected(child, true)
            end
        end
    end

    Main_OnCommand(40005, 0)
    Main_OnCommand(40297, 0)
end

function M.get_source_for_mixer(mixer_track)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        for s = 0, GetTrackNumSends(t, 0) - 1 do
            if GetTrackSendInfo_Value(t, 0, s, "P_DESTTRACK") == mixer_track then
                return t
            end
        end
    end
    return nil
end

return M
