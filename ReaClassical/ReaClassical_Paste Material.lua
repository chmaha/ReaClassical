--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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
local main, check_hidden_track_items, check_for_overrun

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    Undo_BeginBlock()
    local initial_track_count = CountTracks(0)
    Main_OnCommand(42398, 0) -- paste items/tracks
    local final_track_count = CountTracks(0)
    if check_hidden_track_items() then
        ShowMessageBox("Warning: Items have been pasted on hidden tracks! " ..
            "You definitely want to undo this operation...", "ReaClassical Paste", 0)
        return
    end
    if final_track_count > initial_track_count then
        ShowMessageBox(
            "Warning: Items have been pasted on new tracks outside of the existing groups! " ..
            "You probably want to undo this operation...", "ReaClassical Paste", 0)
        return
    end
    if check_for_overrun() then
        ShowMessageBox(
            "Warning: Your pasted material has overrun into the next folder! " ..
            "You probably want to undo this operation...", "ReaClassical Paste", 0)
        return
    end
    Undo_EndBlock('ReaClassical Paste', 0)
end

---------------------------------------------------------------------

function check_hidden_track_items()
    local track_count = CountTracks(0)

    for i = 0, track_count - 1 do
        local track = GetTrack(0, i)
        if track then
            local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
            local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
            local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
            local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

            if mixer_state ~= "" or aux_state ~= "" or submix_state ~= "" or rcmaster_state ~= "" then
                local item_count = CountTrackMediaItems(track)
                if item_count > 0 then
                    return true
                end
            end
        end
    end
    return false
end

---------------------------------------------------------------------

function check_for_overrun()
    local item_count = CountSelectedMediaItems(0)
    if item_count == 0 then return false end

    local checked_tracks = {}
    local first_track_guid = nil

    for i = 0, item_count - 1 do
        local item = GetSelectedMediaItem(0, i)
        if item then
            local track = GetMediaItemTrack(item)
            if track then
                local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
                local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

                if not first_track_guid then
                    first_track_guid = guid -- Store first track GUID
                elseif not checked_tracks[guid] and folder_depth == 1 then
                    return true             -- Found a second unique parent track
                end

                checked_tracks[guid] = true
            end
        end
    end

    return false -- No additional unique folder track found
end

---------------------------------------------------------------------

main()
