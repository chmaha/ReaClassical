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

local _gm_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. _gm_path .. "?.lua;" .. _gm_path .. "lib/?.lua;"
local gui_mode = require("ReaClassical_GuiMode")

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local is_accessible = APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed
local humanize_timestr = require("ReaClassical_Time_Naming")
local humanize_folder_phrase = require("ReaClassical_Folder_Naming")
local enum_project_markers = require("ReaClassical_Marker_Enum")

local main, get_color_table, other_dest_marker_check, find_marker_pos

local _, opened_string = GetProjExtState(0, "ReaClassical", "toolbaropened")

if opened_string ~= "y" then
    if not gui_mode.accessible() then
        local editing_toolbar = reaper.NamedCommandLookup("_RSdcbfd5e17e15e31f892e3fefdb1969b81d22b6df")
        Main_OnCommand(editing_toolbar, 0)
    end
    SetProjExtState(0, "ReaClassical", "toolbaropened", "y")
end

function main()
    PreventUIRefresh(1)
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
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    local sdmousehover = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[8] then sdmousehover = tonumber(table[8]) or 0 end
    end

    local selected_track = GetSelectedTrack(0, 0)

    local cur_pos
    if sdmousehover == 1 then
        cur_pos = BR_PositionAtMouseCursor(false)
    else
        cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    end

    if cur_pos ~= -1 then
        local existing_in_pos
        if is_accessible then
            local proj = EnumProjects(-1)
            existing_in_pos = proj and find_marker_pos(proj, 996, "DEST-IN")
        end

        if existing_in_pos and cur_pos <= existing_in_pos then
            say("Destination out must be after destination in.")
        else
            Undo_BeginBlock()
            local i = 0
            while true do
                local project, _ = EnumProjects(i)
                if project == nil then
                    break
                else
                    DeleteProjectMarker(project, 997, false)
                end
                i = i + 1
            end

            local track_prefix = "D"
            local track_number = 1
            local other_dest_track_num = other_dest_marker_check()

            if selected_track then SetOnlyTrackSelected(selected_track) end

            local colors = get_color_table()

            local marker_color = (workflow == "Horizontal") and colors.dest_marker or colors.dest_items
            local marker_label = (workflow == "Horizontal") and "DEST-OUT" or (track_prefix .. ":DEST-OUT")
            AddProjectMarker2(0, false, cur_pos, 0, marker_label, 997, marker_color)
            SetProjExtState(0, "ReaClassical", "DestOutTrackNum", tostring(track_number))
            Undo_EndBlock("Add Destination Out Marker", -1)
            local folder_phrase = humanize_folder_phrase(track_prefix)
            say("Added destination out @ " .. humanize_timestr(format_timestr_pos(cur_pos, "", -1))
                .. (folder_phrase ~= "" and (" in " .. folder_phrase) or ""))

            if other_dest_track_num and other_dest_track_num ~= track_number then
                MB("Warning: Dest OUT marker group does not match Dest IN!", "Add Dest Marker OUT", 0)
            end
        end
    end
    PreventUIRefresh(-1)
end

function get_color_table()
    return require("ReaClassical_Colors_Table")
end

function other_dest_marker_check()
    local _, stored = GetProjExtState(0, "ReaClassical", "DestInTrackNum")
    if stored ~= "" then
        return tonumber(stored)
    end
    return nil
end

function find_marker_pos(proj, marker_id, marker_type)
    local num_markers = GetNumRegionsOrMarkers(proj)

    for i = 0, num_markers - 1 do
        local _, isrgn, pos, _, raw_label, markrgnindexnumber = enum_project_markers(proj, i)
        if not isrgn and markrgnindexnumber == marker_id then
            local label = raw_label:match(":(.+)$") or raw_label
            if label == marker_type then
                return pos
            end
        end
    end

    return nil
end

main()
