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

local main, get_input_tracks

---------------------------------------------------------------------

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

function get_input_tracks()
    local tracks = {}
    local num_tracks = CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        local rec_mode = GetMediaTrackInfo_Value(track, "I_RECMODE")
        if rec_mode == 0 then
            table.insert(tracks, track)
        end
    end
    return tracks
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

    local tracks = get_input_tracks()
    if #tracks == 0 then return end

    local current = GetMediaTrackInfo_Value(tracks[1], "I_RECMON")
    local new_state = (current + 1) % 3

    local state_names = { [0] = "off", [1] = "on", [2] = "tape mode" }

    Undo_BeginBlock()
    for _, track in ipairs(tracks) do
        SetMediaTrackInfo_Value(track, "I_RECMON", new_state)
    end
    Undo_EndBlock("Toggle Monitor (" .. (state_names[new_state] or "") .. ")", -1)
    say("Monitor: " .. (state_names[new_state] or ""))
end

---------------------------------------------------------------------

main()
