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

local M = {}

local FLAG_KEY = "P_EXT:cue_solo"
local FLAG_ADDED_MAINSEND = "r"
local FLAG_KEPT_MAINSEND = "y"

local CUE_TYPES = { "mixer", "aux", "submix", "roomtone", "rcref", "live", "listenback", "rcmaster" }

local function get_flag(track)
    local _, v = GetSetMediaTrackInfo_String(track, FLAG_KEY, "", false)
    return v
end

local function set_flag(track, v)
    GetSetMediaTrackInfo_String(track, FLAG_KEY, v, true)
end

local function is_rcmaster(track)
    local _, v = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
    if v == "y" then return true end
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return name:match("^RCMASTER") ~= nil
end

local function find_rcmaster()
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if is_rcmaster(t) then return t end
    end
    return nil
end

local function is_cue_type(track)
    for _, key in ipairs(CUE_TYPES) do
        local _, v = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if v == "y" then return true end
    end
    return is_rcmaster(track)
end

local function each_flagged(fn)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        local f = get_flag(t)
        if f ~= "" then fn(t, f) end
    end
end

local function update_rcmaster()
    local rcmaster = find_rcmaster()
    if not rcmaster then return end
    local any_other, rcm_soloed = false, false
    each_flagged(function(t)
        if t == rcmaster then rcm_soloed = true else any_other = true end
    end)
    local want = (any_other and not rcm_soloed) and 0 or 1
    if GetMediaTrackInfo_Value(rcmaster, "B_MAINSEND") ~= want then
        SetMediaTrackInfo_Value(rcmaster, "B_MAINSEND", want)
    end
end

local function cue_on(track)
    if get_flag(track) ~= "" then return end
    if is_rcmaster(track) then
        set_flag(track, FLAG_KEPT_MAINSEND)
    elseif GetMediaTrackInfo_Value(track, "B_MAINSEND") == 0 then
        SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
        set_flag(track, FLAG_ADDED_MAINSEND)
    else
        set_flag(track, FLAG_KEPT_MAINSEND)
    end
end

local function cue_off(track)
    local f = get_flag(track)
    if f == "" then return end
    if f == FLAG_ADDED_MAINSEND then
        SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
    end
    set_flag(track, "")
end

function M.enabled()
    local _, v = GetProjExtState(0, "ReaClassical", "CueSolo")
    return v == "y"
end

function M.applies_to(track)
    return M.enabled() and is_cue_type(track)
end

function M.is_soloed(track)
    if M.applies_to(track) then
        return get_flag(track) ~= ""
    end
    return GetMediaTrackInfo_Value(track, "I_SOLO") > 0
end

function M.set(track, on, native_mode)
    if M.applies_to(track) then
        if GetMediaTrackInfo_Value(track, "I_SOLO") ~= 0 then
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
        if on then cue_on(track) else cue_off(track) end
        update_rcmaster()
    else
        SetMediaTrackInfo_Value(track, "I_SOLO", on and (native_mode or 2) or 0)
    end
end

function M.toggle(track)
    local now_on = not M.is_soloed(track)
    M.set(track, now_on)
    return now_on
end

function M.clear_all()
    each_flagged(cue_off)
    update_rcmaster()
end

function M.exclusive(track, native_mode)
    if M.applies_to(track) then
        Main_OnCommand(40340, 0)
        M.clear_all()
        M.set(track, true)
    else
        Main_OnCommand(40340, 0)
        M.clear_all()
        SetMediaTrackInfo_Value(track, "I_SOLO", native_mode or 2)
    end
end

function M.unsolo_everything()
    Main_OnCommand(40340, 0)
    M.clear_all()
end

function M.refresh()
    if not M.enabled() then
        local had = false
        each_flagged(function() had = true end)
        if had then M.clear_all() end
        return
    end
    each_flagged(function(t, f)
        if f == FLAG_ADDED_MAINSEND and GetMediaTrackInfo_Value(t, "B_MAINSEND") == 0 then
            SetMediaTrackInfo_Value(t, "B_MAINSEND", 1)
        end
    end)
    update_rcmaster()
end

function M.set_enabled(on)
    if on == M.enabled() then return end
    if on then
        SetProjExtState(0, "ReaClassical", "CueSolo", "y")
        for i = 0, CountTracks(0) - 1 do
            local t = GetTrack(0, i)
            if is_cue_type(t) and GetMediaTrackInfo_Value(t, "I_SOLO") > 0 then
                SetMediaTrackInfo_Value(t, "I_SOLO", 0)
                cue_on(t)
            end
        end
        update_rcmaster()
    else
        local soloed = {}
        each_flagged(function(t) soloed[#soloed + 1] = t end)
        M.clear_all()
        SetProjExtState(0, "ReaClassical", "CueSolo", "")
        for _, t in ipairs(soloed) do
            SetMediaTrackInfo_Value(t, "I_SOLO", 2)
        end
    end
end

return M
