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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say       = require("ReaClassical_Announce")
local rank_info = require("ReaClassical_Rank_Info")
local iu        = require("ReaClassical_Item_Utils")
local ui_input  = require("ReaClassical_Accessible_Input")

if not (APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed) then
    local _, debug_str = GetProjExtState(0, "ReaClassical", "DebugAnnounce")
    if debug_str ~= "on" then
        MB("Accessible Item Name requires ReaClassical Clara (an accessibility bridge) to be installed.",
            "ReaClassical Error", 0)
        return
    end
end

local WINDOW_TITLE = "Item Name"

local function commit(item, take, new_base)
    local _, _, rank = rank_info.get_current_rank(item)
    local final_name = new_base
    if rank.prefix ~= "" then
        final_name = new_base ~= "" and (new_base .. "-" .. rank.prefix) or rank.prefix
    end

    Undo_BeginBlock()
    GetSetMediaItemTakeInfo_String(take, "P_NAME", final_name, true)
    Undo_EndBlock("Rename Item", -1)
    UpdateArrange()

    local spoken = iu.humanize_item_name(new_base)
    say("Renamed: " .. (spoken ~= "" and spoken or "no name") .. rank_info.rank_announce_suffix(item))
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

local sel_count = CountSelectedMediaItems(0)
if sel_count == 0 then
    say("No item selected")
    return
end

local item = nil
local parent_count = 0
for i = 0, sel_count - 1 do
    local sel_item = GetSelectedMediaItem(0, i)
    local sel_track = GetMediaItem_Track(sel_item)
    if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") == 1 then
        parent_count = parent_count + 1
        item = sel_item
    end
end

if parent_count == 0 then
    say("Please select an item on the parent (folder) track")
    return
elseif parent_count > 1 then
    say("Please select only one item on the parent track")
    return
end

local take = GetActiveTake(item)
if not take then
    say("Selected item has no active take")
    return
end

local _, current_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
local base_name = rank_info.strip_rank_prefix(current_name)

local ok, entered = ui_input.ask(WINDOW_TITLE, "Item Name", "Item name", base_name)
if not ok then
    say("Cancelled")
    return
end

local new_base = entered:match("^%s*(.-)%s*$")
if new_base == base_name then
    say("Kept")
    return
end

commit(item, take, new_base)
