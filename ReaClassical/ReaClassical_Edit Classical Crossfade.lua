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
local fade_editor_toggle = r.NamedCommandLookup("_RScc8cfd9f58e03fed9f8f467b7dae42089b826067")
local fade_editor_state = r.GetToggleCommandState(fade_editor_toggle)

r.PreventUIRefresh(1)
r.Undo_BeginBlock()

local item = r.GetSelectedMediaItem(0,0)
if fade_editor_state == 1 and item ~= nil then
    r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    r.Main_OnCommand(41174, 0) -- Item navigation: Move cursor to end of items
    r.Main_OnCommand(40839, 0) -- Move edit cursor forward one measure (no seek)
    r.Main_OnCommand(40839, 0) -- Move edit cursor forward one measure (no seek)
    local trim_right = r.NamedCommandLookup("_XENAKIOS_TRIM_RIGHTEDGETO_EDCURSOR")
    r.Main_OnCommand(trim_right, 0) -- XENAKIOS_TRIM_RIGHTEDGETO_EDCURSOR
    r.Main_OnCommand(40841, 0) -- Move edit cursor forward one beat (no seek)
    local select_under = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    r.Main_OnCommand(select_under, 0) -- XENAKIOS_SELITEMSUNDEDCURSELTX
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    r.Main_OnCommand(41173, 0) -- Item navigation: Move cursor to start of items
    r.Main_OnCommand(40840, 0) -- Move edit cursor back one measure (no seek)
    r.Main_OnCommand(40840, 0) -- Move edit cursor back one measure (no seek)
    local trim_left = r.NamedCommandLookup("_XENAKIOS_TRIM_LEFTEDGETO_EDCURSOR")
    r.Main_OnCommand(trim_left, 0) -- XENAKIOS_TRIM_LEFTEDGETO_EDCURSOR
    r.Main_OnCommand(40839, 0) -- Move edit cursor forward one measure (no seek)
    r.Main_OnCommand(40839, 0) -- Move edit cursor forward one measure (no seek)
    r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
    -- local go_home = r.NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
    -- r.Main_OnCommand(go_home, 0) -- XENAKIOS_TVPAGEHOME
    local center_scroll = r.NamedCommandLookup("_SWS_HSCROLL50") -- SWS: Horizontal scroll to put edit cursor at 50%
    r.Main_OnCommand(center_scroll, 0)
else
    r.ShowMessageBox('This ReaClassical script only works while in the fade editor (F)', "Edit Classical Crossfade", 0)
end

r.Undo_EndBlock('Edit Classical Crossfade', 0)
r.PreventUIRefresh(-1)
r.UpdateArrange()
r.UpdateTimeline()
