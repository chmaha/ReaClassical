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
  Use reaper.ShowMessageBox in case of file-writing error before showing console message for copy/paste
  Move file-saving to its own function
  General switch to snake_case where possible
  Switch to using local variables
  Other small typographical changes

mpl 04.04.2023 changelog:
  clean up a bit
  turn r=reaper in EEL-like functions scope
  change io.open(w) to wb for possible huge files

chmaha 04.05.2023 changelog:
  Rename functions and some variables
  Move Main() to top for ease of reading
]]
for key in pairs(reaper) do _G[key] = reaper[key] end

local check_existing_markers, get_dest_filename, get_metadata, write_data_header, extension_mod
local pattern_match, write_data_markers, save_file

---------------------------------------------------------------
function Main()
  local ts_start, ts_end = GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  local has_time_sel = math.abs(ts_end - ts_start) > 0.01
  ts_start = 0
  ts_end = math.huge

  local ret, num_of_markers, pattern = check_existing_markers(ts_start, ts_end)
  if not ret then return end
  local filename = get_dest_filename()
  if not filename then return end
  local metadata = get_metadata(filename)
  if not metadata then return end

  local output = {}
  write_data_header(output, metadata)
  write_data_markers(output, ts_start, ts_end, pattern, metadata)
  save_file(filename, output)
end

---------------------------------------------------------------
function check_existing_markers(ts_start, ts_end)
  local _, num_of_markers = CountProjectMarkers(0)
  if not num_of_markers or num_of_markers == 0 then
    ShowMessageBox('Please use "Create CD Markers script" first', "Create CUE file", 0)
    return
  end

  local pattern
  for i = 1, num_of_markers do
    local _, _, pos_out, _, name_out, markrgnindexnumber = EnumProjectMarkers2(0, i - 1)
    if pos_out >= ts_start and pos_out <= ts_end then
      if pattern_match(name_out) == '#' then
        pattern = '#'
        break
      end
      if pattern_match(name_out) == '!' then
        pattern = '!'
        break
      end
      if pattern_match(name_out) == '@' then
        pattern = '@'
        break
      end
    end
  end

  return true, num_of_markers, pattern
end

---------------------------------------------------------------
function get_dest_filename()
  local full_project_name = GetProjectName(0)
  if not full_project_name or (full_project_name and full_project_name == '') then
    ShowMessageBox("Please save your project first!", "Create CUE file", 0)
    return
  end
  return full_project_name:match("^(.+)[.].*$")
end

---------------------------------------------------------------
function get_metadata(filename)
  local metadata = {}
  local this_year = os.date("%Y")
  local ret, user_inputs = GetUserInputs('Add Metadata for CUE file', 5,
    'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
    'Classical,' .. this_year .. ',Performer,My Classical Album,' .. filename .. '.wav')
  if not ret then return end
  local fields = {}
  for word in user_inputs:gmatch('[^%,]+') do fields[#fields + 1] = word end
  if #fields ~= 5 then
    ShowMessageBox('Sorry. Empty fields not supported', "Create CUE file", 0)
    return
  end

  local ext_len = fields[5]:reverse():find('%.')
  if not ext_len then
    ShowMessageBox('Please enter filename with ext', "Create CUE file", 0)
    return
  end
  local ext = fields[5]:sub(1 - ext_len):upper()
  metadata.ext = ext
  local format = extension_mod(ext)

  metadata.GENRE = fields[1]
  metadata.DATE = fields[2]
  metadata.PERFORMER = fields[3]
  metadata.TITLE = fields[4]
  metadata.FILE = fields[5] .. ' ' .. format
  return metadata
end

---------------------------------------------------------------
function extension_mod(ext)
  local list = { "AIFF", "MP3" }
  for _, v in pairs(list) do if ext == v then return ext end end
  return "WAV"
end

---------------------------------------------------------------
function write_data_header(output, metadata)
  local indent_header = ' '
  table.insert(output, indent_header .. 'REM GENRE ' .. metadata.GENRE)
  table.insert(output, indent_header .. 'REM DATE ' .. metadata.DATE)
  table.insert(output, indent_header .. 'PERFORMER ' .. metadata.PERFORMER)
  table.insert(output, indent_header .. 'TITLE ' .. metadata.TITLE)
  table.insert(output, indent_header .. 'FILE ' .. metadata.FILE)
  table.insert(output, '')
end

---------------------------------------------------------------
function pattern_match(name_out) return name_out:gsub('%s', ''):sub(0, 1) end

---------------------------------------------------------------
function write_data_markers(output, ts_start, ts_end, pattern, metadata)
  local indent_single = '   '
  local indent_double = '     '
  local marker_id = 1 -- init count for output
  for i = 1, CountProjectMarkers(0) do
    local _, _, pos_out, _, name_out, markrgnindexnumber = EnumProjectMarkers2(0, i - 1)
    if not (
        pos_out >= ts_start
        and pos_out <= ts_end
        and (not pattern or (pattern and pattern_match(name_out) == pattern))
        ) then
      goto skip_to_next
    end
    if pattern and pattern_match(name_out) == pattern then name_out = name_out:match(pattern .. '(.*)') end

    -- time formatting
    pos_out = format_timestr_pos(pos_out - ts_start, '', 5) -- offset by time selection start
    local time = {}
    for num in pos_out:gmatch('[%d]+') do
      if tonumber(num) > 10 then num = tonumber(num) end
      time[#time + 1] = num
    end
    if tonumber(time[1]) > 0 then time[2] = tonumber(time[2]) + tonumber(time[1]) * 60 end
    pos_out = table.concat(time, ':', 2)


    local id = ("%02d"):format(marker_id)
    if name_out == nil or name_out == '' then nameOut = 'Untitled ' .. id end -- handle empty markers
    table.insert(output, indent_single .. 'TRACK ' .. id .. ' AUDIO')
    table.insert(output, indent_double .. 'TITLE ' .. '"' .. name_out .. '"')
    table.insert(output, indent_double .. 'PERFORMER ' .. '"' .. metadata.PERFORMER .. '"')
    table.insert(output, indent_double .. 'INDEX 01 ' .. pos_out)

    marker_id = marker_id + 1
    ::skip_to_next::
  end
end

---------------------------------------------------------------
function save_file(filename, output)
  local _, path = EnumProjects(-1, "")
  if path == "" then path = GetProjectPath("") else path = path:match("(.+)/.+[.]RPP") end
  local retval0, file = JS_Dialog_BrowseForSaveFile('Generate CUE file', path, filename, ".cue")
  if retval0 == 1 then
    if not file:lower():match('%.cue') then file = file .. '.cue' end
    local f = io.open(file, 'wb')
    if f then
      f:write(table.concat(output, '\n'))
      f:close()
    else
      ShowMessageBox(
        "There was an error creating the file. Copy and paste the contents of the following console window to a new .cue file.",
        "Create CUE file", 0)
      ShowConsoleMsg(out_str)
    end
  end
end

---------------------------------------------------------------

Main()
