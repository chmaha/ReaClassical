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

local main, find_rcmaster

function find_rcmaster()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        if rcmaster_state == "y" then return track end
    end
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if name:match("^RCMASTER") then return track end
    end
    return nil
end

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

    local rcmaster = find_rcmaster()
    if not rcmaster then
        say("RCMASTER track not found")
        return
    end

    local num_sends = GetTrackNumSends(rcmaster, 1)
    if num_sends == 0 then
        say("RCMASTER has no hardware outputs")
        return
    end

    local all_muted = true
    for i = 0, num_sends - 1 do
        if GetTrackSendInfo_Value(rcmaster, 1, i, "B_MUTE") == 0 then
            all_muted = false
            break
        end
    end

    Undo_BeginBlock()
    local new_state = all_muted and 0 or 1
    for i = 0, num_sends - 1 do
        SetTrackSendInfo_Value(rcmaster, 1, i, "B_MUTE", new_state)
    end
    Undo_EndBlock("Toggle RCMASTER hardware output mute", -1)

    say(new_state == 1 and "RCM hardware output muted" or "RCM hardware output active")
end

main()
