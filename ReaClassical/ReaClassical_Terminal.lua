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
local humanize_track_name = require("ReaClassical_Track_Naming")
local humanize_timestr = require("ReaClassical_Time_Naming")

local workflow = ""

---------------------------------------------------------------------
-- Word lists (ported from ReaClassical_Mission Control.lua)
---------------------------------------------------------------------

local pair_words = {
    "2ch", "pair", "paire", "paar", "coppia", "par", "para", "пара", "对", "ペア",
    "쌍", "زوج", "pari", "пар", "πάρoς", "двойка", "קבוצה", "çift",
    "pár", "pāris", "pora", "jozi", "जोड़ी", "คู่", "pasang", "cặp",
    "stereo", "stéréo", "estéreo", "立体声", "ステレオ", "스테레오",
    "ستيريو", "στερεοφωνικός", "סטריאו", "stereotipas", "स्टीरियो",
    "สเตอริโอ", "âm thanh nổi", "paarig", "doppel", "duo"
}

local left_words = {
    "l", "left", "gauche", "sinistra", "izquierda", "esquerda", "ліворуч", "слева", "vlevo", "balra", "vänster",
    "vasakule", "venstre", "vänstra", "levý", "левый", "lijevo", "stânga", "sol", "kushoto", "ซ้าย", "बाएँ", "बायां",
    "links", "linke", "lewa", "lewy", "lewe", "lewo"
}

local right_words = {
    "r", "right", "droite", "destra", "derecha", "direita", "праворуч", "справа", "vpravo", "jobbra", "höger",
    "paremale", "høyre", "högra", "pravý", "правый", "desno", "dreapta", "sağ", "kulia", "ขวา", "दाएँ", "दायां",
    "rechts", "rechte", "prawa", "prawy", "prawe", "prawo"
}

local RANK_LETTERS = { e = 1, v = 2, g = 3, o = 4, b = 5, p = 6, u = 7, f = 8, n = 9 }

local RANK_PREFIXES = {
    "Excellent", "Very Good", "Good", "OK", "Below Average", "Poor", "Unusable", "False Start", ""
}

---------------------------------------------------------------------
-- Output
---------------------------------------------------------------------

local say = require("ReaClassical_Announce")

---------------------------------------------------------------------
-- Generic helpers
---------------------------------------------------------------------

function trackname_check(track, pattern)
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return string.find(name, pattern)
end

function clamp(value, lo, hi)
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Speaks recorded take/item names without their zero-padding, mirroring
-- announce_current_item() (Next/Previous Item or Fade.lua): "008" -> "Take
-- 8", "Beethoven_T006" -> "Beethoven take 6". Anything else (a manually
-- typed item name) passes through unchanged.
function humanize_item_name(name)
    if not name or name == "" then return name end
    local prefix, take_num = name:match("^(.+)_T(%d+)$")
    if take_num then
        return prefix .. " take " .. tonumber(take_num)
    end
    local only_num = name:match("^(%d+)$")
    if only_num then
        return "Take " .. tonumber(only_num)
    end
    return name
end

---------------------------------------------------------------------
-- dB / pan helpers (ported from ReaClassical_Edit Automation.lua)
---------------------------------------------------------------------

function linear_to_db(val)
    if val <= 0.0000000298023223876953125 then
        return -150.0
    end
    return 20 * math.log(val, 10)
end

function db_to_linear(db)
    if db <= -150 then
        return 0.0
    end
    return 10 ^ (db / 20)
end

function format_pan(panVal)
    if math.abs(panVal) < 0.01 then
        return "C"
    elseif panVal < 0 then
        return tostring(math.floor(-panVal * 100 + 0.5)) .. "L"
    else
        return tostring(math.floor(panVal * 100 + 0.5)) .. "R"
    end
end

-- Parses a percentage string such as "+25", "-5" or "0" into a linear
-- pan value in the range -1..1.
function pct_to_pan(str)
    local n = tonumber(str)
    if not n then return nil end
    return clamp(n / 100, -1, 1)
end

-- Peak hold readout for a single track, matching the navigation scripts'
-- format_peak() (and rec.levels?'s reading of REAPER's own peak hold, not
-- cleared -- clearing would also reset the visible Meterbridge hold line).
function format_track_peak(track)
    local peak = -150.0
    local num_chans = math.min(GetMediaTrackInfo_Value(track, "I_NCHAN"), 2)
    for ch = 0, num_chans - 1 do
        local val = Track_GetPeakHoldDB(track, ch, false) * 100
        if val > peak then peak = val end
    end
    if peak <= -150.0 then return "silence" end
    return string.format("%.1f dB", peak)
end

---------------------------------------------------------------------
-- Track enumeration (ported from ReaClassical_Mission Control.lua
-- and ReaClassical_Vertical Workflow.lua)
---------------------------------------------------------------------

function get_rcmaster()
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        if state == "y" or trackname_check(track, "^RCMASTER") then
            return track, i
        end
    end
    return nil
end

-- Port of create_mixer_table() (Mission Control.lua) returning a plain,
-- track-order array of "M:" mixer tracks. Index N == "mixer track N".
function get_mixer_tracks()
    local tracks = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if state == "y" then
            table.insert(tracks, track)
        end
    end
    return tracks
end

-- Port of get_special_tracks() (Mission Control.lua:2277-2375)
function get_special_tracks()
    local tracks = {}

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)

        if aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y"
            or live_state == "y" or rcmaster_state == "y" or listenback_state == "y" then
            local track_type = "other"
            local has_routing = false

            if aux_state == "y" then
                track_type = "aux"
                has_routing = true
            elseif submix_state == "y" then
                track_type = "submix"
                has_routing = true
            elseif rt_state == "y" then
                track_type = "roomtone"
            elseif ref_state == "y" then
                track_type = "reference"
            elseif live_state == "y" then
                track_type = "live"
            elseif listenback_state == "y" then
                track_type = "listenback"
            elseif rcmaster_state == "y" then
                track_type = "rcmaster"
            end

            local _, rcm_disconnect = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
            local has_hyphen = (rcm_disconnect == "y")

            local display_name
            if track_type == "aux" or track_type == "submix" then
                display_name = name:gsub("^[@#]:?", ""):gsub("%-$", "")
            elseif track_type == "reference" then
                display_name = name:gsub("^REF:?", ""):gsub("%-$", "")
            elseif track_type == "roomtone" then
                display_name = ""
            elseif track_type == "live" then
                display_name = ""
            elseif track_type == "listenback" then
                display_name = ""
            elseif track_type == "rcmaster" then
                display_name = ""
            else
                display_name = name:gsub("%-$", "")
            end

            table.insert(tracks, {
                track = track,
                name = display_name,
                full_name = name,
                type = track_type,
                has_hyphen = has_hyphen,
                has_routing = has_routing,
                index = i
            })
        end
    end

    local type_priority = {
        aux = 1,
        submix = 2,
        roomtone = 3,
        rcmaster = 4,
        live = 5,
        reference = 6,
        listenback = 7
    }

    table.sort(tracks, function(a, b)
        local priority_a = type_priority[a.type] or 99
        local priority_b = type_priority[b.type] or 99
        if priority_a ~= priority_b then
            return priority_a < priority_b
        else
            return a.index < b.index
        end
    end)

    return tracks
end

-- type is "aux" or "submix" (etc.), preserving original track order
function get_special_tracks_by_type(t)
    local result = {}
    for _, info in ipairs(get_special_tracks()) do
        if info.type == t then
            table.insert(result, info)
        end
    end
    return result
end

-- Resolves a 1-based index into a list of special tracks (aux/submix/
-- reference/etc.). If num_str is "" (no index given), succeeds only when
-- exactly one track of that type exists in the project; if more than one
-- exists, the caller must specify an index. num_prefix is the symbol used
-- in "not found" messages for an explicit index (e.g. "@", "#", "").
-- Returns (info, nil) on success, or (nil, error_message) otherwise.
function resolve_special_index(list, num_str, type_label, num_prefix)
    if num_str ~= "" then
        local info = list[tonumber(num_str)]
        if info then return info end
        return nil, "No " .. type_label .. " track " .. num_prefix .. num_str
    end

    if #list == 0 then
        return nil, "No " .. type_label .. " track found"
    elseif #list == 1 then
        return list[1]
    end

    return nil, "Multiple " .. type_label .. " tracks in project. Add a number to specify which one to work on"
end

-- Port of create_track_table() (Vertical Workflow.lua:858-933)
function build_track_table(is_empty)
    local track_table = {}
    local num_of_tracks = CountTracks(0)
    local rcmaster_index
    local j = 0
    local k = 1
    local prev_k = 1
    local groups_equal = true
    local mixer_tracks = {}
    for i = 0, num_of_tracks - 1, 1 do
        local track = GetTrack(0, i)
        local parent = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, live_state = GetSetMediaTrackInfo_String(track, "P_EXT:live", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, listenback_state = GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if parent == 1 then
            if j > 1 and k ~= prev_k then
                groups_equal = false
            end
            j = j + 1
            prev_k = k
            k = 1
            track_table[j] = { parent = track, tracks = {} }
            if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", tostring(k), true) end
        elseif trackname_check(track, "^M:") or mixer_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "y", true)
            local mod_name = string.match(name, "^M:(.*)") or name
            GetSetMediaTrackInfo_String(track, "P_NAME", "M:" .. mod_name, true)
            table.insert(mixer_tracks, track)
        elseif trackname_check(track, "^@") or aux_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:aux", "y", true)
            local mod_name = string.match(name, "@?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "@" .. mod_name, true)
        elseif trackname_check(track, "^#") or submix_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:submix", "y", true)
            local mod_name = string.match(name, "#?(.*)")
            GetSetMediaTrackInfo_String(track, "P_NAME", "#" .. mod_name, true)
        elseif trackname_check(track, "^RoomTone") or rt_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "RoomTone", true)
        elseif trackname_check(track, "^LIVE") or live_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:live", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "LIVE", true)
        elseif trackname_check(track, "^REF") or ref_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "y", true)
            local mod_name = name:match("^REF:?(.*)") or name
            if name ~= "REF" then
                GetSetMediaTrackInfo_String(track, "P_NAME", "REF:" .. mod_name, true)
            end
        elseif trackname_check(track, "^LISTENBACK") or listenback_state == "y" then
            GetSetMediaTrackInfo_String(track, "P_EXT:listenback", "y", true)
            GetSetMediaTrackInfo_String(track, "P_NAME", "LISTENBACK", true)
        elseif trackname_check(track, "^RCMASTER") or rcmaster_state == "y" then
            rcmaster_index = i
        else
            if j > 0 then
                table.insert(track_table[j].tracks, track)
                if is_empty then GetSetMediaTrackInfo_String(track, "P_EXT:mix_order", tostring(k + 1), true) end
            else
                groups_equal = false
            end
            k = k + 1
        end
    end
    if j > 1 and k ~= prev_k then
        groups_equal = false
    end
    return track_table, rcmaster_index, k, j, mixer_tracks, groups_equal
end

-- Returns track_table, rcmaster_index, folder_count, tracks_per_group, mixer_tracks
function get_track_table()
    local track_table, rcmaster_index, _, folder_count, mixer_tracks = build_track_table(false)
    local tracks_per_group = 1
    if track_table[1] then
        tracks_per_group = #track_table[1].tracks + 1
    end
    return track_table, rcmaster_index, folder_count, tracks_per_group, mixer_tracks
end

---------------------------------------------------------------------
-- Routing helpers
---------------------------------------------------------------------

function route_to_track(src, dst)
    SetMediaTrackInfo_Value(src, "B_MAINSEND", 0)
    CreateTrackSend(src, dst)
end

function has_send_to(src, dst)
    local n = GetTrackNumSends(src, 0)
    for i = 0, n - 1 do
        if GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK") == dst then
            return true
        end
    end
    return false
end

function remove_send_to(src, dst)
    local n = GetTrackNumSends(src, 0)
    for i = n - 1, 0, -1 do
        if GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK") == dst then
            RemoveTrackSend(src, 0, i)
        end
    end
end

function find_send_index(src, dst)
    local n = GetTrackNumSends(src, 0)
    for i = 0, n - 1 do
        if GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK") == dst then
            return i
        end
    end
    return nil
end

-- Toggles a track's RCMASTER connection on/off, mirroring
-- Mission Control.lua's P_EXT:rcm_disconnect convention plus the
-- actual send created/removed by route_tracks().
function set_rcm_connection(track, connect)
    local rcmaster = get_rcmaster()
    if not rcmaster then return false end
    GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", connect and "" or "y", true)
    if connect then
        if not has_send_to(track, rcmaster) then
            route_to_track(track, rcmaster)
        end
    else
        remove_send_to(track, rcmaster)
    end
    return true
end

---------------------------------------------------------------------
-- Target / list resolution
---------------------------------------------------------------------

-- Resolves a single-track selector token to a MediaTrack, returning
-- (track, nil) on success or (nil, err) if a specific error message should
-- be shown instead of the caller's generic "Unknown target" message:
--   "rcm"  -> RCMASTER
--   "@N"   -> Nth aux track ("@" alone -> the only aux track, if exactly one)
--   "#N"   -> Nth submix track ("#" alone -> the only submix track, if exactly one)
--   "N"    -> mixer track N
function resolve_target(token)
    if token == "rcm" then
        return get_rcmaster()
    end

    local aux_n = token:match("^@(%d*)$")
    if aux_n then
        local info, err = resolve_special_index(get_special_tracks_by_type("aux"), aux_n, "aux", "@")
        return info and info.track, err
    end

    local sub_n = token:match("^#(%d*)$")
    if sub_n then
        local info, err = resolve_special_index(get_special_tracks_by_type("submix"), sub_n, "submix", "#")
        return info and info.track, err
    end

    local mixer_n = token:match("^(%d+)$")
    if mixer_n then
        local mixer = get_mixer_tracks()
        return mixer[tonumber(mixer_n)]
    end

    local ref_n = token:match("^ref(%d*)$")
    if ref_n then
        local info, err = resolve_special_index(get_special_tracks_by_type("reference"), ref_n, "reference", "ref")
        return info and info.track, err
    end

    if token == "rt" then
        local info, err = resolve_special_index(get_special_tracks_by_type("roomtone"), "", "RoomTone", "")
        return info and info.track, err
    end

    if token == "live" then
        local info, err = resolve_special_index(get_special_tracks_by_type("live"), "", "LIVE", "")
        return info and info.track, err
    end

    if token == "lb" then
        local info, err = resolve_special_index(get_special_tracks_by_type("listenback"), "", "Listenback", "")
        return info and info.track, err
    end

    return nil
end

-- Expands a list token ("*", "1", "1,3", "4-6", "1,4-6") into an array of
-- 1-based indices in 1..count, in ascending order of appearance. Strips
-- all whitespace first so "1, 3" / " 1 - 3 " (spaces users instinctively
-- type after commas/dashes) parse the same as "1,3" / "1-3".
function expand_index_list(token, count)
    token = token:gsub("%s+", "")
    if token == "*" then
        local result = {}
        for n = 1, count do table.insert(result, n) end
        return result
    end

    local result = {}
    for part in token:gmatch("[^,]+") do
        local a, b = part:match("^(%d+)-(%d+)$")
        if a then
            for n = tonumber(a), tonumber(b) do table.insert(result, n) end
        else
            local n = tonumber(part)
            if n then table.insert(result, n) end
        end
    end
    return result
end

-- Expands a track-list token ("*", "1", "1,3", "4-6", "1,4-6") into an
-- array of mixer tracks, in get_mixer_tracks() order.
function parse_track_list(token)
    local mixer = get_mixer_tracks()
    local result = {}
    for _, n in ipairs(expand_index_list(token, #mixer)) do
        if mixer[n] then table.insert(result, mixer[n]) end
    end
    return result
end

-- Resolves any track-selector token into an array of tracks, plus an
-- optional error message (returned when the array is empty and a specific
-- message should be shown instead of the caller's generic fallback).
-- "@..."/"#..." resolve against the aux/submix lists (each accepting "*",
-- "N", "N-M", "N,M", "N,M-P", ..., or nothing at all for "the only one");
-- "rcm" resolves to RCMASTER; everything else is a mixer-track list via
-- parse_track_list(). Used so that mute/solo/pan/fader/etc. commands all
-- accept single, range, comma-separated and "*" targets uniformly across
-- mixer tracks, auxes and submixes.
function resolve_target_list(token)
    if token == "rcm" then
        local rcmaster = get_rcmaster()
        return rcmaster and { rcmaster } or {}
    end

    if token == "@" or token == "#" then
        local type_label = (token == "@") and "aux" or "submix"
        local info, err = resolve_special_index(get_special_tracks_by_type(type_label), "", type_label, token)
        return info and { info.track } or {}, err
    end

    local aux_list = token:match("^@(.+)$")
    if aux_list then
        local specials = get_special_tracks_by_type("aux")
        local result = {}
        for _, n in ipairs(expand_index_list(aux_list, #specials)) do
            if specials[n] then table.insert(result, specials[n].track) end
        end
        return result
    end

    local sub_list = token:match("^#(.+)$")
    if sub_list then
        local specials = get_special_tracks_by_type("submix")
        local result = {}
        for _, n in ipairs(expand_index_list(sub_list, #specials)) do
            if specials[n] then table.insert(result, specials[n].track) end
        end
        return result
    end

    if token == "ref" then
        local info, err = resolve_special_index(get_special_tracks_by_type("reference"), "", "reference", "ref")
        return info and { info.track } or {}, err
    end

    local ref_list = token:match("^ref(.+)$")
    if ref_list then
        local specials = get_special_tracks_by_type("reference")
        local result = {}
        for _, n in ipairs(expand_index_list(ref_list, #specials)) do
            if specials[n] then table.insert(result, specials[n].track) end
        end
        return result
    end

    if token == "rt" then
        local info, err = resolve_special_index(get_special_tracks_by_type("roomtone"), "", "RoomTone", "")
        return info and { info.track } or {}, err
    end

    if token == "live" then
        local info, err = resolve_special_index(get_special_tracks_by_type("live"), "", "LIVE", "")
        return info and { info.track } or {}, err
    end

    if token == "lb" then
        local info, err = resolve_special_index(get_special_tracks_by_type("listenback"), "", "Listenback", "")
        return info and { info.track } or {}, err
    end

    return parse_track_list(token)
end

-- Tries each known word-based special-track prefix (ref[list], rt, live,
-- lb) against the start of cmd, returning (target_token, remainder) if cmd
-- starts with one. Matched via fixed literal prefixes rather than folding
-- letters into the shared numeric/@/# character class, since a generic
-- greedy/backtracking split would misparse e.g. "refum" as target "refu" +
-- op "m" instead of target "ref" + op "um" (the same ambiguity "u" already
-- creates against the "um"/"us" mute/solo suffixes for any letter-based
-- target name). Each prefix's allowed trailing chars stop at the first
-- letter, so the remainder always starts exactly where the op begins.
-- The optional ref index deliberately excludes "-" even though
-- expand_index_list() supports dash ranges elsewhere: since "rest" below is
-- unconstrained (.*), Lua never backtracks into the index class, so a
-- trailing "-" would otherwise get swallowed as a (bogus) range start
-- against operators like "-rcm" (e.g. "ref-rcm" or "ref2-rcm" must split
-- before the dash, not after it).
function split_word_target(cmd)
    local rest = cmd:match("^ref[%d,%*]*(.*)$")
    if rest then return cmd:sub(1, #cmd - #rest), rest end
    rest = cmd:match("^rcm(.*)$")
    if rest then return "rcm", rest end
    rest = cmd:match("^rt(.*)$")
    if rest then return "rt", rest end
    rest = cmd:match("^live(.*)$")
    if rest then return "live", rest end
    rest = cmd:match("^lb(.*)$")
    if rest then return "lb", rest end
    return nil, nil
end

-- Comma-joined humanized names for a list of tracks, for confirming which
-- tracks a batch command (mute/solo/pan/fader/etc.) just applied to.
function track_names_str(tracks)
    local names = {}
    for _, track in ipairs(tracks) do
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        table.insert(names, humanize_track_name(name))
    end
    return table.concat(names, ", ")
end

-- Per-track label (humanized name, no separator) for property queries over a
-- resolved track list: "" when there's exactly one track in the result (the
-- user already knows which track they asked about), the track's name when
-- there are several (needed to tell the results apart). Callers append
-- whatever separator fits the surrounding text (": ", " ", etc.) themselves.
function query_label(track, total)
    if total <= 1 then return "" end
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return humanize_track_name(name)
end

-- label .. sep, or "" if label is empty (the single-track case) -- avoids
-- a stray leading separator when query_label() has nothing to say.
function label_prefix(label, sep)
    if label == "" then return "" end
    return label .. sep
end

---------------------------------------------------------------------
-- Track renaming (port of rename_tracks(), Mission Control.lua:2510-2566)
---------------------------------------------------------------------

-- Renames mixer track at 1-based "position" (in get_mixer_tracks() order)
-- to new_name, plus the position-matching track in every folder, applying
-- the D:/S{n}: prefix convention for vertical workflows. Preserves the
-- track's existing RCMASTER-connection state.
function rename_mixer_position(mixer_tracks, position, new_name)
    local mixer_track = mixer_tracks[position]
    if not mixer_track then return false end

    local _, rcm_disconnect = GetSetMediaTrackInfo_String(mixer_track, "P_EXT:rcm_disconnect", "", false)

    local clean_name = new_name:gsub("%-$", "")
    GetSetMediaTrackInfo_String(mixer_track, "P_NAME", "M:" .. clean_name, true)

    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then
            folder_number = folder_number + 1
            local track_index = i + (position - 1)
            local target_track = GetTrack(0, track_index)
            if target_track then
                GetSetMediaTrackInfo_String(target_track, "P_EXT:rcm_disconnect", rcm_disconnect, true)
                local prefix = ""
                if workflow == "Vertical" then
                    if folder_number == 1 then
                        prefix = "D:"
                    else
                        prefix = "S" .. (folder_number - 1) .. ":"
                    end
                end
                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. clean_name, true)
            end
        end
    end
    return true
end

-- Valid language values for album= lg= field (mirrors Create CD Markers.lua dropdown).
local VALID_LANGUAGES = {
    "Albanian", "Amharic", "Arabic", "Armenian", "Assamese", "Azerbaijani",
    "Bambora", "Basque", "Bengali", "Bielorussian", "Breton", "Bulgarian",
    "Burmese", "Catalan", "Chinese", "Churash", "Croatian", "Czech", "Danish",
    "Dari", "Dutch", "English", "Esperanto", "Estonian", "Faroese", "Finnish",
    "Flemish", "French", "Frisian", "Fulani", "Gaelic", "Galician", "Georgian",
    "German", "Greek", "Gujurati", "Gurani", "Hausa", "Hebrew", "Hindi",
    "Hungarian", "Icelandic", "Indonesian", "Irish", "Italian", "Japanese",
    "Kannada", "Kazakh", "Khmer", "Korean", "Laotian", "Lappish", "Latin",
    "Latvian", "Lithuanian", "Luxembourgian", "Macedonian", "Malagasay",
    "Malaysian", "Maltese", "Marathi", "Moldavian", "Ndebele", "Nepali",
    "Norwegian", "Occitan", "Oriya", "Papamiento", "Persian", "Polish",
    "Portugese", "Punjabi", "Pushtu", "Quechua", "Romanian", "Romansh",
    "Russian", "Ruthenian", "Serbian", "Serbo-croat", "Shona", "Sinhalese",
    "Slovak", "Slovenian", "Somali", "Spanish", "SrananTongo", "Swahili",
    "Swedish", "Tadzhik", "Tamil", "Tatar", "Telugu", "Thai", "Turkish",
    "Ukrainian", "Urdu", "Uzbek", "Vietnamese", "Wallon", "Welsh", "Zulu",
}

---------------------------------------------------------------------
-- Marker metadata helpers (Metadata Report.lua / Create CD Markers.lua
-- pipe-delimited "Title|KEY=VAL|KEY=VAL" convention)
---------------------------------------------------------------------

-- Rebuilds a "#Title|KEY=VAL" / "@Title|KEY=VAL" marker name string.
-- new_title: nil/"" leaves the title unchanged, otherwise replaces it.
-- field_updates: map of KEY -> value, where "" leaves the field
-- unchanged, "0" clears it, and any other value sets it.
function rebuild_marker_name(name, prefix, new_title, field_updates)
    local body = name:sub(2)
    local title = body:match("^([^|]*)") or ""
    if new_title and new_title ~= "" then
        title = new_title
    end

    local fields = {}
    local order = {}
    for key, val in body:gmatch("|(%u+)=([^|]*)") do
        fields[key] = val
        table.insert(order, key)
    end

    for key, val in pairs(field_updates or {}) do
        if val == "0" then
            fields[key] = nil
        elseif val ~= "" then
            if fields[key] == nil then
                table.insert(order, key)
            end
            fields[key] = val
        end
    end

    local result = prefix .. title
    for _, key in ipairs(order) do
        if fields[key] ~= nil then
            result = result .. "|" .. key .. "=" .. fields[key]
        end
    end
    return result
end

-- Finds the marker linked to a media item via its P_EXT:cdmarker GUID.
-- Returns mark_index, retval, isrgn, pos, rgnend, name, markrgnID, color
function get_item_cd_marker(item)
    local ok, guid = GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", "", false)
    if not ok or guid == "" then return nil end

    local ok_index, mark_index_str = GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. guid, "", false)
    if not ok_index or mark_index_str == "" then return nil end

    local mark_index = tonumber(mark_index_str)
    if not mark_index then return nil end

    local retval, isrgn, pos, rgnend, name, markrgnID, color = EnumProjectMarkers3(0, mark_index)
    if not retval then return nil end
    return mark_index, isrgn, pos, rgnend, name, markrgnID, color
end

-- Finds the album marker ("@Title|...") - returns the same shape as
-- get_item_cd_marker (minus the leading mark_index argument check).
function get_album_marker()
    local num_markers, num_regions = CountProjectMarkers(0)
    for idx = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnID, color = EnumProjectMarkers3(0, idx)
        if retval and not isrgn and name:match("^@") then
            return idx, isrgn, pos, rgnend, name, markrgnID, color
        end
    end
    return nil
end

---------------------------------------------------------------------
-- Command handlers (one "try_*" function per category). Each returns
-- true if it matched and handled the command, false otherwise.
---------------------------------------------------------------------

-- Replaces the current project with a blank one (prompting to save unsaved
-- changes first, same as File: New project), so Nv/Nh can be run again from
-- inside an existing ReaClassical project instead of only on an empty one.
-- Returns false if the user cancelled the save prompt.
function start_fresh_project()
    Main_OnCommand(40023, 0) -- File: New project
    local _, wf_after = GetProjExtState(0, "ReaClassical", "Workflow")
    return wf_after == ""
end

-- Port of get_items_at_midpoint() (Mission Control.lua:3612-3631).
function get_items_at_midpoint(ref_item, folder_start, folder_end)
    local pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
    local len = GetMediaItemInfo_Value(ref_item, "D_LENGTH")
    local mid = pos + len * 0.5
    local tolerance = 0.0001
    local result = {}
    for t = folder_start, folder_end do
        local track = GetTrack(0, t)
        local n = CountTrackMediaItems(track)
        for i = 0, n - 1 do
            local item = GetTrackMediaItem(track, i)
            local ipos = GetMediaItemInfo_Value(item, "D_POSITION")
            local ilen = GetMediaItemInfo_Value(item, "D_LENGTH")
            if mid >= (ipos - tolerance) and mid <= (ipos + ilen + tolerance) then
                result[#result + 1] = item
            end
        end
    end
    return result
end

-- Port of consolidate_folders_to_first() (Mission Control.lua:3635-3863).
-- Required before converting Vertical -> Horizontal: Horizontal workflow
-- expects exactly one folder, so every other folder's items get appended
-- end-to-end onto the first folder's matching track slots first, and the
-- now-empty folders are removed. Without this step, convert=h either
-- leaves extra folders behind or hands the Horizontal Workflow script a
-- track layout it doesn't know how to convert.
function consolidate_folders_to_first()
    local num_tracks = CountTracks(0)
    local folders = {}

    local i = 0
    while i < num_tracks do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if folder_depth == 1 then
            local folder_info = { parent = track, children = {} }
            table.insert(folders, folder_info)

            i = i + 1
            local current_depth = 1
            while i < num_tracks and current_depth > 0 do
                local child_track = GetTrack(0, i)
                local child_depth = GetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH")
                table.insert(folder_info.children, child_track)
                current_depth = current_depth + child_depth
                if current_depth <= 0 then break end
                i = i + 1
            end
        end
        i = i + 1
    end

    if #folders < 2 then return end

    -- Collect items from each folder, grouping peers by midpoint instead of I_GROUPID.
    -- Each "midpoint group" is a set of items that share the same midpoint position --
    -- they are treated as a unit when consolidating, just as grouped items were before.
    for _, folder in ipairs(folders) do
        local all_folder_tracks = { folder.parent }
        for _, child in ipairs(folder.children) do
            table.insert(all_folder_tracks, child)
        end

        -- Build a set of all items in this folder
        local folder_item_set = {}
        for _, track in ipairs(all_folder_tracks) do
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                folder_item_set[item] = true
            end
        end

        -- Group items by midpoint: use the parent (folder.parent) track's items
        -- as reference items, then find their peers across the folder.
        local midpoint_groups = {} -- list of {items = {...}, ref_pos = pos}
        local seen = {}

        -- Resolve folder track index range for scoped midpoint lookup
        local folder_start_idx = GetMediaTrackInfo_Value(folder.parent, "IP_TRACKNUMBER") - 1
        local folder_end_idx = folder_start_idx
        for _, child in ipairs(folder.children) do
            folder_end_idx = GetMediaTrackInfo_Value(child, "IP_TRACKNUMBER") - 1
        end

        local parent_item_count = CountTrackMediaItems(folder.parent)
        for j = 0, parent_item_count - 1 do
            local ref_item = GetTrackMediaItem(folder.parent, j)
            if not seen[ref_item] then
                local peers = get_items_at_midpoint(ref_item, folder_start_idx, folder_end_idx)

                -- Only keep peers that are actually in this folder
                local group_items = {}
                for _, peer in ipairs(peers) do
                    if folder_item_set[peer] then
                        group_items[#group_items + 1] = peer
                        seen[peer] = true
                    end
                end
                local ref_pos = GetMediaItemInfo_Value(ref_item, "D_POSITION")
                table.insert(midpoint_groups, { items = group_items, ref_pos = ref_pos })
            end
        end

        -- Collect any remaining folder items not reached via the parent track
        local ungrouped_items = {}
        for _, track in ipairs(all_folder_tracks) do
            local item_count = CountTrackMediaItems(track)
            for j = 0, item_count - 1 do
                local item = GetTrackMediaItem(track, j)
                if not seen[item] then
                    seen[item] = true
                    table.insert(ungrouped_items, item)
                end
            end
        end

        folder.midpoint_groups = midpoint_groups
        folder.ungrouped_items = ungrouped_items
    end

    -- Find earliest and latest positions in first folder
    local first_folder = folders[1]
    local first_folder_earliest = math.huge
    local latest_end = 0

    for _, group in ipairs(first_folder.midpoint_groups) do
        for _, item in ipairs(group.items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
            if pos < first_folder_earliest then first_folder_earliest = pos end
            if item_end > latest_end then latest_end = item_end end
        end
    end
    for _, item in ipairs(first_folder.ungrouped_items) do
        local pos = GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos < first_folder_earliest then first_folder_earliest = pos end
        if item_end > latest_end then latest_end = item_end end
    end

    -- Shift first folder to start at 0 if needed
    if first_folder_earliest ~= 0 and first_folder_earliest ~= math.huge then
        local shift = -first_folder_earliest
        for _, group in ipairs(first_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                SetMediaItemInfo_Value(item, "D_POSITION", pos + shift)
            end
        end
        for _, item in ipairs(first_folder.ungrouped_items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            SetMediaItemInfo_Value(item, "D_POSITION", pos + shift)
        end
        latest_end = latest_end + shift
    end

    local first_folder_tracks = { first_folder.parent }
    for _, child in ipairs(first_folder.children) do
        table.insert(first_folder_tracks, child)
    end

    local current_position = (latest_end > 0) and (latest_end + 10) or 0

    for folder_idx = 2, #folders do
        local source_folder = folders[folder_idx]

        -- Find earliest position in this folder
        local folder_earliest = math.huge
        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local pos = GetMediaItemInfo_Value(item, "D_POSITION")
                if pos < folder_earliest then folder_earliest = pos end
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            if pos < folder_earliest then folder_earliest = pos end
        end

        local folder_offset = current_position - folder_earliest

        local source_folder_tracks = { source_folder.parent }
        for _, child in ipairs(source_folder.children) do
            table.insert(source_folder_tracks, child)
        end

        local function move_item_to_first_folder(item, new_pos)
            local source_track = GetMediaItem_Track(item)
            local source_track_pos = nil
            for idx, folder_track in ipairs(source_folder_tracks) do
                if folder_track == source_track then
                    source_track_pos = idx; break
                end
            end
            if source_track_pos and source_track_pos <= #first_folder_tracks then
                local dest_track = first_folder_tracks[source_track_pos]
                MoveMediaItemToTrack(item, dest_track)
                SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
            end
        end

        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
                move_item_to_first_folder(item, original_pos + folder_offset)
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local original_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            move_item_to_first_folder(item, original_pos + folder_offset)
        end

        -- Find end of all items now in this folder's slots
        local folder_end = 0
        for _, group in ipairs(source_folder.midpoint_groups) do
            for _, item in ipairs(group.items) do
                local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                    GetMediaItemInfo_Value(item, "D_LENGTH")
                if item_end > folder_end then folder_end = item_end end
            end
        end
        for _, item in ipairs(source_folder.ungrouped_items) do
            local item_end = GetMediaItemInfo_Value(item, "D_POSITION") +
                GetMediaItemInfo_Value(item, "D_LENGTH")
            if item_end > folder_end then folder_end = item_end end
        end

        current_position = folder_end + 10
    end

    -- Delete only empty folders (2 onwards)
    Main_OnCommand(40297, 0) -- Unselect all
    for folder_idx = 2, #folders do
        local folder = folders[folder_idx]
        local has_items = CountTrackMediaItems(folder.parent) > 0
        if not has_items then
            for _, child in ipairs(folder.children) do
                if CountTrackMediaItems(child) > 0 then
                    has_items = true; break
                end
            end
        end
        if not has_items then
            SetTrackSelected(folder.parent, true)
            for _, child in ipairs(folder.children) do
                SetTrackSelected(child, true)
            end
        end
    end

    Main_OnCommand(40005, 0) -- Remove selected tracks
    Main_OnCommand(40297, 0) -- Unselect all
end

function try_project_setup(cmd)
    local v_count, v_names = cmd:match("^(%d+)v=(.+)$")
    if not v_count then
        v_count = cmd:match("^(%d+)v$")
    end
    if v_count then
        if tonumber(v_count) < 2 then
            say("Each folder needs a minimum of 2 tracks")
            return true
        end
        if workflow ~= "" then
            if not start_fresh_project() then
                say("Cancelled")
                return true
            end
            workflow = ""
        end
        SetProjExtState(0, "ReaClassical", "TrackCount", v_count)
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        _G.RC_TERMINAL_ARGS = nil
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        if APIExists("SNM_SetIntConfigVar") then SNM_SetIntConfigVar("scrubmode", 1) end
        if v_names and v_names ~= "" then
            local mixer_tracks = get_mixer_tracks()
            local position = 1
            for name in v_names:gmatch("[^,]+") do
                local clean_name = trim(name)
                rename_mixer_position(mixer_tracks, position, clean_name)
                local mixer_track = mixer_tracks[position]
                if mixer_track then apply_pan_from_name(mixer_track, clean_name) end
                position = position + 1
            end
        end
        return true
    end

    local h_count, h_names = cmd:match("^(%d+)h=(.+)$")
    if not h_count then
        h_count = cmd:match("^(%d+)h$")
    end
    if h_count then
        if tonumber(h_count) < 2 then
            say("Each folder needs a minimum of 2 tracks")
            return true
        end
        if workflow ~= "" then
            if not start_fresh_project() then
                say("Cancelled")
                return true
            end
            workflow = ""
        end
        SetProjExtState(0, "ReaClassical", "TrackCount", h_count)
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
        _G.RC_TERMINAL_ARGS = nil
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        if APIExists("SNM_SetIntConfigVar") then SNM_SetIntConfigVar("scrubmode", 1) end
        if h_names and h_names ~= "" then
            local mixer_tracks = get_mixer_tracks()
            local position = 1
            for name in h_names:gmatch("[^,]+") do
                local clean_name = trim(name)
                rename_mixer_position(mixer_tracks, position, clean_name)
                local mixer_track = mixer_tracks[position]
                if mixer_track then apply_pan_from_name(mixer_track, clean_name) end
                position = position + 1
            end
        end
        return true
    end

    -- Mirrors Mission Control's "Convert to Horizontal" button: Horizontal
    -- workflow expects exactly one folder, so every other folder's items
    -- must be consolidated onto the first folder before re-syncing, or the
    -- Workflow script is left with a track layout it can't convert.
    if cmd == "convert=h" then
        if workflow == "Horizontal" then
            say("The project already uses a Horizontal workflow")
            return true
        end
        consolidate_folders_to_first()
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
        _G.RC_TERMINAL_ARGS = nil
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        if CountMediaItems(0) > 0 then
            _G.RC_TERMINAL_ARGS = { silent = true }
            dofile(script_path .. "ReaClassical_Prepare Takes.lua")
            _G.RC_TERMINAL_ARGS = nil
        end
        say("Conversion to Horizontal workflow complete")
        return true
    end

    if cmd == "convert=v" then
        if workflow == "Vertical" then
            say("The project already uses a Vertical workflow")
            return true
        end
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
        _G.RC_TERMINAL_ARGS = nil
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        workflow = wf
        if CountMediaItems(0) > 0 then
            _G.RC_TERMINAL_ARGS = { silent = true }
            dofile(script_path .. "ReaClassical_Prepare Takes.lua")
            _G.RC_TERMINAL_ARGS = nil
        end
        say("Conversion to Vertical workflow complete")
        return true
    end

    return false
end

function strip_rank_prefix(name)
    local all_prefixes = { "Excellent", "Very Good", "Good", "OK", "Below Average", "Poor", "Unusable", "False Start" }
    for _, prefix in ipairs(all_prefixes) do
        if name == prefix then return "" end
        name = name:gsub("^" .. prefix .. "%-", "")
    end
    return name
end

-- Rebuilds the active take's display name from a base name and an
-- item-rank index ("1".."9" or "" for no rank), per Notes.lua.
function apply_item_name(item, base_name, rank_str)
    local take = GetActiveTake(item)
    if not take then return end

    local final_name = base_name
    if rank_str and rank_str ~= "" then
        local idx = tonumber(rank_str)
        local prefix = idx and RANK_PREFIXES[idx]
        if prefix and prefix ~= "" then
            if base_name ~= "" then
                final_name = prefix .. "-" .. base_name
            else
                final_name = prefix
            end
        end
    end
    GetSetMediaItemTakeInfo_String(take, "P_NAME", final_name, true)
end

function try_naming(cmd)
    local names = cmd:match("^n=(.+)$")
    if names then
        local mixer_tracks = get_mixer_tracks()
        local position = 1
        local renamed = {}
        for name in names:gmatch("[^,]+") do
            if rename_mixer_position(mixer_tracks, position, trim(name)) then
                table.insert(renamed, trim(name))
            else
                say("No mixer track at position " .. position)
            end
            position = position + 1
        end
        if #renamed > 0 then
            say("Renamed: " .. table.concat(renamed, ", "))
        end
        return true
    end

    local pos, single_name = cmd:match("^(%d+)n=(.+)$")
    if pos then
        local mixer_tracks = get_mixer_tracks()
        if rename_mixer_position(mixer_tracks, tonumber(pos), trim(single_name)) then
            say("Renamed to " .. trim(single_name))
        else
            say("No mixer track at position " .. pos)
        end
        return true
    end

    local sub_n, sub_name = cmd:match("^#(%d*)n=(.+)$")
    if sub_name then
        local info, err = resolve_special_index(get_special_tracks_by_type("submix"), sub_n, "submix", "#")
        if info then
            GetSetMediaTrackInfo_String(info.track, "P_NAME", "#" .. trim(sub_name), true)
            say("Submix renamed to " .. trim(sub_name))
        else
            say(err)
        end
        return true
    end

    local aux_n, aux_name = cmd:match("^@(%d*)n=(.+)$")
    if aux_name then
        local info, err = resolve_special_index(get_special_tracks_by_type("aux"), aux_n, "aux", "@")
        if info then
            GetSetMediaTrackInfo_String(info.track, "P_NAME", "@" .. trim(aux_name), true)
            say("Aux renamed to " .. trim(aux_name))
        else
            say(err)
        end
        return true
    end

    local ref_n, ref_name = cmd:match("^ref(%d*)n=(.+)$")
    if ref_name then
        local info, err = resolve_special_index(get_special_tracks_by_type("reference"), ref_n, "REF", "")
        if info then
            GetSetMediaTrackInfo_String(info.track, "P_NAME", "REF:" .. trim(ref_name), true)
            say("Reference renamed to " .. trim(ref_name))
        else
            say(err)
        end
        return true
    end

    if cmd == "pn?" then
        local _, notes = GetSetProjectNotes(0, false, "")
        say(notes ~= "" and notes or "No project notes set")
        return true
    end

    local proj_note = cmd:match("^pn=(.*)$")
    if proj_note then
        GetSetProjectNotes(0, true, proj_note)
        say("Project notes updated")
        return true
    end

    if cmd == "tn?" then
        local track = GetSelectedTrack(0, 0)
        if not track then
            say("No track selected"); return true
        end
        local _, notes = GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", "", false)
        say(notes ~= "" and notes or "No track notes set")
        return true
    end

    local track_note = cmd:match("^tn=(.*)$")
    if track_note then
        local track = GetSelectedTrack(0, 0)
        if not track then
            say("No track selected")
            return true
        end
        GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", track_note, true)
        say("Track notes updated")
        return true
    end

    -- in=Title (no comma): rename the active take of the selected item
    local item_name = cmd:match("^in=([^,]*)$")
    if item_name then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected")
            return true
        end
        local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
        apply_item_name(item, trim(item_name), rank_str)
        say("Item renamed to " .. trim(item_name))
        return true
    end

    if cmd == "ino?" then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected"); return true
        end
        local _, notes = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
        say(notes ~= "" and notes or "No item notes set")
        return true
    end

    local item_notes = cmd:match("^ino=(.*)$")
    if item_notes then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected")
            return true
        end
        GetSetMediaItemInfo_String(item, "P_NOTES", item_notes, true)
        say("Item notes updated")
        return true
    end

    if cmd == "ir?" then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected"); return true
        end
        local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
        local rank_index = tonumber(rank_str) or 9
        local label = RANK_PREFIXES[rank_index]
        say("Rank: " .. (label ~= "" and label or "None"))
        return true
    end

    local rank_letter = cmd:match("^ir=([evgobpufn])$")
    if rank_letter then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected")
            return true
        end
        local rank_index = RANK_LETTERS[rank_letter]
        local rank_str = (rank_index == 9) and "" or tostring(rank_index)
        GetSetMediaItemInfo_String(item, "P_EXT:item_rank", rank_str, true)

        local take = GetActiveTake(item)
        local base_name = ""
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            base_name = strip_rank_prefix(name)
        end
        apply_item_name(item, base_name, rank_str)
        local label = RANK_PREFIXES[rank_index]
        say("Rank: " .. (label ~= "" and label or "None"))
        return true
    end

    if cmd == "itn?" then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected"); return true
        end
        local _, tn = GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", "", false)
        say(tn ~= "" and ("Take number: " .. tn) or "No take number set")
        return true
    end

    local take_num = cmd:match("^itn=(%d+)$")
    if take_num then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected")
            return true
        end
        GetSetMediaItemInfo_String(item, "P_EXT:item_take_num", take_num == "0" and "" or take_num, true)
        say(take_num == "0" and "Take number cleared" or ("Take number set to " .. take_num))
        return true
    end

    return false
end

-- folder is track_table[n] = { parent = track, tracks = {...} }.
-- position 1 == parent ("D:"/folder track), position N (N>1) == its
-- (N-1)th child, matching the mixer-track-position convention.
function get_folder_position_track(folder, position)
    if position == 1 then
        return folder.parent
    end
    return folder.tracks[position - 1]
end

-- Resolves a folder label ("D" or "S<n>", matching the D:/S{n}: naming
-- convention used by rename_mixer_position()) to its track_table entry.
function resolve_folder_label(track_table, label)
    if label == "D" then
        if not track_table[1] then return nil, "No folders found" end
        return track_table[1]
    end
    local s_n = label:match("^S(%d+)$")
    if s_n then
        local folder = track_table[tonumber(s_n) + 1]
        if not folder then return nil, "No folder S" .. s_n end
        return folder
    end
    return nil, "Unknown folder " .. label
end

-- Resolves a position-list token ("1", "1,3", "2-4", "*") within folder
-- into an array of actual tracks, via get_folder_position_track().
function resolve_folder_position_list(folder, positions_str)
    local tracks_per_group = #folder.tracks + 1
    local tracks = {}
    for _, p in ipairs(expand_index_list(positions_str, tracks_per_group)) do
        local track = get_folder_position_track(folder, p)
        if track then table.insert(tracks, track) end
    end
    return tracks
end

-- Shared by auto_assign_inputs() and project-creation naming (Nv=/Nh=):
-- pans a mixer track hard left/right if its name ends/starts with a
-- left/right word. A pair/stereo name resets pan to center, since a
-- renamed-from-left/right track should not keep a stale hard pan. Any
-- other name is left untouched, preserving manual pan adjustments.
-- name should already have any "M:" prefix stripped.
function apply_pan_from_name(mixer_track, name)
    local lower_name = name:lower()

    local is_pair = false
    for _, word in ipairs(pair_words) do
        if lower_name:match("%s" .. word .. "$") or lower_name:match(word .. "$") then
            is_pair = true
            break
        end
    end

    local is_left, is_right = false, false
    for _, word in ipairs(left_words) do
        if lower_name:match("%s" .. word .. "$") or lower_name:match("^" .. word .. "%s") then
            is_left = true
            break
        end
    end
    if not is_left then
        for _, word in ipairs(right_words) do
            if lower_name:match("%s" .. word .. "$") or lower_name:match("^" .. word .. "%s") then
                is_right = true
                break
            end
        end
    end

    if is_left then
        SetMediaTrackInfo_Value(mixer_track, "D_PAN", -1.0)
    elseif is_right then
        SetMediaTrackInfo_Value(mixer_track, "D_PAN", 1.0)
    elseif is_pair then
        SetMediaTrackInfo_Value(mixer_track, "D_PAN", 0.0)
    end
end

-- Port of auto_assign() (Mission Control.lua:2592-2675), simplified to
-- operate on the destination folder (track_table[1]) and the project's
-- mixer tracks directly.
function auto_assign_inputs(start_input)
    local mixer_tracks = get_mixer_tracks()
    local track_table = get_track_table()
    if not track_table[1] then
        say("No folders found")
        return
    end

    local max_inputs = GetNumAudioInputs()
    local input_channel = start_input - 1

    for i = 1, #mixer_tracks do
        local mixer_track = mixer_tracks[i]
        local d_track = get_folder_position_track(track_table[1], i)
        if d_track then
            local _, raw_name = GetSetMediaTrackInfo_String(mixer_track, "P_NAME", "", false)
            local track_name = raw_name:match("^M:(.*)") or raw_name
            local lower_name = track_name:lower()

            local is_pair = false
            for _, word in ipairs(pair_words) do
                if lower_name:match("%s" .. word .. "$") or lower_name:match(word .. "$") then
                    is_pair = true
                    break
                end
            end

            apply_pan_from_name(mixer_track, track_name)

            if input_channel < max_inputs then
                if is_pair and (input_channel + 1 < max_inputs) then
                    SetMediaTrackInfo_Value(d_track, "I_RECINPUT", 1024 + input_channel)
                    input_channel = input_channel + 2
                else
                    SetMediaTrackInfo_Value(d_track, "I_RECINPUT", input_channel)
                    input_channel = input_channel + 1
                end
            else
                SetMediaTrackInfo_Value(d_track, "I_RECINPUT", -1)
            end
        end
    end

    if workflow == "Vertical" then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    end

    say("Inputs auto-assigned starting at input " .. start_input)
end

-- Checks that hardware input channel start_ch (1-based) exists, and for a
-- stereo pair, that start_ch+1 also exists.
function hw_input_exists(start_ch, is_stereo)
    local max_inputs = GetNumAudioInputs()
    if start_ch < 1 or start_ch > max_inputs then return false end
    if is_stereo and start_ch + 1 > max_inputs then return false end
    return true
end

-- Position N's plain name (no "Mixer track" prefix, no folder prefix) for
-- announcing a per-position input change applied across every folder: read
-- from the dedicated mixer track's "M:Name" and strip just the "M:" tag,
-- since the change isn't really about that one mixer track -- it's every
-- folder's track at this position. Using any one folder's own copy of the
-- name would be worse: it carries a folder-specific prefix (e.g.
-- "Destination ...") that wrongly implies the change only hit that folder.
local function position_name(position)
    local track = get_mixer_tracks()[position]
    if not track then return "Track " .. position .. " of the folder" end
    local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    local rest = name:match("^M:(.*)$")
    if rest and rest ~= "" then return rest end
    return "Track " .. position .. " of the folder"
end

function try_input_config(cmd)
    -- N=mono,X: set the track at position N in every folder to mono,
    -- recording from hardware input X (1-based). X is required --
    -- automatic placement is what `ai`/`ai=N` are for.
    local mono_pos, mono_input = cmd:match("^(%d+)=mono,(%d+)$")
    if mono_pos then
        local n = tonumber(mono_pos)
        local mixer_tracks = get_mixer_tracks()
        if not mixer_tracks[n] then
            say("There are only " .. #mixer_tracks .. " tracks per folder")
            return true
        end
        local input_num = tonumber(mono_input)
        if not hw_input_exists(input_num, false) then
            say("Hardware input " .. input_num .. " does not exist")
            return true
        end
        local input_ch = input_num - 1
        local track_table = get_track_table()
        for _, folder in ipairs(track_table) do
            local track = get_folder_position_track(folder, n)
            if track then
                SetMediaTrackInfo_Value(track, "I_RECINPUT", input_ch)
            end
        end
        say(position_name(n) .. " set to mono, input " .. input_num)
        return true
    end

    -- N=stereo,X: set the track at position N in every folder to a stereo
    -- input pair starting at hardware channel X (1-based)
    -- (I_RECINPUT = 1024 + (X-1)), mirroring the mono/stereo radio button
    -- in Mission Control's input selector. X is required -- automatic
    -- placement is what `ai`/`ai=N` are for.
    local stereo_pos, stereo_input = cmd:match("^(%d+)=stereo,(%d+)$")
    if stereo_pos then
        local n = tonumber(stereo_pos)
        local mixer_tracks = get_mixer_tracks()
        if not mixer_tracks[n] then
            say("There are only " .. #mixer_tracks .. " tracks per folder")
            return true
        end
        local start_ch = tonumber(stereo_input)
        if not hw_input_exists(start_ch, true) then
            say("Hardware inputs " .. start_ch .. "/" .. (start_ch + 1) .. " do not exist")
            return true
        end
        local track_table = get_track_table()
        for _, folder in ipairs(track_table) do
            local track = get_folder_position_track(folder, n)
            if track then
                SetMediaTrackInfo_Value(track, "I_RECINPUT", 1024 + (start_ch - 1))
            end
        end
        say(position_name(n) .. " set to stereo, input " .. start_ch .. "/" .. (start_ch + 1))
        return true
    end

    -- N=y / N=n: enable/disable record-arming for mixer track N. Joins the
    -- same bare "<target>=value" family as N=mono/N=stereo above (this
    -- track's recording setup is: mono/stereo/armed/disarmed) rather than
    -- using a separate "rd=" keyword.
    local rd_pos, rd_val = cmd:match("^(%d+)=([yn])$")
    if rd_pos then
        local mixer_tracks = get_mixer_tracks()
        local track = mixer_tracks[tonumber(rd_pos)]
        if track then
            GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", rd_val == "n" and "y" or "", true)
            say(position_name(tonumber(rd_pos)) .. " record " .. (rd_val == "y" and "enabled" or "disabled"))
        else
            say("No mixer track at position " .. rd_pos)
        end
        return true
    end

    local rd_all = cmd:match("^%*=([yn])$")
    if rd_all then
        for _, track in ipairs(get_mixer_tracks()) do
            GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", rd_all == "n" and "y" or "", true)
        end
        say("Record " .. (rd_all == "y" and "enabled" or "disabled") .. " for all tracks")
        return true
    end

    -- <target>input?: report input (mono/stereo) and record-enabled state
    -- for one or more mixer tracks. Needs an explicit noun (unlike the
    -- bare "=y"/"=n" setter above) since a query has no value to infer
    -- meaning from. Always needs a numeric/list target prefix, so it can't
    -- be confused with the unrelated bare "in?" CD-metadata query.
    local rd_query_str = cmd:match("^([%d,%-%*%s]+)input%?$")
    if rd_query_str then
        local tracks, err = resolve_target_list((rd_query_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        for _, track in ipairs(tracks) do
            local prefix = label_prefix(query_label(track, #tracks), " ")
            local _, disabled = GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", "", false)
            local source = get_source_for_mixer(track) or track
            say(prefix .. rec_input_description(source)
                .. ", record: " .. (disabled == "y" and "disabled" or "enabled"))
        end
        return true
    end

    if cmd == "ai" then
        auto_assign_inputs(1)
        return true
    end

    local ai_start = cmd:match("^ai=(%d+)$")
    if ai_start then
        auto_assign_inputs(tonumber(ai_start))
        return true
    end

    return false
end

function try_selection(cmd)
    if cmd == "sel?" then
        local n = CountSelectedTracks(0)
        if n == 0 then
            say("No tracks selected")
        else
            local names = {}
            for i = 0, n - 1 do
                local track = GetSelectedTrack(0, i)
                local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
                table.insert(names, humanize_track_name(name))
            end
            say("Selected tracks: " .. table.concat(names, ", "))
        end

        local item_count = CountSelectedMediaItems(0)
        if item_count == 0 then
            say("No items selected")
        else
            local item_names = {}
            for i = 0, item_count - 1 do
                local item = GetSelectedMediaItem(0, i)
                local take = GetActiveTake(item)
                local name = ""
                if take then
                    _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                end
                table.insert(item_names, name ~= "" and humanize_item_name(name) or "(unnamed)")
            end
            say(item_count .. " item(s) selected: " .. table.concat(item_names, ", "))
        end
        return true
    end

    if cmd == "time?" then
        say(humanize_timestr(format_timestr_pos(GetCursorPosition(), "", -1)))
        return true
    end

    -- sel=+<folder>,<positions>: add regular track(s) inside <folder> (a
    -- "D"/"S<n>" label, per the D:/S{n}: naming convention) at the given
    -- position(s) within that folder ("1", "1,3", "2-4", "*", per
    -- get_folder_position_track()) to the current selection.
    local add_label, add_positions = cmd:match("^sel=%+%s*(%a[%a%d]*)%s*,%s*([%d,%-%*%s]+)$")
    if add_label then
        local folder, err = resolve_folder_label(get_track_table(), add_label)
        if not folder then
            say(err)
            return true
        end
        local tracks = resolve_folder_position_list(folder, add_positions)
        if #tracks == 0 then
            say("No matching tracks")
            return true
        end
        for _, track in ipairs(tracks) do SetTrackSelected(track, true) end
        say("Added to selection: " .. track_names_str(tracks))
        return true
    end

    -- sel=<folder>,<positions>: exclusively select the same.
    local sel_label, sel_positions = cmd:match("^sel=%s*(%a[%a%d]*)%s*,%s*([%d,%-%*%s]+)$")
    if sel_label then
        local folder, err = resolve_folder_label(get_track_table(), sel_label)
        if not folder then
            say(err)
            return true
        end
        local tracks = resolve_folder_position_list(folder, sel_positions)
        if #tracks == 0 then
            say("No matching tracks")
            return true
        end
        SetOnlyTrackSelected(tracks[1])
        for i = 2, #tracks do SetTrackSelected(tracks[i], true) end
        say("Selected: " .. track_names_str(tracks))
        return true
    end

    -- sel=+<positions> / sel=<positions> with no folder label: only valid
    -- in Horizontal workflow, which has exactly one folder, so the
    -- position is unambiguous; Vertical projects must specify the folder
    -- via sel=D,N / sel=S1,N etc., since they have more than one folder.
    local add_positions_only = cmd:match("^sel=%+%s*([%d,%-%*%s]+)$")
    if add_positions_only then
        if workflow ~= "Horizontal" then
            say("Specify a folder, e.g. sel=+D," .. add_positions_only .. " or sel=+S1," .. add_positions_only)
            return true
        end
        local track_table = get_track_table()
        if not track_table[1] then
            say("No folders found")
            return true
        end
        local tracks = resolve_folder_position_list(track_table[1], add_positions_only)
        if #tracks == 0 then
            say("No matching tracks")
            return true
        end
        for _, track in ipairs(tracks) do SetTrackSelected(track, true) end
        say("Added to selection: " .. track_names_str(tracks))
        return true
    end

    local sel_positions_only = cmd:match("^sel=%s*([%d,%-%*%s]+)$")
    if sel_positions_only then
        if workflow ~= "Horizontal" then
            say("Specify a folder, e.g. sel=D," .. sel_positions_only .. " or sel=S1," .. sel_positions_only)
            return true
        end
        local track_table = get_track_table()
        if not track_table[1] then
            say("No folders found")
            return true
        end
        local tracks = resolve_folder_position_list(track_table[1], sel_positions_only)
        if #tracks == 0 then
            say("No matching tracks")
            return true
        end
        SetOnlyTrackSelected(tracks[1])
        for i = 2, #tracks do SetTrackSelected(tracks[i], true) end
        say("Selected: " .. track_names_str(tracks))
        return true
    end

    -- tr=<query>: jump to (select) the first track in the current folder
    -- (the one containing the currently selected track) whose humanized
    -- name contains <query> (case-insensitive substring match).
    local tr_query = cmd:match("^tr=(.+)$")
    if tr_query then
        local selected = GetSelectedTrack(0, 0)
        if not selected then
            say("No track selected")
            return true
        end

        local folder
        for _, f in ipairs(get_track_table()) do
            if f.parent == selected then
                folder = f
                break
            end
            for _, t in ipairs(f.tracks) do
                if t == selected then
                    folder = f
                    break
                end
            end
            if folder then break end
        end
        if not folder then
            say("Not in a ReaClassical folder")
            return true
        end

        -- If the folder is collapsed (I_FOLDERCOMPACT 2), its children
        -- aren't selectable/visible -- the selected track will be the
        -- parent in that case, so reveal them the same way the "Show
        -- Children" action does before searching.
        if GetMediaTrackInfo_Value(folder.parent, "I_FOLDERCOMPACT") == 2 then
            dofile(script_path .. "ReaClassical_Show Children.lua")
        end

        local candidates = { folder.parent }
        for _, t in ipairs(folder.tracks) do table.insert(candidates, t) end

        local query = trim(tr_query):lower()
        for _, t in ipairs(candidates) do
            local _, name = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
            if humanize_track_name(name):lower():find(query, 1, true) then
                SetOnlyTrackSelected(t)
                TrackList_AdjustWindows(false)
                say(humanize_track_name(name))
                return true
            end
        end
        say("No track found matching: " .. trim(tr_query))
        return true
    end

    return false
end

function try_markers(cmd)
    local mk_name = cmd:match("^mk=(.+)$")
    if mk_name then
        local pos = GetCursorPosition()
        AddProjectMarker2(0, false, pos, 0, trim(mk_name), -1, 0)
        say("Marker added: " .. trim(mk_name) .. " @ " .. format_timestr_pos(pos, "", -1))
        return true
    end

    if cmd == "mk?" then
        local cursor = GetCursorPosition()
        local num_markers, num_regions = CountProjectMarkers(0)
        local best_name, best_pos
        for idx = 0, num_markers + num_regions - 1 do
            local retval, isrgn, pos, _, name = EnumProjectMarkers3(0, idx)
            if retval and not isrgn and pos <= cursor then
                if not best_pos or pos > best_pos then
                    best_pos = pos
                    best_name = name
                end
            end
        end
        if best_name then
            say(best_name .. " @ " .. format_timestr_pos(best_pos, "", -1))
        else
            say("No marker found before cursor")
        end
        return true
    end

    local rg_a, rg_b = cmd:match("^rg=([^,]+),(.+)$")
    if rg_a then
        rg_a, rg_b = trim(rg_a), trim(rg_b)
        local pos_a, pos_b
        local num_markers, num_regions = CountProjectMarkers(0)
        for idx = 0, num_markers + num_regions - 1 do
            local retval, isrgn, pos, _, name = EnumProjectMarkers3(0, idx)
            if retval and not isrgn then
                if name == rg_a then pos_a = pos end
                if name == rg_b then pos_b = pos end
            end
        end
        if not pos_a or not pos_b then
            say("Could not find both markers")
            return true
        end
        local start_pos, end_pos = math.min(pos_a, pos_b), math.max(pos_a, pos_b)
        AddProjectMarker2(0, true, start_pos, end_pos, "", -1, 0)
        say("Region created: " .. rg_a .. " to " .. rg_b)
        return true
    end

    return false
end

-- Display label for a routing-chain hop: "RCM", or the destination's
-- humanized name (e.g. "Mixer track Violin", "Submix Strings").
function routing_label_for_track(dest, rcmaster)
    if rcmaster and dest == rcmaster then return "RC Master" end
    local _, name = GetSetMediaTrackInfo_String(dest, "P_NAME", "", false)
    return humanize_track_name(name)
end

-- Walks every outgoing send from start_track, following each destination's
-- own sends in turn, until each branch either reaches RCM or dead-ends.
-- Returns an array of { path = {labels...}, reached = bool }. Guards against
-- cycles/runaway chains with a visited-set per branch and a depth cap.
function build_routing_chains(start_track, rcmaster)
    local chains = {}

    local function walk(track, path, visited)
        local n = GetTrackNumSends(track, 0)
        if n == 0 then
            if #path > 0 then table.insert(chains, { path = path, reached = false }) end
            return
        end
        for i = 0, n - 1 do
            local dest = GetTrackSendInfo_Value(track, 0, i, "P_DESTTRACK")
            local new_path = {}
            for _, p in ipairs(path) do table.insert(new_path, p) end
            table.insert(new_path, routing_label_for_track(dest, rcmaster))

            if rcmaster and dest == rcmaster then
                table.insert(chains, { path = new_path, reached = true })
            elseif visited[dest] or #new_path > 8 then
                table.insert(chains, { path = new_path, reached = false })
            else
                local new_visited = {}
                for k, v in pairs(visited) do new_visited[k] = v end
                new_visited[dest] = true
                walk(dest, new_path, new_visited)
            end
        end
    end

    walk(start_track, {}, { [start_track] = true })
    return chains
end

-- Builds the FX-chain lines for a single track (no leading indent, no
-- track-name prefix), shared by the full <ref>? summary and the standalone
-- <ref>fx? query.
function format_fx_lines(track)
    local fx_count = TrackFX_GetCount(track)
    if fx_count == 0 then return { "No FX" } end
    local chain_enabled = GetMediaTrackInfo_Value(track, "I_FXEN") ~= 0
    local lines = { "track FX: " .. (chain_enabled and "enabled" or "disabled") }
    for i = 0, fx_count - 1 do
        local _, fx_name = TrackFX_GetFXName(track, i, "")
        local enabled = TrackFX_GetEnabled(track, i)
        table.insert(lines, string.format("%d. %s (%s)", i + 1, fx_name, enabled and "on" or "off"))
    end
    return lines
end

-- Resolves a selector for an existing FX on `track` to its 0-based chain
-- index, for the rmfx=/mvfx=/fxon=/fxoff= commands: a 1-based chain
-- position ("2"), or failing that a case-insensitive substring match
-- against the FX names already on the chain (first match wins), mirroring
-- how tr=text finds a track by partial name.
function resolve_fx_index(track, selector)
    local fx_count = TrackFX_GetCount(track)
    local n = tonumber(selector)
    if n then
        if n >= 1 and n <= fx_count then return n - 1 end
        return nil, "No FX at position " .. selector
    end
    local lower = selector:lower()
    for i = 0, fx_count - 1 do
        local _, fx_name = TrackFX_GetFXName(track, i, "")
        if fx_name:lower():find(lower, 1, true) then
            return i
        end
    end
    return nil, "FX not found: " .. selector
end

-- Builds the routing-to-RCM lines for a single track (no leading indent, no
-- track-name prefix), shared by the full <ref>? summary and the standalone
-- <ref>r? query. Returns nil for RCMASTER itself, since it IS the mix bus
-- terminus and has no "routing to RCM" of its own.
function format_routing_lines(track, rcmaster)
    if rcmaster and track == rcmaster then return nil end
    local chains = build_routing_chains(track, rcmaster)
    if #chains == 0 then
        return { "routing: not connected to RCM" }
    elseif #chains == 1 then
        local c = chains[1]
        return { "routing: " .. table.concat(c.path, " to ")
            .. (c.reached and "" or " (not connected to RCM)") }
    end
    local lines = { "routing:" }
    for _, c in ipairs(chains) do
        table.insert(lines, "  " .. table.concat(c.path, " to ")
            .. (c.reached and "" or " (not connected to RCM)"))
    end
    return lines
end

-- <ref>fx? / <ref>r? — single fields broken out of the <ref>? summary below
-- for standalone queries. <ref> is any single-track token resolved via
-- resolve_target() (validated with is_target() first, since the suffix is
-- stripped with a non-greedy match and could otherwise misfire on
-- unrelated commands ending in "fx?"/"r?").
function try_track_subquery(cmd)
    local fx_ref = cmd:match("^(.-)fx%?$")
    if fx_ref and is_target(fx_ref) then
        local track, err = resolve_target(fx_ref)
        if not track then
            say(err or ("Unknown target: " .. fx_ref))
            return true
        end
        say(table.concat(format_fx_lines(track), "\n  "))
        return true
    end

    local r_ref = cmd:match("^(.-)r%?$")
    if r_ref and is_target(r_ref) then
        local track, err = resolve_target(r_ref)
        if not track then
            say(err or ("Unknown target: " .. r_ref))
            return true
        end
        local routing_lines = format_routing_lines(track, get_rcmaster())
        if not routing_lines then
            say("RC Master is the mix bus terminus, no routing to report")
            return true
        end
        say(table.concat(routing_lines, "\n  "))
        return true
    end

    return false
end

-- <ref>? — full single-track summary (mute, solo, fader, pan, phase, peak,
-- routing to RCM, and FX chain) in one say() call. <ref> is a single-track
-- token resolved via resolve_target() ("1", "@", "@N", "#", "#N", "rcm");
-- deliberately not offered for "*" or ranges, since that would be a wall of
-- speech.
function try_track_query(cmd)
    local ref = cmd == "rcm?" and "rcm"
        or cmd:match("^([%#@]%d*)%?$")
        or cmd:match("^(%d+)%?$")
        or cmd:match("^(ref%d*)%?$")
        or (cmd == "rt?" and "rt")
        or (cmd == "live?" and "live")
        or (cmd == "lb?" and "lb")
    if not ref then return false end

    local track, err = resolve_target(ref)
    if not track then
        say(err or ("Unknown target: " .. ref))
        return true
    end

    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    local db = linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL"))
    local phase = GetMediaTrackInfo_Value(track, "B_PHASE") == 1

    local lines = {
        "mute:  " .. (muted and "on" or "off"),
        "solo:  " .. (soloed and "on" or "off"),
        string.format("fader: %.1f dB", db),
        "pan:   " .. format_pan(GetMediaTrackInfo_Value(track, "D_PAN")),
        "phase: " .. (phase and "inverted" or "normal"),
        "peak:  " .. format_track_peak(track),
    }

    -- Record input (N=y/n) only ever applies to plain mixer refs.
    if ref:match("^%d+$") then
        local _, disabled = GetSetMediaTrackInfo_String(track, "P_EXT:input_disabled", "", false)
        table.insert(lines, "record: " .. (disabled == "y" and "disabled" or "enabled"))
        table.insert(lines, "input: " .. rec_input_description(get_source_for_mixer(track) or track))
    end

    local routing_lines = format_routing_lines(track, get_rcmaster())
    if routing_lines then
        for _, l in ipairs(routing_lines) do table.insert(lines, l) end
    end

    for _, l in ipairs(format_fx_lines(track)) do table.insert(lines, l) end

    say(table.concat(lines, "\n"))
    return true
end

function try_mute_solo(cmd)
    -- Word-based special-track targets (ref[list], rt, live, lb) for
    -- mute/solo/polarity, resolved up front since these prefixes are
    -- ordinary letters and would otherwise collide with the regex-based
    -- numeric/@/# pattern matching below (see split_word_target()).
    local word_target, word_op = split_word_target(cmd)
    if word_target then
        local tracks, err = resolve_target_list(word_target)
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end

        if word_op == "xs" then
            for _, track in ipairs(get_mixer_tracks()) do
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            end
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 2) end
            say("Soloed " .. track_names_str(tracks))
            return true
        elseif word_op == "m" or word_op == "um" or word_op == "s" or word_op == "us" then
            local op_word
            if word_op == "m" then
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 1) end
                op_word = "Muted"
            elseif word_op == "um" then
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 0) end
                op_word = "Unmuted"
            elseif word_op == "s" then
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 2) end
                op_word = "Soloed"
            else
                for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 0) end
                op_word = "Unsoloed"
            end
            say(op_word .. " " .. track_names_str(tracks))
            return true
        elseif word_op == "i=y" or word_op == "i=n" then
            local pol_val = word_op:match("i=([yn])")
            for _, track in ipairs(tracks) do
                SetMediaTrackInfo_Value(track, "B_PHASE", pol_val == "y" and 1 or 0)
            end
            say((pol_val == "y" and "Inverted" or "Normal") .. " polarity: " .. track_names_str(tracks))
            return true
        elseif word_op == "i?" then
            for _, track in ipairs(tracks) do
                local phase = GetMediaTrackInfo_Value(track, "B_PHASE")
                local prefix = label_prefix(query_label(track, #tracks), " ")
                say(prefix .. "polarity: " .. (phase == 1 and "inverted" or "normal"))
            end
            return true
        elseif word_op == "m?" or word_op == "s?" then
            for _, track in ipairs(tracks) do
                local prefix = label_prefix(query_label(track, #tracks), " ")
                if word_op == "m?" then
                    local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
                    say(prefix .. "mute: " .. (muted and "on" or "off"))
                else
                    local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
                    say(prefix .. "solo: " .. (soloed and "on" or "off"))
                end
            end
            return true
        end
        -- Unrecognized suffix after a recognized word target (e.g. ref?,
        -- handled by try_track_query instead): fall through.
    end

    -- <target>xs: exclusive solo — unsolo/unmute every mixer track, then solo
    -- only the specified tracks. Target follows the same syntax as <target>s.
    local xs_target = cmd:match("^([%d,%-%*@#%s]+)xs$")
    if xs_target then
        local tracks, err = resolve_target_list((xs_target:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        for _, track in ipairs(get_mixer_tracks()) do
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
        end
        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "I_SOLO", 2)
        end
        say("Soloed " .. track_names_str(tracks))
        return true
    end

    -- <target>m / <target>s / <target>um / <target>us, where <target> is
    -- a mixer track list ("1", "1,3", "4-6", "1,4-6", "*") or a single
    -- "@N" aux / "#N" submix.
    local target_str, op = cmd:match("^([%d,%-%*@#%s]+)(u?[ms])$")
    if target_str then
        local tracks, err = resolve_target_list((target_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end

        local op_word
        if op == "m" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 1) end
            op_word = "Muted"
        elseif op == "um" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "B_MUTE", 0) end
            op_word = "Unmuted"
        elseif op == "s" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 2) end
            op_word = "Soloed"
        elseif op == "us" then
            for _, track in ipairs(tracks) do SetMediaTrackInfo_Value(track, "I_SOLO", 0) end
            op_word = "Unsoloed"
        end
        say(op_word .. " " .. track_names_str(tracks))
        return true
    end

    -- <target>i=y / <target>i=n: flip / reset track polarity (B_PHASE).
    local pol_target, pol_val = cmd:match("^([%d,%-%*@#%s]+)i=([yn])$")
    if pol_target then
        local tracks, err = resolve_target_list((pol_target:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end

        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "B_PHASE", pol_val == "y" and 1 or 0)
        end
        say((pol_val == "y" and "Inverted" or "Normal") .. " polarity: " .. track_names_str(tracks))
        return true
    end

    -- <target>i? query: report polarity for each track.
    local pol_query_str = cmd:match("^([%d,%-%*@#%s]+)i%?$")
    if pol_query_str then
        local tracks, err = resolve_target_list((pol_query_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end
        for _, track in ipairs(tracks) do
            local phase = GetMediaTrackInfo_Value(track, "B_PHASE")
            local prefix = label_prefix(query_label(track, #tracks), " ")
            say(prefix .. "polarity: " .. (phase == 1 and "inverted" or "normal"))
        end
        return true
    end

    -- <target>m? / <target>s? query forms.
    local query_str, query_op = cmd:match("^([%d,%-%*@#%s]+)([ms])%?$")
    if query_str then
        local tracks, err = resolve_target_list((query_str:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or "No matching tracks")
            return true
        end

        for _, track in ipairs(tracks) do
            local prefix = label_prefix(query_label(track, #tracks), " ")
            if query_op == "m" then
                local muted = GetMediaTrackInfo_Value(track, "B_MUTE") > 0
                say(prefix .. "mute: " .. (muted and "on" or "off"))
            else
                local soloed = GetMediaTrackInfo_Value(track, "I_SOLO") > 0
                say(prefix .. "solo: " .. (soloed and "on" or "off"))
            end
        end
        return true
    end

    return false
end

-- <target> here is a mixer track list ("1", "1,3", "4-6", "1,4-6", "*")
-- or a single "@N" aux / "#N" submix / "rcm", resolved via
-- resolve_target_list() so pan/fader commands accept single, range,
-- comma-separated and "*" targets uniformly.
function try_pan(cmd)
    local target_str, rest = split_word_target(cmd)
    if not target_str then
        target_str, rest = cmd:match("^([%#@]?[%d,%-%*%s]*)(.+)$")
        if not target_str then return false end
        target_str = target_str:gsub("%s+", "")
    end

    local delta = rest:match("^p([+-]%d+)$")
    if delta then
        local tracks, err = resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        for _, track in ipairs(tracks) do
            local pan = GetMediaTrackInfo_Value(track, "D_PAN")
            pan = clamp(pan + tonumber(delta) / 100, -1, 1)
            SetMediaTrackInfo_Value(track, "D_PAN", pan)
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            say(humanize_track_name(name) .. " pan: " .. format_pan(pan))
        end
        return true
    end

    local abs_val = rest:match("^p=([+-]?%d+)$")
    if abs_val then
        local tracks, err = resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        local pan = pct_to_pan(abs_val)
        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "D_PAN", pan)
        end
        say("Pan set to " .. format_pan(pan) .. ": " .. track_names_str(tracks))
        return true
    end

    if rest == "p?" then
        local tracks, err = resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        for _, track in ipairs(tracks) do
            local prefix = label_prefix(query_label(track, #tracks), ": ")
            say(prefix .. format_pan(GetMediaTrackInfo_Value(track, "D_PAN")))
        end
        return true
    end

    return false
end

function try_fader(cmd)
    local target_str, rest = split_word_target(cmd)
    if not target_str then
        target_str, rest = cmd:match("^([%#@]?[%d,%-%*%s]*)(.+)$")
        if not target_str then return false end
        target_str = target_str:gsub("%s+", "")
    end

    local delta = rest:match("^f([+-]%d+)$")
    if delta then
        local tracks, err = resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        for _, track in ipairs(tracks) do
            local db = linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL")) + tonumber(delta)
            SetMediaTrackInfo_Value(track, "D_VOL", db_to_linear(db))
            local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
            say(string.format("%s: %.1f dB", humanize_track_name(name), db))
        end
        return true
    end

    local abs_db = rest:match("^f=([+-]?%d+)$")
    if abs_db then
        local tracks, err = resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        for _, track in ipairs(tracks) do
            SetMediaTrackInfo_Value(track, "D_VOL", db_to_linear(tonumber(abs_db)))
        end
        say("Volume set to " .. abs_db .. " dB: " .. track_names_str(tracks))
        return true
    end

    if rest == "f?" then
        local tracks, err = resolve_target_list(target_str)
        if #tracks == 0 then
            say(err or ("Unknown target: " .. target_str))
            return true
        end
        for _, track in ipairs(tracks) do
            local prefix = label_prefix(query_label(track, #tracks), ": ")
            local db = linear_to_db(GetMediaTrackInfo_Value(track, "D_VOL"))
            say(string.format("%s%.1f dB", prefix, db))
        end
        return true
    end

    return false
end

-- <target>pk? — read-only peak hold (dB) for a mixer track list ("1",
-- "1,3", "4-6", "1,4-6", "*"), a single "@N" aux / "#N" submix, or "rcm",
-- resolved via resolve_target_list() (same target syntax as try_pan/try_fader).
function try_peak(cmd)
    local target_str, rest = split_word_target(cmd)
    if not target_str then
        target_str, rest = cmd:match("^([%#@]?[%d,%-%*%s]*)(.+)$")
        if not target_str then return false end
        target_str = target_str:gsub("%s+", "")
    end

    if rest ~= "pk?" then return false end

    local tracks, err = resolve_target_list(target_str)
    if #tracks == 0 then
        say(err or ("Unknown target: " .. target_str))
        return true
    end
    for _, track in ipairs(tracks) do
        local prefix = label_prefix(query_label(track, #tracks), ": ")
        say(prefix .. format_track_peak(track))
    end
    return true
end

---------------------------------------------------------------------
-- Automation (port of apply_automation() in
-- ReaClassical_Insert Automation.lua, driven by fixed parameters instead
-- of ImGui sliders, operating on the current track selection)
---------------------------------------------------------------------

-- Maps the short addauto= parameter token to its built-in track-envelope
-- name (per get_track_envelopes() in ReaClassical_Insert Automation.lua),
-- whether it needs dB<->linear conversion, and the action ID that shows
-- (and thereby creates) that envelope when it doesn't already exist.
local AUTOMATION_PARAMS = {
    vol      = { name = "Volume", db = true, show_cmd = 40406 },
    pan      = { name = "Pan", db = false, show_cmd = 40407 },
    width    = { name = "Width", db = false, show_cmd = 41870 },
    mute     = { name = "Mute", db = false, show_cmd = 40867 },
    trimvol  = { name = "Trim Volume", db = true, show_cmd = 42020 },
    prevol   = { name = "Volume (Pre-FX)", db = true, show_cmd = 41865 },
    prepan   = { name = "Pan (Pre-FX)", db = false, show_cmd = 41867 },
    prewidth = { name = "Width (Pre-FX)", db = false, show_cmd = 41869 },
}

-- Converts a user-facing addauto= value (dB for volume-like params, -1..1
-- for pan/width, 0/1 for mute) into the raw value the envelope stores.
-- Pan is negated to match REAPER's internal envelope sign convention, per
-- denormalize_value() in ReaClassical_Insert Automation.lua.
function automation_raw_value(info, value)
    if info.db then return db_to_linear(value) end
    if info.name == "Pan" or info.name == "Pan (Pre-FX)" then return -value end
    return value
end

-- Default track value to fall back on when no envelope point exists yet
-- at a ramp boundary, per get_default_track_value() in
-- ReaClassical_Insert Automation.lua.
function automation_default_value(track, info)
    if info.name == "Volume" or info.name == "Volume (Pre-FX)" or info.name == "Trim Volume" then
        return GetMediaTrackInfo_Value(track, "D_VOL")
    elseif info.name == "Pan" or info.name == "Pan (Pre-FX)" then
        return GetMediaTrackInfo_Value(track, "D_PAN")
    elseif info.name == "Width" or info.name == "Width (Pre-FX)" then
        return GetMediaTrackInfo_Value(track, "D_WIDTH")
    elseif info.name == "Mute" then
        return 1 - GetMediaTrackInfo_Value(track, "B_MUTE")
    end
    return 1.0
end

function automation_envelope_value_at(env, time)
    local br_env = BR_EnvAlloc(env, false)
    local value = BR_EnvValueAtPos(br_env, time)
    BR_EnvFree(br_env, false)
    return value
end

-- Deletes any automation item(s) on env whose range overlaps [start_t,
-- end_t), so a newly-inserted item replaces overlapping automation
-- instead of silently stacking an invisible duplicate on top of it (a
-- particular trap for blind users, who can't see the overlap to notice
-- it happened).
function delete_overlapping_automation_items(env, start_t, end_t)
    local count = CountAutomationItems(env)
    if count == 0 then return end
    local any = false
    for i = 0, count - 1 do
        local pos = GetSetAutomationItemInfo(env, i, "D_POSITION", 0, false)
        local len = GetSetAutomationItemInfo(env, i, "D_LENGTH", 0, false)
        local overlaps = pos < end_t and (pos + len) > start_t
        GetSetAutomationItemInfo(env, i, "D_UISEL", overlaps and 1 or 0, true)
        if overlaps then any = true end
    end
    if any then
        Main_OnCommand(42086, 0) -- Envelope: Delete automation items
    end
end

-- Returns the ramp-inclusive range remembered from the most recent
-- addauto=/addautoitem= call (see apply_terminal_automation()), but only
-- if [ts_start, ts_end] still exactly matches the exact selection bounds
-- that call was given — i.e. nothing has changed the selection since.
-- Returns nil, nil otherwise, so a stale memory can never silently apply
-- to a selection the user has since moved on from.
function remembered_automation_range(ts_start, ts_end)
    local _, core_start_str = GetProjExtState(0, "ReaClassical", "LastAutoCoreStart")
    local _, core_end_str = GetProjExtState(0, "ReaClassical", "LastAutoCoreEnd")
    local core_start, core_end = tonumber(core_start_str), tonumber(core_end_str)
    if not (core_start and core_end
            and math.abs(core_start - ts_start) < 0.0005
            and math.abs(core_end - ts_end) < 0.0005) then
        return nil, nil
    end

    local _, full_start_str = GetProjExtState(0, "ReaClassical", "LastAutoFullStart")
    local _, full_end_str = GetProjExtState(0, "ReaClassical", "LastAutoFullEnd")
    return tonumber(full_start_str), tonumber(full_end_str)
end

-- Applies info/value/ramp_in/ramp_out to each track in tracks, across the
-- current time selection (with ramps outside it), mirroring
-- apply_automation() in ReaClassical_Insert Automation.lua. Any existing
-- automation item overlapping the affected range is deleted first
-- regardless of as_item, so a plain-points edit correctly replaces a
-- prior item-based one (and vice versa) instead of being silently masked
-- underneath it. An automation item is only created over the new range
-- when as_item is true; otherwise the change is written directly as
-- envelope points on the main lane.
--
-- If this exact time selection was just used for a previous
-- addauto=/addautoitem= call (per remembered_automation_range()), that
-- call's full ramp-inclusive range is cleared too, even if it was wider
-- than this one's — so reusing the same selection reliably replaces
-- whatever's there (ramps included) instead of leaving old ramp debris
-- behind. The new edit's own shape (and what gets remembered afterward)
-- is still exactly what this call asked for, not the wider clear range.
--
-- Afterward, the time selection itself is left untouched (it stays
-- exactly as the user set it); instead, the ramp-inclusive range is
-- remembered in project state so a follow-up rmauto or addauto=/
-- addautoitem= can silently widen to cover it, without changing what's
-- shown as selected. See try_delete_automation() for how that memory is
-- only trusted while the selection hasn't changed since.
function apply_terminal_automation(tracks, info, value, ramp_in, ramp_out, ts_start, ts_end, as_item)
    local target_value = automation_raw_value(info, value)
    local needs_scaling = info.name == "Volume" or info.name == "Volume (Pre-FX)" or info.name == "Trim Volume"

    local ramp_in_start = ts_start - ramp_in
    local ramp_out_end = ts_end + ramp_out
    local affected_start = ramp_in > 0 and ramp_in_start or (ts_start - 0.002)
    local affected_end = ramp_out > 0 and ramp_out_end or (ts_end + 0.002)

    local clear_start, clear_end = affected_start, affected_end
    local prev_full_start, prev_full_end = remembered_automation_range(ts_start, ts_end)
    if prev_full_start and prev_full_end then
        clear_start = math.min(clear_start, prev_full_start)
        clear_end = math.max(clear_end, prev_full_end)
    end

    -- Sample the "before"/"after" values from just outside the full
    -- clear range (not just this call's own range), so the new ramp
    -- blends from the genuine surrounding context rather than a
    -- soon-to-be-deleted point from a previous wider edit.
    local query_before_time = clear_start - 0.001
    local query_after_time = clear_end + 0.001

    for _, track in ipairs(tracks) do
        local env = GetTrackEnvelopeByName(track, info.name)
        if not env then
            SetOnlyTrackSelected(track)
            Main_OnCommand(info.show_cmd, 0)
            env = GetTrackEnvelopeByName(track, info.name)
        end
        if env then
            local target_to_insert = needs_scaling and ScaleToEnvelopeMode(1, target_value) or target_value

            delete_overlapping_automation_items(env, clear_start, clear_end)

            local val_before = automation_envelope_value_at(env, query_before_time)
                or automation_default_value(track, info)
            local val_after = automation_envelope_value_at(env, query_after_time)
                or automation_default_value(track, info)

            DeleteEnvelopePointRange(env, clear_start - 0.001, clear_end + 0.001)

            local val_before_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_before) or val_before
            local val_after_to_insert = needs_scaling and ScaleToEnvelopeMode(1, val_after) or val_after

            if ramp_in > 0 then
                InsertEnvelopePoint(env, ramp_in_start, val_before_to_insert, 0, 0, false, true)
                InsertEnvelopePoint(env, ts_start, target_to_insert, 0, 0, false, true)
            else
                InsertEnvelopePoint(env, ts_start - 0.001, val_before_to_insert, 0, 0, false, true)
                InsertEnvelopePoint(env, ts_start, target_to_insert, 0, 0, false, true)
            end

            if ramp_out > 0 then
                InsertEnvelopePoint(env, ts_end, target_to_insert, 0, 0, false, true)
                InsertEnvelopePoint(env, ramp_out_end, val_after_to_insert, 0, 0, false, true)
            else
                InsertEnvelopePoint(env, ts_end, target_to_insert, 0, 0, false, true)
                InsertEnvelopePoint(env, ts_end + 0.001, val_after_to_insert, 0, 0, false, true)
            end

            Envelope_SortPoints(env)

            if as_item then
                InsertAutomationItem(env, -1, affected_start, affected_end - affected_start)
            end
        end
    end

    -- Remember both the exact selection bounds the user gave us and the
    -- ramp-inclusive range actually affected, so try_delete_automation()
    -- can widen to the latter only while the visible selection still
    -- matches the former (i.e. nothing has changed it since).
    SetProjExtState(0, "ReaClassical", "LastAutoCoreStart", tostring(ts_start))
    SetProjExtState(0, "ReaClassical", "LastAutoCoreEnd", tostring(ts_end))
    SetProjExtState(0, "ReaClassical", "LastAutoFullStart", tostring(affected_start))
    SetProjExtState(0, "ReaClassical", "LastAutoFullEnd", tostring(affected_end))
end

-- addauto=<param>,<value>[,<ramp_in>[,<ramp_out>]]: applies automation to
-- the currently-selected tracks (see sel=/sel? in try_selection()) across
-- the current time selection, with ramps outside its bounds, written
-- directly as envelope points (no automation item) — convenient for
-- building up a multi-step "staircase" automation curve one call at a
-- time. addautoitem=... takes the same arguments but wraps the change in
-- an automation item instead, so it can be moved/resized/deleted as a
-- unit. Either form replaces any pre-existing automation item overlapping
-- the affected range. Afterward, the time selection is extended to cover
-- any ramps, so a follow-up rmauto clears the whole thing (ramps
-- included) without the user needing to redraw the selection. Both
-- require a time selection — open-ended changes with no end point belong
-- to the Mixer Snapshot Manager instead.
-- <param> is one of vol/pan/width/mute/trimvol/prevol/prepan/prewidth;
-- FX parameters aren't supported here since they have no stable short
-- name across plugins. <value> is dB for the volume-like params, -1..1
-- for pan/width, 0/1 for mute. <ramp_in>/<ramp_out> are seconds and
-- default to 0.
function try_automation(cmd)
    local as_item = false
    local rest = cmd:match("^addauto=(.+)$")
    if not rest then
        rest = cmd:match("^addautoitem=(.+)$")
        as_item = true
    end
    if not rest then return false end

    local parts = {}
    for part in rest:gmatch("[^,]+") do
        table.insert(parts, trim(part))
    end

    local param_key = parts[1] and parts[1]:lower()
    local info = param_key and AUTOMATION_PARAMS[param_key]
    if not info then
        say("Unknown automation parameter. Use one of: vol, pan, width, mute, trimvol, prevol, prepan, prewidth")
        return true
    end

    local value = tonumber(parts[2])
    if not value then
        say("Usage: addauto=<param>,<value>[,<ramp_in>[,<ramp_out>]] (or addautoitem=...)")
        return true
    end

    local ramp_in = tonumber(parts[3]) or 0
    local ramp_out = tonumber(parts[4]) or 0

    local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if ts_start == ts_end then
        say("No time selection: make a time selection first, or use the Mixer Snapshot Manager for open-ended changes")
        return true
    end

    local tracks = {}
    for i = 0, CountSelectedTracks(0) - 1 do
        table.insert(tracks, GetSelectedTrack(0, i))
    end
    if #tracks == 0 then
        say("No tracks selected")
        return true
    end

    apply_terminal_automation(tracks, info, value, ramp_in, ramp_out, ts_start, ts_end, as_item)
    say(info.name .. " automation" .. (as_item and " item" or "") .. " added: " .. track_names_str(tracks))
    return true
end

-- rmauto / rmauto=* (bare, or explicit "*"): deletes ALL built-in
-- envelope automation on the currently-selected tracks within the
-- current time selection — both plain points and any overlapping
-- automation item (ramps included), across every built-in param
-- (vol/pan/width/mute/trimvol/prevol/prepan/prewidth) that already has
-- an envelope. rmauto=<param>[,<param>...] instead restricts the
-- deletion to just the named envelope(s) — needed once a track has more
-- than one automation lane active, so clearing one doesn't sweep up the
-- others. The time selection left over right after an
-- addauto=/addautoitem= call is normally exactly the area to undo, and
-- the user can always recreate a time selection to cover whatever needs
-- clearing. Requires a time selection.
--
-- If the selection still exactly matches the bounds most recently given
-- to addauto=/addautoitem= (i.e. nothing has changed it since), this
-- silently widens the deletion to that call's ramp-inclusive range too —
-- without changing what's shown as selected — so the ramps get cleared
-- even though the visible selection only covers their flat middle.
function try_delete_automation(cmd)
    local target_infos
    if cmd == "rmauto" then
        target_infos = AUTOMATION_PARAMS
    else
        local rest = cmd:match("^rmauto=(.+)$")
        if not rest then return false end

        if rest == "*" then
            target_infos = AUTOMATION_PARAMS
        else
            target_infos = {}
            for part in rest:gmatch("[^,]+") do
                local key = trim(part):lower()
                local info = AUTOMATION_PARAMS[key]
                if not info then
                    say("Unknown automation parameter: " .. trim(part) ..
                        ". Use one of: vol, pan, width, mute, trimvol, prevol, prepan, prewidth, or *")
                    return true
                end
                target_infos[key] = info
            end
        end
    end

    local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
    if ts_start == ts_end then
        say("No time selection found")
        return true
    end

    local tracks = {}
    for i = 0, CountSelectedTracks(0) - 1 do
        table.insert(tracks, GetSelectedTrack(0, i))
    end
    if #tracks == 0 then
        say("No tracks selected")
        return true
    end

    local del_start, del_end = ts_start, ts_end
    local full_start, full_end = remembered_automation_range(ts_start, ts_end)
    if full_start and full_end then
        del_start, del_end = full_start, full_end
    end

    -- Pad the boundaries slightly: a ramp point sits exactly at the
    -- edge of the (possibly widened) deletion range, so a zero-margin
    -- delete can leave it behind depending on REAPER's range
    -- inclusivity/float precision right at that edge.
    del_start = del_start - 0.001
    del_end = del_end + 0.001

    local any_item = false
    for _, track in ipairs(tracks) do
        for _, info in pairs(target_infos) do
            local env = GetTrackEnvelopeByName(track, info.name)
            if env then
                local count = CountAutomationItems(env)
                for i = 0, count - 1 do
                    local pos = GetSetAutomationItemInfo(env, i, "D_POSITION", 0, false)
                    local len = GetSetAutomationItemInfo(env, i, "D_LENGTH", 0, false)
                    local overlaps = pos < del_end and (pos + len) > del_start
                    GetSetAutomationItemInfo(env, i, "D_UISEL", overlaps and 1 or 0, true)
                    if overlaps then any_item = true end
                end
                DeleteEnvelopePointRange(env, del_start, del_end)
            end
        end
    end
    if any_item then
        Main_OnCommand(42086, 0) -- Envelope: Delete automation items
    end
    UpdateArrange()
    say("Automation deleted: " .. track_names_str(tracks))
    return true
end

-- Parses ",key=value,key=value..." into a field_updates table, mapping
-- the short keys used in terminal commands to the pipe-delimited marker
-- field names from ReaClassical_Metadata Report.lua.
function parse_ddp_fields(rest, field_map)
    local updates = {}
    for kv in rest:gmatch(",([^,]*)") do
        local k, v = kv:match("^(%a+)=(.*)$")
        if k and field_map[k] then
            updates[field_map[k]] = v
        end
    end
    return updates
end

function try_ddp(cmd)
    -- in? query: report CD marker / take metadata for the selected item.
    if cmd == "in?" then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected"); return true
        end
        local mark_index, _, _, _, name = get_item_cd_marker(item)
        local raw
        if mark_index then
            raw = name or ""
        else
            local take = GetActiveTake(item)
            if not take then
                say("No active take"); return true
            end
            local _, tname = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            raw = tname or ""
        end
        local stripped = raw:match("^[#@](.*)") or raw
        local lines = {}
        local first = true
        for part in (stripped .. "|"):gmatch("([^|]*)|") do
            if first then
                lines[#lines + 1] = "Title: " .. (part ~= "" and part or "(none)")
                first = false
            else
                local k, v = part:match("^([^=]+)=(.*)$")
                if k then lines[#lines + 1] = k .. ": " .. v end
            end
        end
        say(table.concat(lines, "\n"))
        return true
    end

    -- in=Title,pf=...,sw=...,cp=...,ar=...,msg=...,isrc=...
    local title, rest = cmd:match("^in=([^,]*)(,.+)$")
    if title then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected")
            return true
        end

        local mark_index, _, pos, rgnend, name, markrgnID, color = get_item_cd_marker(item)
        if not mark_index then
            say("No CD marker linked to this item")
            return true
        end

        local field_map = {
            pf = "PERFORMER",
            sw = "SONGWRITER",
            cp = "COMPOSER",
            ar = "ARRANGER",
            msg = "MESSAGE",
            isrc = "ISRC"
        }
        local updates = parse_ddp_fields(rest, field_map)
        local new_name = rebuild_marker_name(name, "#", trim(title), updates)
        SetProjectMarkerByIndex(0, mark_index, false, pos, rgnend, markrgnID, new_name, color)

        local take = GetActiveTake(item)
        if take then
            GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name:sub(2), true)
        end

        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Create CD Markers.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- album? query: report @-item metadata from the folder track.
    if cmd == "album?" then
        local sel_track = GetSelectedTrack(0, 0)
        local folder_track = sel_track
        if folder_track then
            local depth = GetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH")
            if depth ~= 1 then
                local idx = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
                folder_track = nil
                for i = idx - 1, 0, -1 do
                    local t = GetTrack(0, i)
                    if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
                        folder_track = t
                        break
                    end
                end
            end
        end
        local at_name = nil
        if folder_track then
            for i = 0, CountTrackMediaItems(folder_track) - 1 do
                local item = GetTrackMediaItem(folder_track, i)
                local take = GetActiveTake(item)
                if take then
                    local _, n = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    if n and n:match("^@") then
                        at_name = n
                        break
                    end
                end
            end
        end
        if not at_name then
            say("No album metadata found (run createcd first or use album= to set metadata)")
            return true
        end
        local stripped = at_name:sub(2)
        local lines = {}
        local first = true
        for part in (stripped .. "|"):gmatch("([^|]*)|") do
            if first then
                lines[#lines + 1] = "Album title: " .. (part ~= "" and part or "(none)")
                first = false
            else
                local k, v = part:match("^([^=]+)=(.*)$")
                if k then lines[#lines + 1] = k .. ": " .. v end
            end
        end
        say(table.concat(lines, "\n"))
        return true
    end

    -- album=Title,cat=...,pf=...,sw=...,cp=...,ar=...,id=...,msg=...
    -- Finds or creates the @-prefixed item on the folder track, updates its
    -- take name (the source of truth for album metadata), then re-runs
    -- createcd to sync all markers/regions.
    local album_title, album_rest = cmd:match("^album=([^,]*)(.*)$")
    if album_title then
        -- Walk selected track up to its folder parent to find the @-item
        local sel_track = GetSelectedTrack(0, 0)
        local folder_track = sel_track
        if folder_track then
            local depth = GetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH")
            if depth ~= 1 then
                local idx = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
                folder_track = nil
                for i = idx - 1, 0, -1 do
                    local t = GetTrack(0, i)
                    if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
                        folder_track = t
                        break
                    end
                end
            end
        end
        local field_map = {
            cat = "CATALOG",
            pf = "PERFORMER",
            sw = "SONGWRITER",
            cp = "COMPOSER",
            ar = "ARRANGER",
            id = "IDENTIFICATION",
            msg = "MESSAGE",
            lg = "LANGUAGE"
        }
        local updates = parse_ddp_fields(album_rest, field_map)
        -- Validate language against the known dropdown list (case-insensitive).
        if updates["LANGUAGE"] and updates["LANGUAGE"] ~= "" and updates["LANGUAGE"] ~= "0" then
            local canonical = nil
            local lower_input = updates["LANGUAGE"]:lower()
            for _, lang in ipairs(VALID_LANGUAGES) do
                if lang:lower() == lower_input then
                    canonical = lang
                    break
                end
            end
            if not canonical then
                say("Unknown language: " .. updates["LANGUAGE"])
                return true
            end
            updates["LANGUAGE"] = canonical
        end
        -- Sync "Manual Contributors Entry" proj state with whether people fields
        -- are being explicitly set or cleared.
        local people_fields = { "PERFORMER", "SONGWRITER", "COMPOSER", "ARRANGER" }
        local has_people_values = false
        local any_people_specified = false
        local all_people_zeroed = true
        for _, f in ipairs(people_fields) do
            if updates[f] and updates[f] ~= "" then
                any_people_specified = true
                if updates[f] ~= "0" then
                    has_people_values = true
                    all_people_zeroed = false
                end
            end
        end
        if has_people_values then
            SetProjExtState(0, "ReaClassical", "manual_people_entry", "1")
        elseif any_people_specified and all_people_zeroed then
            SetProjExtState(0, "ReaClassical", "manual_people_entry", "0")
        end
        -- Use the existing @-item name as base so un-specified fields are preserved.
        -- When no @-item exists yet, only include COMPOSER/PERFORMER=Various defaults
        -- if the user isn't setting any people fields themselves (to avoid polluting
        -- an explicit cp=Bach with a stray pf=Various from the scaffold).
        local base_name = nil
        if folder_track then
            for i = 0, CountTrackMediaItems(folder_track) - 1 do
                local item = GetTrackMediaItem(folder_track, i)
                local take = GetActiveTake(item)
                if take then
                    local _, n = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    if n and n:match("^@") then
                        base_name = n
                        break
                    end
                end
            end
        end
        if not base_name then
            base_name = has_people_values
                and "@MyAlbumTitle|MESSAGE=Created with ReaClassical"
                or "@MyAlbumTitle|COMPOSER=Various|PERFORMER=Various|MESSAGE=Created with ReaClassical"
        end
        local new_name = rebuild_marker_name(base_name, "@", trim(album_title), updates)
        _G.RC_TERMINAL_ARGS = { action = "set_album", name = new_name }
        dofile(script_path .. "ReaClassical_Create CD Markers.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    return false
end

function try_undo_redo(cmd)
    local n = cmd:match("^(%d*)z$")
    if n then
        local count = tonumber(n) or 1
        for _ = 1, count do
            Main_OnCommand(40029, 0)
        end
        say("Undone " .. count .. (count == 1 and " step" or " steps"))
        return true
    end

    n = cmd:match("^(%d*)y$")
    if n then
        local count = tonumber(n) or 1
        for _ = 1, count do
            Main_OnCommand(40030, 0)
        end
        say("Redone " .. count .. (count == 1 and " step" or " steps"))
        return true
    end

    return false
end

-- Moves mixer track N up/down by one position, porting reorder_track()
-- (Mission Control.lua:2679-2721): only the single "M:" track is physically
-- reordered within the mixer block (folder tracks keep their I_FOLDERDEPTH
-- positions intact), then the Vertical/Horizontal Workflow sync moves each
-- folder's media items, rec inputs and names to follow the new mixer order.
function move_mixer_track(n, direction)
    local mixer_tracks = get_mixer_tracks()
    local target = (direction == "down") and (n + 1) or (n - 1)
    if target < 1 or target > #mixer_tracks then
        return false
    end

    local from_track = mixer_tracks[n]

    local before_track
    if target < n then
        before_track = mixer_tracks[target]
    elseif target < #mixer_tracks then
        before_track = mixer_tracks[target + 1]
    else
        before_track = nil
    end

    Main_OnCommand(40297, 0) -- Unselect all tracks
    SetTrackSelected(from_track, true)

    local before_idx
    if before_track then
        before_idx = GetMediaTrackInfo_Value(before_track, "IP_TRACKNUMBER") - 1
    else
        before_idx = CountTracks(0)
    end
    ReorderSelectedTracks(before_idx, 0)

    local _, _, folder_count = get_track_table()
    if folder_count > 1 then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    else
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
    end
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    return true
end

-- mv<positions>u<count> / mv<positions>d<count>: move one or more mixer
-- tracks up/down within the mixer order. Verb-first ("mv", not bare u/d)
-- since this acts directly on the track(s) themselves, same category as
-- rm/add. <positions> is a single index ("6") or a contiguous block ("6,7"
-- or "1-3", per expand_index_list()) -- the moved tracks must stay
-- adjacent, so cross-cutting lists like "1,3" aren't supported. Each
-- block-step is a chain of adjacent move_mixer_track() swaps (ascending for
-- "up", descending for "down"), which leapfrogs the block past the single
-- neighbor track on the move side while preserving the block's internal
-- order.
function try_reorder(cmd)
    local positions_str, count_str = cmd:match("^mv([%d,%-%s]+)u(%d*)$")
    local direction = "up"
    if not positions_str then
        positions_str, count_str = cmd:match("^mv([%d,%-%s]+)d(%d*)$")
        direction = "down"
    end
    if not positions_str then return false end

    local mixer_tracks = get_mixer_tracks()
    local positions = expand_index_list(positions_str, #mixer_tracks)
    if #positions == 0 then return false end
    table.sort(positions)

    for i = 2, #positions do
        if positions[i] ~= positions[i - 1] + 1 then
            say("Only a contiguous block of tracks can be moved together")
            return true
        end
    end

    local count = tonumber(count_str) or 1
    if count < 1 then count = 1 end

    local names = {}
    for _, p in ipairs(positions) do
        local track = mixer_tracks[p]
        local _, name = track and GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        table.insert(names, humanize_track_name(name))
    end

    local p1, pk = positions[1], positions[#positions]
    local moved = 0

    for _ = 1, count do
        if direction == "up" then
            if p1 - 1 < 1 then break end
            for n = p1, pk do move_mixer_track(n, "up") end
            p1, pk = p1 - 1, pk - 1
        else
            if pk + 1 > #mixer_tracks then break end
            for n = pk, p1, -1 do move_mixer_track(n, "down") end
            p1, pk = p1 + 1, pk + 1
        end
        moved = moved + 1
    end

    if moved == 0 then
        say("Cannot move " .. table.concat(names, ", ") .. " " .. direction)
    else
        local pos_str = (p1 == pk) and tostring(p1) or (p1 .. "-" .. pk)
        say(table.concat(names, ", ") .. " moved to position " .. pos_str)
    end
    return true
end

-- Appends one new track to every folder plus a corresponding "M:" mixer
-- track, names the new position, then re-syncs via the active workflow
-- script (mirrors ReaClassical_Add Aux.lua's end-of-script dofile).
function add_mixer_track(name)
    local track_table, _, folder_count, tracks_per_group = get_track_table()
    if folder_count == 0 or not track_table[1] then
        say("No folders found")
        return
    end

    -- New mixer-block track, appended after the existing mixer block.
    local mixer_insert_idx = (folder_count + 1) * tracks_per_group
    InsertTrackAtIndex(mixer_insert_idx, true)
    local new_mixer_track = GetTrack(0, mixer_insert_idx)
    SetMediaTrackInfo_Value(new_mixer_track, "I_FOLDERDEPTH", 0)
    GetSetMediaTrackInfo_String(new_mixer_track, "P_EXT:mixer", "y", true)
    GetSetMediaTrackInfo_String(new_mixer_track, "P_EXT:mix_order", tostring(tracks_per_group + 1), true)
    if APIExists("osara_outputMessage") then
        SetMediaTrackInfo_Value(new_mixer_track, "B_SHOWINTCP", 1)
    end

    -- Capture each folder's color (parent track's color, falling back to
    -- its first child's color if the parent has none) before inserting,
    -- so the new track in each folder can match it.
    local folder_colors = {}
    for f = 0, folder_count - 1 do
        local folder = track_table[f + 1]
        local folder_color = GetTrackColor(folder.parent)
        if folder_color == 0 and folder.tracks[1] then
            folder_color = GetTrackColor(folder.tracks[1])
        end
        folder_colors[f] = folder_color
    end

    -- New child track at the end of every folder (high to low so each
    -- folder's insertion index stays valid). Tag each new track as
    -- Destination (first folder) or Source (other folders) so that
    -- delete_non_rc_tracks() in the Vertical/Horizontal Workflow sync
    -- (run below) doesn't treat it as a stray non-RC track and remove it.
    for f = folder_count - 1, 0, -1 do
        local insert_idx = (f + 1) * tracks_per_group
        local last_child_idx = insert_idx - 1
        InsertTrackAtIndex(insert_idx, true)
        local new_track = GetTrack(0, insert_idx)
        SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", -1)
        local last_child = GetTrack(0, last_child_idx)
        SetMediaTrackInfo_Value(last_child, "I_FOLDERDEPTH", 0)
        if folder_colors[f] ~= 0 then
            SetTrackColor(new_track, folder_colors[f])
        end
        if f == 0 then
            GetSetMediaTrackInfo_String(new_track, "P_EXT:Destination", "y", true)
        else
            GetSetMediaTrackInfo_String(new_track, "P_EXT:Source", "y", true)
        end
    end

    local mixer_tracks = get_mixer_tracks()
    local new_position = #mixer_tracks
    local final_name = name or ("Track " .. new_position)
    rename_mixer_position(mixer_tracks, new_position, final_name)

    if folder_count > 1 then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    else
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
    end
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    say("Track added: " .. final_name)
end

-- Generalized port of delete_tracks()/delete_mixer()
-- (Delete Track From All Groups.lua:106-140).
function remove_mixer_track(n)
    local _, _, folder_count, tracks_per_group = get_track_table()
    local child_count = tracks_per_group - 1
    local track_idx = n - 1

    if folder_count == 0 then
        say("No folders found")
        return
    end
    if tracks_per_group == 2 then
        say("Already at the minimum number of tracks to form a folder")
        return
    end
    if track_idx <= 0 or track_idx > child_count then
        say("Cannot remove mixer track " .. n)
        return
    end

    local removed_track = get_mixer_tracks()[n]
    local _, removed_name = GetSetMediaTrackInfo_String(removed_track, "P_NAME", "", false)
    removed_name = humanize_track_name(removed_name)

    if track_idx == child_count then
        move_mixer_track(n, "up")
        track_idx = track_idx - 1
        n = n - 1
    end

    local similar_tracks = {}
    for i = track_idx + (folder_count - 1) * tracks_per_group, track_idx, -tracks_per_group do
        table.insert(similar_tracks, i)
    end
    for _, idx in ipairs(similar_tracks) do
        DeleteTrack(GetTrack(0, idx))
    end

    local mixer_location = (folder_count * (tracks_per_group - 1)) + track_idx
    DeleteTrack(GetTrack(0, mixer_location))

    if folder_count > 1 then
        dofile(script_path .. "ReaClassical_Vertical Workflow.lua")
    else
        dofile(script_path .. "ReaClassical_Horizontal Workflow.lua")
    end
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    say("Track removed: " .. removed_name)
end

function try_add_remove(cmd)
    local add_name = cmd:match("^add=(.+)$")
    if cmd == "add" or add_name then
        add_mixer_track(add_name and trim(add_name) or nil)
        return true
    end

    local rm_n = cmd:match("^rm(%d+)$")
    if rm_n then
        remove_mixer_track(tonumber(rm_n))
        return true
    end

    local aux_name = cmd:match("^add@=(.+)$")
    if cmd == "add@" or aux_name then
        dofile(script_path .. "ReaClassical_Add Aux.lua")
        local list = get_special_tracks_by_type("aux")
        local info = list[#list]
        if info then
            if aux_name then
                GetSetMediaTrackInfo_String(info.track, "P_NAME", "@" .. trim(aux_name), true)
            end
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            say("Aux added: " .. humanize_track_name(name))
        end
        return true
    end

    local sub_name = cmd:match("^add#=(.+)$")
    if cmd == "add#" or sub_name then
        dofile(script_path .. "ReaClassical_Add Submix.lua")
        local list = get_special_tracks_by_type("submix")
        local info = list[#list]
        if info then
            if sub_name then
                GetSetMediaTrackInfo_String(info.track, "P_NAME", "#" .. trim(sub_name), true)
            end
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            say("Submix added: " .. humanize_track_name(name))
        end
        return true
    end

    local rm_aux = cmd:match("^rm@(%d*)$")
    if rm_aux then
        local info, err = resolve_special_index(get_special_tracks_by_type("aux"), rm_aux, "aux", "@")
        if info then
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            DeleteTrack(info.track)
            say("Aux removed: " .. humanize_track_name(name))
        else
            say(err)
        end
        return true
    end

    local rm_sub = cmd:match("^rm#(%d*)$")
    if rm_sub then
        local info, err = resolve_special_index(get_special_tracks_by_type("submix"), rm_sub, "submix", "#")
        if info then
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            DeleteTrack(info.track)
            say("Submix removed: " .. humanize_track_name(name))
        else
            say(err)
        end
        return true
    end

    -- addlb=N: add a listenback track armed on hardware input N (1-based),
    -- or just retune the input if a listenback track already exists.
    local lb_input = cmd:match("^addlb=(%d+)$")
    if lb_input then
        local existing = get_special_tracks_by_type("listenback")
        if #existing > 0 then
            SetMediaTrackInfo_Value(existing[1].track, "I_RECINPUT", tonumber(lb_input) - 1)
            say("Listenback input set to " .. lb_input)
            return true
        end

        local insert_idx = CountTracks(0)
        InsertTrackAtIndex(insert_idx, false)
        local lb_track = GetTrack(0, insert_idx)

        GetSetMediaTrackInfo_String(lb_track, "P_EXT:listenback", "y", true)
        GetSetMediaTrackInfo_String(lb_track, "P_NAME", "LISTENBACK", true)
        SetMediaTrackInfo_Value(lb_track, "I_RECINPUT", tonumber(lb_input) - 1)
        SetMediaTrackInfo_Value(lb_track, "I_RECMON", 1)
        SetMediaTrackInfo_Value(lb_track, "I_RECARM", 1)
        SetMediaTrackInfo_Value(lb_track, "I_RECMODE", 2)
        SetMediaTrackInfo_Value(lb_track, "B_MAINSEND", 1)
        SetMediaTrackInfo_Value(lb_track, "B_SHOWINTCP", 0)
        SetMediaTrackInfo_Value(lb_track, "B_SHOWINMIXER", 1)
        SetMediaTrackInfo_Value(lb_track, "D_VOL", 1.0)

        local fx_idx = TrackFX_AddByName(lb_track, "ListenbackMicMonitor", false, -1)
        if fx_idx < 0 then
            TrackFX_AddByName(lb_track, "JS:ListenbackMicMonitor", false, -1)
        end

        say("Listenback track added, input " .. lb_input)
        return true
    end

    if cmd == "rmlb" then
        local lb_list = get_special_tracks_by_type("listenback")
        if #lb_list == 0 then
            say("No listenback track found")
            return true
        end
        DeleteTrack(lb_list[1].track)
        say("Listenback track removed")
        return true
    end

    local rm_ref = cmd:match("^rmref(%d*)$")
    if rm_ref then
        local info, err = resolve_special_index(get_special_tracks_by_type("reference"), rm_ref, "REF", "")
        if info then
            local _, name = GetSetMediaTrackInfo_String(info.track, "P_NAME", "", false)
            DeleteTrack(info.track)
            say("Reference track removed: " .. humanize_track_name(name))
        else
            say(err)
        end
        return true
    end

    if cmd == "rmrt" then
        local rt_list = get_special_tracks_by_type("roomtone")
        if #rt_list == 0 then
            say("No RoomTone track found")
            return true
        end
        DeleteTrack(rt_list[1].track)
        say("RoomTone track removed")
        return true
    end

    if cmd == "rmlive" then
        local live_list = get_special_tracks_by_type("live")
        if #live_list == 0 then
            say("No LIVE track found")
            return true
        end
        DeleteTrack(live_list[1].track)
        say("LIVE track removed")
        return true
    end

    return false
end

-- True for any single-track selector token understood by resolve_target:
-- "rcm", "N", "@N", "#N", "@" (the only aux), "#" (the only submix).
function is_target(str)
    return str == "rcm" or str:match("^%d+$") ~= nil or str:match("^[%#@]%d*$") ~= nil
        or str:match("^ref%d*$") ~= nil or str == "rt" or str == "live" or str == "lb"
end

function try_routing_fx(cmd)
    -- Word-based special-track targets (ref[list], rt, live, lb, rcm), resolved
    -- up front since these prefixes are ordinary letters (see
    -- split_word_target()). Shared by the -rcm/rcm?/fx= blocks below.
    local word_target, word_rest = split_word_target(cmd)

    if cmd == "*/*#" or cmd == "*/*@" then
        local kind = (cmd == "*/*#") and "submix" or "aux"
        local targets = get_special_tracks_by_type(kind)
        for _, mixer_track in ipairs(get_mixer_tracks()) do
            for _, info in ipairs(targets) do
                remove_send_to(mixer_track, info.track)
            end
        end
        say("All sends to " .. kind .. "es removed")
        return true
    end

    -- List/range forms: "<list>-rcm" (connect) / "<list>/rcm" (disconnect)
    -- <list> is "*", "N", "N-M", "N,M", "N,M-P", ... (mixer tracks), or
    -- "ref"/"ref<list>" for reference tracks.
    local is_ref_list = word_target and word_target:match("^ref")
    local list_target = (is_ref_list and word_rest == "-rcm" and word_target)
        or cmd:match("^([%d,%-%*%s]+)-rcm$")
    local list_connect = true
    if not list_target then
        list_target = (is_ref_list and word_rest == "/rcm" and word_target)
            or cmd:match("^([%d,%-%*%s]+)/rcm$")
        list_connect = false
    end
    if list_target then
        local tracks, err = resolve_target_list((list_target:gsub("%s+", "")))
        if #tracks == 0 then
            say(err or ("Unknown target: " .. list_target))
            return true
        end
        for _, track in ipairs(tracks) do
            set_rcm_connection(track, list_connect)
        end
        say((list_connect and "Connected to RCM: " or "Disconnected from RCM: ") .. track_names_str(tracks))
        return true
    end

    local query_target = (word_target and word_rest == "-rcm?" and word_target)
        or cmd:match("^([%#@]?%d*)-rcm%?$")
    if query_target then
        local track, err = resolve_target(query_target)
        if not track then
            say(err or ("Unknown target: " .. query_target))
            return true
        end
        local _, state = GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect", "", false)
        say("RCM connection: " .. (state == "y" and "disconnected" or "connected"))
        return true
    end

    local rcm_target = (word_target and word_rest == "-rcm" and word_target)
        or cmd:match("^([%#@]?%d*)-rcm$")
    local connect = true
    if not rcm_target then
        rcm_target = (word_target and word_rest == "/rcm" and word_target)
            or cmd:match("^([%#@]?%d*)/rcm$")
        connect = false
    end
    if rcm_target then
        local track, err = resolve_target(rcm_target)
        if not track then
            say(err or ("Unknown target: " .. rcm_target))
            return true
        end
        set_rcm_connection(track, connect)
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        say((connect and "Connected to RCM: " or "Disconnected from RCM: ") .. humanize_track_name(name))
        return true
    end

    local fx_target, fx_name, fx_pos
    if word_target then
        fx_name, fx_pos = word_rest:match("^fx=([^,]+),(%d+)$")
        if not fx_name then fx_name = word_rest:match("^fx=(.+)$") end
        if fx_name then fx_target = word_target end
    end
    if not fx_target then
        fx_target, fx_name, fx_pos = cmd:match("^([%#@]?%d*)fx=([^,]+),(%d+)$")
    end
    if not fx_target then
        fx_target, fx_name = cmd:match("^([%#@]?%d*)fx=(.+)$")
    end
    if fx_target then
        local track, err = resolve_target(fx_target)
        if not track then
            say(err or ("Unknown target: " .. fx_target))
            return true
        end
        local idx = TrackFX_AddByName(track, trim(fx_name), false, -1)
        if idx < 0 then
            say("FX not found: " .. fx_name)
        else
            if fx_pos then
                TrackFX_CopyToTrack(track, idx, track, tonumber(fx_pos) - 1, true)
            end
            say("FX added: " .. trim(fx_name))
        end
        return true
    end

    -- <ref>rmfx=selector: remove an existing FX from the chain. `selector`
    -- is a 1-based chain position or a case-insensitive substring of the
    -- FX's name (see resolve_fx_index()). Verb leads the noun ("rmfx", not
    -- "fxrm") since "rm" is an action on "fx", whereas fxon=/fxoff= keep
    -- "fx" first because "on"/"off" describe a state of it, not an action.
    local rmfx_target, rmfx_sel
    if word_target then
        rmfx_sel = word_rest:match("^rmfx=(.+)$")
        if rmfx_sel then rmfx_target = word_target end
    end
    if not rmfx_target then
        rmfx_target, rmfx_sel = cmd:match("^([%#@]?%d*)rmfx=(.+)$")
    end
    if rmfx_target then
        local track, err = resolve_target(rmfx_target)
        if not track then
            say(err or ("Unknown target: " .. rmfx_target))
            return true
        end
        local idx, fx_err = resolve_fx_index(track, rmfx_sel)
        if not idx then
            say(fx_err)
            return true
        end
        local _, removed_name = TrackFX_GetFXName(track, idx, "")
        TrackFX_Delete(track, idx)
        say("FX removed: " .. removed_name)
        return true
    end

    -- <ref>mvfx=selector,N: move an existing FX directly to absolute chain
    -- position N (clamped in-range). N is required -- there's no bare
    -- <ref>mvfx=selector form. Verb-first, same reasoning as rmfx= above.
    local mvfx_target, mvfx_sel, mvfx_pos
    if word_target then
        mvfx_sel, mvfx_pos = word_rest:match("^mvfx=([^,]+),(%d+)$")
        if mvfx_sel then mvfx_target = word_target end
    end
    if not mvfx_target then
        mvfx_target, mvfx_sel, mvfx_pos = cmd:match("^([%#@]?%d*)mvfx=([^,]+),(%d+)$")
    end
    if mvfx_target then
        local track, err = resolve_target(mvfx_target)
        if not track then
            say(err or ("Unknown target: " .. mvfx_target))
            return true
        end
        local idx, fx_err = resolve_fx_index(track, mvfx_sel)
        if not idx then
            say(fx_err)
            return true
        end
        local new_idx = clamp(tonumber(mvfx_pos) - 1, 0, TrackFX_GetCount(track) - 1)
        local _, fx_name = TrackFX_GetFXName(track, idx, "")
        TrackFX_CopyToTrack(track, idx, track, new_idx, true)
        say(fx_name .. " moved to position " .. (new_idx + 1))
        return true
    end

    -- <ref>fxon=selector / <ref>fxoff=selector: enable/disable (bypass) an
    -- existing FX without removing it from the chain.
    local fxen_target, fxen_sel, fxen_state
    if word_target then
        fxen_sel = word_rest:match("^fxon=(.+)$")
        if fxen_sel then
            fxen_target, fxen_state = word_target, true
        else
            fxen_sel = word_rest:match("^fxoff=(.+)$")
            if fxen_sel then fxen_target, fxen_state = word_target, false end
        end
    end
    if not fxen_target then
        fxen_target, fxen_sel = cmd:match("^([%#@]?%d*)fxon=(.+)$")
        if fxen_target then fxen_state = true end
    end
    if not fxen_target then
        fxen_target, fxen_sel = cmd:match("^([%#@]?%d*)fxoff=(.+)$")
        if fxen_target then fxen_state = false end
    end
    if fxen_target then
        local track, err = resolve_target(fxen_target)
        if not track then
            say(err or ("Unknown target: " .. fxen_target))
            return true
        end
        local idx, fx_err = resolve_fx_index(track, fxen_sel)
        if not idx then
            say(fx_err)
            return true
        end
        TrackFX_SetEnabled(track, idx, fxen_state)
        local _, fx_name = TrackFX_GetFXName(track, idx, "")
        say(fx_name .. ": " .. (fxen_state and "on" or "off"))
        return true
    end

    -- <ref>fxon / <ref>fxoff (no "=selector"): enable/disable the whole
    -- chain at once via REAPER's track-level FX bypass flag (I_FXEN) --
    -- the same master bypass as the button at the top of the FX chain
    -- window, leaving every individual FX's own on/off state untouched.
    local fxall_target, fxall_state
    if word_target then
        if word_rest == "fxon" then
            fxall_target, fxall_state = word_target, true
        elseif word_rest == "fxoff" then
            fxall_target, fxall_state = word_target, false
        end
    end
    if not fxall_target then
        local t = cmd:match("^([%#@]?%d*)fxon$")
        if t then fxall_target, fxall_state = t, true end
    end
    if not fxall_target then
        local t = cmd:match("^([%#@]?%d*)fxoff$")
        if t then fxall_target, fxall_state = t, false end
    end
    if fxall_target then
        local track, err = resolve_target(fxall_target)
        if not track then
            say(err or ("Unknown target: " .. fxall_target))
            return true
        end
        SetMediaTrackInfo_Value(track, "I_FXEN", fxall_state and 1 or 0)
        say("All FX: " .. (fxall_state and "on" or "off"))
        return true
    end

    local a, b = cmd:match("^([^%-/]+)-([^%-/]+)$")
    if a and is_target(a) and is_target(b) then
        local track_a, err_a = resolve_target(a)
        local track_b, err_b = resolve_target(b)
        if track_a and track_b then
            CreateTrackSend(track_a, track_b)
            local _, name_a = GetSetMediaTrackInfo_String(track_a, "P_NAME", "", false)
            local _, name_b = GetSetMediaTrackInfo_String(track_b, "P_NAME", "", false)
            say("Send created: " .. humanize_track_name(name_a) .. " to " .. humanize_track_name(name_b))
        else
            say(err_a or err_b or "Unknown target")
        end
        return true
    end

    local ra, rb = cmd:match("^([^%-/]+)/([^%-/]+)$")
    if ra and is_target(ra) and is_target(rb) then
        local track_a, err_a = resolve_target(ra)
        local track_b, err_b = resolve_target(rb)
        if track_a and track_b then
            remove_send_to(track_a, track_b)
            local _, name_a = GetSetMediaTrackInfo_String(track_a, "P_NAME", "", false)
            local _, name_b = GetSetMediaTrackInfo_String(track_b, "P_NAME", "", false)
            say("Send removed: " .. humanize_track_name(name_a) .. " to " .. humanize_track_name(name_b))
        else
            say(err_a or err_b or "Unknown target")
        end
        return true
    end

    return false
end

function format_session_time(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    return string.format("%dh %02dm", h, m)
end

function get_project_age_str()
    local retval, creation_date = GetProjExtState(0, "ReaClassical", "CreationDate")
    if retval and creation_date ~= "" then
        local year, month, day, hour, min, sec = creation_date:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if year then
            local t = os.time({
                year = tonumber(year) or 0,
                month = tonumber(month) or 0,
                day = tonumber(day) or 0,
                hour = tonumber(hour) or 0,
                min = tonumber(min) or 0,
                sec = tonumber(sec) or 0
            })
            local age = os.time() - t
            local days = math.floor(age / 86400)
            if days >= 365 then return "> 1 year" end
            local hours = math.floor((age % 86400) / 3600)
            local minutes = math.floor((age % 3600) / 60)
            return string.format("%d days, %dh %02dm", days, hours, minutes)
        end
    end
    return "n/a"
end

function get_session_time_str()
    local retval, stored = GetProjExtState(0, "ReaClassical", "SessionStart")
    if retval and stored ~= "" then
        local start = tonumber(stored)
        if start then return format_session_time(os.time() - start) end
    end
    return "n/a"
end

function get_reaclassical_version()
    if not APIExists("ReaPack_GetOwner") then return "n/a" end
    local path = ({ get_action_context() })[2]
    if not path or path == "" then return "n/a" end
    local entry = ReaPack_GetOwner(path)
    if not entry then return "n/a" end
    local info = { ReaPack_GetEntryInfo(entry) }
    ReaPack_FreeEntry(entry)
    return (info[1] and info[7] and info[7] ~= "") and info[7] or "n/a"
end

---------------------------------------------------------------------

-- Gathers every project-wide number used by stats? and stats.key? so neither
-- has to duplicate the track/item scans.
function compute_stats()
    local _, _, folder_count, tracks_per_group, mixer_tracks = get_track_table()
    local num_tracks = CountTracks(0)
    local num_items = CountMediaItems(0)

    local num_cd_markers, num_regions = 0, 0
    local total_project_length, album_end = 0, nil
    local nm, nr = CountProjectMarkers(0)
    for i = 0, nm + nr - 1 do
        local retval, isrgn, pos, _, name = EnumProjectMarkers(i)
        if retval then
            if name:match("^#") then num_cd_markers = num_cd_markers + 1 end
            if name == "=END" then album_end = pos end
            if isrgn then num_regions = num_regions + 1 end
        end
    end

    for i = 0, num_items - 1 do
        local item = GetMediaItem(0, i)
        if item then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            total_project_length = math.max(total_project_length, pos + len)
        end
    end

    local total_source_length = 0
    local counted_folders = 0
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if track then
            local depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            if depth == 1 then counted_folders = counted_folders + 1 end
            if counted_folders > 1 then
                for j = 0, CountTrackMediaItems(track) - 1 do
                    local item = GetTrackMediaItem(track, j)
                    if item then
                        total_source_length = total_source_length + GetMediaItemInfo_Value(item, "D_LENGTH")
                    end
                end
            end
        end
    end

    local num_sd_edits, num_splits = 0, 0
    if num_tracks > 0 then
        local first_track = GetTrack(0, 0)
        local ti_count = CountTrackMediaItems(first_track)
        for j = 0, ti_count - 1 do
            local item = GetTrackMediaItem(first_track, j)
            if item then
                local _, sd = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
                if sd ~= "" then num_sd_edits = num_sd_edits + 1 end
            end
        end
        for j = 0, ti_count - 1 do
            local item1 = GetTrackMediaItem(first_track, j)
            if item1 then
                local p1 = GetMediaItemInfo_Value(item1, "D_POSITION")
                local e1 = p1 + GetMediaItemInfo_Value(item1, "D_LENGTH")
                for k = j + 1, ti_count - 1 do
                    local item2 = GetTrackMediaItem(first_track, k)
                    if item2 and GetMediaItemInfo_Value(item2, "D_POSITION") < e1 then
                        num_splits = num_splits + 1
                    end
                end
            end
        end
    end

    local num_fx, num_auto = 0, 0
    for i = 0, num_tracks - 1 do
        local track = GetTrack(0, i)
        if track then
            num_fx = num_fx + TrackFX_GetCount(track)
            for e = 0, CountTrackEnvelopes(track) - 1 do
                local env = GetTrackEnvelope(track, e)
                if env then
                    local _, chunk = GetEnvelopeStateChunk(env, "", false)
                    if chunk:match("VIS 1") and CountEnvelopePoints(env) > 0 then
                        num_auto = num_auto + 1
                    end
                end
            end
        end
    end

    return {
        folder_count = folder_count,
        tracks_per_group = tracks_per_group,
        mixer_tracks = mixer_tracks,
        num_items = num_items,
        num_cd_markers = num_cd_markers,
        num_regions = num_regions,
        total_project_length = total_project_length,
        album_end = album_end,
        total_source_length = total_source_length,
        num_sd_edits = num_sd_edits,
        num_splits = num_splits,
        num_fx = num_fx,
        num_auto = num_auto,
        num_special = #get_special_tracks(),
    }
end

local function get_ver_str()
    return "ReaClassical " .. get_reaclassical_version() .. ", REAPER " ..
        (GetAppVersion():match("^(%d+%.%d+)") or "?")
end

local function add_tracks_lines(lines, s)
    lines[#lines + 1] = "Mixer tracks:"
    for i, track in ipairs(s.mixer_tracks) do
        local _, name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        lines[#lines + 1] = string.format("  %d: %s", i, humanize_track_name(name))
    end
    local aux_tracks = get_special_tracks_by_type("aux")
    if #aux_tracks > 0 then
        lines[#lines + 1] = "Aux tracks:"
        for i, info in ipairs(aux_tracks) do
            lines[#lines + 1] = string.format("  @%d: %s", i, info.name)
        end
    end
    local submix_tracks = get_special_tracks_by_type("submix")
    if #submix_tracks > 0 then
        lines[#lines + 1] = "Submix tracks:"
        for i, info in ipairs(submix_tracks) do
            lines[#lines + 1] = string.format("  #%d: %s", i, info.name)
        end
    end
    local rcmaster = get_rcmaster()
    if rcmaster then
        local _, rname = GetSetMediaTrackInfo_String(rcmaster, "P_NAME", "", false)
        lines[#lines + 1] = "RC Master: " .. humanize_track_name(rname)
    else
        lines[#lines + 1] = "RC Master: none"
    end
end

local function add_selection_line(lines)
    lines[#lines + 1] = "Selection: " .. CountSelectedTracks(0) .. " track(s), " ..
        CountSelectedMediaItems(0) .. " item(s), cursor: " ..
        format_timestr(GetCursorPosition(), "")
end

-- Builds the same lines stats? speaks, for both speech and stats.cp clipboard text.
local function build_report_lines(s)
    local lines = {}
    lines[#lines + 1] = "Workflow: " .. (workflow ~= "" and workflow or "(none)") .. ", " .. get_ver_str()
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Album Stats:"
    lines[#lines + 1] = "  Final album length: " .. (s.album_end and format_timestr(s.album_end, "") or "n/a")
    lines[#lines + 1] = "  CD markers: " .. s.num_cd_markers
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Project Stats:"
    lines[#lines + 1] = "  Project age: " .. get_project_age_str()
    lines[#lines + 1] = "  Session time: " .. get_session_time_str()
    lines[#lines + 1] = "  Total project length: " .. format_timestr(s.total_project_length, "")
    lines[#lines + 1] = "  Total source material: " .. format_timestr(s.total_source_length, "")
    lines[#lines + 1] = "  Items: " .. s.num_items
    lines[#lines + 1] = "  Folders: " .. s.folder_count .. ", tracks per group: " .. s.tracks_per_group ..
        ", mixer tracks: " .. #s.mixer_tracks
    lines[#lines + 1] = "  Special tracks: " .. s.num_special .. ", regions: " .. s.num_regions
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Edit Stats:"
    lines[#lines + 1] = "  S-D edits: " .. s.num_sd_edits .. ", item splits: " .. s.num_splits
    lines[#lines + 1] = ""
    lines[#lines + 1] = "FX & Automation:"
    lines[#lines + 1] = "  FX: " .. s.num_fx .. ", automation lanes: " .. s.num_auto
    lines[#lines + 1] = ""
    add_tracks_lines(lines, s)
    lines[#lines + 1] = ""
    add_selection_line(lines)
    return lines
end

local function say_lines(lines)
    for _, line in ipairs(lines) do
        say(line)
    end
end

local function copy_to_clipboard(text)
    if not APIExists("CF_SetClipboard") then
        say("SWS extension required for clipboard copy")
        return
    end
    CF_SetClipboard(text)
    say("Copied to clipboard")
end

function try_stats(cmd)
    if cmd == "stats?" then
        local _, existing = GetProjExtState(0, "ReaClassical", "SessionStart")
        if existing == "" then
            SetProjExtState(0, "ReaClassical", "SessionStart", tostring(os.time()))
        end

        say_lines(build_report_lines(compute_stats()))
        return true
    end

    if cmd == "stats.cp" then
        local _, existing = GetProjExtState(0, "ReaClassical", "SessionStart")
        if existing == "" then
            SetProjExtState(0, "ReaClassical", "SessionStart", tostring(os.time()))
        end

        copy_to_clipboard(table.concat(build_report_lines(compute_stats()), "\n"))
        return true
    end

    if cmd == "stats.cpver" then
        copy_to_clipboard(get_ver_str())
        return true
    end

    if cmd == "stats.ver?" then
        say(get_ver_str())
        return true
    end

    if cmd == "stats.albumlen?" then
        local s = compute_stats()
        say("Final album length: " .. (s.album_end and format_timestr(s.album_end, "") or "n/a"))
        return true
    end

    if cmd == "stats.cdmarkers?" then
        say("CD markers: " .. compute_stats().num_cd_markers)
        return true
    end

    if cmd == "stats.age?" then
        say("Project age: " .. get_project_age_str())
        return true
    end

    if cmd == "stats.session?" then
        local _, existing = GetProjExtState(0, "ReaClassical", "SessionStart")
        if existing == "" then
            SetProjExtState(0, "ReaClassical", "SessionStart", tostring(os.time()))
        end
        say("Session time: " .. get_session_time_str())
        return true
    end

    if cmd == "stats.session" then
        SetProjExtState(0, "ReaClassical", "SessionStart", tostring(os.time()))
        say("Session timer reset")
        return true
    end

    if cmd == "stats.projlen?" then
        say("Total project length: " .. format_timestr(compute_stats().total_project_length, ""))
        return true
    end

    if cmd == "stats.srclen?" then
        say("Total source material: " .. format_timestr(compute_stats().total_source_length, ""))
        return true
    end

    if cmd == "stats.items?" then
        say("Items: " .. compute_stats().num_items)
        return true
    end

    if cmd == "stats.folders?" then
        local s = compute_stats()
        say("Folders: " .. s.folder_count .. ", tracks per group: " .. s.tracks_per_group)
        return true
    end

    if cmd == "stats.special?" then
        say("Special tracks: " .. compute_stats().num_special)
        return true
    end

    if cmd == "stats.regions?" then
        say("Regions: " .. compute_stats().num_regions)
        return true
    end

    if cmd == "stats.edits?" then
        local s = compute_stats()
        say("S-D edits: " .. s.num_sd_edits .. ", item splits: " .. s.num_splits)
        return true
    end

    if cmd == "stats.fx?" then
        local s = compute_stats()
        say("FX: " .. s.num_fx .. ", automation lanes: " .. s.num_auto)
        return true
    end

    if cmd == "stats.tracks?" then
        local lines = {}
        add_tracks_lines(lines, compute_stats())
        say_lines(lines)
        return true
    end

    if cmd == "stats.sel?" then
        local lines = {}
        add_selection_line(lines)
        say_lines(lines)
        return true
    end

    return false
end

-- pr=N, pr=a,N, pr=0, pt=N: delegate to ReaClassical_Set Item Playback Rate.lua
-- via the headless hook, so timestretch ripples subsequent items in the same
-- folder exactly as the GUI tool does.
function try_playrate_pitch(cmd)
    if cmd == "pr=0" then
        _G.RC_TERMINAL_ARGS = { action = "reset_rate" }
        dofile(script_path .. "ReaClassical_Set Item Playback Rate.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- pr=a,N -> absolute rate change of N% from normal speed
    local abs_rate = cmd:match("^pr=a,([+-]?[%d.]+)$")
    if abs_rate then
        _G.RC_TERMINAL_ARGS = { action = "rate", value = tonumber(abs_rate), relative = false }
        dofile(script_path .. "ReaClassical_Set Item Playback Rate.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- pr=N -> rate change of N% relative to the current rate
    local rel_rate = cmd:match("^pr=([+-]?[%d.]+)$")
    if rel_rate then
        _G.RC_TERMINAL_ARGS = { action = "rate", value = tonumber(rel_rate), relative = true }
        dofile(script_path .. "ReaClassical_Set Item Playback Rate.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- pt=N -> set pitch to N semitones (pt=0 resets to normal)
    local pitch = cmd:match("^pt=([+-]?[%d.]+)$")
    if pitch then
        _G.RC_TERMINAL_ARGS = { action = "pitch", value = tonumber(pitch) }
        dofile(script_path .. "ReaClassical_Set Item Playback Rate.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    if cmd == "pr?" then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected"); return true
        end
        local take = GetActiveTake(item)
        if not take then
            say("No active take"); return true
        end
        local rate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
        say(string.format("Playrate: %.4f%s", rate, math.abs(rate - 1.0) < 0.0001 and " (normal)" or ""))
        return true
    end

    if cmd == "pt?" then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected"); return true
        end
        local take = GetActiveTake(item)
        if not take then
            say("No active take"); return true
        end
        local pitch_val = GetMediaItemTakeInfo_Value(take, "D_PITCH")
        say(string.format("Pitch: %+.2f semitones%s", pitch_val, math.abs(pitch_val) < 0.001 and " (normal)" or ""))
        return true
    end

    return false
end

function try_misc(cmd)
    if cmd == "newtab" then
        Main_OnCommand(40859, 0) -- File: New project tab
        return true
    end

    -- help — open the local offline copy of the Terminal command reference.
    if cmd == "help" then
        if not APIExists("CF_ShellExecute") then
            say("SWS/S&M extension required to open the guide")
            return true
        end
        local resource_path = GetResourcePath()
        local pathseparator = package.config:sub(1, 1)
        local html = table.concat({
            resource_path, "Scripts", "chmaha Scripts", "ReaClassical", "ReaClassical-Terminal-Guide.html"
        }, pathseparator)
        local file = io.open(html, "r")
        if file then
            io.close(file)
            CF_ShellExecute(html)
        else
            say("Re-install ReaClassical metapackage via ReaPack first")
        end
        return true
    end

    if cmd == "factoryreset" then
        dofile(script_path .. "ReaClassical_Factory Reset.lua")
        return true
    end

    -- allowgui=y/n: override the OSARA-installed GUI block so ReaImGui
    -- windows (Mission Control, Notes, Preferences, etc.) can be opened
    -- again even with OSARA active; allowgui? reports the current state.
    local allowgui_val = cmd:match("^allowgui=([yn])$")
    if allowgui_val then
        SetExtState("ReaClassical", "AllowGui", allowgui_val, true)
        say(allowgui_val == "y" and "GUI windows allowed" or "GUI windows blocked while OSARA is installed")
        return true
    end

    if cmd == "allowgui?" then
        local allowed = GetExtState("ReaClassical", "AllowGui") == "y"
        say(allowed and "GUI windows allowed" or "GUI windows blocked while OSARA is installed")
        return true
    end

    -- debug=on/off: toggle the console-message fallback used by say() (in
    -- ReaClassical_Announce.lua) on platforms without OSARA (e.g. testing
    -- on Linux), so announcements can be checked without the real plugin
    -- installed; debug? reports the current state.
    local debug_val = cmd:match("^debug=(%a+)$")
    if debug_val == "on" or debug_val == "off" then
        SetExtState("ReaClassical", "DebugAnnounce", debug_val, true)
        say(debug_val == "on" and "Debug announcements on" or "Debug announcements off")
        return true
    end

    if cmd == "debug?" then
        local on = GetExtState("ReaClassical", "DebugAnnounce") == "on"
        say(on and "Debug announcements on" or "Debug announcements off")
        return true
    end

    -- nudge=<ms>: sets the ReaClassical project-level nudge amount (in
    -- milliseconds) used by the Nudge Marker Left/Right reascripts; nudge?
    -- reports the current value. REAPER's own item-nudge amount/unit isn't
    -- exposed to ReaScript, so this is tracked independently per project.
    local nudge_ms = cmd:match("^nudge=([%d%.]+)$")
    if nudge_ms then
        local ms = tonumber(nudge_ms)
        if not ms or ms <= 0 then
            say("nudge= requires a positive number of milliseconds")
            return true
        end
        SetProjExtState(0, "ReaClassical", "NudgeMs", tostring(ms))
        say("Nudge amount set to " .. ms .. " milliseconds")
        return true
    end

    if cmd == "nudge?" then
        local _, stored = GetProjExtState(0, "ReaClassical", "NudgeMs")
        local ms = tonumber(stored) or 5
        say("Nudge amount: " .. ms .. " milliseconds")
        return true
    end

    if cmd == "update" then
        local action = NamedCommandLookup("_REAPACK_SYNC")
        if action ~= 0 then
            Main_OnCommand(action, 0)
        else
            say("ReaPack is not installed")
        end
        return true
    end

    -- import or import=dest: scan the project's media folder for new audio
    -- files and import them (Smart Import), via the headless hook in
    -- ReaClassical_Smart Import Audio.lua. "dest" also duplicates each
    -- session's takes onto the destination folder.
    if cmd == "import" or cmd == "import=dest" then
        _G.RC_TERMINAL_ARGS = { include_destination = (cmd == "import=dest") }
        dofile(script_path .. "ReaClassical_Smart Import Audio.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- import=smart,1[,dest]   -> one folder per take (same as plain "import")
    -- import=smart,2[,dest]   -> round-robin across the current number of source folders
    -- import=smart,3,N[,dest] -> round-robin across N folders (created if needed)
    -- Optional trailing ",dest" includes the destination folder (D:) in the
    -- distribution, matching the GUI's "Include destination folder" checkbox.
    local smart_mode, smart_rest = cmd:match("^import=smart,([123])(.*)$")
    if smart_mode then
        smart_mode = tonumber(smart_mode)
        local args = {}
        local dest

        if smart_mode == 3 then
            local folder_count
            folder_count, dest = smart_rest:match("^,(%d+),(dest)$")
            if not folder_count then
                folder_count = smart_rest:match("^,(%d+)$")
            end
            if not folder_count then
                say("import=smart,3 requires a folder count, e.g. import=smart,3,5")
                return true
            end
            args.robin_folder_count = tonumber(folder_count)
        else
            dest = smart_rest:match("^,(dest)$")
            if smart_rest ~= "" and not dest then
                say("Unknown command: " .. cmd)
                return true
            end
            if smart_mode == 2 then
                args.robin_folder_count = "current"
            end
        end

        args.include_destination = (dest == "dest")
        _G.RC_TERMINAL_ARGS = args
        dofile(script_path .. "ReaClassical_Smart Import Audio.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- import=N or import=N,session       -> import only take N (optionally
    --   restricted to a session, default "default"), placed at the edit cursor
    -- import=N-M or import=N-M,session   -> import takes N..M, same restrictions
    local take_a, take_b, take_session = cmd:match("^import=(%d+)-(%d+),(.+)$")
    if not take_a then
        take_a, take_b = cmd:match("^import=(%d+)-(%d+)$")
    end
    if not take_a then
        local take_n, session = cmd:match("^import=(%d+),(.+)$")
        if take_n then
            take_a, take_b, take_session = take_n, take_n, session
        end
    end
    if not take_a then
        local take_n = cmd:match("^import=(%d+)$")
        if take_n then
            take_a, take_b = take_n, take_n
        end
    end
    if take_a then
        _G.RC_TERMINAL_ARGS = {
            include_destination = false,
            at_cursor = true,
            filter = {
                take_min = tonumber(take_a),
                take_max = tonumber(take_b),
                session = take_session and trim(take_session) or "default",
            },
        }
        dofile(script_path .. "ReaClassical_Smart Import Audio.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- repos=N: reposition CD track groups on the selected folder track,
    -- leaving N seconds between each group, via the headless hook in
    -- ReaClassical_Reposition_Album_Tracks.lua.
    local repos_arg = cmd:match("^repos=(.+)$")
    if repos_arg then
        local gap = tonumber(repos_arg)
        if not gap then
            say("Please enter a number")
            return true
        end
        _G.RC_TERMINAL_ARGS = { gap = gap }
        dofile(script_path .. "ReaClassical_Reposition_Album_Tracks.lua")
        -- Reposition skips createcd in terminal mode; sync markers now.
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Create CD Markers.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- find=N or find=N,session or find=,session: locate a take by number
    -- and/or session name, via the headless hook in ReaClassical_Find Take.lua.
    local find_args = cmd:match("^find=(.*)$")
    if find_args then
        local take_str, session_name = find_args:match("^([^,]*),(.*)$")
        if not take_str then
            take_str = find_args
            session_name = ""
        end
        local take_choice = tonumber(take_str)
        if not take_choice and session_name ~= "" then take_choice = 1 end
        _G.RC_TERMINAL_ARGS = { take_choice = take_choice, session_name = trim(session_name) }
        dofile(script_path .. "ReaClassical_Find Take.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- buildlist=source or buildlist=bwf: build an HTML edit list using either
    -- source-file timing or BWF start-offset timing.
    local buildlist_type = cmd:match("^buildlist=(.+)$")
    if buildlist_type then
        if buildlist_type == "source" then
            dofile(script_path .. "ReaClassical_Build Edit List.lua")
            say("Edit list built")
        elseif buildlist_type == "bwf" then
            _G.RC_TERMINAL_ARGS = { offset = 0 }
            dofile(script_path .. "ReaClassical_Build Edit List using BWF offset.lua")
            _G.RC_TERMINAL_ARGS = nil
            say("Edit list built")
        else
            say("Unknown buildlist type: " .. buildlist_type)
        end
        return true
    end

    -- createcd: create CD/DDP markers for the selected folder track, via the
    -- headless hook in ReaClassical_Create CD Markers.lua, without opening
    -- the DDP Metadata Editor.
    if cmd == "createcd" then
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Create CD Markers.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- peak?: scan all unmuted tracks and jump the edit cursor to the peak position.
    if cmd == "peak?" then
        _G.RC_TERMINAL_ARGS = { jump_to_peak = true }
        dofile(script_path .. "ReaClassical_Peak and Overs Check.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- overs?: scan all unmuted tracks for the peak level and any overs above
    -- the saved threshold, via the headless hook in
    -- ReaClassical_Peak and Overs Check.lua.
    if cmd == "overs?" then
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Peak and Overs Check.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- overs=N: same as overs?, but using N dB as the over threshold for this
    -- scan (also saved as the new default threshold).
    local overs_threshold = cmd:match("^overs=([%-%d%.]+)$")
    if overs_threshold then
        local threshold = tonumber(overs_threshold)
        if not threshold then
            say("Please enter a number")
            return true
        end
        _G.RC_TERMINAL_ARGS = { threshold = threshold }
        dofile(script_path .. "ReaClassical_Peak and Overs Check.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- digital=y|1 or digital=n|0: toggle Digital Release Only mode (no pregap
    -- or frame-snapping offsets; used for streaming-only deliverables).
    -- digital?: query the current setting.
    local dr_val = cmd:match("^digital=([yn10])$")
    if dr_val then
        local on = (dr_val == "y" or dr_val == "1")
        SetProjExtState(0, "ReaClassical", "digital_release_only", on and "1" or "0")
        say("Digital release only: " .. (on and "on" or "off"))
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Create CD Markers.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    if cmd == "digital?" then
        local _, val = GetProjExtState(0, "ReaClassical", "digital_release_only")
        say("Digital release only: " .. (val == "1" and "on" or "off"))
        return true
    end

    -- isrc=y|1 or isrc=n|0: toggle Manual ISRC Entry mode. When on, all ISRC
    -- codes are entered independently per track; when off, they auto-increment
    -- from the first track's ISRC.
    -- isrc?: query the current setting.
    local isrc_val = cmd:match("^isrc=([yn10])$")
    if isrc_val then
        local on = (isrc_val == "y" or isrc_val == "1")
        SetProjExtState(0, "ReaClassical", "manual_isrc_entry", on and "1" or "0")
        say("Manual ISRC entry: " .. (on and "on" or "off"))
        return true
    end

    if cmd == "isrc?" then
        local _, val = GetProjExtState(0, "ReaClassical", "manual_isrc_entry")
        say("Manual ISRC entry: " .. (val == "1" and "on" or "off"))
        return true
    end

    -- addoffsets: record the current CD marker positions as per-item OFFSET
    -- fields, so subsequent createcd runs preserve the manual positions.
    if cmd == "addoffsets" then
        dofile(script_path .. "ReaClassical_Add CD Marker Offsets.lua")
        say("Marker offsets updated")
        return true
    end

    -- rmoffsets: strip all OFFSET fields from the selected folder track's
    -- items, reverting to automatic marker placement on the next createcd run.
    if cmd == "rmoffsets" then
        dofile(script_path .. "ReaClassical_Remove All CD Marker Offsets.lua")
        say("Marker offsets removed")
        return true
    end

    -- offsets?: report whether any marker offsets are active on the selected track.
    if cmd == "offsets?" then
        local track = GetSelectedTrack(0, 0)
        if not track then
            say("No track selected"); return true
        end
        local has_offsets = false
        for i = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, i)
            local take = GetActiveTake(item)
            if take then
                local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                if name and name:match("|OFFSET=") then
                    has_offsets = true
                    break
                end
            end
        end
        say("Marker offsets: " .. (has_offsets and "active" or "none"))
        return true
    end

    -- tu / td: move the selected album track item one position up or down in
    -- the timeline, then re-sync CD markers headlessly.
    if cmd == "tu" or cmd == "td" then
        local id_str = cmd == "tu"
            and "_RS18fe066cb8806e30b0371fc30a79c67ce2b807f1"
            or "_RS6d1212ff49d4205e6f7f0d7c30ae539d3da05f6f"
        local named_cmd_id = NamedCommandLookup(id_str)
        if named_cmd_id == 0 then
            say("Move Album Track " .. (cmd == "tu" and "Up" or "Down") .. " script not installed")
            return true
        end
        -- Suppress any GUI that the named command might trigger via createcd.
        SetProjExtState(0, "ReaClassical", "ddp_silent", "y")
        Main_OnCommand(named_cmd_id, 0)
        SetProjExtState(0, "ReaClassical", "ddp_silent", "")
        -- Re-sync markers headlessly in case the named command skipped createcd.
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Create CD Markers.lua")
        _G.RC_TERMINAL_ARGS = nil
        say("Album track moved " .. (cmd == "tu" and "up" or "down"))
        return true
    end

    -- render=ddp|cue|wav|flac|opus|mp3|custom: run createcd headlessly then apply
    -- the chosen render preset. "custom" opens the REAPER render dialog instead.
    -- Plain "render" is an alias for "render=custom".
    local render_fmt = cmd:match("^render=(.+)$") or (cmd == "render" and "custom")
    if render_fmt then
        local valid = { ddp = true, cue = true, wav = true, flac = true, opus = true, mp3 = true, custom = true }
        if not valid[render_fmt] then
            say("Unknown format: " .. render_fmt .. " (use ddp, cue, wav, flac, opus, mp3, custom)")
            return true
        end
        _G.RC_TERMINAL_ARGS = { action = "render", format = render_fmt }
        dofile(script_path .. "ReaClassical_Create CD Markers.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    return false
end

---------------------------------------------------------------------
-- Mixer Snapshot helpers (headless; no ImGui required)
-- Data format is identical to ReaClassical_Mixer Snapshots.lua so
-- the two scripts share the same project-state storage.
---------------------------------------------------------------------

function snap_serialize_table(tbl, indent)
    indent = indent or 0
    local result = {}
    local prefix = string.rep("  ", indent)
    table.insert(result, "{\n")
    for k, v in pairs(tbl) do
        local key_str = type(k) == "number" and ("[" .. k .. "]") or ('["' .. tostring(k) .. '"]')
        if type(v) == "table" then
            table.insert(result, prefix .. "  " .. key_str .. " = " ..
                snap_serialize_table(v, indent + 1) .. ",\n")
        elseif type(v) == "string" then
            table.insert(result, prefix .. "  " .. key_str ..
                ' = "' .. v:gsub('"', '\\"') .. '",\n')
        elseif type(v) == "number" or type(v) == "boolean" then
            table.insert(result, prefix .. "  " .. key_str .. " = " .. tostring(v) .. ",\n")
        end
    end
    table.insert(result, prefix .. "}")
    return table.concat(result)
end

function snap_deserialize_table(str)
    if not str or str == "" then return nil end
    local func = load("return " .. str)
    return func and func() or nil
end

function snap_is_special_track(track)
    local _, mixer = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
    local _, aux   = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
    local _, sub   = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
    return mixer == "y" or aux == "y" or sub == "y"
end

function snap_find_track_by_guid(guid)
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        if GetTrackGUID(t) == guid then return t end
    end
    return nil
end

function snap_get_item_by_guid(guid)
    for i = 0, CountMediaItems(0) - 1 do
        local item = GetMediaItem(0, i)
        if BR_GetMediaItemGUID(item) == guid then return item end
    end
    return nil
end

function snap_get_track_state(track)
    local s    = {}
    s.volume   = GetMediaTrackInfo_Value(track, "D_VOL")
    s.pan      = GetMediaTrackInfo_Value(track, "D_PAN")
    s.mute     = GetMediaTrackInfo_Value(track, "B_MUTE")
    s.solo     = GetMediaTrackInfo_Value(track, "I_SOLO")
    s.phase    = GetMediaTrackInfo_Value(track, "B_PHASE")
    s.width    = GetMediaTrackInfo_Value(track, "D_WIDTH")
    s.guid     = GetTrackGUID(track)
    s.fx_chain = {}
    for i = 0, TrackFX_GetCount(track) - 1 do
        local fx = {
            enabled = TrackFX_GetEnabled(track, i),
            name    = select(2, TrackFX_GetFXName(track, i, "")),
            params  = {}
        }
        for p = 0, TrackFX_GetNumParams(track, i) - 1 do
            fx.params[p] = TrackFX_GetParam(track, i, p)
        end
        s.fx_chain[i] = fx
    end
    s.sends = {}
    for i = 0, GetTrackNumSends(track, 0) - 1 do
        s.sends[i] = {
            volume    = GetTrackSendInfo_Value(track, 0, i, "D_VOL"),
            pan       = GetTrackSendInfo_Value(track, 0, i, "D_PAN"),
            mute      = GetTrackSendInfo_Value(track, 0, i, "B_MUTE"),
            dest_guid = GetTrackGUID(BR_GetMediaTrackSendInfo_Track(track, 0, i, 1)),
        }
    end
    s.hw_outs = {}
    for i = 0, GetTrackNumSends(track, 1) - 1 do
        s.hw_outs[i] = {
            volume  = GetTrackSendInfo_Value(track, 1, i, "D_VOL"),
            pan     = GetTrackSendInfo_Value(track, 1, i, "D_PAN"),
            mute    = GetTrackSendInfo_Value(track, 1, i, "B_MUTE"),
            channel = GetTrackSendInfo_Value(track, 1, i, "I_DSTCHAN"),
        }
    end
    return s
end

function snap_apply_track_state(track, state, flags)
    if not track then return end
    if flags.volume then SetMediaTrackInfo_Value(track, "D_VOL", state.volume) end
    if flags.pan then SetMediaTrackInfo_Value(track, "D_PAN", state.pan) end
    if flags.mute then SetMediaTrackInfo_Value(track, "B_MUTE", state.mute) end
    if flags.solo then SetMediaTrackInfo_Value(track, "I_SOLO", state.solo) end
    if flags.phase then SetMediaTrackInfo_Value(track, "B_PHASE", state.phase) end
    if flags.width and state.width then
        SetMediaTrackInfo_Value(track, "D_WIDTH", state.width)
    end
    if flags.fx then
        for fx_idx, fx in pairs(state.fx_chain) do
            if TrackFX_GetCount(track) > fx_idx then
                TrackFX_SetEnabled(track, fx_idx, fx.enabled)
                for p, v in pairs(fx.params) do
                    TrackFX_SetParam(track, fx_idx, p, v)
                end
            end
        end
    end
    if flags.sends then
        for i, send in pairs(state.sends) do
            if GetTrackNumSends(track, 0) > i then
                SetTrackSendInfo_Value(track, 0, i, "D_VOL", send.volume)
                SetTrackSendInfo_Value(track, 0, i, "D_PAN", send.pan)
                SetTrackSendInfo_Value(track, 0, i, "B_MUTE", send.mute)
            end
        end
    end
    if flags.routing and state.sends then
        local n = GetTrackNumSends(track, 0)
        for i = n - 1, 0, -1 do RemoveTrackSend(track, 0, i) end
        local rcmaster_guid = nil
        for i = 0, CountTracks(0) - 1 do
            local tr = GetTrack(0, i)
            local _, rcs = GetSetMediaTrackInfo_String(tr, "P_EXT:rcmaster", "", false)
            if rcs == "y" then
                rcmaster_guid = GetTrackGUID(tr); break
            end
        end
        local has_rcm = false
        for _, send in pairs(state.sends) do
            local dst = snap_find_track_by_guid(send.dest_guid)
            if dst then
                local idx = CreateTrackSend(track, dst)
                if idx >= 0 then
                    SetTrackSendInfo_Value(track, 0, idx, "D_VOL", send.volume)
                    SetTrackSendInfo_Value(track, 0, idx, "D_PAN", send.pan)
                    SetTrackSendInfo_Value(track, 0, idx, "B_MUTE", send.mute)
                    if rcmaster_guid and send.dest_guid == rcmaster_guid then
                        has_rcm = true
                    end
                end
            end
        end
        if snap_is_special_track(track) then
            GetSetMediaTrackInfo_String(track, "P_EXT:rcm_disconnect",
                has_rcm and "" or "y", true)
        end
        if state.hw_outs then
            local hw_n = GetTrackNumSends(track, 1)
            for i = 0, math.min(hw_n - 1, #state.hw_outs) do
                if state.hw_outs[i] then
                    SetTrackSendInfo_Value(track, 1, i, "D_VOL", state.hw_outs[i].volume)
                    SetTrackSendInfo_Value(track, 1, i, "D_PAN", state.hw_outs[i].pan)
                    SetTrackSendInfo_Value(track, 1, i, "D_MUTE", state.hw_outs[i].mute)
                end
            end
        end
    end
end

function snap_recall_snapshot(snapshot, flags)
    if not snapshot then return end
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if snap_is_special_track(track) and snapshot.tracks[i] then
            snap_apply_track_state(track, snapshot.tracks[i], flags)
        end
    end
    UpdateArrange()
    TrackList_AdjustWindows(false)
end

function snap_find_by_item_guid(snaps, guid)
    for _, s in ipairs(snaps) do
        if s.item_guid == guid then return s end
    end
    return nil
end

function snap_get_item_position(guid)
    local item = snap_get_item_by_guid(guid)
    if item then return GetMediaItemInfo_Value(item, "D_POSITION") end
    return math.huge
end

function snap_find_at_cursor(snaps, cursor_pos)
    for _, s in ipairs(snaps) do
        local item = snap_get_item_by_guid(s.item_guid)
        if item then
            local item_start = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end   = item_start + GetMediaItemInfo_Value(item, "D_LENGTH")
            if cursor_pos >= item_start and cursor_pos < item_end then
                return s
            end
        end
    end
    local prev_snap, prev_pos = nil, -1
    for _, s in ipairs(snaps) do
        local item = snap_get_item_by_guid(s.item_guid)
        if item then
            local p = GetMediaItemInfo_Value(item, "D_POSITION")
            if p < cursor_pos and p > prev_pos then
                prev_pos = p
                prev_snap = s
            end
        end
    end
    return prev_snap
end

function snap_load_bank(bank)
    local retval, str = GetProjExtState(0, "MixerSnapshots", "data_" .. bank)
    if retval > 0 and str ~= "" then
        local data = snap_deserialize_table(str)
        if data then
            return data.snapshots or {}, {
                volume                = data.recall_volume ~= false,
                pan                   = data.recall_pan ~= false,
                mute                  = data.recall_mute ~= false,
                solo                  = data.recall_solo ~= false,
                phase                 = data.recall_phase ~= false,
                width                 = data.recall_width ~= false,
                fx                    = data.recall_fx ~= false,
                sends                 = data.recall_sends ~= false,
                routing               = data.recall_routing ~= false,
                disable_auto_recall   = data.disable_auto_recall or false,
                switch_mid_gap        = data.switch_mid_gap ~= false,
                counter               = data.counter or 0,
                bank_folder_selection = data.bank_folder_selection or "all",
            }
        end
    end
    return {}, {
        volume = true,
        pan = true,
        mute = true,
        solo = true,
        phase = true,
        width = true,
        fx = true,
        sends = true,
        routing = true,
        disable_auto_recall = false,
        switch_mid_gap = true,
        counter = 0,
        bank_folder_selection = "all",
    }
end

function snap_save_bank(bank, snaps, flags)
    local data = {
        counter               = flags.counter or 0,
        snapshots             = snaps,
        disable_auto_recall   = flags.disable_auto_recall or false,
        switch_mid_gap        = flags.switch_mid_gap ~= false,
        bank_folder_selection = flags.bank_folder_selection or "all",
        recall_volume         = flags.volume ~= false,
        recall_pan            = flags.pan ~= false,
        recall_mute           = flags.mute ~= false,
        recall_solo           = flags.solo ~= false,
        recall_phase          = flags.phase ~= false,
        recall_width          = flags.width ~= false,
        recall_fx             = flags.fx ~= false,
        recall_sends          = flags.sends ~= false,
        recall_routing        = flags.routing ~= false,
    }
    SetProjExtState(0, "MixerSnapshots", "data_" .. bank, snap_serialize_table(data))
end

function snap_get_current_bank()
    local _, bank = GetProjExtState(0, "MixerSnapshots", "current_bank")
    if bank == "" then bank = "A" end
    return bank
end

function snap_set_current_bank(bank)
    SetProjExtState(0, "MixerSnapshots", "current_bank", bank)
end

function snap_sort_by_timeline(snaps)
    table.sort(snaps, function(a, b)
        return snap_get_item_position(a.item_guid) < snap_get_item_position(b.item_guid)
    end)
end

-- Port of convert_snapshots_to_automation() from Mixer Snapshots.lua.
-- All logic is pure REAPER API; no ImGui dependency.
function snap_convert_to_automation(snaps, flags)
    if #snaps == 0 then
        say("No snapshots to convert")
        return
    end

    Undo_BeginBlock()

    -- Clear existing automation from special tracks
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if snap_is_special_track(track) then
            for e = 0, CountTrackEnvelopes(track) - 1 do
                local env = GetTrackEnvelope(track, e)
                DeleteEnvelopePointRange(env, -1000000, 1000000)
                GetSetEnvelopeInfo_String(env, "VISIBLE", "0", true)
                GetSetEnvelopeInfo_String(env, "ACTIVE", "0", true)
                GetSetEnvelopeInfo_String(env, "ARM", "0", true)
            end
        end
    end

    -- Sort snapshots by timeline position
    local sorted = {}
    for i, snap in ipairs(snaps) do
        local item = snap_get_item_by_guid(snap.item_guid)
        if item then
            table.insert(sorted, {
                snap = snap,
                pos  = GetMediaItemInfo_Value(item, "D_POSITION"),
                idx  = i,
            })
        end
    end
    table.sort(sorted, function(a, b) return a.pos < b.pos end)

    -- Collect parameter values at each snapshot position, keyed by track GUID
    local param_changes = {}
    for _, sd in ipairs(sorted) do
        local item = snap_get_item_by_guid(sd.snap.item_guid)
        if item then
            local snap_pos = GetMediaItemInfo_Value(item, "D_POSITION")
            for _, ts in pairs(sd.snap.tracks) do
                local tg = ts.guid
                if not param_changes[tg] then
                    param_changes[tg] = {
                        volume = {},
                        pan = {},
                        mute = {},
                        solo = {},
                        phase = {},
                        width = {},
                        fx = {},
                        sends = {},
                    }
                end
                local pc = param_changes[tg]
                table.insert(pc.volume, { pos = snap_pos, value = ts.volume, snap_idx = sd.idx })
                table.insert(pc.pan, { pos = snap_pos, value = ts.pan, snap_idx = sd.idx })
                table.insert(pc.mute, { pos = snap_pos, value = ts.mute, snap_idx = sd.idx })
                table.insert(pc.solo, { pos = snap_pos, value = ts.solo, snap_idx = sd.idx })
                table.insert(pc.phase, { pos = snap_pos, value = ts.phase, snap_idx = sd.idx })
                if ts.width then
                    table.insert(pc.width, { pos = snap_pos, value = ts.width, snap_idx = sd.idx })
                end
                for fx_idx, fx in pairs(ts.fx_chain) do
                    if not pc.fx[fx_idx] then pc.fx[fx_idx] = {} end
                    for param_idx, val in pairs(fx.params) do
                        if not pc.fx[fx_idx][param_idx] then
                            pc.fx[fx_idx][param_idx] = {}
                        end
                        table.insert(pc.fx[fx_idx][param_idx],
                            { pos = snap_pos, value = val, snap_idx = sd.idx })
                    end
                end
                for si, send in pairs(ts.sends) do
                    if not pc.sends[si] then
                        pc.sends[si] = { volume = {}, pan = {}, mute = {} }
                    end
                    table.insert(pc.sends[si].volume,
                        { pos = snap_pos, value = send.volume, snap_idx = sd.idx })
                    table.insert(pc.sends[si].pan,
                        { pos = snap_pos, value = send.pan, snap_idx = sd.idx })
                    table.insert(pc.sends[si].mute,
                        { pos = snap_pos, value = send.mute, snap_idx = sd.idx })
                end
            end
        end
    end

    local auto_count    = 0
    local tracks_w_auto = {}

    local function has_changes(points)
        if #points < 2 then return false end
        local first = points[1].value
        for i = 2, #points do
            if math.abs(points[i].value - first) > 0.0001 then return true end
        end
        return false
    end

    local function get_or_create_envelope(track, param_name)
        local env = GetTrackEnvelopeByName(track, param_name)
        if env then
            GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
            GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
            GetSetEnvelopeInfo_String(env, "ARM", "1", true)
            return env
        end
        local num_sel, saved = CountSelectedTracks(0), {}
        for i = 0, num_sel - 1 do saved[i] = GetSelectedTrack(0, i) end
        Main_OnCommand(40297, 0)
        SetTrackSelected(track, true)
        local action_ids = { Volume = 40406, Pan = 40407, Mute = 40867, Width = 41870 }
        local action = action_ids[param_name]
        if action then
            local had = false
            for e = 0, CountTrackEnvelopes(track) - 1 do
                local _, nm = GetEnvelopeName(GetTrackEnvelope(track, e), "")
                if nm == param_name then
                    had = true; break
                end
            end
            if not had then Main_OnCommand(action, 0) end
        end
        Main_OnCommand(40297, 0)
        for i = 0, num_sel - 1 do SetTrackSelected(saved[i], true) end
        env = GetTrackEnvelopeByName(track, param_name)
        if env then
            GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
            GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
            GetSetEnvelopeInfo_String(env, "ARM", "1", true)
        end
        return env
    end

    -- Inserts stepped automation points with optional gap-midpoint switching
    -- and a 35 ms ramp before each value change (mirrors GUI behaviour).
    -- Also resets all changing parameters to neutral on the first call
    -- (idempotent — safe to call once per envelope per conversion run).
    local function insert_automation_points(env, points, needs_scaling)
        local to_write, prev = {}, nil
        for _, pt in ipairs(points) do
            if not prev or math.abs(pt.value - prev) > 0.0001 then
                table.insert(to_write, pt); prev = pt.value
            end
        end
        if #to_write == 0 then return end

        -- Reset all parameters that will receive automation to neutral
        for tg, pc in pairs(param_changes) do
            local tr = snap_find_track_by_guid(tg)
            if tr then
                if has_changes(pc.volume) then SetMediaTrackInfo_Value(tr, "D_VOL", 1.0) end
                if has_changes(pc.pan) then SetMediaTrackInfo_Value(tr, "D_PAN", 0.0) end
                if has_changes(pc.mute) then SetMediaTrackInfo_Value(tr, "B_MUTE", 0) end
                if has_changes(pc.phase) then SetMediaTrackInfo_Value(tr, "B_PHASE", 0) end
                if has_changes(pc.width) then SetMediaTrackInfo_Value(tr, "D_WIDTH", 1.0) end
                for si, sp in pairs(pc.sends) do
                    if has_changes(sp.volume) then
                        SetTrackSendInfo_Value(tr, 0, si, "D_VOL", 1.0)
                    end
                    if has_changes(sp.pan) then
                        SetTrackSendInfo_Value(tr, 0, si, "D_PAN", 0.0)
                    end
                    if has_changes(sp.mute) then
                        SetTrackSendInfo_Value(tr, 0, si, "B_MUTE", 0)
                    end
                end
            end
        end

        local auto_points = {}
        table.insert(auto_points, { pos = 0, value = to_write[1].value })

        local folder_sel = flags.bank_folder_selection or "all"

        for i = 1, #to_write do
            local pt        = to_write[i]
            local snap      = snaps[pt.snap_idx]
            local snap_item = snap and snap_get_item_by_guid(snap.item_guid)
            if not snap_item then goto continue_pt end

            local snap_start  = GetMediaItemInfo_Value(snap_item, "D_POSITION")
            local snap_folder = GetMediaItem_Track(snap_item)
            local target_pos  = snap_start

            if i > 1 and flags.switch_mid_gap then
                local prev_pt   = to_write[i - 1]
                local prev_snap = snaps[prev_pt.snap_idx]
                local prev_item = prev_snap and snap_get_item_by_guid(prev_snap.item_guid)
                if prev_item then
                    local prev_folder = GetMediaItem_Track(prev_item)
                    local should_check = (folder_sel == "all")
                    if not should_check then
                        local _, pg = GetSetMediaTrackInfo_String(prev_folder, "GUID", "", false)
                        local _, sg = GetSetMediaTrackInfo_String(snap_folder, "GUID", "", false)
                        if pg == folder_sel or sg == folder_sel then should_check = true end
                    end
                    if should_check then
                        local snap_guid   = BR_GetMediaItemGUID(snap_item)
                        local latest_end  = -1
                        local has_overlap = false
                        for k = 0, CountMediaItems(0) - 1 do
                            local it = GetMediaItem(0, k)
                            if BR_GetMediaItemGUID(it) ~= snap_guid then
                                local check_it = (folder_sel == "all")
                                if not check_it then
                                    local it_tr = GetMediaItem_Track(it)
                                    local _, itg = GetSetMediaTrackInfo_String(it_tr, "GUID", "", false)
                                    check_it = (itg == folder_sel)
                                end
                                if check_it then
                                    local it_s = GetMediaItemInfo_Value(it, "D_POSITION")
                                    local it_e = it_s + GetMediaItemInfo_Value(it, "D_LENGTH")
                                    if it_s < snap_start and it_e > snap_start then
                                        has_overlap = true; break
                                    end
                                    if it_e < snap_start and it_e > latest_end then
                                        latest_end = it_e
                                    end
                                end
                            end
                        end
                        if not has_overlap and latest_end >= 0 then
                            local gap = snap_start - latest_end
                            if gap > 0.001 then
                                target_pos = latest_end + gap / 2
                            end
                        end
                    end
                end
            end

            if i > 1 then
                table.insert(auto_points, { pos = target_pos - 0.035, value = to_write[i - 1].value })
            end
            table.insert(auto_points, { pos = target_pos, value = pt.value })

            ::continue_pt::
        end

        for _, ap in ipairs(auto_points) do
            local v = needs_scaling and ScaleToEnvelopeMode(1, ap.value) or ap.value
            InsertEnvelopePoint(env, ap.pos, v, 0, 0, false, true)
        end
    end

    -- Write automation lanes for every track whose parameters actually change
    for tg, pc in pairs(param_changes) do
        local track = snap_find_track_by_guid(tg)
        if track then
            local got_auto = false
            SetMediaTrackInfo_Value(track, "I_AUTOMODE", 1) -- read mode

            if has_changes(pc.volume) then
                local env = get_or_create_envelope(track, "Volume")
                if env then
                    insert_automation_points(env, pc.volume, true)
                    Envelope_SortPoints(env)
                    auto_count = auto_count + 1; got_auto = true
                end
            end
            if has_changes(pc.pan) then
                local inv = {}
                for _, pt in ipairs(pc.pan) do
                    table.insert(inv, { pos = pt.pos, value = -pt.value, snap_idx = pt.snap_idx })
                end
                local env = get_or_create_envelope(track, "Pan")
                if env then
                    insert_automation_points(env, inv, false)
                    Envelope_SortPoints(env)
                    auto_count = auto_count + 1; got_auto = true
                end
            end
            if has_changes(pc.mute) then
                local inv = {}
                for _, pt in ipairs(pc.mute) do
                    table.insert(inv, {
                        pos = pt.pos,
                        value = pt.value == 1 and 0 or 1,
                        snap_idx = pt.snap_idx
                    })
                end
                local env = get_or_create_envelope(track, "Mute")
                if env then
                    insert_automation_points(env, inv, false)
                    Envelope_SortPoints(env)
                    auto_count = auto_count + 1; got_auto = true
                end
            end
            if has_changes(pc.solo) then
                local env = GetTrackEnvelopeByName(track, "Solo")
                if env then
                    insert_automation_points(env, pc.solo, false)
                    Envelope_SortPoints(env)
                    auto_count = auto_count + 1; got_auto = true
                end
            end
            if has_changes(pc.phase) then
                local env = GetTrackEnvelopeByName(track, "Phase")
                    or GetTrackEnvelopeByName(track, "Polarity")
                if env then
                    insert_automation_points(env, pc.phase, false)
                    Envelope_SortPoints(env)
                    auto_count = auto_count + 1; got_auto = true
                end
            end
            if has_changes(pc.width) then
                local env = get_or_create_envelope(track, "Width")
                if env then
                    insert_automation_points(env, pc.width, false)
                    Envelope_SortPoints(env)
                    auto_count = auto_count + 1; got_auto = true
                end
            end
            for fx_idx, fx_params in pairs(pc.fx) do
                for param_idx, pts in pairs(fx_params) do
                    if has_changes(pts) then
                        local env = GetFXEnvelope(track, fx_idx, param_idx, true)
                        if env then
                            insert_automation_points(env, pts, false)
                            Envelope_SortPoints(env)
                            GetSetEnvelopeInfo_String(env, "VISIBLE", "1", true)
                            GetSetEnvelopeInfo_String(env, "ACTIVE", "1", true)
                            GetSetEnvelopeInfo_String(env, "ARM", "1", true)
                            auto_count = auto_count + 1; got_auto = true
                        end
                    end
                end
            end
            for si, sp in pairs(pc.sends) do
                if has_changes(sp.volume) or has_changes(sp.pan) or has_changes(sp.mute) then
                    local num_sel, saved = CountSelectedTracks(0), {}
                    for k = 0, num_sel - 1 do saved[k] = GetSelectedTrack(0, k) end
                    Main_OnCommand(40297, 0)
                    SetTrackSelected(track, true)
                    Main_OnCommand(41327, 0) -- Track: Toggle send envelopes visible
                    Main_OnCommand(40297, 0)
                    for k = 0, num_sel - 1 do SetTrackSelected(saved[k], true) end

                    if has_changes(sp.volume) then
                        local env = BR_GetMediaTrackSendInfo_Envelope(track, 0, si, 0)
                        if env then
                            insert_automation_points(env, sp.volume, true)
                            Envelope_SortPoints(env)
                            auto_count = auto_count + 1; got_auto = true
                        end
                    end
                    if has_changes(sp.pan) then
                        local env = BR_GetMediaTrackSendInfo_Envelope(track, 0, si, 1)
                        if env then
                            insert_automation_points(env, sp.pan, false)
                            Envelope_SortPoints(env)
                            auto_count = auto_count + 1; got_auto = true
                        end
                    end
                    if has_changes(sp.mute) then
                        local inv = {}
                        for _, pt in ipairs(sp.mute) do
                            table.insert(inv, {
                                pos = pt.pos,
                                value = pt.value == 1 and 0 or 1,
                                snap_idx = pt.snap_idx
                            })
                        end
                        local env = BR_GetMediaTrackSendInfo_Envelope(track, 0, si, 2)
                        if env then
                            insert_automation_points(env, inv, false)
                            Envelope_SortPoints(env)
                            auto_count = auto_count + 1; got_auto = true
                        end
                    end
                end
            end

            if got_auto then tracks_w_auto[track] = true end
        end
    end

    -- Show in TCP any tracks that received automation
    for track in pairs(tracks_w_auto) do
        if GetMediaTrackInfo_Value(track, "B_SHOWINTCP") == 0 then
            SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 1)
            local _, guid  = GetSetMediaTrackInfo_String(track, "GUID", "", false)
            local _, mixer = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
            local key      = (mixer == "y") and ("mixer_tcp_visible_" .. guid)
                or ("tcp_visible_" .. guid)
            SetProjExtState(0, "ReaClassical_MissionControl", key, "1")
        end
    end

    UpdateArrange()
    TrackList_AdjustWindows(false)
    Undo_EndBlock("Convert Mixer Snapshots to Automation", -1)
    say(auto_count .. " automation lane" .. (auto_count ~= 1 and "s" or "") ..
        " created from " .. #snaps .. " snapshot" .. (#snaps ~= 1 and "s" or ""))
end

---------------------------------------------------------------------

local function snap_daemon_cmd()
    if not APIExists("AddRemoveReaScript") then return 0 end
    local path = script_path .. "ReaClassical_Mixer Snapshots Daemon.lua"
    return AddRemoveReaScript(true, 0, path, true)
end

local function snap_daemon_running()
    local _, ts = GetProjExtState(0, "MixerSnapshots", "daemon_heartbeat")
    return (os.time() - (tonumber(ts) or 0)) < 5
end

---------------------------------------------------------------------

function try_snapshots(cmd)
    -- snap? — list all snapshots in current bank (timeline order)
    if cmd == "snap?" then
        local bank = snap_get_current_bank()
        local snaps = snap_load_bank(bank)
        if #snaps == 0 then
            say("No snapshots in bank " .. bank)
            return true
        end
        snap_sort_by_timeline(snaps)
        say("Bank " .. bank .. " (" .. #snaps .. " snapshot" .. (#snaps ~= 1 and "s" or "") .. "):")
        for i, s in ipairs(snaps) do
            local item = snap_get_item_by_guid(s.item_guid)
            local pos_str = item and format_timestr_pos(GetMediaItemInfo_Value(item, "D_POSITION"), "", -1) or "?"
            local name = s.item_name ~= "" and humanize_item_name(s.item_name) or s.item_guid:sub(1, 13) .. "..."
            local pipe = name:find("|")
            if pipe then name = name:sub(1, pipe - 1) end
            say(string.format("  %d: %s @ %s  [%s %s]", i, name, pos_str,
                s.date or "", s.time or ""))
        end
        return true
    end

    -- snap.bank? — query active bank
    if cmd == "snap.bank?" then
        say("Snapshot bank: " .. snap_get_current_bank())
        return true
    end

    -- snap.bank=X — switch active bank
    local new_bank = cmd:match("^snap%.bank=([ABCD])$")
    if new_bank then
        snap_set_current_bank(new_bank)
        say("Snapshot bank: " .. new_bank)
        return true
    end

    -- snap.ar? — query auto-recall state for current bank
    if cmd == "snap.ar?" then
        local bank = snap_get_current_bank()
        local _, flags = snap_load_bank(bank)
        say("Auto-recall (bank " .. bank .. "): " ..
            (flags.disable_auto_recall and "off" or "on"))
        return true
    end

    -- snap.ar=y/n — enable/disable auto-recall for current bank
    local ar_val = cmd:match("^snap%.ar=([yn])$")
    if ar_val then
        local bank = snap_get_current_bank()
        local snaps, flags = snap_load_bank(bank)
        flags.disable_auto_recall = (ar_val == "n")
        snap_save_bank(bank, snaps, flags)
        say("Auto-recall (bank " .. bank .. "): " ..
            (flags.disable_auto_recall and "off" or "on"))
        return true
    end

    -- snap.gapfolder? — show current gap-detection folder for current bank
    if cmd == "snap.gapfolder?" then
        local bank = snap_get_current_bank()
        local _, flags = snap_load_bank(bank)
        local sel = flags.bank_folder_selection or "all"
        if sel == "all" then
            say("Gap folder (bank " .. bank .. "): all")
        else
            local tr   = snap_find_track_by_guid(sel)
            local name = ""
            if tr then
                _, name = GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
            end
            say("Gap folder (bank " .. bank .. "): " .. (name ~= "" and name or sel))
        end
        return true
    end

    -- snap.gapfolder=all  or  snap.gapfolder=<track name>
    local gf_val = cmd:match("^snap%.gapfolder=(.+)$")
    if gf_val then
        local bank = snap_get_current_bank()
        local snaps, flags = snap_load_bank(bank)
        if gf_val == "all" then
            flags.bank_folder_selection = "all"
            snap_save_bank(bank, snaps, flags)
            say("Gap folder (bank " .. bank .. "): all")
        else
            local found = nil
            for i = 0, CountTracks(0) - 1 do
                local t = GetTrack(0, i)
                local _, tn = GetSetMediaTrackInfo_String(t, "P_NAME", "", false)
                if tn == gf_val then
                    found = t; break
                end
            end
            if not found then
                say("No track named '" .. gf_val .. "' found")
            else
                local _, tg = GetSetMediaTrackInfo_String(found, "GUID", "", false)
                flags.bank_folder_selection = tg
                snap_save_bank(bank, snaps, flags)
                say("Gap folder (bank " .. bank .. "): " .. gf_val)
            end
        end
        return true
    end

    -- snap.copy=X — copy bank X into current bank (snapshots only)
    local copy_bank = cmd:match("^snap%.copy=([ABCD])$")
    if copy_bank then
        local bank = snap_get_current_bank()
        if copy_bank == bank then
            say("Already in bank " .. bank)
            return true
        end
        local src_snaps = snap_load_bank(copy_bank)
        local _, dst_flags = snap_load_bank(bank)
        snap_save_bank(bank, src_snaps, dst_flags)
        say("Copied " .. #src_snaps .. " snapshot" .. (#src_snaps ~= 1 and "s" or "") ..
            " from bank " .. copy_bank .. " to bank " .. bank)
        return true
    end

    -- snap.rm (bare, no "=N") — delete all snapshots in current bank, the
    -- whole-collection counterpart to snap.rm=N below (same bare-vs-"="
    -- distinction as fxoff/fxoff=selector). Dotted to match every other
    -- snap.* command, now that snap.add/snap.rm[=N]/snap.recall[=N] cover
    -- the full instance-level family alongside the existing bank settings.
    if cmd == "snap.rm" then
        local bank = snap_get_current_bank()
        local _, flags = snap_load_bank(bank)
        flags.counter = 0
        snap_save_bank(bank, {}, flags)
        say("Bank " .. bank .. " cleared")
        return true
    end

    -- snap.add — create or update snapshot for the selected item
    if cmd == "snap.add" then
        local item = GetSelectedMediaItem(0, 0)
        if not item then
            say("No item selected"); return true
        end
        local item_guid = BR_GetMediaItemGUID(item)
        local take = GetActiveTake(item)
        local item_name = ""
        if take then
            _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        end
        local bank = snap_get_current_bank()
        local snaps, flags = snap_load_bank(bank)
        local existing_idx = nil
        for i, s in ipairs(snaps) do
            if s.item_guid == item_guid then
                existing_idx = i; break
            end
        end
        local snapshot = {
            item_guid = item_guid,
            item_name = item_name or "",
            date      = os.date("%Y-%m-%d"),
            time      = os.date("%H:%M:%S"),
            notes     = existing_idx and (snaps[existing_idx].notes or "") or "",
            tracks    = {},
        }
        for i = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, i)
            if snap_is_special_track(track) then
                snapshot.tracks[i] = snap_get_track_state(track)
            end
        end
        local display = item_name ~= "" and humanize_item_name(item_name) or item_guid:sub(1, 13)
        if existing_idx then
            snaps[existing_idx] = snapshot
            say("Snapshot updated: " .. display)
        else
            flags.counter = (flags.counter or 0) + 1
            table.insert(snaps, snapshot)
            say("Snapshot created: " .. display)
        end
        snap_save_bank(bank, snaps, flags)
        if not snap_daemon_running() then
            local cid = snap_daemon_cmd()
            if cid ~= 0 then
                Main_OnCommand(cid, 0)
                say("Snapshot daemon started")
            end
        end
        return true
    end

    -- snap.recall (bare) — recall snapshot matching the current cursor/item
    -- position; snap.recall=N below recalls a specific numbered snapshot.
    if cmd == "snap.recall" then
        local bank = snap_get_current_bank()
        local snaps, flags = snap_load_bank(bank)
        local item = GetSelectedMediaItem(0, 0)
        local snap = item and snap_find_by_item_guid(snaps, BR_GetMediaItemGUID(item))
        if not snap then
            snap = snap_find_at_cursor(snaps, GetCursorPosition())
        end
        if snap then
            snap_recall_snapshot(snap, flags)
            local name = snap.item_name ~= "" and humanize_item_name(snap.item_name) or "snapshot"
            say("Recalled: " .. name)
        else
            say("No snapshot at cursor position")
        end
        return true
    end

    -- snap.recall=N — recall snapshot N (1-based, timeline order)
    local snap_n = cmd:match("^snap%.recall=(%d+)$")
    if snap_n then
        local bank = snap_get_current_bank()
        local snaps, flags = snap_load_bank(bank)
        snap_sort_by_timeline(snaps)
        local n = tonumber(snap_n)
        local snap = snaps[n]
        if not snap then
            say("No snapshot " .. n .. " in bank " .. bank)
            return true
        end
        snap_recall_snapshot(snap, flags)
        local name = snap.item_name ~= "" and humanize_item_name(snap.item_name) or snap.item_guid:sub(1, 13)
        say("Recalled snapshot " .. n .. ": " .. name)
        return true
    end

    -- snap.rm=N — delete snapshot N (1-based, timeline order)
    local del_n = cmd:match("^snap%.rm=(%d+)$")
    if del_n then
        local bank = snap_get_current_bank()
        local snaps, flags = snap_load_bank(bank)
        snap_sort_by_timeline(snaps)
        local n = tonumber(del_n)
        if not snaps[n] then
            say("No snapshot " .. n .. " in bank " .. bank)
            return true
        end
        local name = snaps[n].item_name ~= "" and humanize_item_name(snaps[n].item_name)
            or snaps[n].item_guid:sub(1, 13)
        table.remove(snaps, n)
        snap_save_bank(bank, snaps, flags)
        say("Deleted snapshot " .. n .. ": " .. name)
        return true
    end

    -- snap.addauto — convert all snapshots in current bank to automation
    -- lanes. The daemon's job is auto-recalling snapshot states; once that
    -- data is baked into real automation, REAPER plays it back natively and
    -- the daemon is no longer needed, so stop it if it's running.
    if cmd == "snap.addauto" then
        local bank = snap_get_current_bank()
        local snaps, flags = snap_load_bank(bank)
        local had_snaps = #snaps > 0
        snap_convert_to_automation(snaps, flags)
        if had_snaps then
            local msg = "Snapshots converted to automation"
            if snap_daemon_running() then
                local cid = snap_daemon_cmd()
                if cid ~= 0 then
                    Main_OnCommand(cid, 0)
                    SetProjExtState(0, "MixerSnapshots", "daemon_heartbeat", "0")
                    msg = msg .. ". Snapshot daemon stopped (no longer needed)"
                end
            end
            say(msg)
        end
        return true
    end

    -- snap.open — start the Mixer Snapshots Daemon
    if cmd == "snap.open" then
        local cid = snap_daemon_cmd()
        if cid == 0 then
            say("Mixer Snapshots Daemon script not found")
            return true
        end
        if snap_daemon_running() then
            say("Snapshot daemon already running")
        else
            Main_OnCommand(cid, 0)
            say("Snapshot daemon started")
        end
        return true
    end

    -- snap.close — stop the Mixer Snapshots Daemon
    if cmd == "snap.close" then
        local cid = snap_daemon_cmd()
        if cid == 0 then
            say("Mixer Snapshots Daemon script not found")
            return true
        end
        if not snap_daemon_running() then
            say("Snapshot daemon is not running")
        else
            Main_OnCommand(cid, 0)
            SetProjExtState(0, "MixerSnapshots", "daemon_heartbeat", "0")
            say("Snapshot daemon stopped")
        end
        return true
    end

    -- snap.daemon? — check whether the headless auto-recall daemon is running
    if cmd == "snap.daemon?" then
        local _, ts = GetProjExtState(0, "MixerSnapshots", "daemon_heartbeat")
        local t = tonumber(ts) or 0
        if snap_daemon_running() then
            say(string.format("Snapshot daemon: running (last heartbeat %ds ago)", os.time() - t))
        else
            say("Snapshot daemon: stopped  (use snap.open to start)")
        end
        return true
    end

    -- snap.rmauto — clear all automation from special tracks. This is the
    -- reverse of snap.addauto: with the automation gone, recall is back to
    -- depending on mixer snapshots, so make sure the daemon is running.
    if cmd == "snap.rmauto" then
        Undo_BeginBlock()
        local count = 0
        for i = 0, CountTracks(0) - 1 do
            local track = GetTrack(0, i)
            if snap_is_special_track(track) then
                local n = CountTrackEnvelopes(track)
                for e = 0, n - 1 do
                    local env = GetTrackEnvelope(track, e)
                    DeleteEnvelopePointRange(env, -1000000, 1000000)
                    GetSetEnvelopeInfo_String(env, "VISIBLE", "0", true)
                    GetSetEnvelopeInfo_String(env, "ACTIVE", "0", true)
                    GetSetEnvelopeInfo_String(env, "ARM", "0", true)
                end
                if n > 0 then count = count + 1 end
            end
        end
        UpdateArrange()
        TrackList_AdjustWindows(false)
        Undo_EndBlock("Clear Mixer Snapshot Automation", -1)

        local msg = "Cleared automation from " .. count .. " track" .. (count ~= 1 and "s" or "")
        if not snap_daemon_running() then
            local cid = snap_daemon_cmd()
            if cid ~= 0 then
                Main_OnCommand(cid, 0)
                msg = msg .. ". Snapshot daemon started"
            end
        end
        say(msg)
        return true
    end

    return false
end

---------------------------------------------------------------------
-- Prepare Takes + Preferences helpers
---------------------------------------------------------------------

local PREF_LABELS = {
    "S-D Crossfade Length (ms)",
    "CD Track Offset (ms)",
    "INDEX0 Length (s) (>= 1)",
    "Album Lead-out Time (s)",
    "No Auto Item Coloring",
    "No Ranking Color",
    "REF = Overdub Guide",
    "Add S-D Markers at Mouse Hover",
    "Alt Audition Playback Rate",
    "Year of Production",
    "CUE Audio Format",
    "Floating Destination Folder",
    "Find Takes Using Item Names",
    "Show Only Item Take Numbers",
    "Source Audition Mode",
}
local PREF_BINARY = { [5] = true, [6] = true, [7] = true, [8] = true, [12] = true, [13] = true, [14] = true, [15] = true }
local PREF_N = 15
local PREF_FMT_VALID = { WAV = true, FLAC = true, MP3 = true, AIFF = true }
local PREF_KEYS = {
    xfade = 1,
    offset = 2,
    index0 = 3,
    leadout = 4,
    nocolor = 5,
    norank = 6,
    refguide = 7,
    sdmarkers = 8,
    altrate = 9,
    year = 10,
    cuefmt = 11,
    floatdest = 12,
    itemnames = 13,
    takenums = 14,
    srcmode = 15,
}

local function pref_resolve(key)
    local n = tonumber(key)
    if n then return (n >= 1 and n <= PREF_N) and math.floor(n) or nil end
    return PREF_KEYS[key:lower()]
end

local function pref_load()
    local year = os.date("%Y")
    local default = "35,200,3,7,0,0,0,0,0.75," .. year .. ",WAV,0,0,0,0"
    local _, saved = GetProjExtState(0, "ReaClassical", "Preferences")
    if saved == "" then saved = default end
    if select(2, saved:gsub(",", ",")) + 1 ~= PREF_N then saved = default end
    local t = {}
    for v in saved:gmatch("([^,]+)") do t[#t + 1] = v end
    return t
end

local function pref_save(t)
    SetProjExtState(0, "ReaClassical", "Preferences", table.concat(t, ","))
end

local function pref_validate(idx, val)
    if idx == 11 then
        local fmt = val:upper()
        if not PREF_FMT_VALID[fmt] then
            return false, nil, "CUE Audio Format must be WAV, FLAC, AIFF or MP3"
        end
        return true, fmt
    end
    local num = tonumber(val)
    if not num then return false, nil, "must be a number" end
    if num < 0 then return false, nil, "must not be negative" end
    if PREF_BINARY[idx] then
        if num ~= 0 and num ~= 1 then return false, nil, "must be 0 or 1 (boolean field)" end
        return true, tostring(math.floor(num))
    end
    if idx == 3 and num < 1 then return false, nil, "INDEX0 Length must be >= 1" end
    if idx ~= 9 and num ~= math.floor(num) then
        return false, nil, "must be a whole number (only field 9 accepts decimals)"
    end
    return true, tostring(num)
end

---------------------------------------------------------------------

function try_prepare_prefs(cmd)
    -- prepare — run Prepare Takes headlessly
    if cmd == "prepare" then
        if CountMediaItems(0) == 0 then
            say("No items in project"); return true
        end
        _G.RC_TERMINAL_ARGS = {}
        dofile(script_path .. "ReaClassical_Prepare Takes.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- pref? — list all 15 preferences
    if cmd == "pref?" then
        local t = pref_load()
        local out = { "Preferences:" }
        for i = 1, PREF_N do
            out[#out + 1] = string.format("  %2d. %-40s %s", i, PREF_LABELS[i], t[i])
        end
        say(table.concat(out, "\n"))
        return true
    end

    -- pref.key? — query single preference by keyword or index
    local key_q = cmd:match("^pref%.([%w]+)%?$")
    if key_q then
        local idx = pref_resolve(key_q)
        if not idx then
            say("Unknown preference: " .. key_q); return true
        end
        local t = pref_load()
        say(string.format("pref %d (%s) = %s", idx, PREF_LABELS[idx], t[idx]))
        return true
    end

    -- pref.key=value — set single preference with validation
    local key_s, val_s = cmd:match("^pref%.([%w]+)=(.+)$")
    if key_s then
        local idx = pref_resolve(key_s)
        if not idx then
            say("Unknown preference: " .. key_s); return true
        end
        local ok, norm, err = pref_validate(idx, val_s)
        if not ok or not norm then
            say("pref " .. idx .. ": " .. (err or "invalid value")); return true
        end
        local t = pref_load()
        t[idx] = norm
        pref_save(t)
        say(string.format("pref %d (%s) → %s", idx, PREF_LABELS[idx], norm))
        return true
    end

    return false
end

---------------------------------------------------------------------
-- Record Panel helpers (headless, no ImGui)
---------------------------------------------------------------------

local function rec_get_take_count(session_name)
    local sep = package.config:sub(1, 1)
    local media_path = GetProjectPath(0)
    local max_take = 0
    local i = 0
    while true do
        local filename = EnumerateFiles(media_path .. sep .. session_name, i)
        if not filename then break end
        local n = tonumber(filename:match(".*[^%d](%d+)%)?%.%a+$"))
        if n and n > max_take then max_take = n end
        i = i + 1
    end
    return max_take
end

local function rec_update_wildcards(sess, take_num)
    if not APIExists("SNM_SetStringConfigVar") then return end
    local sep = package.config:sub(1, 1)
    local s_dir = sess ~= "" and (sess .. sep) or ""
    local s_sfx = sess ~= "" and (sess .. "_") or ""
    local padded = string.format("%03d", math.max(1, tonumber(take_num) or 1))
    SNM_SetStringConfigVar("recfile_wildcards", s_dir .. s_sfx .. "$tracknameornumber_T" .. padded)
end

local function rec_daemon_cmd()
    if not APIExists("AddRemoveReaScript") then return 0 end
    local path = script_path .. "ReaClassical_Record Panel Daemon.lua"
    return AddRemoveReaScript(true, 0, path, true)
end

local function rec_daemon_running()
    local _, ts = GetProjExtState(0, "ReaClassical", "rec_daemon_heartbeat")
    return (os.time() - (tonumber(ts) or 0)) < 5
end

-- Port of is_special_track() (Meterbridge.lua): excludes mixer/aux/submix/
-- roomtone/live/REF/RCMASTER tracks, plus listenback (kept permanently
-- armed for cue/foldback monitoring, so it never counts as "recording").
local function rec_is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

-- ai/auto_assign_inputs() writes I_RECINPUT to the source/destination track
-- (the one actually armed for recording), not to its "M:" mixer channel-
-- strip track -- so rd?/N? must read I_RECINPUT from that same track,
-- found here by reversing the mixer track's feed send (mirrors
-- find_mixer_for_track() in ReaClassical_Record Panel.lua, in reverse).
function get_source_for_mixer(mixer_track)
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

-- Same decoding as rec_input_label(), but spelling out "none"/mono/stereo
-- for the rd? and N? terminal queries instead of the daemon status table's
-- compact "-" placeholder.
function rec_input_description(tr)
    local rec_input = math.floor(GetMediaTrackInfo_Value(tr, "I_RECINPUT"))

    if rec_input == -1 or rec_input == 4096 then
        return "none"
    end

    if (rec_input & 4096) ~= 0 and rec_input > 4096 then
        return "MIDI"
    end

    local is_stereo = (rec_input & 1024) ~= 0
    return rec_input_label(tr) .. " (" .. (is_stereo and "stereo" or "mono") .. ")"
end

local function rec_track_label(tr)
    local ok, name = GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    return (ok and name ~= "" and name) or ("Track " .. GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
end

-- Port of get_input_label() (Meterbridge.lua), always preferring hardware
-- channel names (falling back to numeric channel numbers) since there's no
-- GUI here to offer a toggle.
function rec_input_label(tr)
    local rec_input = math.floor(GetMediaTrackInfo_Value(tr, "I_RECINPUT"))

    if rec_input == -1 or rec_input == 4096 then
        return "-"
    end

    if (rec_input & 4096) ~= 0 and rec_input > 4096 then
        return "MIDI"
    end

    local start_channel = rec_input & 1023
    local is_stereo = (rec_input & 1024) ~= 0
    local is_multichannel = (rec_input & 2048) ~= 0
    local first_input = start_channel + 1

    local hw_name1 = GetInputChannelName(start_channel)

    if is_stereo then
        local hw_name2 = GetInputChannelName(start_channel + 1)
        if hw_name1 and hw_name1 ~= "" and hw_name2 and hw_name2 ~= "" then
            local base1 = hw_name1:match("^(.+)%s+%d+$") or hw_name1
            local base2 = hw_name2:match("^(.+)%s+%d+$") or hw_name2
            if base1 == base2 then
                return string.format("%s+%s", hw_name1, hw_name2)
            else
                return string.format("%s/%s", hw_name1, hw_name2)
            end
        end
        return string.format("%d-%d", first_input, first_input + 1)
    elseif is_multichannel then
        local num_channels = math.floor(GetMediaTrackInfo_Value(tr, "I_NCHAN"))
        if hw_name1 and hw_name1 ~= "" then
            return string.format("%s+%d", hw_name1, num_channels - 1)
        end
        return string.format("%d-%d", first_input, first_input + num_channels - 1)
    else
        if hw_name1 and hw_name1 ~= "" then
            return hw_name1
        end
        return string.format("%d", first_input)
    end
end

---------------------------------------------------------------------

function try_record(cmd)
    -- rec.open — start the Record Panel Daemon and arm the selected folder
    if cmd == "rec.open" then
        local cid = rec_daemon_cmd()
        if cid == 0 then
            say("Record Panel Daemon script not found")
            return true
        end
        local already_running = rec_daemon_running()
        if not already_running then
            SetProjExtState(0, "ReaClassical", "rec_daemon_stop", "")
            Main_OnCommand(cid, 0)
            -- Pre-set the Panel toggle so F9 (called below) sees it as open
            -- before the daemon's first defer frame fires
            local panel_id = NamedCommandLookup("_RSbd41ad183cae7b18bccb86b087f719e945278160")
            if panel_id ~= 0 then SetToggleCommandState(1, panel_id, 1) end
        end
        -- Arm the selected folder (first-press F9 behaviour) if nothing is armed yet
        local any_armed = false
        for i = 0, CountTracks(0) - 1 do
            local t = GetTrack(0, i)
            local _, lb = GetSetMediaTrackInfo_String(t, "P_EXT:listenback", "", false)
            if lb ~= "y" and GetMediaTrackInfo_Value(t, "I_RECARM") == 1 then
                any_armed = true; break
            end
        end
        if not any_armed and APIExists("AddRemoveReaScript") then
            local f9_cid = AddRemoveReaScript(true, 0,
                script_path .. "ReaClassical_Classical Take Record.lua", true)
            if f9_cid ~= 0 then Main_OnCommand(f9_cid, 0) end
        end

        local status_msg = already_running and "Record daemon already running" or "Record daemon started"
        local armed_folder
        for i = 0, CountTracks(0) - 1 do
            local t = GetTrack(0, i)
            local _, lb = GetSetMediaTrackInfo_String(t, "P_EXT:listenback", "", false)
            if lb ~= "y" and GetMediaTrackInfo_Value(t, "I_RECARM") == 1
                and GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
                armed_folder = t; break
            end
        end
        if armed_folder then
            local _, take_num = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
            status_msg = status_msg .. (take_num ~= "" and (". Armed for take " .. take_num) or ". Folder armed")
        end
        say(status_msg)
        return true
    end

    -- rec.close — signal the daemon to stop itself cleanly
    if cmd == "rec.close" then
        local cid = rec_daemon_cmd()
        if cid == 0 then
            say("Record Panel Daemon script not found")
            return true
        end
        if not rec_daemon_running() then
            say("Record daemon is not running")
        else
            -- Signal the daemon to stop on its next frame; it resets the Panel
            -- toggle state itself so F9 opens the GUI again.
            SetProjExtState(0, "ReaClassical", "rec_daemon_stop", "1")
            -- Invalidate heartbeat immediately so rec.open can restart right away
            SetProjExtState(0, "ReaClassical", "rec_daemon_heartbeat", "0")
            say("Record daemon stopped")
        end
        return true
    end

    -- rec.arm — arm the selected folder for recording without starting it.
    -- If it's already armed (or already recording), just announces that
    -- instead of changing anything -- the precise counterpart to rec.start,
    -- with F9 still doing both steps in one press via the classic toggle.
    if cmd == "rec.arm" then
        _G.RC_TERMINAL_ARGS = { mode = "arm" }
        dofile(script_path .. "ReaClassical_Classical Take Record.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- rec.start — start recording on the already-armed folder. If nothing
    -- is armed yet (or already recording), just announces that instead of
    -- arming it for you -- use rec.arm first. Bare "rec.start" is distinct
    -- from "rec.start=HH:MM"/"rec.start?" below (the scheduled-start-time
    -- setting), since those require a trailing "=" or "?".
    if cmd == "rec.start" then
        _G.RC_TERMINAL_ARGS = { mode = "start" }
        dofile(script_path .. "ReaClassical_Classical Take Record.lua")
        _G.RC_TERMINAL_ARGS = nil
        return true
    end

    -- rec.stop — press F9 to stop the current recording
    if cmd == "rec.stop" then
        if GetPlayState() == 0 then
            say("Not recording")
            return true
        end
        if not APIExists("AddRemoveReaScript") then
            say("AddRemoveReaScript API not found (install SWS extension)")
            return true
        end
        local f9_cid = AddRemoveReaScript(true, 0,
            script_path .. "ReaClassical_Classical Take Record.lua", true)
        if f9_cid == 0 then
            say("Classical Take Record script not found")
            return true
        end
        -- Classical Take Record.lua now announces "Stopped recording take N"
        -- itself, so nothing further to say.
        Main_OnCommand(f9_cid, 0)
        return true
    end

    -- rec.pause — toggle pause/unpause while recording. The Record Panel
    -- Daemon announces "Paused recording take N" / "Recording take N"
    -- itself on its next frame, so nothing further to say here.
    if cmd == "rec.pause" then
        local ps = GetPlayState()
        if ps ~= 5 and ps ~= 6 then
            say("Not recording")
            return true
        end
        Main_OnCommand(1008, 0) -- Transport: Pause
        return true
    end

    -- rec.next — move to the next recording section (Vertical workflow only)
    if cmd == "rec.next" then
        local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
        if wf ~= "Vertical" then
            say("Next Section is only available in Vertical workflow")
            return true
        end
        if GetPlayState() ~= 0 then
            say("Stop recording before moving to next section")
            return true
        end
        if not APIExists("AddRemoveReaScript") then
            say("AddRemoveReaScript API not found (install SWS extension)")
            return true
        end
        local next_cid = AddRemoveReaScript(true, 0,
            script_path .. "ReaClassical_Set Next Recording Section.lua", true)
        if next_cid == 0 then
            say("Set Next Recording Section script not found")
            return true
        end
        Main_OnCommand(next_cid, 0)
        say("Moved to next recording section")
        return true
    end

    -- rec.split — stop and immediately start a new take, incrementing the
    -- take number (Horizontal) or moving to the next folder (Vertical),
    -- matching the Record Panel's "+Take" button (Shift+F9)
    if cmd == "rec.split" then
        if GetPlayState() == 0 then
            say("Not recording")
            return true
        end
        if not APIExists("AddRemoveReaScript") then
            say("AddRemoveReaScript API not found (install SWS extension)")
            return true
        end
        local inc_cid = AddRemoveReaScript(true, 0,
            script_path .. "ReaClassical_Increment Take Number While Recording.lua", true)
        if inc_cid == 0 then
            say("Increment Take Number While Recording script not found")
            return true
        end
        Main_OnCommand(inc_cid, 0)
        say("Take split")
        return true
    end

    -- rec.daemon? — check daemon status
    if cmd == "rec.daemon?" then
        local _, ts = GetProjExtState(0, "ReaClassical", "rec_daemon_heartbeat")
        local t = tonumber(ts) or 0
        if rec_daemon_running() then
            say(string.format("Record daemon: running (last heartbeat %ds ago)", os.time() - t))
        else
            say("Record daemon: stopped  (use rec.open to start)")
        end
        return true
    end

    -- rec? — show all settings
    if cmd == "rec?" then
        local _, sess      = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        local _, take_str  = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        local _, override  = GetProjExtState(0, "ReaClassical", "TakeCounterOverride")
        local _, start_t   = GetProjExtState(0, "ReaClassical", "Recording Start")
        local _, end_t     = GetProjExtState(0, "ReaClassical", "Recording End")
        local _, dur       = GetProjExtState(0, "ReaClassical", "Recording Duration")
        local _, overlap   = GetProjExtState(0, "ReaClassical", "AllowOverlappingTakes")
        local _, horiz     = GetProjExtState(0, "ReaClassical", "RecordTakesHorizontally")
        local _, clip_rep  = GetProjExtState(0, "ReaClassical", "ClipReporting")
        local n            = tonumber(take_str) or 0
        local take_display = n > 0
            and string.format("T%03d (%s)", n, override == "1" and "manual override" or "auto")
            or "auto-detect"
        say(table.concat({
            "Recording settings:",
            string.format("  session:    %s", sess ~= "" and sess or "(none)"),
            string.format("  take:       %s", take_display),
            string.format("  start:      %s", start_t ~= "" and start_t or "(none)"),
            string.format("  end:        %s", end_t ~= "" and end_t or "(none)"),
            string.format("  duration:   %s", dur ~= "" and dur or "(none)"),
            string.format("  overlap:    %s", overlap == "1" and "yes" or "no"),
            string.format("  horizontal: %s", horiz == "1" and "yes" or "no"),
            string.format("  clip:       %s", clip_rep == "0" and "no" or "yes"),
            string.format("  daemon:     %s", rec_daemon_running() and "running" or "stopped"),
        }, "\n"))
        return true
    end

    -- rec.session=name — set session name (scans existing files for correct next take)
    local sess_set = cmd:match("^rec%.session=(.+)$")
    if sess_set then
        sess_set = trim(sess_set)
        SetProjExtState(0, "ReaClassical", "TakeSessionName", sess_set)
        SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "0")
        local max_found = rec_get_take_count(sess_set)
        local next_take = max_found + 1
        SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(next_take))
        rec_update_wildcards(sess_set, next_take)
        say(string.format("Session: %s  (next take: T%03d)", sess_set, next_take))
        return true
    end

    -- rec.session? — query session name
    if cmd == "rec.session?" then
        local _, sess = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        say("Session: " .. (sess ~= "" and sess or "(none)"))
        return true
    end

    -- rec.rmsession — clear session name
    if cmd == "rec.rmsession" then
        SetProjExtState(0, "ReaClassical", "TakeSessionName", "")
        SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "0")
        local max_found = rec_get_take_count("")
        local next_take = max_found + 1
        SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(next_take))
        rec_update_wildcards("", next_take)
        say(string.format("Session cleared  (next take: T%03d)", next_take))
        return true
    end

    -- rec.take=N — set specific take with validation against existing files
    local take_n_str = cmd:match("^rec%.take=(%d+)$")
    if take_n_str then
        local n = tonumber(take_n_str)
        local _, sess = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        local max_found = rec_get_take_count(sess)
        if n < max_found then
            say(string.format(
                "Cannot set take to %d — highest found is T%03d. Use rec.take=%d or higher.",
                n, max_found, max_found))
            return true
        end
        SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(n))
        SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "1")
        rec_update_wildcards(sess, n)
        say(string.format("Take set to T%03d (manual override)", n))
        return true
    end

    -- rec.take=auto — disable override, revert to file-scan auto-detection
    if cmd == "rec.take=auto" then
        local _, sess = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "0")
        local max_found = rec_get_take_count(sess)
        local next_take = max_found + 1
        SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(next_take))
        rec_update_wildcards(sess, next_take)
        say(string.format("Take: auto-detect  (next: T%03d)", next_take))
        return true
    end

    -- rec.take? — query take number and mode
    if cmd == "rec.take?" then
        local _, take_str = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        local n = tonumber(take_str) or 0
        if n > 0 then
            say(string.format("Next is take %d", n))
        else
            say("Next take not yet set")
        end
        return true
    end

    -- rec.latest? — scan the project media folder (honoring the current
    -- session name, if set) for the highest take number found on disk,
    -- as opposed to rec.take? which reports the upcoming take number.
    if cmd == "rec.latest?" then
        local _, sess = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        local max_found = rec_get_take_count(sess)
        if max_found > 0 then
            say(string.format("Latest is take %d", max_found))
        else
            say("No takes found on disk" .. (sess ~= "" and (" for session: " .. sess) or ""))
        end
        return true
    end

    -- rec.inctake — manually increment take by 1 (also updates wildcards)
    if cmd == "rec.inctake" then
        local _, take_str = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
        local _, sess = GetProjExtState(0, "ReaClassical", "TakeSessionName")
        local n = math.max(1, (tonumber(take_str) or 0) + 1)
        SetProjExtState(0, "ReaClassical", "CurrentTakeNumber", tostring(n))
        SetProjExtState(0, "ReaClassical", "TakeCounterOverride", "1")
        rec_update_wildcards(sess, n)
        say(string.format("Take incremented to T%03d", n))
        return true
    end

    -- rec.rank=letter — set rank for the take currently recording (applied
    -- when it stops) or, if stopped, the last-recorded take. Mirrors the
    -- Record Panel's rank dropdown via the same WebRemote_* ext-state channel.
    local rec_rank_letter = cmd:match("^rec%.rank=([evgobpufn])$")
    if rec_rank_letter then
        local rank_index = RANK_LETTERS[rec_rank_letter]
        local rank_str = (rank_index == 9) and "" or tostring(rank_index)
        SetProjExtState(0, "ReaClassical", "WebRemote_Rank", rank_str)
        SetProjExtState(0, "ReaClassical", "WebRemote_Pending", "1")
        say("Rank: " .. (RANK_PREFIXES[rank_index] ~= "" and RANK_PREFIXES[rank_index] or "None"))
        return true
    end

    -- rec.note=text — set notes for the take currently recording (applied
    -- when it stops) or, if stopped, the last-recorded take.
    local rec_note_val = cmd:match("^rec%.note=(.*)$")
    if rec_note_val then
        SetProjExtState(0, "ReaClassical", "WebRemote_Note", rec_note_val)
        SetProjExtState(0, "ReaClassical", "WebRemote_Pending", "1")
        say(rec_note_val ~= "" and ("Note: " .. rec_note_val) or "Note cleared")
        return true
    end

    -- rec.start=HH:MM — set recording start time
    local start_val = cmd:match("^rec%.start=(.+)$")
    if start_val then
        if not start_val:match("^%d+:%d%d$") then
            say("Invalid format — use HH:MM (e.g. rec.start=20:00)")
            return true
        end
        SetProjExtState(0, "ReaClassical", "Recording Start", start_val)
        say("Recording start: " .. start_val)
        return true
    end

    -- rec.start? — query start time
    if cmd == "rec.start?" then
        local _, v = GetProjExtState(0, "ReaClassical", "Recording Start")
        say("Recording start: " .. (v ~= "" and v or "(none)"))
        return true
    end

    -- rec.end=HH:MM — set recording end time
    local end_val = cmd:match("^rec%.end=(.+)$")
    if end_val then
        if not end_val:match("^%d+:%d%d$") then
            say("Invalid format — use HH:MM (e.g. rec.end=23:00)")
            return true
        end
        SetProjExtState(0, "ReaClassical", "Recording End", end_val)
        say("Recording end: " .. end_val)
        return true
    end

    -- rec.end? — query end time
    if cmd == "rec.end?" then
        local _, v = GetProjExtState(0, "ReaClassical", "Recording End")
        say("Recording end: " .. (v ~= "" and v or "(none)"))
        return true
    end

    -- rec.duration=HH:MM — set recording duration
    local dur_val = cmd:match("^rec%.duration=(.+)$")
    if dur_val then
        if not dur_val:match("^%d+:%d%d$") then
            say("Invalid format — use HH:MM (e.g. rec.duration=02:30)")
            return true
        end
        SetProjExtState(0, "ReaClassical", "Recording Duration", dur_val)
        say("Recording duration: " .. dur_val)
        return true
    end

    -- rec.duration? — query duration
    if cmd == "rec.duration?" then
        local _, v = GetProjExtState(0, "ReaClassical", "Recording Duration")
        say("Recording duration: " .. (v ~= "" and v or "(none)"))
        return true
    end

    -- rec.rmtime — clear all time window fields at once
    if cmd == "rec.rmtime" then
        SetProjExtState(0, "ReaClassical", "Recording Start", "")
        SetProjExtState(0, "ReaClassical", "Recording End", "")
        SetProjExtState(0, "ReaClassical", "Recording Duration", "")
        say("Recording time window cleared")
        return true
    end

    -- rec.overlap=y/n — allow overlapping takes
    local overlap_val = cmd:match("^rec%.overlap=([yn])$")
    if overlap_val then
        local v = overlap_val == "y" and "1" or "0"
        SetProjExtState(0, "ReaClassical", "AllowOverlappingTakes", v)
        say("Allow overlapping takes: " .. (v == "1" and "yes" or "no"))
        return true
    end

    -- rec.overlap? — query overlap setting
    if cmd == "rec.overlap?" then
        local _, v = GetProjExtState(0, "ReaClassical", "AllowOverlappingTakes")
        say("Allow overlapping takes: " .. (v == "1" and "yes" or "no"))
        return true
    end

    -- rec.horizontal=y/n — record takes horizontally (vertical workflow)
    local horiz_val = cmd:match("^rec%.horizontal=([yn])$")
    if horiz_val then
        local v = horiz_val == "y" and "1" or "0"
        SetProjExtState(0, "ReaClassical", "RecordTakesHorizontally", v)
        say("Record takes horizontally: " .. (v == "1" and "yes" or "no"))
        return true
    end

    -- rec.horizontal? — query horizontal setting
    if cmd == "rec.horizontal?" then
        local _, v = GetProjExtState(0, "ReaClassical", "RecordTakesHorizontally")
        say("Record takes horizontally: " .. (v == "1" and "yes" or "no"))
        return true
    end

    -- rec.clip=y/n — toggle OSARA clip announcements from the Record Panel
    -- Daemon for rec-armed tracks (on by default; unset ProjExtState == on)
    local clip_val = cmd:match("^rec%.clip=([yn])$")
    if clip_val then
        local v = clip_val == "y" and "1" or "0"
        SetProjExtState(0, "ReaClassical", "ClipReporting", v)
        say("Clip reporting: " .. (v == "1" and "yes" or "no"))
        return true
    end

    -- rec.clip? — query clip reporting setting
    if cmd == "rec.clip?" then
        local _, v = GetProjExtState(0, "ReaClassical", "ClipReporting")
        say("Clip reporting: " .. (v == "0" and "no" or "yes"))
        return true
    end

    -- rec.levels? — report the current peak hold (dB) for every rec-armed
    -- track, in track order, for an immediate "lay of the land" overview.
    -- Reads REAPER's own peak hold directly (same value Meterbridge shows
    -- and rec.rmlevels clears), so it works whether or not the Record Panel
    -- Daemon is running, and reflects the loudest moment since the last
    -- clear (manual, via rec.rmlevels, or an acknowledged clip).
    if cmd == "rec.levels?" then
        local lines = {}
        for i = 0, CountTracks(0) - 1 do
            local tr = GetTrack(0, i)
            if GetMediaTrackInfo_Value(tr, "I_RECARM") == 1 and not rec_is_special_track(tr) then
                local num_channels = math.max(1, math.floor(GetMediaTrackInfo_Value(tr, "I_NCHAN")))
                local db = -150
                for ch = 0, math.min(num_channels, 64) - 1 do
                    db = math.max(db, Track_GetPeakHoldDB(tr, ch, false) * 100)
                end
                lines[#lines + 1] = string.format("%s, input %s: %.1f dB",
                    rec_track_label(tr), rec_input_label(tr), db)
            end
        end
        say(#lines > 0 and table.concat(lines, "\n") or "No rec-armed tracks")
        return true
    end

    -- rec.rmlevels — clear peak/RMS hold values via REAPER's native
    -- "Track: Reset all peak/RMS values" action, so the next rec.levels?
    -- reflects only what happens from this point on
    if cmd == "rec.rmlevels" then
        Main_OnCommand(40527, 0)
        say("Peak hold values cleared")
        return true
    end

    return false
end

---------------------------------------------------------------------
-- OSARA installer (downloads/extracts via OS-builtin tools only:
-- PowerShell on Windows, curl/unzip on macOS)
---------------------------------------------------------------------

-- Mirrors ReaClassical_Factory Reset.lua's ExecUpdate() restart sequence.
function restart_reaper()
    Main_OnCommand(40886, 0)
    if IsProjectDirty(0) == 0 then
        Main_OnCommand(40063, 0)
        Main_OnCommand(40004, 0)
    else
        MB("Restart cancelled due to unsaved changes.", "ReaClassical", 0)
    end
end

-- Native Windows CPU architecture (PROCESSOR_ARCHITEW6432 reflects the real
-- host arch when running under WOW64; falls back to PROCESSOR_ARCHITECTURE).
function windows_arch()
    local arch = os.getenv("PROCESSOR_ARCHITEW6432") or os.getenv("PROCESSOR_ARCHITECTURE") or ""
    return arch:upper()
end

local OSARA_BASE_URL = "https://github.com/chmaha/ReaClassical/raw/main/Installers/UserPlugins/OSARA/"

function try_osara_install(cmd)
    if cmd ~= "installosara" then return false end

    local system = GetOS()
    local separator = package.config:sub(1, 1)
    local resource_path = GetResourcePath()
    local userplugins_path = resource_path .. separator .. "UserPlugins"

    local exec_cmd, plugin_file
    if string.find(system, "^Win") then
        local filename
        if system == "Win32" then
            filename = "reaper_osara32.dll"
        elseif windows_arch():find("ARM64") then
            filename = "reaper_osara_arm64ec.dll"
        else
            filename = "reaper_osara64.dll"
        end
        local url = OSARA_BASE_URL .. filename
        plugin_file = userplugins_path .. separator .. filename
        exec_cmd = string.format(
            'powershell -NoProfile -ExecutionPolicy Bypass -Command "' ..
            "$ProgressPreference='SilentlyContinue'; " ..
            "Invoke-WebRequest -Uri '%s' -OutFile '%s'" ..
            '"',
            url, plugin_file)
    elseif string.find(system, "^OSX") or string.find(system, "^macOS") then
        local url = OSARA_BASE_URL .. "reaper_osara.dylib"
        plugin_file = userplugins_path .. separator .. "reaper_osara.dylib"
        exec_cmd = string.format("curl -fsSL -o '%s' '%s'", plugin_file, url)
    else
        say("installosara is only supported on Windows and macOS")
        return true
    end

    local already_installed = false
    local existing = io.open(plugin_file, "rb")
    if existing then
        existing:close()
        already_installed = true
    end

    local prompt
    if already_installed then
        prompt = "OSARA already appears to be installed in UserPlugins." ..
            "\n\nReinstall it anyway? REAPER will restart afterwards."
    else
        prompt = "This will download OSARA and install it into REAPER's UserPlugins folder," ..
            "\nthen restart REAPER to load it." ..
            "\n\nAre you sure you want to continue?"
    end

    local response = MB(prompt, "Install OSARA", 4)
    if response ~= 6 then return true end

    say("Downloading and installing OSARA, please wait...")
    local ok = os.execute(exec_cmd)
    if not ok then
        say("Failed to download/install OSARA. Check your internet connection and try again.")
        return true
    end

    say("OSARA installed. Restarting REAPER...")
    restart_reaper()
    return true
end

---------------------------------------------------------------------
-- REAPER self-updater: "updatereaper" (bare) installs the recommended/tested
-- version listed at the project's tested_reaper_ver.txt on GitHub;
-- "updatereaper=latest" installs the latest public release;
-- "updatereaper=VERSION" installs a specific version (main, dev, or RC --
-- e.g. "updatereaper=752" or "updatereaper=7.52" for 7.52, or
-- "updatereaper=596+dev1009"/"updatereaper=597rc1" for a dev/RC build);
-- "updatereaper=rec" (or "=recommended") is a synonym for the bare command.
-- Unlike the GUI tool, version lookups search the full historical archive
-- with no cutoff. This closes all open projects (REAPER's own save-changes
-- prompt protects unsaved work), downloads, and installs/restarts
-- immediately -- see ReaClassical_Update REAPER.lua for the actual
-- download/install logic, which runs as its own deferred script so a large
-- download doesn't block REAPER's UI thread.
---------------------------------------------------------------------

function try_update_reaper(cmd)
    if cmd ~= "updatereaper" and not cmd:match("^updatereaper=") then return false end

    if not APIExists("AddRemoveReaScript") then
        say("AddRemoveReaScript API not found (install SWS extension)")
        return true
    end

    local version = cmd:match("^updatereaper=(.+)$")
    local mode = "recommended"
    if version then
        local lower = version:lower()
        if lower == "rec" or lower == "recommended" then
            mode = "recommended"
        elseif lower == "latest" then
            mode = "latest"
        else
            mode = "version"
        end
    end
    SetExtState("ReaClassical_UpdateReaper", "mode", mode, false)
    if mode == "version" then
        SetExtState("ReaClassical_UpdateReaper", "version", version, false)
    end

    local update_cid = AddRemoveReaScript(true, 0,
        script_path .. "ReaClassical_Update REAPER.lua", true)
    if update_cid == 0 then
        say("Update REAPER script not found")
        return true
    end
    Main_OnCommand(update_cid, 0)
    return true
end

---------------------------------------------------------------------
-- Commands that shouldn't be remembered for "!" (repeat last command):
-- one-shot setup/destructive/external-resource actions where blindly
-- replaying them again would be pointless at best (help, newtab) or
-- actively unwanted (Nv/Nh discards the project just created;
-- factoryreset/installosara/update/updatereaper download or reset things).
---------------------------------------------------------------------

function is_unrepeatable_command(full_input)
    local first = trim(full_input:match("^([^;]+)") or "")
    if first == "help" or first == "newtab" or first == "factoryreset"
        or first == "installosara" or first == "update"
        or first == "updatereaper" or first:match("^updatereaper=")
        or first:match("^%d+v") or first:match("^%d+h") then
        return true
    end
    return false
end

---------------------------------------------------------------------
-- Dispatcher
---------------------------------------------------------------------

function execute_command(cmd)
    if cmd == "" then return end

    if try_project_setup(cmd) then return end
    if try_naming(cmd) then return end
    if try_input_config(cmd) then return end
    if try_selection(cmd) then return end
    if try_markers(cmd) then return end
    if try_track_query(cmd) then return end
    if try_track_subquery(cmd) then return end
    if try_mute_solo(cmd) then return end
    if try_pan(cmd) then return end
    if try_fader(cmd) then return end
    if try_peak(cmd) then return end
    if try_automation(cmd) then return end
    if try_delete_automation(cmd) then return end
    if try_ddp(cmd) then return end
    if try_undo_redo(cmd) then return end
    if try_reorder(cmd) then return end
    if try_add_remove(cmd) then return end
    if try_routing_fx(cmd) then return end
    if try_stats(cmd) then return end
    if try_playrate_pitch(cmd) then return end
    if try_snapshots(cmd) then return end
    if try_prepare_prefs(cmd) then return end
    if try_record(cmd) then return end
    if try_misc(cmd) then return end
    if try_osara_install(cmd) then return end
    if try_update_reaper(cmd) then return end

    say("Unknown command: " .. cmd)
end

---------------------------------------------------------------------
-- Entry point
---------------------------------------------------------------------

function main()
    local _, wf = GetProjExtState(0, "ReaClassical", "Workflow")
    workflow = wf

    local input
    local repeating = _G.RC_REPEAT_LAST == true

    if repeating then
        local _, last = GetProjExtState(0, "ReaClassical", "LastTerminalCommand")
        if last == "" then
            say("No previous command to repeat")
            return
        end
        input = last
    else
        local retval, user_input = GetUserInputs("ReaClassical Terminal", 1, "Command:,extrawidth=300", "")
        if not retval then return end
        input = trim(user_input)

        if input == "!" then
            local _, last = GetProjExtState(0, "ReaClassical", "LastTerminalCommand")
            if last == "" then
                say("No previous command to repeat")
                return
            end
            input = last
        elseif input ~= "" and not is_unrepeatable_command(input) then
            SetProjExtState(0, "ReaClassical", "LastTerminalCommand", input)
        end
    end

    local commands = {}
    for c in input:gmatch("[^;]+") do
        c = trim(c)
        if c ~= "" then table.insert(commands, c) end
    end
    if #commands == 0 then return end

    -- Give VoiceOver/OSARA time to finish announcing the focus change
    -- caused by the dialog closing before we speak the result, otherwise
    -- the announcement gets stomped and only the focused control's
    -- accessibility role (e.g. "text") is heard. Not needed when repeating
    -- the last command since no dialog was ever opened.
    local dialog_closed_time = time_precise()
    local function run_commands()
        if not repeating and time_precise() - dialog_closed_time < 0.2 then
            defer(run_commands)
            return
        end

        if workflow == "" then
            local first = commands[1]
            if not (first:match("^%d+v") or first:match("^%d+h") or first == "newtab"
                    or first == "update" or first == "installosara" or first == "factoryreset" or first == "help"
                    or first == "updatereaper" or first:match("^updatereaper=")
                    or first == "debug=on" or first == "debug=off") then
                say("Please create a ReaClassical project first (e.g. 6v)")
                return
            end
        end

        Undo_BeginBlock()
        for _, c in ipairs(commands) do
            execute_command(c)
        end
        Undo_EndBlock("ReaClassical Terminal: " .. input, -1)
        UpdateArrange()
    end
    run_commands()
end

main()
