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
local main, update_offsets

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
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

    SetProjExtState(0, "ReaClassical", "ddp_refresh_trigger", "y")
    SetProjExtState(0, "ReaClassical", "ddp_silent", "y")

    local saved_offset = 0.2
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[2] then saved_offset = table[2] / 1000 end
    end

    local updated = update_offsets(saved_offset)

    local create_cd_markers = NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")
    Main_OnCommand(create_cd_markers, 0)

    if updated > 0 then
        MB(string.format("Updated %d item offset(s)", updated), "", 0)
        -- ShowConsoleMsg(string.format("Updated %d item offset(s)\n", updated))
    else
        MB("No offsets changed", "", 0)
        -- ShowConsoleMsg("No items needed OFFSET update\n")
    end

    Undo_EndBlock('Add CD Marker Offsets', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function update_offsets(offset)
    local num_items = CountMediaItems(0)
    if num_items == 0 then return end

    local cd_frame = 1 / 75
    local updated = 0

    for i = 0, num_items - 1 do
        local item = GetMediaItem(0, i)
        -- Get stored marker GUID from item's P_EXT:cdmarker
        local ok, guid = GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", "", false)

        if not ok or guid == "" then goto continue end

        -- Find marker index using GUID
        local ok_index, mark_index_str = GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. guid, "", false)
        if not ok_index or mark_index_str == "" then goto continue end

        local mark_index = tonumber(mark_index_str)
        if not mark_index then goto continue end

        -- Get marker info
        local retval, isrgn, marker_pos = EnumProjectMarkers3(0, mark_index)
        if not retval or isrgn then goto continue end

        -- Get item start and take
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local take = GetActiveTake(item)
        if not take then goto continue end

        local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if take_name == "" then goto continue end

        -- Extract existing OFFSET from name
        local name_offset = 0
        local offset_match = take_name:match("|OFFSET=([%-%d%.]+)")
        if offset_match then
            name_offset = tonumber(offset_match) or 0
        end

        -- Calculate expected marker position
        local expected_marker_pos = item_start - offset - name_offset

        -- If marker is already within tolerance, skip
        if math.abs(marker_pos - expected_marker_pos) < cd_frame then goto continue end

        -- Calculate new offset
        local new_offset = (item_start - offset) - marker_pos

        -- Update take name with new offset
        if take_name:match("|OFFSET=") then
            take_name = take_name:gsub("|OFFSET=[%-%d%.]+", "|OFFSET=" .. string.format("%.6f", new_offset))
        else
            take_name = take_name .. "|OFFSET=" .. string.format("%.6f", new_offset)
        end

        GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name, true)
        updated = updated + 1

        ::continue::
    end

    return updated
end

---------------------------------------------------------------------

main()
