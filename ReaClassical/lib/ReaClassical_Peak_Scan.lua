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

local M = {}

local PEAK_RATE = 100
local LN10 = math.log(10)
local MAX_PEAK_ARRAY_ELEMENTS = 16000
local AUTOMODE_TRIM_READ = 0
local AUTOMODE_BYPASS = 6

function M.is_rcmaster(track)
    local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return rcmaster_state == "y" or name:find("^RCMASTER") ~= nil
end

local function env_in_use(env)
    if not env then return false end
    local _, active = GetSetEnvelopeInfo_String(env, "ACTIVE", "", false)
    if active == "0" then return false end
    return CountEnvelopePoints(env) > 0 or CountAutomationItems(env) > 0
end

local function automation_mode(track)
    local override = GetGlobalAutomationOverride()
    if override and override >= 0 then return override end
    return GetMediaTrackInfo_Value(track, "I_AUTOMODE")
end

local function env_stage(env, static_mult)
    return { env = env, scale = GetEnvelopeScalingMode(env), mult = static_mult }
end

local function fader_stages(track, fader_value, env)
    local mode = automation_mode(track)
    if mode ~= AUTOMODE_BYPASS and env_in_use(env) then
        local mult = mode == AUTOMODE_TRIM_READ and fader_value or 1.0
        return { env_stage(env, mult) }
    end
    return { { value = fader_value } }
end

local function track_stages(track)
    local stages = fader_stages(track, GetMediaTrackInfo_Value(track, "D_VOL"),
        GetTrackEnvelopeByName(track, "Volume"))
    if automation_mode(track) ~= AUTOMODE_BYPASS then
        for _, name in ipairs({ "Volume (Pre-FX)", "Trim Volume" }) do
            local env = GetTrackEnvelopeByName(track, name)
            if env_in_use(env) then stages[#stages + 1] = env_stage(env, 1.0) end
        end
    end
    return stages
end

local function concat(a, b)
    local out = {}
    for _, s in ipairs(a) do out[#out + 1] = s end
    for _, s in ipairs(b) do out[#out + 1] = s end
    return out
end

local function master_stages()
    local master = GetMasterTrack(0)
    if GetMediaTrackInfo_Value(master, "B_MUTE") == 1 then return nil end
    return track_stages(master)
end

local function build_paths(track, visited)
    if visited[track] then return {} end
    if GetMediaTrackInfo_Value(track, "B_MUTE") == 1 then return {} end

    local own = track_stages(track)

    if M.is_rcmaster(track) then
        if GetMediaTrackInfo_Value(track, "B_MAINSEND") == 1 then
            local m = master_stages()
            if not m then return {} end
            return { concat(own, m) }
        end
        return { own }
    end

    local next_visited = {}
    for k in pairs(visited) do next_visited[k] = true end
    next_visited[track] = true

    local paths = {}
    local routed = false

    for s = 0, GetTrackNumSends(track, 0) - 1 do
        local dest = BR_GetMediaTrackSendInfo_Track(track, 0, s, 1)
        if dest then
            routed = true
            if GetTrackSendInfo_Value(track, 0, s, "B_MUTE") == 0 then
                local send_env = BR_GetMediaTrackSendInfo_Envelope(track, 0, s, 0)
                local send = fader_stages(track, GetTrackSendInfo_Value(track, 0, s, "D_VOL"), send_env)
                for _, p in ipairs(build_paths(dest, next_visited)) do
                    paths[#paths + 1] = concat(own, concat(send, p))
                end
            end
        end
    end

    if GetMediaTrackInfo_Value(track, "B_MAINSEND") == 1 then
        routed = true
        local parent = GetParentTrack(track)
        if parent then
            for _, p in ipairs(build_paths(parent, next_visited)) do
                paths[#paths + 1] = concat(own, p)
            end
        else
            local m = master_stages()
            if m then paths[#paths + 1] = concat(own, m) end
        end
    end

    if not routed then return { own } end
    return paths
end

local function compile_path(stages)
    local const = 1.0
    local envs = {}
    for _, s in ipairs(stages) do
        if s.env then
            const = const * s.mult
            envs[#envs + 1] = s
        else
            const = const * s.value
        end
    end
    return { const = const, envs = envs }
end

function M.chain_gain(track)
    local paths = build_paths(track, {})
    if #paths == 0 then return nil end

    local compiled = {}
    local all_static = true
    local best_static = 0
    for _, p in ipairs(paths) do
        local c = compile_path(p)
        compiled[#compiled + 1] = c
        if #c.envs > 0 then
            all_static = false
        elseif c.const > best_static then
            best_static = c.const
        end
    end

    if all_static then return { static = best_static } end
    return { paths = compiled }
end

function M.gain_at(gain, pos)
    if gain.static then return gain.static end
    local best = 0
    for _, p in ipairs(gain.paths) do
        local g = p.const
        for _, s in ipairs(p.envs) do
            local _, v = Envelope_Evaluate(s.env, pos, 0, 0)
            g = g * ScaleFromEnvelopeMode(s.scale, v)
        end
        if g > best then best = g end
    end
    return best
end

function M.scan_item(item, gain, on_sample)
    if GetMediaItemInfo_Value(item, "B_MUTE") == 1 then return end

    local take = GetActiveTake(item)
    if not take or TakeIsMIDI(take) then return end

    local source = GetMediaItemTake_Source(take)
    if not source then return end

    local num_channels = math.max(1, GetMediaSourceNumChannels(source))
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = GetMediaItemInfo_Value(item, "D_LENGTH")
    local playrate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    local start_offs = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local item_vol = GetMediaItemInfo_Value(item, "D_VOL")
    local take_vol = GetMediaItemTakeInfo_Value(take, "D_VOL")
    local base_gain = item_vol * take_vol

    if playrate <= 0 or item_len <= 0 then return end

    local total_samples = math.floor(item_len * playrate * PEAK_RATE + 0.5)
    if total_samples < 1 then return end

    local vol_env = GetTakeEnvelopeByName(take, "Volume")
    local br_vol_env = vol_env and APIExists("CF_GetSWSVersion") and BR_EnvAlloc(vol_env, false) or nil

    local chunk_samples = math.max(1, math.floor(MAX_PEAK_ARRAY_ELEMENTS / (2 * num_channels)))
    local buf = new_array(2 * chunk_samples * num_channels)

    local samples_done = 0
    while samples_done < total_samples do
        local this_count = math.min(chunk_samples, total_samples - samples_done)
        local chunk_start_offs = start_offs + samples_done / PEAK_RATE
        local frame_count = num_channels * this_count
        local retval = PCM_Source_GetPeaks(source, PEAK_RATE, chunk_start_offs, num_channels, this_count, 0, buf)
        local vals = buf.table(1, 2 * frame_count)

        local returned = retval & 0xFFFFF
        if returned <= 0 or returned > this_count then
            returned = this_count
        end

        for f = 1, returned do
            local peak = 0
            local base = (f - 1) * num_channels
            for c = 1, num_channels do
                local idx = base + c
                local v = math.max(math.abs(vals[idx]), math.abs(vals[frame_count + idx]))
                if v > peak then peak = v end
            end

            local abs_f = samples_done + f
            local pos = item_pos + (abs_f - 1) / (PEAK_RATE * playrate)
            local env_gain = br_vol_env and BR_EnvValueAtPos(br_vol_env, pos) or 1.0
            peak = peak * base_gain * env_gain * M.gain_at(gain, pos)

            local db = peak > 0 and (20 * math.log(peak) / LN10) or -150
            on_sample(pos, db)
        end

        samples_done = samples_done + this_count
    end

    if br_vol_env then BR_EnvFree(br_vol_env, false) end
end

return M
