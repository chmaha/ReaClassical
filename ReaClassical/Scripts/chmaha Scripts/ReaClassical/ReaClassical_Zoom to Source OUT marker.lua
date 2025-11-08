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

local main, markers, move_to_project_tab, zoom

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local _, source_proj = markers()

    if source_proj then
        move_to_project_tab(source_proj)
    end

    GoToMarker(0, 999, false)
    zoom()
end

---------------------------------------------------------------------

function zoom()
    local cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    SetEditCurPos(cur_pos - 3, false, false)
    Main_OnCommand(40625, 0)             -- Time selection: Set start point
    SetEditCurPos(cur_pos + 3, false, false)
    Main_OnCommand(40626, 0)             -- Time selection: Set end point
    local zoom_to_selection = NamedCommandLookup("_SWS_ZOOMSIT")
    Main_OnCommand(zoom_to_selection, 0) -- SWS: Zoom to selected items or time selection
    SetEditCurPos(cur_pos, false, false)
    Main_OnCommand(1012, 0)              -- View: Zoom in horizontal
    Main_OnCommand(40635, 0)             -- Time selection: Remove (unselect) time selection
end

---------------------------------------------------------------------

function markers()
    local marker_labels = { "DEST-IN", "DEST-OUT", "SOURCE-IN", "SOURCE-OUT" }
    local sd_markers = {}
    for _, label in ipairs(marker_labels) do
        sd_markers[label] = { count = 0, proj = nil }
    end

    local num = 0
    local source_proj, dest_proj
    local proj_marker_count = 0
    local pos_table = {}
    local active_proj = EnumProjects(-1)
    local track_number = 1
    while true do
        local proj = EnumProjects(num)
        if proj == nil then
            break
        end
        local _, num_markers, num_regions = CountProjectMarkers(proj)
        for i = 0, num_markers + num_regions - 1, 1 do
            local _, _, pos, _, raw_label, _ = EnumProjectMarkers2(proj, i)
            local number = string.match(raw_label, "(%d+):.+")
            local label = string.match(raw_label, "%d*:?(.+)") or ""

            if label == "DEST-IN" then
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[1] = pos
            elseif label == "DEST-OUT" then
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[2] = pos
            elseif label == "SOURCE-IN" then
                track_number = number
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[3] = pos
            elseif label == "SOURCE-OUT" then
                track_number = number
                sd_markers[label].count = 1
                sd_markers[label].proj = proj
                pos_table[4] = pos
            elseif string.match(label, "SOURCE PROJECT") then
                source_proj = proj
                proj_marker_count = proj_marker_count + 1
            elseif string.match(label, "DEST PROJECT") then
                dest_proj = proj
                proj_marker_count = proj_marker_count + 1
            end
        end
        num = num + 1
    end

    if proj_marker_count == 0 then
        for _, marker in pairs(sd_markers) do
            if marker.proj ~= active_proj then
                marker.count = 0
            end
        end
    end

    local source_in = sd_markers["SOURCE-IN"].count
    local source_out = sd_markers["SOURCE-OUT"].count
    local dest_in = sd_markers["DEST-IN"].count
    local dest_out = sd_markers["DEST-OUT"].count

    local sin = sd_markers["SOURCE-IN"].proj
    local sout = sd_markers["SOURCE-OUT"].proj
    local din = sd_markers["DEST-IN"].proj
    local dout = sd_markers["DEST-OUT"].proj


    local source_count = source_in + source_out
    local dest_count = dest_in + dest_out

    if (source_count == 2 and sin ~= sout) or (dest_count == 2 and din ~= dout) then proj_marker_count = -1 end

    if source_proj and ((sin and sin ~= source_proj) or (sout and sout ~= source_proj)) then
        proj_marker_count = -1
    end
    if dest_proj and ((din and din ~= dest_proj) or (dout and dout ~= dest_proj)) then
        proj_marker_count = -1
    end

    return proj_marker_count, source_proj, dest_proj, dest_in, dest_out, dest_count,
        source_in, source_out, source_count, pos_table, track_number
end

---------------------------------------------------------------------

function move_to_project_tab(proj_type)
    SelectProjectInstance(proj_type)
end

---------------------------------------------------------------------

main()
