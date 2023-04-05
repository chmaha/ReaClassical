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
  Simplify Main() with separate functions
  Add pairs(reaper) code
]]
for key in pairs(reaper) do _G[key] = reaper[key] end

local pattern_match, ext_mod, get_proj_path, save_file
local count_markers, create_filename, create_string, get_data
----------------------------------------------------------
function Main()
  local ret, num_of_markers = count_markers() if not ret then return end
  local ret, filename = create_filename() if not ret then return end
  local ret, fields, ext_len = get_data(filename) if not ret then return end
  local string = create_string(fields, num_of_markers, ext_len)
  save_file(filename, string)
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
  if not full_project_name then
    ShowMessageBox("Please save your project first!", "Create CUE file", 0)
    return false
  else
    return true, full_project_name:match("^(.+)[.].*$")
  end
end

----------------------------------------------------------
function get_data(filename)
  local this_year = os.date("%Y")

  local ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
    'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
    'Classical,' .. this_year .. ',Performer,My Classical Album,' .. filename .. '.wav')
  if not ret then return end
  local fields = {}
  for word in user_inputs:gmatch('[^%,]+') do fields[#fields + 1] = word end
  if #fields ~= 5 then
    ShowMessageBox('Sorry. Empty fields not supported.', "Create CUE file", 0)
    return false
  end
  local ext_len = fields[5]:reverse():find('%.')
  if not ext_len then
    ShowMessageBox('Please enter filename with an extension', "Create CUE file", 0)
    return false
  end
  return true, fields, ext_len
end

----------------------------------------------------------
function create_string(fields, num_of_markers, ext_len)
  local ext = fields[5]:sub(1 - ext_len):upper()

  local format = ext_mod(ext)

  local out_str =
      ' REM GENRE ' .. fields[1] ..
      '\n REM DATE ' .. fields[2] ..
      '\n PERFORMER ' .. fields[3] ..
      '\n TITLE ' .. fields[4] ..
      '\n FILE ' .. fields[5] .. ' ' .. format .. '\n'

  local ind3 = '   '
  local ind5 = '     '

  local marker_id = 1
  for i = 0, num_of_markers - 1 do
    local _, _, pos_out, _, name_out = EnumProjectMarkers2(0, i)
    if pattern_match(name_out) ~= '#'
    then
      goto skip_to_next
    end
    name_out = name_out:match('#(.*)')
    pos_out = format_timestr_pos(pos_out, '', 5)

    local time = {}
    for num in pos_out:gmatch('[%d]+') do
      if tonumber(num) > 10 then num = tonumber(num) end
      time[#time + 1] = num
    end
    if tonumber(time[1]) > 0 then time[2] = tonumber(time[2]) + tonumber(time[1]) * 60 end

    local perf = fields[3]
    pos_out = table.concat(time, ':', 2)

    local id = ("%02d"):format(marker_id)
    marker_id = marker_id + 1
    if name_out == nil or name_out == '' then local nameOut1 = 'Untitled ' .. id end
    out_str = out_str .. ind3 .. 'TRACK ' .. id .. ' AUDIO' .. '\n' ..
        ind5 .. 'TITLE ' .. '"' .. name_out .. '"' .. '\n' ..
        ind5 .. 'PERFORMER ' .. '"' .. perf .. '"' .. '\n' ..
        ind5 .. 'INDEX 01 ' .. pos_out .. '\n'
    ::skip_to_next::
  end
  return out_str
end

----------------------------------------------------------
function pattern_match(name_out)
  return name_out:gsub('%s', ''):sub(0, 1)
end

----------------------------------------------------------
function ext_mod(ext)
  local list = { "AIFF", "MP3" }
  for _, v in pairs(list) do
    if ext == v then
      return ext
    end
  end
  return "WAV"
end

----------------------------------------------------------
function save_file(filename, out_str)
  local _, path = EnumProjects(-1, "")
  if path == "" then
    path = GetProjectPath("")
  else
    path = path:match("(.+)/.+[.]RPP")
  end
  local retval0, file = JS_Dialog_BrowseForSaveFile('Generate CUE file', path, filename, ".cue")
  if retval0 == 1 then
    if not file:lower():match('%.cue') then file = file .. '.cue' end
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
  end
end

----------------------------------------------------------

Main()

