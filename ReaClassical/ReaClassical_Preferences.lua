--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2023 chmaha

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

local r = reaper
local load_prefs, display_prefs, save_prefs, pref_check

-----------------------------------------------------------------------
function Main()
  local pass
  local ret, input = display_prefs()
  if ret then pass = pref_check(input) end
  if pass == 1 then save_prefs(input) end
end
-----------------------------------------------------------------------
function display_prefs()
  local saved
  local bool = r.HasExtState("ReaClassical", "Preferences")
  if bool then saved = load_prefs() end
  local ret, input
  if saved then
    ret, input = r.GetUserInputs('ReaClassical Preferences', 3,
     'S-D Crossfade length (ms),CD track offset (ms),INDEX0 length (s)  (>= 1)',saved)
  else
    ret, input = r.GetUserInputs('ReaClassical Preferences', 3,
     'S-D Crossfade length (ms),CD track offset (ms),INDEX0 length (s)  (>= 1)','35,200,3')
  end
  return ret, input
end
-----------------------------------------------------------------------
function load_prefs()
  return r.GetExtState("ReaClassical", "Preferences")
end
-----------------------------------------------------------------------
function save_prefs(input)
  r.SetExtState("ReaClassical", "Preferences", input, true)
end
-----------------------------------------------------------------------
function pref_check(input)
  local pass = 1
  local table = {}
  for entry in input:gmatch('([^,]+)') do table[#table + 1] = entry end
  if #table ~= 3 then
    r.ShowMessageBox('Empty preferences not allowed. Using previously saved values or defaults', "Warning", 0)
    pass = 0
  end
  return pass
end
-----------------------------------------------------------------------

Main()