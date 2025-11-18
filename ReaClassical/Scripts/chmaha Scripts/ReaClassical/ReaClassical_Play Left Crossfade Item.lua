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
local main, move_cursor_to_time_selection_midpoint, get_color_table
local get_path, on_stop, marker_actions
---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end
    local in_bounds = GetToggleCommandStateEx(32065, 43664)
    if in_bounds ~= 1 then CrossfadeEditor_OnCommand(43664) end
    -- check if left or right item is muted
    local left_mute = GetToggleCommandStateEx(32065, 43633)
    local right_mute = GetToggleCommandStateEx(32065, 43634)
    if left_mute == 1 then CrossfadeEditor_OnCommand(43633) end
    if right_mute == 0 then CrossfadeEditor_OnCommand(43634) end
    local midpoint = move_cursor_to_time_selection_midpoint()
    local colors = get_color_table()
    CSurf_OnPlayRateChange(1)
    -- prevent action 43491 from not playing if mouse cursor doesn't move
    CrossfadeEditor_OnCommand(43483) -- decrease preview momentarily

    CrossfadeEditor_OnCommand(43491) -- set pre/post and play both items
    AddProjectMarker2(0, false, midpoint, 0, "!1016", 1016, colors.audition)
    marker_actions()
    on_stop()
end

---------------------------------------------------------------------

function move_cursor_to_time_selection_midpoint()
    local start_time, end_time = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if start_time == end_time then
        return nil -- no active time selection
    end

    local midpoint = (start_time + end_time) / 2
    SetEditCurPos(midpoint, true, false) -- move cursor, seek playback if playing
    return midpoint
end

---------------------------------------------------------------------

function get_color_table()
    local resource_path = GetResourcePath()
    local relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "")
    package.path = package.path .. ";" .. resource_path .. relative_path .. "?.lua;"
    return require("ReaClassical_Colors_Table")
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

function on_stop()
    if GetPlayState() == 0 then
        DeleteProjectMarker(NULL, 1016, false)
        Main_OnCommand(41185, 0) -- Item properties: Unsolo all
        return
    else
        defer(on_stop)
    end
end

---------------------------------------------------------------------

function marker_actions()
    local markers = {}
    local next_idx = 1
    local tolerance = 0.05 -- seconds (50 ms)

    -- Pre-scan markers once
    local num_markers, num_regions = CountProjectMarkers(0)
    for i = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, _, name, mark_idx = EnumProjectMarkers(i)
        if retval and not isrgn and name:sub(1, 1) == "!" then
            local cmd = tonumber(name:sub(2))
            if cmd then
                table.insert(markers, { pos = pos, cmd = cmd, mark_idx = mark_idx })
            end
        end
    end

    table.sort(markers, function(a, b) return a.pos < b.pos end)

    local function reset_marker_index(play_pos)
        for i, m in ipairs(markers) do
            if m.pos >= play_pos then
                next_idx = i
                return
            end
        end
        next_idx = 1
    end

    local function check_next_marker()
        local state = GetPlayState()
        if state & 1 == 0 then
            reset_marker_index(GetCursorPosition())
        else
            if markers[next_idx] then
                local play_pos = GetPlayPosition()
                local target = markers[next_idx]
                if play_pos >= target.pos - tolerance then
                    Main_OnCommand(target.cmd, 0)
                    -- Check immediately if playback has stopped
                    if GetPlayState() & 1 == 0 then
                        return -- stop script entirely
                    end
                    next_idx = next_idx + 1
                    if next_idx > #markers then
                        next_idx = 1
                    end
                end
            end
        end
        defer(check_next_marker)
    end

    reset_marker_index(GetCursorPosition())
    check_next_marker()
end

---------------------------------------------------------------------

main()
