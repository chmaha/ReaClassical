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

local keys = require("ReaEdit_XFM_Keys")

local M = {}

local function script_file(script_path, relative)
    return script_path .. (relative:gsub("/", package.config:sub(1, 1)))
end

M.KEYMAP_NAME = "ReaEdit Crossfade Mode.ReaperKeyMap"

local function scripts_in_table()
    local list, seen = {}, {}
    for _, k in ipairs(keys.KEYS) do
        if k.script and not seen[k.script] then
            seen[k.script] = true
            list[#list + 1] = k.script
        end
    end
    return list
end

local function command_ids(script_path)
    local list = scripts_in_table()
    local ids, missing = {}, {}
    for i, script in ipairs(list) do
        local cid = AddRemoveReaScript(true, 0, script_file(script_path, script), i == #list)
        local named = cid ~= 0 and ReverseNamedCommandLookup(cid) or nil
        if named and named ~= "" then
            ids[script] = "_" .. named
        else
            missing[#missing + 1] = script
        end
    end
    return ids, missing
end

function M.build_keymap(script_path)
    local ids, missing = command_ids(script_path)
    if #missing > 0 then return nil, missing end
    local lines = {}
    for _, k in ipairs(keys.KEYS) do
        local cmd = k.native and tostring(k.native) or ids[k.script]
        lines[#lines + 1] = ("KEY %d %d %s %d\t\t# Main (alt-%d) : %s : %s"):format(
            k.mod, k.key, cmd, keys.SECTION, keys.SECTION, k.label, k.description)
    end
    for _, d in ipairs(keys.DISABLED) do
        lines[#lines + 1] = ("KEY %d %d 0 %d\t\t# Main (alt-%d) : %s : DISABLED DEFAULT"):format(
            d.mod, d.key, keys.SECTION, keys.SECTION, d.label)
    end
    return table.concat(lines, "\n") .. "\n", {}
end

function M.write_keymap(script_path)
    local text, missing = M.build_keymap(script_path)
    if not text then
        return nil, "These ReaEdit scripts could not be found next to the setup script: " .. table.concat(missing, ", ")
    end
    local dir = GetResourcePath() .. package.config:sub(1, 1) .. "KeyMaps"
    RecursiveCreateDirectory(dir, 0)
    local path = dir .. package.config:sub(1, 1) .. M.KEYMAP_NAME
    local f, err = io.open(path, "wb")
    if not f then return nil, "Could not write " .. path .. ": " .. tostring(err) end
    f:write(text)
    f:close()
    SetExtState("ReaEdit", "XfmKeysFile", path, true)
    return path, #keys.KEYS
end

function M.keys_present(script_path)
    if not APIExists("SectionFromUniqueID") or not APIExists("CountActionShortcuts") then return nil end
    local section = SectionFromUniqueID(keys.SECTION)
    if not section then return nil end
    local sentinel
    for _, script in ipairs(scripts_in_table()) do
        if script:find("Select Both Items", 1, true) then sentinel = script; break end
    end
    sentinel = sentinel or scripts_in_table()[1]
    local cid = AddRemoveReaScript(true, 0, script_file(script_path, sentinel), true)
    if cid == 0 then return nil end
    return CountActionShortcuts(section, cid) > 0
end

return M
