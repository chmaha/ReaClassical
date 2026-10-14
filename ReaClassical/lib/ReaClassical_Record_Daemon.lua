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

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local root_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path

local M = {}

function M.daemon_cmd()
    if not APIExists("AddRemoveReaScript") then return 0 end
    local path = root_path .. "lib/ReaClassical_Record Panel Daemon.lua"
    return AddRemoveReaScript(true, 0, path, true)
end

function M.is_running()
    local _, ts = GetProjExtState(0, "ReaClassical", "rec_daemon_heartbeat")
    return (os.time() - (tonumber(ts) or 0)) < 5
end

function M.open()
    local cid = M.daemon_cmd()
    if cid == 0 then return "not_found" end

    local already_running = M.is_running()
    if not already_running then
        SetProjExtState(0, "ReaClassical", "rec_daemon_stop", "")
        Main_OnCommand(cid, 0)
        local panel_id = NamedCommandLookup("_RSbd41ad183cae7b18bccb86b087f719e945278160")
        if panel_id ~= 0 then SetToggleCommandState(1, panel_id, 1) end
    end

    local any_armed = false
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        local _, lb = GetSetMediaTrackInfo_String(t, "P_EXT:listenback", "", false)
        if lb ~= "y" and GetMediaTrackInfo_Value(t, "I_RECARM") == 1 then
            any_armed = true; break
        end
    end
    if not any_armed and APIExists("AddRemoveReaScript") then
        local f9_cid = AddRemoveReaScript(true, 0, root_path .. "ReaClassical_Classical Take Record.lua", true)
        if f9_cid ~= 0 then Main_OnCommand(f9_cid, 0) end
    end

    local armed_take
    for i = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, i)
        local _, lb = GetSetMediaTrackInfo_String(t, "P_EXT:listenback", "", false)
        if lb ~= "y" and GetMediaTrackInfo_Value(t, "I_RECARM") == 1
            and GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
            local _, take_num = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
            armed_take = take_num
            break
        end
    end

    return already_running and "already_running" or "started", armed_take
end

function M.close()
    local cid = M.daemon_cmd()
    if cid == 0 then return "not_found" end
    if not M.is_running() then return "not_running" end
    SetProjExtState(0, "ReaClassical", "rec_daemon_stop", "1")
    SetProjExtState(0, "ReaClassical", "rec_daemon_heartbeat", "0")
    return "stopped"
end

function M.open_message(status, take_num)
    if status == "not_found" then return "Record Panel Daemon script not found" end
    local msg = status == "already_running" and "Record daemon already running" or "Record daemon started"
    if take_num then
        msg = msg .. (take_num ~= "" and (". Armed for take " .. take_num) or ". Folder armed")
    end
    return msg
end

function M.close_message(status)
    if status == "not_found" then return "Record Panel Daemon script not found" end
    if status == "not_running" then return "Record daemon is not running" end
    return "Record daemon stopped"
end

return M
