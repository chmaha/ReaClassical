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
local parent_path = script_path
local say       = require("ReaClassical_Announce")
local rank_info = require("ReaClassical_Rank_Info")

if not (APIExists("clara_outputMessage") or _G.__RC_debug_shim_installed) then
    local _, debug_str = GetProjExtState(0, "ReaClassical", "DebugAnnounce")
    if debug_str ~= "on" then
        MB("Accessible Item Rank requires ReaClassical Clara (an accessibility bridge) to be installed.",
            "ReaClassical Error", 0)
        return
    end
end

set_action_options(3)

local WINDOW_TITLE = "Item Rank"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_LEFT  = 1818584692
local KEY_RIGHT = 1919379572
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_BACK  = 8
local KEY_Q     = 113
local KEY_W     = 119
local KEY_SPACE = 32

local LIST_ORDER = { 9, 1, 2, 3, 4, 5, 6, 7, 8 }
local RANK_TO_POS = {}
for pos, rank_num in ipairs(LIST_ORDER) do RANK_TO_POS[rank_num] = pos end

local item      = nil
local list_pos  = RANK_TO_POS[9]
local base_name = ""
local last_char = 0

local function spoken_rank_name(idx)
    local n = rank_info.RANKS[idx].name
    return n == "No Rank" and "None" or n
end

local function announce_list_pos()
    say(spoken_rank_name(LIST_ORDER[list_pos]))
end

local function humanize_take_name(name)
    if not name or name == "" then return name end
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

local function sync_item()
    local sel_count = CountSelectedMediaItems(0)
    if sel_count == 0 then
        say("No item selected")
        return
    end

    local parent_count = 0
    local new_item = nil
    for i = 0, sel_count - 1 do
        local sel_item = GetSelectedMediaItem(0, i)
        local sel_track = GetMediaItem_Track(sel_item)
        if GetMediaTrackInfo_Value(sel_track, "I_FOLDERDEPTH") == 1 then
            parent_count = parent_count + 1
            new_item = sel_item
        end
    end

    if parent_count == 0 then
        say("Please select an item on the parent track")
        return
    elseif parent_count > 1 then
        say("Please select only one item on the parent track")
        return
    end

    item = new_item
    base_name = ""
    local take = GetActiveTake(item)
    if take then
        local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        base_name = humanize_take_name(rank_info.strip_rank_prefix(name))
    end

    local _, current_idx = rank_info.get_current_rank(item)
    list_pos = RANK_TO_POS[current_idx]

    say(string.format("%s: %s", base_name ~= "" and base_name or "item", spoken_rank_name(LIST_ORDER[list_pos])))
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    gfx.drawstr("[Rank]  " .. rank_info.RANKS[LIST_ORDER[list_pos]].name)
    gfx.update()
end

local function apply_rank(rank_str)
    Undo_BeginBlock()
    local label = rank_info.apply_rank(item, rank_str)
    Undo_EndBlock("Set Item Rank", -1)
    say("Rank set: " .. (label ~= "No Rank" and label or "None"))
end

local function handle_key(char)
    if char == KEY_UP then
        list_pos = list_pos > 1 and list_pos - 1 or #LIST_ORDER
        announce_list_pos()
    elseif char == KEY_DOWN then
        list_pos = list_pos < #LIST_ORDER and list_pos + 1 or 1
        announce_list_pos()
    elseif char == KEY_ENTER then
        local rank_num = LIST_ORDER[list_pos]
        apply_rank((rank_num == 9) and "" or tostring(rank_num))
    elseif char == KEY_BACK then
        apply_rank("")
        list_pos = RANK_TO_POS[9]
    elseif char == KEY_LEFT or char == KEY_Q then
        dofile(parent_path .. "ReaClassical_Previous Item or Fade.lua")
        sync_item()
    elseif char == KEY_RIGHT or char == KEY_W then
        dofile(parent_path .. "ReaClassical_Next Item or Fade.lua")
        sync_item()
    elseif char == KEY_SPACE then
        if GetPlayState() & 1 == 1 then
            SetProjExtState(0, "ReaClassical", "PreviousStopPosition", tostring(GetPlayPosition()))
        end
        Main_OnCommand(40044, 0)
    elseif char == KEY_ESC then
        say("Cancelled")
        return false
    end
    return true
end

local function main()
    local char = gfx.getchar()
    if char == -1 then gfx.quit() return end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        if not handle_key(char) then
            gfx.quit()
            return
        end
    end
    draw_window()
    defer(main)
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
if take then
    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    base_name = humanize_take_name(rank_info.strip_rank_prefix(name))
end

local _, current_idx = rank_info.get_current_rank(item)
list_pos = RANK_TO_POS[current_idx]

gfx.init(WINDOW_TITLE, 500, 44, 0)
say(string.format(
    "Rank for %s: %s. Up or down to move through ranks, left or right or Q or W for previous or next item, "
    .. "space to play or stop, Enter to set, Backspace to clear, Escape to cancel.",
    base_name ~= "" and base_name or "item", spoken_rank_name(LIST_ORDER[list_pos])))

defer(main)
