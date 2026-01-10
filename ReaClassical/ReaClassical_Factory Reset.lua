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

local main, copy_file, get_path, update_reaper_ini
local ExecUpdate

---------------------------------------------------------------------

function main()
    local system = GetOS()
    local separator = package.config:sub(1, 1)
    local resource_path = GetResourcePath()

    local menu_relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "ReaClassical-menu.ini")
    local kb_relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "ReaClassical-kb.ini")
    local renderpresets_relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical",
        "ReaClassical-render.ini")
    local main_ini_relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical",
        "ReaClassical.ini")

    local src_menu_path = resource_path .. menu_relative_path
    local src_renderpresets_path = resource_path .. renderpresets_relative_path
    local src_shortcuts_path = resource_path .. kb_relative_path
    local src_main_ini_path = resource_path .. main_ini_relative_path

    local dest_menu_path = resource_path .. separator .. "reaper-menu.ini"
    local dest_shortcuts_path = resource_path .. separator .. "reaper-kb.ini"
    local dest_renderpresets_path = resource_path .. separator .. "reaper-render.ini"
    local dest_main_ini_path = resource_path .. separator .. "reaper.ini"

    local splash_relative_path = get_path("Scripts", "chmaha Scripts", "ReaClassical", "reaclassical-splash.png")
    local splash_abs_path = resource_path .. separator .. splash_relative_path

    local theme_relative_path = get_path("", "ColorThemes", "ReaClassical.ReaperTheme")
    local theme_abs_path = resource_path .. theme_relative_path

    local response = MB(
        "This function will reset keymap, menu and render presets to ReaClassical defaults." ..
        "\nAffected files will be backed up with a .backup extension." ..
        "\n\nAre you sure you want to continue?",
        "ReaClassical Reset", 4)

    if response == 6 then
        copy_file(src_renderpresets_path, dest_renderpresets_path)
        copy_file(src_menu_path, dest_menu_path)
        copy_file(src_shortcuts_path, dest_shortcuts_path)
        copy_file(src_main_ini_path, dest_main_ini_path)
    end

    update_reaper_ini(dest_main_ini_path, "lastthemefn5", theme_abs_path)

    -- re-apply absolute splash reference on MacOS
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        update_reaper_ini(dest_main_ini_path, "splashimage", splash_abs_path)
    else
        update_reaper_ini(dest_main_ini_path, "splashimage", splash_relative_path)
    end

    if response == 6 then
        ExecUpdate()
    end
end

---------------------------------------------------------------------

function copy_file(source, destination)
    -- Check if destination file exists
    local destination_file_exists = io.open(destination, "rb")
    if destination_file_exists then
        destination_file_exists:close()
        -- Backup existing destination file
        local backup_destination = destination .. ".backup"
        os.remove(backup_destination)
        local success, err = os.rename(destination, backup_destination)
        if not success then
            MB("Error creating backup: " .. err, "ReaClassical Reset", 0)
            return
        end
    end

    -- Open source file
    local source_file = io.open(source, "rb")
    if not source_file then
        MB("Error opening source file: " .. source, "ReaClassical Reset", 0)
        return
    end

    -- Open destination file
    local destination_file = io.open(destination, "wb")
    if not destination_file then
        source_file:close()
        MB("Error opening destination file: " .. destination, "ReaClassical Reset", 0)
        return
    end

    -- Read content from source and write to destination
    local content = source_file:read("*a")
    destination_file:write(content)

    --Close files
    source_file:close()
    destination_file:close()
end

---------------------------------------------------------------------

function get_path(...)
    local pathseparator = package.config:sub(1, 1);
    local elements = { ... }
    return table.concat(elements, pathseparator)
end

---------------------------------------------------------------------

function update_reaper_ini(ini_file, key, value)
    local file = io.open(ini_file, "r")
    if not file then return false end

    local lines = {}
    local updated = false
    local in_reaper_section = false
    local reaper_section_index = nil

    for line in file:lines() do
        -- Detect section headers
        if line:match("^%[.+%]") then
            if line:match("^%[REAPER%]") then
                in_reaper_section = true
                reaper_section_index = #lines + 1
            else
                in_reaper_section = false
            end
        end

        -- Update existing key inside REAPER section
        if in_reaper_section and line:match("^" .. key .. "=") then
            line = key .. "=" .. value
            updated = true
        end

        table.insert(lines, line)
    end

    file:close()

    -- Insert new key if it was not found
    if not updated and reaper_section_index then
        table.insert(lines, reaper_section_index + 1, key .. "=" .. value)
    end

    -- Write file back
    file = io.open(ini_file, "w")
    if not file then return false end
    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()

    return true
end

---------------------------------------------------------------------

function ExecUpdate()
    local msg = [[
        ReaClassical has to close for the update process to complete.
        Should you have unsaved projects, you will be prompted to save them.
        After the installation is complete, ReaClassical will restart automatically.

        Quit ReaClassical?]]

    local ret = MB(msg, "ReaClassical Reset", 4)
    if ret == 7 then
        return
    end

    Main_OnCommand(40886, 0)

    if IsProjectDirty(0) == 0 then
        Main_OnCommand(40063, 0)
        Main_OnCommand(40004, 0)
    else
        MB("Restart cancelled!", "ReaClassical Reset", 0)
    end
end

---------------------------------------------------------------------

main()
