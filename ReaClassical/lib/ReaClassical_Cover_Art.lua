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

local M = {}

local CANDIDATES = {
    "cover.jpg", "cover.jpeg", "cover.png",
    "folder.jpg", "folder.jpeg", "folder.png",
}

local function file_exists(path)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
end

function M.find()
    local media_path = GetProjectPath()
    if not media_path or media_path == "" then return nil, nil end

    local slash = package.config:sub(1, 1)
    for _, name in ipairs(CANDIDATES) do
        local path = media_path .. slash .. name
        if file_exists(path) then return path, name end
    end
    return nil, nil
end

return M
