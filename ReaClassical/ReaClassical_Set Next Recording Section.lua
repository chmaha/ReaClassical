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
local main, get_last_item_end
local set_group_state, find_folder_parents_indices

---------------------------------------------------------------------

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    MB("Please create a vertical workflow ReaClassical project using F8 to use this function.",
        "ReaClassical Error", 0)
    return
end

---------------------------------------------------------------------

function main()

    if workflow ~= "Vertical" then
        MB("This function only runs on a vertical workflow project.", "ReaClassical Error", 0)
        return
    end

    Undo_BeginBlock()

    local parents = find_folder_parents_indices()
    if #parents == 0 then
        MB("No folder parent tracks (groups) found. Only moved edit cursor.", "Set up next recording section", 0)
        return
    end

    for idx, parent_idx in ipairs(parents) do
        if idx == 2 then
            set_group_state(parent_idx, true, false)
        else
            set_group_state(parent_idx, false, true)
        end
    end

    if CountTracks(0) > 0 then
        Main_OnCommand(40297, 0) -- Unselect all tracks
        local second_parent_idx = parents[2]
        if second_parent_idx then
            local second_parent = GetTrack(0, second_parent_idx)
            if second_parent then
                SetTrackSelected(second_parent, true)
            end
        end
    end
    Main_OnCommand(40913,0) -- scroll first group into view
    local last_end = get_last_item_end()
    if not last_end then
        MB("No media items in project. Not setting new edit cursor position.", "Set up next recording section", 0)
        return
    end
    local new_pos = last_end + 5.0 -- Move edit cursor to 5 seconds after the last item end
    SetEditCurPos(new_pos, true, false)

    TrackList_AdjustWindows(false)
    UpdateArrange()
    UpdateTimeline()
    Undo_EndBlock("Set up next recording section", -1)
end

---------------------------------------------------------------------

function get_last_item_end()
    local total_items = CountMediaItems(0)
    if total_items == 0 then return nil end

    local max_end = -1
    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if item then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION") or 0
            local len = GetMediaItemInfo_Value(item, "D_LENGTH") or 0
            local e = pos + len
            if e > max_end then max_end = e end
        end
    end
    return max_end
end

---------------------------------------------------------------------

function set_group_state(parent_idx, enable_rec, mute_group)
    local tcount = CountTracks(0)
    if parent_idx < 0 or parent_idx >= tcount then return end

    local parent = GetTrack(0, parent_idx)
    if not parent then return end

    SetMediaTrackInfo_Value(parent, "I_RECARM", enable_rec and 1 or 0)
    SetMediaTrackInfo_Value(parent, "B_MUTE", mute_group and 1 or 0)

    local depth = 0
    for i = parent_idx + 1, tcount - 1 do
        local track = GetTrack(0, i)
        if not track then break end
        local fd = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        SetMediaTrackInfo_Value(track, "I_RECARM", enable_rec and 1 or 0)
        SetMediaTrackInfo_Value(track, "B_MUTE", mute_group and 1 or 0)

        if fd == 1 then
            depth = depth + 1
        elseif fd == -1 then
            if depth <= 0 then
                break
            else
                depth = depth - 1
            end
        end
    end
end

---------------------------------------------------------------------

function find_folder_parents_indices()
    local parents = {}
    local tcount = CountTracks(0)
    for i = 0, tcount - 1 do
        local tr = GetTrack(0, i)
        if tr then
            local fd = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if fd == 1 then
                parents[#parents + 1] = i
            end
        end
    end
    return parents
end

---------------------------------------------------------------------

main()
