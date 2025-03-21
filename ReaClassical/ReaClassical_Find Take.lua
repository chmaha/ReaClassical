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

local main

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
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

    for i = 0, num_of_items - 1, 1 do
        local item = GetMediaItem(0, i)
        local take = GetActiveTake(item)
        if take then
            local src = GetMediaItemTake_Source(take)
            local filename = GetMediaSourceFileName(src, "")
            local take_capture = tonumber(filename:match(".*[^%d](%d+)%)?%.%a+$"))
            local session_match = true

            if session_name and session_name ~= "" then
                session_match = filename:lower():find(session_name:lower()) ~= nil
            end

            local edit, _ = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)

            if take_capture == take_choice and session_match and not edit then
                found = true
                local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
                SetEditCurPos(item_start, 1, 0)
                local center = NamedCommandLookup("_SWS_HSCROLL50")
                Main_OnCommand(center, 0)
                Main_OnCommand(40769, 0) -- unselect all items
                SetMediaItemSelected(item, true)
                Main_OnCommand(40034, 0) -- select all in group
                break
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

main()
