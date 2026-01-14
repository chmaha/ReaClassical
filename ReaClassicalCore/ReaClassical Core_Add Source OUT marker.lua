--[[
@noindex

This file is a part of "ReaClassical Core" package.
See "ReaClassicalCore.lua" for more information.

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

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local source_marker = ColorToNative(23, 223, 143) | 0x1000000

function main()
    PreventUIRefresh(1)
    local workflow = "Horizontal"
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
                MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.",
            "ReaClassical Error", 0)
        return
    end
    local _, input = GetProjExtState(0, "ReaClassical Core", "Preferences")
    local sdmousehover = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[3] then sdmousehover = tonumber(table[3]) or 0 end
    end

    local cur_pos
    if sdmousehover == 1 then
        cur_pos = BR_PositionAtMouseCursor(false)
    else
        cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    end

    if cur_pos ~= -1 then
        local i = 0
        while true do
            local project, _ = EnumProjects(i)
            if project == nil then
                break
            else
                DeleteProjectMarker(project, 999, false)
            end
            i = i + 1
        end

        AddProjectMarker2(0, false, cur_pos, 0, "SOURCE-OUT", 999, source_marker)
    end
    PreventUIRefresh(-1)
end

---------------------------------------------------------------------

main()
