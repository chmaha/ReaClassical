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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local talkback_track = require("ReaClassical_Talkback_Track")

local main

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

    if not talkback_track.find() then
        if APIExists("clara_outputMessage") then
            say("No talkback track found. Add one via Mission Control")
        else
            MB("No talkback track found. Add one via Mission Control (Add Special Tracks).",
                "Toggle Talkback", 0)
        end
        return
    end

    Undo_BeginBlock()
    local now_on = talkback_track.toggle()
    Undo_EndBlock("Toggle talkback", -1)

    local _, _, section_id, cmd_id = get_action_context()
    SetToggleCommandState(section_id, cmd_id, now_on and 1 or 0)
    RefreshToolbar2(section_id, cmd_id)

    say(now_on and "Talkback on" or "Talkback off")
end

main()
