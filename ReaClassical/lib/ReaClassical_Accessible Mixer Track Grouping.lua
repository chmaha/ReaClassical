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
local say      = require("ReaClassical_Announce")
local mm       = require("ReaClassical_MM_Utils")
local mmg      = require("ReaClassical_MM_Groups")
local help     = require("ReaClassical_Accessible_Help")
local ui_input = require("ReaClassical_Accessible_Input")

set_action_options(3)

local WINDOW_TITLE = "Accessible Mixer Track Grouping"

local STATE_GROUPS = "groups"
local STATE_MENU   = "menu"
local STATE_MEMBERS = "members"
local STATE_CONFIRM_DELETE_ALL = "confirm_delete_all"

local GROUPS_VIRTUAL_ROWS = 3

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local state      = STATE_GROUPS
local group_idx  = 1
local menu_idx   = 1
local member_idx = 1
local last_char  = 0

local groups     = {}
local cur_slot   = nil
local cur_group  = nil

local function aspect_enabled(key)
    return cur_group ~= nil and cur_group.aspects[key] ~= false
end

local menu_rows = {}

local function aspect_name(key)
    return key:sub(1, 1):upper() .. key:sub(2)
end

local function build_menu_rows()
    menu_rows = {
        { id = "rename",  label = "Rename" },
        { id = "enabled", label = "Group " .. (cur_group and not cur_group.disabled and "enabled" or "disabled") },
        { id = "members", label = "Members" },
        { id = "remove",  label = "Remove Group" },
    }
    for _, aspect in ipairs(mmg.ASPECTS) do
        menu_rows[#menu_rows + 1] = {
            id = "aspect:" .. aspect.key,
            label = aspect_name(aspect.key) .. " " .. (aspect_enabled(aspect.key) and "enabled" or "disabled"),
            aspect_key = aspect.key,
        }
    end
end

local function announce_menu_row(i)
    local row = menu_rows[i]
    if not row then return end
    local msg = row.label
    if row.id == "members" then msg = msg .. " (Enter to view)" end
    if row.id == "remove" then msg = msg .. ". Enter to remove" end
    if row.id == "enabled" or row.aspect_key then msg = msg .. ". Enter to toggle" end
    say(msg)
end

local member_tracks = {}

local function rebuild_member_tracks()
    member_tracks = mm.get_special_tracks_list()
end

local function track_in_group(track)
    if not cur_group then return false end
    local owner = mmg.find_group_for_track(track)
    return owner ~= nil and owner.native == cur_group.native
end

local function announce_member(i)
    local t = member_tracks[i]
    local mark = track_in_group(t) and " (in group)" or ""
    say(mm.get_label(t) .. mark)
end

local function sorted_groups()
    local snapshot = mmg.load_groups()
    table.sort(snapshot, function(a, b) return a.native < b.native end)
    return snapshot
end

local function group_label(g)
    if not g then return "" end
    local members = "no tracks yet"
    for _, d in ipairs(mmg.describe_groups()) do
        if d.native == g.native then
            if #d.labels > 0 then members = table.concat(d.labels, ", ") end
            break
        end
    end
    return string.format("'%s': %s%s", g.name, members, g.disabled and " (disabled)" or "")
end

local function refresh_group()
    groups = sorted_groups()
    cur_group = mmg.group_for_slot(cur_slot, groups)
    return cur_group ~= nil
end

local function prompt_new_group()
    local slot = mmg.first_free_slot(groups)
    if not slot then
        say("No free group slots")
        return nil
    end
    local ok, entered = ui_input.ask(WINDOW_TITLE, "New Group",
        "Group name", "Group " .. slot)
    if not ok then
        say("Cancelled")
        return nil
    end
    local name = entered ~= "" and entered or ("Group " .. slot)
    mmg.rename_slot(slot, name)
    groups = sorted_groups()
    for _, g in ipairs(groups) do
        if g.native == slot then return g end
    end
    return nil
end

local function prompt_rename()
    local ok, entered = ui_input.ask(WINDOW_TITLE, "Rename Group",
        "Group name", cur_group.name)
    if not ok then
        say("Cancelled")
        return
    end
    if entered ~= "" then
        mmg.rename_slot(cur_slot, entered)
        refresh_group()
    end
    say(group_label(cur_group))
end

local function announce_groups_entry(i)
    local count = #groups
    if i <= count then
        say(group_label(groups[i]))
    elseif i == count + 1 then
        say("New group. Enter to create")
    elseif i == count + 2 then
        say((mmg.is_globally_disabled() and "Enable" or "Disable") .. " all groups. Enter to toggle")
    else
        say("Delete all groups. Enter to confirm")
    end
end

local function announce_group_menu(with_hint)
    build_menu_rows()
    local row = menu_rows[menu_idx]
    local hint = with_hint
        and ". Up or down for options, Enter to select, Escape for groups"
        or ""
    say(row.label .. hint)
end

local function handle_key(char)
    if state == STATE_GROUPS then
        local last_idx = #groups + GROUPS_VIRTUAL_ROWS
        if char == KEY_UP then
            group_idx = group_idx > 1 and group_idx - 1 or last_idx
            announce_groups_entry(group_idx)
        elseif char == KEY_DOWN then
            group_idx = group_idx < last_idx and group_idx + 1 or 1
            announce_groups_entry(group_idx)
        elseif char == KEY_ENTER then
            if group_idx <= #groups then
                local g = groups[group_idx]
                cur_slot = g.native
                refresh_group()
                state = STATE_MENU
                menu_idx = 1
                announce_group_menu(true)
            elseif group_idx == #groups + 1 then
                local g = prompt_new_group()
                if g then
                    cur_slot = g.native
                    refresh_group()
                    state = STATE_MEMBERS
                    member_idx = 1
                    rebuild_member_tracks()
                    say("Add tracks: up or down to browse, Enter to add or remove, Escape for options.")
                    announce_member(member_idx)
                end
            elseif group_idx == #groups + 2 then
                local now_disabled = mmg.toggle_global_disabled()
                say(now_disabled and "All groups disabled" or "All groups enabled")
            else
                state = STATE_CONFIRM_DELETE_ALL
                say("Delete all groups? This cannot be undone. Enter to confirm, Escape to cancel.")
            end
        elseif char == 104 or char == 72 then
            help.enter({
                { key = "Up/Down", desc = "Browse groups, New group, and the two global actions" },
                { key = "Enter", desc = "Open options / create / toggle all groups / delete all groups" },
                { key = "Escape", desc = "Save nothing (changes apply immediately) and close" },
            }, function() announce_groups_entry(group_idx) end)
        elseif char == KEY_ESC then
            say("Closed")
            return false
        end
    elseif state == STATE_MENU then
        if not refresh_group() then
            state = STATE_GROUPS
            group_idx = 1
            say("Group removed. On: " .. (#groups > 0 and group_label(groups[1]) or "no groups"))
        elseif char == KEY_UP then
            menu_idx = menu_idx > 1 and menu_idx - 1 or #menu_rows
            announce_menu_row(menu_idx)
        elseif char == KEY_DOWN then
            menu_idx = menu_idx < #menu_rows and menu_idx + 1 or 1
            announce_menu_row(menu_idx)
        elseif char == KEY_ENTER then
            local row = menu_rows[menu_idx]
            if row.id == "rename" then
                prompt_rename()
            elseif row.id == "enabled" then
                mmg.toggle_slot_disabled(cur_slot)
                refresh_group()
                build_menu_rows()
                announce_menu_row(menu_idx)
            elseif row.id == "members" then
                state = STATE_MEMBERS
                member_idx = 1
                rebuild_member_tracks()
                if #member_tracks == 0 then
                    say("No mixer/special tracks found")
                    state = STATE_MENU
                else
                    say("Up or down to browse tracks, Enter to add or remove, Escape for options.")
                    announce_member(member_idx)
                end
            elseif row.id == "remove" then
                local removed_label = group_label(cur_group)
                mmg.clear_slot(cur_slot)
                groups = sorted_groups()
                cur_group = nil
                state = STATE_GROUPS
                group_idx = 1
                say("Removed: " .. removed_label .. ". On: " .. (#groups > 0 and group_label(groups[1]) or "no groups"))
            elseif row.aspect_key then
                local enabled = not aspect_enabled(row.aspect_key)
                mmg.set_group_aspect(cur_slot, row.aspect_key, enabled)
                refresh_group()
                build_menu_rows()
                announce_menu_row(menu_idx)
            end
        elseif char == 104 or char == 72 then
            help.enter({
                { key = "Up/Down", desc = "Browse options and aspect switches" },
                { key = "Enter", desc = "Rename / toggle Enabled / open Members / Remove Group / toggle an aspect" },
                { key = "Escape", desc = "Back to groups" },
            }, function() announce_menu_row(menu_idx) end)
        elseif char == KEY_ESC then
            state = STATE_GROUPS
            group_idx = math.min(group_idx, #groups)
            say(group_label(cur_group))
        end
    elseif state == STATE_MEMBERS then
        if char == KEY_UP then
            member_idx = member_idx > 1 and member_idx - 1 or #member_tracks
            announce_member(member_idx)
        elseif char == KEY_DOWN then
            member_idx = member_idx < #member_tracks and member_idx + 1 or 1
            announce_member(member_idx)
        elseif char == KEY_ENTER then
            local t = member_tracks[member_idx]
            local was_in = track_in_group(t)
            local target_slot = nil
            if not was_in then target_slot = cur_slot end
            mmg.set_track_native_slot(t, target_slot)
            refresh_group()
            say((was_in and "Removed from group: " or "Added to group: ") .. mm.get_label(t))
        elseif char == 104 or char == 72 then
            help.enter({
                { key = "Up/Down", desc = "Browse mixer/special tracks" },
                { key = "Enter", desc = "Add to or remove from this group" },
                { key = "Escape", desc = "Back to the group's options" },
            }, function() announce_member(member_idx) end)
        elseif char == KEY_ESC then
            state = STATE_MENU
            menu_idx = 1
            build_menu_rows()
            say("Options")
            announce_menu_row(menu_idx)
        end
    elseif state == STATE_CONFIRM_DELETE_ALL then
        if char == KEY_ENTER then
            mmg.remove_all_groups()
            groups = sorted_groups()
            state = STATE_GROUPS
            group_idx = 1
            say("All groups deleted.")
        elseif char == KEY_ESC then
            state = STATE_GROUPS
            say("Cancelled")
            announce_groups_entry(group_idx)
        end
    end

    return true
end

local function status_line()
    if state == STATE_GROUPS then
        local what
        if group_idx <= #groups then
            what = group_label(groups[group_idx])
        elseif group_idx == #groups + 1 then
            what = "New group"
        elseif group_idx == #groups + 2 then
            what = mmg.is_globally_disabled() and "Enable all groups" or "Disable all groups"
        else
            what = "Delete all groups"
        end
        return "[Groups]  " .. what
    elseif state == STATE_MENU then
        local row = menu_rows[menu_idx]
        return "[Options]  " .. (row and row.label or "")
    elseif state == STATE_MEMBERS then
        local t = member_tracks[member_idx]
        return "[Members]  " .. (t and mm.get_label(t) or "")
    elseif state == STATE_CONFIRM_DELETE_ALL then
        return "[Confirm]  Delete all groups?"
    end
    return ""
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    gfx.drawstr(status_line())
    gfx.update()
end

local function main()
    local char = gfx.getchar()
    if char == -1 then gfx.quit() return end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        local consumed = help.is_active() and help.handle_key(char)
        if not consumed then
            if not handle_key(char) then
                gfx.quit()
                return
            end
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

groups = sorted_groups()

gfx.init(WINDOW_TITLE, 500, 44, 0)
if #groups == 0 then
    say("Mixer Track Grouping. No groups yet. Enter creates one.")
else
    say("Mixer Track Grouping. " .. #groups .. " group"
        .. (#groups == 1 and "" or "s") .. ". Up or down to browse, Enter for options, "
        .. "H for shortcuts, Escape to close. On: " .. group_label(groups[1]))
end

defer(main)
