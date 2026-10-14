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
local say = require("ReaClassical_Announce")
local au  = require("ReaClassical_Automation_Info")
local mm  = require("ReaClassical_MM_Utils")
local mmg = require("ReaClassical_MM_Groups")
local transport = require("ReaClassical_Transport_Utils")
local help = require("ReaClassical_Accessible_Help")
local ui_input = require("ReaClassical_Accessible_Input")
local special_track_nav = require("ReaClassical_Special_Track_Nav")
local automation_ownership = require("ReaClassical_Automation_Ownership")
local automation_mode = require("ReaClassical_Automation_Mode")

if not APIExists("CF_GetSWSVersion") then
    MB("Edit Automation requires the SWS extension to be installed.", "ReaClassical Error", 0)
    return
end

set_action_options(3)

local WINDOW_TITLE = "Edit Automation"

local db_to_linear     = au.db_to_linear
local linear_to_db     = au.linear_to_db
local is_special_track = au.is_automation_track
local find_env_info    = au.find_env_info
local is_vol_env       = au.is_vol_env
local raw_to_display   = au.raw_to_display
local format_display   = au.format_display
local get_track_label  = au.get_track_label
local get_mixer_target = au.get_mixer_target

local function speech_value(env_info, dval)
    return (format_display(env_info, dval):gsub("^%-", "minus "))
end

local STATE_PICK = "pick"
local STATE_EDIT = "edit"

local MODE_BOTH  = "both"
local MODE_LEFT  = "left"
local MODE_RIGHT = "right"
local MODE_P1    = "p1"
local MODE_P2    = "p2"
local MODE_P3    = "p3"
local MODE_P4    = "p4"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_LEFT  = 1818584692
local KEY_RIGHT = 1919379572
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_BACK  = 8

local KEY_PLUS_FINE    = 61
local KEY_PLUS_COARSE  = 43
local KEY_MINUS_FINE   = 45
local KEY_MINUS_COARSE = 95

local state     = STATE_PICK
local found     = {}
local pick_idx  = 1
local item      = nil
local last_char = 0

local function same_param(a, b)
    if a.type ~= b.type then return false end
    if a.type == "track" then return a.name == b.name end
    return a.fx_name == b.fx_name and a.name == b.name
end

local function anchor_track(entry)
    if mm.is_special_track(entry.track) then return entry.track end
    return get_mixer_target(entry.track)
end

local function find_group_siblings(entry)
    local anchor = anchor_track(entry)
    if not anchor then return {}, nil end
    local targets, grouped, group_name = mmg.get_action_targets(anchor, "automation")
    if not grouped then return {}, nil end
    local target_set = {}
    for _, t in ipairs(targets) do target_set[t] = true end

    local siblings = {}
    for _, other in ipairs(found) do
        if other ~= entry and same_param(other.env_info, entry.env_info) then
            local other_anchor = anchor_track(other)
            if other_anchor and other_anchor ~= anchor and target_set[other_anchor] then
                siblings[#siblings + 1] = other
            end
        end
    end
    return siblings, group_name
end

local function ms_phrase(ms)
    if ms >= 1000 then
        local secs = string.format("%.2f", ms / 1000):gsub("0+$", ""):gsub("%.$", "")
        return secs .. " seconds"
    end
    return ms .. " milliseconds"
end

local edit_mode  = MODE_BOTH
local edit_value = 0
local p1, p2, p3, p4 = 0, 0, 0, 0

local EDIT_HINT = ". Editing. Enter to type a specific value, or Up or down to nudge. H for shortcuts, Escape to stop."

local function edit_shortcuts()
    return {
        { key = "Enter", desc = "Type a specific value in an input box" },
        { key = "Up or Down", desc = "Nudge the value (Shift for a finer step)" },
        { key = "1, 2, 3, or 4", desc = "Select one point: ramp-in start, ramp-in end, "
            .. "ramp-out start, or ramp-out end" },
        { key = "A, S, or D", desc = "Select both edges, the ramp-in edge, or the ramp-out edge" },
        { key = "+ or -", desc = "Nudge the current selection right or left "
            .. "(Shift for a bigger step)" },
        { key = "+ or - with a point (1-4) selected", desc = "Move that point alone, "
            .. "clamped to its neighboring point" },
        { key = "+ or - with S or D selected", desc = "Shift that whole ramp left or right, "
            .. "keeping its length" },
        { key = "+ or - with A selected", desc = "Grow or shrink the plateau, pushing both "
            .. "ramps outward or pulling them inward together" },
        { key = "Left or Right arrow", desc = "Move the whole item (Shift for a bigger step)" },
        { key = "0", desc = "Reset to how this item looked when editing began" },
        { key = "Backspace", desc = "Delete this item" },
        { key = "Escape", desc = "Stop editing" },
    }
end

local function display_to_raw(env_info, display)
    if env_info.type == "track" then
        local n = env_info.name
        if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
            return db_to_linear(display)
        elseif n == "Pan" or n == "Pan (Pre-FX)" then
            return -(display / 100)
        elseif n == "Width" or n == "Width (Pre-FX)" then
            return display / 100
        end
    end
    return display
end

local function get_range_info(env_info, track)
    if env_info.type == "track" then
        local n = env_info.name
        if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
            return -150, 12, "dB"
        elseif n == "Pan" or n == "Pan (Pre-FX)" then
            return -100, 100, "L=-100 to R=+100"
        elseif n == "Width" or n == "Width (Pre-FX)" then
            return -100, 100, "-100 to +100"
        elseif n == "Mute" then
            return 0, 1, "0=muted 1=unmuted"
        end
        return 0, 1, ""
    else
        local _, lo, hi = TrackFX_GetParam(track, env_info.fx_idx, env_info.param_idx)
        if lo > hi then lo, hi = hi, lo end
        return lo, hi, ""
    end
end

local function get_boundary_raw(br_env, track, env_info)
    return function(t)
        local v = BR_EnvValueAtPos(br_env, t)
        if v then return v end
        if env_info.type == "track" then
            local n = env_info.name
            if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
                return GetMediaTrackInfo_Value(track, "D_VOL")
            elseif n == "Pan" or n == "Pan (Pre-FX)" then
                return GetMediaTrackInfo_Value(track, "D_PAN")
            elseif n == "Width" or n == "Width (Pre-FX)" then
                return GetMediaTrackInfo_Value(track, "D_WIDTH")
            elseif n == "Mute" then
                return 1 - GetMediaTrackInfo_Value(track, "B_MUTE")
            end
            return 1.0
        else
            return TrackFX_GetParam(track, env_info.fx_idx, env_info.param_idx)
        end
    end
end

local function detect_ramps(env, ai_idx, ai_pos, ai_len, raw_mid, env_info)
    local count = CountEnvelopePointsEx(env, ai_idx)
    if count < 2 then return 0, 0 end

    local pts = {}
    for i = 0, count - 1 do
        local _, t, v = GetEnvelopePointEx(env, ai_idx, i)
        local rel_t = t - ai_pos
        if is_vol_env(env_info) then
            v = ScaleFromEnvelopeMode(1, v)
        end
        table.insert(pts, { t = rel_t, v = v })
    end
    table.sort(pts, function(a, b) return a.t < b.t end)

    local tol = 0.001
    local t_first, t_last
    for _, pt in ipairs(pts) do
        if math.abs(pt.v - raw_mid) < tol then
            if not t_first then t_first = pt.t end
            t_last = pt.t
        end
    end

    return math.max(0, t_first or 0),
           math.max(0, t_last and (ai_len - t_last) or 0)
end

local function time_nudge_amount(bigger)
    local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
    local base = (tonumber(stored) or 5) / 1000
    if not bigger then return base end
    local _, factor = GetProjExtState(0, "ReaClassical", "ModifierFactor")
    return base * (tonumber(factor) or 5)
end

local function nudge_step(coarse)
    if item.env_info.type == "track" then
        local n = item.env_info.name
        if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
            return coarse and 1.0 or 0.2
        end
        return coarse and 5.0 or 1.0
    end
    local range = item.disp_max - item.disp_min
    return coarse and (range * 0.05) or (range * 0.01)
end

local function scan()
    found   = {}
    local cursor = GetCursorPosition()

    for ti = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, ti)
        if is_special_track(t) then
            local envs = {}
            for ei = 0, CountTrackEnvelopes(t) - 1 do
                table.insert(envs, GetTrackEnvelope(t, ei))
            end
            for fx = 0, TrackFX_GetCount(t) - 1 do
                for p = 0, TrackFX_GetNumParams(t, fx) - 1 do
                    local fxe = GetFXEnvelope(t, fx, p, false)
                    if fxe then table.insert(envs, fxe) end
                end
            end

            for _, env in ipairs(envs) do
                for ai = 0, CountAutomationItems(env) - 1 do
                    local pos = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
                    local len = GetSetAutomationItemInfo(env, ai, "D_LENGTH",   0, false)
                    if cursor >= pos and cursor < pos + len then
                        local env_info = find_env_info(t, env)
                        if env_info then
                            local br = BR_EnvAlloc(env, false)
                            local get_bv = get_boundary_raw(br, t, env_info)
                            local raw_mid    = BR_EnvValueAtPos(br, pos + len / 2)
                            local orig_before = get_bv(pos - 0.001)
                            local orig_after  = get_bv(pos + len + 0.001)
                            BR_EnvFree(br, false)

                            if raw_mid then
                                local ri, ro = detect_ramps(env, ai, pos, len, raw_mid, env_info)
                                local dval = raw_to_display(env_info, raw_mid)
                                local lo, hi, unit = get_range_info(env_info, t)
                                local track_label = get_track_label(t)
                                local param_label = env_info.type == "track"
                                    and env_info.name
                                    or  (env_info.fx_name .. ": " .. env_info.name)
                                table.insert(found, {
                                    label       = param_label .. " on " .. track_label,
                                    track       = t,
                                    env         = env,
                                    ai_idx      = ai,
                                    env_info    = env_info,
                                    display_val = dval,
                                    disp_min    = lo,
                                    disp_max    = hi,
                                    unit        = unit,
                                    ramp_in     = ri,
                                    ramp_out    = ro,
                                    orig_before = orig_before,
                                    orig_after  = orig_after,
                                    ai_pos      = pos,
                                    ai_len      = len,
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

local function deselect_all_automation_items()
    for ti = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, ti)
        for ei = 0, CountTrackEnvelopes(t) - 1 do
            local e = GetTrackEnvelope(t, ei)
            for ai = 0, CountAutomationItems(e) - 1 do
                GetSetAutomationItemInfo(e, ai, "D_UISEL", 0, true)
            end
        end
    end
end

local function delete_by_position(env, lo, hi)
    local any = false
    for ai = 0, CountAutomationItems(env) - 1 do
        local p = GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
        local l = GetSetAutomationItemInfo(env, ai, "D_LENGTH",   0, false)
        local overlaps = p < hi and (p + l) > lo
        GetSetAutomationItemInfo(env, ai, "D_UISEL", overlaps and 1 or 0, true)
        if overlaps then any = true end
    end
    if any then Main_OnCommand(42086, 0) end
end

local function delete_current(entries, label)
    Undo_BeginBlock()
    deselect_all_automation_items()
    for _, e in ipairs(entries) do
        local pos = e.live_pos or e.ai_pos
        local len = e.live_len or e.ai_len
        delete_by_position(e.env, pos - 0.005, pos + len + 0.005)
    end
    UpdateArrange()
    Undo_EndBlock("Delete Automation Item", -1)
    say("Deleted " .. label)
end

local function render()
    local ei = item.env_info
    local scale = is_vol_env(ei)
    local is_mute = ei.type == "track" and ei.name == "Mute"
    local delta = edit_value - item.display_val

    local new_pos = p1
    local new_len = p4 - p1

    local entries = { item }
    for _, sib in ipairs(item.siblings or {}) do entries[#entries + 1] = sib end

    PreventUIRefresh(1)
    for _, entry in ipairs(entries) do
        local env   = entry.env
        local track = entry.track

        local entry_display = is_mute and edit_value
            or math.max(entry.disp_min, math.min(entry.disp_max, entry.display_val + delta))
        local target_raw = display_to_raw(ei, entry_display)
        local tgt = scale and ScaleToEnvelopeMode(1, target_raw) or target_raw
        local b = scale and ScaleToEnvelopeMode(1, entry.orig_before) or entry.orig_before
        local a = scale and ScaleToEnvelopeMode(1, entry.orig_after)  or entry.orig_after

        local prev_pos = entry.live_pos or entry.ai_pos
        local prev_len = entry.live_len or entry.ai_len
        local lo = math.min(prev_pos, new_pos) - 0.005
        local hi = math.max(prev_pos + prev_len, new_pos + new_len) + 0.005

        deselect_all_automation_items()
        delete_by_position(env, lo, hi)
        DeleteEnvelopePointRange(env, lo, hi)

        if p2 - p1 > 0.0005 then
            InsertEnvelopePoint(env, p1, b,   0, 0, false, true)
            InsertEnvelopePoint(env, p2, tgt, 0, 0, false, true)
        else
            local before_point = p2 - 0.001
            if before_point >= 0 then
                InsertEnvelopePoint(env, before_point, b,   0, 0, false, true)
            end
            InsertEnvelopePoint(env, p2,          tgt, 0, 0, false, true)
        end

        if p4 - p3 > 0.0005 then
            InsertEnvelopePoint(env, p3, tgt, 0, 0, false, true)
            InsertEnvelopePoint(env, p4, a,   0, 0, false, true)
        else
            InsertEnvelopePoint(env, p3,          tgt, 0, 0, false, true)
            InsertEnvelopePoint(env, p4 + 0.001,  a,   0, 0, false, true)
        end

        Envelope_SortPoints(env)
        local ai_idx = InsertAutomationItem(env, -1, new_pos, new_len)
        if special_track_nav.is_special_track(track) then
            automation_ownership.mark_user_ai(env, ai_idx)
        end
        automation_mode.ensure_engaged()

        entry.live_pos, entry.live_len = new_pos, new_len

        SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
        local _, ms   = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
        local mc_key  = (ms == "y") and ("mixer_tcp_visible_" .. guid) or ("tcp_visible_" .. guid)
        SetProjExtState(0, "ReaClassical_MissionControl", mc_key, "1")
    end

    TrackList_AdjustWindows(false)
    UpdateArrange()
    PreventUIRefresh(-1)
end

local function compute_points_from_item()
    edit_value = item.display_val
    p1 = item.ai_pos
    p2 = item.ai_pos + item.ramp_in
    p3 = item.ai_pos + item.ai_len - item.ramp_out
    p4 = item.ai_pos + item.ai_len
end

local function enter_edit_mode(found_entry)
    item      = found_entry
    edit_mode = MODE_BOTH
    compute_points_from_item()
    item.live_pos, item.live_len = item.ai_pos, item.ai_len
    item.siblings, item.group_name = find_group_siblings(item)
    for _, sib in ipairs(item.siblings) do
        sib.live_pos, sib.live_len = sib.ai_pos, sib.ai_len
    end
    state = STATE_EDIT
end

local function group_suffix()
    return item.group_name and (", " .. item.group_name .. " group") or ""
end

local function reset_to_original()
    compute_points_from_item()
    render()
    say("Reset to original: " .. speech_value(item.env_info, edit_value) .. group_suffix())
end

local function nudge_value(char)
    local ei = item.env_info
    local is_mute = ei.type == "track" and ei.name == "Mute"
    if is_mute then
        edit_value = edit_value >= 0.5 and 0 or 1
    else
        local coarse = (gfx.mouse_cap & 8) ~= 8
        local step = nudge_step(coarse)
        if char == KEY_DOWN then step = -step end
        edit_value = math.max(item.disp_min, math.min(item.disp_max, edit_value + step))
    end
    render()
    say(speech_value(ei, edit_value) .. group_suffix())
end

local function move_whole_item(delta)
    if p1 + delta < 0 then delta = -p1 end
    p1, p2, p3, p4 = p1 + delta, p2 + delta, p3 + delta, p4 + delta
    render()
    local ms = math.floor(math.abs(delta) * 1000 + 0.5)
    say(string.format("Item moved %s by %s", delta >= 0 and "right" or "left", ms_phrase(ms)))
end

local function announce_ramp_in()
    say("Ramp in " .. ms_phrase(math.floor((p2 - p1) * 1000 + 0.5)))
end

local function announce_ramp_out()
    say("Ramp out " .. ms_phrase(math.floor((p4 - p3) * 1000 + 0.5)))
end

local function adjust_point(which, dir, amt)
    local delta = dir * amt
    if which == MODE_P1 then
        p1 = math.max(0, math.min(p2, p1 + delta))
        render()
        announce_ramp_in()
    elseif which == MODE_P2 then
        p2 = math.max(p1, math.min(p3, p2 + delta))
        render()
        announce_ramp_in()
    elseif which == MODE_P3 then
        p3 = math.max(p2, math.min(p4, p3 + delta))
        render()
        announce_ramp_out()
    elseif which == MODE_P4 then
        p4 = math.max(p3, p4 + delta)
        render()
        announce_ramp_out()
    end
end

local function shift_ramp_in(dir, amt)
    if dir > 0 then
        amt = math.min(amt, p3 - p2)
    else
        amt = math.min(amt, p1)
    end
    local delta = dir * amt
    p1, p2 = p1 + delta, p2 + delta
    render()
    local ms = math.floor((p1 - item.ai_pos) * 1000 + 0.5)
    if ms == 0 then
        say("Ramp in back at its original start position")
    else
        say(string.format("Ramp in starts %s %s its original position",
            ms_phrase(math.abs(ms)), ms > 0 and "after" or "before"))
    end
end

local function shift_ramp_out(dir, amt)
    if dir < 0 then
        amt = math.min(amt, p3 - p2)
    end
    local delta = dir * amt
    p3, p4 = p3 + delta, p4 + delta
    render()
    local ms = math.floor((p4 - (item.ai_pos + item.ai_len)) * 1000 + 0.5)
    if ms == 0 then
        say("Ramp out back at its original end position")
    else
        say(string.format("Ramp out ends %s %s its original position",
            ms_phrase(math.abs(ms)), ms > 0 and "after" or "before"))
    end
end

local function adjust_plateau(dir, amt)
    if dir > 0 then
        amt = math.min(amt, p1)
    else
        amt = math.min(amt, (p3 - p2) / 2)
    end
    local shift = dir * amt
    p1, p2 = p1 - shift, p2 - shift
    p3, p4 = p3 + shift, p4 + shift
    render()
    say("Plateau: " .. ms_phrase(math.floor((p3 - p2) * 1000 + 0.5)))
end

local MODE_LABELS = {
    [MODE_BOTH]  = "Both",
    [MODE_LEFT]  = "Left",
    [MODE_RIGHT] = "Right",
    [MODE_P1]    = "Ramp in start",
    [MODE_P2]    = "Ramp in end",
    [MODE_P3]    = "Ramp out start",
    [MODE_P4]    = "Ramp out end",
}

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_PICK then
        gfx.drawstr(#found == 0 and "No automation items at cursor"
                                  or "[Select]  " .. found[pick_idx].label)
    elseif state == STATE_EDIT then
        gfx.drawstr(string.format("[Editing]  %s = %s  |  Ramp in %dms  Ramp out %dms  |  Selection: %s",
            item.label, format_display(item.env_info, edit_value),
            math.floor((p2 - p1) * 1000 + 0.5), math.floor((p4 - p3) * 1000 + 0.5), MODE_LABELS[edit_mode]))
    end
    gfx.update()
end

local function handle_key(char)
    if state == STATE_PICK then
        if #found == 0 then
            if char == KEY_ESC or char == KEY_ENTER then return false end
            return true
        end
        if transport.handle_transport_key(char) then
        elseif char == KEY_UP then
            pick_idx = pick_idx > 1 and pick_idx - 1 or #found
            say(found[pick_idx].label)
        elseif char == KEY_DOWN then
            pick_idx = pick_idx < #found and pick_idx + 1 or 1
            say(found[pick_idx].label)
        elseif char == KEY_ENTER then
            local target = found[pick_idx]
            enter_edit_mode(target)
            say(target.label .. group_suffix() .. EDIT_HINT)
        elseif char == KEY_BACK then
            local target = found[pick_idx]
            local siblings, group_name = find_group_siblings(target)
            local entries = { target }
            for _, s in ipairs(siblings) do entries[#entries + 1] = s end
            delete_current(entries, target.label .. (group_name and (", " .. group_name .. " group") or ""))
            scan()
            if #found == 0 then
                say("No automation items remain")
                return false
            end
            if pick_idx > #found then pick_idx = #found end
            say(found[pick_idx].label)
        elseif char == KEY_ESC then
            return false
        end
    elseif state == STATE_EDIT then
        if transport.handle_transport_key(char) then
        elseif char == 104 or char == 72 then
            help.enter(edit_shortcuts(), function() say(item.label) end)
        elseif char == KEY_UP or char == KEY_DOWN then
            Undo_BeginBlock()
            nudge_value(char)
            Undo_EndBlock("Edit Automation: Value", -1)
        elseif char == 49 then
            edit_mode = MODE_P1
            say("Ramp in start selected")
        elseif char == 50 then
            edit_mode = MODE_P2
            say("Ramp in end selected")
        elseif char == 51 then
            edit_mode = MODE_P3
            say("Ramp out start selected")
        elseif char == 52 then
            edit_mode = MODE_P4
            say("Ramp out end selected")
        elseif char == 65 or char == 97 then
            edit_mode = MODE_BOTH
            say("Both edges selected")
        elseif char == 83 or char == 115 then
            edit_mode = MODE_LEFT
            say("Left edge selected")
        elseif char == 68 or char == 100 then
            edit_mode = MODE_RIGHT
            say("Right edge selected")
        elseif char == KEY_LEFT or char == KEY_RIGHT then
            local bigger = (gfx.mouse_cap & 8) == 8
            local amt    = time_nudge_amount(bigger)
            local dir    = (char == KEY_RIGHT) and 1 or -1

            Undo_BeginBlock()
            move_whole_item(dir * amt)
            Undo_EndBlock("Edit Automation: Move Item", -1)
        elseif char == KEY_PLUS_FINE or char == KEY_PLUS_COARSE
            or char == KEY_MINUS_FINE or char == KEY_MINUS_COARSE then
            local dir    = (char == KEY_PLUS_FINE or char == KEY_PLUS_COARSE) and 1 or -1
            local coarse = (char == KEY_PLUS_COARSE or char == KEY_MINUS_COARSE)
            local amt    = time_nudge_amount(coarse)

            Undo_BeginBlock()
            if edit_mode == MODE_P1 or edit_mode == MODE_P2
                or edit_mode == MODE_P3 or edit_mode == MODE_P4 then
                adjust_point(edit_mode, dir, amt)
                Undo_EndBlock("Edit Automation: Move Point", -1)
            elseif edit_mode == MODE_LEFT then
                shift_ramp_in(dir, amt)
                Undo_EndBlock("Edit Automation: Shift Ramp In", -1)
            elseif edit_mode == MODE_RIGHT then
                shift_ramp_out(dir, amt)
                Undo_EndBlock("Edit Automation: Shift Ramp Out", -1)
            else
                adjust_plateau(dir, amt)
                Undo_EndBlock("Edit Automation: Plateau", -1)
            end
        elseif char == 48 then
            Undo_BeginBlock()
            reset_to_original()
            Undo_EndBlock("Edit Automation: Reset", -1)
        elseif char == KEY_ENTER then
            while true do
                local ok, entered = ui_input.ask(WINDOW_TITLE,
                    item.label .. " - Value",
                    "Value", string.format("%.2f", edit_value))
                if not ok then
                    say("Cancelled")
                    break
                end
                local num = tonumber(entered)
                if not num then
                    say("Please enter a number")
                else
                    edit_value = math.max(item.disp_min, math.min(item.disp_max, num))
                    render()
                    say(speech_value(item.env_info, edit_value) .. group_suffix())
                    break
                end
            end
        elseif char == KEY_BACK then
            local entries = { item }
            for _, s in ipairs(item.siblings or {}) do entries[#entries + 1] = s end
            delete_current(entries, item.label .. group_suffix())
            state = STATE_PICK
            scan()
            pick_idx = 1
            if #found == 0 then
                say("No automation items remain")
                return false
            end
            say(found[pick_idx].label)
        elseif char == KEY_ESC then
            state = STATE_PICK
            scan()
            pick_idx = 1
            if #found == 0 then
                say("No automation items at cursor")
                return false
            end
            say(found[pick_idx].label)
        end
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

scan()

if #found == 0 then
    say("No automation items found at cursor")
    return
end

gfx.init(WINDOW_TITLE, 600, 44, 0)

if #found == 1 then
    enter_edit_mode(found[1])
    say(item.label .. group_suffix() .. EDIT_HINT)
else
    say(string.format(
        "%d automation items at cursor. Up and down to browse, Enter to edit, Backspace to delete, Escape to close. %s",
        #found, found[1].label))
end

defer(main)
