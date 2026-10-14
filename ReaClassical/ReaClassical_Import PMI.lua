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
local pmi = require("ReaClassical_PMI_Import")
local common = require("ReaClassical_CD_Import_Common")

if not common.check_prerequisites("Import PMI") then return end

local folder_track = pmi.find_folder_track()
if not folder_track then
    MB("No destination folder track found.", "Import PMI", 0)
    return
end
if not common.check_folder_track_empty(folder_track, "Import PMI") then return end

local ok, pmi_path = GetUserFileNameForRead("", "Import PMI -- Choose a .pmi File", "pmi")
if not ok or pmi_path == "" then return end

local disc, err = pmi.parse(pmi_path)
if not disc then
    MB(err, "Import PMI", 0)
    return
end

local PREGAP_EPSILON = 0.01
local pregap1_start = disc.tracks[1].pregap_start_sec or disc.tracks[1].start_sec
local has_pregap1_span = disc.tracks[1].start_sec - pregap1_start > PREGAP_EPSILON
local keep_pregap1 = has_pregap1_span
    and not pmi.pregap_is_silent(pmi_path, disc, pregap1_start, disc.tracks[1].start_sec)

local wav_path = (pmi_path:gsub("%.[Pp][Mm][Ii]$", "")) .. ".wav"
local wok, werr = pmi.extract_wav(pmi_path, disc, wav_path)
if not wok then
    MB(werr, "Import PMI", 0)
    return
end

local item, ierr = common.insert_source_item(folder_track, wav_path)
if not item then
    MB(ierr, "Import PMI", 0)
    return
end

local function common_value(tracks, key)
    local first = tracks[1][key]
    if not first or first == "" then return "" end
    for i = 2, #tracks do
        if tracks[i][key] ~= first then return "" end
    end
    return first
end

local function album_field(explicit, tracks, key)
    if explicit ~= "" then return explicit end
    return common_value(tracks, key)
end

local album_meta = {
    title = disc.title,
    performer = album_field(disc.performer, disc.tracks, "performer"),
    songwriter = album_field(disc.songwriter, disc.tracks, "songwriter"),
    composer = album_field(disc.composer, disc.tracks, "composer"),
    arranger = album_field(disc.arranger, disc.tracks, "arranger"),
    genre = disc.genre,
    message = "Imported from a Pyramix .pmi pre-master",
}

local track_meta = {}
for i, t in ipairs(disc.tracks) do
    track_meta[i] = {
        title = t.title,
        performer = t.performer,
        songwriter = t.songwriter,
        composer = t.composer,
        arranger = t.arranger,
        message = "",
    }
end

local ok2, err2 = common.run({
    label = "Import PMI",
    source_name = "PMI",
    script_path = script_path,
    item = item,
    tracks = disc.tracks,
    track_meta = track_meta,
    album_meta = album_meta,
    catalog = disc.catalog,
    has_pregap1_span = has_pregap1_span,
    keep_pregap1 = keep_pregap1,
})
if not ok2 then
    MB(err2, "Import PMI", 0)
end
