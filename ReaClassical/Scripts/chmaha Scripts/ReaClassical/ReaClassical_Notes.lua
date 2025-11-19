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
package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'
local main

---------------------------------------------------------------------

local ctx           = ImGui.CreateContext('ReaClassical Notes Window')
local window_open   = true

local DEFAULT_W     = 350
local DEFAULT_H     = 375

local MIN_H_PROJECT = 60
local MIN_H_TRACK   = 80
local MIN_H_ITEM    = 80

local project_note  = ""
local track_note    = ""
local item_note     = ""

local editing_track = nil
local editing_item  = nil

---------------------------------------------------------------------

function main()
    local item  = GetSelectedMediaItem(0, 0)
    local track = GetSelectedTrack(0, 0)
    local proj  = 0

    if project_note == "" then
        local _, str = GetSetProjectNotes(proj, false, "")
        project_note = str or ""
    end

    if editing_track ~= track then
        ImGui.SetWindowFocus(ctx)
        if editing_track then
            GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
        end

        editing_track = track
        if track then
            local _, str = GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", "", false)
            track_note = str or ""
        else
            track_note = ""
        end
    end

    if editing_item ~= item then
        ImGui.SetWindowFocus(ctx)
        if editing_item then
            GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
        end

        editing_item = item
        if item then
            local _, str = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
            item_note = str or ""
        else
            item_note = ""
        end
    end

    if window_open then
        local FLT_MAX = 3.402823466e+38
        ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)
        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Notes", window_open)
        window_open = open_ref

        if opened then
            local avail_w, avail_h = ImGui_GetContentRegionAvail(ctx)

            local static_height    = 3 * ImGui_GetTextLineHeightWithSpacing(ctx) + 40
            local dynamic_h        = math.max(0, avail_h - static_height)

            local base_total       = MIN_H_PROJECT + MIN_H_TRACK + MIN_H_ITEM
            local extra            = math.max(0, dynamic_h - base_total)

            local h_project        = math.max(MIN_H_PROJECT, MIN_H_PROJECT + extra * 0.2)
            local h_track          = math.max(MIN_H_TRACK, MIN_H_TRACK + extra * 0.4)
            local h_item           = math.max(MIN_H_ITEM, MIN_H_ITEM + extra * 0.4)

            -- PROJECT NOTE
            ImGui.Text(ctx, "Project Note:")
            local changed_project
            changed_project, project_note = ImGui.InputTextMultiline(ctx, "##project_note", project_note, avail_w,
            h_project)
            if changed_project then
                GetSetProjectNotes(proj, true, project_note)
            end

            -- TRACK NOTE
            ImGui.Text(ctx, "Track Note:")
            local changed_track
            changed_track, track_note = ImGui.InputTextMultiline(ctx, "##track_note", track_note, avail_w, h_track)
            if changed_track and editing_track then
                GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
            end


            -- ITEM NOTE
            ImGui.Text(ctx, "Item Note:")
            local changed_item
            changed_item, item_note = ImGui.InputTextMultiline(ctx, "##item_note", item_note, avail_w, h_item)
            if changed_item and editing_item then
                GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

defer(main)
