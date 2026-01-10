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

local main, folder_check, get_color_table, get_path
local route_to_track, trackname_check, scroll_to_first_track

---------------------------------------------------------------------

function main()
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
    local folders = folder_check()
    if folders == 0 then
        return
    end

    Undo_BeginBlock()

    local rcmaster
    local rcmaster_index
    local num_of_tracks = CountTracks(0)

    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        if trackname_check(track, "^RCMASTER") or rcmaster_state == "y" then
            rcmaster = track
            rcmaster_index = i
            break
        end
    end

    if rcmaster == nil then
        MB("Sorry, can't find RCMASTER", "Error!", 0)
        return
    end

    InsertTrackAtIndex(rcmaster_index, true) -- Add track just before RCMASTER
    local bus = GetTrack(0, rcmaster_index)
    GetSetMediaTrackInfo_String(bus, "P_EXT:aux", "y", true)
    SetMediaTrackInfo_Value(bus, "I_FOLDERDEPTH", 0)

    route_to_track(bus, rcmaster)
    local colors = get_color_table()
    SetTrackColor(bus, colors.aux)
    GetSetMediaTrackInfo_String(bus, "P_NAME", "@", true) -- Add @ as track name
    SetMediaTrackInfo_Value(bus, "B_SHOWINTCP", 0)
    Main_OnCommand(40297, 0)
    scroll_to_first_track()

    if folders > 1 then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    else
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end

    Undo_EndBlock("Add Aux", 0)
end

---------------------------------------------------------------------

function folder_check()
    local folders = 0
    local tracks_per_group = 1
    local total_tracks = CountTracks(0)
    for i = 0, total_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        local special_states = mixer_state == "y" or aux_state == "y" or submix_state == "y"
            or rt_state == "y" or ref_state == "y" or live_state == "y" or rcmaster_state == "y"
        local special_names = trackname_check(track, "^M:") or trackname_check(track, "^RCMASTER")
            or trackname_check(track, "^@") or trackname_check(track, "^#") or trackname_check(track, "^RoomTone")
            or trackname_check(track, "^LIVE") or trackname_check(track, "^REF")

        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 then
            folders = folders + 1
        elseif folders == 1 and not (special_states or special_names) then
            tracks_per_group = tracks_per_group + 1
        end
    end
    return folders, tracks_per_group, total_tracks
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

function route_to_track(track, rcmaster)
    SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
    CreateTrackSend(track, rcmaster)
end

---------------------------------------------------------------------

function trackname_check(track, string)
    local _, trackname = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(trackname, string)
end

---------------------------------------------------------------------

function scroll_to_first_track()
  local track1 = GetTrack(0, 0)
  if not track1 then return end

  -- Save current selected tracks to restore later
  local saved_sel = {}
  local count_sel = CountSelectedTracks(0)
  for i = 0, count_sel - 1 do
    saved_sel[i+1] = GetSelectedTrack(0, i)
  end

  -- Select only Track 1
  Main_OnCommand(40297, 0) -- Unselect all tracks
  SetTrackSelected(track1, true)

  -- Scroll Track 1 into view (vertically)
  Main_OnCommand(40913, 0) -- "Track: Vertical scroll selected tracks into view"

  -- Restore previous selection
  Main_OnCommand(40297, 0) -- Unselect all tracks
  for _, tr in ipairs(saved_sel) do
    SetTrackSelected(tr, true)
  end
end

---------------------------------------------------------------------

main()
