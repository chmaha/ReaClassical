--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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
local main, format_time, get_project_age, reaclassical_get_stats

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    reaclassical_get_stats()
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function format_time(seconds)
    if not seconds then return "n/a" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

---------------------------------------------------------------------

function get_project_age()
    local retval, creation_date = GetProjExtState(0, "ReaClassical", "CreationDate")
    if retval and creation_date ~= "" then
        local year, month, day, hour, min, sec = creation_date:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if year and month and day and hour and min and sec then
            local creation_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour =
                    tonumber(hour),
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

---------------------------------------------------------------------

function reaclassical_get_stats()
    local project_age = get_project_age()

    local num_items, num_tracks = CountMediaItems(0), CountTracks(0)
    local num_cd_markers, num_sd_edits, num_splits, num_regions = 0, 0, 0, 0
    local num_fx, num_automation_lanes, total_source_length, total_project_length, album_end = 0, 0, 0, 0, nil
    local folder_count = 0

    for i = 0, num_items - 1 do
        local item = GetMediaItem(0, i)
        if item then
            local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
            total_project_length = math.max(total_project_length, item_pos + item_len)
        end
    end

    local num_markers = CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, _, name, _ = EnumProjectMarkers(i)
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
        for j = 0, track_items - 1 do
            local item = GetTrackMediaItem(first_track, j)
            if item then
                local retval, sd_edit = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
                if retval and sd_edit ~= "" then
                    num_sd_edits = num_sd_edits + 1
                end
            end
        end

        for j = 0, track_items - 1 do
            local item1 = GetTrackMediaItem(first_track, j)
            if item1 then
                local item1_pos = GetMediaItemInfo_Value(item1, "D_POSITION")
                local item1_end = item1_pos + GetMediaItemInfo_Value(item1, "D_LENGTH")
                for k = j + 1, track_items - 1 do
                    local item2 = GetTrackMediaItem(first_track, k)
                    if item2 then
                        local item2_pos = GetMediaItemInfo_Value(item2, "D_POSITION")
                        if item2_pos < item1_end then
                            num_splits = num_splits + 1
                        end
                    end
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
            end

            if folder_count > 1 then -- Exclude the first folder for total_source_length
                local track_items = CountTrackMediaItems(track)
                for j = 0, track_items - 1 do
                    local item = GetTrackMediaItem(track, j)
                    if item then
                        total_source_length = total_source_length + GetMediaItemInfo_Value(item, "D_LENGTH")
                    end
                end
            end

            num_fx = num_fx + TrackFX_GetCount(track)
            num_automation_lanes = num_automation_lanes + CountTrackEnvelopes(track)
        end
    end

    local special_tracks = num_tracks - (folder_count * tracks_per_group) - tracks_per_group - 1
    local msg = string.format(
        "Album Stats:\n"
        .. "- Final album length: %s\n"
        .. "- Number of CD markers: %d\n\n"
        .. "Project Stats:\n"
        .. "- Project age: %s\n"
        .. "- Total project length: %s\n"
        .. "- Total length of all source material: %s\n"
        .. "- Total number of items: %d\n"
        .. "- Number of track folders: %d\n"
        .. "- Number of tracks per group: %d\n"
        .. "- Number of special tracks: %d\n"
        .. "- Number of regions: %d\n\n"
        .. "Edit Stats:\n"
        .. "- Number of dest S-D edits: %d\n"
        .. "- Number of dest item splits: %d\n\n"
        .. "FX & Automation:\n"
        .. "- Total FX count: %d\n"
        .. "- Total automation lanes: %d",
        format_time(album_end), num_cd_markers,
        project_age, format_time(total_project_length), format_time(total_source_length), num_items,
        folder_count, tracks_per_group, special_tracks, num_regions,
        num_sd_edits, num_splits,
        num_fx, num_automation_lanes
    )

    MB(msg, "ReaClassical Stats", 0)
end

---------------------------------------------------------------------

main()
