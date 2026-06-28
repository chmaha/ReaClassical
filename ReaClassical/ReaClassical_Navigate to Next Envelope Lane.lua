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
local humanize_track_name = require("ReaClassical_Track_Naming")
local say = require("ReaClassical_Announce")

local main, announce_selected_envelope

local SPECIAL_PEXTS = { "mixer", "aux", "submix", "roomtone", "rcref", "live", "listenback" }

local function is_special_track(t)
    for _, pext in ipairs(SPECIAL_PEXTS) do
        local _, v = GetSetMediaTrackInfo_String(t, "P_EXT:" .. pext, "", false)
        if v == "y" then return true end
    end
    return false
end

local function get_track_envelopes(t)
    local envs = {}
    for i = 0, CountTrackEnvelopes(t) - 1 do
        envs[#envs + 1] = GetTrackEnvelope(t, i)
    end
    return envs
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

    local sel_track = GetSelectedTrack(0, 0)
    if sel_track and is_special_track(sel_track) then
        local envs = get_track_envelopes(sel_track)
        if #envs == 0 then
            say("No envelope lanes on this track")
            return
        end
        local cur_env = GetSelectedEnvelope(0)
        local cur_pos = nil
        if cur_env and Envelope_GetParentTrack(cur_env) == sel_track then
            for i, env in ipairs(envs) do
                if env == cur_env then cur_pos = i; break end
            end
        end
        if cur_pos and cur_pos >= #envs then
            say("Last envelope lane")
            return
        end
        SetCursorContext(2, envs[(cur_pos or 0) + 1])
        UpdateArrange()
        UpdateTimeline()
        announce_selected_envelope()
        return
    end

    Main_OnCommand(41864, 0) -- Move to next envelope lane

    UpdateArrange()
    UpdateTimeline()
    announce_selected_envelope()
end

---------------------------------------------------------------------

main()
