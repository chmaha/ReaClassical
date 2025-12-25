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

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
    return
end

set_action_options(2)

package.path        = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui         = require 'imgui' '0.10'
local main

---------------------------------------------------------------------

local ctx           = ImGui.CreateContext('ReaClassical Notes Window')
local window_open   = true

local DEFAULT_W     = 350
local DEFAULT_H     = 375

local MIN_H_PROJECT = 60
local MIN_H_TRACK   = 80
local MIN_H_ITEM    = 80

local track_note    = ""
local item_note     = ""
local item_rank     = 9 -- Default to "No Rank"

local editing_track = nil
local editing_item  = nil

-- Rank color options (matching SAI marker manager)
local RANKS = {
    { name = "Excellent",     rgba = 0x39FF1499 }, -- Bright lime green
    { name = "Very Good",     rgba = 0x32CD3299 }, -- Lime green
    { name = "Good",          rgba = 0x00AD8399 }, -- Teal green
    { name = "OK",            rgba = 0xFFFFAA99 }, -- Soft yellow
    { name = "Below Average", rgba = 0xFFBF0099 }, -- Gold/amber
    { name = "Poor",          rgba = 0xFF753899 }, -- Orange
    { name = "Unusable",      rgba = 0xDC143C99 }, -- Crimson red
    { name = "False Start",   rgba = 0x808080FF }, -- Grey
    { name = "No Rank",       rgba = 0x00000000 }  -- Transparent
}

---------------------------------------------------------------------

function main()
    local item         = GetSelectedMediaItem(0, 0)
    local track        = GetSelectedTrack(0, 0)
    local proj         = 0

    local project_note = GetSetProjectNotes(proj, false, "")

    -- Safety: check if last edited item/track still exists
    if editing_item and not ValidatePtr2(0, editing_item, "MediaItem*") then
        editing_item = nil
        item_note = ""
        item_rank = 9
    end

    if editing_track and not ValidatePtr2(0, editing_track, "MediaTrack*") then
        editing_track = nil
        track_note = ""
    end

    if editing_track ~= track then
        ImGui.SetWindowFocus(ctx)
        if editing_track then
            GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
        end

        editing_track = track
        if track then
            local _, note = GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", "", false)
            track_note = note
        end
    end

    if editing_item ~= item then
        ImGui.SetWindowFocus(ctx)
        if editing_item then
            GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_rank", tostring(item_rank), true)
        end

        editing_item = item
        if item then
            local _, note = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
            item_note = note
            
            local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
            item_rank = tonumber(rank_str) or 9
        else
            item_rank = 9
        end
    end

    if window_open then
        local _, FLT_MAX = ImGui.NumericLimits_Float()
        ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)
        local opened, open_ref = ImGui.Begin(ctx, "ReaClassical Notes", window_open)
        window_open = open_ref

        if opened then
            local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

            -- Add extra space for rank combo box
            local static_height    = 4 * ImGui.GetTextLineHeightWithSpacing(ctx) + 50
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

            -- ITEM RANK (only show if item is selected)
            if editing_item then
                ImGui.Text(ctx, "Item Rank:")
                ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, RANKS[item_rank].rgba)
                ImGui.SetNextItemWidth(ctx, avail_w)
                if ImGui.BeginCombo(ctx, "##item_rank", RANKS[item_rank].name) then
                    for i, rank in ipairs(RANKS) do
                        ImGui.PushStyleColor(ctx, ImGui.Col_Header, rank.rgba)
                        local is_selected = (item_rank == i)
                        if ImGui.Selectable(ctx, rank.name, is_selected) then
                            item_rank = i
                            GetSetMediaItemInfo_String(editing_item, "P_EXT:item_rank", tostring(item_rank), true)
                        end
                        if is_selected then
                            ImGui.SetItemDefaultFocus(ctx)
                        end
                        ImGui.PopStyleColor(ctx)
                    end
                    ImGui.EndCombo(ctx)
                end
                ImGui.PopStyleColor(ctx)
                
                -- ITEM NOTE
                ImGui.Text(ctx, "Item Note:")
                local changed_item
                changed_item, item_note = ImGui.InputTextMultiline(ctx, "##item_note", item_note, avail_w, h_item)
                if changed_item and editing_item then
                    GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
                end
            end

            ImGui.End(ctx)
        end

        defer(main)
    end
end

---------------------------------------------------------------------

defer(main)