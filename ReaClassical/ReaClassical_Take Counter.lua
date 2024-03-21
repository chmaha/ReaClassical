--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2024 chmaha

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

for key in pairs(reaper) do _G[key] = reaper[key] end

local main, get_take_count, clean_up

local iterated_filenames = false
local added_take_number = false
local rec_name_set = false
local take_count, take_text, take_choice
local _, prev_recfilename_value = get_config_var_string("recfile_wildcards")
local separator = package.config:sub(1, 1);

local X = 300
local Y = 125

local _, session = GetProjExtState(0, "ReaClassical Take Counter", "Session")

if session ~= nil and session ~= "" then
  session = session .. separator
else
  session = ""
end

---------------------------------------------------------------------

function main()
  local playstate = GetPlayState()
  gfx.setfont(1, "Arial", 90, 98)

  if playstate == 0 or playstate == 1 then -- stopped or playing
    added_take_number = false
    gfx.x = 0
    gfx.y = 0
    gfx.set(0.5, 0.8, 0.5, 1)

    if not iterated_filenames then
      take_text = get_take_count() + 1
    else
      take_text = take_count + 1
    end

    if gfx.mouse_cap & 1 == 1 then
      local choice = ShowMessageBox("Recalculate take count?", "ReaClassical Take Counter", 4)
      if choice == 6 then
        take_text = get_take_count() + 1
        rec_name_set = false
      end
    elseif gfx.mouse_cap & 2 == 2 then
      local session_text = session:gsub(separator .. "$", "")
      local ret, choices = GetUserInputs('ReaClassical Take Counter', 2, 'Set Take Number:,Session Name:',
        take_text .. ',' .. session_text)
      take_choice, session_choice = string.match(choices, "(%d*),?(.*)")
      if take_choice ~= nil and take_choice ~= "" then
        take_choice = tonumber(take_choice)
      else
        take_choice = take_text
      end
      if session_choice ~= nil and session_choice ~= "" then
        session = session_choice .. separator
      elseif ret ~= false then
        session = ""
      end
      if take_choice ~= nil and take_choice >= take_count then
        take_count = take_choice - 1
        take_text = take_choice
        rec_name_set = false
      else
        ShowMessageBox("You cannot set a take number lower than the highest found "
          .. "in the project path."
          .. "\nRecalculating take count...", "ReaClassical Take Counter", 0)
        take_text = get_take_count() + 1
        rec_name_set = false
      end
    end

    if not rec_name_set then
      SNM_SetStringConfigVar("recfile_wildcards", session .. "$tracknumber_$track-T_" .. take_text)
      rec_name_set = true
    end

    local take_width, take_height = gfx.measurestr(take_text)
    gfx.x = ((X - take_width) / 2)
    -- gfx.y = ((Y - take_height) / 2)
    gfx.drawstr(take_text)
    gfx.setfont(1, "Arial", 25, 98)
    local session_text = session:gsub(separator .. "$", "")
    if session_text == "" and take_text == 1 then
      gfx.setfont(1, "Arial", 15, 98)
      session_text = "Right-click to set session name"
    end
    local session_width, session_height = gfx.measurestr(session_text)
    gfx.x = ((X - session_width) / 2)
    gfx.y = ((Y - session_height + take_height / 3) / 2)
    gfx.set(0.8, 0.8, 0.9, 1)
    gfx.drawstr("\n" .. session_text)
  else -- recording
    gfx.x = 0
    gfx.y = 0
    gfx.set(1, 0.5, 0.5, 1)
    gfx.circle(50, 50, 20, 40)

    if not iterated_filenames then
      take_text = get_take_count() + 1
    end

    local take_width, take_height = gfx.measurestr(take_text)
    gfx.x = ((X - take_width) / 2)
    --gfx.y = ((Y - take_height) / 2)
    gfx.drawstr(take_text)

    local session_text = session:gsub(separator .. "$", "")
    gfx.setfont(1, "Arial", 25, 98)
    local session_width, session_height = gfx.measurestr(session_text)
    gfx.x = ((X - session_width) / 2)
    gfx.y = ((Y - session_height + take_height / 3) / 2)
    gfx.drawstr("\n" .. session_text)

    if not added_take_number then
      take_count = take_count + 1
      take_text = take_count
      added_take_number = true
      rec_name_set = false
    end
  end

  local key = gfx.getchar()
  if key ~= -1 then
    defer(main)
  else
    session = session:gsub(separator .. "$", "")
    atexit(clean_up(session))
  end
end

---------------------------------------------------------------------

function get_take_count()
  take_count = 0

  local media_path = GetProjectPath(0)                   -- .. separator .. session
  local command
  if string.lower(package.config:sub(1, 1)) == '\\' then -- Windows
    command = 'dir "' .. media_path .. '" /b /s /a:-d'
  else                                                   -- Unix-like
    command = 'ls -pR "' .. media_path .. '" | grep -v /$'
  end

  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  local i = 1
  for filename in result:gmatch("[^\r\n]+") do
    local take_capture = tonumber(filename:match(".*[^%d](%d+)%)?%.%a+$"))
    if take_capture and take_capture > take_count then take_count = take_capture end
    iterated_filenames = true
  end

  return take_count
end

---------------------------------------------------------------------

function clean_up(string)
  SetProjExtState(0, "ReaClassical Take Counter", "Session", string)
  SNM_SetStringConfigVar("recfile_wildcards", prev_recfilename_value)
end

---------------------------------------------------------------------

gfx.init("Take Number", X, Y, 0, 0, 0)

main()
