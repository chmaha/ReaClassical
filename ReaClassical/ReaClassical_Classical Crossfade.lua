--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, return_xfade_length

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local xfade_len = return_xfade_length()
    local fade_editor_toggle = NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
    local state = GetToggleCommandState(fade_editor_toggle)
    local select_items = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    Main_OnCommand(select_items, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
    Main_OnCommand(40297, 0)        -- Track: Unselect (clear selection of) all tracks

    MoveEditCursor(-xfade_len, false)
    Main_OnCommand(40625, 0) -- Time selection: Set start point

    MoveEditCursor(xfade_len, false)
    Main_OnCommand(40626, 0) -- Time selection: Set end point
    Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection
    Main_OnCommand(40635, 0) -- Time selection: Remove time selection

    local selected_items = CountSelectedMediaItems(0)
    if selected_items > 0 and (state == -1 or state == 0) then
        local item = GetSelectedMediaItem(0, 0)
        Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
        SetMediaItemSelected(item, 1)
    end

    Undo_EndBlock('Classical Crossfade', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function return_xfade_length()
    local xfade_len = 0.035
    local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
    if input ~= "" then
        local table = {}
        for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
        if table[1] then xfade_len = table[1] / 1000 end
    end
    return xfade_len
end

---------------------------------------------------------------------

main()
