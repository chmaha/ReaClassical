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

local render_settings = require("ReaClassical_Render_Settings")
local enum_project_markers = require("ReaClassical_Marker_Enum")
local rank_info = require("ReaClassical_Rank_Info")

local M = {}

M.EXPORT_FORMATS = {
    { key = "wav",  label = "WAV" },
    { key = "flac", label = "FLAC" },
    { key = "opus", label = "Opus 160" },
    { key = "mp3",  label = "MP3 320" },
}

local SPECIAL_KEYS = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "talkback", "rcmaster", "playback", "notes" }

function M.is_special_track(track)
    for _, key in ipairs(SPECIAL_KEYS) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

function M.get_rc_folders()
    local folders = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 and not M.is_special_track(track) then
            folders[#folders + 1] = track
        end
    end
    return folders
end

function M.get_folder_children(parent_track)
    local children = {}
    if not parent_track then return children end
    local idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER")
    local num_tracks = CountTracks(0)
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end
        children[#children + 1] = tr
        depth = depth + GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        idx = idx + 1
    end
    return children
end

function M.clean_take_name(raw_name, keep_rank)
    local clean = (raw_name:match("^(.-)%s*|") or raw_name):match("^%s*(.-)%s*$")
    if not keep_rank then
        clean = rank_info.strip_rank_prefix(clean):match("^%s*(.-)%s*$")
    end
    return clean
end

function M.sanitize_filename(name)
    name = name:gsub("[\\/]", "-"):gsub('[:%*%?"<>|%c]', ""):gsub("%s+", " ")
    return (name:match("^%s*(.-)[%s%.]*$"))
end

local function stash_regions()
    local stash = {}
    local i = 0
    while true do
        local ret, isrgn, pos, rgnend, name, idx, color = enum_project_markers(0, i)
        if not ret then break end
        if isrgn then
            stash[#stash + 1] = { pos = pos, rgnend = rgnend, name = name, idx = idx, color = color }
        end
        i = i + 1
    end
    for _, r in ipairs(stash) do DeleteProjectMarker(0, r.idx, true) end
    return stash
end

local function restore_regions(stash)
    for _, r in ipairs(stash) do
        AddProjectMarker2(0, true, r.pos, r.rgnend, r.name, r.idx, r.color)
    end
end

local function save_render_settings()
    local s = {}
    local _
    _, s.format = GetSetProjectInfo_String(0, "RENDER_FORMAT", "", false)
    s.srate      = GetSetProjectInfo(0, "RENDER_SRATE", 0, false)
    s.channels   = GetSetProjectInfo(0, "RENDER_CHANNELS", 0, false)
    s.boundsflag = GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false)
    s.renderset  = GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
    s.dither     = GetSetProjectInfo(0, "RENDER_DITHER", 0, false)
    _, s.file    = GetSetProjectInfo_String(0, "RENDER_FILE", "", false)
    _, s.pattern = GetSetProjectInfo_String(0, "RENDER_PATTERN", "", false)
    return s
end

local function restore_render_settings(s)
    GetSetProjectInfo_String(0, "RENDER_FORMAT", s.format, true)
    GetSetProjectInfo(0, "RENDER_SRATE", s.srate, true)
    GetSetProjectInfo(0, "RENDER_CHANNELS", s.channels, true)
    GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", s.boundsflag, true)
    GetSetProjectInfo(0, "RENDER_SETTINGS", s.renderset, true)
    GetSetProjectInfo(0, "RENDER_DITHER", s.dither, true)
    GetSetProjectInfo_String(0, "RENDER_FILE", s.file, true)
    GetSetProjectInfo_String(0, "RENDER_PATTERN", s.pattern, true)
end

local function save_track_mute_state()
    local state = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        state[i] = {
            track = track,
            mute = GetMediaTrackInfo_Value(track, "B_MUTE"),
            solo = GetMediaTrackInfo_Value(track, "I_SOLO"),
        }
    end
    return state
end

local function restore_track_mute_state(state)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if state[i] then
            SetMediaTrackInfo_Value(track, "B_MUTE", state[i].mute)
            SetMediaTrackInfo_Value(track, "I_SOLO", state[i].solo)
        end
    end
end

local function solo_folder_for_render(folder_track, mute_state)
    local original = {}
    for _, s in pairs(mute_state) do original[s.track] = s.mute end
    local keep = { [folder_track] = true }
    for _, c in ipairs(M.get_folder_children(folder_track)) do keep[c] = true end
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local mute = 1
        if M.is_special_track(track) or keep[track] then
            mute = original[track] or 0
        end
        SetMediaTrackInfo_Value(track, "B_MUTE", mute)
        SetMediaTrackInfo_Value(track, "I_SOLO", 0)
    end
end

local function get_export_subdir(format, rs)
    if format == "wav" then return string.format("WAV_%d_%d", rs.samplerate, rs.bitdepth) end
    if format == "flac" then return string.format("FLAC_%d_%d", rs.samplerate, rs.bitdepth) end
    if format == "opus" then return "OPUS_160" end
    return "MP3_320"
end

local function apply_format_render_settings(format, rs)
    if format == "wav" then
        GetSetProjectInfo_String(0, "RENDER_FORMAT", render_settings.build_wav_format(rs.bitdepth), true)
        GetSetProjectInfo(0, "RENDER_SRATE", rs.samplerate, true)
        GetSetProjectInfo(0, "RENDER_DITHER", render_settings.dither_value_for(rs.bitdepth, rs.dither), true)
    elseif format == "flac" then
        GetSetProjectInfo_String(0, "RENDER_FORMAT", render_settings.build_flac_format(rs.bitdepth), true)
        GetSetProjectInfo(0, "RENDER_SRATE", rs.samplerate, true)
        GetSetProjectInfo(0, "RENDER_DITHER", render_settings.dither_value_for(rs.bitdepth, rs.dither), true)
    elseif format == "opus" then
        GetSetProjectInfo_String(0, "RENDER_FORMAT", "U2dnTwAAIEMACgAAAAIAAAA=", true)
        GetSetProjectInfo(0, "RENDER_SRATE", 48000, true)
        GetSetProjectInfo(0, "RENDER_DITHER", 0, true)
    elseif format == "mp3" then
        GetSetProjectInfo_String(0, "RENDER_FORMAT", "bDNwbUABAAAAAAAAAgAAAP////8EAAAAQAEAAAAAAAA=", true)
        GetSetProjectInfo(0, "RENDER_SRATE", render_settings.mp3_samplerate_for(rs.samplerate), true)
        GetSetProjectInfo(0, "RENDER_DITHER", 0, true)
    end
    GetSetProjectInfo(0, "RENDER_CHANNELS", 2, true)
    GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 3, true)
    GetSetProjectInfo(0, "RENDER_SETTINGS", 0, true)
end

function M.load_render_settings()
    local sr, bd, d = render_settings.load()
    return { samplerate = sr, bitdepth = bd, dither = d }
end

-- groups: list of { folder = track|nil, regions = { { start, finish, name } } }
-- folder is soloed during its render when given
function M.render_groups(opts)
    local proj_path = GetProjectPath()
    if proj_path == "" then
        return nil, "Please save the project before exporting."
    end

    local slash = package.config:sub(1, 1)
    local subdir = get_export_subdir(opts.format, opts.settings)
    local base_rel = "Exports/" .. opts.dir_name .. "/" .. subdir .. "/"
    RecursiveCreateDirectory(proj_path .. slash .. "Exports" .. slash .. opts.dir_name .. slash .. subdir, 0)

    local saved_render = save_render_settings()
    apply_format_render_settings(opts.format, opts.settings)

    Undo_BeginBlock()
    PreventUIRefresh(1)

    local stash = stash_regions()
    local mute_state = save_track_mute_state()
    local used = {}
    local total = 0

    for _, group in ipairs(opts.groups) do
        local added = {}
        for _, r in ipairs(group.regions) do
            local name = M.sanitize_filename(r.name)
            if name ~= "" and r.finish > r.start then
                local unique, n = name, 2
                while used[unique:lower()] do
                    unique = name .. " (" .. n .. ")"
                    n = n + 1
                end
                used[unique:lower()] = true
                added[#added + 1] = AddProjectMarker2(0, true, r.start, r.finish, unique, -1, 0)
            end
        end
        if #added > 0 then
            if group.folder then solo_folder_for_render(group.folder, mute_state) end
            GetSetProjectInfo_String(0, "RENDER_FILE", base_rel, true)
            GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region", true)
            Main_OnCommand(42230, 0)
            total = total + #added
        end
        for _, idx in ipairs(added) do DeleteProjectMarker(0, idx, true) end
    end

    restore_track_mute_state(mute_state)
    restore_regions(stash)

    PreventUIRefresh(-1)
    restore_render_settings(saved_render)
    Undo_EndBlock(opts.undo_label, -1)
    UpdateArrange()
    UpdateTimeline()

    return total, base_rel
end

function M.draw_render_settings(ImGui, ctx, rs)
    ImGui.Text(ctx, "Render settings:")
    ImGui.SameLine(ctx)

    local srate_preview = "44.1 kHz"
    for idx, sr in ipairs(render_settings.samplerate_list) do
        if sr == rs.samplerate then srate_preview = render_settings.samplerate_labels[idx] end
    end
    ImGui.SetNextItemWidth(ctx, 100)
    if ImGui.BeginCombo(ctx, "##render_samplerate", srate_preview) then
        for idx, sr in ipairs(render_settings.samplerate_list) do
            local is_sel = (rs.samplerate == sr)
            if ImGui.Selectable(ctx, render_settings.samplerate_labels[idx], is_sel) then
                rs.samplerate = sr
                render_settings.save_samplerate(sr)
            end
            if is_sel then ImGui.SetItemDefaultFocus(ctx) end
        end
        ImGui.EndCombo(ctx)
    end
    if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "Render sample rate (WAV / FLAC)")
    end

    ImGui.SameLine(ctx)
    local bitdepth_preview = "16-bit"
    for idx, bd in ipairs(render_settings.bitdepth_list) do
        if bd == rs.bitdepth then bitdepth_preview = render_settings.bitdepth_labels[idx] end
    end
    ImGui.SetNextItemWidth(ctx, 100)
    if ImGui.BeginCombo(ctx, "##render_bitdepth", bitdepth_preview) then
        for idx, bd in ipairs(render_settings.bitdepth_list) do
            local is_sel = (rs.bitdepth == bd)
            if ImGui.Selectable(ctx, render_settings.bitdepth_labels[idx], is_sel) then
                rs.bitdepth = bd
                render_settings.save_bitdepth(bd)
                if bd ~= 16 then
                    rs.dither = "Off"
                    render_settings.save_dither("Off")
                end
            end
            if is_sel then ImGui.SetItemDefaultFocus(ctx) end
        end
        ImGui.EndCombo(ctx)
    end
    if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, "Render bit depth (WAV / FLAC)")
    end

    ImGui.SameLine(ctx)
    local dither_disabled = rs.bitdepth ~= 16
    if dither_disabled then ImGui.BeginDisabled(ctx) end
    ImGui.SetNextItemWidth(ctx, 120)
    if ImGui.BeginCombo(ctx, "##render_dither", rs.dither) then
        for _, d in ipairs(render_settings.dither_list) do
            local is_sel = (rs.dither == d)
            if ImGui.Selectable(ctx, d, is_sel) then
                rs.dither = d
                render_settings.save_dither(d)
            end
            if is_sel then ImGui.SetItemDefaultFocus(ctx) end
        end
        ImGui.EndCombo(ctx)
    end
    if dither_disabled then ImGui.EndDisabled(ctx) end
    if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx,
            "Dither, 16-bit only (WAV / FLAC)\n"
            .. "Triangular: light dither, unshaped\n"
            .. "HP filtered: dither + noise shaping\n"
            .. "Noise shaping: noise shaping alone, no dither\n"
            .. "Off: neither")
    end
end

function M.draw_format_buttons(ImGui, ctx, tooltip_prefix)
    local chosen
    ImGui.Text(ctx, "Export:")
    ImGui.SameLine(ctx)
    for i, f in ipairs(M.EXPORT_FORMATS) do
        if i > 1 then ImGui.SameLine(ctx) end
        if ImGui.Button(ctx, f.label .. "##export_" .. f.key) then chosen = f.key end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, tooltip_prefix .. f.label)
        end
    end
    return chosen
end

return M
