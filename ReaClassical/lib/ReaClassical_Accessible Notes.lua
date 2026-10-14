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
local parent_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say       = require("ReaClassical_Announce")
local gui_mode = require("ReaClassical_GuiMode")
local rank_info = require("ReaClassical_Rank_Info")
local ui_input  = require("ReaClassical_Accessible_Input")

set_action_options(3)

local WINDOW_TITLE = "Notes"

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

local STATE_LIST = "list"

local state      = STATE_LIST
local list_pos   = 1
local last_char  = 0
local fields     = {}

local cur_item  = nil
local cur_track = nil

local function derive_take_number(item)
    local take = GetActiveTake(item)
    if not take then return "" end
    local src = GetMediaItemTake_Source(take)
    local filename = GetMediaSourceFileName(src, "")
    local take_num = tonumber(
        filename:match("(%d+)%)?%s*%[chan%s*%d+%]%.[^%.]+$")
        or filename:match("(%d+)%)?%.[^%.]+$")
    )
    return take_num and tostring(take_num) or ""
end

local function build_fields(item, track)
    local list = {}
    local take = item and GetActiveTake(item) or nil

    if item then
        if take then
            list[#list + 1] = {
                label = "Item Name",
                get = function()
                    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    return rank_info.strip_rank_prefix(name or "")
                end,
                set = function(v)
                    local _, _, rank = rank_info.get_current_rank(item)
                    local final_name = v
                    if rank.prefix ~= "" then
                        final_name = v ~= "" and (v .. "-" .. rank.prefix) or rank.prefix
                    end
                    GetSetMediaItemTakeInfo_String(take, "P_NAME", final_name, true)
                    UpdateArrange()
                end,
            }
        end

        list[#list + 1] = {
            label = "Item Note",
            get = function()
                local _, v = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
                return (v or ""):gsub("[\r\n]+", " ")
            end,
            set = function(v)
                GetSetMediaItemInfo_String(item, "P_NOTES", v, true)
                UpdateArrange()
            end,
        }

        list[#list + 1] = {
            label = "Take Number",
            get = function()
                local _, stored = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
                return stored ~= "" and stored or derive_take_number(item)
            end,
            set = function(v) GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", v, true) end,
        }
    end

    if track then
        list[#list + 1] = {
            label = "Track Note",
            get = function()
                local _, v = GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", "", false)
                return (v or ""):gsub("[\r\n]+", " ")
            end,
            set = function(v) GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", v, true) end,
        }
    end

    list[#list + 1] = {
        label = "Project Note",
        get = function()
            return (GetSetProjectNotes(0, false, "") or ""):gsub("[\r\n]+", " ")
        end,
        set = function(v) GetSetProjectNotes(0, true, v) end,
    }

    return list
end

local function current_field() return fields[list_pos] end

local function announce_field(pos)
    local f = fields[pos]
    local v = f.get()
    say(f.label .. ": " .. (v ~= "" and v or "empty"))
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    local f = current_field()
    local v = f.get()
    gfx.drawstr("[" .. f.label .. "]  " .. (v ~= "" and v or "(empty)"))
    gfx.update()
end

local function save_field(f, new_val)
    new_val = new_val:match("^%s*(.-)%s*$")
    Undo_BeginBlock()
    f.set(new_val)
    Undo_EndBlock("Set " .. f.label, -1)
    say(f.label .. " saved" .. (new_val ~= "" and (": " .. new_val) or " (empty)"))
end

local function handle_key(char)
    if state == STATE_LIST then
        if char == KEY_UP then
            list_pos = list_pos > 1 and list_pos - 1 or #fields
            announce_field(list_pos)
        elseif char == KEY_DOWN then
            list_pos = list_pos < #fields and list_pos + 1 or 1
            announce_field(list_pos)
        elseif char == KEY_ENTER then
            local f = current_field()
            local ok, entered = ui_input.ask(WINDOW_TITLE, f.label, f.label, f.get())
            if ok then
                save_field(f, entered)
            else
                say("Cancelled")
            end
        elseif char == KEY_BACK then
            local f = current_field()
            if f.get() ~= "" then
                Undo_BeginBlock()
                f.set("")
                Undo_EndBlock("Clear " .. f.label, -1)
                say(f.label .. " cleared")
            end
        elseif char == KEY_LEFT or char == KEY_Q then
            dofile(parent_path .. "ReaClassical_Previous Item or Fade.lua")
        elseif char == KEY_RIGHT or char == KEY_W then
            dofile(parent_path .. "ReaClassical_Next Item or Fade.lua")
        elseif char == KEY_SPACE then
            if GetPlayState() & 1 == 1 then
                SetProjExtState(0, "ReaClassical", "PreviousStopPosition", tostring(GetPlayPosition()))
            end
            Main_OnCommand(40044, 0)
        elseif char == KEY_ESC then
            say("Closed")
            return false
        end
    end
    return true
end

local function sync_to_selection()
    local item = GetSelectedMediaItem(0, 0)
    local track = GetSelectedTrack(0, 0)
    if item == cur_item and track == cur_track then return false end

    local prev_label = fields[list_pos] and fields[list_pos].label

    cur_item, cur_track = item, track
    fields = build_fields(cur_item, cur_track)

    list_pos = 1
    if prev_label then
        for i, f in ipairs(fields) do
            if f.label == prev_label then
                list_pos = i
                break
            end
        end
    end

    announce_field(list_pos)
    return true
end

local function main()
    if not gui_mode.accessible() then
        gfx.quit()
        gui_mode.switch_window("ReaClassical_Notes.lua")
        return
    end

    sync_to_selection()

    local char = gfx.getchar()
    if char ~= last_char and gui_mode.gfx_shortcut(char) then
        last_char = char
        gui_mode.toggle_and_announce()
        defer(main)
        return
    end
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

cur_item  = GetSelectedMediaItem(0, 0)
cur_track = GetSelectedTrack(0, 0)
fields = build_fields(cur_item, cur_track)

local first_value = fields[1].get()

gfx.init(WINDOW_TITLE, 500, 44, 0)
say(string.format(
    "%s: %s. Up or down to move, space to play or stop, Enter to edit, Backspace to clear, Escape to close.",
    fields[1].label, first_value ~= "" and first_value or "empty"))

defer(main)
