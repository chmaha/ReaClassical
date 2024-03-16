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

local main, get_take_count

gfx.init("Take Number", 300, 100, 0, 0, 0)

local iterated_filenames = false
local take_count
local added_take_number = false
local text
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
    end
  end


  local key = gfx.getchar()
  if key ~= -1 then defer(main) end
end

---------------------------------------------------------------------

function get_take_count()
  take_count = 0
  local num_of_items = CountMediaItems(0)
  for i = 0, num_of_items - 1 do
    local item = GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    local src = reaper.GetMediaItemTake_Source(take)
    local filename = reaper.GetMediaSourceFileName(src, "")
    local take_capture = tonumber(filename:match(".*[^%d](%d+)%)?%.%a+$"))
    if take_capture and take_capture > take_count then take_count = take_capture end
    iterated_filenames = true
  end

  return take_count

end

---------------------------------------------------------------------

main()
