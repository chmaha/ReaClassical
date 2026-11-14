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
local gui_mode = require("ReaClassical_GuiMode")
local humanize_track_name = require("ReaClassical_Track_Naming")
local say = require("ReaClassical_Announce")
local item_utils = require("ReaClassical_Item_Utils")
local peak_scan = require("ReaClassical_Peak_Scan")

local main, report, find_peak, threshold_text

local TITLE = "Item Peak Check"

function report(msg)
    if gui_mode.accessible() then
        say(msg)
    else
        MB(msg, TITLE, 0)
    end
end

function find_peak(ref_item)
    local result
    for _, item in ipairs(item_utils.get_item_peers(ref_item)) do
        local track = GetMediaItemTrack(item)
        local gain = peak_scan.chain_gain(track)
        if gain then
            peak_scan.scan_item(item, gain, function(pos, db)
                if not result or db > result.db then
                    result = result or {}
                    result.db, result.pos, result.track = db, pos, track
                end
            end)
        end
    end
    if result then
        local _, name = GetTrackName(result.track)
        result.track_name = humanize_track_name(name)
    end
    return result
end

function threshold_text(db, threshold)
    local diff = db - threshold
    if diff >= 0 then
        return string.format("%.2f dB over the %.1f dB threshold.", diff, threshold)
    end
    return string.format("%.2f dB below the %.1f dB threshold.", -diff, threshold)
end

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

    if not APIExists("CF_GetSWSVersion") then
        MB("Please install the SWS extension before running this function", "Error: Missing Extension", 0)
        return
    end

    local item = GetSelectedMediaItem(0, 0)
    if not item then
        report("No item selected.")
        return
    end

    local peak = find_peak(item)
    if not peak then
        report("No audio found in this item or its children.")
        return
    end

    local _, saved = GetProjExtState(0, "ReaClassical", "PeaksThreshold")
    local threshold = tonumber(saved) or -1.0

    SetEditCurPos(peak.pos, true, false)
    SetOnlyTrackSelected(peak.track)
    Main_OnCommand(40913, 0)

    report(string.format("Peak before effects: %.2f dB at %s (%s). %s",
        peak.db, format_timestr_pos(peak.pos, "", 0), peak.track_name, threshold_text(peak.db, threshold)))
end

main()
