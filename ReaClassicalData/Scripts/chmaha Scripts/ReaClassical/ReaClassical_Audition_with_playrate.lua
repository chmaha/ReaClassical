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
    local colors = get_color_table()
    local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
    local fade_editor_state = GetToggleCommandState(fade_editor_toggle)
    if fade_editor_state ~= 1 then
        local pos = BR_PositionAtMouseCursor(false)
        local screen_x, screen_y = GetMousePosition()
        local track = GetTrackFromPoint(screen_x, screen_y)
        if track then
            SetOnlyTrackSelected(track)
            solo()
            select_children_of_selected_folders()
            mixer(colors)
            unselect_folder_children()
            SetEditCurPos(pos, 0, 0)
            OnPlayButton()
            PreventUIRefresh(-1)
            Undo_EndBlock('Audition', 0)
            UpdateArrange()
            UpdateTimeline()
            TrackList_AdjustWindows(false)
        end
    else
        DeleteProjectMarker(nil, 1016, false)
        BR_GetMouseCursorContext()
        local hover_item = BR_GetMouseCursorContext_Item()
        if hover_item ~= nil then
            SetMediaItemSelected(hover_item, 1)
            UpdateArrange()
        end
        local item_one = get_selected_media_item_at(0)
        local item_two = get_selected_media_item_at(1)
        if not item_one and not item_two then
            MB("Please select at least one of the items involved in the crossfade", "Audition", 0)
            return
        elseif item_one and not item_two then
            local color = GetMediaItemInfo_Value(item_one, "I_CUSTOMCOLOR")
            if color == colors.xfade_green then
                item_two = item_one
                select_prev_item(true)
                item_one = get_selected_media_item_at(0)
            else
                select_next_item(true)
                item_two = get_selected_media_item_at(0)
            end
        end

        Main_OnCommand(41185, 0) -- unsolo all
        local item_one_muted = GetMediaItemInfo_Value(item_one, "B_MUTE")
        local item_two_muted = GetMediaItemInfo_Value(item_two, "B_MUTE")

        local one_pos = GetMediaItemInfo_Value(item_one, "D_POSITION")
        local one_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
        local two_pos = GetMediaItemInfo_Value(item_two, "D_POSITION")
        Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        BR_GetMouseCursorContext()
        local mouse_pos = BR_GetMouseCursorContext_Position()
        local item_hover = BR_GetMouseCursorContext_Item()
        local end_of_one = one_pos + one_length
        local overlap = end_of_one - two_pos
        local mouse_to_item_two = two_pos - mouse_pos
        if item_hover == item_one then
            local item_length = GetMediaItemInfo_Value(item_one, "D_LENGTH")
            SetMediaItemSelected(item_hover, true)
            Main_OnCommand(40034, 0)     -- Item Grouping: Select all items in group(s)
            if item_one_muted == 0 then
                Main_OnCommand(41559, 0) -- Item properties: Solo
            end
            AddProjectMarker2(0, false, one_pos + item_length, 0, "!1016", 1016, colors.audition)
            SetEditCurPos(mouse_pos, false, false)
            OnPlayButton() -- play until end of item_hover (one_pos + item_length)
        elseif item_hover == item_two then
            SetMediaItemSelected(item_hover, true)
            Main_OnCommand(40034, 0)     -- Item Grouping: Select all items in group(s)
            if item_two_muted == 0 then
                Main_OnCommand(41559, 0) -- Item properties: Solo
            end
            SetEditCurPos(two_pos, false, false)
            AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1016, colors.audition)
            OnPlayButton() -- play until mouse cursor
        elseif not item_hover and mouse_pos < two_pos then
            local total_time = 2 * mouse_to_item_two + overlap
            AddProjectMarker2(0, false, mouse_pos + total_time, 0, "!1016", 1016,
                colors.audition)
            SetEditCurPos(mouse_pos, false, false)
            OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
        else
            local mouse_to_item_one = mouse_pos - end_of_one
            local mirrored_total_time = 2 * mouse_to_item_one + overlap
            AddProjectMarker2(0, false, mouse_pos, 0, "!1016", 1016,
                colors.audition)
            AddProjectMarker2(0, false, mouse_pos - mirrored_total_time, 0, "START", 1111,
                colors.audition)
            GoToMarker(0, 1111, false)
            OnPlayButton() -- play from mouse_pos to same distance after end_of_one (mirrored)
            DeleteProjectMarker(nil, 1111, false)
        end
        Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        SetMediaItemSelected(item_one, false)
        SetMediaItemSelected(item_two, true)

        SetEditCurPos(two_pos + (overlap / 2), false, false)
        on_stop()
        Undo_EndBlock('Audition', 0)
        PreventUIRefresh(-1)
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

function mixer(colors)
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        if mixer_state == "y" then
            SetTrackColor(track, colors.mixer)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if aux_state == "y" then
            SetTrackColor(track, colors.aux)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if submix_state == "y" then
            SetTrackColor(track, colors.submix)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if rt_state == "y" then
            SetTrackColor(track, colors.roomtone)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if ref_state == "y" then
            SetTrackColor(track, colors.ref)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if live_state == "y" then
            SetTrackColor(track, colors.live)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        end
        if rcmaster_state == "y" then
            SetTrackColor(track, colors.rcmaster)
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        end
        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or live_state == "y" or rcmaster_state == "y"
            or rt_state == "y" or ref_state == "y" then
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 1)
        else
            SetMediaTrackInfo_Value(track, 'B_SHOWINMIXER', 0)
        end

        local _, source_track = GetSetMediaTrackInfo_String(track, "P_EXT:Source", "", false)
        if trackname_check(track, "^S%d+:") or source_track == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 0 or 1)
        end
        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", (mastering == 1) and 1 or 0)
        end
        if mastering == 1 and i == 0 then
            Main_OnCommand(40727, 0) -- minimize all tracks
            SetTrackSelected(track, 1)
            Main_OnCommand(40723, 0) -- expand and minimize others
            SetTrackSelected(track, 0)
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
