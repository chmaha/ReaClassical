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
local take_count
local text
local _, prev_recfilename_value = get_config_var_string("recfile_wildcards")

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
      text = get_take_count() + 1
    else
      text = take_count + 1
    end

    if gfx.mouse_cap & 1 == 1 then
      local choice = ShowMessageBox("Recalculate take count?", "ReaClassical Take Counter", 4)
      if choice == 6 then
        text = get_take_count() + 1
        rec_name_set = false
      end
    elseif gfx.mouse_cap & 2 == 2 then
      local _, take_choice = GetUserInputs('ReaClassical Take Counter', 1, 'Set Take Number:', '')
      take_choice = tonumber(take_choice)
      if take_choice ~= nil and take_choice > take_count then
        take_count = take_choice - 1
        text = take_choice
        rec_name_set = false
      else
        ShowMessageBox("You cannot set a take number lower than the highest found "
          .. "in the project path."
          .. "\nRecalculating take count...", "ReaClassical Take Counter", 0)
        text = get_take_count() + 1
        rec_name_set = false
      end
    end

    if not rec_name_set then
      SNM_SetStringConfigVar("recfile_wildcards", "$project-$track-T_" .. text)
      rec_name_set = true
    end

    local text_width, text_height = gfx.measurestr(text)
    gfx.x = ((300 - text_width) / 2)
    gfx.y = ((100 - text_height) / 2)
    gfx.drawstr(text)
  else -- recording
    gfx.x = 0
    gfx.y = 0
    gfx.set(1, 0.5, 0.5, 1)
    gfx.circle(50, 50, 20, 40)

    if not iterated_filenames then
      text = get_take_count() + 1
    end

    local text_width, text_height = gfx.measurestr(text)
    gfx.x = ((300 - text_width) / 2)
    gfx.y = ((100 - text_height) / 2)
    gfx.drawstr(text)

    if not added_take_number then
      take_count = take_count + 1
      text = take_count
      added_take_number = true
      rec_name_set = false
    end
  end

  local key = gfx.getchar()
  if key ~= -1 then
    defer(main)
  else
    atexit(clean_up())
  end
end

---------------------------------------------------------------------

function get_take_count()
  take_count = 0

  local media_path = GetProjectPath(0)
  local audioFiles = {}
  local command = ""
  if string.lower(package.config:sub(1, 1)) == '\\' then -- Windows
    command = 'dir "' .. media_path .. '" /b /a:-d'
  else                                                   -- Unix-like
    command = 'ls -p "' .. media_path .. '" | grep -v /'
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

function clean_up()
  SNM_SetStringConfigVar("recfile_wildcards", prev_recfilename_value)
end

---------------------------------------------------------------------

gfx.init("Take Number", 300, 100, 0, 0, 0)

main()
