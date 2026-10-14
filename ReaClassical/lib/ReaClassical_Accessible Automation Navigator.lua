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
local mm  = require("ReaClassical_MM_Utils")
local mmg = require("ReaClassical_MM_Groups")
local au  = require("ReaClassical_Automation_Info")
local transport = require("ReaClassical_Transport_Utils")
local preview = require("ReaClassical_Automation_Preview")
local special_track_nav = require("ReaClassical_Special_Track_Nav")
local automation_ownership = require("ReaClassical_Automation_Ownership")
local automation_mode = require("ReaClassical_Automation_Mode")
local ui_input = require("ReaClassical_Accessible_Input")
local get_destination_source = au.get_destination_source
set_action_options(3)

local WINDOW_TITLE = "Automation Navigator"

local main, init_fx_list, init_param_list, handle_key, draw_window, insert_automation
local strip_fx_name, announce_fx, announce_param
local ensure_track_envelope, insert_track_param, insert_fx_param
local get_default_value, read_boundary, delete_overlapping_items
local refresh_pick_tracks, announce_pick_track, toggle_virtual_selection
local format_nudge_display
local track_display_value_at, fx_native_value_at

local STATE_PICK_TRACK  = "picktrack"
local STATE_SOURCE      = "source"
local STATE_TRACK_PARAM = "trackparam"
local STATE_FX          = "fx"
local STATE_PARAM       = "param"
local STATE_VALUE       = "value"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_LEFT  = 1818584692
local KEY_RIGHT = 1919379572
local KEY_ENTER = 13
local KEY_ESC   = 27

local SOURCE_OPTIONS = { "track", "fx" }
local SOURCE_LABELS  = { track = "Track parameters", fx = "FX" }

local TRACK_PARAMS = {
    { label = "Volume",        env_name = "Volume",          show_cmd = 40406, disp_min = -150, disp_max = 12,  unit = "dB",                is_vol   = true },
    { label = "Pan",           env_name = "Pan",             show_cmd = 40407, disp_min = -100, disp_max = 100, unit = "L=-100 to R=+100", is_pan   = true },
    { label = "Width",         env_name = "Width",           show_cmd = 41870, disp_min = -100, disp_max = 100, unit = "-100 to +100",     is_width = true },
    { label = "Mute",          env_name = "Mute",            show_cmd = 40867, disp_min = 0,    disp_max = 1,   unit = "0=muted 1=unmuted", is_mute  = true },
    { label = "Trim volume",   env_name = "Trim Volume",     show_cmd = 42020, disp_min = -150, disp_max = 12,  unit = "dB",                is_vol   = true },
    { label = "Pre-FX volume", env_name = "Volume (Pre-FX)", show_cmd = 41865, disp_min = -150, disp_max = 12,  unit = "dB",                is_vol   = true },
    { label = "Pre-FX pan",    env_name = "Pan (Pre-FX)",    show_cmd = 41867, disp_min = -100, disp_max = 100, unit = "L=-100 to R=+100", is_pan   = true },
    { label = "Pre-FX width",  env_name = "Width (Pre-FX)",  show_cmd = 41869, disp_min = -100, disp_max = 100, unit = "-100 to +100",     is_width = true },
}

local state           = STATE_PICK_TRACK
local track           = nil
local param_track     = nil
local pick_tracks      = {}
local pick_idx         = 1
local virtual_sel      = {}
local virtual_sel_set  = {}
local picked_tracks    = {}
local group_relative   = false
local value_baseline   = 0
local source_idx      = 1
local track_param_sel = 1
local fx_list         = {}
local param_list      = {}
local fx_sel          = 1
local param_sel       = 1
local confirmed_val   = 0
local confirmed_label_word = nil
local confirmed_label_t    = nil
local fx_range        = nil
local nudge_val        = 0
local nudge_active     = false
local ramp_in_secs    = 0
local ramp_out_secs   = 0
local last_char       = 0

local function has_time_selection()
    local s, e = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    return e > s
end

local function show_in_tcp(t)
    SetMediaTrackInfo_Value(t, "B_SHOWINTCP", 1)
    local _, ms   = GetSetMediaTrackInfo_String(t, "P_EXT:mixer", "", false)
    local _, guid = GetSetMediaTrackInfo_String(t, "GUID", "", false)
    local mc_key  = (ms == "y") and ("mixer_tcp_visible_" .. guid) or ("tcp_visible_" .. guid)
    SetProjExtState(0, "ReaClassical_MissionControl", mc_key, "1")
    TrackList_AdjustWindows(false)
end

local function db_to_linear(db)
    if db <= -150 then return 0.0 end
    return 10 ^ (db / 20)
end

local function linear_to_db(val)
    if val <= 0.0000000298023223876953125 then return -150.0 end
    return 20 * math.log(val, 10)
end

local function parse_fmt_number(s)
    if s:find("%-[Ii]nf") then return -150 end
    if s:find("[Ii]nf")   then return 1e9  end
    local num, suffix = s:match("([-+]?[0-9]*%.?[0-9]+)%s*([kK]?)")
    if not num then return nil end
    local n = tonumber(num)
    if suffix == "k" or suffix == "K" then n = n * 1000 end
    return n
end

local function display_to_env_native(tp, display_val)
    if tp.is_vol   then return ScaleToEnvelopeMode(1, db_to_linear(display_val)) end
    if tp.is_pan   then return -(display_val / 100) end
    if tp.is_width then return display_val / 100 end
    return display_val
end

local function clear_preview()
    preview.clear()
end

local function start_preview()
    clear_preview()
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        local field = preview.DIRECT_FIELD[tp.env_name]
        if not field then return end
        for _, t in ipairs(picked_tracks) do
            local pt = get_destination_source(t) or t
            preview.snapshot_track(pt, field)
        end
    else
        local fx_raw    = fx_list[fx_sel].raw_idx
        local param_raw = param_list[param_sel].raw_idx
        for _, t in ipairs(picked_tracks) do
            if fx_raw < TrackFX_GetCount(t) and param_raw < TrackFX_GetNumParams(t, fx_raw) then
                preview.snapshot_fx(t, fx_raw, param_raw)
            end
        end
    end
end

local function apply_preview(val)
    if not preview.has_targets() then return end
    if SOURCE_OPTIONS[source_idx] == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        preview.apply_track((tp.is_pan or tp.is_width) and val / 100 or val)
    else
        preview.apply_fx(val)
    end
end

local function get_fx_normalized_info()
    local fx_raw    = fx_list[fx_sel].raw_idx
    local param_raw = param_list[param_sel].raw_idx
    local _, min_val, max_val = TrackFX_GetParam(track, fx_raw, param_raw)
    if min_val > max_val then min_val, max_val = max_val, min_val end
    if not (math.abs(min_val) < 0.001 and math.abs(max_val - 1.0) < 0.001) then
        return false, min_val, max_val, nil, nil
    end
    local old_val = TrackFX_GetParam(track, fx_raw, param_raw)
    TrackFX_SetParam(track, fx_raw, param_raw, 0)
    local _, fmt0 = TrackFX_GetFormattedParamValue(track, fx_raw, param_raw, "")
    TrackFX_SetParam(track, fx_raw, param_raw, 1)
    local _, fmt1 = TrackFX_GetFormattedParamValue(track, fx_raw, param_raw, "")
    TrackFX_SetParam(track, fx_raw, param_raw, old_val)
    local n0 = parse_fmt_number(fmt0) or 0
    local n1 = parse_fmt_number(fmt1) or 0
    return true, math.min(n0, n1), math.max(n0, n1), fmt0, fmt1
end

local function find_normalized_for_display(display_num)
    local fx_raw    = fx_list[fx_sel].raw_idx
    local param_raw = param_list[param_sel].raw_idx
    local old_val   = TrackFX_GetParam(track, fx_raw, param_raw)
    local best_val, best_diff = 0, math.huge
    for i = 0, 200 do
        local test_val = i / 200
        TrackFX_SetParam(track, fx_raw, param_raw, test_val)
        local _, test_str = TrackFX_GetFormattedParamValue(track, fx_raw, param_raw, "")
        local test_num = parse_fmt_number(test_str)
        if test_num then
            local diff = math.abs(test_num - display_num)
            if diff < best_diff then
                best_diff = diff
                best_val  = test_val
            end
            if diff < 0.01 then break end
        end
    end
    TrackFX_SetParam(track, fx_raw, param_raw, old_val)
    return best_val
end

local function classify_fx_range()
    local fx_raw    = fx_list[fx_sel].raw_idx
    local param_raw = param_list[param_sel].raw_idx
    local old_val   = TrackFX_GetParam(track, fx_raw, param_raw)

    local low_fmt, high_fmt
    local low_num, high_num
    local low_t, high_t = 0, 1
    local any_numeric = false

    for i = 0, 50 do
        local t = i / 50
        TrackFX_SetParam(track, fx_raw, param_raw, t)
        local _, s = TrackFX_GetFormattedParamValue(track, fx_raw, param_raw, "")
        if i == 0  then low_fmt  = s end
        if i == 50 then high_fmt = s end
        local n = parse_fmt_number(s)
        if n then
            any_numeric = true
            if not low_num then low_num, low_t = n, t end
            high_num, high_t = n, t
        end
    end

    TrackFX_SetParam(track, fx_raw, param_raw, old_val)

    return {
        low_label   = (not parse_fmt_number(low_fmt))  and low_fmt  or nil,
        high_label  = (not parse_fmt_number(high_fmt)) and high_fmt or nil,
        low_num     = low_num,  low_t  = low_t,
        high_num    = high_num, high_t = high_t,
        any_numeric = any_numeric,
    }
end

local function get_value_range()
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        return tp.disp_min, tp.disp_max
    else
        if fx_range and fx_range.any_numeric then
            return fx_range.low_num or -math.huge, fx_range.high_num or math.huge
        end
        local _, lo, hi = get_fx_normalized_info()
        return lo, hi
    end
end

local function fx_range_words()
    local words = {}
    if fx_range and fx_range.low_label  then words[#words + 1] = fx_range.low_label  end
    if fx_range and fx_range.high_label then words[#words + 1] = fx_range.high_label end
    return words
end

local function get_value_prompt()
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        local tp   = TRACK_PARAMS[track_param_sel]
        local unit = tp.unit or ""
        if unit ~= "" then
            return string.format("Enter value %g to %g %s", tp.disp_min, tp.disp_max, unit)
        end
        return string.format("Enter value %g to %g", tp.disp_min, tp.disp_max)
    else
        if fx_range and (fx_range.low_label or fx_range.high_label) then
            local word_str = table.concat(fx_range_words(), " or ")
            if fx_range.any_numeric then
                return string.format("Enter value %g to %g, or type %s",
                    fx_range.low_num or 0, fx_range.high_num or 0, word_str)
            end
            return "No numeric scale for this parameter. Type " .. word_str
        end

        local is_norm, lo, hi, fmt0, fmt1 = get_fx_normalized_info()
        if is_norm then
            return "Enter value " .. (fmt0 or "0") .. " to " .. (fmt1 or "1")
        end
        return string.format("Enter value %g to %g", lo, hi)
    end
end

function refresh_pick_tracks()
    pick_tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if mm.is_special_track(t) then
            pick_tracks[#pick_tracks + 1] = t
        end
    end
end

function announce_pick_track(with_hint)
    local t = pick_tracks[pick_idx]
    if not t then
        say("No special tracks found")
        return
    end
    local label = mm.get_label(t)
    local sel_suffix = virtual_sel_set[t] and " (selected)" or ""
    if with_hint then
        say("Insert automation. " .. label .. sel_suffix
            .. ". Up or down to browse tracks, Enter to select, "
            .. "Shift+Enter to add or remove from a multi-track selection, Escape to close")
    else
        say(label .. sel_suffix)
    end
end

function toggle_virtual_selection()
    local t = pick_tracks[pick_idx]
    if not t then return end
    local label = mm.get_label(t)
    if virtual_sel_set[t] then
        virtual_sel_set[t] = nil
        for i, vt in ipairs(virtual_sel) do
            if vt == t then table.remove(virtual_sel, i) break end
        end
        say(label .. " removed. " .. #virtual_sel .. " track" .. (#virtual_sel == 1 and "" or "s") .. " selected")
    else
        virtual_sel_set[t] = true
        virtual_sel[#virtual_sel + 1] = t
        say(label .. " added. " .. #virtual_sel .. " track" .. (#virtual_sel == 1 and "" or "s") .. " selected")
    end
end

function strip_fx_name(raw)
    return raw:match("^%a+%d*: (.+)$") or raw
end

function ensure_track_envelope(pt, tp)
    local env = GetTrackEnvelopeByName(pt, tp.env_name)
    if not env then
        SetOnlyTrackSelected(pt)
        Main_OnCommand(tp.show_cmd, 0)
        env = GetTrackEnvelopeByName(pt, tp.env_name)
    end
    return env
end

local function default_track_value_for(pt, tp)
    local n = tp.env_name
    if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
        return GetMediaTrackInfo_Value(pt, "D_VOL")
    elseif n == "Pan" or n == "Pan (Pre-FX)" then
        return -GetMediaTrackInfo_Value(pt, "D_PAN")
    elseif n == "Width" or n == "Width (Pre-FX)" then
        return GetMediaTrackInfo_Value(pt, "D_WIDTH")
    elseif n == "Mute" then
        return 1 - GetMediaTrackInfo_Value(pt, "B_MUTE")
    end
    return 1.0
end

function get_default_value()
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        return default_track_value_for(param_track, TRACK_PARAMS[track_param_sel])
    else
        local fx_raw    = fx_list[fx_sel].raw_idx
        local param_raw = param_list[param_sel].raw_idx
        return TrackFX_GetParam(track, fx_raw, param_raw)
    end
end

function read_boundary(env, t)
    if not env then return get_default_value() end
    if CountEnvelopePoints(env) == 0 and CountAutomationItems(env) == 0 then
        return get_default_value()
    end
    local _, val = Envelope_Evaluate(env, t, 44100, 1)
    return val
end

function delete_overlapping_items(env, start_t, end_t)
    local count = CountAutomationItems(env)
    if count == 0 then return end
    local any = false
    for i = 0, count - 1 do
        local pos = GetSetAutomationItemInfo(env, i, "D_POSITION", 0, false)
        local len = GetSetAutomationItemInfo(env, i, "D_LENGTH",   0, false)
        local overlaps = pos < end_t and (pos + len) > start_t
        GetSetAutomationItemInfo(env, i, "D_UISEL", overlaps and 1 or 0, true)
        if overlaps then any = true end
    end
    if any then Main_OnCommand(42086, 0) end
end

function init_fx_list()
    fx_list = {}
    local n = TrackFX_GetCount(track)
    for i = 0, n - 1 do
        local _, name = TrackFX_GetFXName(track, i, "")
        fx_list[#fx_list + 1] = { raw_idx = i, name = strip_fx_name(name) }
    end
end

function init_param_list()
    param_list = {}
    local fx_raw = fx_list[fx_sel].raw_idx
    local n = TrackFX_GetNumParams(track, fx_raw)
    for i = 0, n - 1 do
        local _, pname = TrackFX_GetParamName(track, fx_raw, i, "")
        param_list[#param_list + 1] = { raw_idx = i, name = pname }
    end
end

function announce_fx()
    if #fx_list == 0 then say("No FX on track") return end
    say(fx_list[fx_sel].name)
end

function announce_param()
    if #param_list == 0 then say("No parameters") return end
    say(param_list[param_sel].name)
end

function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13

    if state == STATE_PICK_TRACK then
        if #pick_tracks == 0 then
            gfx.drawstr("No special tracks found")
        else
            local sel_suffix = #virtual_sel > 0 and ("  [" .. #virtual_sel .. " selected]") or ""
            gfx.drawstr("[Track]  " .. mm.get_label(pick_tracks[pick_idx]) .. sel_suffix)
        end
    elseif state == STATE_SOURCE then
        gfx.drawstr("[Source]  " .. SOURCE_LABELS[SOURCE_OPTIONS[source_idx]])
    elseif state == STATE_TRACK_PARAM then
        gfx.drawstr("[Param]  " .. TRACK_PARAMS[track_param_sel].label)
    elseif state == STATE_FX then
        if #fx_list == 0 then
            gfx.drawstr("No FX on track")
        else
            gfx.drawstr("[FX]  " .. fx_list[fx_sel].name)
        end
    elseif state == STATE_PARAM then
        gfx.drawstr("[Param]  " .. param_list[param_sel].name)
    elseif state == STATE_VALUE then
        gfx.drawstr("[Automation item]  "
            .. (nudge_active and format_nudge_display() or "_"))
    end
    gfx.update()
end

local function insert_bracket(env, native)
    local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if ts_start >= ts_end then
        say("Please set a time selection first")
        return true
    end

    local ramp_in_start  = math.max(0, ts_start - ramp_in_secs)
    local ramp_out_end   = ts_end   + ramp_out_secs
    local affected_start = ramp_in_secs  > 0 and ramp_in_start or math.max(0, ts_start - 0.002)
    local affected_end   = ramp_out_secs > 0 and ramp_out_end  or (ts_end   + 0.002)

    local t_before   = ramp_in_secs  > 0 and ramp_in_start  or math.max(0, ts_start - 0.001)
    local t_after    = ramp_out_secs > 0 and ramp_out_end   or (ts_end   + 0.001)
    local val_before = read_boundary(env, t_before)
    local val_after  = read_boundary(env, t_after)

    delete_overlapping_items(env, affected_start, affected_end)
    DeleteEnvelopePointRange(env, affected_start - 0.001, affected_end + 0.001)

    if ramp_in_secs > 0 then
        if ramp_in_start < ts_start then
            InsertEnvelopePoint(env, ramp_in_start,      val_before, 0, 0, false, true)
        end
        InsertEnvelopePoint(env, ts_start,            native,     0, 0, false, true)
    else
        if t_before < ts_start then
            InsertEnvelopePoint(env, t_before,           val_before, 0, 0, false, true)
        end
        InsertEnvelopePoint(env, ts_start,            native,     0, 0, false, true)
    end

    if ramp_out_secs > 0 then
        InsertEnvelopePoint(env, ts_end,              native,     0, 0, false, true)
        InsertEnvelopePoint(env, ramp_out_end,        val_after,  0, 0, false, true)
    else
        InsertEnvelopePoint(env, ts_end,              native,     0, 0, false, true)
        InsertEnvelopePoint(env, ts_end + 0.001,      val_after,  0, 0, false, true)
    end

    Envelope_SortPoints(env)

    local item_start = ramp_in_secs  > 0 and ramp_in_start or math.max(0, ts_start - 0.002)
    local item_end   = ramp_out_secs > 0 and (ts_end   + ramp_out_secs) or (ts_end   + 0.002)
    local ai_idx = InsertAutomationItem(env, -1, item_start, item_end - item_start)
    local env_track = Envelope_GetParentTrack(env)
    if special_track_nav.is_special_track(env_track) then
        automation_ownership.mark_user_ai(env, ai_idx)
    end
    automation_mode.ensure_engaged()

    return false
end

function insert_track_param(display_val)
    local tp = TRACK_PARAMS[track_param_sel]
    local relative = group_relative and not tp.is_mute
    local delta = relative and (display_val - value_baseline) or 0
    local ts_start = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

    Undo_BeginBlock()
    local touched_labels = {}
    for _, t in ipairs(picked_tracks) do
        local pt = get_destination_source(t) or t
        local track_display = display_val
        if relative then
            track_display = math.max(tp.disp_min, math.min(tp.disp_max,
                track_display_value_at(pt, tp, ts_start) + delta))
        end
        local native = display_to_env_native(tp, track_display)
        local env = ensure_track_envelope(pt, tp)
        if not env then
            say("Could not create " .. tp.label .. " envelope on " .. mm.get_label(t))
        else
            local stay = insert_bracket(env, native)
            if stay then
                Undo_EndBlock("", -1)
                return true
            end
            show_in_tcp(pt)
            touched_labels[#touched_labels + 1] = mm.get_label(t)
        end
    end

    if #touched_labels == 0 then
        Undo_EndBlock("", -1)
        return true
    end

    local val_str = tp.is_vol and string.format("%.1f dB", display_val) or string.format("%.2f", display_val)
    if #picked_tracks == 1 then
        say(string.format("Added %s automation item at %s", tp.label, val_str))
    else
        say(string.format("Added %s automation item at %s to %d track%s",
            tp.label, val_str, #touched_labels, #touched_labels == 1 and "" or "s"))
    end
    Undo_EndBlock("Track Automation: " .. tp.label, -1)
    UpdateArrange()
    UpdateTimeline()
    return false
end

function insert_fx_param(display_val)
    local fx_entry    = fx_list[fx_sel]
    local param_entry = param_list[param_sel]
    local fx_raw      = fx_entry.raw_idx
    local param_raw   = param_entry.raw_idx
    local is_norm = get_fx_normalized_info()

    local native, announce
    if confirmed_label_t then
        native   = confirmed_label_t
        announce = confirmed_label_word
    elseif is_norm then
        native   = find_normalized_for_display(display_val)
        announce = string.format("%.3f", display_val)
    else
        native   = display_val
        announce = string.format("%.3f", display_val)
    end

    local relative = group_relative and not confirmed_label_t
    local delta = relative and (native - value_baseline) or 0
    local ts_start = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)

    Undo_BeginBlock()

    local touched_labels = {}
    local skipped_labels = {}
    for _, t in ipairs(picked_tracks) do
        local env = (fx_raw < TrackFX_GetCount(t) and param_raw < TrackFX_GetNumParams(t, fx_raw))
            and GetFXEnvelope(t, fx_raw, param_raw, true)
            or nil
        if not env then
            skipped_labels[#skipped_labels + 1] = mm.get_label(t)
        else
            local t_native = native
            if relative then
                local cur = fx_native_value_at(t, fx_raw, param_raw, ts_start)
                if cur then
                    local _, lo, hi = TrackFX_GetParam(t, fx_raw, param_raw)
                    if lo > hi then lo, hi = hi, lo end
                    t_native = math.max(lo, math.min(hi, cur + delta))
                end
            end
            local stay = insert_bracket(env, t_native)
            if stay then
                Undo_EndBlock("", -1)
                return true
            end
            show_in_tcp(t)
            touched_labels[#touched_labels + 1] = mm.get_label(t)
        end
    end

    if #touched_labels == 0 then
        Undo_EndBlock("", -1)
        say("Could not create automation envelope on any selected track")
        return true
    end

    if #picked_tracks == 1 then
        say(string.format("Added %s automation item at %s", param_entry.name, announce))
    else
        local msg = string.format("Added %s automation item at %s to %d track%s",
            param_entry.name, announce, #touched_labels, #touched_labels == 1 and "" or "s")
        if #skipped_labels > 0 then
            msg = msg .. ". Skipped (FX not found): " .. table.concat(skipped_labels, ", ")
        end
        say(msg)
    end
    Undo_EndBlock("FX Automation: " .. fx_entry.name .. " > " .. param_entry.name, -1)
    UpdateArrange()
    UpdateTimeline()
    return false
end

function insert_automation(display_val)
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        return insert_track_param(display_val)
    else
        return insert_fx_param(display_val)
    end
end

local function try_commit_value_text(raw)
    local word = raw:lower()
    if fx_range then
        if fx_range.low_label and word == fx_range.low_label:lower() then
            confirmed_label_word, confirmed_label_t =
                fx_range.low_label, fx_range.low_t
            clear_preview()
            return true
        end
        if fx_range.high_label and word == fx_range.high_label:lower() then
            confirmed_label_word, confirmed_label_t =
                fx_range.high_label, fx_range.high_t
            clear_preview()
            return true
        end
    end
    local val = tonumber(raw)
    local min_v, max_v = get_value_range()
    local words = fx_range_words()
    local hint = #words > 0 and (", or type " .. table.concat(words, " or ")) or ""
    if not val then
        say("Please enter a number" .. hint)
        return false
    end
    if val < min_v or val > max_v then
        say(string.format("Please enter a value between %g and %g", min_v, max_v) .. hint)
        return false
    end
    confirmed_label_word, confirmed_label_t = nil, nil
    confirmed_val = val
    clear_preview()
    return true
end

local function finish_with_ramps_and_insert()
    local ok_in, in_str = ui_input.ask(WINDOW_TITLE, "Ramp In",
        "Ramp in seconds, blank for none", "")
    if not ok_in then
        say("Cancelled")
        return true
    end
    ramp_in_secs = math.max(0, tonumber(in_str) or 0)
    local ok_out, out_str = ui_input.ask(WINDOW_TITLE, "Ramp Out",
        "Ramp out seconds, blank for none", "")
    if not ok_out then
        say("Cancelled")
        return true
    end
    ramp_out_secs = math.max(0, tonumber(out_str) or 0)
    return insert_automation(confirmed_val)
end

local function ask_and_commit_value()
    local prefill = ""
    while true do
        local ok, raw = ui_input.ask(WINDOW_TITLE, "Automation Value",
            get_value_prompt(), prefill)
        if not ok then
            say("Cancelled")
            return true
        end
        if try_commit_value_text(raw) then
            return finish_with_ramps_and_insert()
        end
        prefill = raw
    end
end

local function format_fx_native(native)
    local fx_raw    = fx_list[fx_sel].raw_idx
    local param_raw = param_list[param_sel].raw_idx
    local old_val = TrackFX_GetParam(track, fx_raw, param_raw)
    TrackFX_SetParam(track, fx_raw, param_raw, native)
    local _, fmt = TrackFX_GetFormattedParamValue(track, fx_raw, param_raw, "")
    TrackFX_SetParam(track, fx_raw, param_raw, old_val)
    return fmt
end

function format_nudge_display()
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        if tp.is_vol then return string.format("%.1f dB", nudge_val) end
        if tp.is_pan or tp.is_width then return string.format("%.2f", nudge_val) end
        return nudge_val >= 0.5 and "Unmuted" or "Muted"
    else
        return format_fx_native(nudge_val)
    end
end

local function speech_nudge_display()
    return (format_nudge_display():gsub("^%-", "minus "))
end

function track_display_value_at(pt, tp, t)
    local env  = GetTrackEnvelopeByName(pt, tp.env_name)
    local has_env_data = env and (CountEnvelopePoints(env) > 0 or CountAutomationItems(env) > 0)
    local native = has_env_data and select(2, Envelope_Evaluate(env, t, 44100, 1))
        or default_track_value_for(pt, tp)
    if tp.is_vol then
        if has_env_data then native = ScaleFromEnvelopeMode(1, native) end
        return linear_to_db(native)
    elseif tp.is_pan then
        return -native * 100
    elseif tp.is_width then
        return native * 100
    else
        return native
    end
end

function fx_native_value_at(t, fx_raw, param_raw, ts)
    if fx_raw >= TrackFX_GetCount(t) or param_raw >= TrackFX_GetNumParams(t, fx_raw) then
        return nil
    end
    local env = GetFXEnvelope(t, fx_raw, param_raw, false)
    if env and (CountEnvelopePoints(env) > 0 or CountAutomationItems(env) > 0) then
        local _, val = Envelope_Evaluate(env, ts, 44100, 1)
        return val
    end
    return TrackFX_GetParam(t, fx_raw, param_raw)
end

local function get_current_display_value()
    local ts_start = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        return track_display_value_at(param_track, TRACK_PARAMS[track_param_sel], ts_start)
    else
        local fx_raw    = fx_list[fx_sel].raw_idx
        local param_raw = param_list[param_sel].raw_idx
        local env       = GetFXEnvelope(track, fx_raw, param_raw, false)
        return read_boundary(env, ts_start)
    end
end

local function get_current_value_str()
    local source = SOURCE_OPTIONS[source_idx]
    local val    = get_current_display_value()
    if source == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        if tp.is_vol then return string.format("%.1f dB", val) end
        if tp.is_pan or tp.is_width then return string.format("%.2f", val) end
        return string.format("%.0f", val)
    else
        local is_norm = get_fx_normalized_info()
        if is_norm then return format_fx_native(val) end
        return string.format("%.3f", val)
    end
end

local function enter_value_state()
    state     = STATE_VALUE
    confirmed_label_word = nil
    confirmed_label_t    = nil
    fx_range = nil
    nudge_active = false
    nudge_val    = get_current_display_value()
    value_baseline = nudge_val
    if SOURCE_OPTIONS[source_idx] == "fx" then
        local is_norm = get_fx_normalized_info()
        if is_norm then fx_range = classify_fx_range() end
    end
    start_preview()
    apply_preview(nudge_val)
    say("Current value " .. get_current_value_str()
        .. ". Enter to type a specific value, or Up and Down to nudge, Shift for a finer step")
end

local function nudge_step(coarse)
    local source = SOURCE_OPTIONS[source_idx]
    if source == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        if tp.is_vol   then return coarse and 1.0 or 0.2 end
        if tp.is_pan   then return coarse and 5.0 or 1.0 end
        if tp.is_width then return coarse and 5.0 or 1.0 end
        return 1.0
    else
        local is_norm, lo, hi = get_fx_normalized_info()
        if is_norm then return coarse and 0.05 or 0.01 end
        local range = (hi > lo) and (hi - lo) or 1
        return coarse and (range * 0.05) or (range * 0.01)
    end
end

function handle_key(char)
    if state == STATE_PICK_TRACK then
        if #pick_tracks == 0 then
            if char == KEY_ESC then return false end
            return true
        end
        if char == KEY_UP then
            pick_idx = pick_idx > 1 and pick_idx - 1 or #pick_tracks
            announce_pick_track(false)
        elseif char == KEY_DOWN then
            pick_idx = pick_idx < #pick_tracks and pick_idx + 1 or 1
            announce_pick_track(false)
        elseif char == KEY_ENTER then
            if (gfx.mouse_cap & 8) == 8 then
                toggle_virtual_selection()
            else
                local group_name
                local anchor = pick_tracks[pick_idx]
                group_relative = false
                if #virtual_sel > 0 then
                    picked_tracks = {}
                    local labels = {}
                    for _, vt in ipairs(virtual_sel) do
                        picked_tracks[#picked_tracks + 1] = vt
                        labels[#labels + 1] = mm.get_label(vt)
                    end
                    anchor = picked_tracks[1]
                    say(#picked_tracks .. " tracks selected: " .. table.concat(labels, ", "))
                else
                    local targets, grouped, gname = mmg.get_action_targets(anchor, "automation")
                    picked_tracks = targets
                    group_relative = grouped
                    group_name = grouped and gname or nil
                end
                track = anchor
                param_track = get_destination_source(track) or track
                init_fx_list()
                state = STATE_SOURCE
                local group_prefix = group_name
                    and (#picked_tracks .. " tracks in " .. group_name .. " group selected. ")
                    or ""
                say(group_prefix .. SOURCE_LABELS[SOURCE_OPTIONS[source_idx]]
                    .. ". Up and down to browse, Enter to select, Escape to go back")
            end
        elseif char == KEY_ESC then
            return false
        end
    elseif state == STATE_SOURCE then
        if char == KEY_UP then
            source_idx = source_idx > 1 and source_idx - 1 or #SOURCE_OPTIONS
            say(SOURCE_LABELS[SOURCE_OPTIONS[source_idx]])
        elseif char == KEY_DOWN then
            source_idx = source_idx < #SOURCE_OPTIONS and source_idx + 1 or 1
            say(SOURCE_LABELS[SOURCE_OPTIONS[source_idx]])
        elseif char == KEY_ENTER then
            local source = SOURCE_OPTIONS[source_idx]
            if source == "track" then
                state = STATE_TRACK_PARAM
                say("Track parameters. " .. TRACK_PARAMS[track_param_sel].label
                    .. ". Up and down to browse, Enter to select, Escape to go back")
            else
                if #fx_list == 0 then
                    say("No FX on this track")
                else
                    state = STATE_FX
                    say(fx_list[fx_sel].name
                        .. ". Up and down to browse, Enter to select, Escape to go back")
                end
            end
        elseif char == KEY_ESC then
            state = STATE_PICK_TRACK
            announce_pick_track(false)
        end
    elseif state == STATE_TRACK_PARAM then
        if char == KEY_UP then
            track_param_sel = track_param_sel > 1 and track_param_sel - 1 or #TRACK_PARAMS
            say(TRACK_PARAMS[track_param_sel].label)
        elseif char == KEY_DOWN then
            track_param_sel = track_param_sel < #TRACK_PARAMS and track_param_sel + 1 or 1
            say(TRACK_PARAMS[track_param_sel].label)
        elseif char == KEY_ENTER then
            enter_value_state()
        elseif char == KEY_ESC then
            state = STATE_SOURCE
            say(SOURCE_LABELS[SOURCE_OPTIONS[source_idx]])
        end
    elseif state == STATE_FX then
        if char == KEY_UP then
            if #fx_list > 0 then
                fx_sel = fx_sel > 1 and fx_sel - 1 or #fx_list
                announce_fx()
            end
        elseif char == KEY_DOWN then
            if #fx_list > 0 then
                fx_sel = fx_sel < #fx_list and fx_sel + 1 or 1
                announce_fx()
            end
        elseif char == KEY_ENTER then
            if #fx_list > 0 then
                init_param_list()
                if #param_list == 0 then
                    say(fx_list[fx_sel].name .. " has no parameters")
                else
                    param_sel = 1
                    state = STATE_PARAM
                    say(fx_list[fx_sel].name .. " selected. " .. param_list[1].name)
                end
            end
        elseif char == KEY_ESC then
            state = STATE_SOURCE
            say(SOURCE_LABELS[SOURCE_OPTIONS[source_idx]])
        end
    elseif state == STATE_PARAM then
        if char == KEY_UP then
            param_sel = param_sel > 1 and param_sel - 1 or #param_list
            announce_param()
        elseif char == KEY_DOWN then
            param_sel = param_sel < #param_list and param_sel + 1 or 1
            announce_param()
        elseif char == KEY_ENTER then
            enter_value_state()
        elseif char == KEY_ESC then
            state = STATE_FX
            announce_fx()
        end
    elseif state == STATE_VALUE then
        if transport.handle_transport_key(char) then
        elseif char == KEY_UP or char == KEY_DOWN then
            local source = SOURCE_OPTIONS[source_idx]
            local tp = source == "track" and TRACK_PARAMS[track_param_sel] or nil

            if tp and tp.is_mute then
                nudge_val = nudge_val >= 0.5 and 0 or 1
            else
                local coarse = (gfx.mouse_cap & 8) ~= 8
                local step   = nudge_step(coarse)
                if char == KEY_DOWN then step = -step end
                nudge_val = nudge_val + step

                if source == "track" then
                    nudge_val = math.max(tp.disp_min, math.min(tp.disp_max, nudge_val))
                else
                    local is_norm, lo, hi = get_fx_normalized_info()
                    if is_norm then
                        nudge_val = math.max(0, math.min(1, nudge_val))
                    else
                        nudge_val = math.max(lo, math.min(hi, nudge_val))
                    end
                end
            end

            nudge_active = true
            apply_preview(nudge_val)
            say(speech_nudge_display())
        elseif char == KEY_ENTER then
            if nudge_active then
                if SOURCE_OPTIONS[source_idx] == "fx" then
                    confirmed_label_t    = nudge_val
                    confirmed_label_word = format_fx_native(nudge_val)
                else
                    confirmed_val = nudge_val
                end
                clear_preview()
                if not finish_with_ramps_and_insert() then
                    return false
                end
            else
                if not ask_and_commit_value() then
                    return false
                end
            end
        elseif char == KEY_ESC then
            clear_preview()
            local source = SOURCE_OPTIONS[source_idx]
            if source == "track" then
                state = STATE_TRACK_PARAM
                say(TRACK_PARAMS[track_param_sel].label)
            else
                state = STATE_PARAM
                announce_param()
            end
        end
    end

    return true
end

function main()
    local char = gfx.getchar()
    if char == -1 then
        clear_preview()
        gfx.quit()
        return
    end
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
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then modifier = "Cmd" end
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.",
        "ReaClassical Error", 0)
    return
end

if not has_time_selection() then
    say("Please set a time selection first")
    return
end

refresh_pick_tracks()
if #pick_tracks == 0 then
    say("No special tracks found")
    return
end

atexit(clear_preview)

gfx.init(WINDOW_TITLE, 480, 44, 0)

state = STATE_PICK_TRACK
announce_pick_track(true)

defer(main)
