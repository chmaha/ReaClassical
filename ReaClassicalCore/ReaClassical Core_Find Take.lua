--[[
@noindex

This file is a part of "ReaClassical Core" package.
See "ReaClassicalCore.lua" for more information.

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

function main()

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
                    Main_OnCommand(40034, 0) -- select all in group
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
                        Main_OnCommand(40034, 0)
                        break
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

main()
