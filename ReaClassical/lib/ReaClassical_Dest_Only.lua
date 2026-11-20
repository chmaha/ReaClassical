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

local M = {}

local EXT_SECTION = "ReaClassical_MissionControl"

function M.folders()
    local folders = {}
    local folder_count = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folder_count = folder_count + 1
            local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
            folders[#folders + 1] = {
                track = track,
                prefix = track_name:match("^([^:]+):") or ("Folder " .. folder_count),
                guid = guid,
                index = i
            }
        end
    end
    return folders
end

local function folder_members(folder_info)
    local tracks = { folder_info.track }
    local child_idx = folder_info.index + 1
    local depth = 1
    while child_idx < CountTracks(0) and depth > 0 do
        local child_track = GetTrack(0, child_idx)
        tracks[#tracks + 1] = child_track
        depth = depth + GetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH")
        child_idx = child_idx + 1
    end
    return tracks
end

function M.set_folder_visible(folder_info, state)
    if not folder_info or not ValidatePtr(folder_info.track, "MediaTrack*") then return end
    for _, track in ipairs(folder_members(folder_info)) do
        SetMediaTrackInfo_Value(track, "B_SHOWINTCP", state and 1 or 0)
    end
    SetProjExtState(0, EXT_SECTION, "folder_tcp_visible_" .. folder_info.guid, state and "1" or "0")
end

function M.dest_height()
    local _, height_str = GetProjExtState(0, EXT_SECTION, "dest_only_height")
    return tonumber(height_str) or 0
end

function M.set_dest_height(height)
    SetProjExtState(0, EXT_SECTION, "dest_only_height", tostring(height))
end

function M.set(dest_only, folders)
    folders = folders or M.folders()
    local dest_height = M.dest_height()

    for _, folder_info in ipairs(folders) do
        local is_dest = folder_info.prefix == "D"
        M.set_folder_visible(folder_info, dest_only and is_dest or not dest_only)

        if is_dest and ValidatePtr(folder_info.track, "MediaTrack*") then
            for _, track in ipairs(folder_members(folder_info)) do
                local _, saved = GetSetMediaTrackInfo_String(track, "P_EXT:rc_prev_height", "", false)
                if dest_only and dest_height > 0 then
                    if saved == "" then
                        local current = GetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE")
                        GetSetMediaTrackInfo_String(track, "P_EXT:rc_prev_height", tostring(current), true)
                    end
                    SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", dest_height)
                elseif not dest_only and saved ~= "" then
                    SetMediaTrackInfo_Value(track, "I_HEIGHTOVERRIDE", tonumber(saved) or 0)
                    GetSetMediaTrackInfo_String(track, "P_EXT:rc_prev_height", "", true)
                end
            end
        end
    end

    TrackList_AdjustWindows(false)
    UpdateArrange()
end

function M.run_action(dest_only, label)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return false
    end
    if workflow ~= "Vertical" then
        MB("This function is only available in the Vertical workflow.", "ReaClassical Error", 0)
        return false
    end
    Undo_BeginBlock()
    PreventUIRefresh(1)
    M.set(dest_only)
    PreventUIRefresh(-1)
    Undo_EndBlock(label, -1)
    return true
end

return M
