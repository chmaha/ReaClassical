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

local main, solo, trackname_check, mixer, on_stop
local get_color_table, get_path, select_next_item
local get_selected_media_item_at, unselect_folder_children
local select_children_of_selected_folders, select_prev_item

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local _, mastering = GetProjExtState(0, "ReaClassical", "MasteringModeSet")
mastering = (mastering ~= "" and tonumber(mastering)) or 0
local ref_is_guide = 0
local audition_speed = 0.75
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[7] then ref_is_guide = tonumber(table[7]) or 0 end
    if table[9] then audition_speed = tonumber(table[9]) or 0.75 end
end

function main()
    Undo_BeginBlock()
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
    PreventUIRefresh(1)
    CSurf_OnPlayRateChange(audition_speed)
    local group_state = GetToggleCommandState(1156)
    if group_state ~= 1 then
        Main_OnCommand(1156, 0) -- Enable item grouping
    end
    local pos = BR_PositionAtMouseCursor(false)
    local screen_x, screen_y = GetMousePosition()
    local track = GetTrackFromPoint(screen_x, screen_y)
    if track then
        SetOnlyTrackSelected(track)
        solo()
        select_children_of_selected_folders()
        mixer()
        unselect_folder_children()
        SetEditCurPos(pos, 0, 0)
        OnPlayButton()
        PreventUIRefresh(-1)
        Undo_EndBlock('Audition', 0)
        UpdateArrange()
        UpdateTimeline()
        TrackList_AdjustWindows(false)
    end
end

---------------------------------------------------------------------

function solo()
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or rcmaster_state == "y") then
            if IsTrackSelected(track) and parent ~= 1 then
                SetMediaTrackInfo_Value(track, "I_SOLO", 2)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if rt_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if ref_state == "y" then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0) -- unsolo all tracks
                mute_state = 0
                solo_state = 1
            elseif ref_is_guide == 1 then
                mute_state = 0
                solo_state = 0
            end

            SetMediaTrackInfo_Value(track, "B_MUTE", mute_state)
            SetMediaTrackInfo_Value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function mixer()
    local colors = get_color_table()
    
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
        
        -- Check if this is a special track that should respect Mission Control TCP visibility
        local is_special_track = (aux_state == "y" or submix_state == "y" or rt_state == "y" or 
                                  live_state == "y" or ref_state == "y" or rcmaster_state == "y")
        
        -- Get Mission Control TCP visibility setting for special tracks
        local mission_control_tcp_visible = nil
        if is_special_track then
            local _, tcp_vis_str = GetProjExtState(0, "ReaClassical_MissionControl", "tcp_visible_" .. guid)
            if tcp_vis_str ~= "" then
                mission_control_tcp_visible = (tcp_vis_str == "1")
            end
        end
        
        if mixer_state == "y" then
            SetTrackColor(track, colors.mixer)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        
        if aux_state == "y" then
            SetTrackColor(track, colors.aux)
            -- Use Mission Control setting if available, otherwise default to 0
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end
        
        if submix_state == "y" then
            SetTrackColor(track, colors.submix)
            -- Use Mission Control setting if available, otherwise default to 0
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end
        
        if rt_state == "y" then
            SetTrackColor(track, colors.roomtone)
            -- Use Mission Control setting if available, otherwise default to 1
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            end
        end
        
        if live_state == "y" then
            SetTrackColor(track, colors.live)
            -- Use Mission Control setting if available, otherwise default to 1
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            end
        end
        
        if ref_state == "y" then
            SetTrackColor(track, colors.ref)
            -- Use Mission Control setting if available, otherwise default to 1
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            end
        end
        
        if rcmaster_state == "y" then
            SetTrackColor(track, colors.rcmaster)
            -- Use Mission Control setting if available, otherwise default to 0
            if mission_control_tcp_visible ~= nil then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", mission_control_tcp_visible and 1 or 0)
            else
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
            end
        end
        
        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rcmaster_state == "y"
           or rt_state == "y" or live_state == "y" or ref_state == "y" then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end
        
        local _, source_track = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", false)
        if trackname_check(track, "^S%d+:") or source_track == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        
        -- Check folder visibility (only in Vertical workflow)
        -- This needs to run BEFORE we check for folder parent tracks
        local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
        local parent_folder_visible = true -- Default to visible
        
        if workflow == "Vertical" then
            -- First, find if this track is inside a folder and get that folder's visibility
            local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            
            if folder_depth ~= 1 then
                -- This might be a child track - find its parent folder
                local search_idx = i - 1
                local current_depth = 0
                
                while search_idx >= 0 do
                    local parent_track = GetTrack(0, search_idx)
                    local parent_depth = GetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH")
                    
                    if parent_depth == 1 then
                        -- Found the parent folder - check its visibility
                        local _, parent_guid = GetSetMediaTrackInfo_String(parent_track, "GUID", "", false)
                        local _, folder_vis_str = GetProjExtState(0, "ReaClassical_MissionControl", "folder_tcp_visible_" .. parent_guid)
                        
                        if folder_vis_str ~= "" then
                            parent_folder_visible = (folder_vis_str == "1")
                        end
                        break
                    end
                    
                    search_idx = search_idx - 1
                end
            end
            
            -- Now handle the track based on whether it's a folder parent or child
            if folder_depth == 1 then
                -- This is a folder parent track - check Mission Control visibility
                local _, folder_vis_str = GetProjExtState(0, "ReaClassical_MissionControl", "folder_tcp_visible_" .. guid)
                
                if folder_vis_str ~= "" then
                    local should_show = (folder_vis_str == "1")
                    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", should_show and 1 or 0)
                end
            else
                -- This is potentially a child track - hide it if parent folder is hidden
                if not parent_folder_visible and not is_special_track then
                    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
                end
            end
        end
    end
end

---------------------------------------------------------------------

function on_stop()
    if GetPlayState() == 0 then
        DeleteProjectMarker(nil, 1016, false)
        Main_OnCommand(41185, 0) -- Item properties: Unsolo all
        return
    else
        defer(on_stop)
    end
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
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

function get_selected_media_item_at(index)
    local selected_count = 0
    local total_items = CountMediaItems(0)

    for i = 0, total_items - 1 do
        local item = GetMediaItem(0, i)
        if IsMediaItemSelected(item) then
            if selected_count == index then
                return item
            end
            selected_count = selected_count + 1
        end
    end

    return nil
end

---------------------------------------------------------------------

function select_children_of_selected_folders()
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local tr = GetTrack(0, i)
        if IsTrackSelected(tr) then
            local depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
            if depth == 1 then -- folder parent
                local j = i + 1
                while j < track_count do
                    local ch_tr = GetTrack(0, j)
                    SetTrackSelected(ch_tr, true) -- select child track

                    local ch_depth = GetMediaTrackInfo_Value(ch_tr, "I_FOLDERDEPTH")
                    if ch_depth == -1 then
                        break -- end of folder children
                    end

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
            -- We found a selected folder parent
            unselect_mode = true
        elseif unselect_mode then
            SetTrackSelected(tr, false)
        end

        -- Adjust folder depth
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

function select_next_item(unselect_all_first)
    local num_tracks = CountTracks(0)
    local nextMi = nil

    -- Scan tracks from last to first
    for i = num_tracks - 1, 0, -1 do
        local tr = GetTrack(0, i)
        if IsTrackVisible(tr, false) then -- Visible in TCP/MCP
            -- Scan items from last to first
            local num_items = CountTrackMediaItems(tr)
            for j = num_items - 1, 0, -1 do
                local mi = GetTrackMediaItem(tr, j)
                if GetMediaItemInfo_Value(mi, "B_UISEL") == 1 then
                    if nextMi then
                        if unselect_all_first then
                            Main_OnCommand(40289, 0) -- Unselect all items
                        end
                        SetMediaItemSelected(nextMi, true)
                        UpdateArrange()
                        return
                    end
                end
                nextMi = mi
            end
        end
    end
end

---------------------------------------------------------------------

function select_prev_item(unselect_all_first)
    local num_tracks = CountTracks(0)
    local prevMi = nil

    -- Scan tracks from first to last (forward)
    for i = 0, num_tracks - 1 do
        local tr = GetTrack(0, i)
        if IsTrackVisible(tr, false) then -- Visible in TCP/MCP
            -- Scan items from first to last
            local num_items = CountTrackMediaItems(tr)
            for j = 0, num_items - 1 do
                local mi = GetTrackMediaItem(tr, j)
                if GetMediaItemInfo_Value(mi, "B_UISEL") == 1 then
                    if prevMi then
                        if unselect_all_first then
                            Main_OnCommand(40289, 0) -- Unselect all items
                        end
                        SetMediaItemSelected(prevMi, true)
                        UpdateArrange()
                        return
                    end
                end
                prevMi = mi
            end
        end
    end
end

---------------------------------------------------------------------

main()
