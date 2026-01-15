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

local main
local select_items_containing_midpoint, get_parent_folder, get_folder_children

---------------------------------------------------------------------

function main()
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

    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local find_takes_using_items = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[13] then find_takes_using_items = tonumber(table[13]) or 0 end
    end

    local take_choice
    local _, session_name = GetProjExtState(0, "ReaClassical", "SessionNameSearch")
    ::start::
    local retval, inputs = GetUserInputs('Find Take', 2, 'Take Number:,Session Name (optional):', ',' .. session_name)
    if not retval then return end

    take_choice, session_name = inputs:match("([^,]*),([^,]*)")
    take_choice = tonumber(take_choice)
    if not take_choice and session_name ~= "" then take_choice = 1 end

    session_name = session_name:match("^%s*(.-)%s*$") -- Trim spaces around the session name
    SetProjExtState(0, "ReaClassical", "SessionNameSearch", session_name)

    local found = false
    local num_of_items = CountMediaItems(0)

    -- FIRST: Try to find using stored P_EXT:item_take_num
    for i = 0, num_of_items - 1 do
        local item = GetMediaItem(0, i)
        local _, stored_take_num = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
        
        if stored_take_num and stored_take_num ~= "" then
            local take_num = tonumber(stored_take_num)
            if take_num == take_choice then
                -- Check session name if provided
                local session_match = true
                if session_name and session_name ~= "" then
                    local take = GetActiveTake(item)
                    if take then
                        if find_takes_using_items == 0 then
                            -- Check filename for session
                            local src = GetMediaItemTake_Source(take)
                            local filename = GetMediaSourceFileName(src, "")
                            session_match = filename:lower():match("%f[%a]" .. session_name:lower() .. "[^i]*%f[%A]") ~= nil
                        else
                            -- Check take name for session
                            local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                            session_match = take_name:lower():match("%f[%a]" .. session_name:lower() .. "[^i]*%f[%A]") ~= nil
                        end
                    end
                end
                
                -- Check if not an edit
                local edit, _ = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
                
                if session_match and not edit then
                    found = true
                    local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                    SetEditCurPos(item_start, true, false)
                    Main_OnCommand(40769, 0) -- unselect all items
                    SetMediaItemSelected(item, true)
                    select_items_containing_midpoint()
                    break
                end
            end
        end
    end

    -- If not found in P_EXT, fall back to original search methods
    if not found then
        if find_takes_using_items == 0 then -- search using filenames
            for i = 0, num_of_items - 1, 1 do
                local item = GetMediaItem(0, i)
                local take = GetActiveTake(item)
                if take then
                    local src = GetMediaItemTake_Source(take)
                    local filename = GetMediaSourceFileName(src, "")
                    local take_capture = tonumber(
                    -- Case: (###)[chan X].wav  or  ### [chan X].wav  (with or without space)
                        filename:match("(%d+)%)?%s*%[chan%s*%d+%]%.[^%.]+$")
                        -- Case: (###).wav  or  ###.wav
                        or filename:match("(%d+)%)?%.[^%.]+$")
                    )

                    local session_match = true

                    if session_name and session_name ~= "" then
                        session_match = filename:lower():match("%f[%a]" .. session_name:lower() .. "[^i]*%f[%A]") ~= nil
                    end

                    local edit, _ = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)

                    if take_capture == take_choice and session_match and not edit then
                        found = true
                        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                        SetEditCurPos(item_start, true, false)
                        Main_OnCommand(40769, 0) -- unselect all items
                        SetMediaItemSelected(item, true)
                        select_items_containing_midpoint()
                        break
                    end
                end
            end
        else -- search using take names
            for i = 0, num_of_items - 1 do
                local item = GetMediaItem(0, i)
                local take = GetActiveTake(item)
                if take then
                    local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    local session_match = true
                    if session_name and session_name ~= "" then
                        session_match = take_name:lower():match("%f[%a]" .. session_name:lower() .. "[^i]*%f[%A]") ~= nil
                    end

                    if take_name and session_match then
                        if take_choice then
                            local take_num = tonumber(take_name:match("(%d+)"))
                            if take_num == take_choice then
                                found = true
                            end
                        else
                            found = true
                        end

                        if found then
                            local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                            SetEditCurPos(item_start, true, false)
                            Main_OnCommand(40769, 0)
                            SetMediaItemSelected(item, true)
                            select_items_containing_midpoint()
                            break
                        end
                    end
                end
            end
        end
    end

    if not found and (take_choice or session_name ~= "") then
        local response = MB("Take not found. Try again?", "Find Take", 4)
        if response == 6 then
            goto start
        end
    end
end

---------------------------------------------------------------------

function select_items_containing_midpoint()
    local num_sel = CountSelectedMediaItems(0)
    if num_sel == 0 then return end

    -- Get the folder tracks for all selected items
    local folder_tracks = {}
    for i = 0, num_sel - 1 do
        local item = GetSelectedMediaItem(0, i)
        local track = GetMediaItemTrack(item)
        local folder = get_parent_folder(track)
        if folder then
            folder_tracks[folder] = true
        end
    end

    -- Get all tracks within the relevant folders
    local tracks_to_check = {}
    for folder, _ in pairs(folder_tracks) do
        local children = get_folder_children(folder)
        tracks_to_check[folder] = true -- Include folder track itself
        for _, child in ipairs(children) do
            tracks_to_check[child] = true
        end
    end

    -- Collect selected items' midpoints
    local positions_to_check = {}
    for i = 0, num_sel - 1 do
        local item = GetSelectedMediaItem(0, i)
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local len = GetMediaItemInfo_Value(item, "D_LENGTH")
        local mid = pos + (len / 2)
        table.insert(positions_to_check, mid)
    end

    local tolerance = 0.0001

    -- For each midpoint position, select items in folder that contain it
    for _, check_pos in ipairs(positions_to_check) do
        for track, _ in pairs(tracks_to_check) do
            local num_items = CountTrackMediaItems(track)
            for i = 0, num_items - 1 do
                local item = GetTrackMediaItem(track, i)
                local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len

                -- Select if this item's span contains the check position
                if check_pos >= (item_pos - tolerance) and check_pos <= (item_end + tolerance) then
                    SetMediaItemSelected(item, true)
                end
            end
        end
    end
end

---------------------------------------------------------------------

function get_parent_folder(track)
    -- Returns the parent folder track, or nil if track is not in a folder
    if not track then return nil end

    local track_idx = GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1

    -- Walk backwards to find parent folder
    for i = track_idx, 0, -1 do
        local t = GetTrack(0, i)
        if not t then break end

        local depth = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
        if depth == 1 then
            return t
        end
    end

    return nil
end

---------------------------------------------------------------------

function get_folder_children(parent_track)
    -- Returns all child tracks of a folder
    local children = {}
    if not parent_track then return children end

    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1

    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end

        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")

        if depth > 0 then
            table.insert(children, tr)
        end

        depth = depth + folder_depth

        if depth <= 0 then break end

        idx = idx + 1
    end

    return children
end

---------------------------------------------------------------------

main()