--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

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

---------------------------------------------------------------------

-- Translates a raw P_NAME's internal prefix encoding into a spoken label,
-- e.g. "M:Violin" -> "Mixer track Violin", "#Strings" -> "Submix Strings",
-- "@" (no custom name) -> "Auxiliary". REF/LISTENBACK/RCMASTER get a
-- word-spaced form ("Reference", "Listen back", "RC Master") since OSARA
-- otherwise tries to spell them out letter-by-letter as acronyms.
local function humanize_track_name(name)
    if not name or name == "" then return "(unnamed)" end

    local rest = name:match("^M:(.*)$")
    if rest then return rest ~= "" and ("Mixer track " .. rest) or "Mixer track" end

    rest = name:match("^D:(.*)$")
    if rest then return rest ~= "" and ("Destination " .. rest) or "Destination" end

    local src_num, src_rest = name:match("^S(%d+):(.*)$")
    if src_num then
        return src_rest ~= "" and ("Source " .. src_num .. " " .. src_rest) or ("Source " .. src_num)
    end

    rest = name:match("^@(.*)$")
    if rest then return rest ~= "" and ("Auxiliary " .. rest) or "Auxiliary" end

    rest = name:match("^#(.*)$")
    if rest then return rest ~= "" and ("Submix " .. rest) or "Submix" end

    rest = name:match("^REF:?(.*)$")
    if rest then return rest ~= "" and ("Reference " .. rest) or "Reference" end

    if name == "LISTENBACK" then return "Listen back" end
    if name == "RCMASTER" then return "RC Master" end

    return name
end

---------------------------------------------------------------------

return humanize_track_name
