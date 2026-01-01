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

local main, clean_take_names

---------------------------------------------------------------------


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

    local selected_track = GetSelectedTrack(0, 0)

    if not selected_track then
        MB("Error: No track selected.", "Remove Take Names", 0)
        return
    end

    -- Find folder parent (or use selected if already a folder)
    local depth = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")
    if depth ~= 1 then
        MB("Error: The selected track is not a folder track.",
            "Remove Take Names", 0)
        return
    end

    local num_of_items = CountTrackMediaItems(selected_track)

    if num_of_items == 0 then
        MB("No items found on the selected track", "Error", 0)
        return
    end

    local response = MB(
        "Are you sure you would like to remove item take names from the selected folder track?", "Remove Take Names", 4)
    if response == 6 then clean_take_names(selected_track, num_of_items) end

    Undo_EndBlock('Remove Take Names', 0)
end

---------------------------------------------------------------------

function clean_take_names(selected_track, num_of_items)
    for i = 0, num_of_items - 1 do
        local item = GetTrackMediaItem(selected_track, i)
        local take = GetActiveTake(item)
        if take then
            GetSetMediaItemTakeInfo_String(take, "P_NAME", "", true)
        end
    end
end

---------------------------------------------------------------------

main()
