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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local album_meta_store = require("ReaClassical_Album_Metadata")

function M.check_prerequisites(label)
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", label, 0)
        return false
    end

    if GetProjectName(0) == "" then
        MB("Please save your project before running this function.", label, 0)
        return false
    end

    return true
end

function M.check_folder_track_empty(folder_track, label)
    local track_count = CountTracks(0)
    local track_idx = GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") - 1
    for i = track_idx, track_count - 1 do
        local track = GetTrack(0, i)
        if CountTrackMediaItems(track) > 0 then
            MB("The destination folder already has items on it. " .. label .. " expects a "
                .. "fresh, empty project -- run it before adding any other audio.", label, 0)
            return false
        end
        if GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") < 0 then break end
    end
    return true
end

function M.insert_source_item(track, filepath)
    local src = PCM_Source_CreateFromFile(filepath)
    if not src then return nil, "Could not read the audio at " .. filepath end
    local item = AddMediaItemToTrack(track)
    local take = AddTakeToMediaItem(item)
    SetMediaItemTake_Source(take, src)
    SetMediaItemInfo_Value(item, "D_POSITION", 0)
    SetMediaItemInfo_Value(item, "D_LENGTH", GetMediaSourceLength(src))
    return item
end

local TRACK_KEYS = { "performer", "songwriter", "composer", "arranger", "message" }

local function build_track_name(t, tm, has_gap)
    local parts = { (has_gap and "!" or "") .. (tm.title or "") }
    if t.isrc and t.isrc ~= "" then parts[#parts + 1] = "ISRC=" .. t.isrc end
    for _, k in ipairs(TRACK_KEYS) do
        if tm[k] and tm[k] ~= "" then parts[#parts + 1] = k:upper() .. "=" .. tm[k] end
    end
    return table.concat(parts, "|")
end

function M.run(opts)
    local tracks, track_meta, album_meta = opts.tracks, opts.track_meta, opts.album_meta
    local item_start_pos = GetMediaItemInfo_Value(opts.item, "D_POSITION")

    local split_points = {}
    if opts.has_pregap1_span then
        split_points[#split_points + 1] = item_start_pos + tracks[1].start_sec
    end
    for i = 2, #tracks do
        split_points[#split_points + 1] = item_start_pos + tracks[i].start_sec
    end

    Undo_BeginBlock()
    PreventUIRefresh(1)

    local segments = {}
    local current = opts.item
    for _, pos in ipairs(split_points) do
        local right = SplitMediaItem(current, pos)
        if not right then
            PreventUIRefresh(-1)
            Undo_EndBlock(opts.label, -1)
            return false, "Splitting the imported audio failed unexpectedly."
        end
        segments[#segments + 1] = current
        current = right
    end
    segments[#segments + 1] = current

    local folder_track = GetTrack(0, 0)

    local first_track_idx = 1
    if opts.has_pregap1_span then
        local pregap_item = segments[1]
        local pregap_take = GetActiveTake(pregap_item)
        if opts.keep_pregap1 then
            GetSetMediaItemTakeInfo_String(pregap_take, "P_NAME", "", true)
        else
            DeleteTrackMediaItem(folder_track, pregap_item)
        end
        first_track_idx = 2
    end

    for i, t in ipairs(tracks) do
        local seg = segments[first_track_idx + i - 1]
        local take = GetActiveTake(seg)
        local has_gap = (i > 1) and t.pregap_start_sec ~= nil
        GetSetMediaItemTakeInfo_String(take, "P_NAME", build_track_name(t, track_meta[i], has_gap), true)
    end

    local ALBUM_KEYS_ORDERED = { "performer", "songwriter", "composer", "arranger" }
    local parts = { "@" .. (album_meta.title or "") }
    for _, k in ipairs(ALBUM_KEYS_ORDERED) do
        if album_meta[k] and album_meta[k] ~= "" then parts[#parts + 1] = k:upper() .. "=" .. album_meta[k] end
    end
    if album_meta.genre and album_meta.genre ~= "" then parts[#parts + 1] = "GENRE=" .. album_meta.genre end
    if opts.catalog ~= "" then parts[#parts + 1] = "CATALOG=" .. opts.catalog end
    if album_meta.message and album_meta.message ~= "" then parts[#parts + 1] = "MESSAGE=" .. album_meta.message end

    album_meta_store.set_album_metadata_str(folder_track, table.concat(parts, "|"), nil)

    for i = 0, CountTrackMediaItems(folder_track) - 1 do
        local final_item = GetTrackMediaItem(folder_track, i)
        local final_take = GetActiveTake(final_item)
        if final_take then
            for k = GetNumTakeMarkers(final_take) - 1, 0, -1 do
                DeleteTakeMarker(final_take, k)
            end
        end
    end

    if GetToggleCommandStateEx(0, 40691) == 1 then
        Main_OnCommand(40691, 0)
    end

    local PREF_N = 16
    local pref_year = os.date("%Y")
    local pref_default = "35,200,3,7,0,0,0,0,0.75," .. pref_year .. ",WAV,0,0,0,0,2"
    local _, saved_prefs = GetProjExtState(0, "ReaClassical", "Preferences")
    if saved_prefs == "" or select(2, saved_prefs:gsub(",", ",")) + 1 ~= PREF_N then
        saved_prefs = pref_default
    end
    local pref_entries = {}
    for v in saved_prefs:gmatch("([^,]+)") do pref_entries[#pref_entries + 1] = v end
    pref_entries[2] = "0"
    SetProjExtState(0, "ReaClassical", "Preferences", table.concat(pref_entries, ","))

    _G.RC_SCRIPT_ARGS = { no_undo_wrap = true, silent = true }
    dofile(opts.script_path .. "ReaClassical_Create CD Markers.lua")
    _G.RC_SCRIPT_ARGS = nil

    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()

    Main_OnCommand(40047, 0)

    Undo_EndBlock(opts.label, -1)

    say(string.format("Imported %d track%s from %s and created CD markers.%s", #tracks, #tracks == 1 and "" or "s",
        opts.source_name, opts.keep_pregap1 and " Kept a hidden track before track 1." or ""))

    return true
end

return M
