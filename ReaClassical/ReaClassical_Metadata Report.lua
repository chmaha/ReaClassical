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
local main, parse_markers, generate_report, any

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    local metadata, error_msg = parse_markers()
    if error_msg ~= "" then
        MB(error_msg, "", 0)
    end
    local report = generate_report(metadata)
    ClearConsole()
    reaper.ShowConsoleMsg(report)

    Undo_EndBlock('DDP metadata report', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function parse_markers()
    local num_markers = reaper.CountProjectMarkers(0)
    local metadata = { album = {}, tracks = {} }
    local error_msg = ""

    -- First pass: Extract album-wide metadata
    for i = 0, num_markers - 1 do
        local _, isrgn, _, _, name, _ = reaper.EnumProjectMarkers(i)
        if not isrgn then -- Only process markers
            local album_marker = name:match("^@(.-)|")
            if album_marker then
                metadata.album = {
                    title = album_marker,
                    catalog = name:match("CATALOG=([^|]+)") or name:match("EAN=([^|]+)") or name:match("UPC=([^|]+)") or
                        nil,
                    performer = name:match("PERFORMER=([^|]+)") or nil,
                    songwriter = name:match("SONGWRITER=([^|]+)") or nil,
                    composer = name:match("COMPOSER=([^|]+)") or nil,
                    arranger = name:match("ARRANGER=([^|]+)") or nil,
                    message = name:match("MESSAGE=([^|]+)") or nil,
                    identification = name:match("IDENTIFICATION=([^|]+)") or nil,
                    genre = name:match("GENRE=([^|]+)") or nil,
                    language = name:match("LANGUAGE=([^|]+)") or nil
                }
                break -- Stop early after finding album metadata
            end
        end
    end

    -- Second pass: Process track markers
    for i = 0, num_markers - 1 do
        local _, isrgn, _, _, name, _ = reaper.EnumProjectMarkers(i)
        if not isrgn then                -- Only process markers
            if not name:match("^@") then -- Ignore album line since it's already processed
                local track_title = name:match("^#([^|]+)")
                if track_title then
                    local track_data = {
                        title = track_title,
                        isrc = name:match("ISRC=([^|]+)") or nil,
                        performer = name:match("PERFORMER=([^|]+)") or nil,
                        songwriter = name:match("SONGWRITER=([^|]+)") or nil,
                        composer = name:match("COMPOSER=([^|]+)") or nil,
                        arranger = name:match("ARRANGER=([^|]+)") or nil,
                        message = name:match("MESSAGE=([^|]+)") or nil
                    }

                    local missing_album_metadata = false

                    if track_data.performer ~= nil and metadata.album.performer == nil then
                        missing_album_metadata = true
                    end
                    if track_data.songwriter ~= nil and metadata.album.songwriter == nil then
                        missing_album_metadata = true
                    end
                    if track_data.composer ~= nil and metadata.album.composer == nil then
                        missing_album_metadata = true
                    end
                    if track_data.arranger ~= nil and metadata.album.arranger == nil then
                        missing_album_metadata = true
                    end

                    -- Assign error message to error_msg variable
                    if missing_album_metadata then
                        error_msg = "Note: One or more tracks specify " ..
                        "performer, songwriter, composer, or arranger\n" ..
                        "without an associated album-wide entry and " ..
                        "therefore won't currently be added to the DDP metadata."
                    end

                    table.insert(metadata.tracks, track_data)
                end
            end
        end
    end

    return metadata, error_msg
end

---------------------------------------------------------------------

function generate_report(metadata)
    local report = "CD Text Information\n===================\n"

    if metadata.album.language then
        report = report .. "  Language     : " .. metadata.album.language .. "\n"
    end

    if #metadata.tracks > 0 then
        report = report .. "  Tracks       : 1-" .. #metadata.tracks .. "\n"
    end

    if metadata.album.title or #metadata.tracks > 0 then
        report = report .. "  Title\n"
        if metadata.album.title then
            report = report .. "    Album : " .. metadata.album.title .. "\n"
        end
        for i, track in ipairs(metadata.tracks) do
            if track.title then
                report = report .. string.format("    Trk %02d: %s\n", i, track.title)
            end
        end
    end

    if metadata.album.performer or any(metadata.tracks, "performer") then
        report = report .. "  Performer\n"
        if metadata.album.performer then
            report = report .. "    Album : " .. metadata.album.performer .. "\n"
        end
        for i, track in ipairs(metadata.tracks) do
            if track.performer then
                report = report .. string.format("    Trk %02d: %s\n", i, track.performer)
            end
        end
    end

    if metadata.album.composer or any(metadata.tracks, "composer") then
        report = report .. "  Composer\n"
        if metadata.album.composer then
            report = report .. "    Album : " .. metadata.album.composer .. "\n"
        end
        for i, track in ipairs(metadata.tracks) do
            if track.composer then
                report = report .. string.format("    Trk %02d: %s\n", i, track.composer)
            end
        end
    end

    if metadata.album.songwriter or any(metadata.tracks, "songwriter") then
        report = report .. "  Songwriter\n"
        if metadata.album.songwriter then
            report = report .. "    Album : " .. metadata.album.songwriter .. "\n"
        end
        for i, track in ipairs(metadata.tracks) do
            if track.songwriter then
                report = report .. string.format("    Trk %02d: %s\n", i, track.songwriter)
            end
        end
    end

    if metadata.album.arranger or any(metadata.tracks, "arranger") then
        report = report .. "  Arranger\n"
        if metadata.album.arranger then
            report = report .. "    Album : " .. metadata.album.arranger .. "\n"
        end
        for i, track in ipairs(metadata.tracks) do
            if track.arranger then
                report = report .. string.format("    Trk %02d: %s\n", i, track.arranger)
            end
        end
    end

    if metadata.album.message or any(metadata.tracks, "message") then
        report = report .. "  Message\n"
        if metadata.album.message then
            report = report .. "    Album : " .. metadata.album.message .. "\n"
        end
        for i, track in ipairs(metadata.tracks) do
            if track.message then
                report = report .. string.format("    Trk %02d: %s\n", i, track.message)
            end
        end
    end

    if metadata.album.genre then
        report = report .. "  Genre\n    Detail: " .. metadata.album.genre .. "\n"
    end

    if metadata.album.identification then
        report = report .. "  Identification\n    Album : " .. metadata.album.identification .. "\n"
    end

    return report
end

function any(tracks, field)
    for _, track in ipairs(tracks) do
        if track[field] then return true end
    end
    return false
end

---------------------------------------------------------------------

main()
