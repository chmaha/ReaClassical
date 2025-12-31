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
    local horizontal_zoom = NamedCommandLookup("_RSe4ae3f4797f2fb7f209512fc22ad6ef9854ca770")
    local vertical_zoom = NamedCommandLookup("_RS444f747139500db030a1c4e03b8a0805ac502dfe")
    Main_OnCommand(horizontal_zoom, 0)
    Main_OnCommand(vertical_zoom, 0)
    PreventUIRefresh(-1)
    Undo_EndBlock('Whole Project View', 0)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

main()
