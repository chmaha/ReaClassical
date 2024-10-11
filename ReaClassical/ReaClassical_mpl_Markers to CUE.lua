--[[
@noindex

mpl Generate CUE from project markers

chmaha 04.04.23 changelog:
  Remove dependency on mpl_Various_functions.lua
  CUE format correction: Use "WAV" for WavPack, FLAC etc (still allowing for MP3 and AIFF as alternative formats).
  Use current year in dialog box
  Extend width of dialog box for better visibility
  Automatically use project name as part of audio file and cue file naming
  Force saving of project before use (for project name usage)
  Use project path as default for saving .cue file
  Use ShowMessageBox in case of file-writing error before showing console message for copy/paste
  Move file-saving to its own function
  General switch to snake_case where possible
  Switch to using local variables
  Other small typographical changes

chmaha 05.04.23 changelog:
  Simplify main() with separate functions
  Remove superfluous code
  Add pairs(reaper) code

chmaha 24Q1pre changelog:
  Add ISRC to CUE file when present
  Ensure album metadata is surrounded by quotation marks
  Add CATALOG to top of CUE file if present in the album metadata @ marker
  Generate album reports in plaintext and html
  Use snake_case for new function names
  Add quotation marks around generated filename on successful message to user
  Add pregap information
  Correct calculation of final track duration when preceeded by a pregap
  Use DDP @ album metadata if available
  Use saved year if available
  Add REM line about ReaClassical
  Add INDEX 00 lines if present in project
  Remove pattern match function and use :find() inline
  Fix slash path match
  Remove superfluous quotes
  Allow for RPP and rpp as the extension (REAPER on Windows is lowercase)
]]

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, count_markers, create_filename, get_data, create_string
local ext_mod, save_file, save_metadata, format_time, parse_cue_file
local create_plaintext_report, create_html_report, any_isrc_present
local time_to_mmssff, subtract_time_strings, add_pregaps_to_table
local formatted_pos_out

----------------------------------------------------------

function main()
    local ret1, num_of_markers = count_markers()
    if not ret1 then return end
    local ret2, filename = create_filename()
    if not ret2 then return end
    local ret3, fields, extension = get_data(filename)
    if not ret3 then return end
    local string, catalog_number, album_length = create_string(fields, num_of_markers, extension)
    local path, slash, cue_file = save_file(fields, string)

    local txtOutputPath = path .. slash .. 'album_report.txt'
    local HTMLOutputPath = path .. slash .. 'album_report.html'
    local albumTitle, albumPerformer, tracks = parse_cue_file(cue_file, album_length, num_of_markers)
    if albumTitle and albumPerformer and #tracks > 0 then
        create_plaintext_report(albumTitle, albumPerformer, tracks, txtOutputPath, album_length, catalog_number)
        create_html_report(albumTitle, albumPerformer, tracks, HTMLOutputPath, album_length, catalog_number)
    end
    ShowMessageBox(
        "Album reports have been generated in the root project folder.\nCUE file written to \"" .. cue_file .. "\"",
        "Create CUE file", 0)
end

----------------------------------------------------------

function count_markers()
    local num_of_markers = CountProjectMarkers(0)
    if num_of_markers == 0 then
        ShowMessageBox('Please use "Create CD Markers script" first', "Create CUE file", 0)
        return false
    end
    return true, num_of_markers
end

----------------------------------------------------------

function create_filename()
    local full_project_name = GetProjectName(0)
    if full_project_name == "" then
        ShowMessageBox("Please save your project first!", "Create CUE file", 0)
        return false
    else
        return true, full_project_name:match("^(.+)[.].*$")
    end
end

----------------------------------------------------------

function get_data(filename)
    local this_year = os.date("%Y")

    local _, ddp_metadata = GetProjExtState(0, "ReaClassical", "AlbumMetadata")
    local _, metadata_saved = GetProjExtState(0, "ReaClassical", "CUEMetadata")

    local ret, user_inputs
    if ddp_metadata ~= "" then
        local ddp_metadata_table = {}
        for value in ddp_metadata:gmatch("[^,]+") do
            table.insert(ddp_metadata_table, value)
        end

        if metadata_saved ~= "" then
            local saved_metadata_table = {}
            for value in metadata_saved:gmatch("[^,]+") do
                table.insert(saved_metadata_table, value)
            end

            ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
                'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
                ddp_metadata_table[4] ..
                ',' ..
                saved_metadata_table[2] ..
                ',' .. ddp_metadata_table[2] .. ',' .. ddp_metadata_table[1] .. ',' .. saved_metadata_table[5])
        else
            ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
                'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
                ddp_metadata_table[4] ..
                ',' ..
                this_year .. ',' .. ddp_metadata_table[2] .. ',' .. ddp_metadata_table[1] .. ',' .. filename .. '.wav')
        end
    else
        if metadata_saved ~= "" then
            ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
                'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
                metadata_saved)
        else
            ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
                'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
                'Classical,' .. this_year .. ',Performer,My Classical Album,' .. filename .. '.wav')
        end
    end

    if not ret then return end

    local fields = {}
    for word in user_inputs:gmatch('[^%,]+') do fields[#fields + 1] = word end
    if #fields ~= 5 then
        ShowMessageBox('Sorry. Empty fields not supported.', "Create CUE file", 0)
        return false
    end
    local extension = fields[5]:match('%.([a-zA-Z0-9]+)$')
    if not extension then
        ShowMessageBox('Please enter filename with an extension', "Create CUE file", 0)
        return false
    end
    save_metadata(user_inputs)
    return true, fields, extension:upper()
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
            local has_isrc_code = name_out:find("ISRC")
            local isrc_code = name_out:match('ISRC=([%w%d]+)') or ""
            if has_isrc_code then
                name_out = name_out:match(('#(.*)|'))
            else
                name_out = name_out:match(('#(.*)'))
            end
            local formatted_time = format_time(raw_pos_out)

            local perf = fields[3]

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

function save_file(fields, out_str)
    local _, path = EnumProjects(-1)
    local slash = package.config:sub(1, 1)
    if path == "" then
        path = GetProjectPath()
    else
        local pattern = "(.+)" .. slash .. ".+[.][Rr][Pp][Pp]"
        path = path:match(pattern)
    end
    local file = path .. slash .. fields[5]:match('^(.+)[.].+') .. '.cue'
    local f = io.open(file, 'w')
    if f then
        f:write(out_str)
        f:close()
    else
        ShowMessageBox(
            "There was an error creating the file. " ..
            "Copy and paste the contents of the following console window to a new .cue file.",
            "Create CUE file", 0)
        ShowConsoleMsg(out_str)
    end
    return path, slash, file
end

----------------------------------------------------------

function save_metadata(user_inputs)
    SetProjExtState(0, "ReaClassical", "CUEMetadata", user_inputs)
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

function create_plaintext_report(albumTitle, albumPerformer, tracks, txtOutputPath, albumLength, catalog_number)
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

function create_html_report(albumTitle, albumPerformer, tracks, htmlOutputPath, albumLength, catalog_number)
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
            formatted_pos_out = format_time(raw_pos_out)
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
