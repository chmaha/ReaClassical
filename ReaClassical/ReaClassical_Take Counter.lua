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

local main, get_rec_number

---------------------------------------------------------------------

function main()

  local playstate = GetPlayState()
  gfx.setfont(1, "Arial", 90, 98)
  if playstate == 0 or playstate == 1 then -- stopped or playing
    gfx.x = 0
    gfx.y = 0
    gfx.set(0.5, 0.8, 0.5, 1)
    local text = get_rec_number() + 1
    local text_width, text_height = gfx.measurestr(text)
    gfx.x = ((300 - text_width) / 2)
    gfx.y = ((100 - text_height) / 2)
    gfx.drawstr(text)
  else -- recording
    gfx.x = 0
    gfx.y = 0
    gfx.set(1, 0.5, 0.5, 1)
    gfx.circle(50, 50, 20, 40)
    text = get_rec_number() + 1
    local text = get_rec_number() + 1
    local text_width, text_height = gfx.measurestr(text)
    gfx.x = ((300 - text_width) / 2)
    gfx.y = ((100 - text_height) / 2)
    gfx.drawstr(text)
  end

  local key = gfx.getchar()
  if key ~= -1 then defer(main) end

end

---------------------------------------------------------------------

function get_rec_number()
  
  local max_recpass = 0
  for i = 0, CountMediaItems(0) - 1 do
    local item = GetMediaItem(0, i)
    local _, statechunk = GetItemStateChunk(item, "", false)
    local num = tonumber(statechunk:match("RECPASS%s*(%d+)"))
    if num and num > max_recpass then max_recpass = num end
  end

  return max_recpass

end

---------------------------------------------------------------------

gfx.init("Take Number", 300, 100, 0, 0, 0)

main()
