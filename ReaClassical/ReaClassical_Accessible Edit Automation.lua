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
local au  = require("ReaClassical_Automation_Info")

local db_to_linear     = au.db_to_linear
local linear_to_db     = au.linear_to_db
local is_special_track = au.is_special_track
local find_env_info    = au.find_env_info
local is_vol_env       = au.is_vol_env
local raw_to_display   = au.raw_to_display
local format_display   = au.format_display
local get_track_label  = au.get_track_label

---------------------------------------------------------------------
-- State machine

local STATE_PICK     = "pick"
local STATE_ACTION   = "action"
local STATE_VALUE    = "value"
local STATE_RAMP_IN  = "rampin"
local STATE_RAMP_OUT = "rampout"

local ACTIONS = { "Edit", "Delete" }

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27
local KEY_BACK  = 8

local state     = STATE_PICK
local found     = {}
local pick_idx  = 1
local item      = nil
local action_idx = 1
local value_str = ""
local ri_str    = ""
local ro_str    = ""
local last_char = 0

local new_display_val = nil
local new_ramp_in     = nil
local new_ramp_out    = nil

---------------------------------------------------------------------
-- Utility

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
    -- Returns a getter function for boundary values
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

---------------------------------------------------------------------
-- Scan all special tracks for automation items under the edit cursor

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
                                    orig_ri     = ri,
                                    orig_ro     = ro,
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

---------------------------------------------------------------------

local function get_value_prompt()
    return "Value " .. format_display(item.env_info, item.display_val)
        .. ". Enter new value or press Enter to keep"
end

---------------------------------------------------------------------

-- Deselects every automation item project-wide so the global delete
-- command (42086) only removes the one item we select afterward.
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

---------------------------------------------------------------------

local function delete_item()
    deselect_all_automation_items()
    GetSetAutomationItemInfo(item.env, item.ai_idx, "D_UISEL", 1, true)
    Main_OnCommand(42086, 0) -- Envelope: Delete automation items
    UpdateArrange()
    say("Deleted " .. item.label)
end

---------------------------------------------------------------------

local function apply_edit()
    local env      = item.env
    local ei       = item.env_info
    local track    = item.track
    local pos      = item.ai_pos
    local len      = item.ai_len

    -- Stable middle section is defined by the ORIGINAL ramp widths
    local mid_start = pos + item.orig_ri
    local mid_end   = pos + len - item.orig_ro

    local target_raw = display_to_raw(ei, new_display_val)
    local vb = item.orig_before
    local va = item.orig_after

    deselect_all_automation_items()
    GetSetAutomationItemInfo(env, item.ai_idx, "D_UISEL", 1, true)
    Main_OnCommand(42086, 0)

    -- Clear full affected range
    local new_start = mid_start - new_ramp_in
    local new_end   = mid_end   + new_ramp_out
    DeleteEnvelopePointRange(env,
        math.min(new_start, pos) - 0.002,
        math.max(new_end, pos + len) + 0.002)

    -- Scale for volume if envelope mode requires it
    local scale = is_vol_env(ei)
    local tgt = scale and ScaleToEnvelopeMode(1, target_raw) or target_raw
    local b   = scale and ScaleToEnvelopeMode(1, vb)         or vb
    local a   = scale and ScaleToEnvelopeMode(1, va)         or va

    if new_ramp_in > 0 then
        InsertEnvelopePoint(env, new_start,        b,   0, 0, false, true)
        InsertEnvelopePoint(env, mid_start,         tgt, 0, 0, false, true)
    else
        InsertEnvelopePoint(env, mid_start,         b,   0, 0, false, true)
        InsertEnvelopePoint(env, mid_start + 0.001, tgt, 0, 0, false, true)
    end

    if new_ramp_out > 0 then
        InsertEnvelopePoint(env, mid_end,           tgt, 0, 0, false, true)
        InsertEnvelopePoint(env, new_end,            a,   0, 0, false, true)
    else
        InsertEnvelopePoint(env, mid_end - 0.001,   tgt, 0, 0, false, true)
        InsertEnvelopePoint(env, mid_end,            a,   0, 0, false, true)
    end

    Envelope_SortPoints(env)
    InsertAutomationItem(env, -1, new_start, new_end - new_start)

    -- Show track in TCP and sync Mission Control extstate
    SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
    local _, ms   = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
    local _, guid = GetSetMediaTrackInfo_String(track, "GUID", "", false)
    local mc_key  = (ms == "y") and ("mixer_tcp_visible_" .. guid) or ("tcp_visible_" .. guid)
    SetProjExtState(0, "ReaClassical_MissionControl", mc_key, "1")
    TrackList_AdjustWindows(false)
    UpdateArrange()

    local pname  = ei.type == "track" and ei.name or (ei.fx_name .. ": " .. ei.name)
    local ri_msg = new_ramp_in  > 0 and string.format(", ramp in %.1fs",  new_ramp_in)  or ""
    local ro_msg = new_ramp_out > 0 and string.format(", ramp out %.1fs", new_ramp_out) or ""
    say(string.format("Updated %s to %s%s%s", pname,
        format_display(ei, new_display_val), ri_msg, ro_msg))
end

---------------------------------------------------------------------

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_PICK then
        gfx.drawstr(#found == 0 and "No automation items at cursor"
                                  or "[Select]  " .. found[pick_idx].label)
    elseif state == STATE_ACTION then
        gfx.drawstr("[Edit/Delete]  " .. ACTIONS[action_idx])
    elseif state == STATE_VALUE then
        gfx.drawstr("[Value]  " .. (value_str == "" and "(keep)" or value_str))
    elseif state == STATE_RAMP_IN then
        gfx.drawstr("[Ramp in]  " .. (ri_str == "" and "(keep)" or ri_str .. "s"))
    elseif state == STATE_RAMP_OUT then
        gfx.drawstr("[Ramp out]  " .. (ro_str == "" and "(keep)" or ro_str .. "s"))
    end
    gfx.update()
end

---------------------------------------------------------------------

-- Shared digit/dot/backspace handling for value-entry states. Announces
-- each typed character and each backspaced-away character, same as the
-- Accessible DDP Metadata Editor. Returns true if char was consumed.
local function handle_digits(char, getter, setter)
    local s = getter()
    if char >= 48 and char <= 57 then
        if #s < 8 then
            local ch = string.char(char)
            setter(s .. ch)
            say(ch)
        end
        return true
    elseif char == 46 then
        if not s:find("%.") then
            setter(s .. ".")
            say(".")
        end
        return true
    elseif char == KEY_BACK then
        if #s > 0 then
            local deleted = s:sub(-1)
            setter(s:sub(1, -2))
            say(deleted)
        end
        return true
    end
    return false
end

---------------------------------------------------------------------

local function handle_key(char)
    if state == STATE_PICK then
        if #found == 0 then
            if char == KEY_ESC or char == KEY_ENTER then return false end
            return true
        end
        if char == KEY_UP then
            pick_idx = pick_idx > 1 and pick_idx - 1 or #found
            say(found[pick_idx].label)
        elseif char == KEY_DOWN then
            pick_idx = pick_idx < #found and pick_idx + 1 or 1
            say(found[pick_idx].label)
        elseif char == KEY_ENTER then
            item       = found[pick_idx]
            action_idx = 1
            state      = STATE_ACTION
            say("Edit or delete " .. item.label .. "? Up or down to choose, Enter to confirm")
        elseif char == KEY_ESC then
            return false
        end

    elseif state == STATE_ACTION then
        if char == KEY_UP or char == KEY_DOWN then
            action_idx = action_idx == 1 and 2 or 1
            say(ACTIONS[action_idx])
        elseif char == KEY_ENTER then
            if action_idx == 1 then
                value_str = ""
                state     = STATE_VALUE
                say(get_value_prompt())
            else
                Undo_BeginBlock()
                delete_item()
                Undo_EndBlock("Delete Automation Item", -1)
                return false
            end
        elseif char == KEY_ESC then
            state = STATE_PICK
            say(found[pick_idx].label)
        end

    elseif state == STATE_VALUE then
        if char == 45 then
            if value_str == "" then
                value_str = "-"
                say("-")
            end
        elseif handle_digits(char,
            function() return value_str end,
            function(v) value_str = v end) then
            -- handled by handle_digits
        elseif char == KEY_ENTER then
            if value_str == "" then
                new_display_val = item.display_val
            else
                local v = tonumber(value_str)
                if not v then say("Please enter a number") return true end
                if v < item.disp_min or v > item.disp_max then
                    say(string.format("Enter a value between %g and %g",
                        item.disp_min, item.disp_max))
                    return true
                end
                new_display_val = v
            end
            ri_str = ""
            state  = STATE_RAMP_IN
            say(string.format("Ramp in %.1f seconds. Enter new value or press Enter to keep", item.ramp_in))
        elseif char == KEY_ESC then
            state = STATE_PICK
            say(found[pick_idx].label)
        end

    elseif state == STATE_RAMP_IN then
        if handle_digits(char,
            function() return ri_str end,
            function(v) ri_str = v end) then
            -- handled by handle_digits
        elseif char == KEY_ENTER then
            new_ramp_in = ri_str == "" and item.ramp_in
                                        or math.max(0, tonumber(ri_str) or 0)
            ro_str = ""
            state  = STATE_RAMP_OUT
            say(string.format("Ramp out %.1f seconds. Enter new value or press Enter to keep", item.ramp_out))
        elseif char == KEY_ESC then
            state = STATE_VALUE
            say(get_value_prompt())
        end

    elseif state == STATE_RAMP_OUT then
        if handle_digits(char,
            function() return ro_str end,
            function(v) ro_str = v end) then
            -- handled by handle_digits
        elseif char == KEY_ENTER then
            new_ramp_out = ro_str == "" and item.ramp_out
                                         or math.max(0, tonumber(ro_str) or 0)
            Undo_BeginBlock()
            apply_edit()
            Undo_EndBlock("Edit Automation Item", -1)
            return false
        elseif char == KEY_ESC then
            state = STATE_RAMP_IN
            say(string.format("Ramp in %.1f seconds. Enter new value or press Enter to keep", item.ramp_in))
        end
    end

    return true
end

---------------------------------------------------------------------

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

---------------------------------------------------------------------

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

gfx.init("Accessible Edit Automation", 600, 44, 0)

if #found == 1 then
    item       = found[1]
    action_idx = 1
    state      = STATE_ACTION
    say("Edit or delete " .. item.label .. "? Up or down to choose, Enter to confirm")
else
    say(string.format(
        "%d automation items at cursor. Up and down to browse, Enter to select, Escape to close. %s",
        #found, found[1].label))
end

defer(main)
