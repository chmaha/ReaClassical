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

local M = {}

local KEY_LINE_PATTERN = "^KEY%s+%S+%s+%S+%s+(%S+)%s+(%S+)%s*#%s*(.-)%s*\r?$"

local function split_comment(comment)
    local parts = {}
    local rest = comment
    while true do
        local s, e = rest:find(" : ", 1, true)
        if not s then
            parts[#parts + 1] = rest
            break
        end
        parts[#parts + 1] = rest:sub(1, s - 1)
        rest = rest:sub(e + 1)
    end
    return parts
end

function M.shortcuts_for_section(section, strip_prefix)
    local path = GetResourcePath() .. "/reaper-kb.ini"
    local file = io.open(path, "r")
    if not file then return nil end

    local section_str = tostring(section)
    local list = {}
    for line in file:lines() do
        local cmdid, line_section, comment = line:match(KEY_LINE_PATTERN)
        if cmdid and line_section == section_str and cmdid ~= "0" then
            local parts = split_comment(comment)
            local key_label = parts[2]
            local action = parts[#parts]
            local native_name = action and action:match("^ReaClassical:%s*(.*)$")
            local script_name = native_name and ("ReaClassical_" .. native_name)
                or (action and action:match("^Script:%s*(.*)$"))
            if key_label and script_name and script_name:sub(1, 13) == "ReaClassical_" then
                local desc = script_name:gsub("%.lua$", "")
                if strip_prefix and desc:sub(1, #strip_prefix) == strip_prefix then
                    desc = desc:sub(#strip_prefix + 1)
                else
                    desc = desc:gsub("^ReaClassical_", "")
                end
                list[#list + 1] = { key = key_label, desc = desc, cmdid = cmdid }
            end
        end
    end
    file:close()
    return list
end

function M.key_map_for_section(section)
    local path = GetResourcePath() .. "/reaper-kb.ini"
    local file = io.open(path, "r")
    if not file then return {} end

    local section_str = tostring(section)
    local map = {}
    for line in file:lines() do
        local cmdid, line_section, comment = line:match(KEY_LINE_PATTERN)
        if cmdid and line_section == section_str and cmdid ~= "0" and not map[cmdid] then
            local parts = split_comment(comment)
            local key_label = parts[2]
            if key_label then map[cmdid] = key_label end
        end
    end
    file:close()
    return map
end

function M.run_command(cmdid)
    local numeric = tonumber(cmdid)
    if not numeric then
        numeric = NamedCommandLookup(cmdid)
        if not numeric or numeric == 0 then return false end
    end
    Main_OnCommand(numeric, 0)
    return true
end

return M
