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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local notes_track = require("ReaClassical_Notes_Track")

local DEFAULT_LENGTH = 5
local SHOW_ITEM_NOTES_CMD = 40850

local function main()
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

    local play_state = GetPlayState()
    local active = (play_state & 1) == 1 or (play_state & 4) == 4
    local pos = active and GetPlayPosition() or GetCursorPosition()
    local sel_start, sel_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local length = DEFAULT_LENGTH
    if not active and sel_end > sel_start then
        pos, length = sel_start, sel_end - sel_start
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)
    local created = not notes_track.find()
    local track = notes_track.create()
    local item = AddMediaItemToTrack(track)
    SetMediaItemInfo_Value(item, "D_POSITION", pos)
    SetMediaItemInfo_Value(item, "D_LENGTH", length)
    SelectAllMediaItems(0, false)
    SetMediaItemSelected(item, true)
    PreventUIRefresh(-1)
    UpdateArrange()
    TrackList_AdjustWindows(false)
    Undo_EndBlock("Add Note at Cursor", -1)

    say(created and "Notes track created, note added" or "Note added")
    Main_OnCommand(SHOW_ITEM_NOTES_CMD, 0)
end

main()
