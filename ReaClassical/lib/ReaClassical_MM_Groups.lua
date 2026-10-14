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
local mm = require("ReaClassical_MM_Utils")

local M = {}

local REC_SEP = "\30"
local FIELD_SEP = "\31"

local ASPECT_KEYS = { "mute", "solo", "pan", "fader", "automation", "polarity" }

local function default_aspects()
    local a = {}
    for _, k in ipairs(ASPECT_KEYS) do a[k] = true end
    return a
end

local function aspects_to_str(a)
    local parts = {}
    for _, k in ipairs(ASPECT_KEYS) do parts[#parts + 1] = a[k] and "1" or "0" end
    return table.concat(parts)
end

local function aspects_from_str(s)
    if not s or #s ~= #ASPECT_KEYS then return nil end
    local a = {}
    for i, k in ipairs(ASPECT_KEYS) do
        local c = s:sub(i, i)
        if c ~= "0" and c ~= "1" then return nil end
        a[k] = c == "1"
    end
    return a
end

local function normalize_aspects(g)
    if not g.aspects then g.aspects = default_aspects() end
    for _, k in ipairs(ASPECT_KEYS) do
        if g.aspects[k] == nil then g.aspects[k] = true end
    end
end

local function serialize(groups)
    local recs = {}
    for _, g in ipairs(groups) do
        normalize_aspects(g)
        recs[#recs + 1] = (g.disabled and "1" or "0") .. FIELD_SEP .. g.pattern .. FIELD_SEP .. g.name
            .. FIELD_SEP .. (g.native and tostring(g.native) or "")
            .. FIELD_SEP .. aspects_to_str(g.aspects)
    end
    return table.concat(recs, REC_SEP)
end

local function deserialize(str)
    local groups = {}
    if not str or str == "" then return groups end
    for rec in (str .. REC_SEP):gmatch("(.-)" .. REC_SEP) do
        local flag, pattern, name, native, astr =
            rec:match("^(%d)" .. FIELD_SEP .. "(.-)" .. FIELD_SEP .. "(.-)" .. FIELD_SEP
                .. "(%d*)" .. FIELD_SEP .. "([01]+)$")
        local aspects
        if pattern then
            aspects = aspects_from_str(astr)
        else
            flag, pattern, name, native =
                rec:match("^(%d)" .. FIELD_SEP .. "(.-)" .. FIELD_SEP .. "(.-)" .. FIELD_SEP .. "(%d+)$")
        end
        if not pattern then
            flag, pattern, name = rec:match("^(%d)" .. FIELD_SEP .. "(.-)" .. FIELD_SEP .. "(.*)$")
        end
        if not pattern then
            flag, pattern = rec:match("^(%d)" .. FIELD_SEP .. "(.*)$")
            name = pattern
        end
        if pattern then
            groups[#groups + 1] = {
                pattern = pattern, name = name, disabled = flag == "1", native = tonumber(native),
                aspects = aspects,
            }
        end
    end
    return groups
end

local function alloc_native_slot(groups)
    local used = {}
    for _, g in ipairs(groups) do
        if g.native then used[g.native] = true end
    end
    for n = 1, M.MAX_NATIVE_SLOTS do
        if not used[n] then return n end
    end
    return nil
end

function M.load_groups()
    local _, str = GetProjExtState(0, "ReaClassical", "MixerGroups")
    local groups = deserialize(str)
    local migrated = false

    if #groups > 0 then
        local seen = {}
        local deduped = {}
        for _, g in ipairs(groups) do
            if not g.native or not seen[g.native] then
                if g.native then seen[g.native] = true end
                deduped[#deduped + 1] = g
            else
                migrated = true
            end
        end
        groups = deduped
    end

    for _, g in ipairs(groups) do
        if not g.native then
            g.native = alloc_native_slot(groups)
            migrated = true
        end
        normalize_aspects(g)
    end
    if migrated then
        SetProjExtState(0, "ReaClassical", "MixerGroups", serialize(groups))
        M.sync_native(groups)
    end
    return groups
end

function M.save_groups(groups)
    SetProjExtState(0, "ReaClassical", "MixerGroups", serialize(groups))
end

function M.is_globally_disabled()
    local _, v = GetProjExtState(0, "ReaClassical", "MixerGroupsGlobalDisabled")
    return v == "1"
end

function M.set_globally_disabled(disabled)
    SetProjExtState(0, "ReaClassical", "MixerGroupsGlobalDisabled", disabled and "1" or "")
    M.sync_native()
end

function M.toggle_global_disabled()
    local disabled = not M.is_globally_disabled()
    M.set_globally_disabled(disabled)
    return disabled
end

local function pattern_parts(pattern)
    local parts = {}
    for raw in (pattern .. ","):gmatch("(.-),") do
        local part = raw:match("^%s*(.-)%s*$")
        if part ~= "" then parts[#parts + 1] = part end
    end
    return parts
end

local function cached_label(track, cache)
    if not cache then return mm.get_label(track):lower() end
    local label = cache[track]
    if not label then
        label = mm.get_label(track):lower()
        cache[track] = label
    end
    return label
end

local function label_matches(track, pattern, cache)
    local label = cached_label(track, cache)
    for _, part in ipairs(pattern_parts(pattern)) do
        if label:find(part:lower(), 1, true) then return true end
    end
    return false
end

function M.match_tracks(pattern, tracks, cache)
    tracks = tracks or mm.get_special_tracks_list()
    local list = {}
    for _, t in ipairs(tracks) do
        if label_matches(t, pattern, cache) then list[#list + 1] = t end
    end
    return list
end

function M.find_group_for_track(track, groups, cache)
    groups = groups or M.load_groups()
    for i, g in ipairs(groups) do
        if label_matches(track, g.pattern, cache) then return g, i end
    end
    return nil, nil
end

function M.next_group_name(groups)
    groups = groups or M.load_groups()
    return "Group " .. (#groups + 1)
end

function M.create_group(pattern, name)
    pattern = (pattern or ""):match("^%s*(.-)%s*$")
    if pattern == "" or #pattern_parts(pattern) == 0 then
        return false, "No text entered"
    end
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" then name = M.next_group_name() end

    local groups = M.load_groups()
    for _, g in ipairs(groups) do
        if g.pattern:lower() == pattern:lower() then
            return false, "A group matching '" .. pattern .. "' already exists"
        end
    end

    local matched = M.match_tracks(pattern)
    if #matched == 0 then
        return false, "No tracks matched '" .. pattern .. "'"
    end

    local free = {}
    for _, t in ipairs(matched) do
        if not M.find_group_for_track(t, groups) then free[#free + 1] = t end
    end
    if #free < 2 then
        return false, "Not enough ungrouped tracks matched '" .. pattern
            .. "' -- need at least 2 not already in another group"
    end

    groups[#groups + 1] = { pattern = pattern, name = name, disabled = false, native = alloc_native_slot(groups), aspects = default_aspects() }
    M.save_groups(groups)
    M.sync_native(groups)

    local skipped = #matched - #free
    local msg = string.format("Group '%s' created with %d tracks", name, #free)
    if skipped > 0 then
        msg = msg .. string.format(" (%d already in another group, skipped)", skipped)
    end
    return true, msg
end

local function resolved_members(group, groups, tracks, cache)
    local members = {}
    for _, t in ipairs(M.match_tracks(group.pattern, tracks, cache)) do
        if M.find_group_for_track(t, groups, cache) == group then members[#members + 1] = t end
    end
    return members
end

local NATIVE_PARAMS = { "VOLUME", "PAN", "MUTE", "SOLO", "POLARITY" }
local NATIVE_OFFSET = 96
local LEGACY_OFFSET = 32

local NATIVE_PARAM_FOR_ASPECT = { fader = "VOLUME", pan = "PAN", mute = "MUTE", solo = "SOLO", polarity = "POLARITY" }

local function set_native_bit(track, slot, aspects)
    local mask = 1 << (slot - 1)
    for _, p in ipairs(NATIVE_PARAMS) do
        local aspect_for_param
        for aspect, param in pairs(NATIVE_PARAM_FOR_ASPECT) do
            if param == p then aspect_for_param = aspect break end
        end
        if not (aspect_for_param and aspects and aspects[aspect_for_param] == false) then
            GetSetTrackGroupMembershipEx(track, p .. "_LEAD", NATIVE_OFFSET, mask, mask)
            GetSetTrackGroupMembershipEx(track, p .. "_FOLLOW", NATIVE_OFFSET, mask, mask)
        end
    end
end

local function clear_bank(track, offset)
    for _, p in ipairs(NATIVE_PARAMS) do
        GetSetTrackGroupMembershipEx(track, p .. "_LEAD", offset, 0xFFFFFFFF, 0)
        GetSetTrackGroupMembershipEx(track, p .. "_FOLLOW", offset, 0xFFFFFFFF, 0)
    end
end

function M.sync_native(groups)
    groups = groups or M.load_groups()
    local global_off = M.is_globally_disabled()
    local tracks = mm.get_special_tracks_list()
    local label_cache = {}

    local owner_by_track = {}
    for _, g in ipairs(groups) do
        normalize_aspects(g)
        if g.native and not g.disabled and not global_off then
            local members = resolved_members(g, groups, tracks, label_cache)
            if #members >= 2 then
                for _, t in ipairs(members) do
                    if not owner_by_track[t] then owner_by_track[t] = g end
                end
            end
        end
    end

    for _, track in ipairs(tracks) do
        clear_bank(track, NATIVE_OFFSET)
        clear_bank(track, LEGACY_OFFSET)
        local g = owner_by_track[track]
        if g then
            set_native_bit(track, g.native, g.aspects)
        end
    end
end

function M.get_action_targets(track, aspect)
    if M.is_globally_disabled() then return { track }, false end
    local groups = M.load_groups()
    local g = M.find_group_for_track(track, groups)
    if not g or g.disabled then return { track }, false end
    local members = resolved_members(g, groups)
    if #members < 2 then return { track }, false end
    if aspect then
        normalize_aspects(g)
        if g.aspects[aspect] == false then return { track }, false end
    end
    return members, true, g.name
end

function M.remove_all_groups()
    M.save_groups({})
    M.sync_native({})
end

function M.remove_group_for_track(track)
    local groups = M.load_groups()
    local g, idx = M.find_group_for_track(track, groups)
    if not g then return false, nil end
    table.remove(groups, idx)
    M.save_groups(groups)
    M.sync_native(groups)
    return true, g.name
end

function M.toggle_group_disabled_for_track(track)
    local groups = M.load_groups()
    local g, idx = M.find_group_for_track(track, groups)
    if not g or not idx then return false, nil, nil end
    g.disabled = not g.disabled
    groups[idx] = g
    M.save_groups(groups)
    M.sync_native(groups)
    return true, g.name, g.disabled
end

function M.describe_groups()
    local groups = M.load_groups()
    local out = {}
    for _, g in ipairs(groups) do
        local members = resolved_members(g, groups)
        local labels = {}
        for _, t in ipairs(members) do labels[#labels + 1] = mm.get_label(t) end
        out[#out + 1] = {
            pattern = g.pattern, name = g.name, disabled = g.disabled, native = g.native, labels = labels,
        }
    end
    return out
end

function M.describe_group_for_track(track)
    local groups = M.load_groups()
    local g = M.find_group_for_track(track, groups)
    if not g then return nil end
    local members = resolved_members(g, groups)
    local labels = {}
    for _, t in ipairs(members) do labels[#labels + 1] = mm.get_label(t) end
    return { pattern = g.pattern, name = g.name, disabled = g.disabled, native = g.native, labels = labels }
end

M.MAX_NATIVE_SLOTS = 32

function M.owner_slot_map(groups, tracks)
    groups = groups or M.load_groups()
    tracks = tracks or mm.get_special_tracks_list()
    local cache = {}
    local map = {}
    for _, t in ipairs(tracks) do
        local g = M.find_group_for_track(t, groups, cache)
        map[t] = g and g.native or nil
    end
    return map
end

M.ASPECTS = {
    { key = "mute",       letter = "M" },
    { key = "solo",       letter = "S" },
    { key = "pan",        letter = "Pa" },
    { key = "fader",      letter = "F" },
    { key = "automation", letter = "A" },
    { key = "polarity",   letter = "Po" },
}

function M.first_free_slot(groups)
    groups = groups or M.load_groups()
    local used = {}
    for _, g in ipairs(groups) do
        if g.native then used[g.native] = true end
    end
    for s = 1, M.MAX_NATIVE_SLOTS do
        if not used[s] then return s end
    end
    return nil
end

local function label_part(track)
    return (mm.get_label(track):gsub(",", " "))
end

local function unassign(track, groups)
    local g, idx = M.find_group_for_track(track, groups)
    if not g then return groups end
    local part = label_part(track):lower()
    local parts = {}
    for _, p in ipairs(pattern_parts(g.pattern)) do
        if p:lower() ~= part then parts[#parts + 1] = p end
    end
    if #parts == 0 then
        table.remove(groups, idx)
    else
        g.pattern = table.concat(parts, ",")
    end
    return groups
end

function M.group_for_slot(slot, groups)
    groups = groups or M.load_groups()
    for _, g in ipairs(groups) do
        if g.native == slot then return g end
    end
    return nil
end

function M.set_track_native_slot(track, slot)
    local groups = M.load_groups()
    local target = slot and M.group_for_slot(slot, groups) or nil
    groups = unassign(track, groups)
    if slot and not target then
        target = { pattern = "", name = "Group " .. slot, disabled = false, native = slot, aspects = default_aspects() }
        groups[#groups + 1] = target
    end
    if target then
        local parts = pattern_parts(target.pattern)
        parts[#parts + 1] = label_part(track)
        target.pattern = table.concat(parts, ",")
    end
    M.save_groups(groups)
    M.sync_native(groups)
    return groups
end

function M.rename_slot(slot, name)
    local groups = M.load_groups()
    name = (name or ""):match("^%s*(.-)%s*$")
    local g = M.group_for_slot(slot, groups)
    if not g then
        if name == "" then return groups end
        groups[#groups + 1] = { pattern = "", name = name, disabled = false, native = slot, aspects = default_aspects() }
    elseif name ~= "" then
        g.name = name
    end
    M.save_groups(groups)
    return groups
end

function M.toggle_slot_disabled(slot)
    local groups = M.load_groups()
    local g = M.group_for_slot(slot, groups)
    if not g then return groups end
    g.disabled = not g.disabled
    M.save_groups(groups)
    M.sync_native(groups)
    return groups
end

function M.set_group_aspect(slot, key, enabled)
    local groups = M.load_groups()
    local g = M.group_for_slot(slot, groups)
    if not g then return groups end
    normalize_aspects(g)
    if g.aspects[key] == enabled then return groups end
    g.aspects[key] = enabled
    M.save_groups(groups)

    local param = NATIVE_PARAM_FOR_ASPECT[key]
    if param then
        local members = resolved_members(g, groups, nil, {})
        if #members >= 2 then
            local mask = 1 << (slot - 1)
            local val = enabled and mask or 0
            for _, t in ipairs(members) do
                GetSetTrackGroupMembershipEx(t, param .. "_LEAD", NATIVE_OFFSET, mask, val)
                GetSetTrackGroupMembershipEx(t, param .. "_FOLLOW", NATIVE_OFFSET, mask, val)
            end
        end
    end
    return groups
end

function M.clear_slot(slot)
    local groups = M.load_groups()
    for i, g in ipairs(groups) do
        if g.native == slot then
            table.remove(groups, i)
            break
        end
    end
    M.save_groups(groups)
    M.sync_native(groups)
    return groups
end

return M
