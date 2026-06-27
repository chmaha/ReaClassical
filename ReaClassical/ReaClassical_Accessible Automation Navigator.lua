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

local main, init_fx_list, init_param_list, handle_key, draw_window, insert_automation
local strip_fx_name, announce_fx, announce_param
local ensure_track_envelope, insert_track_param, insert_fx_param
local get_default_value, read_boundary, delete_overlapping_items

---------------------------------------------------------------------

local STATE_SOURCE      = "source"
local STATE_TRACK_PARAM = "trackparam"
local STATE_FX          = "fx"
local STATE_PARAM       = "param"
local STATE_TYPE        = "type"
local STATE_VALUE       = "value"
local STATE_RAMP_IN     = "rampin"
local STATE_RAMP_OUT    = "rampout"

-- gfx.getchar() key codes (cross-platform REAPER gfx)
local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_LEFT  = 1818584692
local KEY_RIGHT = 1919379572
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_BACK  = 8

local SOURCE_OPTIONS = { "track", "fx" }
local SOURCE_LABELS  = { track = "Track parameters", fx = "FX" }

-- env_name: exact name for GetTrackEnvelopeByName
-- show_cmd: Main_OnCommand action that creates/shows the envelope
-- snap_key: SetMediaTrackInfo_Value key for snapshot mode (nil = not applicable)
local TRACK_PARAMS = {
    { label = "Volume",        env_name = "Volume",          show_cmd = 40406, snap_key = "D_VOL",   disp_min = -150, disp_max = 12,  unit = "dB",                is_vol   = true },
    { label = "Pan",           env_name = "Pan",             show_cmd = 40407, snap_key = "D_PAN",   disp_min = -100, disp_max = 100, unit = "L=-100 to R=+100", is_pan   = true },
    { label = "Width",         env_name = "Width",           show_cmd = 41870, snap_key = "D_WIDTH", disp_min = -100, disp_max = 100, unit = "-100 to +100",     is_width = true },
    { label = "Mute",          env_name = "Mute",            show_cmd = 40867, snap_key = "B_MUTE",  disp_min = 0,    disp_max = 1,   unit = "0=muted 1=unmuted", is_mute  = true },
    { label = "Trim volume",   env_name = "Trim Volume",     show_cmd = 42020, snap_key = nil,        disp_min = -150, disp_max = 12,  unit = "dB",                is_vol   = true },
    { label = "Pre-FX volume", env_name = "Volume (Pre-FX)", show_cmd = 41865, snap_key = nil,        disp_min = -150, disp_max = 12,  unit = "dB",                is_vol   = true },
    { label = "Pre-FX pan",    env_name = "Pan (Pre-FX)",    show_cmd = 41867, snap_key = nil,        disp_min = -100, disp_max = 100, unit = "L=-100 to R=+100", is_pan   = true },
    { label = "Pre-FX width",  env_name = "Width (Pre-FX)",  show_cmd = 41869, snap_key = nil,        disp_min = -100, disp_max = 100, unit = "-100 to +100",     is_width = true },
}

local TYPE_OPTIONS = { "snapshot", "point", "item" }
local TYPE_LABELS  = {
    snapshot = "Set snapshot value",
    point    = "Automation point",
    item     = "Automation item",
}

local state           = STATE_SOURCE
local track           = nil
local source_idx      = 1       -- default: Track parameters
local track_param_sel = 1
local fx_list         = {}
local param_list      = {}
local fx_sel          = 1
local param_sel       = 1
local type_idx        = 1       -- default: Set snapshot value
local value_str       = ""
local confirmed_val   = 0
local ramp_in_str     = ""
local ramp_out_str    = ""
local ramp_in_secs    = 0
local ramp_out_secs   = 0
local last_char       = 0

---------------------------------------------------------------------

local function db_to_linear(db)
    if db <= -150 then return 0.0 end
    return 10 ^ (db / 20)
end

local function linear_to_db(val)
    if val <= 0.0000000298023223876953125 then return -150.0 end
    return 20 * math.log(val, 10)
end

-- Converts display_val to the raw value used by SetMediaTrackInfo_Value (snapshot mode).
local function display_to_snap_native(tp, display_val)
    if tp.is_vol   then return db_to_linear(display_val) end
    if tp.is_pan   then return display_val / 100 end
    if tp.is_width then return display_val / 100 end
    return display_val
end

-- Converts display_val to the value stored in the envelope point.
-- Pan envelopes use inverted sign vs D_PAN (REAPER internal convention).
local function display_to_env_native(tp, display_val)
    if tp.is_vol   then return db_to_linear(display_val) end
    if tp.is_pan   then return -(display_val / 100) end
    if tp.is_width then return display_val / 100 end
    return display_val
end

-- For normalized VST/VST3 FX params (min=0, max=1): probes formatted values at
-- endpoints and returns (true, numeric_lo, numeric_hi, fmt_str_0, fmt_str_1).
-- For non-normalized (JSFX/LV2): returns (false, actual_min, actual_max, nil, nil).
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
    local function parse_fmt(s)
        if s:find("%-[Ii]nf") then return -150 end
        if s:find("[Ii]nf")   then return 1e9  end
        return tonumber(s:match("[-+]?[0-9]*%.?[0-9]+")) or 0
    end
    local n0, n1 = parse_fmt(fmt0), parse_fmt(fmt1)
    return true, math.min(n0, n1), math.max(n0, n1), fmt0, fmt1
end

-- Searches through 201 evenly-spaced normalized values (0-1) to find the one
-- whose formatted string output is numerically closest to display_num.
local function find_normalized_for_display(display_num)
    local fx_raw    = fx_list[fx_sel].raw_idx
    local param_raw = param_list[param_sel].raw_idx
    local old_val   = TrackFX_GetParam(track, fx_raw, param_raw)
    local best_val, best_diff = 0, math.huge
    for i = 0, 200 do
        local test_val = i / 200
        TrackFX_SetParam(track, fx_raw, param_raw, test_val)
        local _, test_str = TrackFX_GetFormattedParamValue(track, fx_raw, param_raw, "")
        local test_num = tonumber(test_str:match("[-+]?[0-9]*%.?[0-9]+"))
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

local function get_value_range()
    if SOURCE_OPTIONS[source_idx] == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        return tp.disp_min, tp.disp_max
    else
        local _, lo, hi = get_fx_normalized_info()
        return lo, hi
    end
end

local function get_value_prompt()
    if SOURCE_OPTIONS[source_idx] == "track" then
        local tp   = TRACK_PARAMS[track_param_sel]
        local unit = tp.unit or ""
        if unit ~= "" then
            return string.format("Enter value %g to %g %s", tp.disp_min, tp.disp_max, unit)
        end
        return string.format("Enter value %g to %g", tp.disp_min, tp.disp_max)
    else
        local is_norm, lo, hi, fmt0, fmt1 = get_fx_normalized_info()
        if is_norm then
            return "Enter value " .. (fmt0 or "0") .. " to " .. (fmt1 or "1")
        end
        return string.format("Enter value %g to %g", lo, hi)
    end
end

---------------------------------------------------------------------

function strip_fx_name(raw)
    return raw:match("^%a+%d*: (.+)$") or raw
end

---------------------------------------------------------------------

function ensure_track_envelope(tp)
    local env = GetTrackEnvelopeByName(track, tp.env_name)
    if not env then
        SetOnlyTrackSelected(track)
        Main_OnCommand(tp.show_cmd, 0)
        env = GetTrackEnvelopeByName(track, tp.env_name)
    end
    return env
end

---------------------------------------------------------------------

function get_default_value()
    if SOURCE_OPTIONS[source_idx] == "track" then
        local tp = TRACK_PARAMS[track_param_sel]
        local n = tp.env_name
        if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
            return GetMediaTrackInfo_Value(track, "D_VOL")
        elseif n == "Pan" or n == "Pan (Pre-FX)" then
            return GetMediaTrackInfo_Value(track, "D_PAN")
        elseif n == "Width" or n == "Width (Pre-FX)" then
            return GetMediaTrackInfo_Value(track, "D_WIDTH")
        elseif n == "Mute" then
            return 1 - GetMediaTrackInfo_Value(track, "B_MUTE") -- envelope: 1=unmuted
        end
        return 1.0
    else
        local fx_raw    = fx_list[fx_sel].raw_idx
        local param_raw = param_list[param_sel].raw_idx
        return TrackFX_GetParam(track, fx_raw, param_raw)
    end
end

---------------------------------------------------------------------

function read_boundary(env, t)
    if not env then return get_default_value() end
    if CountEnvelopePoints(env) == 0 and CountAutomationItems(env) == 0 then
        return get_default_value()
    end
    local _, val = Envelope_Evaluate(env, t, 44100, 1)
    return val
end

---------------------------------------------------------------------

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
    if any then Main_OnCommand(42086, 0) end -- Envelope: Delete selected automation items
end

---------------------------------------------------------------------

function init_fx_list()
    fx_list = {}
    local n = TrackFX_GetCount(track)
    for i = 0, n - 1 do
        local _, name = TrackFX_GetFXName(track, i, "")
        fx_list[#fx_list + 1] = { raw_idx = i, name = strip_fx_name(name) }
    end
end

---------------------------------------------------------------------

function init_param_list()
    param_list = {}
    local fx_raw = fx_list[fx_sel].raw_idx
    local n = TrackFX_GetNumParams(track, fx_raw)
    for i = 0, n - 1 do
        local _, pname = TrackFX_GetParamName(track, fx_raw, i, "")
        param_list[#param_list + 1] = { raw_idx = i, name = pname }
    end
end

---------------------------------------------------------------------

function announce_fx()
    if #fx_list == 0 then say("No FX on track") return end
    say(fx_list[fx_sel].name)
end

---------------------------------------------------------------------

function announce_param()
    if #param_list == 0 then say("No parameters") return end
    say(param_list[param_sel].name)
end

---------------------------------------------------------------------

function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13

    if state == STATE_SOURCE then
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
    elseif state == STATE_TYPE then
        gfx.drawstr("[Type]  " .. TYPE_LABELS[TYPE_OPTIONS[type_idx]])
    elseif state == STATE_VALUE then
        gfx.drawstr("[Value]  " .. (value_str == "" and "_" or value_str))
    elseif state == STATE_RAMP_IN then
        gfx.drawstr("[Ramp in]  " .. (ramp_in_str == "" and "(none)" or ramp_in_str .. "s"))
    elseif state == STATE_RAMP_OUT then
        gfx.drawstr("[Ramp out]  " .. (ramp_out_str == "" and "(none)" or ramp_out_str .. "s"))
    end
    gfx.update()
end

---------------------------------------------------------------------

-- Shared bracket-insertion logic for both track and FX point/item modes.
-- env must already exist. native is the target value in raw envelope units.
-- Returns true to keep navigator open (error), false to close.
local function insert_bracket(env, native, ins_type)
    local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if ts_start >= ts_end then
        say("Please set a time selection first")
        return true
    end

    local ramp_in_start  = ts_start - ramp_in_secs
    local ramp_out_end   = ts_end   + ramp_out_secs
    local affected_start = ramp_in_secs  > 0 and ramp_in_start or (ts_start - 0.002)
    local affected_end   = ramp_out_secs > 0 and ramp_out_end  or (ts_end   + 0.002)

    -- Read boundaries BEFORE any deletions
    local t_before   = ramp_in_secs  > 0 and ramp_in_start  or (ts_start - 0.001)
    local t_after    = ramp_out_secs > 0 and ramp_out_end   or (ts_end   + 0.001)
    local val_before = read_boundary(env, t_before)
    local val_after  = read_boundary(env, t_after)

    delete_overlapping_items(env, affected_start, affected_end)
    DeleteEnvelopePointRange(env, affected_start - 0.001, affected_end + 0.001)

    if ramp_in_secs > 0 then
        InsertEnvelopePoint(env, ramp_in_start,      val_before, 0, 0, false, true)
        InsertEnvelopePoint(env, ts_start,            native,     0, 0, false, true)
    else
        InsertEnvelopePoint(env, ts_start - 0.001,   val_before, 0, 0, false, true)
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

    if ins_type == "item" then
        local item_start = ramp_in_secs  > 0 and (ts_start - ramp_in_secs)  or (ts_start - 0.002)
        local item_end   = ramp_out_secs > 0 and (ts_end   + ramp_out_secs) or (ts_end   + 0.002)
        InsertAutomationItem(env, -1, item_start, item_end - item_start)
    end

    return false
end

---------------------------------------------------------------------

-- Returns true to keep the navigator open (error), false to close on success.
function insert_track_param(display_val, ins_type)
    local tp = TRACK_PARAMS[track_param_sel]

    if ins_type == "snapshot" then
        if not tp.snap_key then
            state = STATE_TYPE
            say("Snapshot not available for " .. tp.label .. ". Choose Automation point or item")
            return true
        end
        Undo_BeginBlock()
        if tp.is_mute then
            local muted = display_val < 0.5
            SetMediaTrackInfo_Value(track, "B_MUTE", muted and 1 or 0)
            say(string.format("Set %s: %s", tp.label, muted and "muted" or "unmuted"))
        else
            SetMediaTrackInfo_Value(track, tp.snap_key, display_to_snap_native(tp, display_val))
            if tp.is_vol then
                say(string.format("Set %s to %.1f dB", tp.label, display_val))
            else
                say(string.format("Set %s to %.2f", tp.label, display_val))
            end
        end
        Undo_EndBlock("Set track param: " .. tp.label, -1)
        return false
    end

    local env = ensure_track_envelope(tp)
    if not env then
        say("Could not create " .. tp.label .. " envelope")
        return false
    end

    Undo_BeginBlock()
    local stay = insert_bracket(env, display_to_env_native(tp, display_val), ins_type)
    if stay then
        Undo_EndBlock("", -1)
        return true
    end

    local label = ins_type == "item" and "automation item" or "automation point"
    if tp.is_vol then
        say(string.format("Added %s %s at %.1f dB", tp.label, label, display_val))
    else
        say(string.format("Added %s %s at %.2f", tp.label, label, display_val))
    end
    Undo_EndBlock("Track Automation: " .. tp.label, -1)
    UpdateArrange()
    UpdateTimeline()
    return false
end

---------------------------------------------------------------------

function insert_fx_param(display_val, ins_type)
    local fx_entry    = fx_list[fx_sel]
    local param_entry = param_list[param_sel]
    local fx_raw      = fx_entry.raw_idx
    local param_raw   = param_entry.raw_idx
    local is_norm, lo, hi = get_fx_normalized_info()

    -- For normalized VST/VST3 params, find the 0-1 normalized value whose
    -- formatted output is closest to the user's typed value.
    -- For non-normalized (JSFX/LV2), use display_val directly as the native value.
    local normalized
    if is_norm then
        normalized = find_normalized_for_display(display_val)
    else
        local range = (hi > lo) and (hi - lo) or 1
        normalized = (display_val - lo) / range
    end
    local native = is_norm and normalized or display_val

    Undo_BeginBlock()

    if ins_type == "snapshot" then
        TrackFX_SetParamNormalized(track, fx_raw, param_raw, normalized)
        Undo_EndBlock("Set FX param: " .. fx_entry.name .. " > " .. param_entry.name, -1)
        say(string.format("Set %s to %.3f", param_entry.name, display_val))
        return false
    end

    local env = GetFXEnvelope(track, fx_raw, param_raw, true)
    if not env then
        Undo_EndBlock("", -1)
        say("Could not create automation envelope")
        return false
    end

    local stay = insert_bracket(env, native, ins_type)
    if stay then
        Undo_EndBlock("", -1)
        return true
    end

    local label = ins_type == "item" and "automation item" or "automation point"
    say(string.format("Added %s %s at %.3f", param_entry.name, label, display_val))
    Undo_EndBlock("FX Automation: " .. fx_entry.name .. " > " .. param_entry.name, -1)
    UpdateArrange()
    UpdateTimeline()
    return false
end

---------------------------------------------------------------------

function insert_automation(display_val)
    local ins_type = TYPE_OPTIONS[type_idx]
    if SOURCE_OPTIONS[source_idx] == "track" then
        return insert_track_param(display_val, ins_type)
    else
        return insert_fx_param(display_val, ins_type)
    end
end

---------------------------------------------------------------------

-- Shared digit/dot/backspace handling for value-entry states.
local function handle_digits(char, str_var_getter, str_var_setter)
    local s = str_var_getter()
    if char >= 48 and char <= 57 then
        if #s < 8 then str_var_setter(s .. string.char(char)) end
    elseif char == 46 then
        if not s:find("%.") then str_var_setter(s .. ".") end
    elseif char == KEY_BACK then
        if #s > 0 then
            s = s:sub(1, -2)
            str_var_setter(s)
            say(s ~= "" and s or "cleared")
        end
    end
end

---------------------------------------------------------------------

function handle_key(char)
    if state == STATE_SOURCE then
        if char == KEY_UP or char == KEY_DOWN then
            source_idx = source_idx == 1 and 2 or 1
            say(SOURCE_LABELS[SOURCE_OPTIONS[source_idx]])
        elseif char == KEY_ENTER then
            if SOURCE_OPTIONS[source_idx] == "track" then
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
            return false
        end

    elseif state == STATE_TRACK_PARAM then
        if char == KEY_UP then
            track_param_sel = track_param_sel > 1 and track_param_sel - 1 or #TRACK_PARAMS
            say(TRACK_PARAMS[track_param_sel].label)
        elseif char == KEY_DOWN then
            track_param_sel = track_param_sel < #TRACK_PARAMS and track_param_sel + 1 or 1
            say(TRACK_PARAMS[track_param_sel].label)
        elseif char == KEY_ENTER then
            state = STATE_TYPE
            say(TYPE_LABELS[TYPE_OPTIONS[type_idx]]
                .. ". Up and down to change, Enter to confirm, Escape to go back")
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
            state = STATE_TYPE
            say(TYPE_LABELS[TYPE_OPTIONS[type_idx]]
                .. ". Up and down to change, Enter to confirm, Escape to go back")
        elseif char == KEY_ESC then
            state = STATE_FX
            announce_fx()
        end

    elseif state == STATE_TYPE then
        if char == KEY_UP or char == KEY_LEFT then
            type_idx = type_idx > 1 and type_idx - 1 or #TYPE_OPTIONS
            say(TYPE_LABELS[TYPE_OPTIONS[type_idx]])
        elseif char == KEY_DOWN or char == KEY_RIGHT then
            type_idx = type_idx < #TYPE_OPTIONS and type_idx + 1 or 1
            say(TYPE_LABELS[TYPE_OPTIONS[type_idx]])
        elseif char == KEY_ENTER then
            value_str = ""
            state = STATE_VALUE
            say(get_value_prompt())
        elseif char == KEY_ESC then
            if SOURCE_OPTIONS[source_idx] == "track" then
                state = STATE_TRACK_PARAM
                say(TRACK_PARAMS[track_param_sel].label)
            else
                state = STATE_PARAM
                announce_param()
            end
        end

    elseif state == STATE_VALUE then
        if char >= 48 and char <= 57 then
            if #value_str < 8 then value_str = value_str .. string.char(char) end
        elseif char == 45 then
            if value_str == "" then value_str = "-" end
        elseif char == 46 then
            if not value_str:find("%.") then value_str = value_str .. "." end
        elseif char == KEY_BACK then
            if #value_str > 0 then
                value_str = value_str:sub(1, -2)
                say(value_str ~= "" and value_str or "cleared")
            end
        elseif char == KEY_ENTER then
            local val = tonumber(value_str)
            local min_v, max_v = get_value_range()
            if not val then
                say("Please enter a number")
            elseif val < min_v or val > max_v then
                say(string.format("Please enter a value between %g and %g", min_v, max_v))
            else
                local ins_type = TYPE_OPTIONS[type_idx]
                if ins_type == "snapshot" then
                    local stay = insert_automation(val)
                    if not stay then return false end
                else
                    confirmed_val = val
                    ramp_in_str   = ""
                    state = STATE_RAMP_IN
                    say("Enter ramp in seconds. Enter for no ramp")
                end
            end
        elseif char == KEY_ESC then
            state = STATE_TYPE
            say(TYPE_LABELS[TYPE_OPTIONS[type_idx]])
        end

    elseif state == STATE_RAMP_IN then
        if char >= 48 and char <= 57 then
            if #ramp_in_str < 8 then ramp_in_str = ramp_in_str .. string.char(char) end
        elseif char == 46 then
            if not ramp_in_str:find("%.") then ramp_in_str = ramp_in_str .. "." end
        elseif char == KEY_BACK then
            if #ramp_in_str > 0 then
                ramp_in_str = ramp_in_str:sub(1, -2)
                say(ramp_in_str ~= "" and ramp_in_str or "cleared")
            end
        elseif char == KEY_ENTER then
            ramp_in_secs  = math.max(0, tonumber(ramp_in_str) or 0)
            ramp_out_str  = ""
            state = STATE_RAMP_OUT
            say("Enter ramp out seconds. Enter for no ramp")
        elseif char == KEY_ESC then
            state = STATE_VALUE
            say(get_value_prompt())
        end

    elseif state == STATE_RAMP_OUT then
        if char >= 48 and char <= 57 then
            if #ramp_out_str < 8 then ramp_out_str = ramp_out_str .. string.char(char) end
        elseif char == 46 then
            if not ramp_out_str:find("%.") then ramp_out_str = ramp_out_str .. "." end
        elseif char == KEY_BACK then
            if #ramp_out_str > 0 then
                ramp_out_str = ramp_out_str:sub(1, -2)
                say(ramp_out_str ~= "" and ramp_out_str or "cleared")
            end
        elseif char == KEY_ENTER then
            ramp_out_secs = math.max(0, tonumber(ramp_out_str) or 0)
            local stay = insert_automation(confirmed_val)
            if not stay then return false end
        elseif char == KEY_ESC then
            state = STATE_RAMP_IN
            say("Enter ramp in seconds. Enter for no ramp")
        end
    end

    return true
end

---------------------------------------------------------------------

function main()
    local char = gfx.getchar()
    if char == -1 then
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

---------------------------------------------------------------------

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then modifier = "Cmd" end
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.",
        "ReaClassical Error", 0)
    return
end

track = GetSelectedTrack(0, 0)
if not track then
    say("No track selected")
    return
end

init_fx_list()

gfx.init("Accessible Automation Navigator", 480, 44, 0)

say("Accessible Automation Navigator. "
    .. SOURCE_LABELS[SOURCE_OPTIONS[source_idx]]
    .. ". Up and down to browse, Enter to select, Escape to close")

defer(main)
