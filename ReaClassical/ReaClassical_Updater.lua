--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Copyright (C) 2022–2025 chmaha

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

local main, copy_file, get_path, update_reaper_ini, update_keyb_ini
local ExecUpdate

---------------------------------------------------------------------

function main()
    local system = GetOS()
    local separator = package.config:sub(1, 1)
    local resource_path = GetResourcePath()
    local menu_relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "ReaClassical-menu.ini")
    local source_file_path = resource_path .. menu_relative_path
    local destination_file_path = resource_path .. separator .. "reaper-menu.ini"
    local kb_relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "ReaClassical-kb.ini")
    local source_shortcuts_path = resource_path .. kb_relative_path
    local dest_shortcuts_path = resource_path .. separator .. "reaper-kb.ini"
    local splash_relative_path = get_path("", "Scripts", "chmaha Scripts", "ReaClassical", "reaclassical-splash.png")
    local splash_abs_path = resource_path .. splash_relative_path
    local reaper_ini = resource_path .. separator .. "reaper.ini"

    -- re-apply absolute splash reference on MacOS
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        update_reaper_ini(reaper_ini, "splashimage", splash_abs_path)
    end

    local sync_reapack = NamedCommandLookup("_REAPACK_SYNC")
    Main_OnCommand(sync_reapack, 0)
    MB("1) Syncing ReaPack repos. Please wait for this to complete before pressing OK.",
        "ReaClassical Updater", 0)

    local response1 = MB(
        "2) This section will overwrite your custom toolbars and menus.\nAre you sure you want to continue?",
        "ReaClassical Updater", 4)
    if response1 == 6 then
        copy_file(source_file_path, destination_file_path)
    end

    local response2 = MB(
        "3) This section will overwrite your custom keymaps!\n" ..
        "Are you sure you want to continue?",
        "ReaClassical Updater",
        4
    )
    if response2 == 6 then
        copy_file(source_shortcuts_path, dest_shortcuts_path)
        if string.find(system, "^Win") then
            update_keyb_ini(dest_shortcuts_path,
                "KEY 8 96 _RS444f747139500db030a1c4e03b8a0805ac502dfe 0",
                "KEY 9 223 _RS444f747139500db030a1c4e03b8a0805ac502dfe 0"
            )
        else
            update_keyb_ini(dest_shortcuts_path,
                "KEY 9 223 _RS444f747139500db030a1c4e03b8a0805ac502dfe 0",
                "KEY 8 96 _RS444f747139500db030a1c4e03b8a0805ac502dfe 0"
            )
        end
    end

    if response1 == 6 or response2 == 6 then
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
            MB("Error creating backup: " .. err, "ReaClassical Updater", 0)
            return
        end
    end

    -- Open source file
    local source_file = io.open(source, "rb")
    if not source_file then
        MB("Error opening source file: " .. source, "ReaClassical Updater", 0)
        return
    end

    -- Open destination file
    local destination_file = io.open(destination, "wb")
    if not destination_file then
        source_file:close()
        MB("Error opening destination file: " .. destination, "ReaClassical Updater", 0)
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
    local section_found = false

    for line in file:lines() do
        if line:match("^%[REAPER%]") then
            section_found = true
        end

        if section_found and line:match("^" .. key .. "=") then
            line = key .. "=" .. value
            updated = true
        end

        table.insert(lines, line)
    end
    file:close()

    if not updated and section_found then
        table.insert(lines, key .. "=" .. value)
    end

    file = io.open(ini_file, "w")
    if not file then return false end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()

    return true
end

---------------------------------------------------------------------

function update_keyb_ini(file_path, old_text, new_text)
    local file = io.open(file_path, "r")
    if not file then return false end

    local lines = {}
    local updated = false

    for line in file:lines() do
        local new_line = line:gsub(old_text, new_text)
        if new_line ~= line then
            updated = true
        end
        table.insert(lines, new_line)
    end
    file:close()

    file = io.open(file_path, "w")
    if not file then return false end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()

    return updated
end

---------------------------------------------------------------------

function ExecUpdate()
    local msg = [[
        ReaClassical has to close for the update process to complete.
        Should you have unsaved projects, you will be prompted to save them.
        After the installation is complete, ReaClassical will restart automatically.

        Quit ReaClassical?]]

    local ret = MB(msg, "ReaClassical Updater", 4)
    if ret == 7 then
        return
    end

    Main_OnCommand(40886, 0)

    if IsProjectDirty(0) == 0 then
        Main_OnCommand(40063, 0)
        Main_OnCommand(40004, 0)
    else
        MB("Restart cancelled!", "ReaClassical Updater", 0)
    end
end

---------------------------------------------------------------------


main()
