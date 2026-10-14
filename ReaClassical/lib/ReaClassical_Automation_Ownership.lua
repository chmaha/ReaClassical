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

M.USER_TAG = "RC_USER"

function M.mark_user_ai(env, ai_idx)
    GetSetAutomationItemInfo_String(env, ai_idx, "P_POOL_NAME", M.USER_TAG, true)
end

function M.is_user_ai(env, ai_idx)
    local _, name = GetSetAutomationItemInfo_String(env, ai_idx, "P_POOL_NAME", "", false)
    return name == M.USER_TAG
end

function M.deselect_all_automation_items()
    for ti = 0, CountTracks(0) - 1 do
        local t = GetTrack(0, ti)
        for ei = 0, CountTrackEnvelopes(t) - 1 do
            local e = GetTrackEnvelope(t, ei)
            for ai = 0, CountAutomationItems(e) - 1 do
                GetSetAutomationItemInfo(e, ai, "D_UISEL", 0, true)
            end
        end
    end
end

function M.delete_conversion_owned_ai(env)
    local any = false
    for ai = 0, CountAutomationItems(env) - 1 do
        if not M.is_user_ai(env, ai) then
            GetSetAutomationItemInfo(env, ai, "D_UISEL", 1, true)
            any = true
        end
    end
    if any then Main_OnCommand(42086, 0) end
end

return M
