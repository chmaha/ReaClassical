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

local function major_of(version)
    return version and tonumber(version:match("^(%d+)"))
end

local function get_installed_major()
    if not APIExists("ReaPack_GetOwner") then return nil end
    local path = ({ get_action_context() })[2]
    if not path or path == "" then return nil end
    local entry = ReaPack_GetOwner(path)
    if not entry then return nil end
    local _, _, _, _, _, _, version = ReaPack_GetEntryInfo(entry)
    ReaPack_FreeEntry(entry)
    return major_of(version)
end

local function fetch_url(url)
    local function try_cmd(cmd)
        local pipe = io.popen(cmd)
        local out = pipe and pipe:read("*a")
        if pipe then pipe:close() end
        return (out and out ~= "") and out or nil
    end

    local out = try_cmd('curl -s -m 8 -k -L "' .. url .. '"')
    if out then return out end

    local platform = GetOS()

    if not platform:match("Win") then
        out = try_cmd('wget -q -T 8 --no-check-certificate -O - "' .. url .. '"')
        if out then return out end
    else
        local ps_cmd = 'powershell.exe -NoProfile -Command "$ProgressPreference=' ..
            "'SilentlyContinue'; " ..
            "(New-Object Net.WebClient).DownloadString('" .. url .. "')\""
        out = try_cmd(ps_cmd)
        if out then return out end
    end

    return nil
end

local function get_latest_major()
    local index_url = "https://raw.githubusercontent.com/chmaha/ReaClassical/main/index.xml"
    local xml = fetch_url(index_url)
    if not xml then return nil end

    local block = xml:match('<reapack name="ReaClassical%.lua".-\n%s*</reapack>')
    if not block then return nil end

    local latest
    for version in block:gmatch('<version name="([^"]+)"') do
        latest = version
    end
    return major_of(latest)
end

local function run_sync()
    local sync_cid = NamedCommandLookup("_REAPACK_SYNC")
    if sync_cid == 0 then
        MB("ReaPack is not installed, so ReaClassical can't be updated this way.\n\n" ..
            "Install ReaPack from https://reapack.com/ to enable updates.",
            "ReaClassical Update", 0)
        return
    end
    Main_OnCommand(sync_cid, 0)
end

local installed_major = get_installed_major()
local latest_major = get_latest_major()

if installed_major and latest_major and latest_major > installed_major then
    MB(("ReaClassical %d is available, but that's a new major version -- " ..
        "please download and install it from https://reaclassical.com " ..
        "instead of updating via ReaPack."):format(latest_major),
        "ReaClassical Update", 0)
    return
end

run_sync()
