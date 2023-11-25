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
    local string = create_string(fields, num_of_markers, extension)
    save_file(fields, string)
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

    local out_str =
        'REM GENRE ' .. fields[1] ..
        '\nREM DATE ' .. fields[2] ..
        '\nREM ALBUM_LENGTH ' .. album_length ..
        '\nPERFORMER ' .. '"' .. fields[3] .. '"' ..
        '\nTITLE ' .. '"' .. fields[4] .. '"' ..
        '\nFILE ' .. '"' .. fields[5] .. '"' .. ' ' .. format .. '\n'

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
    
    return out_str
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
        ShowMessageBox("CUE file written to " .. file, "Create CUE file", 0)
    else
        ShowMessageBox(
            "There was an error creating the file. Copy and paste the contents of the following console window to a new .cue file.",
            "Create CUE file", 0)
        ShowConsoleMsg(out_str)
    end
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

----------------------------------------------------------

main()
