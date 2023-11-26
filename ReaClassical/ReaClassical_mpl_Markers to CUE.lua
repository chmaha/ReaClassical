--[[
@noindex

mpl Generate CUE from project markers

chmaha 04.04.23 changelog:
  Remove dependency on mpl_Various_functions.lua
  CUE format correction: Use "WAV" for WavPack, FLAC etc (still allowing for MP3 and AIFF as alternative formats). See http://wiki.hydrogenaud.io/index.php?title=Cue_sheet#Cue_sheet_commands and http://github.com/libyal/libodraw/blob/main/documentation/CUE%20sheet%20format.asciidoc#271-file-types
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

]]

for key in pairs(reaper) do _G[key] = reaper[key] end

----------------------------------------------------------

function main()
    local ret, num_of_markers = count_markers()
    if not ret then return end
    local ret, filename = create_filename()
    if not ret then return end
    local ret, fields, extension = get_data(filename)
    if not ret then return end
    local string, catalog_number, album_length = create_string(fields, num_of_markers, extension)
    path, slash, cue_file = save_file(fields, string)

    local txtOutputPath = path .. slash .. 'album_report.txt'
    local HTMLOutputPath = path .. slash .. 'album_report.html'
    local albumTitle, albumPerformer, tracks = parseCueFile(cue_file, album_length)
    if albumTitle and albumPerformer and #tracks > 0 then 
        createPlainTextReport(albumTitle, albumPerformer, tracks, txtOutputPath, album_length, catalog_number)
        createHTMLReport(albumTitle, albumPerformer, tracks, HTMLOutputPath, album_length, catalog_number)
	end
    ShowMessageBox("Album report generated in the root project folder. CUE file written to " .. cue_file, "Create CUE file", 0)
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

    local _, metadata_saved = GetProjExtState(0, "Markers to CUE", "Metadata")
    local ret, user_inputs, metadata_table
    if metadata_saved ~= "" then
        ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
            'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
            metadata_saved)
    else
        ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
            'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
            'Classical,' .. this_year .. ',Performer,My Classical Album,' .. filename .. '.wav')
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
    
    local _, _, raw_pos_out, _, name_out = EnumProjectMarkers2(0, num_of_markers - 1)
    album_length = format_time(raw_pos_out)
    local _, _, _, _, album_meta = EnumProjectMarkers2(0, num_of_markers - 2)
    catalog_number = album_meta:match('CATALOG=([%w%d]+)') or ""
    local out_str = ""
    
    if catalog_number ~= "" then
        out_str =
          'REM GENRE ' .. fields[1] ..
          '\nREM DATE ' .. fields[2] ..
          '\nREM ALBUM_LENGTH ' .. album_length ..
          '\nCATALOG ' .. catalog_number ..
          '\nPERFORMER ' .. '"' .. fields[3] .. '"' ..
          '\nTITLE ' .. '"' .. fields[4] .. '"' ..
          '\nFILE ' .. '"' .. fields[5] .. '"' .. ' ' .. format .. '\n'
    else
       out_str =
         'REM GENRE ' .. fields[1] ..
         '\nREM DATE ' .. fields[2] ..
         '\nREM ALBUM_LENGTH ' .. album_length ..
         '\nPERFORMER ' .. '"' .. fields[3] .. '"' ..
         '\nTITLE ' .. '"' .. fields[4] .. '"' ..
         '\nFILE ' .. '"' .. fields[5] .. '"' .. ' ' .. format .. '\n'
    end
    
    local ind3 = '   '
    local ind5 = '     '

    local marker_id = 1
    for i = 0, num_of_markers - 1 do
        local _, _, raw_pos_out, _, name_out = EnumProjectMarkers2(0, i)
        if pattern_match(name_out) ~= '#'
        then
            goto skip_to_next
        end
        local has_isrc_code = name_out:find("ISRC")
        local isrc_code = name_out:match('ISRC=([%w%d]+)') or ""
        if has_isrc_code then 
          name_out = name_out:match(('#(.*)|'))
        else
          name_out = name_out:match(('#(.*)'))
        end
        formatted_pos_out = format_time(raw_pos_out)
        
        local perf = fields[3]
        

        local id = ("%02d"):format(marker_id)
        marker_id = marker_id + 1
        if name_out == nil or name_out == '' then name_out = 'Untitled' end
        
        if isrc_code ~= "" then
        out_str = out_str .. ind3 .. 'TRACK ' .. id .. ' AUDIO' .. '\n' ..
            ind5 .. 'TITLE ' .. '"' .. name_out .. '"' .. '\n' ..
            ind5 .. 'PERFORMER ' .. '"' .. perf .. '"' .. '\n' ..
            ind5 .. 'ISRC ' .. isrc_code .. '\n' ..
            ind5 .. 'INDEX 01 ' .. formatted_pos_out .. '\n'
        else
        out_str = out_str .. ind3 .. 'TRACK ' .. id .. ' AUDIO' .. '\n' ..
            ind5 .. 'TITLE ' .. '"' .. name_out .. '"' .. '\n' ..
            ind5 .. 'PERFORMER ' .. '"' .. perf .. '"' .. '\n' ..
            ind5 .. 'INDEX 01 ' .. formatted_pos_out .. '\n'
        end
        ::skip_to_next::
    end
    
    return out_str, catalog_number, album_length
end

----------------------------------------------------------

function pattern_match(name_out)
    return name_out:gsub('%s', ''):sub(0, 1)
end

----------------------------------------------------------

function ext_mod(extension)
    local list = { "AIFF", "MP3" }
    for _, v in pairs(list) do
        if extension == v then
            return extension
        end
    end
    return "WAV"
end

----------------------------------------------------------

function save_file(fields, out_str)
    local _, path = EnumProjects(-1, "")
    if path == "" then
        path = GetProjectPath("")
    else
        path = path:match("(.+)/.+[.]RPP")
    end
    local os = GetOS()
    local slash = "/"
    if os:match("Win.+") then
        slash = "\\"
    end
    local file = path .. slash .. fields[5]:match('^(.+)[.].+') .. '.cue'
    local f = io.open(file, 'w')
    if f then
        f:write(out_str)
        f:close()
    else
        ShowMessageBox(
            "There was an error creating the file. Copy and paste the contents of the following console window to a new .cue file.",
            "Create CUE file", 0)
        ShowConsoleMsg(out_str)
    end
    return path, slash, file
end

----------------------------------------------------------

function save_metadata(user_inputs)
    SetProjExtState(0, "Markers to CUE", "Metadata", user_inputs)
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

function parseCueFile(cueFilePath, albumLength)
    local file = io.open(cueFilePath, "r")

    if not file then
        return
    end

    local albumTitle, albumPerformer
    local tracks = {}

    local currentTrack = {}  -- Track being processed

    for line in file:lines() do
        if line:find("^TITLE") then
            albumTitle = line:match('"([^"]+)"')
        elseif line:find("^PERFORMER") then
            albumPerformer = line:match('"([^"]+)"')
        elseif line:find("^%s+TRACK") then
            currentTrack = {
                number = tonumber(line:match("(%d+)")),
                --performer = albumPerformer,  -- Added this line to include performer information
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
    
    for i = 2, #tracks do
    	local secondTimeString = string.format("%02d:%02d:%02d", tracks[i].mm, tracks[i].ss, tracks[i].ff)
        local firstTimeString = string.format("%02d:%02d:%02d", tracks[i - 1].mm, tracks[i - 1].ss, tracks[i - 1].ff)
        tracks[i-1].length = subtractTimeStrings(secondTimeString, firstTimeString)
    end
    
    -- Deal with final track length based on album length
    local firstTimeString = string.format("%02d:%02d:%02d", tracks[#tracks-1].mm, tracks[#tracks-1].ss, tracks[#tracks-1].ff)
    tracks[#tracks].length = subtractTimeStrings(albumLength, firstTimeString)  
	
    return albumTitle, albumPerformer, tracks
end

-----------------------------------------------------------------

function createPlainTextReport(albumTitle, albumPerformer, tracks, txtOutputPath, albumLength, catalog_number)
    local file = io.open(txtOutputPath, "w")

    if not file then
        return
    end

    -- Write album information
    local formattedDate = os.date("%d/%m/%Y %I:%M%p")
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
    -- Write track information
    for _, track in ipairs(tracks or {}) do
    	local isrcSeparator = track.isrc and " | " or ""
    	--local perfSeparator = track.performer and " | " or ""
        file:write(string.format("%02d | %02d:%02d:%02d | %s | %s%s%s \n",
            track.number or 0, track.mm or 0, track.ss or 0, track.ff or 0, track.length, track.title or "", isrcSeparator, track.isrc or "" ))
    end

    file:close()
end

-----------------------------------------------------------------

function createHTMLReport(albumTitle, albumPerformer, tracks, htmlOutputPath, albumLength, catalog_number)
    local file = io.open(htmlOutputPath, "w")

    if not file then
        return
    end

    -- Write HTML header
    file:write("<html>\n<head>\n<style>\n")
    file:write("table {\n  font-family: Arial, sans-serif;\n  border-collapse: collapse;\n  width: auto;\n}\n")
    file:write("th, td {\n  border: 1px solid #dddddd;\n  text-align: left;\n  padding: 8px;\n}\n")
    file:write("th {\n  background-color: #f2f2f2;\n}\n</style>\n</head>\n<body>\n")

    -- Write album information
    local formattedDate = os.date("%d/%m/%Y %I:%M%p")
    file:write("<h2>Generated by ReaClassical (" .. formattedDate .. ")</h2>\n\n")
    file:write("<h3>Album: ", (albumTitle or ""), "</h3>")
    file:write("<h3>Album Performer: ", (albumPerformer or ""), "</h3>\n")
    
    if catalog_number ~= "" then
        file:write("<h3>UPC/EAN: ", catalog_number, "</h3>\n")
    end
    
    file:write("<h3>Total Running Time: " .. albumLength .. "</h3>\n\n")

    -- Write track information as HTML table
    file:write("<table>\n<tr>\n<th>Track</th>\n<th>Start</th>\n<th>Length</th>\n<th>Title</th>")
    if anyISRCPresent(tracks) then
        file:write("<th>ISRC</th>")
    end
    file:write("</tr>\n")

    for _, track in ipairs(tracks or {}) do
        local isrcSeparator = track.isrc and " | " or ""
        file:write(string.format("<tr>\n<td>%02d</td>\n<td>%02d:%02d:%02d</td>\n<td>%s</td>\n<td>%s</td>\n",
            track.number or 0, track.mm or 0, track.ss or 0, track.ff or 0, track.length or "", track.title or ""))
        if anyISRCPresent(tracks) then
            file:write(string.format("<td>%s</td>\n", track.isrc or ""))
        end
        file:write("</tr>\n")
    end

    file:write("</table>\n</body>\n</html>")

    file:close()
end

-----------------------------------------------------------------

function anyISRCPresent(tracks)
    for _, track in ipairs(tracks or {}) do
        if track.isrc then
            return true
        end
    end
    return false
end

-----------------------------------------------------------------

function timeToMinutesSecondsFrames(timeString)
    local minutes, seconds, frames = timeString:match("(%d+):(%d+):(%d+)")
    return tonumber(minutes), tonumber(seconds), tonumber(frames)
end

-----------------------------------------------------------------

function subtractTimeStrings(timeString1, timeString2)
    local minutes1, seconds1, frames1 = timeToMinutesSecondsFrames(timeString1)
    local minutes2, seconds2, frames2 = timeToMinutesSecondsFrames(timeString2)

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

main()
