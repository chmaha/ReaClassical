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
local humanize_timestr = require("ReaClassical_Time_Naming")
local sd_xfade = require("ReaClassical_SD_Crossfade_Utils")

local EPS = 0.0001

local function find_left_piece(right_item)
    local track = GetMediaItemTrack(right_item)
    local r_pos = GetMediaItemInfo_Value(right_item, "D_POSITION")
    for j = 0, CountTrackMediaItems(track) - 1 do
        local item = GetTrackMediaItem(track, j)
        if item ~= right_item then
            local pos = GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = pos + GetMediaItemInfo_Value(item, "D_LENGTH")
            if pos < r_pos - EPS and item_end > r_pos + EPS then
                return item, item_end
            end
        end
    end
end

local function move_crossfades_before_split(existing)
    local pairs_list = {}
    local overlap
    for i = 0, CountMediaItems(0) - 1 do
        local right = GetMediaItem(0, i)
        if not existing[right] then
            local left, left_end = find_left_piece(right)
            if left then
                local split_pos = GetMediaItemInfo_Value(right, "D_POSITION")
                local ov = left_end - split_pos
                ov = math.min(ov, sd_xfade.get_extend_room(right, false))
                ov = math.min(ov, split_pos - GetMediaItemInfo_Value(left, "D_POSITION") - EPS)
                overlap = overlap and math.min(overlap, ov) or ov
                pairs_list[#pairs_list + 1] = { left = left, right = right, split_pos = split_pos }
            end
        end
    end
    if not overlap or overlap <= EPS then return end

    for _, p in ipairs(pairs_list) do
        sd_xfade.set_item_edge(p.left, true, p.split_pos)
        sd_xfade.set_item_edge(p.right, false, p.split_pos - overlap)
        SetMediaItemInfo_Value(p.left, "D_FADEOUTLEN", overlap)
        SetMediaItemInfo_Value(p.left, "D_FADEOUTLEN_AUTO", overlap)
        SetMediaItemInfo_Value(p.right, "D_FADEINLEN", overlap)
        SetMediaItemInfo_Value(p.right, "D_FADEINLEN_AUTO", overlap)
    end
end

local function main()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        local modifier = "Ctrl"
        local system = GetOS()
        if string.find(system, "^OSX") or string.find(system, "^macOS") then
            modifier = "Cmd"
        end
        MB("Please create a ReaClassical project via " .. modifier
            .. "+N to use this function.", "ReaClassical Error", 0)
        return
    end

    local pos = (GetPlayState() == 0) and GetCursorPosition() or GetPlayPosition()
    local before_count = CountMediaItems(0)
    local existing = {}
    for i = 0, before_count - 1 do
        existing[GetMediaItem(0, i)] = true
    end

    PreventUIRefresh(1)
    Undo_BeginBlock()
    Main_OnCommand(40012, 0)
    local split_count = CountMediaItems(0) - before_count
    if split_count > 0 then
        move_crossfades_before_split(existing)
    end
    Undo_EndBlock("ReaClassical Split Item at Cursor", -1)
    PreventUIRefresh(-1)
    UpdateArrange()

    if split_count <= 0 then
        say("No items split")
    else
        say("Split created @ " .. humanize_timestr(format_timestr_pos(pos, "", -1)))
    end
end

main()
