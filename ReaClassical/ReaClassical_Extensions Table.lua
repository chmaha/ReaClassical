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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end


---------------------------------------------------------------------

return {
    paste = NamedCommandLookup("_SWS_AWPASTE"),
    collapse = NamedCommandLookup("_SWS_COLLAPSE"),
    delete_all_items = NamedCommandLookup("_SWS_DELALLITEMS"),
    folder_small = NamedCommandLookup("_SWS_FOLDSMALL"),
    cursor_at_50 = NamedCommandLookup("_SWS_HSCROLL50"),
    maker_folder = NamedCommandLookup("_SWS_MAKEFOLDER"),
    nudge_right = NamedCommandLookup("_SWS_NUDGESAMPLERIGHT"),
    restore_view = NamedCommandLookup("_SWS_RESTOREVIEW"),
    save_view = NamedCommandLookup("_SWS_SAVEVIEW"),
    select_first_track = NamedCommandLookup("_SWS_SEL1"),
    select_all_parents = NamedCommandLookup("_SWS_SELALLPARENTS"),
    select_children = NamedCommandLookup("_SWS_SELCHILDREN2"),
    select_next_folder = NamedCommandLookup("_SWS_SELNEXTFOLDER"),
    select_next_item = NamedCommandLookup("_SWS_SELNEXTITEM"),
    select_next_item_keep_sel = NamedCommandLookup("_SWS_SELNEXTITEM2"),
    select_prev_item = NamedCommandLookup("_SWS_SELPREVITEM"),
    unselect_children = NamedCommandLookup("_SWS_UNSELCHILDREN"),
    unselect_tracks = NamedCommandLookup("_SWS_UNSELONTRACKS"),
    v_zoom_fit = NamedCommandLookup("_SWS_VZOOMFIT"),
    h_zoom_fit = NamedCommandLookup("_SWS_ZOOMSIT"),
    delete_all_regions = NamedCommandLookup("_SWSMARKERLIST10"),
    delete_all_markers = NamedCommandLookup("_SWSMARKERLIST9"),
    arm_active_env = NamedCommandLookup("_S&M_ARMALLENVS"),
    remove_track_grouping = NamedCommandLookup("_S&M_REMOVE_TR_GRP"),
    select_under_edit_cur = NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"),
    set_rec_armed = NamedCommandLookup("_XENAKIOS_SELTRAX_RECARMED"),
    set_rec_unarmed = NamedCommandLookup("_XENAKIOS_SELTRAX_RECUNARMED"),
    adaptive_delete = NamedCommandLookup("_XENAKIOS_TSADEL"),
    scroll_to_home = NamedCommandLookup("_XENAKIOS_TVPAGEHOME")
}

---------------------------------------------------------------------
