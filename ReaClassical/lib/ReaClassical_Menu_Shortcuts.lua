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

function M.parse_section(section)
    local path = GetResourcePath() .. "/reaper-menu.ini"
    local file = io.open(path, "r")
    if not file then return nil end

    local target = "[" .. section .. "]"
    local in_section = false
    local root = {}
    local stack = { root }

    for raw_line in file:lines() do
        local line = raw_line:gsub("\r$", "")
        if line:match("^%[.-%]$") then
            if in_section then break end
            in_section = (line == target)
        elseif in_section then
            local cur = stack[#stack]
            local cmdid, label = line:match("^item_%d+=(_%S+)%s+(.*)$")
            if cmdid then
                cur[#cur + 1] = { type = "item", label = label, cmdid = cmdid }
            else
                local code_str, rest = line:match("^item_%d+=(%-?%d+)%s*(.*)$")
                if code_str then
                    local code = tonumber(code_str)
                    if code == -1 then
                    elseif code == -2 then
                        local node = { type = "submenu", label = rest, items = {} }
                        cur[#cur + 1] = node
                        stack[#stack + 1] = node.items
                    elseif code == -3 then
                        if #stack > 1 then stack[#stack] = nil end
                    elseif code == -4 then
                        cur[#cur + 1] = { type = "header", label = rest }
                    else
                        cur[#cur + 1] = { type = "item", label = rest, cmdid = code_str }
                    end
                end
            end
        end
    end
    file:close()
    return root
end

return M
