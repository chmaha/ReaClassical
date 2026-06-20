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

local main, nudge_selected_markers, humanize_marker_label

---------------------------------------------------------------------

-- Maps the known ReaClassical S-D marker types to a humanized, lower-case
-- form ("destination in", "source out", etc.) so OSARA doesn't read IN/OUT
-- as letter-by-letter abbreviations. Any folder prefix (e.g. "S2:") is
-- stripped along with everything else -- the folder isn't announced.
-- Falls back to the raw marker name for anything else.
function humanize_marker_label(raw_name)
    if not raw_name or raw_name == "" then return "marker" end
    local label = raw_name:match(":(.+)$") or raw_name
    local map = {
        ["DEST-IN"] = "destination in",
        ["DEST-OUT"] = "destination out",
        ["SOURCE-IN"] = "source in",
        ["SOURCE-OUT"] = "source out",
    }
    return map[label] or raw_name
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

    local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
    local ms = tonumber(stored) or 5
    local amount = ms / 1000

    local moved, label = nudge_selected_markers(amount)
    if moved == 0 then
        say("No marker selected")
    elseif moved == 1 then
        say(humanize_marker_label(label) .. " nudged " .. ms .. " milliseconds right")
    else
        say(moved .. " markers nudged " .. ms .. " milliseconds right")
    end
end

---------------------------------------------------------------------

-- Nudges every selected (non-region) project marker by `amount` seconds,
-- clamped at 0. Returns how many were moved, plus the label of the last
-- one moved (used for the single-marker announcement).
function nudge_selected_markers(amount)
    Undo_BeginBlock()

    local proj = EnumProjects(-1)
    local total = GetNumRegionsOrMarkers(proj)
    local moved = 0
    local last_label

    for i = 0, total - 1 do
        local marker = GetRegionOrMarker(proj, i, "")
        if GetRegionOrMarkerInfo_Value(proj, marker, "B_ISREGION") == 0
            and GetRegionOrMarkerInfo_Value(proj, marker, "B_UISEL") == 1 then
            local pos = GetRegionOrMarkerInfo_Value(proj, marker, "D_STARTPOS")
            local new_pos = math.max(0, pos + amount)
            SetRegionOrMarkerInfo_Value(proj, marker, "D_STARTPOS", new_pos)

            local _, name = GetSetRegionOrMarkerInfo_String(proj, marker, "P_NAME", "", false)
            moved = moved + 1
            last_label = name ~= "" and name or "Marker"
        end
    end

    Undo_EndBlock("Nudge marker right", -1)
    UpdateArrange()
    UpdateTimeline()
    return moved, last_label
end

---------------------------------------------------------------------

main()
