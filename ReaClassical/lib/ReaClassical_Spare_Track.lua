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

local function ext(track, key)
    local _, value = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
    return value
end

function M.is_spare(track)
    return track ~= nil and ext(track, "spare") == "y"
end

function M.is_spare_mixer(track)
    return M.is_spare(track) and ext(track, "mixer") == "y"
end

function M.folder_children(parent)
    local children = {}
    if not parent then return children end
    local idx = math.floor(GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER"))
    local depth = 1
    for i = idx, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        children[#children + 1] = track
        depth = depth + GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if depth <= 0 then break end
    end
    return children
end

function M.is_spare_folder(parent)
    if not parent or GetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH") ~= 1 then
        return false
    end
    local children = M.folder_children(parent)
    if #children == 0 then return false end
    for _, child in ipairs(children) do
        if not M.is_spare(child) then return false end
    end
    return true
end

function M.mark(track, is_mixer)
    GetSetMediaTrackInfo_String(track, "P_EXT:spare", "y", true)
    if is_mixer then
        SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
        SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
    else
        SetMediaTrackInfo_Value(track, "I_RECARM", 0)
        SetMediaTrackInfo_Value(track, "I_RECMODE", 2)
        SetMediaTrackInfo_Value(track, "I_RECINPUT", -1)
    end
end

function M.unmark(track, is_mixer)
    GetSetMediaTrackInfo_String(track, "P_EXT:spare", "", true)
    if is_mixer then
        SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 1)
    else
        SetMediaTrackInfo_Value(track, "I_RECMODE", 0)
    end
end

function M.apply_state()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if M.is_spare(track) then
            if ext(track, "mixer") == "y" then
                SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
                SetMediaTrackInfo_Value(track, "B_SHOWINMIXER", 0)
            else
                SetMediaTrackInfo_Value(track, "I_RECMODE", 2)
                local parent = GetParentTrack(track)
                if parent and M.is_spare_folder(parent)
                    and GetMediaTrackInfo_Value(parent, "I_FOLDERCOMPACT") ~= 2 then
                    SetMediaTrackInfo_Value(parent, "I_FOLDERCOMPACT", 2)
                end
            end
        end
    end
end

local SPECIAL_KEYS = { "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }

local function is_special_non_mixer(track)
    for _, key in ipairs(SPECIAL_KEYS) do
        if ext(track, key) == "y" then return true end
    end
    return false
end

function M.has_spares()
    for i = 0, CountTracks(0) - 1 do
        if M.is_spare(GetTrack(0, i)) then return true end
    end
    return false
end

function M.activate(name)
    local found = false
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if M.is_spare(track) then
            found = true
            if ext(track, "mixer") == "y" then
                M.unmark(track, true)
                if name and name ~= "" then
                    GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. name, true)
                end
            else
                local parent = GetParentTrack(track)
                M.unmark(track, false)
                if parent and GetMediaTrackInfo_Value(parent, "I_FOLDERCOMPACT") == 2 then
                    SetMediaTrackInfo_Value(parent, "I_FOLDERCOMPACT", workflow == "Horizontal" and 0 or 1)
                end
            end
        end
    end
    return found
end

function M.retire_second_track(delete_items)
    local converted = 0
    local last_mixer
    local n = CountTracks(0)
    for i = 0, n - 1 do
        local track = GetTrack(0, i)
        if ext(track, "mixer") == "y" and not M.is_spare(track) then last_mixer = track end
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1
            and ext(track, "mixer") ~= "y" and not is_special_non_mixer(track) then
            local child = GetTrack(0, i + 1)
            if child and GetMediaTrackInfo_Value(child, "I_FOLDERDEPTH") < 0 and not M.is_spare(child) then
                if delete_items then
                    for j = CountTrackMediaItems(child) - 1, 0, -1 do
                        DeleteTrackMediaItem(child, GetTrackMediaItem(child, j))
                    end
                    GetSetMediaTrackInfo_String(child, "P_NAME", "", true)
                end
                M.mark(child, false)
                converted = converted + 1
            end
        end
    end
    if converted > 0 and last_mixer then
        M.mark(last_mixer, true)
        if delete_items then GetSetMediaTrackInfo_String(last_mixer, "P_NAME", "M:", true) end
    end
    M.apply_state()
    return converted
end

return M
