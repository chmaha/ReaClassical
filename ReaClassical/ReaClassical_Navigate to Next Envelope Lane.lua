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
package.path = package.path .. ";" .. script_path .. "?.lua;"
local humanize_track_name = require("ReaClassical_Track_Naming")

local main, say, announce_selected_envelope

---------------------------------------------------------------------

function say(msg)
    if osara_outputMessage then
        osara_outputMessage(tostring(msg))
    end
end

---------------------------------------------------------------------

-- Announces "<humanized track name>, <envelope name>" (e.g. "Destination
-- Main Left, Volume") for whichever envelope is now selected, instead of
-- OSARA's own focus announcement which would just read the raw track name.
function announce_selected_envelope()
    local env = GetSelectedEnvelope(0)
    if not env then
        say("No envelope lane")
        return
    end

    local _, env_name = GetEnvelopeName(env, "")
    local track = Envelope_GetParentTrack(env)

    local track_label
    if track then
        if track == GetMasterTrack(0) then
            track_label = "Master"
        else
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            track_label = humanize_track_name(track_name)
        end
        say(track_label .. ", " .. env_name)
        return
    end

    local take = Envelope_GetParentTake(env, 0, -1)
    if take then
        local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        say((item_name ~= "" and item_name or "(unnamed item)") .. ", " .. env_name)
        return
    end

    say(env_name)
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

    Main_OnCommand(41864, 0) -- Move to next envelope lane

    UpdateArrange()
    UpdateTimeline()
    announce_selected_envelope()
end

---------------------------------------------------------------------

main()
