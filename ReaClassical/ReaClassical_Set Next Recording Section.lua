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
local main, get_last_item_end, get_last_item_end_in_folder
local set_group_state, find_folder_parents_indices
local next_section_vertical_horiz
local solo, mixer, get_color_table, get_path
local select_children_of_selected_folders, unselect_folder_children
local set_rec_arm_for_selected_tracks
local find_mixer_track_for_track, is_mixer_disabled

---------------------------------------------------------------------

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    MB("Please create a vertical workflow ReaClassical project using F8 to use this function.",
        "ReaClassical Error", 0)
    return
end

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local ref_is_guide = 0
if input ~= "" then
    local t = {}
    for entry in input:gmatch('([^,]+)') do t[#t + 1] = entry end
    if t[8] then ref_is_guide = tonumber(t[8]) or 0 end
end

---------------------------------------------------------------------

-- When "Record Takes Horizontally" is enabled in the Record Panel, Next Section
-- moves to the next folder down using exactly the same arming pipeline as
-- RC_Classical_Take_Record, then places the cursor after that folder's last item.
function next_section_vertical_horiz()
    local num_tracks = CountTracks(0)

    -- Find the currently selected folder-parent track (RC_Classical_Take_Record
    -- leaves the folder parent selected after arming).
    local selected_track = GetSelectedTrack(0, 0)
    if not selected_track then return end

    -- Ensure we have the folder parent, not a child
    if GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH") ~= 1 then
        local parent = GetParentTrack(selected_track)
        if parent then
            selected_track = parent
            SetOnlyTrackSelected(parent)
        else
            return
        end
    end

    -- Disarm the current folder using the same helpers RC_Classical_Take_Record uses
    select_children_of_selected_folders()
    set_rec_arm_for_selected_tracks(0)

    -- Walk forward from the track after the current folder parent to find the
    -- next folder parent — identical to the loop in RC_Classical_Take_Record.
    local current_num = GetMediaTrackInfo_Value(selected_track, "IP_TRACKNUMBER")
    local bool = false
    for i = current_num, num_tracks - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            Main_OnCommand(40297, 0) -- deselect all tracks
            SetTrackSelected(track, true)
            select_children_of_selected_folders()
            solo()
            set_rec_arm_for_selected_tracks(1)
            mixer()
            unselect_folder_children()
            Main_OnCommand(40913, 0) -- adjust scroll to selected tracks
            bool = true
            TrackList_AdjustWindows(false)
            break
        end
    end

    if not bool then
        -- No further folder: duplicate, exactly as RC_Classical_Take_Record does
        local duplicate = NamedCommandLookup("_RS2c6e13d20ab617b8de2c95a625d6df2fde4265ff")
        Main_OnCommand(duplicate, 0)
        select_children_of_selected_folders()
        set_rec_arm_for_selected_tracks(1)
        solo()
        unselect_folder_children()
        Main_OnCommand(40913, 0) -- adjust scroll to selected tracks
        TrackList_AdjustWindows(false)
    end

    -- Place edit cursor 1 second after the last item in the newly armed folder.
    -- GetSelectedTrack now points to the new folder parent.
    local new_folder = GetSelectedTrack(0, 0)
    if new_folder then
        local last_end = get_last_item_end_in_folder(new_folder)
        local new_pos = last_end and (last_end + 1.0) or 0.0
        SetEditCurPos(new_pos, true, false)
    end
end

---------------------------------------------------------------------

function main()

    if workflow ~= "Vertical" then
        MB("This function only runs on a vertical workflow project.", "ReaClassical Error", 0)
        return
    end

    -- When "Record Takes Horizontally" is enabled, Next Section moves to the next
    -- folder using the same arming logic as RC_Classical_Take_Record.
    local _, rth_val = GetProjExtState(0, "ReaClassical", "RecordTakesHorizontally")
    if rth_val == "1" then
        Undo_BeginBlock()
        next_section_vertical_horiz()
        UpdateArrange()
        UpdateTimeline()
        Undo_EndBlock("Next Section (horizontal takes mode)", -1)
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
    Main_OnCommand(40913, 0) -- scroll first group into view
    local last_end = get_last_item_end()
    if not last_end then
        MB("No media items in project. Not setting new edit cursor position.", "Set up next recording section", 0)
        return
    end
    local new_pos = last_end + 1.0
    SetEditCurPos(new_pos, true, false)

    TrackList_AdjustWindows(false)
    UpdateArrange()
    UpdateTimeline()
    Undo_EndBlock("Set up next recording section", -1)
end

---------------------------------------------------------------------

-- Returns the end position of the rightmost item across all tracks in the
-- folder whose parent is `folder_track`, or nil if the folder is empty.
function get_last_item_end_in_folder(folder_track)
    if not folder_track then return nil end

    local num_tracks = CountTracks(0)
    local folder_track_num = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
    local folder_end = num_tracks
    local depth = 1
    local t = folder_track_num + 1
    while t < num_tracks and depth > 0 do
        local tr = GetTrack(0, t)
        depth = depth + GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        if depth <= 0 then
            folder_end = t
            break
        end
        t = t + 1
    end

    local latest_end = nil
    for ti = folder_track_num, folder_end - 1 do
        local tr = GetTrack(0, ti)
        local item_count = CountTrackMediaItems(tr)
        for j = 0, item_count - 1 do
            local item = GetTrackMediaItem(tr, j)
            local item_end = GetMediaItemInfo_Value(item, "D_POSITION")
                           + GetMediaItemInfo_Value(item, "D_LENGTH")
            if not latest_end or item_end > latest_end then
                latest_end = item_end
            end
        end
    end

    return latest_end
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

function solo()
    local track = GetSelectedTrack(0, 0)
    if not track then return false end

    for i = 0, CountTracks(0) - 1 do
        track = GetTrack(0, i)
        local _, mixer_state    = GetSetMediaTrackInfo_String(track, "P_EXT:mixer",     "", false)
        local _, aux_state      = GetSetMediaTrackInfo_String(track, "P_EXT:aux",       "", false)
        local _, submix_state   = GetSetMediaTrackInfo_String(track, "P_EXT:submix",    "", false)
        local _, rt_state       = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone",  "", false)
        local _, live_state     = GetSetMediaTrackInfo_String(track, "P_EXT:live",      "", false)
        local _, ref_state      = GetSetMediaTrackInfo_String(track, "P_EXT:rcref",     "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster",  "", false)

        if IsTrackSelected(track) == false and mixer_state ~= "y" and aux_state ~= "y"
            and submix_state ~= "y" and rt_state ~= "y" and live_state ~= "y"
            and rcmaster_state ~= "y" then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
        end
        if live_state == "y" then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
        end
        if ref_state == "y" and ref_is_guide == 1 then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 1)
        end
    end
    return true
end

---------------------------------------------------------------------

function mixer()
    local colors = get_color_table()

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state    = GetSetMediaTrackInfo_String(track, "P_EXT:mixer",     "", false)
        local _, aux_state      = GetSetMediaTrackInfo_String(track, "P_EXT:aux",       "", false)
        local _, submix_state   = GetSetMediaTrackInfo_String(track, "P_EXT:submix",    "", false)
        local _, rt_state       = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone",  "", false)
        local _, live_state     = GetSetMediaTrackInfo_String(track, "P_EXT:live",      "", false)
        local _, ref_state      = GetSetMediaTrackInfo_String(track, "P_EXT:rcref",     "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster",  "", false)
        local _, guid           = GetSetMediaTrackInfo_String(track, "GUID",            "", false)

        local is_special_track = (aux_state == "y" or submix_state == "y" or rt_state == "y" or
            live_state == "y" or ref_state == "y" or rcmaster_state == "y")

        local mission_control_tcp_visible = nil
        if is_special_track then
            local _, tcp_vis_str = GetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid)
            if tcp_vis_str ~= "" then mission_control_tcp_visible = (tcp_vis_str == "1") end
        elseif mixer_state == "y" then
            local _, tcp_vis_str = GetProjExtState(0, "ReaClassical_MissionControl", "mixer_tcp_visible_" .. guid)
            if tcp_vis_str ~= "" then mission_control_tcp_visible = (tcp_vis_str == "1") end
        end

        local function tcp(default)
            if mission_control_tcp_visible ~= nil then
                return mission_control_tcp_visible and 1 or 0
            end
            return default
        end

        if mixer_state    == "y" then SetTrackColor(track, colors.mixer);    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", tcp(0)) end
        if aux_state      == "y" then SetTrackColor(track, colors.aux);      SetMediaTrackInfo_Value(track, "B_SHOWINTCP", tcp(0)) end
        if submix_state   == "y" then SetTrackColor(track, colors.submix);   SetMediaTrackInfo_Value(track, "B_SHOWINTCP", tcp(0)) end
        if rt_state       == "y" then SetTrackColor(track, colors.roomtone); SetMediaTrackInfo_Value(track, "B_SHOWINTCP", tcp(1)) end
        if live_state     == "y" then SetTrackColor(track, colors.live);     SetMediaTrackInfo_Value(track, "B_SHOWINTCP", tcp(1)) end
        if ref_state      == "y" then SetTrackColor(track, colors.ref);      SetMediaTrackInfo_Value(track, "B_SHOWINTCP", tcp(1)) end
        if rcmaster_state == "y" then SetTrackColor(track, colors.rcmaster); SetMediaTrackInfo_Value(track, "B_SHOWINTCP", tcp(0)) end

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rcmaster_state == "y"
            or rt_state == "y" or live_state == "y" or ref_state == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
        else
            SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
        end

        local _, source_track = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", false)
        local _, trackname    = GetSetMediaTrackInfo_String(track, "P_NAME",       "", false)
        if trackname:find("^S%d+:") or source_track == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end

        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        local parent_folder_visible = true

        if wf == "Vertical" then
            local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

            if folder_depth ~= 1 then
                local search_idx = i - 1
                while search_idx >= 0 do
                    local pt = GetTrack(0, search_idx)
                    if GetMediaTrackInfo_Value(pt, "I_FOLDERDEPTH") == 1 then
                        local _, pguid = GetSetMediaTrackInfo_String(pt, "GUID", "", false)
                        local _, fvs = GetProjExtState(0, "ReaClassical_MissionControl",
                            "folder_tcp_visible_" .. pguid)
                        if fvs ~= "" then parent_folder_visible = (fvs == "1") end
                        break
                    end
                    search_idx = search_idx - 1
                end
            end

            if folder_depth == 1 then
                local _, fvs = GetProjExtState(0, "ReaClassical_MissionControl",
                    "folder_tcp_visible_" .. guid)
                if fvs ~= "" then
                    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (fvs == "1") and 1 or 0)
                end
            else
                if not parent_folder_visible and not is_special_track and mixer_state ~= "y" then
                    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
                end
            end
        end
    end
end

---------------------------------------------------------------------

function select_children_of_selected_folders()
    local track_count = CountTracks(0)
    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) then
            if GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") == 1 then
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
end

---------------------------------------------------------------------

function unselect_folder_children()
    local num_tracks = CountTracks(0)
    local depth = 0
    local unselect_mode = false

    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if IsTrackSelected(tr) and folder_change == 1 then
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        if folder_change > 0 then
            depth = depth + folder_change
        elseif folder_change < 0 then
            depth = depth + folder_change
            if depth <= 0 then
                unselect_mode = false
                depth = 0
            end
        end
    end
end

---------------------------------------------------------------------

function find_mixer_track_for_track(track)
    local num_sends = GetTrackNumSends(track, 0)
    for i = 0, num_sends - 1 do
        local dest_track = GetTrackSendInfo_Value(track, 0, i, "P_DESTTRACK")
        if dest_track then
            local _, mixer_state = GetSetMediaTrackInfo_String(dest_track, "P_EXT:mixer", "", false)
            if mixer_state == "y" then return dest_track end
        end
    end
    return nil
end

---------------------------------------------------------------------

function is_mixer_disabled(mixer_track)
    if not mixer_track then return false end
    local _, disabled_state = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:input_disabled", "", false)
    return (disabled_state == "y")
end

---------------------------------------------------------------------

function set_rec_arm_for_selected_tracks(state)
    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if IsTrackSelected(track) then
            local mixer_track = find_mixer_track_for_track(track)
            if state == 1 and is_mixer_disabled(mixer_track) then
                SetMediaTrackInfo_Value(track, "I_RECARM", 0)
            else
                SetMediaTrackInfo_Value(track, "I_RECARM", state)
            end
        end
    end
    UpdateArrange()
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1)
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

main()