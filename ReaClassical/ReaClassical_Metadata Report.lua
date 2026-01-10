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
local create_html_report, any_isrc_present, time_to_mmssff, subtract_time_strings
local add_pregaps_to_table

---------------------------------------------------------------------

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
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
    return
  end

  local metadata, error_msg = parse_markers()
  if error_msg ~= "" then
    MB(error_msg, "", 0)
  end

  local track = get_track_color_from_marker()
  local metadata_file
  local prefix = ""
  if track then
    local _, track_name = GetTrackName(track)
    metadata_file, prefix = get_txt_file(track_name)
    write_rcmeta_file(metadata_file, metadata)
  end

  local ret1, num_of_markers = count_markers()
  if not ret1 then return end
  local ret2, filename = create_filename()
  if not ret2 then return end
  local fields, extension, production_year = create_cue_entries(filename, metadata)

  local string, catalog_number, album_length = create_string(fields, num_of_markers, extension)
  local path, slash, cue_file = save_cue_file(fields, string, prefix)

  local txtOutputPath = path .. slash .. prefix .. 'album_report.txt'
  local HTMLOutputPath = path .. slash .. prefix .. 'album_report.html'
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
end

---------------------------------------------------------------------

function parse_markers()
  local num_markers = CountProjectMarkers(0)
  local metadata = { album = {}, tracks = {} }
  local error_msg = ""

  -- First pass: Extract album-wide metadata
  for i = 0, num_markers - 1 do
    local _, isrgn, _, _, name, _ = EnumProjectMarkers(i)
    if not isrgn then -- Only process markers
      local album_marker = name:match("^@(.-)|")
      if album_marker then
        metadata.album = {
          title = album_marker,
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
        break -- Stop early after finding album metadata
      end
    end
  end

  -- Second pass: Process track markers
  for i = 0, num_markers - 1 do
    local _, isrgn, _, _, name, _ = EnumProjectMarkers(i)
    if not isrgn then              -- Only process markers
      if not name:match("^@") then -- Ignore album line since it's already processed
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

          -- Assign error message to error_msg variable
          if missing_album_metadata then
            error_msg = "Note: One or more tracks specify " ..
                "performer, songwriter, composer, or arranger\n" ..
                "without an associated album-wide entry and " ..
                "therefore won't currently be added to the DDP metadata."
          end

          table.insert(metadata.tracks, track_data)
        end
      end
    end
  end

  return metadata, error_msg
end

---------------------------------------------------------------------

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
    -- file:write("First Track Number  = 1\n")
    file:write(string.format("Total Tracks        = %d\n", #metadata.tracks))

    for i, track in ipairs(metadata.tracks) do
      local track_num = string.format("%02d", i)
      file:write(string.format("Track %s Title      = %s\n", track_num, track.title or ""))
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

---------------------------------------------------------------------

function get_txt_file(track_name)
  local _, path = EnumProjects(-1)
  local slash = package.config:sub(1, 1)
  if path == "" then
    path = GetProjectPath()
  else
    local pattern = "(.+)" .. slash .. ".+[.][Rr][Pp][Pp]"
    path = path:match(pattern)
  end

  -- Extract prefix before ':' in track_name
  local prefix_match = track_name:match("^(.-):")
  local prefix = ""
  if prefix_match then
    prefix = prefix_match .. "_"
  end

  local file = path .. slash .. prefix .. 'metadata.txt'
  return file, prefix
end

---------------------------------------------------------------------

function get_track_color_from_marker()
  local proj = 0
  local marker_count = CountProjectMarkers(proj)

  local target_color = nil

  -- Search markers via EnumProjectMarkers3
  for i = 0, marker_count - 1 do
    local retval, isrgn, _, _, name,
    markrgnindexnumber, color =
        EnumProjectMarkers3(proj, i)

    if retval ~= 0 then
      if not isrgn and markrgnindexnumber == 0 and name == "!" then
        target_color = color
        break
      end
    end
  end

  if not target_color then return nil end

  -- Find first track with matching color
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

---------------------------------------------------------------------

function count_markers()
  local num_of_markers = CountProjectMarkers(0)
  if num_of_markers == 0 then
    MB('Please use "Create CD Markers script" first', "Create CUE file", 0)
    return false
  end
  return true, num_of_markers
end

----------------------------------------------------------

function create_filename()
  local full_project_name = GetProjectName(0)
  if full_project_name == "" then
    MB("Please save your project first!", "Create CUE file", 0)
    return false
  else
    return true, full_project_name:match("^(.+)[.].*$")
  end
end

----------------------------------------------------------

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
    metadata.album.genre,
    year,
    metadata.album.performer,
    metadata.album.title,
    filename .. '.' .. extension
  }

  return fields, extension:upper(), year
end

----------------------------------------------------------

function create_string(fields, num_of_markers, extension)
  local format = ext_mod(extension)

  local _, _, album_pos_out, _, _ = EnumProjectMarkers2(0, num_of_markers - 1)
  local album_length = format_time(album_pos_out)
  local _, _, _, _, album_meta = EnumProjectMarkers2(0, num_of_markers - 2)
  local catalog_number = album_meta:match('CATALOG=([%w%d]+)') or ""
  local out_str

  if catalog_number ~= "" then
    out_str =
        'REM COMMENT "Generated by ReaClassical"' ..
        '\nREM GENRE ' .. fields[1] ..
        '\nREM DATE ' .. fields[2] ..
        '\nREM ALBUM_LENGTH ' .. album_length ..
        '\nCATALOG ' .. catalog_number ..
        '\nPERFORMER ' .. '"' .. fields[3] .. '"' ..
        '\nTITLE ' .. '"' .. fields[4] .. '"' ..
        '\nFILE ' .. '"' .. fields[5] .. '"' .. ' ' .. format .. '\n'
  else
    out_str =
        'REM COMMENT "Generated by ReaClassical"' ..
        '\nREM GENRE ' .. fields[1] ..
        '\nREM DATE ' .. fields[2] ..
        '\nREM ALBUM_LENGTH ' .. album_length ..
        '\nPERFORMER ' .. '"' .. fields[3] .. '"' ..
        '\nTITLE ' .. '"' .. fields[4] .. '"' ..
        '\nFILE ' .. '"' .. fields[5] .. '"' .. ' ' .. format .. '\n'
  end

  local ind3 = '   '
  local ind5 = '     '

  local marker_id = 1
  local is_pregap = false
  local pregap_start = ""
  for i = 0, num_of_markers - 1 do
    local _, _, raw_pos_out, _, name_out = EnumProjectMarkers2(0, i)
    if name_out:find("^#") then
      local perf = name_out:match("PERFORMER=([^|]+)")
      local isrc_code = name_out:match('ISRC=([%w%d]+)') or ""
      name_out = name_out:match("^#([^|]+)")
      local formatted_time = format_time(raw_pos_out)

      if not perf then perf = fields[3] end

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

----------------------------------------------------------

function ext_mod(extension)
  local list = { "AIFF", "MP3" }
  for _, v in pairs(list) do
    if extension == v then
      return extension
    end
  end
  return "WAVE"
end

----------------------------------------------------------

function save_cue_file(fields, out_str, prefix)
  local _, path = EnumProjects(-1)
  local slash = package.config:sub(1, 1)
  if path == "" then
    path = GetProjectPath()
  else
    local pattern = "(.+)" .. slash .. ".+[.][Rr][Pp][Pp]"
    path = path:match(pattern)
  end
  local file = path .. slash .. prefix .. fields[5]:match('^(.+)[.].+') .. '.cue'
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
  return path, slash, file
end

----------------------------------------------------------

function format_time(pos_out)
  pos_out = format_timestr_pos(pos_out, '', 5)
  local time = {}
  for num in pos_out:gmatch('[%d]+') do
    if tonumber(num) > 10 then num = tonumber(num) end
    time[#time + 1] = num
  end
  if tonumber(time[1]) > 0 then time[2] = tonumber(time[2]) + tonumber(time[1]) * 60 end
  return table.concat(time, ':', 2)
end

-----------------------------------------------------------------

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

  -- Deal with final track length based on album length
  local firstTimeString = string.format("%02d:%02d:%02d", tracks[#tracks].mm, tracks[#tracks].ss, tracks[#tracks].ff)
  tracks[#tracks].length = subtract_time_strings(albumLength, firstTimeString)

  return albumTitle, albumPerformer, tracks
end

-----------------------------------------------------------------

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
  file:write("Total Running Time: " .. albumLength .. "\n")
  file:write("-----------------------------\n\n")

  for _, track in ipairs(tracks or {}) do
    local isrcSeparator = track.isrc and " | " or ""

    track.number = track.title == "pregap" and "p" or string.format("%02d", track.number or 0)
    track.title = track.title == "pregap" and "" or track.title

    track.title = track.title:match("^[!]*([^|]*)")

    if track.title == "" then
      file:write(string.format("%-2s | %02d:%02d:%02d | %s |\n",
        track.number or "", track.mm or 0, track.ss or 0, track.ff or 0, track.length))
    else
      file:write(string.format("%-2s | %02d:%02d:%02d | %-8s | %s%s%s \n",
        track.number or "", track.mm or 0, track.ss or 0, track.ff or 0, track.length or "", track.title or "",
        isrcSeparator, track.isrc or ""))
    end
  end

  file:close()
end

-----------------------------------------------------------------

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

  file:write("  <h2><span class='bluelabel'>Total Running Time:</span> " .. albumLength .. "</h3>\n\n")

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
    track.title = track.title == "pregap" and "" or track.title

    track.title = track.title:match("^[!]*([^|]*)")

    file:write("      <tr>\n")
    file:write("        <td>" .. track.number .. "</td>\n")
    file:write("        <td>" ..
      string.format("%02d:%02d:%02d", track.mm or 0, track.ss or 0, track.ff or 0) .. "</td>\n")
    file:write("        <td>" .. (track.length or "") .. "</td>\n")
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

-----------------------------------------------------------------

function any_isrc_present(tracks)
  for _, track in ipairs(tracks or {}) do
    if track.isrc then
      return true
    end
  end
  return false
end

-----------------------------------------------------------------

function time_to_mmssff(timeString)
  local minutes, seconds, frames = timeString:match("(%d+):(%d+):(%d+)")
  return tonumber(minutes), tonumber(seconds), tonumber(frames)
end

-----------------------------------------------------------------

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

-----------------------------------------------------------------

function add_pregaps_to_table(tracks, num_of_markers)
  local pregap
  for i = 0, num_of_markers - 1 do
    local _, _, raw_pos_out, _, name_out = EnumProjectMarkers2(0, i)
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

-----------------------------------------------------------------

main()
