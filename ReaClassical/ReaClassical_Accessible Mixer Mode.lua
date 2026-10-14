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

set_action_options(1)

local _, _, section_id, cmd_id = get_action_context()

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local mm  = require("ReaClassical_MM_Utils")

if not (APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed) then
    local _, debug_str = GetProjExtState(0, "ReaClassical", "DebugAnnounce")
    if debug_str ~= "on" then
        MB("Accessible Mixer Mode requires ReaClassical Clara (an accessibility bridge) to be installed.",
            "ReaClassical Error", 0)
        return
    end
end

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

Main_OnCommand(24800, 0)
Main_OnCommand(24805, 0)
SetExtState("ReaClassical", "MixerMode", "1", false)

say("Mixer mode on")

local target = mm.get_current_target()
if target then
    say(mm.get_label(target) .. ", " .. mm.format_peak(target) .. mm.status_suffix(target))
else
    say("No special tracks found")
end

local function main()
    SetToggleCommandState(section_id, cmd_id, 1)
    defer(main)
end

local function at_exit()
    Main_OnCommand(24800, 0)
    if GetExtState("ReaClassical", "MixerModeForceMain") == "1" then
        SetExtState("ReaClassical", "MixerModeForceMain", "", false)
    else
        local ps = GetPlayState()
        if ps == 5 or ps == 6 then
            Main_OnCommand(24802, 0)
        end
    end
    SetExtState("ReaClassical", "MixerMode", "", false)
    SetToggleCommandState(section_id, cmd_id, 0)
    say("Mixer mode off")
end

atexit(at_exit)
defer(main)
