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

local main, show_envelopes_on_selected_tracks

---------------------------------------------------------------------

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
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

    if CountSelectedTracks(0) == 0 then
        say("No tracks selected")
        return
    end

    Undo_BeginBlock()
    local shown = show_envelopes_on_selected_tracks()
    UpdateArrange()
    Undo_EndBlock("Show Automation Lanes", -1)

    if shown == 0 then
        say("No hidden automation lanes on selected tracks")
    else
        say(shown .. " automation lane" .. (shown ~= 1 and "s" or "") .. " shown")
    end
end

---------------------------------------------------------------------

-- Shows (sets visible = true) every hidden envelope lane on the currently
-- selected tracks, without touching each envelope's active state -- this
-- only restores the lane's visibility. Returns the number of lanes shown.
function show_envelopes_on_selected_tracks()
    local shown = 0
    local num_sel = CountSelectedTracks(0)

    for i = 0, num_sel - 1 do
        local track = GetSelectedTrack(0, i)
        local num_envs = CountTrackEnvelopes(track)

        for e = 0, num_envs - 1 do
            local env = GetTrackEnvelope(track, e)
            local br_env = BR_EnvAlloc(env, false)
            local active, visible, armed, in_lane, lane_height, default_shape, _, _, _, _, fader_scaling =
                BR_EnvGetProperties(br_env)

            if not visible then
                BR_EnvSetProperties(br_env, active, true, armed, in_lane, lane_height, default_shape, fader_scaling)
                shown = shown + 1
            end

            BR_EnvFree(br_env, true)
        end
    end

    return shown
end

---------------------------------------------------------------------

main()
