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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local blemish = require("ReaClassical_Blemish")

local TOOLTIP_SECONDS = 2

set_action_options(3)

local function main()
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

    local message = blemish.describe(blemish.mark())
    say(message)

    if GetExtState("ReaClassical", "RecordPanelOpen") == "1" then return end

    local x, y = GetMousePosition()
    TrackCtl_SetToolTip(message, x + 12, y + 12, true)
    local started = time_precise()
    local function clear_later()
        if time_precise() - started < TOOLTIP_SECONDS then
            defer(clear_later)
        else
            TrackCtl_SetToolTip("", 0, 0, false)
        end
    end
    defer(clear_later)
end

main()
