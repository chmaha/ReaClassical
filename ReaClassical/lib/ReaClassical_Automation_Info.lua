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

local function db_to_linear(db)
    if db <= -150 then return 0.0 end
    return 10 ^ (db / 20)
end

local function linear_to_db(val)
    if val <= 0.0000000298023223876953125 then return -150.0 end
    return 20 * math.log(val, 10)
end

local function is_special_track(t)
    local checks = {
        "P_EXT:mixer", "P_EXT:rcmaster", "P_EXT:aux", "P_EXT:submix",
        "P_EXT:roomtone", "P_EXT:rcref", "P_EXT:live", "P_EXT:listenback"
    }
    for _, key in ipairs(checks) do
        local _, v = GetSetMediaTrackInfo_String(t, key, "", false)
        if v == "y" then return true end
    end
    local _, nm = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
    nm = nm or ""
    return nm:match("^M:") or nm:match("^RCMASTER") or
           nm:match("^@")  or nm:match("^#")
end

local function is_folder_track(t)
    if not t then return false end
    return GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1
end

local function get_parent_folder(t)
    if not t then return nil end
    local track_idx = GetMediaTrackInfo_Value(t, "IP_TRACKNUMBER") - 1
    for i = track_idx - 1, 0, -1 do
        local prev = GetTrack(0, i)
        if not prev then break end
        if GetMediaTrackInfo_Value(prev, "I_FOLDERDEPTH") == 1 then return prev end
    end
    return nil
end

local function is_destination_track(t)
    if not t then return false end
    local folder = is_folder_track(t) and t or get_parent_folder(t)
    if not folder then return false end
    local _, is_dest = GetSetMediaTrackInfo_String(folder, "P_EXT:destination", "", false)
    return is_dest == "y"
end

local function is_automation_track(t)
    return is_special_track(t) or is_destination_track(t)
end

local function get_destination_source(mixer_track)
    if not mixer_track then return nil end
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if is_destination_track(t) then
            for s = 0, GetTrackNumSends(t, 0) - 1 do
                local dest = GetTrackSendInfo_Value(t, 0, s, "P_DESTTRACK")
                if dest == mixer_track then return t end
            end
        end
    end
    return nil
end

local function get_mixer_target(track)
    if not track then return nil end
    for s = 0, GetTrackNumSends(track, 0) - 1 do
        local dest = GetTrackSendInfo_Value(track, 0, s, "P_DESTTRACK")
        if dest and is_special_track(dest) then return dest end
    end
    return nil
end

local function find_env_info(track, env)
    local STANDARD = {
        "Volume", "Pan", "Width", "Volume (Pre-FX)",
        "Pan (Pre-FX)", "Width (Pre-FX)", "Trim Volume", "Mute"
    }
    for _, name in ipairs(STANDARD) do
        if GetTrackEnvelopeByName(track, name) == env then
            return { type = "track", name = name, track = track }
        end
    end
    for fx = 0, TrackFX_GetCount(track) - 1 do
        for p = 0, TrackFX_GetNumParams(track, fx) - 1 do
            if GetFXEnvelope(track, fx, p, false) == env then
                local _, fx_name = TrackFX_GetFXName(track, fx, "")
                local _, pname   = TrackFX_GetParamName(track, fx, p, "")
                return { type = "fx", fx_idx = fx, param_idx = p,
                         name = pname, fx_name = fx_name, track = track }
            end
        end
    end
    return nil
end

local function is_vol_env(env_info)
    if env_info.type ~= "track" then return false end
    local n = env_info.name
    return n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume"
end

local function raw_to_display(env_info, raw)
    if env_info.type == "track" then
        local n = env_info.name
        if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
            return linear_to_db(raw)
        elseif n == "Pan" or n == "Pan (Pre-FX)" then
            return -(raw * 100)
        elseif n == "Width" or n == "Width (Pre-FX)" then
            return raw * 100
        end
    end
    return raw
end

local function format_display(env_info, dval)
    if env_info.type == "track" then
        local n = env_info.name
        if n == "Volume" or n == "Volume (Pre-FX)" or n == "Trim Volume" then
            return string.format("%.1f dB", dval)
        elseif n == "Pan" or n == "Pan (Pre-FX)" then
            if dval > 0.05 then return string.format("%.0fR", dval)
            elseif dval < -0.05 then return string.format("%.0fL", -dval)
            else return "C" end
        elseif n == "Width" or n == "Width (Pre-FX)" then
            return string.format("%.0f%%", dval)
        elseif n == "Mute" then
            return dval < 0.5 and "muted" or "unmuted"
        end
    end
    local track = env_info.track
    local old_val = TrackFX_GetParam(track, env_info.fx_idx, env_info.param_idx)
    TrackFX_SetParam(track, env_info.fx_idx, env_info.param_idx, dval)
    local _, fmt = TrackFX_GetFormattedParamValue(track, env_info.fx_idx, env_info.param_idx, "")
    TrackFX_SetParam(track, env_info.fx_idx, env_info.param_idx, old_val)
    return fmt
end

local function get_track_label(track)
    local _, nm = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if nm and nm ~= "" then
        return nm:match("^M:(.+)") or nm
    end
    return "Track " .. math.floor(GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
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

local function get_fx_range(track, fx_idx, param_idx)
    local _, minval, maxval = TrackFX_GetParam(track, fx_idx, param_idx)
    if minval > maxval then minval, maxval = maxval, minval end
    return minval, maxval
end

local function classify_fx_range(track, fx_idx, param_idx)
    local minval, maxval = get_fx_range(track, fx_idx, param_idx)
    local old_val = TrackFX_GetParam(track, fx_idx, param_idx)

    local low_fmt, high_fmt
    local low_num, high_num
    local low_t, high_t = minval, maxval
    local any_numeric = false

    for i = 0, 50 do
        local t = minval + (maxval - minval) * (i / 50)
        TrackFX_SetParam(track, fx_idx, param_idx, t)
        local _, s = TrackFX_GetFormattedParamValue(track, fx_idx, param_idx, "")
        if i == 0  then low_fmt  = s end
        if i == 50 then high_fmt = s end
        local n = parse_fmt_number(s)
        if n then
            any_numeric = true
            if not low_num then low_num, low_t = n, t end
            high_num, high_t = n, t
        end
    end

    TrackFX_SetParam(track, fx_idx, param_idx, old_val)

    return {
        low_label   = (not parse_fmt_number(low_fmt))  and low_fmt  or nil,
        high_label  = (not parse_fmt_number(high_fmt)) and high_fmt or nil,
        low_fmt = low_fmt, high_fmt = high_fmt,
        low_num = low_num,   low_t  = low_t,
        high_num = high_num, high_t = high_t,
        any_numeric = any_numeric,
        minval = minval, maxval = maxval,
    }
end

local function fx_value_prompt(param_name, r)
    if r.low_label or r.high_label then
        local words = {}
        if r.low_label  then words[#words + 1] = r.low_label  end
        if r.high_label then words[#words + 1] = r.high_label end
        local word_str = table.concat(words, " or ")
        if r.any_numeric then
            return string.format("Enter a value for %s, between %g and %g, or type %s.",
                param_name, r.low_num or r.minval, r.high_num or r.maxval, word_str)
        end
        return string.format("No numeric scale for %s. Type %s.", param_name, word_str)
    end
    return string.format("Enter a value for %s, between %s and %s.", param_name, r.low_fmt, r.high_fmt)
end

local function find_fx_raw_for_display(track, fx_idx, param_idx, display_num)
    local minval, maxval = get_fx_range(track, fx_idx, param_idx)
    local old_val = TrackFX_GetParam(track, fx_idx, param_idx)
    local best_val, best_diff = minval, math.huge
    local STEPS = 500
    for i = 0, STEPS do
        local test_val = minval + (maxval - minval) * (i / STEPS)
        TrackFX_SetParam(track, fx_idx, param_idx, test_val)
        local _, test_str = TrackFX_GetFormattedParamValue(track, fx_idx, param_idx, "")
        local test_num = parse_fmt_number(test_str)
        if test_num and math.abs(test_num - display_num) < best_diff then
            best_diff = math.abs(test_num - display_num)
            best_val = test_val
        end
    end
    TrackFX_SetParam(track, fx_idx, param_idx, old_val)
    return best_val
end

return {
    db_to_linear    = db_to_linear,
    linear_to_db    = linear_to_db,
    is_special_track = is_special_track,
    is_destination_track = is_destination_track,
    is_automation_track  = is_automation_track,
    get_destination_source = get_destination_source,
    get_mixer_target      = get_mixer_target,
    find_env_info   = find_env_info,
    is_vol_env      = is_vol_env,
    raw_to_display  = raw_to_display,
    format_display  = format_display,
    get_track_label = get_track_label,
    parse_fmt_number     = parse_fmt_number,
    get_fx_range         = get_fx_range,
    classify_fx_range    = classify_fx_range,
    fx_value_prompt      = fx_value_prompt,
    find_fx_raw_for_display = find_fx_raw_for_display,
}
