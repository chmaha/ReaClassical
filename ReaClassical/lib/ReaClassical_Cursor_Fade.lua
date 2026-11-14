--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Original idea by Matt Wadsworth.

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
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local rank_info = require("ReaClassical_Rank_Info")
local iu = require("ReaClassical_Item_Utils")
local sdcu = require("ReaClassical_SD_Crossfade_Utils")
local ui_input = require("ReaClassical_Accessible_Input")
local humanize_timestr = require("ReaClassical_Time_Naming")

local M = {}

local EPSILON = 0.0005

local function seconds_text(s)
    local txt = string.format("%.2f", s):gsub("0+$", ""):gsub("%.$", "")
    return txt .. (txt == "1" and " second" or " seconds")
end

local function workflow_ok()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow ~= "" then return true end
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return false
end

local function cursor_inside(item, cursor)
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
    return cursor > pos + EPSILON and cursor < item_end - EPSILON
end

local function ask_length(title, default)
    local value = tostring(default)
    while true do
        local ok, entered = ui_input.ask(nil, title, "Fade length in seconds", value)
        if not ok then
            say("Cancelled")
            return nil
        end
        local n = tonumber(entered)
        if n and n > 0 then return n end
        say("Please enter a length in seconds greater than zero. Correct it or Cancel")
        value = entered
    end
end

local function apply(item, is_out, cursor, length)
    if not cursor_inside(item, cursor) then return nil end
    local pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")

    local fade
    if is_out then
        local new_end = math.min(item_end, cursor + length)
        sdcu.set_item_edge(item, true, new_end)
        fade = new_end - cursor
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade)
        SetMediaItemInfo_Value(item, "D_FADEOUTLEN_AUTO", fade)
    else
        local new_start = math.max(pos, cursor - length)
        sdcu.set_item_edge(item, false, new_start)
        fade = cursor - new_start
        SetMediaItemInfo_Value(item, "D_FADEINLEN", fade)
        SetMediaItemInfo_Value(item, "D_FADEINLEN_AUTO", fade)
    end
    return fade
end

function M.run(is_out, default_length)
    if not workflow_ok() then return end

    local item = GetSelectedMediaItem(0, 0)
    if not item then say("No item selected"); return end

    local crossfaded
    if is_out then
        crossfaded = iu.right_edge_crossfaded(item)
    else
        crossfaded = iu.left_edge_crossfaded(item)
    end
    if crossfaded then
        say((is_out and "Right" or "Left") .. " edge is crossfaded; use the crossfade editor instead")
        return
    end

    local cursor = GetCursorPosition()
    if not cursor_inside(item, cursor) then
        say("Edit cursor is not inside the selected item")
        return
    end

    local title = is_out and "Fade Out From Cursor" or "Fade In To Cursor"
    local length = ask_length(title, default_length)
    if not length then return end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    local shortest
    for _, peer in ipairs(iu.get_item_peers(item)) do
        local fade = apply(peer, is_out, cursor, length)
        if fade and (not shortest or fade < shortest) then shortest = fade end
    end

    UpdateArrange()
    UpdateTimeline()
    PreventUIRefresh(-1)
    Undo_EndBlock(title, -1)

    if not shortest then
        say("Edit cursor is not inside the selected item")
        return
    end

    local where = humanize_timestr(format_timestr_pos(cursor, "", -1))
    if where == "At beginning of project" then where = "the start of the project" end
    local msg = iu.item_label(item, rank_info) .. " "
    if is_out then
        msg = msg .. "fade out, " .. seconds_text(shortest) .. ", starting at " .. where
    else
        msg = msg .. "fade in, " .. seconds_text(shortest) .. ", reaching full level at " .. where
    end
    if shortest < length - EPSILON then
        msg = msg .. ". Only " .. seconds_text(shortest) .. " of audio "
            .. (is_out and "after" or "before") .. " the cursor, so the fade is shorter than requested"
    end
    say(msg)
end

return M
