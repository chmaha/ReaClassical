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
local main, parse_markers, write_rcmeta_file
local get_txt_file, get_track_color_from_marker
local count_markers, create_filename, create_cue_entries, create_string
local ext_mod, save_cue_file, format_time, parse_cue_file, create_plaintext_report
local get_export_dir, get_cue_export_dir, get_project_dir
local create_html_report, any_isrc_present, time_to_mmssff, subtract_time_strings
local add_pregaps_to_table
local round_mmss, round_mmssff_string, format_album_length
local create_cdt_file, crc_ccitt, genre_code_for_name

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local enum_project_markers = require("ReaClassical_Marker_Enum")

function main()
  PreventUIRefresh(1)
  Undo_BeginBlock()
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

  local metadata, error_msg = parse_markers()
  if error_msg ~= "" then
    MB(error_msg, "", 0)
  end

  local track = get_track_color_from_marker()
  local metadata_file
  if track then
    metadata_file = get_txt_file()
    write_rcmeta_file(metadata_file, metadata)
  end

  local ret1, num_of_markers = count_markers()
  if not ret1 then return end
  local ret2, filename = create_filename()
  if not ret2 then return end
  local fields, extension, production_year = create_cue_entries(filename, metadata)

  local string, catalog_number, album_length = create_string(fields, num_of_markers, extension)
  local _, slash, cue_file = save_cue_file(fields, string)

  local cdt_file = cue_file:match('^(.+)[.][^.]+$') .. '.cdt'
  create_cdt_file(metadata, cdt_file, num_of_markers)

  local proj_path = get_project_dir()
  local export_dir = get_export_dir(proj_path, slash)
  local txtOutputPath = export_dir .. slash .. 'album_report.txt'
  local HTMLOutputPath = export_dir .. slash .. 'album_report.html'
  local albumTitle, albumPerformer, tracks = parse_cue_file(cue_file, album_length, num_of_markers)
  if albumTitle and albumPerformer and #tracks > 0 then
    create_plaintext_report(albumTitle, albumPerformer, tracks, txtOutputPath, album_length, catalog_number,
      production_year)
    create_html_report(albumTitle, albumPerformer, tracks, HTMLOutputPath, album_length, catalog_number,
      production_year)
  end

  Undo_EndBlock('DDP metadata report', 0)
  PreventUIRefresh(-1)
  UpdateArrange()
  UpdateTimeline()
  if not (_G.RC_SCRIPT_ARGS and _G.RC_SCRIPT_ARGS.silent) then
    say("Metadata report exported")
  end
end

function parse_markers()
  local num_markers = GetNumRegionsOrMarkers(0)
  local metadata = { album = {}, tracks = {} }
  local error_msg = ""

  for i = 0, num_markers - 1 do
    local _, isrgn, _, _, name, _ = enum_project_markers(0, i)
    if not isrgn then
      local album_marker = name:match("^@(.-)|")
      if album_marker then
        metadata.album = {
          title = album_marker:gsub("[\r\n]+", " "):match("^%s*(.-)%s*$"),
          catalog = name:match("CATALOG=([^|]+)") or name:match("EAN=([^|]+)") or name:match("UPC=([^|]+)") or
              nil,
          performer = name:match("PERFORMER=([^|]+)") or nil,
          songwriter = name:match("SONGWRITER=([^|]+)") or nil,
          composer = name:match("COMPOSER=([^|]+)") or nil,
          arranger = name:match("ARRANGER=([^|]+)") or nil,
          message = name:match("MESSAGE=([^|]+)") or nil,
          identification = name:match("IDENTIFICATION=([^|]+)") or nil,
          genre = name:match("GENRE=([^|]+)") or nil,
          language = name:match("LANGUAGE=([^|]+)") or nil
        }
        break
      end
    end
  end

  for i = 0, num_markers - 1 do
    local _, isrgn, _, _, name, _ = enum_project_markers(0, i)
    if not isrgn then
      if not name:match("^@") then
        local track_title = name:match("^#([^|]+)")
        if track_title then
          local track_data = {
            title = track_title,
            isrc = name:match("ISRC=([^|]+)") or nil,
            performer = name:match("PERFORMER=([^|]+)") or nil,
            songwriter = name:match("SONGWRITER=([^|]+)") or nil,
            composer = name:match("COMPOSER=([^|]+)") or nil,
            arranger = name:match("ARRANGER=([^|]+)") or nil,
            message = name:match("MESSAGE=([^|]+)") or nil,
          }

          local missing_album_metadata = false

          if track_data.performer ~= nil and metadata.album.performer == nil then
            missing_album_metadata = true
          end
          if track_data.songwriter ~= nil and metadata.album.songwriter == nil then
            missing_album_metadata = true
          end
          if track_data.composer ~= nil and metadata.album.composer == nil then
            missing_album_metadata = true
          end
          if track_data.arranger ~= nil and metadata.album.arranger == nil then
            missing_album_metadata = true
          end

          table.insert(metadata.tracks, track_data)
        end
      end
    end
  end

  return metadata, error_msg
end

function write_rcmeta_file(metadata_file, metadata)
  local file = io.open(metadata_file, "w")
  if not file then return false, "Could not open file for writing" end

  file:write("AMF Version         = 1.0 (Sony text file format modification)\n")
  file:write("Remarks             = Generated by ReaClassical\n")

  if metadata.album then
    file:write(string.format("Album Title         = %s\n", metadata.album.title or ""))
    file:write(string.format("Catalog Number      = %s\n", metadata.album.catalog or ""))
    file:write(string.format("Performer           = %s\n", metadata.album.performer or ""))
    file:write(string.format("Songwriter          = %s\n", metadata.album.songwriter or ""))
    file:write(string.format("Composer            = %s\n", metadata.album.composer or ""))
    file:write(string.format("Arranger            = %s\n", metadata.album.arranger or ""))
    file:write(string.format("Album Message       = %s\n", metadata.album.message or ""))
    file:write(string.format("Identification      = %s\n", metadata.album.identification or ""))
    file:write(string.format("Genre Code          = %s\n", metadata.album.genre or ""))
    file:write(string.format("Language            = %s\n", metadata.album.language or ""))
  end

  if metadata.tracks and #metadata.tracks > 0 then
    file:write(string.format("Total Tracks        = %d\n", #metadata.tracks))

    for i, track in ipairs(metadata.tracks) do
      local track_num = string.format("%02d", i)
      file:write(string.format("Track %s Title      = %s\n", track_num, (track.title or ""):gsub("[\r\n]+", " ")))
      file:write(string.format("Track %s Performer  = %s\n", track_num, track.performer or ""))
      file:write(string.format("Track %s Songwriter = %s\n", track_num, track.songwriter or ""))
      file:write(string.format("Track %s Composer   = %s\n", track_num, track.composer or ""))
      file:write(string.format("Track %s Arranger   = %s\n", track_num, track.arranger or ""))
      file:write(string.format("Track %s Message    = %s\n", track_num, track.message or ""))
      file:write(string.format("ISRC %s             = %s\n", track_num, track.isrc or ""))
    end
  end

  file:close()

  return true
end

function get_txt_file()
  local path, slash = get_project_dir()
  local export_dir = get_export_dir(path, slash)
  local file = export_dir .. slash .. 'metadata.txt'
  return file
end

function get_track_color_from_marker()
  local proj = 0
  local marker_count = GetNumRegionsOrMarkers(proj)

  local target_color = nil

  for i = 0, marker_count - 1 do
    local retval, isrgn, _, _, name,
    markrgnindexnumber, color =
        enum_project_markers(proj, i)

    if retval then
      if not isrgn and markrgnindexnumber == 0 and name == "!" then
        target_color = color
        break
      end
    end
  end

  if not target_color then return nil end

  local track_count = CountTracks(proj)

  for i = 0, track_count - 1 do
    local track = GetTrack(proj, i)
    local track_color = GetTrackColor(track)

    if track_color == target_color then
      return track
    end
  end

  return nil
end

function count_markers()
  local num_of_markers = GetNumRegionsOrMarkers(0)
  if num_of_markers == 0 then
    MB('Please use "Create CD Markers script" first', "Create CUE file", 0)
    return false
  end
  return true, num_of_markers
end

function create_filename()
  local full_project_name = GetProjectName(0)
  if full_project_name == "" then
    MB("Please save your project first!", "Create CUE file", 0)
    return false
  else
    return true, full_project_name:match("^(.+)[.].*$")
  end
end

function create_cue_entries(filename, metadata)
  local year = tonumber(os.date("%Y"))
  local extension = "wav"

  local _, input = GetProjExtState(0, "ReaClassical", "Preferences")
  if input ~= "" then
    local prefs_table = {}
    for entry in input:gmatch('([^,]+)') do prefs_table[#prefs_table + 1] = entry end
    if prefs_table[10] then year = tonumber(prefs_table[10]) end
    if prefs_table[11] then extension = tostring(prefs_table[11]) end
  end

  if metadata.album.genre == nil then metadata.album.genre = "Unknown" end
  if metadata.album.performer == nil then metadata.album.performer = "Unknown" end
  if metadata.album.title == nil then metadata.album.title = "Unknown" end

  local fields = {
    metadata.album.performer,
    metadata.album.title,
    filename .. '.' .. extension:lower()
  }

  return fields, extension:upper(), year
end

function create_string(fields, num_of_markers, extension)
  local format = ext_mod(extension)

  local _, _, album_pos_out, _, _ = enum_project_markers(0, num_of_markers - 1)
  local album_length = format_time(album_pos_out)
  local _, _, _, _, album_meta = enum_project_markers(0, num_of_markers - 2)
  local catalog_number = (album_meta and album_meta:match('CATALOG=([%w%d]+)')) or ""
  local cdt_basename = fields[3]:match('^(.+)[.][^.]+$') .. '.cdt'
  local out_str

  if catalog_number ~= "" then
    out_str =
        'REM COMMENT "Generated by ReaClassical"' ..
        '\nCATALOG ' .. catalog_number ..
        '\nCDTEXTFILE ' .. '"' .. cdt_basename .. '"' ..
        '\nPERFORMER ' .. '"' .. fields[1] .. '"' ..
        '\nTITLE ' .. '"' .. fields[2] .. '"' ..
        '\nFILE ' .. '"' .. fields[3] .. '"' .. ' ' .. format .. '\n'
  else
    out_str =
        'REM COMMENT "Generated by ReaClassical"' ..
        '\nCDTEXTFILE ' .. '"' .. cdt_basename .. '"' ..
        '\nPERFORMER ' .. '"' .. fields[1] .. '"' ..
        '\nTITLE ' .. '"' .. fields[2] .. '"' ..
        '\nFILE ' .. '"' .. fields[3] .. '"' .. ' ' .. format .. '\n'
  end

  local ind3 = '   '
  local ind5 = '     '

  local marker_id = 1
  local is_pregap = false
  local pregap_start = ""
  for i = 0, num_of_markers - 1 do
    local _, _, raw_pos_out, _, name_out = enum_project_markers(0, i)
    if name_out:find("^#") then
      local perf = name_out:match("PERFORMER=([^|]+)")
      local isrc_code = name_out:match('ISRC=([%w%d]+)') or ""
      name_out = name_out:match("^#([^|]+)")
      if name_out then name_out = name_out:gsub("[\r\n]+", " "):match("^%s*(.-)%s*$") end
      local formatted_time = format_time(raw_pos_out)

      if not perf then perf = fields[1] end

      local id = ("%02d"):format(marker_id)
      marker_id = marker_id + 1
      if name_out == nil or name_out == '' then name_out = 'Untitled' end

      if isrc_code ~= "" then
        out_str = out_str .. ind3 .. 'TRACK ' .. id .. ' AUDIO' .. '\n' ..
            ind5 .. 'TITLE ' .. '"' .. name_out .. '"' .. '\n' ..
            ind5 .. 'PERFORMER ' .. '"' .. perf .. '"' .. '\n' ..
            ind5 .. 'ISRC ' .. isrc_code .. '\n'
        if is_pregap then
          out_str = out_str .. ind5 .. 'INDEX 00 ' .. pregap_start .. '\n'
          is_pregap = false
        end
        out_str = out_str .. ind5 .. 'INDEX 01 ' .. formatted_time .. '\n'
      else
        out_str = out_str .. ind3 .. 'TRACK ' .. id .. ' AUDIO' .. '\n' ..
            ind5 .. 'TITLE ' .. '"' .. name_out .. '"' .. '\n' ..
            ind5 .. 'PERFORMER ' .. '"' .. perf .. '"' .. '\n'
        if is_pregap then
          out_str = out_str .. ind5 .. 'INDEX 00 ' .. pregap_start .. '\n'
          is_pregap = false
        end
        out_str = out_str .. ind5 .. 'INDEX 01 ' .. formatted_time .. '\n'
      end
    elseif name_out:find("^!") then
      is_pregap = true
      pregap_start = format_time(raw_pos_out)
    end
  end

  return out_str, catalog_number, album_length
end

function ext_mod(extension)
  local list = { "AIFF", "MP3" }
  for _, v in pairs(list) do
    if extension == v then
      return extension
    end
  end
  return "WAVE"
end

function get_export_dir(path, slash)
  local export_dir = path .. slash .. "Exports"
  RecursiveCreateDirectory(export_dir, 0)
  return export_dir
end

function get_project_dir()
  local _, path = EnumProjects(-1)
  local slash = package.config:sub(1, 1)
  if path == "" then
    path = GetProjectPath()
  else
    local pattern = "(.+)" .. slash .. ".+[.][Rr][Pp][Pp]"
    path = path:match(pattern)
  end
  return path, slash
end

function get_cue_export_dir(path, slash)
  local export_dir = get_export_dir(path, slash) .. slash .. "Audio+CUE"
  RecursiveCreateDirectory(export_dir, 0)
  return export_dir
end

function save_cue_file(fields, out_str)
  local path, slash = get_project_dir()
  local export_dir = get_cue_export_dir(path, slash)
  local file = export_dir .. slash .. fields[3]:match('^(.+)[.].+') .. '.cue'
  local f = io.open(file, 'w')
  if f then
    f:write(out_str)
    f:close()
  else
    MB(
      "There was an error creating the file. " ..
      "Copy and paste the contents of the following console window to a new .cue file.",
      "Create CUE file", 0)
    ShowConsoleMsg(out_str)
  end
  return export_dir, slash, file
end

function crc_ccitt(data)
  local crc = 0
  for i = 1, #data do
    crc = (crc ~ (data:byte(i) << 8)) & 0xFFFF
    for _ = 1, 8 do
      if crc & 0x8000 ~= 0 then
        crc = ((crc << 1) ~ 0x1021) & 0xFFFF
      else
        crc = (crc << 1) & 0xFFFF
      end
    end
  end
  return (~crc) & 0xFFFF
end

local CDTEXT_GENRES = {
  { 2,  "Adult Contemporary" },
  { 3,  "Alternative Rock" },
  { 4,  "Childrens Music" },
  { 5,  "Classical" },
  { 6,  "Contemporary Christian" },
  { 7,  "Country" },
  { 8,  "Dance" },
  { 9,  "Easy Listening" },
  { 10, "Erotic" },
  { 11, "Folk" },
  { 12, "Gospel" },
  { 13, "Hip Hop" },
  { 14, "Jazz" },
  { 15, "Latin" },
  { 16, "Musical" },
  { 17, "New Age" },
  { 18, "Opera" },
  { 19, "Operetta" },
  { 20, "Pop" },
  { 21, "Rap" },
  { 22, "Reggae" },
  { 23, "Rock Music" },
  { 24, "Rhythm & Blues" },
  { 25, "Sound Effects" },
  { 26, "Soundtrack" },
  { 27, "Spoken Word" },
  { 28, "World Music" },
}

function genre_code_for_name(name)
  if not name then return 0 end
  local lname = name:lower()
  for _, entry in ipairs(CDTEXT_GENRES) do
    if entry[2]:lower() == lname then return entry[1] end
  end
  return 0
end

local CDTEXT_LANGUAGES = {
  { 1,  "Albanian" }, { 2, "Breton" }, { 3, "Catalan" }, { 4, "Croatian" },
  { 5,  "Welsh" }, { 6, "Czech" }, { 7, "Danish" }, { 8, "German" },
  { 9,  "English" }, { 10, "Spanish" }, { 11, "Esperanto" }, { 12, "Estonian" },
  { 13, "Basque" }, { 14, "Faroese" }, { 15, "French" }, { 16, "Frisian" },
  { 17, "Irish" }, { 18, "Gaelic" }, { 19, "Galician" }, { 20, "Icelandic" },
  { 21, "Italian" }, { 22, "Lappish" }, { 23, "Latin" }, { 24, "Latvian" },
  { 25, "Luxembourgian" }, { 26, "Lithuanian" }, { 27, "Hungarian" }, { 28, "Maltese" },
  { 29, "Dutch" }, { 30, "Norwegian" }, { 31, "Occitan" }, { 32, "Polish" },
  { 33, "Portugese" }, { 34, "Romanian" }, { 35, "Romansh" }, { 36, "Serbian" },
  { 37, "Slovak" }, { 38, "Slovenian" }, { 39, "Finnish" }, { 40, "Swedish" },
  { 41, "Turkish" }, { 42, "Flemish" }, { 43, "Wallon" }, { 69, "Zulu" },
  { 70, "Vietnamese" }, { 71, "Uzbek" }, { 72, "Urdu" }, { 73, "Ukrainian" },
  { 74, "Thai" }, { 75, "Telugu" }, { 76, "Tatar" }, { 77, "Tamil" },
  { 78, "Tadzhik" }, { 79, "Swahili" }, { 80, "SrananTongo" }, { 81, "Somali" },
  { 82, "Sinhalese" }, { 83, "Shona" }, { 84, "Serbo-croat" }, { 85, "Ruthenian" },
  { 86, "Russian" }, { 87, "Quechua" }, { 88, "Pushtu" }, { 89, "Punjabi" },
  { 90, "Persian" }, { 91, "Papamiento" }, { 92, "Oriya" }, { 93, "Nepali" },
  { 94, "Ndebele" }, { 95, "Marathi" }, { 96, "Moldavian" }, { 97, "Malaysian" },
  { 98, "Malagasay" }, { 99, "Macedonian" }, { 100, "Laotian" }, { 101, "Korean" },
  { 102, "Khmer" }, { 103, "Kazakh" }, { 104, "Kannada" }, { 105, "Japanese" },
  { 106, "Indonesian" }, { 107, "Hindi" }, { 108, "Hebrew" }, { 109, "Hausa" },
  { 110, "Gurani" }, { 111, "Gujurati" }, { 112, "Greek" }, { 113, "Georgian" },
  { 114, "Fulani" }, { 115, "Dari" }, { 116, "Churash" }, { 117, "Chinese" },
  { 118, "Burmese" }, { 119, "Bulgarian" }, { 120, "Bengali" }, { 121, "Bielorussian" },
  { 122, "Bambora" }, { 123, "Azerbaijani" }, { 124, "Assamese" }, { 125, "Armenian" },
  { 126, "Arabic" }, { 127, "Amharic" },
}

local function language_code_for_name(name)
  if not name or name == "" then return 0 end
  local lname = name:lower()
  for _, entry in ipairs(CDTEXT_LANGUAGES) do
    if entry[2]:lower() == lname then return entry[1] end
  end
  return 0
end

function create_cdt_file(metadata, cdt_path, num_of_markers)
  local album = metadata.album or {}
  local tracks = metadata.tracks or {}
  local num_tracks = #tracks

  local function clean(v)
    if not v then return "" end
    return (v:gsub("[\r\n]+", " "):match("^%s*(.-)%s*$"))
  end

  local track_starts = {}
  local album_end_pos = 0
  if num_of_markers and num_of_markers > 0 then
    local _, _, last_pos = enum_project_markers(0, num_of_markers - 1)
    album_end_pos = last_pos or 0
    for i = 0, num_of_markers - 1 do
      local _, _, raw_pos_out, _, name_out = enum_project_markers(0, i)
      if name_out:find("^#") then
        track_starts[#track_starts + 1] = raw_pos_out
      end
    end
  end

  local function pos_to_mmssff(pos_seconds)
    local samples = math.floor((pos_seconds or 0) * 44100)
    local nfr = math.floor(samples / 588)
    if samples % 588 ~= 0 then nfr = nfr + 1 end
    local ff = nfr % 75
    nfr = math.floor(nfr / 75)
    local ss = nfr % 60
    nfr = math.floor(nfr / 60)
    if nfr > 99 then nfr = 99 end
    return nfr, ss, ff
  end

  local PACK_TYPES = {
    { 0x80, "title" },
    { 0x81, "performer" },
    { 0x82, "songwriter" },
    { 0x83, "composer" },
    { 0x84, "arranger" },
    { 0x85, "message" },
    { 0x86, "identification" },
    { 0x87, "genre" },
  }

  local function album_field(field)
    return clean(album[field])
  end

  local function track_field(track_number, field)
    return clean(tracks[track_number][field])
  end

  local out = {}
  local serial = 0
  local num_packs_by_type = {}
  for i = 0, 15 do num_packs_by_type[i] = 0 end

  for _, entry in ipairs(PACK_TYPES) do
    local pack_type, field = entry[1], entry[2]
    if pack_type == 0x80 or album_field(field) ~= "" then
      local max_track = (pack_type == 0x87 or pack_type == 0x86) and 0 or num_tracks
      local track_number = 0
      local char_pos = 0

      while track_number <= max_track do
        local pack = {}
        for i = 1, 18 do pack[i] = 0 end
        pack[1] = pack_type
        pack[2] = track_number & 0x7F
        pack[3] = serial & 0xFF
        serial = (serial + 1) & 0xFFFF
        pack[4] = math.min(char_pos, 15)

        local text_ofs = 0
        if pack_type == 0x87 and char_pos == 0 then
          local code = genre_code_for_name(album_field("genre"))
          pack[5] = (code >> 8) & 0xFF
          pack[6] = code & 0xFF
          text_ofs = 2
        end

        local c = text_ofs
        while c < 12 do
          if track_number > max_track then break end
          local text = (track_number == 0) and album_field(field) or track_field(track_number, field)
          local ch = text:byte(char_pos + 1) or 0
          pack[5 + c] = ch
          if ch == 0 or char_pos >= 255 then
            track_number = track_number + 1
            char_pos = 0
          else
            char_pos = char_pos + 1
          end
          c = c + 1
        end

        local header = string.char(table.unpack(pack, 1, 16))
        local crc = crc_ccitt(header)
        pack[17] = (crc >> 8) & 0xFF
        pack[18] = crc & 0xFF

        num_packs_by_type[pack_type - 0x80] = num_packs_by_type[pack_type - 0x80] + 1
        out[#out + 1] = string.char(table.unpack(pack, 1, 18))
      end
    end
  end

  do
    local track_number = 0
    local char_pos = 0

    while track_number <= num_tracks do
      local pack = {}
      for i = 1, 18 do pack[i] = 0 end
      pack[1] = 0x88
      pack[2] = track_number & 0x7F
      pack[3] = serial & 0xFF
      serial = (serial + 1) & 0xFFFF
      pack[4] = math.min(char_pos, 15)

      local limit_text_len = -1
      local staging
      local c = 0
      while c < 12 do
        pack[5 + c] = 0
        if track_number <= num_tracks then
          if char_pos == 0 then
            if track_number == 0 then
              staging = { 1, num_tracks, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
              local mm, ss, ff = pos_to_mmssff(album_end_pos)
              staging[4], staging[5], staging[6] = mm, ss, ff
              limit_text_len = 12
            else
              local mm, ss, ff = pos_to_mmssff(track_starts[track_number])
              staging = { mm, ss, ff }
              limit_text_len = 3
            end
          end
          pack[5 + c] = staging[char_pos + 1] or 0
          if limit_text_len > 0 and char_pos + 1 >= limit_text_len then
            track_number = track_number + 1
            char_pos = 0
          else
            char_pos = char_pos + 1
          end
        end
        c = c + 1
      end

      local header = string.char(table.unpack(pack, 1, 16))
      local crc = crc_ccitt(header)
      pack[17] = (crc >> 8) & 0xFF
      pack[18] = crc & 0xFF

      num_packs_by_type[0x08] = num_packs_by_type[0x08] + 1
      out[#out + 1] = string.char(table.unpack(pack, 1, 18))
    end
  end

  do
    local language_code = language_code_for_name(album_field("language"))
    local track_number = 0
    local char_pos = 0

    while track_number <= 2 do
      local pack = {}
      for i = 1, 18 do pack[i] = 0 end
      pack[1] = 0x8F
      pack[2] = track_number & 0x7F
      pack[3] = serial & 0xFF
      serial = (serial + 1) & 0xFFFF
      pack[4] = math.min(char_pos, 15)

      local limit_text_len = -1
      local staging
      local c = 0
      while c < 12 do
        pack[5 + c] = 0
        if track_number <= 2 then
          if char_pos == 0 then
            limit_text_len = 12
            staging = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
            if track_number == 0 then
              staging[2] = 1
              staging[3] = num_tracks
              for i = 0, 7 do staging[5 + i] = num_packs_by_type[i] end
            elseif track_number == 1 then
              for i = 0, 6 do staging[1 + i] = num_packs_by_type[8 + i] end
              staging[8] = num_packs_by_type[15] + 2
              staging[9] = serial & 0xFF
            else
              staging[5] = language_code
            end
          end
          pack[5 + c] = staging[char_pos + 1] or 0
          if char_pos + 1 >= limit_text_len then
            track_number = track_number + 1
            char_pos = 0
          else
            char_pos = char_pos + 1
          end
        end
        c = c + 1
      end

      local header = string.char(table.unpack(pack, 1, 16))
      local crc = crc_ccitt(header)
      pack[17] = (crc >> 8) & 0xFF
      pack[18] = crc & 0xFF

      num_packs_by_type[0x0F] = num_packs_by_type[0x0F] + 1
      out[#out + 1] = string.char(table.unpack(pack, 1, 18))
    end
  end

  local f = io.open(cdt_path, "wb")
  if f then
    f:write(table.concat(out))
    f:close()
  end
end

function format_time(pos_out)
  local samples = math.floor(pos_out * 44100)
  local nfr = math.floor(samples / 588)
  if samples % 588 ~= 0 then nfr = nfr + 1 end
  local frames = nfr % 75
  nfr = math.floor(nfr / 75)
  local seconds = nfr % 60
  nfr = math.floor(nfr / 60)
  local minutes = nfr
  if minutes > 99 then minutes = 99 end
  return string.format("%02d:%02d:%02d", minutes, seconds, frames)
end

function parse_cue_file(cueFilePath, albumLength, num_of_markers)
  local file = io.open(cueFilePath, "r")

  if not file then
    return
  end

  local albumTitle, albumPerformer
  local tracks = {}

  local currentTrack = {}

  for line in file:lines() do
    if line:find("^TITLE") then
      albumTitle = line:match('"([^"]+)"')
    elseif line:find("^PERFORMER") then
      albumPerformer = line:match('"([^"]+)"')
    elseif line:find("^%s+TRACK") then
      currentTrack = {
        number = tonumber(line:match("(%d+)")),
      }
    elseif line:find("^%s+PERFORMER") then
      currentTrack.performer = line:match('"([^"]+)"')
    elseif line:find("^%s+TITLE") then
      currentTrack.title = line:match('"([^"]+)"')
    elseif line:find("^%s+ISRC") then
      currentTrack.isrc = line:match("ISRC%s+(%S+)")
    elseif line:find("^%s+INDEX 01") then
      local mm, ss, ff = line:match("(%d+):(%d+):(%d+)")
      currentTrack.mm = tonumber(mm)
      currentTrack.ss = tonumber(ss)
      currentTrack.ff = tonumber(ff)
      table.insert(tracks, currentTrack)
    end
  end

  file:close()

  tracks = add_pregaps_to_table(tracks, num_of_markers)

  table.sort(tracks, function(a, b)
    return (a.mm * 60 + a.ss + a.ff / 75) < (b.mm * 60 + b.ss + b.ff / 75)
  end)

  for i = 2, #tracks do
    local secondTimeString = string.format("%02d:%02d:%02d", tracks[i].mm, tracks[i].ss, tracks[i].ff)
    local firstTimeString = string.format("%02d:%02d:%02d", tracks[i - 1].mm, tracks[i - 1].ss, tracks[i - 1].ff)
    tracks[i - 1].length = subtract_time_strings(secondTimeString, firstTimeString)
  end

  if #tracks > 0 then
    local firstTimeString = string.format("%02d:%02d:%02d", tracks[#tracks].mm, tracks[#tracks].ss, tracks[#tracks].ff)
    tracks[#tracks].length = subtract_time_strings(albumLength, firstTimeString)
  end

  return albumTitle, albumPerformer, tracks
end

function create_plaintext_report(albumTitle, albumPerformer, tracks, txtOutputPath, albumLength, catalog_number,
                                 production_year)
  local file = io.open(txtOutputPath, "w")

  if not file then
    return
  end

  local date = os.date("*t")
  local hour = date.hour % 12
  hour = hour == 0 and 12 or hour
  local ampm = date.hour >= 12 and "PM" or "AM"
  local formattedDate = string.format("%d/%02d/%d %d:%02d%s", date.day, date.month, date.year, hour, date.min, ampm)
  file:write("Generated by ReaClassical (" .. formattedDate .. ")\n\n")
  file:write("Album: ", (albumTitle or "") .. "\n")
  file:write("Year: ", (production_year or "") .. "\n")
  file:write("Album Performer: ", (albumPerformer or "") .. "\n")

  if catalog_number ~= "" then
    file:write("UPC/EAN: ", (catalog_number or "") .. "\n\n")
  else
    file:write("\n")
  end

  file:write("-----------------------------\n")
  file:write("Total Running Time: " .. format_album_length(albumLength) .. "\n")
  file:write("-----------------------------\n\n")

  local rows = {}
  local number_w, start_w, length_w, title_w = 0, 0, 0, 0

  for _, track in ipairs(tracks or {}) do
    local number = track.title == "pregap" and "p" or string.format("%02d", track.number or 0)
    local title = track.title == "pregap" and "" or (track.title or "")
    title = title:match("^[!]*([^|]*)")

    local start_str = round_mmss(track.mm or 0, track.ss or 0, track.ff or 0)
    local length_str = track.length and round_mmssff_string(track.length) or ""

    number_w = math.max(number_w, #number)
    start_w = math.max(start_w, #start_str)
    length_w = math.max(length_w, #length_str)
    title_w = math.max(title_w, #title)

    rows[#rows + 1] = {
      number = number,
      start_str = start_str,
      length_str = length_str,
      title = title,
      isrc = track.isrc
    }
  end

  local has_isrc = any_isrc_present(rows)

  for _, row in ipairs(rows) do
    local line = string.format("%-" .. number_w .. "s | %-" .. start_w .. "s | %-" .. length_w .. "s",
      row.number, row.start_str, row.length_str)

    if row.title == "" then
      line = line .. " |"
    else
      line = line .. " | " .. string.format("%-" .. title_w .. "s", row.title)
      if has_isrc then
        line = line .. " | " .. (row.isrc or "")
      end
      if row.title ~= "" then
        line = line .. " "
      end
    end

    file:write(line .. "\n")
  end

  file:close()
end

function create_html_report(albumTitle, albumPerformer, tracks, htmlOutputPath, albumLength, catalog_number,
                            production_year)
  local file = io.open(htmlOutputPath, "w")

  if not file then
    return
  end

  file:write("<html>\n<head>\n")
  file:write("<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=Barlow:wght@200&display=swap'>\n")
  file:write(
    "<link rel='stylesheet' href='https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css'>\n")
  file:write("<style>\n")
  file:write("  .greenlabel {\n    color: #a0c96d;\n  }\n")
  file:write("  .redlabel {\n    color: #ff6961;\n  }\n")
  file:write("  .bluelabel {\n    color: #6fb8df;\n  }\n")
  file:write("  .greylabel {\n    color: #757575;\n  }\n")
  file:write("body {\n")
  file:write("  padding: 20px;\n")
  file:write("  font-family: 'Barlow', sans-serif;\n")
  file:write("}\n")
  file:write(".container {\n")
  file:write("  margin-top: 20px;\n")
  file:write("}\n")
  file:write("table {\n")
  file:write("  margin-top: 20px;\n")
  file:write("}\n")
  file:write("table {\n")
  file:write("  margin-top: 20px;\n")
  file:write("}\n")
  file:write("</style>\n</head>\n<body>\n")

  local date = os.date("*t")
  local hour = date.hour % 12
  hour = hour == 0 and 12 or hour
  local ampm = date.hour >= 12 and "PM" or "AM"
  local formattedDate = string.format("%d/%02d/%d %d:%02d%s", date.day, date.month, date.year, hour, date.min, ampm)
  file:write("<div class='container'>\n")
  file:write("  <h3><span class='greylabel'>Generated by ReaClassical (" .. formattedDate .. ")</span></h2>\n\n")
  file:write("  <h2><span class='greenlabel'>Album:</span> ", (albumTitle or ""), "</h3>\n")
  file:write("  <h2><span class='redlabel'>Year:</span> ", (production_year or ""), "</h3>\n")
  file:write("  <h2><span class='bluelabel'>Album Performer:</span> ", (albumPerformer or ""), "</h3>\n")

  if catalog_number ~= "" then
    file:write("  <h2><span class='greenlabel'>UPC/EAN:</span> ", catalog_number, "</h3>\n")
  end

  file:write("  <h2><span class='bluelabel'>Total Running Time:</span> " .. format_album_length(albumLength) .. "</h3>\n\n")

  file:write("  <table class='table table-striped'>\n")
  file:write("    <thead class='thead-light'>\n")
  file:write("      <tr>\n")
  file:write("        <th>Track</th>\n")
  file:write("        <th>Start</th>\n")
  file:write("        <th>Length</th>\n")
  file:write("        <th>Title</th>\n")
  if any_isrc_present(tracks) then
    file:write("        <th>ISRC</th>\n")
  end
  file:write("      </tr>\n")
  file:write("    </thead>\n")
  file:write("    <tbody>\n")

  for _, track in ipairs(tracks or {}) do
    track.number = track.title == "pregap" and "p" or tostring(track.number or "")
    track.title = track.title == "pregap" and "" or (track.title or "")

    track.title = track.title:match("^[!]*([^|]*)")

    file:write("      <tr>\n")
    file:write("        <td>" .. track.number .. "</td>\n")
    file:write("        <td>" ..
      round_mmss(track.mm or 0, track.ss or 0, track.ff or 0) .. "</td>\n")
    file:write("        <td>" .. (track.length and round_mmssff_string(track.length) or "") .. "</td>\n")
    file:write("        <td>" .. (track.title or "") .. "</td>\n")
    if any_isrc_present(tracks) then
      file:write("        <td>" .. (track.isrc or "") .. "</td>\n")
    end
    file:write("      </tr>\n")
  end

  file:write("    </tbody>\n")
  file:write("  </table>\n")
  file:write("</div>\n</body>\n</html>")

  file:close()
end

function any_isrc_present(tracks)
  for _, track in ipairs(tracks or {}) do
    if track.isrc then
      return true
    end
  end
  return false
end

function time_to_mmssff(timeString)
  local minutes, seconds, frames = timeString:match("(%d+):(%d+):(%d+)")
  return tonumber(minutes), tonumber(seconds), tonumber(frames)
end

local function round_seconds(mm, ss, ff)
  if ff >= 38 then
    ss = ss + 1
    if ss >= 60 then
      ss = 0
      mm = mm + 1
    end
  end
  return mm, ss
end

function round_mmss(mm, ss, ff)
  local rmm, rss = round_seconds(mm, ss, ff)
  return string.format("%d:%02d", rmm, rss)
end

function format_album_length(timeString)
  local mm, ss, ff = time_to_mmssff(timeString)
  mm, ss = round_seconds(mm, ss, ff)
  if mm >= 60 then
    local hh = math.floor(mm / 60)
    mm = mm % 60
    return string.format("%d:%02d:%02d", hh, mm, ss)
  end
  return string.format("%d:%02d", mm, ss)
end

function round_mmssff_string(timeString)
  local mm, ss, ff = time_to_mmssff(timeString)
  return round_mmss(mm, ss, ff)
end

function subtract_time_strings(timeString1, timeString2)
  local minutes1, seconds1, frames1 = time_to_mmssff(timeString1)
  local minutes2, seconds2, frames2 = time_to_mmssff(timeString2)

  local totalFrames1 = frames1 + seconds1 * 75 + minutes1 * 60 * 75
  local totalFrames2 = frames2 + seconds2 * 75 + minutes2 * 60 * 75

  local differenceFrames = totalFrames1 - totalFrames2

  local minutesResult = math.floor(differenceFrames / 75 / 60)
  local secondsResult = math.floor(differenceFrames / 75) % 60
  local framesResult = differenceFrames % 75

  local paddedMinutes = string.format("%02d", minutesResult)
  local paddedSeconds = string.format("%02d", secondsResult)
  local paddedFrames = string.format("%02d", framesResult)

  return paddedMinutes .. ":" .. paddedSeconds .. ":" .. paddedFrames
end

function add_pregaps_to_table(tracks, num_of_markers)
  local pregap
  for i = 0, num_of_markers - 1 do
    local _, _, raw_pos_out, _, name_out = enum_project_markers(0, i)
    if string.sub(name_out, 1, 1) == "!" then
      local formatted_pos_out = format_time(raw_pos_out)
      local mm, ss, ff = formatted_pos_out:match("(%d+):(%d+):(%d+)")
      pregap = {
        title = "pregap",
        mm = tonumber(mm),
        ss = tonumber(ss),
        ff = tonumber(ff)
      }
      table.insert(tracks, pregap)
    end
  end
  return tracks
end

main()
