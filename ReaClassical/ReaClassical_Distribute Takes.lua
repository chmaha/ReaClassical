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

local main, is_special_track, get_rc_folders, get_folder_children
local clear_all_regions, create_regions_for_track
local save_render_settings, restore_render_settings
local save_track_mute_state, restore_track_mute_state
local solo_folder_for_render, render_48k_takes
local ensure_dir

---------------------------------------------------------------------

function is_special_track(track)
    local keys = { "mixer", "aux", "submix", "roomtone", "live", "rcref", "listenback", "rcmaster", "playback" }
    for _, key in ipairs(keys) do
        local _, val = GetSetMediaTrackInfo_String(track, "P_EXT:" .. key, "", false)
        if val == "y" then return true end
    end
    return false
end

---------------------------------------------------------------------

function get_rc_folders()
    local folders = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") == 1 and not is_special_track(track) then
            table.insert(folders, track)
        end
    end
    return folders
end

---------------------------------------------------------------------

function get_folder_children(parent_track)
    local children = {}
    if not parent_track then return children end
    local parent_idx = GetMediaTrackInfo_Value(parent_track, "IP_TRACKNUMBER") - 1
    local num_tracks = CountTracks(0)
    local idx = parent_idx + 1
    local depth = 1
    while idx < num_tracks and depth > 0 do
        local tr = GetTrack(0, idx)
        if not tr then break end
        local folder_depth = GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
        table.insert(children, tr)
        depth = depth + folder_depth
        if depth <= 0 then break end
        idx = idx + 1
    end
    return children
end

---------------------------------------------------------------------

function clear_all_regions()
    local to_delete = {}
    local i = 0
    while true do
        local ret, isrgn, _, _, _, idx = EnumProjectMarkers(i)
        if ret == 0 then break end
        if isrgn then table.insert(to_delete, idx) end
        i = i + 1
    end
    for _, idx in ipairs(to_delete) do
        DeleteProjectMarker(0, idx, true)
    end
end

---------------------------------------------------------------------

-- Creates one region per item on folder_track. name_prefix is prepended to
-- the take name when generating the region name (empty string for horizontal).
-- Returns the count of regions created.
function create_regions_for_track(folder_track, name_prefix)
    local count = 0
    local num_items = GetTrackNumMediaItems(folder_track)
    for i = 0, num_items - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        if take then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local len = GetMediaItemInfo_Value(item, "D_LENGTH")
            local _, raw_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            -- Strip DDP metadata after | and trim whitespace
            local clean = (raw_name:match("^(.-)%s*|") or raw_name):match("^%s*(.-)%s*$")
            local region_name = (name_prefix ~= "" and clean ~= "")
                and (name_prefix .. " " .. clean)
                or (name_prefix ~= "" and name_prefix or clean)
            if region_name ~= "" then
                AddProjectMarker2(0, true, pos, pos + len, region_name, -1, 0)
                count = count + 1
            end
        end
    end
    return count
end

---------------------------------------------------------------------

function save_render_settings()
    local proj = 0
    local s = {}
    local _, fmt = GetSetProjectInfo_String(proj, "RENDER_FORMAT", "", false)
    s.format = fmt
    s.srate       = GetSetProjectInfo(proj, "RENDER_SRATE", 0, false)
    s.channels    = GetSetProjectInfo(proj, "RENDER_CHANNELS", 0, false)
    s.boundsflag  = GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 0, false)
    s.renderset   = GetSetProjectInfo(proj, "RENDER_SETTINGS", 0, false)
    s.dither      = GetSetProjectInfo(proj, "RENDER_DITHER", 0, false)
    local _, file = GetSetProjectInfo_String(proj, "RENDER_FILE", "", false)
    s.file = file
    local _, pat  = GetSetProjectInfo_String(proj, "RENDER_PATTERN", "", false)
    s.pattern = pat
    return s
end

---------------------------------------------------------------------

function restore_render_settings(s)
    local proj = 0
    GetSetProjectInfo_String(proj, "RENDER_FORMAT", s.format, true)
    GetSetProjectInfo(proj, "RENDER_SRATE",      s.srate,      true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS",   s.channels,   true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", s.boundsflag, true)
    GetSetProjectInfo(proj, "RENDER_SETTINGS",   s.renderset,  true)
    GetSetProjectInfo(proj, "RENDER_DITHER",     s.dither,     true)
    GetSetProjectInfo_String(proj, "RENDER_FILE",    s.file,    true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", s.pattern, true)
end

---------------------------------------------------------------------

function save_track_mute_state()
    local state = {}
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        state[i] = {
            mute = GetMediaTrackInfo_Value(track, "B_MUTE"),
            solo = GetMediaTrackInfo_Value(track, "I_SOLO"),
        }
    end
    return state
end

---------------------------------------------------------------------

function restore_track_mute_state(state)
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if state[i] then
            SetMediaTrackInfo_Value(track, "B_MUTE", state[i].mute)
            SetMediaTrackInfo_Value(track, "I_SOLO", state[i].solo)
        end
    end
end

---------------------------------------------------------------------

-- Mutes all content tracks except folder_track and its children.
-- Special tracks (mixer, aux, etc.) are left unmuted so the signal
-- chain to the master remains intact during rendering.
function solo_folder_for_render(folder_track)
    local children = get_folder_children(folder_track)
    local keep = { [folder_track] = true }
    for _, c in ipairs(children) do keep[c] = true end

    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        if is_special_track(track) then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        elseif keep[track] then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        else
            SetMediaTrackInfo_Value(track, "B_MUTE", 1)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

---------------------------------------------------------------------

function ensure_dir(abs_path)
    RecursiveCreateDirectory(abs_path, 0)
end

---------------------------------------------------------------------

-- Applies 48k 16-bit WAV render settings for the given relative output
-- directory and fires the render. All regions in the project are rendered
-- as separate files named by region name ($region).
function render_48k_takes(rel_dir)
    local proj = 0
    -- WAV 16-bit sink config (same blob used for "WAV 48k 16-bit" preset)
    GetSetProjectInfo_String(proj, "RENDER_FORMAT", "ZXZhdxAAAA==", true)
    GetSetProjectInfo(proj, "RENDER_SRATE",      48000, true)
    GetSetProjectInfo(proj, "RENDER_CHANNELS",   2,     true)
    GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3,     true) -- all project regions
    GetSetProjectInfo(proj, "RENDER_SETTINGS",   0,     true) -- master mix
    GetSetProjectInfo(proj, "RENDER_DITHER",     2,     true) -- triangular dither
    GetSetProjectInfo_String(proj, "RENDER_FILE",    rel_dir,  true)
    GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$region", true)
    Main_OnCommand(42230, 0) -- File: Render project, using the most recent render settings
end

---------------------------------------------------------------------

function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    local slash = package.config:sub(1, 1)
    local proj_path = GetProjectPath()
    if proj_path == "" then
        MB("Please save the project before distributing takes.", "ReaClassical Error", 0)
        return
    end

    local base_rel = "Exports/48k_takes/"
    local base_abs = proj_path .. slash .. "Exports" .. slash .. "48k_takes"
    ensure_dir(base_abs)

    local saved_render = save_render_settings()

    Undo_BeginBlock()
    PreventUIRefresh(1)

    clear_all_regions()

    if workflow == "Horizontal" then
        local folders = get_rc_folders()
        if #folders == 0 then
            say("No ReaClassical folders found")
            PreventUIRefresh(-1)
            Undo_EndBlock("Distribute Takes", -1)
            restore_render_settings(saved_render)
            return
        end
        local folder_track = folders[1]
        local count = create_regions_for_track(folder_track, "")
        if count == 0 then
            say("No items with takes found")
            clear_all_regions()
            PreventUIRefresh(-1)
            Undo_EndBlock("Distribute Takes", -1)
            restore_render_settings(saved_render)
            return
        end
        render_48k_takes(base_rel)
        clear_all_regions()
        say(count .. " take" .. (count == 1 and "" or "s") .. " distributed to " .. base_rel)

    elseif workflow == "Vertical" then
        local folders = get_rc_folders()
        if #folders == 0 then
            say("No ReaClassical folders found")
            PreventUIRefresh(-1)
            Undo_EndBlock("Distribute Takes", -1)
            restore_render_settings(saved_render)
            return
        end

        local mute_state = save_track_mute_state()
        local total = 0

        for _, folder_track in ipairs(folders) do
            solo_folder_for_render(folder_track)

            local count = create_regions_for_track(folder_track, "")
            if count > 0 then
                render_48k_takes(base_rel)
                total = total + count
            end
            clear_all_regions()
        end

        restore_track_mute_state(mute_state)

        if total == 0 then
            say("No items with takes found")
        else
            say(total .. " take" .. (total == 1 and "" or "s") .. " distributed to " .. base_rel)
        end
    end

    PreventUIRefresh(-1)
    restore_render_settings(saved_render)
    Undo_EndBlock("Distribute Takes", -1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

main()
