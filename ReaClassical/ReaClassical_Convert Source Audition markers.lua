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
local main, convert_audition_markers

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    convert_audition_markers()

    Undo_EndBlock('Convert Audition Markers', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function convert_audition_markers()
    -- 1. Initial setup
    local curPos = GetCursorPosition()
    local markerCount = CountProjectMarkers(0)
    local start_pos, end_pos, start_tracknum, sai_color
    local marker_type = nil  -- "SAI" or "SAO"
    local sai_idx, sao_idx = nil, nil

    -- 2. Find SAI or SAO marker under edit cursor
    for i = 0, markerCount - 1 do
        local _, isrgn, pos, _, raw_label, _, color = EnumProjectMarkers3(0, i)
        if not isrgn and math.abs(pos - curPos) < 1e-9 then
            local number, suffix = raw_label:match("^(%d+):%s*(%S+)")
            if number and suffix then
                if suffix:match("^SAI") then
                    marker_type = "SAI"
                    start_tracknum = tonumber(number)
                    start_pos = pos
                    sai_color = color or 0
                    sai_idx = i
                elseif suffix:match("^SAO") then
                    marker_type = "SAO"
                    start_tracknum = tonumber(number)
                    end_pos = pos
                    sai_color = color or 0
                    sao_idx = i
                end
            end
            break
        end
    end

    -- Fail if no valid SAI/SAO marker under cursor
    if not marker_type or not start_tracknum then return false end

    -- 3. Depending on marker type, find the matching partner
    if marker_type == "SAI" then
        -- Find next SAO marker for same track
        for i = 0, markerCount - 1 do
            local _, isrgn, pos, _, name = EnumProjectMarkers(i)
            local num, suffix = name:match("^(%d+):%s*(%S+)")
            if not isrgn and num and tonumber(num) == start_tracknum then
                if pos > start_pos and suffix:match("^SAO") then
                    end_pos = pos
                    sao_idx = i
                    break
                end
            end
        end
    elseif marker_type == "SAO" then
        -- Find previous SAI marker for same track
        for i = markerCount - 1, 0, -1 do
            local _, isrgn, pos, _, name = EnumProjectMarkers(i)
            local num, suffix = name:match("^(%d+):%s*(%S+)")
            if not isrgn and num and tonumber(num) == start_tracknum then
                if pos < end_pos and suffix:match("^SAI") then
                    start_pos = pos
                    sai_idx = i
                    break
                end
            end
        end
    end

    -- Fail if no partner found
    if not start_pos or not end_pos then return false end

    -- 4. Create time selection between SAI and SAO
    GetSet_LoopTimeRange(true, false, start_pos, end_pos, false)

    -- 5. Check if we should keep remaining markers
    local keep_remaining = false
    if HasExtState("ReaClassical_SAI_Manager", "keep_markers_after_conversion") then
        local value = GetExtState("ReaClassical_SAI_Manager", "keep_markers_after_conversion")
        keep_remaining = (value == "true")
    end

    -- 6. Delete markers based on checkbox state
    if keep_remaining then
        -- Only delete the current SAI/SAO pair
        if sao_idx and sai_idx then
            -- Delete in reverse order to maintain indices
            if sao_idx > sai_idx then
                DeleteProjectMarkerByIndex(0, sao_idx)
                DeleteProjectMarkerByIndex(0, sai_idx)
            else
                DeleteProjectMarkerByIndex(0, sai_idx)
                DeleteProjectMarkerByIndex(0, sao_idx)
            end
        end
    else
        -- Delete all "SAI"/"SAO" markers (original behavior)
        for i = markerCount - 1, 0, -1 do
            local _, isrgn, _, _, name = EnumProjectMarkers(i)
            if not isrgn and (name:find("SAI") or name:find("SAO")) then
                DeleteProjectMarkerByIndex(0, i)
            end
        end
    end

    -- 7. Delete any existing SOURCE-IN (998) and SOURCE-OUT (999) markers before creating new ones
    local i = 0
    while true do
        local project, _ = EnumProjects(i)
        if project == nil then
            break
        else
            DeleteProjectMarker(project, 998, false)
            DeleteProjectMarker(project, 999, false)
        end
        i = i + 1
    end

    -- 8. Create SOURCE-IN and SOURCE-OUT markers using SAI color
    AddProjectMarker2(0, false, start_pos, 0, start_tracknum .. ":SOURCE-IN", 998, sai_color)
    AddProjectMarker2(0, false, end_pos, 0, start_tracknum .. ":SOURCE-OUT", 999, sai_color)
    Main_OnCommand(40635, 0) -- remove time selection

    -- 9. Disable razor selection
    local razor_enabled = GetToggleCommandState(42618) == 1
    if razor_enabled then Main_OnCommand(42618, 0) end

    -- 10. Clear arrange window override
    Main_OnCommand(42621, 0)

    return true
end


---------------------------------------------------------------------

main()