--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

Copyright (C) 2022–2026 chmaha

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

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "../lib/?.lua;"
local setup = require("ReaEdit_XFM_Setup")

local root = script_path:match("^(.*[\\/])XFM[\\/]$") or script_path

local path, count_or_reason = setup.write_keymap(root)
if not path then
    MB(count_or_reason, "ReaEdit Crossfade Mode Keys", 0)
    return
end

MB(("Created the crossfade mode keys (%d bindings) in this file:\n\n%s\n\n"
    .. "To start using them, import it once:\n"
    .. "1. Open the Action List (Actions, Show action list).\n"
    .. "2. Choose Import/export, then \"Import shortcuts/custom actions, import all sections...\".\n"
    .. "3. Select the file above and open it.\n\n"
    .. "The keys only work while crossfade mode is on, so they never affect your normal shortcuts. "
    .. "While the mode is on, Esc leaves it.\n\n"
    .. "Please note: these keys go in REAPER's last alternate keyboard section, Main (alt-16). If you have "
    .. "shortcuts of your own there, back them up before importing (the manual explains how), because the "
    .. "import may replace shortcuts on the same keys."):format(
    count_or_reason, path), "ReaEdit Crossfade Mode Keys", 0)
