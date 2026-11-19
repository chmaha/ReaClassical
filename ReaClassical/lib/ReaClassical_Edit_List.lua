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

function M.format_timecode(seconds, fps, offset_frames)
    local total_frames = math.floor(seconds * fps) + (offset_frames or 0)
    local h = math.floor(total_frames / (3600 * fps))
    local m = math.floor((total_frames % (3600 * fps)) / (60 * fps))
    local s = math.floor((total_frames % (60 * fps)) / fps)
    local f = total_frames % fps
    return string.format("%02d:%02d:%02d:%02d", h, m, s, f)
end

function M.parse_timecode(timecode)
    local h, m, s = timecode:match("^(%d+):(%d+):([%d%.]+)$")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end

    m, s = timecode:match("^(%d+):([%d%.]+)$")
    if m then
        return tonumber(m) * 60 + tonumber(s)
    end

    return tonumber(timecode) or 0
end

function M.ask_offset()
    local retval, input = GetUserInputs("Frame Offset", 1, "Enter offset (frames):", "0")
    if retval then
        return tonumber(input) or 0
    end
    return 0
end

function M.build(track, fps, opts)
    opts = opts or {}
    local bwf = opts.bwf
    local offset_frames = opts.offset_frames or 0
    local format_timecode = M.format_timecode
    local item_table = {}
    if not track then return item_table end

    local time_sel_start, time_sel_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local has_time_sel = (time_sel_end > time_sel_start)
    local position_offset = (not bwf and has_time_sel) and time_sel_start or 0

    local item_count = CountTrackMediaItems(track)
    local edit_number = 1
    local prev_filename = nil

    for i = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, i)
        local take = GetActiveTake(item)
        if not take then goto continue end

        local position = GetMediaItemInfo_Value(item, "D_POSITION")
        local length = GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = position + length

        if has_time_sel and (item_end <= time_sel_start or position >= time_sel_end) then
            goto continue
        end

        local source = GetMediaItemTake_Source(take)
        local playrate = GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
        local full_path = GetMediaSourceFileName(source)
        local filename = full_path:match("([^\\/]+)$")

        local start_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
        if bwf then
            local retval, bwf_offset_str = GetMediaFileMetadata(source, "Generic:StartOffset")
            local bwf_offset = (retval and bwf_offset_str ~= "") and M.parse_timecode(bwf_offset_str) or 0
            start_offset = bwf_offset + start_offset
        end

        local next_item_position = (i + 1 < item_count) and
            GetMediaItemInfo_Value(GetTrackMediaItem(track, i + 1), "D_POSITION") or item_end

        local end_offset = math.min(start_offset + next_item_position - position, start_offset + length)
        local source_length = (end_offset - start_offset)

        if (math.abs(playrate - 1) > 0.001) then
            source_length = source_length / playrate
            end_offset = start_offset + source_length
        end

        if filename == prev_filename then
            filename = '…'
        else
            prev_filename = filename
        end

        table.insert(item_table, {
            edit_number = edit_number,
            position = format_timecode(position - position_offset, fps, offset_frames),
            filename = filename,
            path = full_path,
            start_sec = position - position_offset,
            end_sec = position + source_length - position_offset,
            s_in = format_timecode(start_offset, fps, offset_frames),
            s_out = format_timecode(end_offset, fps, offset_frames),
            dest_end = format_timecode(position + source_length - position_offset, fps, offset_frames),
            playrate = (math.abs(playrate - 1) < 0.001) and "" or playrate
        })

        edit_number = edit_number + 1

        if i + 1 < item_count then
            local next_item = GetTrackMediaItem(track, i + 1)
            local next_position = GetMediaItemInfo_Value(next_item, "D_POSITION")

            if next_position > item_end and (not has_time_sel or next_position < time_sel_end) then
                table.insert(item_table, {
                    edit_number = "Gap",
                    position = "",
                    filename = "",
                    s_in = "",
                    s_out = "",
                    dest_end = "",
                    playrate = ""
                })
                prev_filename = nil
            end
        end

        ::continue::
    end

    return item_table
end

return M
