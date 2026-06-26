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
local say = require("ReaClassical_Announce")

---------------------------------------------------------------------

local SPECIAL_PEXTS = { "mixer", "aux", "submix", "roomtone", "rcref", "live", "listenback" }

---------------------------------------------------------------------

local function is_special_track(t)
    for _, pext in ipairs(SPECIAL_PEXTS) do
        local _, v = GetSetMediaTrackInfo_String(t, "P_EXT:" .. pext, "", false)
        if v == "y" then return true, pext end
    end
    return false, nil
end

---------------------------------------------------------------------

local function announce_special(t, pext)
    local _, name = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
    if pext == "mixer" then
        local s = name:match("^M:(.+)") or ""
        say(s ~= "" and ("mixer " .. s) or "mixer")
    elseif pext == "aux" then
        local s = name:match("^@(.+)") or ""
        say(s ~= "" and (s .. " auxiliary") or "auxiliary")
    elseif pext == "submix" then
        local s = name:match("^#(.+)") or ""
        say(s ~= "" and (s .. " submix") or "submix")
    elseif pext == "rcref" then
        local s = name:match("^REF:(.+)") or ""
        say(s ~= "" and (s .. " reference") or "reference")
    elseif pext == "live" then
        say("live")
    elseif pext == "roomtone" then
        say("room tone")
    elseif pext == "listenback" then
        say("listenback")
    else
        say(name ~= "" and name or pext)
    end
end

---------------------------------------------------------------------

-- Applies the correct solo/mute state when landing on a special track.
-- REF: unsolo all then solo=1 (REAPER's solo-in-place handles muting others)
-- LIVE: unsolo all then exclusive solo=2
-- Others: no change to solo state
local function apply_solo_for_special(t, pext)
    if pext == "rcref" then
        Main_OnCommand(40340, 0) -- unsolo all tracks
        SetMediaTrackInfo_Value(t, "B_MUTE", 0)
        SetMediaTrackInfo_Value(t, "I_SOLO", 1)
    elseif pext == "live" then
        Main_OnCommand(40340, 0) -- unsolo all tracks first
        SetMediaTrackInfo_Value(t, "B_MUTE", 0)
        SetMediaTrackInfo_Value(t, "I_SOLO", 2) -- exclusive solo
    end
end

---------------------------------------------------------------------

-- Shows all special tracks (except listenback) in TCP so the user can navigate them.
local function ensure_special_visible()
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        for _, pext in ipairs(SPECIAL_PEXTS) do
            local _, v = GetSetMediaTrackInfo_String(t, "P_EXT:" .. pext, "", false)
            if v == "y" then
                if pext ~= "listenback" then
                    SetMediaTrackInfo_Value(t, "B_SHOWINTCP", 1)
                end
                break
            end
        end
    end
end

---------------------------------------------------------------------

-- Clears REF/LIVE solo state when leaving those track types.
local function clear_solo_for_special(t, pext)
    if pext == "rcref" or pext == "live" then
        Main_OnCommand(40340, 0) -- unsolo all
        SetMediaTrackInfo_Value(t, "B_MUTE", 1)
    end
end

---------------------------------------------------------------------

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then modifier = "Cmd" end
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.",
        "ReaClassical Error", 0)
    return
end

local current = GetSelectedTrack(0, 0)
local on_special, pext_type = false, nil
if current then
    on_special, pext_type = is_special_track(current)
end

if on_special then
    -- Store this special track so Toggle can return to it next time
    local special_idx = math.floor(GetMediaTrackInfo_Value(current, "IP_TRACKNUMBER") - 1)
    SetProjExtState(0, "ReaClassical", "LastSpecialTrackIdx", tostring(special_idx))

    -- Clear REF/LIVE solo before leaving the special track section
    clear_solo_for_special(current, pext_type)

    -- Return to the last stored folder track
    local _, idx_str = GetProjExtState(0, "ReaClassical", "LastFolderTrackIdx")
    local idx = tonumber(idx_str)
    local restored = false
    if idx then
        local t = GetTrack(0, idx)
        if t and not is_special_track(t) then
            SetOnlyTrackSelected(t)
            TrackList_AdjustWindows(false)
            SetMediaTrackInfo_Value(t, "I_SOLO", 2) -- exclusive solo on return
            local _, name = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
            say(name ~= "" and name or "Track " .. (idx + 1))
            restored = true
        end
    end
    if not restored then
        for i = 0, CountTracks(0) - 1 do
            local t = GetTrack(0, i)
            if GetMediaTrackInfo_Value(t, "B_SHOWINTCP") == 1 and not is_special_track(t) then
                SetOnlyTrackSelected(t)
                TrackList_AdjustWindows(false)
                SetMediaTrackInfo_Value(t, "I_SOLO", 2)
                local _, name = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
                say(name ~= "" and name or "Track " .. (i + 1))
                return
            end
        end
        say("No folder tracks found")
    end
else
    -- Store the current folder track so Toggle can return to it
    if current then
        local idx = math.floor(GetMediaTrackInfo_Value(current, "IP_TRACKNUMBER") - 1)
        SetProjExtState(0, "ReaClassical", "LastFolderTrackIdx", tostring(idx))
    end

    -- With OSARA, force all special tracks visible so the user can navigate them.
    -- Without OSARA, respect whatever the user has manually shown via Mission Control.
    if APIExists("osara_outputMessage") then
        ensure_special_visible()
    end

    -- Try to return to the last visited special track
    local _, sidx_str = GetProjExtState(0, "ReaClassical", "LastSpecialTrackIdx")
    local sidx = tonumber(sidx_str)
    if sidx then
        local t = GetTrack(0, sidx)
        if t then
            local spec, pext = is_special_track(t)
            if spec and GetMediaTrackInfo_Value(t, "B_SHOWINTCP") == 1 then
                SetOnlyTrackSelected(t)
                TrackList_AdjustWindows(false)
                apply_solo_for_special(t, pext)
                announce_special(t, pext)
                return
            end
        end
    end

    -- Fall back to first visible special track
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetMediaTrackInfo_Value(t, "B_SHOWINTCP") == 1 then
            local spec, pext = is_special_track(t)
            if spec then
                SetOnlyTrackSelected(t)
                TrackList_AdjustWindows(false)
                apply_solo_for_special(t, pext)
                announce_special(t, pext)
                return
            end
        end
    end
    say("No special tracks found")
end
