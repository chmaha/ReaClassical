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

set_action_options(1)

local _, _, section_id, cmd_id = get_action_context()

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local rank_info = require("ReaClassical_Rank_Info")
local iu = require("ReaClassical_Item_Utils")
local ieu = require("ReaClassical_IEM_Utils")

if not (APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed) then
    MB("Accessible Item Edit Mode requires ReaClassical Clara (an accessibility bridge) to be installed.",
        "ReaClassical Error", 0)
    return
end

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

local function status_text(ctx)
    if ctx.selection == "none" then
        return iu.item_label(ctx.item, rank_info) .. ", no free fade edge, gain only"
    end
    return iu.item_label(ctx.item, rank_info) .. " fade-" .. ctx.selection .. " selected"
end

local ctx = ieu.sync_context(iu)
if not ctx then
    say("No items selected")
    return
end

Main_OnCommand(24800, 0)
Main_OnCommand(24804, 0)
SetExtState("ReaClassical", "IEMMode", "1", false)

say("Item edit mode on: " .. status_text(ctx))

local last_raw_sel = GetSelectedMediaItem(0, 0)

local function main()
    SetToggleCommandState(section_id, cmd_id, 1)

    local raw_sel = GetSelectedMediaItem(0, 0)
    if raw_sel ~= last_raw_sel then
        last_raw_sel = raw_sel
        local live = ieu.sync_context(iu)
        if live and live.changed then
            say(status_text(live))
        end
    end

    defer(main)
end

local function at_exit()
    Main_OnCommand(24800, 0)
    SetExtState("ReaClassical", "IEMMode",      "", false)
    SetExtState("ReaClassical", "IEMSelection", "", false)
    SetExtState("ReaClassical", "IEMItemGuid",  "", false)
    SetToggleCommandState(section_id, cmd_id, 0)
    say("Item edit mode off")
end

atexit(at_exit)
defer(main)
