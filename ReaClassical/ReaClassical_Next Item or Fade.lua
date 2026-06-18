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

local main, get_selected_media_item_at, say, announce_current_item

---------------------------------------------------------------------

function say(msg)
    if osara_outputMessage then
        osara_outputMessage(tostring(msg))
    end
end

---------------------------------------------------------------------

function announce_current_item()
    local item = get_selected_media_item_at(0)
    if not item then return end
    local take = GetActiveTake(item)
    local name = ""
    if take then
        _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    end
    if name == "" then
        say("(unnamed)")
        return
    end
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        say(prefix .. " take " .. tonumber(take_num))
        return
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        say("Take " .. tonumber(only_num))
        return
    end
    say(name)
end

---------------------------------------------------------------------

function main()
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

    Main_OnCommand(40417, 0) -- Item navigation: Select and move to next item

    UpdateArrange()
    UpdateTimeline()
    announce_current_item()
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
