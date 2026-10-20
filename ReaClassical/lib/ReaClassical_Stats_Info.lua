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

local enum_project_markers = require("ReaClassical_Marker_Enum")

local M = {}

-- Same rule as Create CD Markers: on the first track, an item starting more than
-- this many seconds after the previous item ends is not part of the album.
local ALBUM_MAX_GAP = 60

M.SECTIONS = {
    { header = "Album Stats", fields = {
        { label = "Final album length",    key = "album_end" },
        { label = "Number of CD markers",  key = "num_cd_markers" },
        { label = "Items outside the album",            key = "num_items_outside_album" },
        { label = "Length of material outside the album", key = "outside_album_length" },
    } },
    { header = "Project Stats", fields = {
        { label = "Project age",                          key = "project_age" },
        { label = "Session time",                          key = "session_time" },
        { label = "Total project length",                  key = "total_project_length" },
        { label = "Total length of all source material",   key = "total_source_length" },
        { label = "Total number of items",                 key = "num_items" },
        { label = "Number of track folders",                key = "folder_count" },
        { label = "Number of tracks per group",             key = "tracks_per_group" },
        { label = "Number of special tracks",               key = "special_tracks" },
        { label = "Number of regions",                      key = "num_regions" },
    } },
    { header = "Edit Stats", fields = {
        { label = "Number of dest S-D edits",   key = "num_sd_edits" },
        { label = "Number of dest item splits", key = "num_splits" },
    } },
    { header = "FX & Automation", fields = {
        { label = "Total FX count",         key = "num_fx" },
        { label = "Total automation lanes", key = "num_automation_lanes" },
    } },
}

do
    local retval, existing = GetProjExtState(0, "ReaClassical", "SessionStart")
    if not retval or existing == "" then
        SetProjExtState(0, "ReaClassical", "SessionStart", tostring(os.time()))
    end
end

function M.reset_session_timer()
    SetProjExtState(0, "ReaClassical", "SessionStart", tostring(os.time()))
end

local function get_session_time()
    local retval, stored = GetProjExtState(0, "ReaClassical", "SessionStart")
    if retval and stored ~= "" then
        local start = tonumber(stored)
        if start then
            local seconds = os.time() - start
            local h = math.floor(seconds / 3600)
            local m = math.floor((seconds % 3600) / 60)
            return string.format("%dh %02dm", h, m)
        end
    end
    return "n/a"
end

local function get_reaper_version()
    local version_str = GetAppVersion()
    local version = version_str:match("^(%d+%.%d+)")
    return tonumber(version)
end

local function get_reaclassical_version()
    local reapack_exists = APIExists("ReaPack_GetOwner")
    if not reapack_exists then
        return "n/a (ReaPack API not found)"
    end

    local script_path = ({ get_action_context() })[2]
    if not script_path or script_path == "" then
        return "n/a"
    end

    local entry = ReaPack_GetOwner(script_path)
    if not entry then
        return "n/a (not installed via ReaPack)"
    end

    local retval, _repo, _cat, _pkg, _desc, _type, version = ReaPack_GetEntryInfo(entry)
    ReaPack_FreeEntry(entry)

    if retval and version and version ~= "" then
        return version
    end

    return "n/a"
end

local function format_time(seconds)
    if not seconds then return "n/a" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function get_project_age()
    local retval, creation_date = GetProjExtState(0, "ReaClassical", "CreationDate")
    if retval and creation_date ~= "" then
        local year, month, day, hour, min, sec = creation_date:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if year and month and day and hour and min and sec then
            local creation_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })
            local age_seconds = os.time() - creation_time
            local days = math.floor(age_seconds / 86400)
            if days >= 365 then
                return "> 1 year"
            end
            local hours = math.floor((age_seconds % 86400) / 3600)
            local minutes = math.floor((age_seconds % 3600) / 60)
            return string.format("%d days, %d hours, %d minutes", days, hours, minutes)
        end
    end
    return "n/a"
end

function M.calculate()
    local project_age = get_project_age()
    local session_time = get_session_time()
    local reaper_version = get_reaper_version()
    local reaclassical_version = get_reaclassical_version()

    local num_items, num_tracks = CountMediaItems(0), CountTracks(0)
    local num_cd_markers, num_sd_edits, num_splits, num_regions = 0, 0, 0, 0
    local num_fx, num_automation_lanes, total_source_length, total_project_length, album_end = 0, 0, 0, 0, nil
    local folder_count = 0
    local num_items_outside_album, outside_album_length = 0, 0

    for i = 0, num_items - 1 do
        local item = GetMediaItem(0, i)
        if item then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            total_project_length = math.max(total_project_length, item_pos + item_len)
        end
    end

    local num_markers = GetNumRegionsOrMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, _, name, _ = enum_project_markers(0, i)
        if retval then
            if name:match("^#") then
                num_cd_markers = num_cd_markers + 1
            elseif name == "=END" then
                album_end = pos
            end
            if isrgn then
                num_regions = num_regions + 1
            end
        end
    end

    if num_tracks > 0 then
        local first_track = GetTrack(0, 0)
        local track_items = CountTrackMediaItems(first_track)
        local prev_end = nil
        local album_prev_end, past_album = nil, false
        for j = 0, track_items - 1 do
            local item = GetTrackMediaItem(first_track, j)
            if item then
                local retval, sd_edit = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
                if retval and sd_edit ~= "" then
                    num_sd_edits = num_sd_edits + 1
                end

                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_end = item_pos + GetMediaItemInfo_Value(item, "D_LENGTH")
                if prev_end and item_pos < prev_end then
                    num_splits = num_splits + 1
                end
                prev_end = prev_end and math.max(prev_end, item_end) or item_end

                if album_prev_end and item_pos - album_prev_end > ALBUM_MAX_GAP then
                    past_album = true
                end
                if past_album then
                    num_items_outside_album = num_items_outside_album + 1
                    outside_album_length = outside_album_length + (item_end - item_pos)
                else
                    album_prev_end = item_end
                end
            end
        end
    end

    local tracks_per_group = 0
    local in_first_folder = false

    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if track then
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

            if depth == 1 then
                folder_count = folder_count + 1
                if folder_count == 1 then
                    in_first_folder = true
                else
                    in_first_folder = false
                end
            end

            if in_first_folder then
                tracks_per_group = tracks_per_group + 1
                if depth < 0 then
                    in_first_folder = false
                end
            end

            if folder_count > 1 then
                local track_items = CountTrackMediaItems(track)
                for j = 0, track_items - 1 do
                    local item = GetTrackMediaItem(track, j)
                    if item then
                        total_source_length = total_source_length + GetMediaItemInfo_Value(item, "D_LENGTH")
                    end
                end
            end

            num_fx = num_fx + TrackFX_GetCount(track)
            local num_envelopes = CountTrackEnvelopes(track)
            for e = 0, num_envelopes - 1 do
                local env = GetTrackEnvelope(track, e)
                if env then
                    local _, chunk = GetEnvelopeStateChunk(env, "", false)
                    if chunk:match("VIS 1") and CountEnvelopePoints(env) > 0 then
                        num_automation_lanes = num_automation_lanes + 1
                    end
                end
            end
        end
    end

    local special_tracks = num_tracks - (folder_count * tracks_per_group)

    return {
        reaper_version = reaper_version,
        reaclassical_version = reaclassical_version,
        album_end = format_time(album_end),
        num_cd_markers = num_cd_markers,
        num_items_outside_album = num_items_outside_album,
        outside_album_length = format_time(outside_album_length),
        project_age = project_age,
        session_time = session_time,
        total_project_length = format_time(total_project_length),
        total_source_length = format_time(total_source_length),
        num_items = num_items,
        folder_count = folder_count,
        tracks_per_group = tracks_per_group,
        special_tracks = special_tracks,
        num_regions = num_regions,
        num_sd_edits = num_sd_edits,
        num_splits = num_splits,
        num_fx = num_fx,
        num_automation_lanes = num_automation_lanes
    }
end

function M.version_text(stats)
    return "ReaClassical " .. stats.reaclassical_version .. " | REAPER " .. stats.reaper_version
end

function M.stats_text(stats)
    local lines = { "ReaClassical Project Statistics", "" }
    for _, section in ipairs(M.SECTIONS) do
        lines[#lines + 1] = section.header .. ":"
        for _, f in ipairs(section.fields) do
            lines[#lines + 1] = "- " .. f.label .. ": " .. tostring(stats[f.key])
        end
        lines[#lines + 1] = ""
    end
    table.remove(lines)
    return table.concat(lines, "\n")
end

return M
