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

---------------------------------------------------------------------
-- Shared parameter naming/scaling helpers for ReaClassical's special-track
-- automation (track and FX-param envelopes). Used by both the accessible
-- automation editor and the lane-free automation navigation scripts so
-- their announcements describe the same parameter the same way.

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

local function find_env_info(track, env)
    local STANDARD = {
        "Volume", "Pan", "Width", "Volume (Pre-FX)",
        "Pan (Pre-FX)", "Width (Pre-FX)", "Trim Volume", "Mute"
    }
    for _, name in ipairs(STANDARD) do
        if GetTrackEnvelopeByName(track, name) == env then
            return { type = "track", name = name }
        end
    end
    for fx = 0, TrackFX_GetCount(track) - 1 do
        for p = 0, TrackFX_GetNumParams(track, fx) - 1 do
            if GetFXEnvelope(track, fx, p, false) == env then
                local _, fx_name = TrackFX_GetFXName(track, fx, "")
                local _, pname   = TrackFX_GetParamName(track, fx, p, "")
                return { type = "fx", fx_idx = fx, param_idx = p,
                         name = pname, fx_name = fx_name }
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
            return -(raw * 100)   -- envelope inverted; display +100 = right
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
    return string.format("%.4g", dval)
end

local function get_track_label(track)
    local _, nm = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if nm and nm ~= "" then
        return nm:match("^M:(.+)") or nm
    end
    return "Track " .. math.floor(GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
end

---------------------------------------------------------------------

return {
    db_to_linear    = db_to_linear,
    linear_to_db    = linear_to_db,
    is_special_track = is_special_track,
    find_env_info   = find_env_info,
    is_vol_env      = is_vol_env,
    raw_to_display  = raw_to_display,
    format_display  = format_display,
    get_track_label = get_track_label,
}
