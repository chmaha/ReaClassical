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
local say = require("ReaClassical_Announce")

local retval, user_input = GetUserInputs("ReaClassical: Jump to Track", 1, "Track:,extrawidth=300", "")
if not retval then return end

user_input = user_input:match("^%s*(.-)%s*$")
if user_input == "" then return end

if GetExtState("ReaClassical", "MixerMode") == "1" then
    local mm = require("ReaClassical_MM_Utils")

    local query = user_input:lower()
    for _, t in ipairs(mm.get_special_tracks_list()) do
        if mm.get_label(t):lower():find(query, 1, true) then
            mm.set_current_target(t)
            say(mm.get_label(t) .. ", " .. mm.format_peak(t) .. mm.status_suffix(t))
            return
        end
    end
    say("No special track found matching: " .. user_input)
    return
end

local folder_scan = require("ReaClassical_Folder_Scan")
local spare_track = require("ReaClassical_Spare_Track")
local humanize_track_name = require("ReaClassical_Track_Naming")

local selected = GetSelectedTrack(0, 0)
if not selected then
    say("No track selected")
    return
end

local parent, parent_idx = folder_scan.get_folder_parent(selected)
if not parent then
    say("Not in a ReaClassical folder")
    return
end

if GetMediaTrackInfo_Value(parent, "I_FOLDERCOMPACT") == 2 and not spare_track.is_spare_folder(parent) then
    SetMediaTrackInfo_Value(parent, "I_FOLDERCOMPACT", 1)
end

local query = user_input:lower()
for _, entry in ipairs(folder_scan.get_folder_tracks(parent, parent_idx)) do
    local _, name = GetSetMediaTrackInfo_String(entry.track, "P_NAME", "", false)
    if humanize_track_name(name):lower():find(query, 1, true) then
        SetOnlyTrackSelected(entry.track)
        TrackList_AdjustWindows(false)
        say(humanize_track_name(name))
        return
    end
end
say("No track found matching: " .. user_input)
