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
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say       = require("ReaClassical_Announce")
local gui_mode = require("ReaClassical_GuiMode")
local snap_info = require("ReaClassical_Mixer_Snapshot_Info")
local item_utils = require("ReaClassical_Item_Utils")
local snap_automation = require("ReaClassical_Snapshot_Automation")
local ui_input  = require("ReaClassical_Accessible_Input")
set_action_options(3)

local WINDOW_TITLE = "Snapshot Settings"

local KEY_UP      = 30064
local KEY_DOWN    = 1685026670
local KEY_ENTER   = 13
local KEY_ESC     = 27
local KEY_NOTES   = 14
local KEY_BACK    = 8
local KEY_CHANGES = 4

local STATE_MAIN         = "main"
local STATE_RECALL       = "recall"
local STATE_BROWSE       = "browse"
local STATE_CONFIRM_CLEAR = "confirm_clear"

local BANKS = { "A", "B", "C", "D" }

local FIELD_LABELS = {
    "Snapshot Bank", "Add or Update Snapshot", "Browse Snapshots",
    "Auto-Recall", "Recall Parameters",
    "Switch Mid-Gap During Playback",
    "Convert to Automation", "Clear Automation", "Clear Bank",
}
local FIELD_KEYS = {
    nil, nil, nil, nil, nil,
    "switch_mid_gap",
    nil, nil, nil,
}
local IDX_BANK, IDX_ADD, IDX_BROWSE, IDX_AR, IDX_RECALL_MENU,
    IDX_SWITCH_MID_GAP, IDX_ADDAUTO, IDX_RMAUTO, IDX_CLEARBANK =
    1, 2, 3, 4, 5, 6, 7, 8, 9

local RECALL_LABELS = {
    "Volume", "Pan", "Mute", "Solo", "Phase", "Width", "FX", "Send Levels", "Send Routing",
}
local RECALL_KEYS = {
    "volume", "pan", "mute", "solo", "phase", "width", "fx", "sends", "routing",
}

local state          = STATE_MAIN
local field_idx       = 1
local last_char        = 0

local recall_idx      = 1

local browse_idx          = 1

local current_bank  = "A"
local current_snaps = {}
local current_flags = {}

local function load_all()
    current_bank = snap_info.get_current_bank()
    current_snaps, current_flags = snap_info.prune_stale_snapshots(current_bank)
end

local function save_flags()
    snap_info.save_bank(current_bank, current_snaps, current_flags)
end

local function value_label(i)
    if i == IDX_BANK then return current_bank end
    if i == IDX_AR then return (not current_flags.disable_auto_recall) and "On" or "Off" end
    if FIELD_KEYS[i] then return current_flags[FIELD_KEYS[i]] and "On" or "Off" end
    return ""
end

local function announce_field(i)
    local val = value_label(i)
    say(FIELD_LABELS[i] .. (val ~= "" and (": " .. val) or ""))
end

local function recall_value_label(ri)
    return current_flags[RECALL_KEYS[ri]] and "On" or "Off"
end

local function announce_recall(ri)
    say(RECALL_LABELS[ri] .. ": " .. recall_value_label(ri))
end

local function browse_item_name(snap)
    local name = snap.item_name ~= "" and item_utils.humanize_item_name(snap.item_name)
        or snap.item_guid:sub(1, 13)
    local pipe = name:find("|")
    if pipe then name = name:sub(1, pipe - 1) end
    return name
end

local function announce_browse(i, with_hint)
    local snap = current_snaps[i]
    local item = snap_info.get_item_by_guid(snap.item_guid)
    local pos_str = item and format_timestr_pos(GetMediaItemInfo_Value(item, "D_POSITION"), "", -1)
        or "unknown position"
    local notes = (snap.notes and snap.notes ~= "") and (". Notes: " .. snap.notes) or ""
    local msg = string.format("%d of %d: %s at %s%s", i, #current_snaps, browse_item_name(snap), pos_str, notes)
    if with_hint then
        msg = msg .. ". Enter to recall, Backspace to delete, Control N for notes, Control D for changes"
    end
    say(msg)
end

local function browse_seek_and_select(i)
    if current_flags.disable_auto_recall then return end
    local snap = current_snaps[i]
    local item = snap_info.get_item_by_guid(snap.item_guid)
    if not item then return end
    SetEditCurPos(GetMediaItemInfo_Value(item, "D_POSITION"), true, true)
    SelectAllMediaItems(0, false)
    for _, peer in ipairs(item_utils.get_item_peers(item)) do
        SetMediaItemSelected(peer, true)
    end
    UpdateArrange()
end

local function enter_browse()
    current_snaps, current_flags = snap_info.load_bank(current_bank)
    snap_info.sort_by_timeline(current_snaps)
    if #current_snaps == 0 then
        say("No snapshots in bank " .. current_bank)
        return
    end
    browse_idx = 1
    state = STATE_BROWSE
    announce_browse(1, true)
    browse_seek_and_select(1)
end

local function handle_recall_key(char)
    if char == KEY_UP then
        recall_idx = recall_idx > 1 and recall_idx - 1 or #RECALL_LABELS
        announce_recall(recall_idx)
    elseif char == KEY_DOWN then
        recall_idx = recall_idx < #RECALL_LABELS and recall_idx + 1 or 1
        announce_recall(recall_idx)
    elseif char == KEY_ENTER then
        local key = RECALL_KEYS[recall_idx]
        current_flags[key] = not current_flags[key]
        save_flags()
        say(recall_value_label(recall_idx))
    elseif char == KEY_ESC then
        state = STATE_MAIN
        say("Recall Parameters")
    end
    return true
end

local function handle_browse_key(char)
    if char == KEY_UP then
        browse_idx = browse_idx > 1 and browse_idx - 1 or #current_snaps
        announce_browse(browse_idx)
        browse_seek_and_select(browse_idx)
    elseif char == KEY_DOWN then
        browse_idx = browse_idx < #current_snaps and browse_idx + 1 or 1
        announce_browse(browse_idx)
        browse_seek_and_select(browse_idx)
    elseif char == KEY_ENTER then
        local snap = current_snaps[browse_idx]
        snap_info.recall_snapshot(snap, current_flags)
        say("Recalled: " .. browse_item_name(snap))
    elseif char == KEY_BACK then
        local name = browse_item_name(current_snaps[browse_idx])
        table.remove(current_snaps, browse_idx)
        snap_info.save_bank(current_bank, current_snaps, current_flags)
        say("Deleted: " .. name)
        current_snaps, current_flags = snap_info.load_bank(current_bank)
        snap_info.sort_by_timeline(current_snaps)
        if #current_snaps == 0 then
            state = STATE_MAIN
        else
            browse_idx = math.min(browse_idx, #current_snaps)
            announce_browse(browse_idx)
            browse_seek_and_select(browse_idx)
        end
    elseif char == KEY_NOTES then
        local ok, entered = ui_input.ask(WINDOW_TITLE,
            "Snapshot Notes", "Notes", current_snaps[browse_idx].notes or "")
        if ok then
            current_snaps[browse_idx].notes = entered
            save_flags()
            say("Notes saved")
        else
            say("Cancelled")
        end
    elseif char == KEY_CHANGES then
        local lines = snap_info.compute_snapshot_diff(current_snaps[browse_idx])
        if #lines == 0 then
            say("All captured values are at default")
        else
            say("Changes from default: " .. table.concat(lines, ". "))
        end
    elseif char == KEY_ESC then
        state = STATE_MAIN
        say("Browse Snapshots")
    end
    return true
end

local function do_add_snapshot()
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
    local created = snap_info.capture_snapshot_for_item(item_guid, item_name, current_bank)
    current_snaps, current_flags = snap_info.load_bank(current_bank)
    local display = item_name ~= "" and item_utils.humanize_item_name(item_name) or item_guid:sub(1, 13)
    local msg = (created and "Snapshot created: " or "Snapshot updated: ") .. display
    if not current_flags.disable_auto_recall
        and snap_info.ensure_daemon_running(script_path .. "ReaClassical_Mixer Snapshots Daemon.lua") then
        msg = msg .. ". Snapshot daemon started"
    end
    say(msg)
end

local function handle_key(char)
    if state == STATE_RECALL then return handle_recall_key(char) end
    if state == STATE_BROWSE then return handle_browse_key(char) end

    if state == STATE_CONFIRM_CLEAR then
        if char == KEY_ENTER then
            current_flags.counter = 0
            snap_info.save_bank(current_bank, {}, current_flags)
            say("Bank " .. current_bank .. " cleared")
            current_snaps, current_flags = snap_info.load_bank(current_bank)
            state = STATE_MAIN
        elseif char == KEY_ESC then
            state = STATE_MAIN
            say("Cancelled")
        end
        return true
    end

    if char == KEY_UP then
        field_idx = field_idx > 1 and field_idx - 1 or #FIELD_LABELS
        announce_field(field_idx)
    elseif char == KEY_DOWN then
        field_idx = field_idx < #FIELD_LABELS and field_idx + 1 or 1
        announce_field(field_idx)
    elseif char == KEY_ENTER then
        if field_idx == IDX_BANK then
            local bi = 1
            for i, b in ipairs(BANKS) do
                if b == current_bank then bi = i; break end
            end
            snap_info.set_current_bank(BANKS[(bi % #BANKS) + 1])
            load_all()
            say(value_label(IDX_BANK))
        elseif field_idx == IDX_ADD then
            do_add_snapshot()
        elseif field_idx == IDX_BROWSE then
            enter_browse()
        elseif field_idx == IDX_AR then
            current_flags.disable_auto_recall = not current_flags.disable_auto_recall
            snap_info.save_bank(current_bank, current_snaps, current_flags)
            local msg = "Auto-recall (bank " .. current_bank .. "): "
                .. (current_flags.disable_auto_recall and "off" or "on")
            local daemon_path = script_path .. "ReaClassical_Mixer Snapshots Daemon.lua"
            if current_flags.disable_auto_recall then
                if snap_info.stop_daemon_if_running(daemon_path) then
                    msg = msg .. ". Snapshot daemon stopped"
                end
            elseif snap_info.ensure_daemon_running(daemon_path) then
                msg = msg .. ". Snapshot daemon started"
            end
            say(msg)
            current_snaps, current_flags = snap_info.load_bank(current_bank)
        elseif field_idx == IDX_RECALL_MENU then
            state = STATE_RECALL
            recall_idx = 1
            say("Recall Parameters. " .. RECALL_LABELS[1] .. ": " .. recall_value_label(1))
        elseif field_idx == IDX_ADDAUTO then
            local automation_count, snapshot_count = snap_automation.convert_snapshots_to_automation()
            if snapshot_count == 0 then
                say("No snapshots to convert")
            else
                say(automation_count .. " automation lanes created from " .. snapshot_count .. " snapshots")
            end
            current_snaps, current_flags = snap_info.load_bank(current_bank)
        elseif field_idx == IDX_RMAUTO then
            local cleared_count = snap_automation.clear_all_automation()
            say("Cleared automation from " .. cleared_count .. " tracks")
            current_snaps, current_flags = snap_info.load_bank(current_bank)
        elseif field_idx == IDX_CLEARBANK then
            state = STATE_CONFIRM_CLEAR
            say("Clear all snapshots in bank " .. current_bank .. "? Enter to confirm, Escape to cancel")
        else
            current_flags[FIELD_KEYS[field_idx]] = not current_flags[FIELD_KEYS[field_idx]]
            save_flags()
            say(value_label(field_idx))
        end
    elseif char == KEY_ESC then
        return false
    end
    return true
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_RECALL then
        gfx.drawstr("[Recall Parameters: " .. RECALL_LABELS[recall_idx] .. "]  " .. recall_value_label(recall_idx))
    elseif state == STATE_BROWSE then
        local snap = current_snaps[browse_idx]
        gfx.drawstr("[Browse Snapshots " .. browse_idx .. "/" .. #current_snaps .. "]  "
                .. (snap and browse_item_name(snap) or ""))
    elseif state == STATE_CONFIRM_CLEAR then
        gfx.drawstr("[Clear Bank " .. current_bank .. "]  Enter to confirm, Escape to cancel")
    else
        local val = value_label(field_idx)
        gfx.drawstr("[" .. FIELD_LABELS[field_idx] .. "]" .. (val ~= "" and ("  " .. val) or ""))
    end
    gfx.update()
end

local function main()
    if not gui_mode.accessible() then
        gfx.quit()
        gui_mode.switch_window("ReaClassical_Mixer Snapshots.lua")
        return
    end

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

load_all()
gfx.init(WINDOW_TITLE, 500, 44, 0)
say(string.format("Snapshot Settings. %s: %s. Up or down to move, Enter to edit, Escape to close.",
    FIELD_LABELS[1], value_label(1)))

defer(main)
