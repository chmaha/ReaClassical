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
local ddp = require("ReaClassical_DDP_Import")
local common = require("ReaClassical_CD_Import_Common")

if not common.check_prerequisites("Import DDP") then return end

local folder_track = ddp.find_folder_track()
if not folder_track then
    MB("No destination folder track found.", "Import DDP", 0)
    return
end
if not common.check_folder_track_empty(folder_track, "Import DDP") then return end

local ok, dat_path = GetUserFileNameForRead("", "Import DDP -- Choose the DDP Audio Stream (*.dat)", "dat")
if not ok or dat_path == "" then return end
if not dat_path:lower():match("%.dat$") then
    MB("Expected a *.DAT file (the DDP audio stream) -- found: " .. dat_path, "Import DDP", 0)
    return
end

local dir, _, slash = ddp.split_path(dat_path)

local catalog, tracks = ddp.parse_pqdescr(dir, slash)
if not catalog then
    MB(tracks, "Import DDP", 0)
    return
end

local album_meta, track_meta, has_cdtext = ddp.parse_cdtext(dir, slash, #tracks)
if not album_meta then
    MB(track_meta, "Import DDP", 0)
    return
end
if not has_cdtext then
    MB("No CDTEXT.BIN found. Using generic CD markers.", "Import DDP", 0)
end

local PREGAP_EPSILON = 0.01
local pregap1_start = tracks[1].pregap_start_sec or tracks[1].start_sec
local has_pregap1_span = tracks[1].start_sec - pregap1_start > PREGAP_EPSILON
local keep_pregap1 = has_pregap1_span
    and not ddp.pregap_is_silent(dat_path, pregap1_start, tracks[1].start_sec)

local item, ierr = common.insert_source_item(folder_track, dat_path)
if not item then
    MB(ierr, "Import DDP", 0)
    return
end

local ok2, err2 = common.run({
    label = "Import DDP",
    source_name = "DDP",
    script_path = script_path,
    item = item,
    tracks = tracks,
    track_meta = track_meta,
    album_meta = album_meta,
    catalog = catalog,
    has_pregap1_span = has_pregap1_span,
    keep_pregap1 = keep_pregap1,
})
if not ok2 then
    MB(err2, "Import DDP", 0)
end
