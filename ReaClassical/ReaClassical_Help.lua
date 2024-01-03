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

---------------------------------------------------------------------

function main()
    local resource_path = GetResourcePath()
    local relative_path = "Scripts/chmaha Scripts/ReaClassical/ReaClassical_PDF_Guide.pdf"
    local pdf = resource_path .. "/" .. relative_path
    local bool = file_exists(pdf)
    if bool == true then
        CF_ShellExecute(pdf)
    else
        ShowMessageBox("Re-install ReaClassical metapackage via ReaPack first!", "ReaClassical PDF Guide not found!", 0)
    end
end

---------------------------------------------------------------------

function file_exists(name)
    local exists = false
    local file = io.open(name, "r")
    if file ~= nil then
        io.close(file)
        exists = true
    end
    return exists
end

---------------------------------------------------------------------

main()
