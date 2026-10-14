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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")

set_action_options(1)

local W, H = 200, 200
local KEY_SPACE = 32
local last_char = 0

gfx.init("Take Number", W, H, 0)
gfx.setfont(1, "Arial", 80, string.byte("b"))

local function give_focus_to_main()
    if APIExists("clara_setFocus") then
        reaper.clara_setFocus(GetMainHwnd())
    elseif APIExists("JS_Window_SetFocus") then
        reaper.JS_Window_SetFocus(GetMainHwnd())
    end
end

give_focus_to_main()

say("Take number display opened. Focus returned to the arrange view. "
    .. "Press spacebar to force focus return if window size has been manipulated.")

local function main()
    local char = gfx.getchar()
    if char == -1 then
        SetExtState("ReaClassical", "TakeDisplayHeartbeat", "", false)
        say("Take number display closed.")
        return
    end

    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        if char == KEY_SPACE then
            give_focus_to_main()
            say("Focus returned to the arrange view.")
        end
    end

    local stop = GetExtState("ReaClassical", "TakeDisplayStop")
    if stop == "1" then
        SetExtState("ReaClassical", "TakeDisplayStop", "", false)
        SetExtState("ReaClassical", "TakeDisplayHeartbeat", "", false)
        gfx.quit()
        say("Take number display closed.")
        return
    end

    SetExtState("ReaClassical", "TakeDisplayHeartbeat", tostring(os.time()), false)

    local _, take_num = GetProjExtState(0, "ReaClassical", "CurrentTakeNumber")
    local playstate  = GetPlayState()

    gfx.r, gfx.g, gfx.b, gfx.a = 0.08, 0.08, 0.08, 1
    gfx.rect(0, 0, gfx.w, gfx.h, true)

    if playstate == 5 then
        gfx.r, gfx.g, gfx.b = 0.9, 0.15, 0.15
    elseif playstate == 6 then
        gfx.r, gfx.g, gfx.b = 0.9, 0.75, 0.1
    else
        gfx.r, gfx.g, gfx.b = 0.2, 0.85, 0.3
    end
    gfx.a = 1

    local label = (take_num ~= "" and take_num ~= "0") and tostring(take_num) or "--"
    gfx.setfont(1, "Arial", math.floor(gfx.h * 0.55), string.byte("b"))
    local tw, th = gfx.measurestr(label)
    gfx.x = math.floor((gfx.w - tw) / 2)
    gfx.y = math.floor((gfx.h - th) / 2)
    gfx.drawstr(label)

    local pad   = math.max(6, math.floor(gfx.h * 0.05))
    local rdot  = math.max(5, math.floor(gfx.h * 0.04))
    local bx    = pad + rdot
    local by    = gfx.h - pad - rdot

    if playstate == 5 then
        gfx.r, gfx.g, gfx.b, gfx.a = 0.9, 0.15, 0.15, 1
        gfx.circle(bx, by, rdot, true, true)
    elseif playstate == 6 then
        local bw = math.max(3, math.floor(rdot * 0.7))
        local bh = math.floor(rdot * 2.2)
        gfx.r, gfx.g, gfx.b, gfx.a = 0.9, 0.75, 0.1, 1
        gfx.rect(bx - rdot,           by - math.floor(bh / 2), bw, bh, true)
        gfx.rect(bx - rdot + bw + 2,  by - math.floor(bh / 2), bw, bh, true)
    end

    gfx.update()
    defer(main)
end

main()
