--[[
@noindex

This file is a part of "ReaEdit" package.
See "ReaEdit.lua" for more information.

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
local say = require("ReaEdit_Announce")
local xfu = require("ReaEdit_XFM_Utils")
local humanize_timestr = require("ReaEdit_Time_Naming")

local DIRECTION = -1
local EPS = 0.0005

local function reference_track()
    local selected = GetSelectedMediaItem(0, 0)
    if selected then return GetMediaItemTrack(selected) end
    for _, track in ipairs(xfu.all_tracks()) do
        if CountTrackMediaItems(track) > 0 then return track end
    end
    return nil
end

local function main()
    local ctx = xfu.is_xfade_mode() and xfu.get_xfade_context() or nil
    local track = ctx and ctx.ref_track or reference_track()
    if not track then say("No items in the project"); return end

    local xfades = xfu.find_crossfades(track)
    if #xfades == 0 then say("No crossfades on this track"); return end

    local target, number
    if ctx then
        for i, xf in ipairs(xfades) do
            if xf.item2 == ctx.item2 then number = i + DIRECTION; break end
        end
        target = number and xfades[number] or nil
    else
        local here = GetCursorPosition()
        if DIRECTION > 0 then
            for i, xf in ipairs(xfades) do
                if xf.center > here + EPS then target, number = xf, i; break end
            end
        else
            for i = #xfades, 1, -1 do
                if xfades[i].center < here - EPS then target, number = xfades[i], i; break end
            end
        end
    end
    if not target then
        say(DIRECTION > 0 and "No next crossfade" or "No previous crossfade")
        return
    end

    if xfu.is_xfade_mode() then
        xfu.focus_crossfade(track, target)
    else
        Main_OnCommand(40289, 0)
        SetMediaItemSelected(target.item2, true)
        SetEditCurPos(target.center, true, false)
    end
    UpdateArrange()

    local ms = math.floor(target.overlap * 1000 + 0.5)
    say(("Crossfade %d of %d at %s, %s to %s, %d milliseconds"):format(
        number, #xfades, humanize_timestr(format_timestr_pos(target.center, "", -1)),
        xfu.item_label(target.item1), xfu.item_label(target.item2), ms))
end

main()
