--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, source_markers, select_matching_folder, lock_items
local unlock_items, ripple_lock_mode, return_xfade_length, xfade

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    Main_OnCommand(40927, 0) -- Options: Enable auto-crossfade on split
    if source_markers() == 2 then
        ripple_lock_mode()
        local focus = NamedCommandLookup("_BR_FOCUS_ARRANGE_WND")
        Main_OnCommand(focus, 0) -- BR_FOCUS_ARRANGE_WND
        GoToMarker(0, 998, false)
        lock_items()
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40625, 0) -- Time Selection: Set start point
        GoToMarker(0, 999, false)
        Main_OnCommand(40626, 0) -- Time Selection: Set end point
        Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
        Main_OnCommand(40034, 0) -- Item Grouping: Select all items in group(s)
        local folder = GetSelectedTrack(0, 0)
        if GetMediaTrackInfo_Value(folder, "IP_TRACKNUMBER") == 1 then
            Main_OnCommand(40311, 0) -- Set ripple-all-tracks
        else
            Main_OnCommand(40310, 0) -- Set ripple-per-track
        end
        local delete = NamedCommandLookup("_XENAKIOS_TSADEL")
        Main_OnCommand(delete, 0) -- XENAKIOS_TSADEL
        Main_OnCommand(40630, 0)  -- Go to start of time selection
        unlock_items()
        local xfade_len = return_xfade_length()
        MoveEditCursor(xfade_len, false)
        local select_under = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
        Main_OnCommand(select_under, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
        MoveEditCursor(-xfade_len * 2, false)
        Main_OnCommand(41305, 0)        -- Item edit: Trim left edge of item to edit cursor
        Main_OnCommand(40630, 0)        -- Go to start of time selection
        xfade(xfade_len)
        Main_OnCommand(40020, 0)        -- Time Selection: Remove time selection and loop point selection
        DeleteProjectMarker(NULL, 998, false)
        DeleteProjectMarker(NULL, 999, false)
        Main_OnCommand(40289, 0) -- Item: Unselect all items
        Main_OnCommand(40310, 0) -- Ripple per-track
    else
        ShowMessageBox("Please use SOURCE-IN and SOURCE-OUT markers", "Delete With Ripple", 0)
    end
    Undo_EndBlock('Cut and Ripple', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function source_markers()
    local _, num_markers, num_regions = CountProjectMarkers(0)
    local exists = 0
    for i = 0, num_markers + num_regions - 1, 1 do
        local _, _, _, _, label, _ = EnumProjectMarkers(i)
        if string.match(label, "%d+:SOURCE[-]IN") or string.match(label, "%d+:SOURCE[-]OUT") then
            exists = exists + 1
        end
    end
    return exists
end

---------------------------------------------------------------------

function select_matching_folder()
    local cursor = GetCursorPosition()
    local marker_id, _ = GetLastMarkerAndCurRegion(0, cursor)
    local _, _, _, _, label, _, _ = EnumProjectMarkers3(0, marker_id)
    local folder_number = tonumber(string.match(label, "(%d*):SOURCE*"))
    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") == folder_number then
            SetOnlyTrackSelected(track)
            break
        end
    end
end

---------------------------------------------------------------------

function lock_items()
    select_matching_folder()
    Main_OnCommand(40182, 0)             -- select all items
    local select_children = NamedCommandLookup("_SWS_SELCHILDREN2")
    Main_OnCommand(select_children, 0)   -- select children of folder
    local unselect_items = NamedCommandLookup("_SWS_UNSELONTRACKS")
    Main_OnCommand(unselect_items, 0)    -- unselect items in folder
    local unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN")
    Main_OnCommand(unselect_children, 0) -- unselect children of folder
    local total_items = CountSelectedMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetSelectedMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 1)
    end
end

---------------------------------------------------------------------

function unlock_items()
    local total_items = CountMediaItems(0)
    for i = 0, total_items - 1, 1 do
        local item = GetMediaItem(0, i)
        SetMediaItemInfo_Value(item, "C_LOCK", 0)
    end
end

---------------------------------------------------------------------

function ripple_lock_mode()
    local _, original_ripple_lock_mode = get_config_var_string("ripplelockmode")
    original_ripple_lock_mode = tonumber(original_ripple_lock_mode)
    if original_ripple_lock_mode ~= 2 then
        SNM_SetIntConfigVar("ripplelockmode", 2)
    end
end

---------------------------------------------------------------------

function return_xfade_length()
    local xfade_len = 0.035
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[1] then xfade_len = table[1] / 1000 end
    end
    return xfade_len
end

---------------------------------------------------------------------

function xfade(xfade_len)
    local select_items = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_items, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(40625, 0)        -- Time selection: Set start point
    MoveEditCursor(xfade_len, false)
    Main_OnCommand(40626, 0)        -- Time selection: Set end point
    Main_OnCommand(40916, 0)        -- Item: Crossfade items within time selection
    Main_OnCommand(40635, 0)        -- Time selection: Remove time selection
    MoveEditCursor(0.001, false)
    Main_OnCommand(select_items, 0)
    MoveEditCursor(-0.001, false)
end

---------------------------------------------------------------------

main()
