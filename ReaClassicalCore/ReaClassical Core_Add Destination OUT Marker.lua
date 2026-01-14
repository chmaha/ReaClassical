--[[
@noindex

This file is a part of "ReaClassical Core" package.
See "ReaClassicalCore.lua" for more information.

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

local main, edge_check, return_check_length

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

local dest_marker = ColorToNative(23,203,223) | 0x1000000

function main()
    PreventUIRefresh(1)
    local workflow = "Horizontal"
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
                MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.",
            "ReaClassical Error", 0)
        return
    end
    local _, input = GetProjExtState(0, "ReaClassical Core", "Preferences")
    local sdmousehover = 0
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[3] then sdmousehover = tonumber(table[3]) or 0 end
    end

    local selected_track = GetSelectedTrack(0, 0)

    local cur_pos, track
    if sdmousehover == 1 then
        cur_pos = BR_PositionAtMouseCursor(false)
        local screen_x, screen_y = GetMousePosition()
        track = GetTrackFromPoint(screen_x, screen_y)
    else
        cur_pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    end

    if cur_pos ~= -1 then
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

        if selected_track then SetOnlyTrackSelected(selected_track) end

        local final_track = track or selected_track

        if edge_check(cur_pos, final_track) == true then
            local response = MB(
                "The marker you are trying to add would either be on or close to an item edge or crossfade. Continue?",
                "Add Dest-IN Marker", 4)
            if response ~= 6 then return end
        end

        AddProjectMarker2(0, false, cur_pos, 0, "DEST-OUT", 997, dest_marker)

    end
    PreventUIRefresh(-1)
end

---------------------------------------------------------------------

function edge_check(cur_pos, track)
    local num_of_items = 0
    local check_length = return_check_length()
    if track then num_of_items = CountTrackMediaItems(track) end
    local clash = false
    for i = 0, num_of_items - 1 do
        local item = GetTrackMediaItem(track, i)
        local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_fadein_len = GetMediaItemInfo_Value(item, "D_FADEINLEN")
        local item_fadein_end = item_start + item_fadein_len
        if cur_pos > item_start and cur_pos < item_fadein_end + check_length then
            clash = true
            break
        end
        local item_length = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_start + item_length
        local item_fadeout_len = GetMediaItemInfo_Value(item, "D_FADEOUTLEN")
        local item_fadeout_start = item_end - item_fadeout_len
        if cur_pos > item_fadeout_start - check_length and cur_pos < item_end then
            clash = true
            break
        end
    end

    return clash
end

---------------------------------------------------------------------

function return_check_length()
    local check_length = 0.5
    local _, input = GetProjExtState(0, "ReaClassical Core", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[2] then check_length = table[2] / 1000 end
    end
    return check_length
end

---------------------------------------------------------------------

main()
