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

local main, select_check, check_next_item_overlap, get_selected_media_item_at

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
local sdmousehover = 0
if input ~= "" then
    local table = {}
    for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
    if table[9] then sdmousehover = tonumber(table[9]) or 0 end
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
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end
    PreventUIRefresh(1)
    local reaper_xfade_toggle = GetToggleCommandState(41827)
    if reaper_xfade_toggle == 0 or reaper_xfade_toggle == -1 then
        if sdmousehover == 1 then
            BR_GetMouseCursorContext()
            local hover_item = BR_GetMouseCursorContext_Item()
            if hover_item ~= nil then
                Main_OnCommand(40289, 0)     -- Item: Unselect all items
                SetMediaItemSelected(hover_item, 1)
            end
        end
        local _, item1 = select_check()
        if item1 and check_next_item_overlap(item1) then
            Main_OnCommand(41827, 0)
        else
            if sdmousehover == 1 then
                MB("Please hover over the right item of a crossfaded pair", "Crossfade Editor", 0)
            else
                MB("Please select the right item of a crossfaded pair", "Crossfade Editor", 0)
            end
        end
        local lock_fade = GetToggleCommandStateEx(32065, 43592)
        if lock_fade == 0 then CrossfadeEditor_OnCommand(43592) end     -- set fade lock
    elseif reaper_xfade_toggle == 1 then
        Main_OnCommand(41827, 0)
    end

    PreventUIRefresh(-1)
    Undo_EndBlock('Classical Crossfade Editor', 0)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function select_check()
    local selected_item = get_selected_media_item_at(0)

    if not selected_item then
        return false
    end

    local track = GetMediaItemTrack(selected_item)

    local current_item_index = GetMediaItemInfo_Value(selected_item, "IP_ITEMNUMBER")
    local prev_item = GetTrackMediaItem(track, current_item_index - 1)

    return prev_item and selected_item, prev_item or false
end

---------------------------------------------------------------------

function check_next_item_overlap(current_item)
    local track = GetMediaItemTrack(current_item)
    if not track then
        return false
    end
    local current_item_index = GetMediaItemInfo_Value(current_item, "IP_ITEMNUMBER")

    local next_item = GetTrackMediaItem(track, current_item_index + 1)

    if not next_item then
        return false
    end

    -- Get the positions and lengths of the items
    local current_item_position = GetMediaItemInfo_Value(current_item, "D_POSITION")
    local current_item_length = GetMediaItemInfo_Value(current_item, "D_LENGTH")
    local current_item_end = current_item_position + current_item_length
    local next_item_position = GetMediaItemInfo_Value(next_item, "D_POSITION")

    -- Check for overlap: next item must start before the current item's end
    if next_item_position >= current_item_end then
        return false
    end
    return true
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

main()
