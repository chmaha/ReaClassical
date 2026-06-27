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

local main, is_special_track, get_folder_parent

---------------------------------------------------------------------

function is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

---------------------------------------------------------------------

function get_folder_parent(track)
    if not track then return nil end
    local idx = math.floor(GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1)
    if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
        return not is_special_track(track) and track or nil
    end
    for i = idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
            return not is_special_track(t) and t or nil
        end
    end
    return nil
end

---------------------------------------------------------------------

function main()
    local selected = GetSelectedTrack(0, 0)
    if not selected then
        say("No track selected.")
        return
    end
    local parent = get_folder_parent(selected)
    if not parent then
        say("Not in a ReaClassical folder.")
        return
    end
    local count = CountTrackMediaItems(parent)
    say(count .. (count == 1 and " item" or " items"))
end

---------------------------------------------------------------------

main()
