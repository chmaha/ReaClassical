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
local say = require("ReaClassical_Announce")
local snap_info = require("ReaClassical_Mixer_Snapshot_Info")
local item_utils = require("ReaClassical_Item_Utils")

local item = GetSelectedMediaItem(0, 0)
if not item then
    say("No item selected")
    return
end

local first_folder = snap_info.get_first_folder_track()
if not first_folder or GetMediaItem_Track(item) ~= first_folder then
    say("Snapshots can only be set on items on the first folder track")
    return
end

local item_guid = BR_GetMediaItemGUID(item)
local take = GetActiveTake(item)
local item_name = ""
if take then
    _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
end

local bank = snap_info.get_current_bank()
local created, snapshot = snap_info.capture_snapshot_for_item(item_guid, item_name, bank)
local display = snapshot.item_name ~= "" and item_utils.humanize_item_name(snapshot.item_name) or item_guid:sub(1, 13)
local msg = created and ("Snapshot created: " .. display) or ("Snapshot updated: " .. display)

local _, flags = snap_info.load_bank(bank)
if not flags.disable_auto_recall then
    local daemon_path = script_path .. "lib/ReaClassical_Mixer Snapshots Daemon.lua"
    if snap_info.ensure_daemon_running(daemon_path) then
        msg = msg .. ". Snapshot daemon started"
    end
end
say(msg)
