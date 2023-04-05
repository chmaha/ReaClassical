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
]]

local r = reaper
local pattern_match, ext_mod, get_proj_path, save_file

function Main()
  local _, num_of_markers = r.CountProjectMarkers(0)
  if not num_of_markers or num_of_markers == 0 then
    r.ShowMessageBox('Please use "Create CD Markers script" first', "Create CUE file", 0)
    return
  end

  local full_project_name = r.GetProjectName(0)
  if not full_project_name then
    r.ShowMessageBox("Please save your project first!", "Create CUE file", 0)
    return
  end
  local filename = full_project_name:match("^(.+)[.].*$")

  local this_year = os.date("%Y")

  local marker_id = 1
  local ret, user_inputs = r.GetUserInputs('Add Metadata for CUE file', 5,
    'Genre,Year,Performer,Album Title,File name (with ext),extrawidth=100',
    'Classical,' .. this_year .. ',Performer,My Classical Album,' .. filename .. '.wav')
  if not ret then return end
  local fields = {}
  for word in user_inputs:gmatch('[^%,]+') do fields[#fields + 1] = word end
  if #fields ~= 5 then
    r.ShowMessageBox('Sorry. Empty fields not supported', "Create CUE file", 0)
    return
  end
  local ext_len = fields[5]:reverse():find('%.')
  if not ext_len then
    r.ShowMessageBox('Please enter filename with ext', "Create CUE file", 0)
    return
  end
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

  local ts_start, tsend = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  local has_time_sel = math.abs(tsend - ts_start) > 0.01

  local has_pattern
  local include

  for i = 1, num_of_markers do
    local _, _, pos_out, _, name_out, markrgnindexnumber = r.EnumProjectMarkers2(0, i - 1)
    if not has_pattern then
      has_pattern = pattern_match(name_out) == '#'
          or pattern_match(name_out) == '!'
          or pattern_match(name_out) == '@'
    end
    if not include then include = pattern_match(name_out) == '#' end
  end

  for i = 1, num_of_markers do
    local _, _, pos_out, _, name_out, markrgnindexnumber = r.EnumProjectMarkers2(0, i - 1)
    if (has_time_sel and not (pos_out >= ts_start and pos_out <= tsend)) or
        (pattern_match(name_out) == '!' or pattern_match(name_out) == '@') or (include and pattern_match(name_out) ~= '#')
    then
      goto skip_to_next
    end

    if pattern_match(name_out) == '#' then name_out = name_out:match('#(.*)') end

    if not has_time_sel then
      pos_out = r.format_timestr_pos(pos_out, '', 5)
    else
      pos_out = r.format_timestr_pos(pos_out - ts_start, '', 5)
    end

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

  local path = get_proj_path()

  save_file(path, filename, out_str)
end

function pattern_match(name_out)
  return name_out:gsub('%s', ''):sub(0, 1)
end

function ext_mod(ext)
  local list = { "AIFF", "MP3" }
  for _, v in pairs(list) do
    if ext == v then
      return ext
    end
  end
  return "WAV"
end

function get_proj_path()
  local _, path = r.EnumProjects(-1, "")
  if path == "" then
    return r.GetProjectPath("")
  else
    return path:match("(.+)/.+[.]RPP")
  end
end

function save_file(path, filename, out_str)
  local retval0, file = r.JS_Dialog_BrowseForSaveFile('Generate CUE file', path, filename, ".cue")
  if retval0 == 1 then
    if not file:lower():match('%.cue') then file = file .. '.cue' end
    local f = io.open(file, 'w')
    if f then
      f:write(out_str)
      f:close()
    else
      r.ShowMessageBox(
        "There was an error creating the file. Copy and paste the contents of the following console window to a new .cue file.",
        "Create CUE file", 0)
      r.ShowConsoleMsg(out_str)
    end
  end
end

Main()
