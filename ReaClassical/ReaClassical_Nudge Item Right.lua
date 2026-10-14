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
local xfu = require("ReaClassical_XFM_Utils")
local rank_info = require("ReaClassical_Rank_Info")
local nudge_utils = require("ReaClassical_Nudge_Utils")

local main, humanize_item_name

function humanize_item_name(name)
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        return prefix .. " take " .. tonumber(take_num)
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        return "Take " .. tonumber(only_num)
    end
    return name
end

function main()
    if xfu.is_xfade_mode() then
        say("Use XFM Nudge Right in crossfade mode")
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

    local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
    local ms = tonumber(stored) or 5
    local amount = ms / 1000

    local moved, first_item = nudge_utils.nudge_items(amount)
    if moved == 0 then
        say("No items selected")
    elseif moved == 1 then
        local name = ""
        local take = GetActiveTake(first_item)
        if take then
            local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            name = take_name
        end
        local rank_suffix = rank_info.rank_announce_suffix(first_item)
        local label = humanize_item_name(rank_info.strip_rank_prefix(name))
        if label == "" then label = "no name" end
        say(label .. " nudged " .. ms .. " milliseconds right" .. rank_suffix)
    else
        say(moved .. " item groups nudged " .. ms .. " milliseconds right")
    end
end

main()
