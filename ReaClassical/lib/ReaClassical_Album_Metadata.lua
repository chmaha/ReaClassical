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

local function find_legacy_item(folder_track)
    if not folder_track then return nil end
    for i = 0, CountTrackMediaItems(folder_track) - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if name and name:match("^@") then
                return item
            end
        end
    end
    return nil
end

function M.get_album_metadata_str(folder_track)
    local _, str = GetProjExtState(0, "ReaClassical", "AlbumMetadata")
    if str and str ~= "" then
        return str, nil
    end

    local legacy_item = find_legacy_item(folder_track)
    if not legacy_item then
        return nil, nil
    end

    local take = GetActiveTake(legacy_item)
    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    return (name:gsub("|$", "")), legacy_item
end

function M.set_album_metadata_str(folder_track, str, legacy_item)
    if legacy_item then
        local take = GetActiveTake(legacy_item)
        if take then
            GetSetMediaItemTakeInfo_String(take, "P_NAME", str, true)
        end
        return
    end
    SetProjExtState(0, "ReaClassical", "AlbumMetadata", str)
end

return M
