--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022 chmaha

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

local r = reaper
r.PreventUIRefresh(1)
r.Undo_BeginBlock()

function Main()
    local fade_editor_toggle = r.NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
    local state = r.GetToggleCommandState(fade_editor_toggle)
    local select_items = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    r.Main_OnCommand(select_items, 0) -- Xenakios/SWS: Select items under edit cursor on selected tracks
    r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
    local fade_left = r.NamedCommandLookup("_SWS_MOVECURFADELEFT")
    r.Main_OnCommand(fade_left, 0) -- SWS: Move cursor left by default fade length
    r.Main_OnCommand(40625, 0) -- Time selection: Set start point
    local fade_right = r.NamedCommandLookup("_SWS_MOVECURFADERIGHT")
    r.Main_OnCommand(fade_right, 0) -- SWS: Move cursor right by default fade length
    r.Main_OnCommand(40626, 0) -- Time selection: Set end point
    r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection
    r.Main_OnCommand(40635, 0) -- Time selection: Remove time selection

    local selected_items = r.CountSelectedMediaItems(0)
    if selected_items > 0 and (state == -1 or state == 0) then
        local item = r.GetSelectedMediaItem(0, 0)
        r.Main_OnCommand(40769, 0) -- Unselect (clear selection of) all tracks/items/envelope points
        r.SetMediaItemSelected(item, 1)
    end

    r.Undo_EndBlock('Classical Crossfade', 0)
    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.UpdateTimeline()
end

Main()
