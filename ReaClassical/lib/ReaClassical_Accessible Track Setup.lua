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
local say          = require("ReaClassical_Announce")
local gui_mode = require("ReaClassical_GuiMode")
local track_rename = require("ReaClassical_Track_Rename")
local af           = require("ReaClassical_Accessible_Focus")
local pan_from_name = require("ReaClassical_Pan_From_Name")
local help         = require("ReaClassical_Accessible_Help")
local ui_input     = require("ReaClassical_Accessible_Input")
local au           = require("ReaClassical_Automation_Info")
local transport    = require("ReaClassical_Transport_Utils")
local track_setup_commands = require("ReaClassical_Track_Setup_Commands")
local special_track_order = require("ReaClassical_Special_Track_Order")

set_action_options(3)

local STATE_MENU                 = "menu"
local STATE_TRACK_NAME           = "track_name"
local STATE_ADD_TRACK            = "add_track"
local STATE_REMOVE_TRACK         = "remove_track"
local STATE_REORDER_TRACK        = "reorder_track"
local STATE_REORDER_SPECIAL      = "reorder_special"
local STATE_SPECIAL_TYPE         = "special_type"
local STATE_SPECIAL_INDEX        = "special_index"
local STATE_ADD_SPECIAL_TYPE     = "add_special_type"
local STATE_ADD_SPECIAL_PARAM    = "add_special_param"
local STATE_REMOVE_SPECIAL_TYPE  = "remove_special_type"
local STATE_REMOVE_SPECIAL_INDEX = "remove_special_index"
local STATE_MIXER_CONTROL        = "mixer_control"
local STATE_MIXER_ROUTING        = "mixer_routing"
local STATE_MIXER_FX             = "mixer_fx"
local STATE_MIXER_FX_ADD         = "mixer_fx_add"
local STATE_MIXER_FX_PICK        = "mixer_fx_pick"
local STATE_MIXER_FX_PARAM       = "mixer_fx_param"
local STATE_MIXER_FX_VALUE       = "mixer_fx_value"
local STATE_SET_INPUTS_MENU      = "set_inputs_menu"
local STATE_SET_INPUTS_MANUAL    = "set_inputs_manual"
local STATE_CONVERT_CONFIRM      = "convert_confirm"
local STATE_MIXER_HW_OUTPUT      = "mixer_hw_output"
local STATE_HW_AUTO              = "hw_auto"
local STATE_OTHER_MENU           = "other_menu"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_LEFT  = 1818584692
local KEY_RIGHT = 1919379572
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_BACK  = 8

local WINDOW_TITLE = "Track Setup"

local MENU_ITEMS = {
    "Track Naming", "Add Track", "Remove Track", "Reorder Track", "Reorder Aux/Submix",
    "Special Track Naming", "Add Special Track", "Remove Special Track",
    "Other Commands", "Mixer Control", "Set Inputs",
}

local OTHER_MENU_ITEMS = {
    "Convert Workflow", "Connect All to RCM", "Disconnect All from RCM",
    "Auto Assign HW Outputs", "Clear All HW Outputs",
}

local function menu_index_of(label)
    for i, item in ipairs(MENU_ITEMS) do
        if item == label then return i end
    end
end

local SPECIAL_TYPES = {
    { type = "aux",       label = "Aux",       prefix = "@" },
    { type = "submix",    label = "Submix",    prefix = "#" },
    { type = "reference", label = "Reference", prefix = "REF:" },
}

local ADD_REMOVE_TYPES = {
    { type = "aux",         label = "Aux",         add_cmd = "add@",   add_named_prefix = "add@=", rm_prefix = "rm@" },
    { type = "submix",      label = "Submix",      add_cmd = "add#",   add_named_prefix = "add#=", rm_prefix = "rm#" },
    { type = "reference",   label = "Reference",   add_script = "ReaClassical_Add Ref Track.lua", rm_prefix = "rmref" },
    { type = "roomtone",    label = "RoomTone",    add_cmd = "addrt",   rm_cmd = "rmrt",   singleton = true },
    { type = "live",        label = "Live",        add_cmd = "addlive", rm_cmd = "rmlive", singleton = true },
    { type = "listenback",  label = "Listenback",  add_channel_prefix = "addlb=", rm_cmd = "rmlb", singleton = true },
    { type = "playback",    label = "Playback",    add_channel_prefix = "addpb=", rm_cmd = "rmpb", singleton = true },
}

local state       = STATE_MENU
local menu_idx    = 1
local other_menu_idx = 1
local workflow    = ""
local last_char   = 0

local mm_direct_entry = false

local function try_refocus()
    return af.refocus_existing(WINDOW_TITLE)
end

local function run_terminal_command(cmd)
    Undo_BeginBlock()
    local handled = track_setup_commands.try_project_setup(cmd)
        or track_setup_commands.try_input_config(cmd)
        or track_setup_commands.try_reorder(cmd)
        or track_setup_commands.try_add_remove(cmd)
        or track_setup_commands.try_routing_fx(cmd)
    Undo_EndBlock("ReaClassical Terminal: " .. cmd, -1)
    UpdateArrange()
    return handled
end

local function ask_text(box_title, caption, prefill)
    return ui_input.ask(box_title, box_title .. " - " .. caption, caption, prefill or "")
end

local function ask_number_required(box_title, caption, err_msg)
    while true do
        local ok, entered = ui_input.ask(box_title, box_title .. " - " .. caption,
            caption, "")
        if not ok then return nil end
        if entered ~= "" then return entered end
        say(err_msg)
    end
end

local mixer_tracks = {}
local tn_position   = 1
local rem_position  = 1
local reorder_position = 1
local reorder_picked_up = false
local reorder_original_position = 1

local rs_list = {}
local rs_position = 1
local rs_picked_up = false
local rs_track = nil
local rs_original_position = 1

local special_type_idx  = 1
local special_list      = {}
local special_idx       = 1

local addrm_type_idx      = 1
local add_special_str     = ""
local add_special_kind    = ""
local rmspecial_list      = {}
local rmspecial_idx       = 1

local mc_position = 1
local PAN_STEP_ROUGH   = 10
local PAN_STEP_FINE    = 1
local FADER_STEP_ROUGH = 1
local FADER_STEP_FINE  = 0.2

local function clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

local function format_pan(pan_val)
    if math.abs(pan_val) < 0.01 then
        return "center"
    elseif pan_val < 0 then
        return tostring(math.floor(-pan_val * 100 + 0.5)) .. " left"
    else
        return tostring(math.floor(pan_val * 100 + 0.5)) .. " right"
    end
end

local function linear_to_db(val)
    if val <= 0.0000000298023223876953125 then
        return -150.0
    end
    return 20 * math.log(val, 10)
end

local function db_to_linear(db)
    if db <= -150 then
        return 0.0
    end
    return 10 ^ (db / 20)
end

local function format_peak(track)
    local peak = -150.0
    local num_chans = math.min(GetMediaTrackInfo_Value(track, "I_NCHAN"), 2)
    for ch = 0, num_chans - 1 do
        local val = Track_GetPeakHoldDB(track, ch, false) * 100
        if val > peak then peak = val end
    end
    if peak <= -150.0 then return "silence" end
    return string.format("%.1f dB", peak)
end

local function refresh_mixer_tracks()
    mixer_tracks = track_rename.get_mixer_tracks()
end

local function announce_track_name(with_hint)
    local track = mixer_tracks[tn_position]
    if not track then
        say("No tracks found")
        return
    end
    local name = track_rename.get_mixer_base_name(track)
    local label = name ~= "" and name or "unnamed"
    if with_hint then
        say(string.format("Track %d of %d: %s. Enter opens an input box to rename; renaming then continues to the next track. "
            .. "Up or down for other tracks, Escape to go back.",
            tn_position, #mixer_tracks, label))
    else
        say(string.format("Track %d: %s", tn_position, label))
    end
end

local function run_track_rename_chain()
    while true do
        local track = mixer_tracks[tn_position]
        if not track then break end
        local current = track_rename.get_mixer_base_name(track)
        local ok, entered = ask_text(WINDOW_TITLE,
            "Rename Track " .. tn_position .. " of " .. #mixer_tracks, current)
        if not ok then
            say("Cancelled")
            break
        end
        Undo_BeginBlock()
        track_rename.rename_mixer_position(mixer_tracks, tn_position, entered, workflow)
        Undo_EndBlock("Rename Track", -1)
        say("Renamed")
        if tn_position < #mixer_tracks then
            tn_position = tn_position + 1
            announce_track_name(false)
        else
            say("Done")
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
            break
        end
    end
end

local function announce_remove_track(with_hint)
    local track = mixer_tracks[rem_position]
    if not track then
        say("No tracks found")
        return
    end
    local name = track_rename.get_mixer_base_name(track)
    local label = name ~= "" and name or "unnamed"
    if with_hint then
        say(string.format("Remove track. Track %d of %d: %s. Enter to remove, "
            .. "up or down to browse, Escape to cancel.", rem_position, #mixer_tracks, label))
    else
        say(string.format("Track %d: %s", rem_position, label))
    end
end

local function announce_reorder_track(with_hint)
    local track = mixer_tracks[reorder_position]
    if not track then
        say("No tracks found")
        return
    end
    local name = track_rename.get_mixer_base_name(track)
    local label = name ~= "" and name or "unnamed"
    if with_hint then
        say(string.format("Reorder track. Track %d of %d: %s. Up or down to browse, "
            .. "Enter to pick up, Escape to close.", reorder_position, #mixer_tracks, label))
    else
        say(string.format("Track %d: %s", reorder_position, label))
    end
end

local function announce_picked_up(with_hint)
    local track = mixer_tracks[reorder_position]
    local name = track and track_rename.get_mixer_base_name(track) or ""
    local label = name ~= "" and name or "unnamed"
    if with_hint then
        say(string.format("Picked up %s, position %d. Up or down to move, Enter to finish, Escape to cancel.",
            label, reorder_position))
    else
        say(string.format("Position %d: %s", reorder_position, label))
    end
end

local function refresh_rs_list()
    rs_list = special_track_order.get_routing_tracks()
end

local function rs_label(info)
    local type_label = info.type == "aux" and "Aux" or "Submix"
    return type_label .. " " .. info.number .. (info.name ~= "" and (": " .. info.name) or "")
end

local function announce_reorder_special(with_hint)
    local info = rs_list[rs_position]
    if not info then
        say("No aux or submix tracks found")
        return
    end
    if with_hint then
        say(string.format("Reorder aux and submix tracks. Position %d of %d: %s. Up or down to browse, "
            .. "Enter to pick up, Escape to close.", rs_position, #rs_list, rs_label(info)))
    else
        say(string.format("Position %d: %s", rs_position, rs_label(info)))
    end
end

local function announce_rs_picked_up(with_hint)
    local info = rs_list[rs_position]
    local label = info and rs_label(info) or ""
    if with_hint then
        say(string.format("Picked up %s, position %d of %d. Up or down to move, Enter to finish, Escape to cancel.",
            label, rs_position, #rs_list))
    else
        local previous = rs_list[rs_position - 1]
        say(string.format("Position %d of %d, %s", rs_position, #rs_list,
            previous and ("after " .. rs_label(previous)) or "first"))
    end
end

local function refresh_special_list()
    special_list = track_rename.get_special_tracks_by_type(SPECIAL_TYPES[special_type_idx].type)
end

local function announce_special_type(with_hint)
    local info = SPECIAL_TYPES[special_type_idx]
    local count = #track_rename.get_special_tracks_by_type(info.type)
    if with_hint then
        say(string.format("%s. %d track%s. Up or down to change type, Enter to select, Escape to go back.",
            info.label, count, count == 1 and "" or "s"))
    else
        say(string.format("%s. %d track%s.", info.label, count, count == 1 and "" or "s"))
    end
end

local function announce_special_index(with_hint)
    local info = special_list[special_idx]
    if not info then
        say("None found")
        return
    end
    local label = info.name ~= "" and info.name or "unnamed"
    if with_hint then
        say(string.format("%s %d of %d: %s. Enter opens an input box to rename; renaming then continues to the next entry. "
            .. "Up or down for others, Escape to go back.",
            SPECIAL_TYPES[special_type_idx].label, special_idx, #special_list, label))
    else
        say(string.format("%s %d: %s", SPECIAL_TYPES[special_type_idx].label, special_idx, label))
    end
end

local function announce_add_special_type(with_hint)
    local info = ADD_REMOVE_TYPES[addrm_type_idx]
    if with_hint then
        say(info.label .. ". Enter to add, up or down to change type, Escape to go back.")
    else
        say(info.label)
    end
end

local function announce_remove_special_type(with_hint)
    local info = ADD_REMOVE_TYPES[addrm_type_idx]
    local count = #track_rename.get_special_tracks_by_type(info.type)
    if with_hint then
        say(string.format("%s. %d track%s. Up or down to change type, Enter to remove, Escape to go back.",
            info.label, count, count == 1 and "" or "s"))
    else
        say(string.format("%s. %d track%s.", info.label, count, count == 1 and "" or "s"))
    end
end

local function announce_rmspecial_index(with_hint)
    local info = rmspecial_list[rmspecial_idx]
    if not info then
        say("None found")
        return
    end
    local type_label = ADD_REMOVE_TYPES[addrm_type_idx].label
    local label = info.name ~= "" and info.name or "unnamed"
    if with_hint then
        say(string.format("%s %d of %d: %s. Enter to remove, up or down for others, Escape to cancel.",
            type_label, rmspecial_idx, #rmspecial_list, label))
    else
        say(string.format("%s %d: %s", type_label, rmspecial_idx, label))
    end
end

local mc_tracks = {}

local MC_FIXED_TYPES = {
    rcmaster = true, roomtone = true, live = true, listenback = true, playback = true,
}

local MC_ROUTABLE_TYPES = { mixer = true, aux = true, submix = true }

local MC_TYPE_LABELS = {
    mixer = "Mixer", rcmaster = "RCMASTER", aux = "Aux", submix = "Submix",
    reference = "Reference", roomtone = "RoomTone", live = "Live",
    listenback = "Listenback", playback = "Playback",
}

local function refresh_mc_tracks()
    mc_tracks = {}
    local mixer_n, aux_n, submix_n, ref_n = 0, 0, 0, 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, spare_state = GetSetMediaTrackInfo_String(track, "P_EXT:spare", "", false)
        if mixer_state == "y" and spare_state == "y" then
        elseif mixer_state == "y" then
            mixer_n = mixer_n + 1
            mc_tracks[#mc_tracks + 1] = { track = track, type = "mixer", index = mixer_n,
                label = track_rename.get_mixer_base_name(track) }
        else
            local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
            local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
            local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
            local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
            local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
            local _, lb_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
            local _, rcm_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
            local _, pb_state = GetSetMediaTrackInfo_String(track, "P_EXT:playback", "", false)

            if aux_state == "y" then
                aux_n = aux_n + 1
                mc_tracks[#mc_tracks + 1] = { track = track, type = "aux", index = aux_n,
                    label = name:gsub("^[@#]:?", ""):gsub("%-$", "") }
            elseif submix_state == "y" then
                submix_n = submix_n + 1
                mc_tracks[#mc_tracks + 1] = { track = track, type = "submix", index = submix_n,
                    label = name:gsub("^[@#]:?", ""):gsub("%-$", "") }
            elseif rt_state == "y" then
                mc_tracks[#mc_tracks + 1] = { track = track, type = "roomtone", index = 1, label = "" }
            elseif ref_state == "y" then
                ref_n = ref_n + 1
                mc_tracks[#mc_tracks + 1] = { track = track, type = "reference", index = ref_n,
                    label = name:gsub("^REF:?", ""):gsub("%-$", "") }
            elseif live_state == "y" then
                mc_tracks[#mc_tracks + 1] = { track = track, type = "live", index = 1, label = "" }
            elseif lb_state == "y" then
                mc_tracks[#mc_tracks + 1] = { track = track, type = "listenback", index = 1, label = "" }
            elseif rcm_state == "y" then
                mc_tracks[#mc_tracks + 1] = { track = track, type = "rcmaster", index = 1, label = "" }
            elseif pb_state == "y" then
                mc_tracks[#mc_tracks + 1] = { track = track, type = "playback", index = 1, label = "" }
            end
        end
    end
end

local function mc_target_token(entry)
    if entry.type == "mixer" then return tostring(entry.index) end
    if entry.type == "aux" then return "@" .. entry.index end
    if entry.type == "submix" then return "#" .. entry.index end
    if entry.type == "rcmaster" then return "rcm" end
    if entry.type == "reference" then return "ref" .. entry.index end
    if entry.type == "roomtone" then return "rt" end
    if entry.type == "live" then return "live" end
    if entry.type == "listenback" then return "lb" end
    return "pb"
end

local function mc_type_label(entry)
    return MC_TYPE_LABELS[entry.type] or entry.type
end

local function mc_display(entry)
    if MC_FIXED_TYPES[entry.type] then
        return mc_type_label(entry)
    end
    local label = entry.label ~= "" and entry.label or "unnamed"
    if entry.type == "mixer" then
        return entry.index .. " " .. mc_type_label(entry) .. " " .. label
    end
    return mc_type_label(entry) .. " " .. label
end

local function get_input_source_track(mixer_track)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        for s = 0, GetTrackNumSends(t, 0) - 1 do
            if GetTrackSendInfo_Value(t, 0, s, "P_DESTTRACK") == mixer_track then
                return t
            end
        end
    end
    return nil
end

local function input_status_text(mixer_track)
    local source = get_input_source_track(mixer_track) or mixer_track
    local rec_input = math.floor(GetMediaTrackInfo_Value(source, "I_RECINPUT"))
    if rec_input == -1 or rec_input == 4096 then return "no input" end
    if (rec_input & 4096) ~= 0 and rec_input > 4096 then return "MIDI input" end
    local is_stereo = (rec_input & 1024) ~= 0
    local base_ch = is_stereo and (rec_input - 1024) or rec_input
    local hw_name1 = GetInputChannelName(base_ch)
    if is_stereo then
        local hw_name2 = GetInputChannelName(base_ch + 1)
        if hw_name1 and hw_name1 ~= "" and hw_name2 and hw_name2 ~= "" then
            return string.format("%s and %s, stereo", hw_name1, hw_name2)
        end
        return string.format("input %d and %d, stereo", base_ch + 1, base_ch + 2)
    end
    if hw_name1 and hw_name1 ~= "" then
        return string.format("%s, mono", hw_name1)
    end
    return string.format("input %d, mono", base_ch + 1)
end

local function status_suffix(track)
    local bits = {}
    if GetMediaTrackInfo_Value(track, "I_SOLO") > 0 then bits[#bits + 1] = "Soloed" end
    if GetMediaTrackInfo_Value(track, "B_MUTE") > 0 then bits[#bits + 1] = "Muted" end
    if #bits == 0 then return "" end
    return ", " .. table.concat(bits, ", ")
end

local function mixer_control_shortcuts(entry)
    local list = {
        { key = "Enter", desc = "Full status readout" },
        { key = "M", desc = "Toggle mute" },
        { key = "S", desc = "Toggle solo" },
        { key = "P", desc = "Toggle polarity" },
    }
    if MC_ROUTABLE_TYPES[entry.type] then
        list[#list + 1] = { key = "R", desc = "Routing picker" }
    end
    if entry.type == "mixer" then
        list[#list + 1] = { key = "I", desc = "Announce current input" }
    end
    list[#list + 1] = { key = "O", desc = "Hardware output" }
    list[#list + 1] = { key = "F", desc = "FX chain" }
    list[#list + 1] = { key = "Left or Right arrow", desc = "Pan (hold Shift for a finer step)" }
    list[#list + 1] = { key = "C", desc = "Center pan" }
    list[#list + 1] = { key = "Minus or Equals", desc = "Fader down or up (hold Shift for a finer step)" }
    list[#list + 1] = { key = "0 or U", desc = "Fader to unity" }
    list[#list + 1] = { key = "K", desc = "Fader to minus infinity" }
    list[#list + 1] = { key = "Shift+S", desc = "Unsolo all tracks" }
    list[#list + 1] = { key = "Shift+M", desc = "Unmute all tracks" }
    list[#list + 1] = { key = "Shift+P", desc = "Polarity normal, all tracks" }
    list[#list + 1] = { key = "Shift+C", desc = "Pan reset from track names, all tracks" }
    list[#list + 1] = { key = "Shift+U", desc = "Fader unity, all tracks" }
    list[#list + 1] = { key = "Shift+K", desc = "Fader minus infinity, all tracks" }
    list[#list + 1] = { key = "Escape", desc = "Close" }
    return list
end

local function announce_mixer_control(with_hint)
    local entry = mc_tracks[mc_position]
    if not entry then
        say("No tracks found")
        return
    end
    local display = mc_display(entry) .. ", " .. format_peak(entry.track) .. status_suffix(entry.track)
    if with_hint then
        say(string.format("Mixer Control. %d of %d: %s. Up or down to browse, Enter for status, "
            .. "H for shortcuts, Escape to close.",
            mc_position, #mc_tracks, display))
    else
        say(display)
    end
end

local function hw_output_status_text(track)
    local n = GetTrackNumSends(track, 1)
    if n == 0 then return "No hardware output" end
    local dst = math.floor(GetTrackSendInfo_Value(track, 1, 0, "I_DSTCHAN"))
    if dst >= 1024 then
        local ch = dst - 1024
        local hw_name = GetOutputChannelName(ch)
        if hw_name and hw_name ~= "" then
            return "Hardware output " .. hw_name
        end
        return string.format("Hardware output %d", ch + 1)
    end
    local hw_name1 = GetOutputChannelName(dst)
    local hw_name2 = GetOutputChannelName(dst + 1)
    if hw_name1 and hw_name1 ~= "" and hw_name2 and hw_name2 ~= "" then
        return string.format("Hardware output %s and %s", hw_name1, hw_name2)
    end
    return string.format("Hardware output %d and %d", dst + 1, dst + 2)
end

local function announce_hw_output(with_hint)
    local entry = mc_tracks[mc_position]
    if not entry then say("No tracks found") return end
    local status = hw_output_status_text(entry.track)
    if with_hint then
        say(string.format("%s. %s. Enter opens an input box for the channel number, "
            .. "C to clear, Escape to cancel.", mc_display(entry), status))
    else
        say(status)
    end
end

local function announce_mixer_status()
    local entry = mc_tracks[mc_position]
    if not entry then
        say("No tracks found")
        return
    end
    local track = entry.track
    local display = mc_display(entry)
    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    local phase = GetMediaTrackInfo_Value(track, "B_PHASE") == 1
    local pan = format_pan(GetMediaTrackInfo_Value(track, "D_PAN"))
    local db = linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL"))
    local rcm_part = ""
    if MC_ROUTABLE_TYPES[entry.type] then
        local _, disconnect_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
        local connected = disconnect_state ~= "y"
        rcm_part = " RCMASTER " .. (connected and "connected" or "disconnected") .. "."
    end
    local input_part = ""
    if entry.type == "mixer" then
        input_part = " " .. input_status_text(track):gsub("^%l", string.upper) .. "."
    end
    say(string.format("%s. Solo %s. Mute %s. Polarity %s. Pan %s. Fader %.1f dB.%s%s",
        display, soloed and "on" or "off", muted and "on" or "off",
        phase and "inverted" or "normal", pan, db, input_part, rcm_part))
end

local function has_send_to(src, dst)
    local n = GetTrackNumSends(src, 0)
    for i = 0, n - 1 do
        if GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK") == dst then
            return true, i
        end
    end
    return false, nil
end

local function build_routing_destinations(source_entry)
    local list = { { token = "rcm", label = "RCMASTER", is_rcm = true } }
    for i, info in ipairs(track_rename.get_special_tracks_by_type("aux")) do
        if not (source_entry.type == "aux" and source_entry.index == i) then
            list[#list + 1] = { token = "@" .. i, track = info.track,
                label = "Aux " .. i .. ": " .. (info.name ~= "" and info.name or "unnamed") }
        end
    end
    for i, info in ipairs(track_rename.get_special_tracks_by_type("submix")) do
        if not (source_entry.type == "submix" and source_entry.index == i) then
            list[#list + 1] = { token = "#" .. i, track = info.track,
                label = "Submix " .. i .. ": " .. (info.name ~= "" and info.name or "unnamed") }
        end
    end
    return list
end

local function is_dest_connected(source_track, dest)
    if dest.is_rcm then
        local _, disconnect_state = GetSetMediaTrackInfo_String(source_track, "P_EXT:rcm_disconnect", "", false)
        return disconnect_state ~= "y"
    end
    return has_send_to(source_track, dest.track)
end

local mc_routing_source = nil
local mc_routing_list   = {}
local mc_routing_idx    = 1

local function get_adjustable_send_idx(dest)
    if dest.is_rcm then return nil end
    local connected, send_idx = has_send_to(mc_routing_source.track, dest.track)
    return connected and send_idx or nil
end

local function announce_routing(with_hint)
    local dest = mc_routing_list[mc_routing_idx]
    local connected = is_dest_connected(mc_routing_source.track, dest)
    local state_str = connected and "connected" or "not connected"
    local level_str = ""
    local send_idx = get_adjustable_send_idx(dest)
    if send_idx then
        local db = linear_to_db(GetTrackSendInfo_Value(mc_routing_source.track, 0, send_idx, "D_VOL"))
        level_str = string.format(", %.1f dB", db)
    end
    if with_hint then
        say(string.format("Routing from %s. %s: %s%s. Up or down to browse, Enter to toggle, "
            .. "H for shortcuts, Escape to go back.",
            mc_display(mc_routing_source), dest.label, state_str, level_str))
    else
        say(string.format("%s: %s%s", dest.label, state_str, level_str))
    end
end

local function mixer_routing_shortcuts(dest)
    local list = { { key = "Enter", desc = "Toggle connection" } }
    if not dest.is_rcm then
        list[#list + 1] = { key = "Minus or Equals", desc = "Send level down or up (hold Shift for a finer step)" }
        list[#list + 1] = { key = "0", desc = "Send level to unity" }
    end
    list[#list + 1] = { key = "Escape", desc = "Go back" }
    return list
end

local mc_fx_source    = nil
local mc_fx_idx       = 1

local mc_installed_fx = nil

local function get_installed_fx()
    if mc_installed_fx then return mc_installed_fx end
    mc_installed_fx = {}
    local i = 0
    while true do
        local ok, name, ident = EnumInstalledFX(i)
        if not ok then break end
        mc_installed_fx[#mc_installed_fx + 1] = { name = name, ident = ident }
        i = i + 1
    end
    return mc_installed_fx
end

local MC_FX_SEARCH_CAP = 200

local function search_installed_fx(query)
    local q = query:lower()
    local matches = {}
    for _, fx in ipairs(get_installed_fx()) do
        if fx.name:lower():find(q, 1, true) then
            matches[#matches + 1] = fx
            if #matches >= MC_FX_SEARCH_CAP then break end
        end
    end
    return matches
end

local mc_fx_pick_list  = {}
local mc_fx_pick_idx   = 1
local mc_fx_pick_query = ""

local mc_fx_param_list  = {}
local mc_fx_param_idx   = 1
local mc_fx_range       = nil

local MC_FX_ENUM_STEP_LIMIT = 32

local function announce_fx_pick(with_hint)
    local pick = mc_fx_pick_list[mc_fx_pick_idx]
    if with_hint then
        local capped = #mc_fx_pick_list >= MC_FX_SEARCH_CAP
        say(string.format("%d match%s for %s.%s %d of %d: %s. Up or down to browse, "
            .. "Enter to add, Escape to go back.",
            #mc_fx_pick_list, #mc_fx_pick_list == 1 and "" or "es", mc_fx_pick_query,
            capped and " Showing first " .. MC_FX_SEARCH_CAP .. ", type more letters to narrow." or "",
            mc_fx_pick_idx, #mc_fx_pick_list, pick.name))
    else
        say(pick.name)
    end
end

local function announce_fx(with_hint)
    local track = mc_fx_source.track
    local count = TrackFX_GetCount(track)
    if count == 0 then
        say("FX Chain: " .. mc_display(mc_fx_source) .. ". No FX."
            .. (with_hint and " A to add, Escape to go back." or ""))
        return
    end
    mc_fx_idx = clamp(mc_fx_idx, 1, count)
    local _, fx_name = TrackFX_GetFXName(track, mc_fx_idx - 1, "")
    local enabled = TrackFX_GetEnabled(track, mc_fx_idx - 1)
    if with_hint then
        say(string.format("FX Chain: %s. %d of %d: %s (%s). Up or down to browse, Enter to toggle, "
            .. "H for shortcuts, Escape to go back.",
            mc_display(mc_fx_source), mc_fx_idx, count, fx_name, enabled and "on" or "off"))
    else
        say(string.format("%s (%s)", fx_name, enabled and "on" or "off"))
    end
end

local MIXER_FX_SHORTCUTS = {
    { key = "Enter", desc = "Toggle on or off" },
    { key = "A", desc = "Add FX" },
    { key = "Backspace", desc = "Remove FX" },
    { key = "Left or Right arrow", desc = "Reorder FX" },
    { key = "W", desc = "Open the FX window" },
    { key = "P", desc = "Edit parameters" },
    { key = "0", desc = "Reset to factory default" },
    { key = "Escape", desc = "Go back" },
}

local function announce_fx_moved()
    local track = mc_fx_source.track
    local count = TrackFX_GetCount(track)
    local _, fx_name = TrackFX_GetFXName(track, mc_fx_idx - 1, "")
    say(string.format("%s moved to %d of %d", fx_name, mc_fx_idx, count))
end

local function announce_fx_add(with_hint)
    if with_hint then
        say("Add FX. Enter opens the input box for the name, Escape to cancel.")
    end
end

local function init_mc_fx_param_list()
    mc_fx_param_list = {}
    local track = mc_fx_source.track
    local fx_raw = mc_fx_idx - 1
    local n = TrackFX_GetNumParams(track, fx_raw)
    for i = 0, n - 1 do
        local _, pname = TrackFX_GetParamName(track, fx_raw, i, "")
        mc_fx_param_list[#mc_fx_param_list + 1] = { raw_idx = i, name = pname }
    end
end

local function announce_mc_fx_param(with_hint)
    local param = mc_fx_param_list[mc_fx_param_idx]
    local track = mc_fx_source.track
    local fx_raw = mc_fx_idx - 1
    local _, current = TrackFX_GetFormattedParamValue(track, fx_raw, param.raw_idx, "")
    if with_hint then
        say(string.format("Parameters: %s. %d of %d: %s = %s. Up or down to browse, "
            .. "Enter to set a value, Escape to go back.",
            mc_display(mc_fx_source), mc_fx_param_idx, #mc_fx_param_list, param.name, current))
    else
        say(string.format("%s = %s", param.name, current))
    end
end

local SET_INPUTS_ITEMS = { "Auto", "Manual" }

local si_menu_idx    = 1
local si_position    = 1

local function input_record_enabled(mixer_track)
    local _, disabled = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:input_disabled", "", false)
    return disabled ~= "y"
end

local function mark_inputs_configured()
    SetProjExtState(0, "ReaClassical", "InputsConfigured", "y")
end

local function announce_manual_input(with_hint)
    local track = mixer_tracks[si_position]
    if not track then say("No tracks found") return end
    local name = track_rename.get_mixer_base_name(track)
    local label = name ~= "" and name or "unnamed"
    local status = input_status_text(track)
    local rec = input_record_enabled(track) and "record enabled" or "record disabled"
    if with_hint then
        say(string.format("Manual Inputs. %d of %d: %s. %s, %s. Up or down to browse, "
            .. "H for shortcuts, Escape to go back.",
            si_position, #mixer_tracks, label, status, rec))
    else
        say(string.format("%s. %s, %s", label, status, rec))
    end
end

local SET_INPUTS_MANUAL_SHORTCUTS = {
    { key = "M", desc = "Set mono input" },
    { key = "S", desc = "Set stereo input" },
    { key = "R", desc = "Toggle record enable" },
    { key = "Escape", desc = "Go back" },
}

local function handle_key(char)
    if state == STATE_MENU then
        if char == KEY_UP then
            menu_idx = menu_idx > 1 and menu_idx - 1 or #MENU_ITEMS
            say(MENU_ITEMS[menu_idx])
        elseif char == KEY_DOWN then
            menu_idx = menu_idx < #MENU_ITEMS and menu_idx + 1 or 1
            say(MENU_ITEMS[menu_idx])
        elseif char == KEY_ENTER then
            if menu_idx == 1 then
                refresh_mixer_tracks()
                if #mixer_tracks == 0 then
                    say("No mixer tracks found")
                    return true
                end
                tn_position = 1
                state = STATE_TRACK_NAME
                announce_track_name(true)
                run_track_rename_chain()
            elseif menu_idx == 2 then
                state = STATE_ADD_TRACK
                say("Add track. Enter opens the input box; leave it empty for a default name, Escape to cancel.")
            elseif menu_idx == 3 then
                refresh_mixer_tracks()
                if #mixer_tracks == 0 then
                    say("No mixer tracks found")
                    return true
                end
                rem_position = 1
                state = STATE_REMOVE_TRACK
                announce_remove_track(true)
            elseif menu_idx == 4 then
                refresh_mixer_tracks()
                if #mixer_tracks == 0 then
                    say("No mixer tracks found")
                    return true
                end
                reorder_position, reorder_picked_up = 1, false
                state = STATE_REORDER_TRACK
                announce_reorder_track(true)
            elseif menu_idx == 5 then
                refresh_rs_list()
                if #rs_list == 0 then
                    say("No aux or submix tracks found")
                    return true
                elseif #rs_list == 1 then
                    say("Only one aux or submix track, nothing to reorder")
                    return true
                end
                rs_position, rs_picked_up = 1, false
                state = STATE_REORDER_SPECIAL
                announce_reorder_special(true)
            elseif menu_idx == 6 then
                special_type_idx = 1
                state = STATE_SPECIAL_TYPE
                announce_special_type(true)
            elseif menu_idx == 7 then
                addrm_type_idx = 1
                state = STATE_ADD_SPECIAL_TYPE
                announce_add_special_type(true)
            elseif menu_idx == 8 then
                addrm_type_idx = 1
                state = STATE_REMOVE_SPECIAL_TYPE
                announce_remove_special_type(true)
            elseif menu_idx == 9 then
                other_menu_idx = 1
                state = STATE_OTHER_MENU
                say(OTHER_MENU_ITEMS[other_menu_idx]
                    .. ". Up or down to browse, Enter to select, Escape to go back.")
            elseif menu_idx == 10 then
                refresh_mc_tracks()
                if #mc_tracks == 0 then
                    say("No tracks found")
                    return true
                end
                mc_position = 1
                state = STATE_MIXER_CONTROL
                announce_mixer_control(true)
            else
                si_menu_idx = 1
                state = STATE_SET_INPUTS_MENU
                say("Set Inputs. " .. SET_INPUTS_ITEMS[si_menu_idx]
                    .. ". Up or down to change, Enter to select, Escape to go back.")
            end
        elseif char == KEY_ESC then
            return false
        end
    elseif state == STATE_OTHER_MENU then
        if char == KEY_UP then
            other_menu_idx = other_menu_idx > 1 and other_menu_idx - 1 or #OTHER_MENU_ITEMS
            say(OTHER_MENU_ITEMS[other_menu_idx])
        elseif char == KEY_DOWN then
            other_menu_idx = other_menu_idx < #OTHER_MENU_ITEMS and other_menu_idx + 1 or 1
            say(OTHER_MENU_ITEMS[other_menu_idx])
        elseif char == KEY_ENTER then
            if other_menu_idx == 1 then
                local target = workflow == "Horizontal" and "Vertical" or "Horizontal"
                state = STATE_CONVERT_CONFIRM
                say(string.format("Convert to %s workflow. Enter to confirm, Escape to cancel.", target))
            elseif other_menu_idx == 2 then
                run_terminal_command("*-rcm")
            elseif other_menu_idx == 3 then
                run_terminal_command("*/rcm")
            elseif other_menu_idx == 4 then
                state = STATE_HW_AUTO
                say("Auto Assign HW Outputs. Enter opens the input box; leave it empty to start from output 1, Escape to cancel.")
            else
                run_terminal_command("clearhw")
            end
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_CONVERT_CONFIRM then
        if char == KEY_ENTER then
            local cmd = workflow == "Horizontal" and "convert=v" or "convert=h"
            run_terminal_command(cmd)
            if try_refocus() then
                local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
                workflow = wf
                state = STATE_OTHER_MENU
                say(OTHER_MENU_ITEMS[other_menu_idx])
            else
                say("Closing.")
                return false
            end
        elseif char == KEY_ESC then
            say("Cancelled")
            state = STATE_OTHER_MENU
            say(OTHER_MENU_ITEMS[other_menu_idx])
        end
    elseif state == STATE_HW_AUTO then
        if char == KEY_ENTER then
            local ok, entered = ui_input.ask(WINDOW_TITLE,
                "Auto Assign HW Outputs", "Starting hardware output, blank for 1", "")
            if ok then
                run_terminal_command(entered == "" and "aho" or ("aho=" .. entered))
                state = STATE_OTHER_MENU
                say(OTHER_MENU_ITEMS[other_menu_idx])
            else
                say("Cancelled")
            end
        elseif char == KEY_ESC then
            state = STATE_OTHER_MENU
            say(OTHER_MENU_ITEMS[other_menu_idx])
        end
    elseif state == STATE_TRACK_NAME then
        if char == KEY_UP or char == KEY_DOWN then
            if char == KEY_UP then
                tn_position = tn_position > 1 and tn_position - 1 or #mixer_tracks
            else
                tn_position = tn_position < #mixer_tracks and tn_position + 1 or 1
            end
            announce_track_name(false)
        elseif char == KEY_ENTER then
            run_track_rename_chain()
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_ADD_TRACK then
        if char == KEY_ENTER then
            local ok, entered = ask_text(WINDOW_TITLE, "Add Track", "")
            if ok then
                run_terminal_command(entered ~= "" and ("add=" .. entered) or "add")
                if try_refocus() then
                    state = STATE_MENU
                    say(MENU_ITEMS[menu_idx])
                else
                    say("Closing.")
                    return false
                end
            else
                say("Cancelled")
                state = STATE_MENU
                say(MENU_ITEMS[menu_idx])
            end
        elseif char == KEY_ESC then
            say("Cancelled")
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_REMOVE_TRACK then
        if char == KEY_UP then
            rem_position = rem_position > 1 and rem_position - 1 or #mixer_tracks
            announce_remove_track(false)
        elseif char == KEY_DOWN then
            rem_position = rem_position < #mixer_tracks and rem_position + 1 or 1
            announce_remove_track(false)
        elseif char == KEY_ENTER then
            run_terminal_command("rm" .. rem_position)
            if try_refocus() then
                refresh_mixer_tracks()
                if #mixer_tracks == 0 then
                    state = STATE_MENU
                    say(MENU_ITEMS[menu_idx])
                else
                    rem_position = math.min(rem_position, #mixer_tracks)
                    announce_remove_track(false)
                end
            else
                say("Closing.")
                return false
            end
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_REORDER_TRACK then
        if reorder_picked_up then
            if char == KEY_UP then
                if reorder_position > 1 then
                    run_terminal_command("mv" .. reorder_position .. "u")
                    if try_refocus() then
                        refresh_mixer_tracks()
                        reorder_position = reorder_position - 1
                        announce_picked_up(false)
                    else
                        say("Closing.")
                        return false
                    end
                else
                    say("Top of list")
                end
            elseif char == KEY_DOWN then
                if reorder_position < #mixer_tracks then
                    run_terminal_command("mv" .. reorder_position .. "d")
                    if try_refocus() then
                        refresh_mixer_tracks()
                        reorder_position = reorder_position + 1
                        announce_picked_up(false)
                    else
                        say("Closing.")
                        return false
                    end
                else
                    say("Bottom of list")
                end
            elseif char == KEY_ENTER then
                reorder_picked_up = false
                say("Moved to position " .. reorder_position .. ".")
                announce_reorder_track(false)
            elseif char == KEY_ESC then
                local delta = reorder_position - reorder_original_position
                if delta == 0 then
                    reorder_picked_up = false
                    say("Cancelled")
                    announce_reorder_track(false)
                else
                    local cmd = delta > 0
                        and ("mv" .. reorder_position .. "u" .. delta)
                        or ("mv" .. reorder_position .. "d" .. (-delta))
                    run_terminal_command(cmd)
                    if try_refocus() then
                        refresh_mixer_tracks()
                        reorder_position = reorder_original_position
                        reorder_picked_up = false
                        say("Cancelled")
                        announce_reorder_track(false)
                    else
                        say("Closing.")
                        return false
                    end
                end
            end
        else
            if char == KEY_UP then
                reorder_position = reorder_position > 1 and reorder_position - 1 or #mixer_tracks
                announce_reorder_track(false)
            elseif char == KEY_DOWN then
                reorder_position = reorder_position < #mixer_tracks and reorder_position + 1 or 1
                announce_reorder_track(false)
            elseif char == KEY_ENTER then
                reorder_original_position = reorder_position
                reorder_picked_up = true
                announce_picked_up(true)
            elseif char == KEY_ESC then
                state = STATE_MENU
                say(MENU_ITEMS[menu_idx])
            end
        end
    elseif state == STATE_REORDER_SPECIAL then
        if rs_picked_up then
            if char == KEY_UP or char == KEY_DOWN then
                local delta = (char == KEY_UP) and -1 or 1
                Undo_BeginBlock()
                local ok, result = special_track_order.move_routing_track(rs_track, delta)
                Undo_EndBlock("Reorder Aux/Submix", -1)
                if ok then
                    UpdateArrange()
                    refresh_rs_list()
                    rs_position = result
                    announce_rs_picked_up(false)
                else
                    say(result == "top" and "Top of list" or "Bottom of list")
                end
            elseif char == KEY_ENTER then
                rs_picked_up = false
                say("Moved to position " .. rs_position .. ".")
                announce_reorder_special(false)
            elseif char == KEY_ESC then
                local steps = rs_position - rs_original_position
                Undo_BeginBlock()
                while steps ~= 0 do
                    local delta = steps > 0 and -1 or 1
                    if not special_track_order.move_routing_track(rs_track, delta) then break end
                    steps = steps + delta
                end
                Undo_EndBlock("Reorder Aux/Submix", -1)
                UpdateArrange()
                refresh_rs_list()
                rs_position = rs_original_position
                rs_picked_up = false
                say("Cancelled")
                announce_reorder_special(false)
            end
        else
            if char == KEY_UP then
                rs_position = rs_position > 1 and rs_position - 1 or #rs_list
                announce_reorder_special(false)
            elseif char == KEY_DOWN then
                rs_position = rs_position < #rs_list and rs_position + 1 or 1
                announce_reorder_special(false)
            elseif char == KEY_ENTER then
                rs_original_position = rs_position
                rs_track = rs_list[rs_position].track
                rs_picked_up = true
                announce_rs_picked_up(true)
            elseif char == KEY_ESC then
                state = STATE_MENU
                say(MENU_ITEMS[menu_idx])
            end
        end
    elseif state == STATE_SPECIAL_TYPE then
        if char == KEY_UP then
            special_type_idx = special_type_idx > 1 and special_type_idx - 1 or #SPECIAL_TYPES
            announce_special_type(false)
        elseif char == KEY_DOWN then
            special_type_idx = special_type_idx < #SPECIAL_TYPES and special_type_idx + 1 or 1
            announce_special_type(false)
        elseif char == KEY_ENTER then
            refresh_special_list()
            if #special_list == 0 then
                say("None found")
            else
                special_idx = 1
                state = STATE_SPECIAL_INDEX
                announce_special_index(true)
            end
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_SPECIAL_INDEX then
        if char == KEY_UP or char == KEY_DOWN then
            if char == KEY_UP then
                special_idx = special_idx > 1 and special_idx - 1 or #special_list
            else
                special_idx = special_idx < #special_list and special_idx + 1 or 1
            end
            announce_special_index(false)
        elseif char == KEY_ENTER then
            while true do
                local info = special_list[special_idx]
                local ok, entered = ask_text(WINDOW_TITLE,
                    "Rename " .. SPECIAL_TYPES[special_type_idx].label
                        .. " " .. special_idx .. " of " .. #special_list, "")
                if not ok then
                    say("Cancelled")
                    announce_special_index(false)
                    break
                end
                Undo_BeginBlock()
                track_rename.rename_special_track(info.track,
                    SPECIAL_TYPES[special_type_idx].prefix, entered)
                Undo_EndBlock("Rename Special Track", -1)
                say("Renamed")
                refresh_special_list()
                if special_idx < #special_list then
                    special_idx = special_idx + 1
                    announce_special_index(false)
                else
                    say("Done")
                    state = STATE_SPECIAL_TYPE
                    announce_special_type(false)
                    break
                end
            end
        elseif char == KEY_ESC then
            state = STATE_SPECIAL_TYPE
            announce_special_type(false)
        end
    elseif state == STATE_ADD_SPECIAL_TYPE then
        if char == KEY_UP then
            addrm_type_idx = addrm_type_idx > 1 and addrm_type_idx - 1 or #ADD_REMOVE_TYPES
            announce_add_special_type(false)
        elseif char == KEY_DOWN then
            addrm_type_idx = addrm_type_idx < #ADD_REMOVE_TYPES and addrm_type_idx + 1 or 1
            announce_add_special_type(false)
        elseif char == KEY_ENTER then
            local info = ADD_REMOVE_TYPES[addrm_type_idx]
            if info.add_script then
                dofile(script_path .. info.add_script)
                if try_refocus() then
                    announce_add_special_type(false)
                else
                    say("Closing.")
                    return false
                end
            elseif info.add_named_prefix then
                add_special_str, add_special_kind = "", "name"
                state = STATE_ADD_SPECIAL_PARAM
                say("Enter opens the input box; leave it empty for no name, Escape to cancel.")
            elseif info.add_channel_prefix then
                add_special_str, add_special_kind = "", "channel"
                state = STATE_ADD_SPECIAL_PARAM
                say("Enter hardware channel number, Escape to cancel.")
            else
                run_terminal_command(info.add_cmd)
                if try_refocus() then
                    announce_add_special_type(false)
                else
                    say("Closing.")
                    return false
                end
            end
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_ADD_SPECIAL_PARAM then
        local info = ADD_REMOVE_TYPES[addrm_type_idx]
        if char == KEY_ENTER then
            if add_special_kind == "name" then
                local ok, entered = ask_text(WINDOW_TITLE,
                    "Add " .. info.label .. " - Name", "")
                if not ok then
                    say("Cancelled")
                    state = STATE_ADD_SPECIAL_TYPE
                    announce_add_special_type(false)
                    return true
                end
                run_terminal_command(entered ~= "" and (info.add_named_prefix .. entered)
                    or info.add_cmd)
            else
                local entered = ask_number_required(WINDOW_TITLE,
                    "Add " .. info.label .. " - Channel",
                    "Please enter a hardware channel number")
                if not entered then
                    say("Cancelled")
                    state = STATE_ADD_SPECIAL_TYPE
                    announce_add_special_type(false)
                    return true
                end
                run_terminal_command(info.add_channel_prefix .. entered)
            end
            if try_refocus() then
                state = STATE_ADD_SPECIAL_TYPE
                announce_add_special_type(false)
            else
                say("Closing.")
                return false
            end
        elseif char == KEY_ESC then
            say("Cancelled")
            state = STATE_ADD_SPECIAL_TYPE
            announce_add_special_type(false)
        end
    elseif state == STATE_REMOVE_SPECIAL_TYPE then
        if char == KEY_UP then
            addrm_type_idx = addrm_type_idx > 1 and addrm_type_idx - 1 or #ADD_REMOVE_TYPES
            announce_remove_special_type(false)
        elseif char == KEY_DOWN then
            addrm_type_idx = addrm_type_idx < #ADD_REMOVE_TYPES and addrm_type_idx + 1 or 1
            announce_remove_special_type(false)
        elseif char == KEY_ENTER then
            local info = ADD_REMOVE_TYPES[addrm_type_idx]
            local count = #track_rename.get_special_tracks_by_type(info.type)
            if count == 0 then
                say("None found")
            elseif info.singleton or count == 1 then
                run_terminal_command(info.rm_cmd or info.rm_prefix)
                announce_remove_special_type(false)
            else
                rmspecial_list = track_rename.get_special_tracks_by_type(info.type)
                rmspecial_idx = 1
                state = STATE_REMOVE_SPECIAL_INDEX
                announce_rmspecial_index(true)
            end
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_REMOVE_SPECIAL_INDEX then
        if char == KEY_UP then
            rmspecial_idx = rmspecial_idx > 1 and rmspecial_idx - 1 or #rmspecial_list
            announce_rmspecial_index(false)
        elseif char == KEY_DOWN then
            rmspecial_idx = rmspecial_idx < #rmspecial_list and rmspecial_idx + 1 or 1
            announce_rmspecial_index(false)
        elseif char == KEY_ENTER then
            local info = ADD_REMOVE_TYPES[addrm_type_idx]
            run_terminal_command(info.rm_prefix .. rmspecial_idx)
            rmspecial_list = track_rename.get_special_tracks_by_type(info.type)
            if #rmspecial_list == 0 then
                state = STATE_REMOVE_SPECIAL_TYPE
                announce_remove_special_type(false)
            else
                rmspecial_idx = math.min(rmspecial_idx, #rmspecial_list)
                announce_rmspecial_index(false)
            end
        elseif char == KEY_ESC then
            state = STATE_REMOVE_SPECIAL_TYPE
            announce_remove_special_type(false)
        end
    elseif state == STATE_MIXER_CONTROL then
        local entry = mc_tracks[mc_position]
        local track = entry.track
        local shift_held = gfx.mouse_cap & 8 == 8
        if transport.handle_transport_key(char) then
        elseif char == KEY_UP then
            mc_position = mc_position > 1 and mc_position - 1 or #mc_tracks
            announce_mixer_control(false)
        elseif char == KEY_DOWN then
            mc_position = mc_position < #mc_tracks and mc_position + 1 or 1
            announce_mixer_control(false)
        elseif char == KEY_ENTER then
            announce_mixer_status()
        elseif char == 104 or char == 72 then
            help.enter(mixer_control_shortcuts(entry), function() announce_mixer_control(false) end)
        elseif char == 109 then
            local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
            SetMediaTrackInfo_Value(track, "B_MUTE", muted and 0 or 1)
            say(muted and "Mute off" or "Mute on")
        elseif char == 115 then
            local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
            SetMediaTrackInfo_Value(track, "I_SOLO", soloed and 0 or 2)
            say(soloed and "Solo off" or "Solo on")
        elseif char == 112 then
            local phase = GetMediaTrackInfo_Value(track, "B_PHASE") == 1
            SetMediaTrackInfo_Value(track, "B_PHASE", phase and 0 or 1)
            say(phase and "Polarity normal" or "Polarity inverted")
        elseif char == KEY_LEFT or char == KEY_RIGHT then
            local step = (shift_held and PAN_STEP_FINE or PAN_STEP_ROUGH) / 100
            if char == KEY_LEFT then step = -step end
            local pan = clamp(GetMediaTrackInfo_Value(track, "D_PAN") + step, -1, 1)
            SetMediaTrackInfo_Value(track, "D_PAN", pan)
            say("Pan " .. format_pan(pan))
        elseif char == 99 then
            SetMediaTrackInfo_Value(track, "D_PAN", 0)
            say("Pan center")
        elseif char == 45 or char == 95 then
            local step = char == 95 and FADER_STEP_FINE or FADER_STEP_ROUGH
            local db = linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL")) - step
            SetMediaTrackInfo_Value(track, "D_VOL", db_to_linear(db))
            say(string.format("Fader %.1f dB", db))
        elseif char == 61 or char == 43 then
            local step = char == 43 and FADER_STEP_FINE or FADER_STEP_ROUGH
            local db = linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL")) + step
            SetMediaTrackInfo_Value(track, "D_VOL", db_to_linear(db))
            say(string.format("Fader %.1f dB", db))
        elseif char == 48 or char == 117 then
            SetMediaTrackInfo_Value(track, "D_VOL", 1.0)
            say("Fader unity")
        elseif char == 107 then
            SetMediaTrackInfo_Value(track, "D_VOL", 0.0)
            say("Fader minus infinity")
        elseif char == 105 or char == 73 then
            if entry.type == "mixer" then
                say(input_status_text(track):gsub("^%l", string.upper))
            else
                say("No input for this track")
            end
        elseif char == 111 or char == 79 then
            state = STATE_MIXER_HW_OUTPUT
            announce_hw_output(true)
        elseif char == 114 or char == 82 then
            if MC_ROUTABLE_TYPES[entry.type] then
                mc_routing_source = entry
                mc_routing_list = build_routing_destinations(entry)
                mc_routing_idx = 1
                state = STATE_MIXER_ROUTING
                announce_routing(true)
            else
                say("No routing available")
            end
        elseif char == 102 or char == 70 then
            mc_fx_source = entry
            mc_fx_idx = 1
            state = STATE_MIXER_FX
            announce_fx(true)
        elseif char == 83 then
            Undo_BeginBlock()
            for _, e in ipairs(mc_tracks) do
                SetMediaTrackInfo_Value(e.track, "I_SOLO", 0)
            end
            Undo_EndBlock("Unsolo All Tracks", -1)
            say("All tracks unsoloed")
        elseif char == 77 then
            Undo_BeginBlock()
            for _, e in ipairs(mc_tracks) do
                SetMediaTrackInfo_Value(e.track, "B_MUTE", 0)
            end
            Undo_EndBlock("Unmute All Tracks", -1)
            say("All tracks unmuted")
        elseif char == 80 then
            Undo_BeginBlock()
            for _, e in ipairs(mc_tracks) do
                SetMediaTrackInfo_Value(e.track, "B_PHASE", 0)
            end
            Undo_EndBlock("Reset Polarity (All Tracks)", -1)
            say("Polarity normal on all tracks")
        elseif char == 67 then
            Undo_BeginBlock()
            for _, e in ipairs(mc_tracks) do
                pan_from_name.apply_pan_from_name(e.track, e.label)
            end
            Undo_EndBlock("Reset Pan From Name (All Tracks)", -1)
            say("Pan reset from track names")
        elseif char == 85 then
            Undo_BeginBlock()
            for _, e in ipairs(mc_tracks) do
                SetMediaTrackInfo_Value(e.track, "D_VOL", 1.0)
            end
            Undo_EndBlock("Fader Unity (All Tracks)", -1)
            say("All faders reset to unity")
        elseif char == 75 then
            Undo_BeginBlock()
            for _, e in ipairs(mc_tracks) do
                SetMediaTrackInfo_Value(e.track, "D_VOL", 0.0)
            end
            Undo_EndBlock("Fader Minus Infinity (All Tracks)", -1)
            say("All faders minus infinity")
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_MIXER_ROUTING then
        if char == KEY_UP then
            mc_routing_idx = mc_routing_idx > 1 and mc_routing_idx - 1 or #mc_routing_list
            announce_routing(false)
        elseif char == KEY_DOWN then
            mc_routing_idx = mc_routing_idx < #mc_routing_list and mc_routing_idx + 1 or 1
            announce_routing(false)
        elseif char == KEY_ENTER then
            local dest = mc_routing_list[mc_routing_idx]
            local source_token = mc_target_token(mc_routing_source)
            local connected = is_dest_connected(mc_routing_source.track, dest)
            run_terminal_command(source_token .. (connected and "/" or "-") .. dest.token)
            announce_routing(false)
        elseif char == 104 or char == 72 then
            help.enter(mixer_routing_shortcuts(mc_routing_list[mc_routing_idx]), function() announce_routing(false) end)
        elseif char == 45 or char == 95 then
            local dest = mc_routing_list[mc_routing_idx]
            local send_idx = get_adjustable_send_idx(dest)
            if not send_idx then
                say(dest.is_rcm and "No level for RCMASTER" or "Connect first")
            else
                local step = char == 95 and FADER_STEP_FINE or FADER_STEP_ROUGH
                local db = linear_to_db(GetTrackSendInfo_Value(mc_routing_source.track, 0, send_idx, "D_VOL")) - step
                SetTrackSendInfo_Value(mc_routing_source.track, 0, send_idx, "D_VOL", db_to_linear(db))
                say(string.format("%s: %.1f dB", dest.label, db))
            end
        elseif char == 61 or char == 43 then
            local dest = mc_routing_list[mc_routing_idx]
            local send_idx = get_adjustable_send_idx(dest)
            if not send_idx then
                say(dest.is_rcm and "No level for RCMASTER" or "Connect first")
            else
                local step = char == 43 and FADER_STEP_FINE or FADER_STEP_ROUGH
                local db = linear_to_db(GetTrackSendInfo_Value(mc_routing_source.track, 0, send_idx, "D_VOL")) + step
                SetTrackSendInfo_Value(mc_routing_source.track, 0, send_idx, "D_VOL", db_to_linear(db))
                say(string.format("%s: %.1f dB", dest.label, db))
            end
        elseif char == 48 then
            local dest = mc_routing_list[mc_routing_idx]
            local send_idx = get_adjustable_send_idx(dest)
            if not send_idx then
                say(dest.is_rcm and "No level for RCMASTER" or "Connect first")
            else
                SetTrackSendInfo_Value(mc_routing_source.track, 0, send_idx, "D_VOL", 1.0)
                say(dest.label .. ": send unity")
            end
        elseif char == KEY_ESC then
            if mm_direct_entry then return false end
            state = STATE_MIXER_CONTROL
            announce_mixer_control(false)
        end
    elseif state == STATE_MIXER_HW_OUTPUT then
        local entry = mc_tracks[mc_position]
        if char == KEY_ENTER then
            local entered = ask_number_required(WINDOW_TITLE,
                "Hardware Output", "Please enter a channel number")
            if entered then
                run_terminal_command(mc_target_token(entry) .. "=out," .. entered)
                state = STATE_MIXER_CONTROL
                announce_mixer_control(false)
            else
                say("Cancelled")
                state = STATE_MIXER_CONTROL
                announce_mixer_control(false)
            end
        elseif char == 99 or char == 67 then
            run_terminal_command(mc_target_token(entry) .. "rmout")
            state = STATE_MIXER_CONTROL
            announce_mixer_control(false)
        elseif char == KEY_ESC then
            say("Cancelled")
            state = STATE_MIXER_CONTROL
            announce_mixer_control(false)
        end
    elseif state == STATE_MIXER_FX then
        local track = mc_fx_source.track
        local count = TrackFX_GetCount(track)
        if transport.handle_transport_key(char) then
        elseif char == KEY_UP then
            if count > 0 then
                mc_fx_idx = mc_fx_idx > 1 and mc_fx_idx - 1 or count
                announce_fx(false)
            end
        elseif char == KEY_DOWN then
            if count > 0 then
                mc_fx_idx = mc_fx_idx < count and mc_fx_idx + 1 or 1
                announce_fx(false)
            end
        elseif char == KEY_ENTER then
            if count > 0 then
                local enabled = TrackFX_GetEnabled(track, mc_fx_idx - 1)
                TrackFX_SetEnabled(track, mc_fx_idx - 1, not enabled)
                say(not enabled and "On" or "Off")
            end
        elseif (char == 104 or char == 72) and count > 0 then
            help.enter(MIXER_FX_SHORTCUTS, function() announce_fx(false) end)
        elseif char == 97 or char == 65 then
            state = STATE_MIXER_FX_ADD
            announce_fx_add(true)
        elseif char == 119 or char == 87 then
            if count > 0 then
                TrackFX_Show(track, mc_fx_idx - 1, 1)
                say("Opened FX window")
                return false
            else
                say("No FX to show")
            end
        elseif char == 112 or char == 80 then
            if count > 0 then
                init_mc_fx_param_list()
                if #mc_fx_param_list == 0 then
                    say("No parameters")
                else
                    mc_fx_param_idx = 1
                    state = STATE_MIXER_FX_PARAM
                    announce_mc_fx_param(true)
                end
            else
                say("No FX to edit parameters for")
            end
        elseif char == 48 then
            if count > 0 then
                local _, fx_name = TrackFX_GetFXName(track, mc_fx_idx - 1, "")
                if TrackFX_SetPresetByIndex(track, mc_fx_idx - 1, -2) then
                    say(fx_name .. " reset to factory default")
                else
                    say(fx_name .. " has no factory default")
                end
            else
                say("No FX to reset")
            end
        elseif char == KEY_BACK then
            if count > 0 then
                TrackFX_Delete(track, mc_fx_idx - 1)
                announce_fx(false)
            end
        elseif char == KEY_LEFT or char == KEY_RIGHT then
            if count > 1 then
                local new_idx = char == KEY_LEFT and mc_fx_idx - 1 or mc_fx_idx + 1
                new_idx = clamp(new_idx, 1, count)
                if new_idx ~= mc_fx_idx then
                    local chain_open = TrackFX_GetChainVisible(track) >= 0
                    TrackFX_CopyToTrack(track, mc_fx_idx - 1, track, new_idx - 1, true)
                    mc_fx_idx = new_idx
                    if not chain_open then
                        announce_fx_moved()
                    elseif try_refocus() then
                        announce_fx_moved()
                    else
                        say("Closing.")
                        return false
                    end
                else
                    announce_fx(false)
                end
            end
        elseif char == KEY_ESC then
            if mm_direct_entry then return false end
            state = STATE_MIXER_CONTROL
            announce_mixer_control(false)
        end
    elseif state == STATE_MIXER_FX_ADD then
        if char == KEY_ENTER then
            while true do
                local ok, entered = ask_text(WINDOW_TITLE, "Add FX", "")
                if not ok then
                    say("Cancelled")
                    break
                end
                local name = track_rename.trim(entered)
                if name == "" then
                    say("Please enter a name")
                else
                    local matches = search_installed_fx(name)
                    if #matches == 0 then
                        say("No FX found matching: " .. name)
                    elseif #matches == 1 then
                        local track = mc_fx_source.track
                        TrackFX_AddByName(track, matches[1].ident, false, -1)
                        mc_fx_idx = TrackFX_GetCount(track)
                        say("Added: " .. matches[1].name)
                        state = STATE_MIXER_FX
                        announce_fx(false)
                        break
                    else
                        mc_fx_pick_list = matches
                        mc_fx_pick_idx = 1
                        mc_fx_pick_query = name
                        state = STATE_MIXER_FX_PICK
                        announce_fx_pick(true)
                        break
                    end
                end
            end
        elseif char == KEY_ESC then
            state = STATE_MIXER_FX
            announce_fx(false)
        end
    elseif state == STATE_MIXER_FX_PICK then
        if char == KEY_UP then
            mc_fx_pick_idx = mc_fx_pick_idx > 1 and mc_fx_pick_idx - 1 or #mc_fx_pick_list
            announce_fx_pick(false)
        elseif char == KEY_DOWN then
            mc_fx_pick_idx = mc_fx_pick_idx < #mc_fx_pick_list and mc_fx_pick_idx + 1 or 1
            announce_fx_pick(false)
        elseif char == KEY_ENTER then
            local pick = mc_fx_pick_list[mc_fx_pick_idx]
            local track = mc_fx_source.track
            TrackFX_AddByName(track, pick.ident, false, -1)
            mc_fx_idx = TrackFX_GetCount(track)
            say("Added: " .. pick.name)
            state = STATE_MIXER_FX
            announce_fx(false)
        elseif char == KEY_ESC then
            state = STATE_MIXER_FX_ADD
            announce_fx_add(false)
        end
    elseif state == STATE_MIXER_FX_PARAM then
        if transport.handle_transport_key(char) then
        elseif char == KEY_UP then
            mc_fx_param_idx = mc_fx_param_idx > 1 and mc_fx_param_idx - 1 or #mc_fx_param_list
            announce_mc_fx_param(false)
        elseif char == KEY_DOWN then
            mc_fx_param_idx = mc_fx_param_idx < #mc_fx_param_list and mc_fx_param_idx + 1 or 1
            announce_mc_fx_param(false)
        elseif char == KEY_ENTER then
            local track = mc_fx_source.track
            local fx_raw = mc_fx_idx - 1
            local param = mc_fx_param_list[mc_fx_param_idx]
            mc_fx_range = au.classify_fx_range(track, fx_raw, param.raw_idx)
            state = STATE_MIXER_FX_VALUE
            say(au.fx_value_prompt(param.name, mc_fx_range)
                .. ". Enter to type a specific value, or Up and Down to nudge, "
                .. "Shift for a finer step")
        elseif char == KEY_ESC then
            state = STATE_MIXER_FX
            announce_fx(false)
        end
    elseif state == STATE_MIXER_FX_VALUE then
        local track = mc_fx_source.track
        local fx_raw = mc_fx_idx - 1
        local param = mc_fx_param_list[mc_fx_param_idx]

        if transport.handle_transport_key(char) then
        elseif char == KEY_UP or char == KEY_DOWN then
            local range = mc_fx_range.maxval - mc_fx_range.minval
            local has_steps, param_step = TrackFX_GetParameterStepSizes(track, fx_raw, param.raw_idx)
            local nsteps = (has_steps and param_step and param_step > 0) and (range / param_step) or nil

            local is_enum = nsteps and nsteps <= MC_FX_ENUM_STEP_LIMIT
            local step
            if is_enum then
                step = param_step
            else
                local shift_held = gfx.mouse_cap & 8 == 8
                step = shift_held and (range * 0.01) or (range * 0.05)
            end
            if char == KEY_DOWN then step = -step end
            local cur = TrackFX_GetParam(track, fx_raw, param.raw_idx)
            local new_val = cur + step
            if is_enum then
                local half_step = param_step * 0.5
                if new_val > mc_fx_range.maxval + half_step then
                    new_val = mc_fx_range.minval
                elseif new_val < mc_fx_range.minval - half_step then
                    new_val = mc_fx_range.minval
                else
                    new_val = clamp(new_val, mc_fx_range.minval, mc_fx_range.maxval)
                end
            else
                new_val = clamp(new_val, mc_fx_range.minval, mc_fx_range.maxval)
            end
            TrackFX_SetParam(track, fx_raw, param.raw_idx, new_val)
            local _, fmt = TrackFX_GetFormattedParamValue(track, fx_raw, param.raw_idx, "")
            say(fmt)
        elseif char == KEY_ENTER then
            while true do
                local ok, entered = ui_input.ask(WINDOW_TITLE,
                    param.name .. " - Value",
                    au.fx_value_prompt(param.name, mc_fx_range), "")
                if not ok then
                    say("Cancelled")
                    break
                end
                local word = entered:lower()
                local matched_t
                if mc_fx_range.low_label and word == mc_fx_range.low_label:lower() then
                    matched_t = mc_fx_range.low_t
                elseif mc_fx_range.high_label and word == mc_fx_range.high_label:lower() then
                    matched_t = mc_fx_range.high_t
                end

                if matched_t then
                    TrackFX_SetParam(track, fx_raw, param.raw_idx, matched_t)
                    local _, confirm_str = TrackFX_GetFormattedParamValue(track, fx_raw, param.raw_idx, "")
                    say(string.format("%s set to %s", param.name, confirm_str))
                    state = STATE_MIXER_FX_PARAM
                    announce_mc_fx_param(false)
                    break
                end

                local num = tonumber(entered)
                if not num then
                    say("Please enter a number")
                else
                    local raw_val = au.find_fx_raw_for_display(track, fx_raw, param.raw_idx, num)
                    TrackFX_SetParam(track, fx_raw, param.raw_idx, raw_val)
                    local _, confirm_str = TrackFX_GetFormattedParamValue(track, fx_raw, param.raw_idx, "")
                    say(string.format("%s set to %s", param.name, confirm_str))
                    state = STATE_MIXER_FX_PARAM
                    announce_mc_fx_param(false)
                    break
                end
            end
        elseif char == KEY_ESC then
            state = STATE_MIXER_FX_PARAM
            announce_mc_fx_param(false)
        end
    elseif state == STATE_SET_INPUTS_MENU then
        if char == KEY_UP or char == KEY_DOWN then
            si_menu_idx = si_menu_idx == 1 and 2 or 1
            say(SET_INPUTS_ITEMS[si_menu_idx])
        elseif char == KEY_ENTER then
            if si_menu_idx == 1 then
                local ok, entered = ui_input.ask(WINDOW_TITLE,
                    "Auto Assign HW Inputs", "Starting hardware input, blank for 1", "")
                if not ok then
                    say("Cancelled")
                    return true
                end
                run_terminal_command(entered == "" and "ai" or ("ai=" .. entered))
                mark_inputs_configured()
                menu_idx = menu_index_of("Mixer Control")
                state = STATE_MENU
                say(MENU_ITEMS[menu_idx])
                return true
            else
                refresh_mixer_tracks()
                if #mixer_tracks == 0 then
                    say("No mixer tracks found")
                    return true
                end
                si_position = 1
                state = STATE_SET_INPUTS_MANUAL
                announce_manual_input(true)
            end
        elseif char == KEY_ESC then
            state = STATE_MENU
            say(MENU_ITEMS[menu_idx])
        end
    elseif state == STATE_SET_INPUTS_MANUAL then
        local track = mixer_tracks[si_position]
        if char == KEY_UP then
            si_position = si_position > 1 and si_position - 1 or #mixer_tracks
            announce_manual_input(false)
        elseif char == KEY_DOWN then
            si_position = si_position < #mixer_tracks and si_position + 1 or 1
            announce_manual_input(false)
        elseif char == KEY_ENTER then
            announce_manual_input(false)
        elseif char == 104 or char == 72 then
            help.enter(SET_INPUTS_MANUAL_SHORTCUTS, function() announce_manual_input(false) end)
        elseif char == 109 or char == 77 then
            local entered = ask_number_required(WINDOW_TITLE,
                "Mono Input", "Please enter a hardware input number")
            if entered then
                run_terminal_command(si_position .. "=mono," .. entered)
                mark_inputs_configured()
            else
                say("Cancelled")
            end
            announce_manual_input(false)
        elseif char == 115 or char == 83 then
            local entered = ask_number_required(WINDOW_TITLE,
                "Stereo Input Start", "Please enter the starting hardware input number")
            if entered then
                run_terminal_command(si_position .. "=stereo," .. entered)
                mark_inputs_configured()
            else
                say("Cancelled")
            end
            announce_manual_input(false)
        elseif char == 114 or char == 82 then
            run_terminal_command(si_position .. "=" .. (input_record_enabled(track) and "n" or "y"))
            mark_inputs_configured()
        elseif char == KEY_ESC then
            state = STATE_SET_INPUTS_MENU
            say(SET_INPUTS_ITEMS[si_menu_idx])
        end
    end

    return true
end

local function status_line()
    if state == STATE_MENU then
        return "[Track Setup]  " .. MENU_ITEMS[menu_idx]
    elseif state == STATE_OTHER_MENU then
        return "[Other Commands]  " .. OTHER_MENU_ITEMS[other_menu_idx]
    elseif state == STATE_TRACK_NAME then
        local track = mixer_tracks[tn_position]
        local name = track and track_rename.get_mixer_base_name(track) or ""
        return string.format("[Track %d/%d]  %s", tn_position, #mixer_tracks, name)
    elseif state == STATE_ADD_TRACK then
        return "[Add Track]"
    elseif state == STATE_REMOVE_TRACK then
        local track = mixer_tracks[rem_position]
        local name = track and track_rename.get_mixer_base_name(track) or ""
        return string.format("[Remove Track %d/%d]  %s", rem_position, #mixer_tracks, name)
    elseif state == STATE_REORDER_TRACK then
        local track = mixer_tracks[reorder_position]
        local name = track and track_rename.get_mixer_base_name(track) or ""
        local prefix = reorder_picked_up and "Picked Up" or "Reorder Track"
        return string.format("[%s %d/%d]  %s", prefix, reorder_position, #mixer_tracks, name)
    elseif state == STATE_REORDER_SPECIAL then
        local info = rs_list[rs_position]
        local prefix = rs_picked_up and "Picked Up" or "Reorder Aux/Submix"
        return string.format("[%s %d/%d]  %s", prefix, rs_position, #rs_list, info and rs_label(info) or "")
    elseif state == STATE_SPECIAL_TYPE then
        return "[Special Track Naming]  " .. SPECIAL_TYPES[special_type_idx].label
    elseif state == STATE_SPECIAL_INDEX then
        local type_label = SPECIAL_TYPES[special_type_idx].label
        local info = special_list[special_idx]
        return string.format("[%s %d/%d]  %s", type_label, special_idx, #special_list,
            info and info.name or "")
    elseif state == STATE_ADD_SPECIAL_TYPE then
        return "[Add Special Track]  " .. ADD_REMOVE_TYPES[addrm_type_idx].label
    elseif state == STATE_ADD_SPECIAL_PARAM then
        return "[Add " .. ADD_REMOVE_TYPES[addrm_type_idx].label .. "]  " .. add_special_str
    elseif state == STATE_REMOVE_SPECIAL_TYPE then
        return "[Remove Special Track]  " .. ADD_REMOVE_TYPES[addrm_type_idx].label
    elseif state == STATE_REMOVE_SPECIAL_INDEX then
        local info = rmspecial_list[rmspecial_idx]
        return string.format("[Remove %s %d/%d]  %s", ADD_REMOVE_TYPES[addrm_type_idx].label,
            rmspecial_idx, #rmspecial_list, info and info.name or "")
    elseif state == STATE_MIXER_CONTROL then
        local entry = mc_tracks[mc_position]
        return string.format("[Mixer Control %d/%d]  %s", mc_position, #mc_tracks,
            entry and mc_display(entry) or "")
    elseif state == STATE_MIXER_ROUTING then
        local dest = mc_routing_list[mc_routing_idx]
        local connected = is_dest_connected(mc_routing_source.track, dest)
        return string.format("[Routing %s]  %s: %s", mc_display(mc_routing_source),
            dest.label, connected and "connected" or "not connected")
    elseif state == STATE_MIXER_HW_OUTPUT then
        local entry = mc_tracks[mc_position]
        return string.format("[HW Output %s]  %s", entry and mc_display(entry) or "",
            entry and hw_output_status_text(entry.track) or "")
    elseif state == STATE_MIXER_FX then
        local track = mc_fx_source.track
        local count = TrackFX_GetCount(track)
        if count == 0 then
            return "[FX " .. mc_display(mc_fx_source) .. "]  No FX"
        end
        local _, fx_name = TrackFX_GetFXName(track, mc_fx_idx - 1, "")
        local enabled = TrackFX_GetEnabled(track, mc_fx_idx - 1)
        return string.format("[FX %s %d/%d]  %s (%s)", mc_display(mc_fx_source), mc_fx_idx, count,
            fx_name, enabled and "on" or "off")
    elseif state == STATE_MIXER_FX_ADD then
        return "[Add FX " .. mc_display(mc_fx_source) .. "]"
    elseif state == STATE_MIXER_FX_PICK then
        local pick = mc_fx_pick_list[mc_fx_pick_idx]
        return string.format("[FX matches %d/%d]  %s", mc_fx_pick_idx, #mc_fx_pick_list, pick and pick.name or "")
    elseif state == STATE_MIXER_FX_PARAM then
        local track = mc_fx_source.track
        local fx_raw = mc_fx_idx - 1
        local param = mc_fx_param_list[mc_fx_param_idx]
        local _, current = TrackFX_GetFormattedParamValue(track, fx_raw, param.raw_idx, "")
        return string.format("[FX Params %d/%d]  %s = %s", mc_fx_param_idx, #mc_fx_param_list,
            param.name, current)
    elseif state == STATE_MIXER_FX_VALUE then
        local param = mc_fx_param_list[mc_fx_param_idx]
        return "[Set " .. param.name .. "]"
    elseif state == STATE_SET_INPUTS_MENU then
        return "[Set Inputs]  " .. SET_INPUTS_ITEMS[si_menu_idx]
    elseif state == STATE_SET_INPUTS_MANUAL then
        local track = mixer_tracks[si_position]
        local name = track and track_rename.get_mixer_base_name(track) or ""
        return string.format("[Manual Inputs %d/%d]  %s", si_position, #mixer_tracks, name)
    elseif state == STATE_CONVERT_CONFIRM then
        local target = workflow == "Horizontal" and "Vertical" or "Horizontal"
        return "[Convert Workflow]  Convert to " .. target .. "?"
    elseif state == STATE_HW_AUTO then
        return "[Auto HW Output Start]  1"
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
    if not gui_mode.accessible() then
        gfx.quit()
        gui_mode.switch_window("ReaClassical_Mission Control.lua")
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

local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
if wf == "" then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier
        .. "+N to use this function.", "ReaClassical Error", 0)
    return
end
workflow = wf

if _G.RC_MM_TARGET then
    local target_track = _G.RC_MM_TARGET.track
    local target_action = _G.RC_MM_TARGET.action or "fx"
    _G.RC_MM_TARGET = nil
    mm_direct_entry = true
    refresh_mc_tracks()
    local found_idx = nil
    for i, e in ipairs(mc_tracks) do
        if e.track == target_track then found_idx = i break end
    end
    if not found_idx then
        MB("Could not resolve the target track for Mixer Mode.", "ReaClassical Error", 0)
        return
    end
    mc_position = found_idx
    local entry = mc_tracks[found_idx]

    if target_action == "routing" then
        if not MC_ROUTABLE_TYPES[entry.type] then
            MB("No routing available for this track type.", "ReaClassical Error", 0)
            return
        end
        mc_routing_source = entry
        mc_routing_list = build_routing_destinations(entry)
        mc_routing_idx = 1
        state = STATE_MIXER_ROUTING
        gfx.init(WINDOW_TITLE, 500, 44, 0)
        try_refocus()
        announce_routing(true)
    else
        mc_fx_source = entry
        mc_fx_idx = 1
        state = STATE_MIXER_FX
        gfx.init(WINDOW_TITLE, 500, 44, 0)
        try_refocus()
        announce_fx(true)
    end
    defer(main)
    return
end

refresh_mixer_tracks()
local any_named = false
for _, track in ipairs(mixer_tracks) do
    if track_rename.get_mixer_base_name(track) ~= "" then
        any_named = true
        break
    end
end

if any_named then
    local _, inputs_configured = GetProjExtState(0, "ReaClassical", "InputsConfigured")
    menu_idx = inputs_configured == "y" and menu_index_of("Mixer Control") or menu_index_of("Set Inputs")
end

gfx.init(WINDOW_TITLE, 500, 44, 0)
try_refocus()

if not any_named and #mixer_tracks > 0 then
    tn_position = 1
    state = STATE_TRACK_NAME
    announce_track_name(true)
    run_track_rename_chain()
else
    say("Track Setup. " .. MENU_ITEMS[menu_idx] .. ". Up or down for other options, Enter to select, Escape to close.")
end

defer(main)
