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

local resource_path = GetResourcePath()
local source_file_path = resource_path .. "/Scripts/chmaha Scripts/ReaClassical/ReaClassical-menu.ini"
local destination_file_path = resource_path .. "/reaper-menu.ini"
local source_shortcuts_path = resource_path .. "/Scripts/chmaha Scripts/ReaClassical/ReaClassical-kb.ini"
local dest_shortcuts_path = resource_path .. "/reaper-kb.ini"

---------------------------------------------------------------------

function main()
    local response1 = ShowMessageBox("This part will overwrite your custom toolbars.\nAre you sure you want to continue?", "ReaClassical Updater",4)
    if response1 == 6 then
      copy_file(source_file_path,destination_file_path)
    end

    local response2 = ShowMessageBox("This part will overwrite your custom keymaps!\nAre you sure you want to continue?", "ReaClassical Updater",4)
    if response2 == 6 then 
      copy_file(source_shortcuts_path,dest_shortcuts_path)
     end
end

---------------------------------------------------------------------

function copy_file(source, destination)
    local source_file = io.open(source, "rb")
    if not source_file then
        ShowMessageBox("Error opening source file: " .. source, "ReaClassical Updater", 0)
        return
    end

    local destination_file = io.open(destination, "wb")
    if not destination_file then
        source_file:close()
        ShowMessageBox("Error opening destination file: " .. destination, "ReaClassical Updater", 0)
        return
    end

    local content = source_file:read("*a")
    destination_file:write(content)

    source_file:close()
    destination_file:close()

    print("File copied successfully.")
end

---------------------------------------------------------------------

main()
