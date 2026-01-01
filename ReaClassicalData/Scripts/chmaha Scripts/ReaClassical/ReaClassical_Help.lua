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

local main

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

---------------------------------------------------------------------

local ctx = ImGui.CreateContext('ReaClassical Help')
local window_open = true

---------------------------------------------------------------------

function main()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end

    ImGui.SetNextWindowSize(ctx, 400, 100, ImGui.Cond_Always)
    local visible, open = ImGui.Begin(ctx, 'ReaClassical Help', true)

    if visible then
        -- Center the text both horizontally and vertically
        local text = "ReaClassical 26 help system coming soon..."
        local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)

        local text_width, text_height = ImGui.CalcTextSize(ctx, text)

        -- Center vertically
        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + (avail_h - text_height) * 0.5)

        -- Center horizontally
        local cursor_start_x = ImGui.GetCursorPosX(ctx)
        ImGui.SetCursorPosX(ctx, cursor_start_x + (avail_w - text_width) * 0.5)
        ImGui.Text(ctx, text)

        ImGui.End(ctx)
    end

    if open then
        defer(main)
    end
end

---------------------------------------------------------------------

defer(main)
