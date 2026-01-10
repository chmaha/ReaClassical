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

local main, format_time, get_project_age, calculate_stats

---------------------------------------------------------------------

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('ReaClassical Stats')
local window_open = true

local stats = {}

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

---------------------------------------------------------------------

function calculate_stats()
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
            num_automation_lanes = num_automation_lanes + CountTrackEnvelopes(track)
        end
    end

    local special_tracks = num_tracks - (folder_count * tracks_per_group) - tracks_per_group - 1

    stats = {
        album_end = format_time(album_end),
        num_cd_markers = num_cd_markers,
        project_age = project_age,
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

---------------------------------------------------------------------

function main()
    if window_open then
        -- Center window every time it opens
        local viewport = ImGui.GetMainViewport(ctx)
        local work_x, work_y = ImGui.Viewport_GetWorkPos(viewport)
        local work_w, work_h = ImGui.Viewport_GetWorkSize(viewport)
        
        -- Estimate window size for centering
        local estimated_w = 200
        local estimated_h = 500
        
        local center_x = work_x + (work_w - estimated_w) / 2
        local center_y = work_y + (work_h - estimated_h) / 2
        
        ImGui.SetNextWindowPos(ctx, center_x, center_y, ImGui.Cond_Once)

        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Project Statistics", window_open, ImGui.WindowFlags_AlwaysAutoResize)
        window_open = open_ref

        if opened then
            -- Album Stats Section
            ImGui.Text(ctx, "Album Stats:")
            ImGui.Text(ctx, "- Final album length: " .. stats.album_end)
            ImGui.Text(ctx, "- Number of CD markers: " .. tostring(stats.num_cd_markers))
            ImGui.Spacing(ctx)

            -- Project Stats Section
            ImGui.Text(ctx, "Project Stats:")
            ImGui.Text(ctx, "- Project age: " .. stats.project_age)
            ImGui.Text(ctx, "- Total project length: " .. stats.total_project_length)
            ImGui.Text(ctx, "- Total length of all source material: " .. stats.total_source_length)
            ImGui.Text(ctx, "- Total number of items: " .. tostring(stats.num_items))
            ImGui.Text(ctx, "- Number of track folders: " .. tostring(stats.folder_count))
            ImGui.Text(ctx, "- Number of tracks per group: " .. tostring(stats.tracks_per_group))
            ImGui.Text(ctx, "- Number of special tracks: " .. tostring(stats.special_tracks))
            ImGui.Text(ctx, "- Number of regions: " .. tostring(stats.num_regions))
            ImGui.Spacing(ctx)

            -- Edit Stats Section
            ImGui.Text(ctx, "Edit Stats:")
            ImGui.Text(ctx, "- Number of dest S-D edits: " .. tostring(stats.num_sd_edits))
            ImGui.Text(ctx, "- Number of dest item splits: " .. tostring(stats.num_splits))
            ImGui.Spacing(ctx)

            -- FX & Automation Section
            ImGui.Text(ctx, "FX & Automation:")
            ImGui.Text(ctx, "- Total FX count: " .. tostring(stats.num_fx))
            ImGui.Text(ctx, "- Total automation lanes: " .. tostring(stats.num_automation_lanes))
            ImGui.Spacing(ctx)

            -- Refresh button
            if ImGui.Button(ctx, "Refresh", 80, 0) then
                calculate_stats()
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

PreventUIRefresh(1)
calculate_stats()
PreventUIRefresh(-1)
UpdateArrange()
UpdateTimeline()
defer(main)