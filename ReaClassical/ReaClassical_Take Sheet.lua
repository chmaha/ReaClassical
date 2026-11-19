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

local main, collect_project_takes, collect_disk_takes, parse_take_name
local format_duration, format_marker_time, csv_field, html_escape
local get_output_base, write_csv, write_html, sort_takes
local collect_edit_rows, build_edit_csv, build_csv, take_columns, build_edit_summary, format_clock

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say = require("ReaClassical_Announce")
local track_scan = require("ReaClassical_Track_Scan")
local global_take = require("ReaClassical_Global_Take")
local edit_list = require("ReaClassical_Edit_List")

set_action_options(2)

local RANK_NAMES = {
    "Excellent", "Very Good", "Good", "OK", "Below Average", "Poor", "Unusable", "False Start"
}

local AUDIO_EXTENSIONS = {
    wav = true, w64 = true, rf64 = true, bwf = true, flac = true,
    aif = true, aiff = true, mp3 = true, ogg = true, opus = true, wv = true,
}

local separator = package.config:sub(1, 1)

function main()
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

    local takes, order = collect_project_takes(workflow)
    collect_disk_takes(takes, order)

    if #order == 0 then
        MB("No recorded takes found in this project or its media folder.", "Take Sheet", 0)
        return
    end

    local rows = {}
    for _, key in ipairs(order) do rows[#rows + 1] = takes[key] end
    sort_takes(rows)

    local show_global = global_take.enabled()
    if not show_global then
        for _, row in ipairs(rows) do
            if row.global then show_global = true break end
        end
    end

    local include_private = MB("Include rankings, notes and item markers?\n\n"
        .. "Choose No for a version to share with artists or other people "
        .. "who should not see your internal comments.", "Take Sheet", 3)
    if include_private == 2 then return end
    include_private = (include_private == 6)

    local timing_choice = MB("Which timing should the edit list use?\n\n"
        .. "Yes = BWF start offset (timeclock-synced projects)\n"
        .. "No = Source file timing (times within each source file)", "Take Sheet", 3)
    if timing_choice == 2 then return end
    local edit_opts = { bwf = (timing_choice == 6), offset_frames = 0 }
    if edit_opts.bwf then edit_opts.offset_frames = edit_list.ask_offset() end

    local fps = TimeMap_curFrameRate(0)
    local edit_rows = collect_edit_rows(takes, fps, show_global, edit_opts)

    local cols = take_columns(show_global, include_private)
    local base = get_output_base() .. (include_private and "take_sheet" or "take_sheet_shared")
    local csv_path = base .. ".csv"
    local edit_csv_path = base .. "_edit_list.csv"
    local html_path = base .. ".html"

    if not write_csv(csv_path, build_csv(rows, cols))
        or not write_csv(edit_csv_path, build_edit_csv(edit_rows)) then
        MB("Failed to write " .. csv_path .. " or " .. edit_csv_path, "Take Sheet", 0)
        return
    end
    if not write_html(html_path, rows, cols, edit_rows, fps, edit_opts, include_private) then
        MB("Failed to write " .. html_path, "Take Sheet", 0)
        return
    end

    say("Take sheet created with " .. #rows .. " takes")
    if APIExists("CF_ShellExecute") then
        CF_ShellExecute(html_path)
    else
        MB("Take sheet written to:\n" .. html_path .. "\n" .. edit_csv_path .. "\n" .. csv_path, "Take Sheet", 0)
    end
end

function parse_take_name(name)
    local take_num = name:match("_T(%d+)[^_]*$")
    if not take_num then return nil, nil end
    local session
    if name:match("_[DS]%d*_[^_]+_T%d+") then
        session = name:match("^(.-)_[DS]%d*_")
    elseif name:match("^[DS]%d*_[^_]+_T%d+") then
        session = ""
    else
        session = name:match("^(.-)_[^_]+_T%d+") or ""
    end
    return session or "", tonumber(take_num)
end

local function file_basename(path)
    local file = path:match("([^\\/]+)$") or path
    return file, (file:match("(.+)%.[^.]+$") or file)
end

local function take_key(path)
    local _, stem = file_basename(path)
    local session, take_num = parse_take_name(stem)
    if take_num then
        return session:lower() .. "|" .. take_num, session, take_num
    end
    return "file|" .. path:lower(), nil, nil
end

local function read_source_info(source)
    local length = GetMediaSourceLength(source)
    local _, date = GetMediaFileMetadata(source, "BWF:OriginationDate")
    local _, time = GetMediaFileMetadata(source, "BWF:OriginationTime")
    local recorded = ""
    if date and date ~= "" then
        recorded = date .. ((time and time ~= "") and (" " .. time) or "")
    end
    return length, recorded
end

local function read_item_details(item, take)
    local _, rank_str = GetSetMediaItemInfo_String(item, "P_EXT:item_rank", "", false)
    local rank_num = tonumber(rank_str)
    local _, notes = GetSetMediaItemInfo_String(item, "P_NOTES", "", false)

    local markers = {}
    for m = 0, GetNumTakeMarkers(take) - 1 do
        local srcpos, name = GetTakeMarker(take, m)
        if srcpos and srcpos >= 0 and name ~= "S-AUD" then
            local label = format_marker_time(srcpos)
            if name and name ~= "" then label = label .. " " .. name end
            markers[#markers + 1] = label
        end
    end

    return {
        rank = rank_num and RANK_NAMES[rank_num] or "",
        notes = notes or "",
        markers = table.concat(markers, "; "),
        global = global_take.get(item),
    }
end

function collect_project_takes(workflow)
    local takes, order = {}, {}
    local cache = track_scan.build()

    for _, folder in ipairs(cache.folders) do
        local track = folder.track
        local _, track_name = GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local is_dest = track_name:match("^D:") ~= nil

        for i = 0, CountTrackMediaItems(track) - 1 do
            local item = GetTrackMediaItem(track, i)
            local take = GetActiveTake(item)
            if take and not TakeIsMIDI(take) then
                local source = GetMediaItemTake_Source(take)
                local parent_source = GetMediaSourceParent(source)
                if parent_source then source = parent_source end
                local path = GetMediaSourceFileName(source, "")
                if path ~= "" then
                    local key, session, take_num = take_key(path)
                    local _, sd = GetSetMediaItemInfo_String(item, "P_EXT:SD", "", false)
                    local is_edit_copy = (sd == "y")
                    local used = is_edit_copy or (workflow == "Vertical" and is_dest)

                    local entry = takes[key]
                    if not entry then
                        local length, recorded = read_source_info(source)
                        local file = file_basename(path)
                        entry = {
                            file = file,
                            session = session or "",
                            take_num = take_num,
                            duration = length,
                            recorded = recorded,
                            used = false,
                            in_project = true,
                            master_is_original = false,
                            rank = "", notes = "", markers = "", global = nil,
                        }
                        takes[key] = entry
                        order[#order + 1] = key
                    end

                    if used then entry.used = true end

                    if not entry.master_is_original and (not entry.has_master or not is_edit_copy) then
                        local details = read_item_details(item, take)
                        entry.rank = details.rank
                        entry.notes = details.notes
                        entry.markers = details.markers
                        entry.global = details.global or entry.global
                        entry.has_master = true
                        entry.master_is_original = not is_edit_copy
                    elseif not entry.global then
                        entry.global = global_take.get(item)
                    end
                end
            end
        end
    end

    return takes, order
end

function collect_disk_takes(takes, order)
    local media_path = GetProjectPath(0)
    if not media_path or media_path == "" then return end

    local function scan_dir(dir)
        local i = 0
        while true do
            local file = EnumerateFiles(dir, i)
            if not file then break end
            local ext = (file:match("%.([^.]+)$") or ""):lower()
            if AUDIO_EXTENSIONS[ext] then
                local path = dir .. separator .. file
                local key, session, take_num = take_key(path)
                if take_num and not takes[key] then
                    local length, recorded = 0, ""
                    local source = PCM_Source_CreateFromFile(path)
                    if source then
                        length, recorded = read_source_info(source)
                        PCM_Source_Destroy(source)
                    end
                    takes[key] = {
                        file = file,
                        session = session,
                        take_num = take_num,
                        duration = length,
                        recorded = recorded,
                        used = false,
                        in_project = false,
                        rank = "", notes = "", markers = "", global = nil,
                    }
                    order[#order + 1] = key
                end
            end
            i = i + 1
        end
    end

    scan_dir(media_path)
    local d = 0
    while true do
        local sub = EnumerateSubdirectories(media_path, d)
        if not sub then break end
        scan_dir(media_path .. separator .. sub)
        d = d + 1
    end
end

function collect_edit_rows(takes, fps, show_global, edit_opts)
    local dest_track
    for _, folder in ipairs(track_scan.build().folders) do
        local _, name = GetSetMediaTrackInfo_String(folder.track, "P_NAME", "", false)
        if name:match("^D:") then
            dest_track = folder.track
            break
        end
    end
    dest_track = dest_track or GetTrack(0, 0)

    local edit_rows = edit_list.build(dest_track, fps, edit_opts)
    for _, row in ipairs(edit_rows) do
        row.take_label = ""
        if row.path then
            local entry = takes[take_key(row.path)]
            if entry then
                local parts = {}
                if show_global and entry.global then parts[#parts + 1] = "G" .. entry.global end
                if entry.session ~= "" then parts[#parts + 1] = entry.session end
                if entry.take_num then parts[#parts + 1] = "T" .. entry.take_num end
                row.take_label = table.concat(parts, " ")
            end
        end
    end
    return edit_rows
end

function sort_takes(rows)
    table.sort(rows, function(a, b)
        if a.global and b.global and a.global ~= b.global then return a.global < b.global end
        if a.global and not b.global then return true end
        if b.global and not a.global then return false end
        if a.session:lower() ~= b.session:lower() then return a.session:lower() < b.session:lower() end
        if (a.take_num or 0) ~= (b.take_num or 0) then return (a.take_num or 0) < (b.take_num or 0) end
        return a.file:lower() < b.file:lower()
    end)
end

function format_duration(seconds)
    seconds = math.floor((seconds or 0) + 0.5)
    local h = seconds // 3600
    local m = (seconds % 3600) // 60
    local s = seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

function format_marker_time(seconds)
    local whole = math.floor(seconds)
    return string.format("%d:%02d", whole // 60, whole % 60)
end

function csv_field(value)
    local s = tostring(value or "")
    if s:find('[,"\r\n]') then
        s = '"' .. s:gsub('"', '""') .. '"'
    end
    return s
end

function html_escape(value, keep_newlines)
    local s = tostring(value or "")
    s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    if not keep_newlines then
        s = s:gsub("\r?\n", "<br>")
    end
    return s
end

function take_columns(show_global, include_private)
    local cols = {}
    local function add(name, get, class) cols[#cols + 1] = { name = name, get = get, class = class } end
    if show_global then add("Global Take", function(r) return r.global or "" end) end
    add("Session", function(r) return r.session ~= "" and r.session or "—" end)
    add("Take", function(r) return r.take_num or "" end)
    if include_private then
        add("Rank", function(r) return r.rank end)
        add("Notes", function(r) return r.notes end, "notes")
        add("Item Markers", function(r) return r.markers end)
    end
    add("Duration", function(r) return format_duration(r.duration) end)
    add("Recorded", function(r) return r.recorded end)
    add("Used in Edit", function(r) return r.used and "Yes" or "No" end)
    add("In Project", function(r) return r.in_project and "Yes" or "No" end)
    add("Source File", function(r) return r.file end)
    return cols
end

function build_csv(rows, cols)
    local lines = {}
    local header_fields = {}
    for _, col in ipairs(cols) do header_fields[#header_fields + 1] = csv_field(col.name) end
    lines[1] = table.concat(header_fields, ",")
    for _, row in ipairs(rows) do
        local fields = {}
        for _, col in ipairs(cols) do fields[#fields + 1] = csv_field(col.get(row)) end
        lines[#lines + 1] = table.concat(fields, ",")
    end
    return table.concat(lines, "\n") .. "\n"
end

local EDIT_HEADERS = { "Edit", "Start", "Take", "Source Filename", "Source In", "Source Out",
    "End Check", "Playback Rate" }

local function edit_row_values(row)
    return { row.edit_number, row.position, row.take_label or "", row.filename,
        row.s_in, row.s_out, row.dest_end, row.playrate }
end

function format_clock(seconds)
    local whole = math.max(0, math.floor((seconds or 0) + 0.5))
    local h = whole // 3600
    local m = (whole % 3600) // 60
    local sec = whole % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%d:%02d", m, sec)
end

function build_edit_summary(edit_rows)
    local segments = {}
    local current
    for _, row in ipairs(edit_rows) do
        if row.edit_number == "Gap" or not row.start_sec then
            current = nil
        else
            local label = row.take_label ~= "" and row.take_label or (row.path or ""):match("([^\\/]+)$") or ""
            if current and current.label == label and math.abs(row.start_sec - current.to) < 0.05 then
                current.to = row.end_sec
            else
                current = { from = row.start_sec, to = row.end_sec, label = label }
                segments[#segments + 1] = current
            end
        end
    end
    return segments
end

function build_edit_csv(edit_rows)
    local lines = {}
    local header_fields = {}
    for _, name in ipairs(EDIT_HEADERS) do header_fields[#header_fields + 1] = csv_field(name) end
    lines[1] = table.concat(header_fields, ",")
    for _, row in ipairs(edit_rows) do
        local fields = {}
        for _, v in ipairs(edit_row_values(row)) do fields[#fields + 1] = csv_field(v) end
        lines[#lines + 1] = table.concat(fields, ",")
    end
    return table.concat(lines, "\n") .. "\n"
end

function write_csv(path, text)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(text)
    file:close()
    return true
end

function write_html(path, rows, cols, edit_rows, fps, edit_opts, include_private)
    local file = io.open(path, "w")
    if not file then return nil end

    local csv = build_csv(rows, cols)
    local edit_csv = build_edit_csv(edit_rows)
    local project_name = GetProjectName(0)
    if project_name == "" then project_name = "Untitled" end
    local used_count = 0
    for _, row in ipairs(rows) do if row.used then used_count = used_count + 1 end end

    file:write([[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Take Sheet</title>
<style>
    body { font-family: Arial, sans-serif; margin: 20px; padding: 0; }
    h2 { margin-bottom: 5px; }
    p { font-size: 15px; color: #555; margin: 4px 0; }
    table { border-collapse: collapse; width: 100%; margin-top: 15px; }
    th, td { border: 1px solid black; padding: 5px; text-align: center; vertical-align: top; }
    th { background-color: #f2f2f2; position: sticky; top: 0; }
    td.notes { text-align: left; max-width: 360px; }
    tr.unused { color: #777; }
    tr.missing { background-color: #eeeeee; color: #888; }
    tr.gap-row { background-color: #e0e0e0; }
    h3 { margin-top: 35px; }
    .controls { margin-top: 12px; }
    details { margin-top: 18px; }
    summary { font-size: 17px; font-weight: bold; cursor: pointer; }
    summary span { font-weight: normal; color: #555; font-size: 15px; }
    table.summary-table { width: auto; min-width: 50%; }
    @media print {
        @page { size: landscape; margin: 1.2cm; }
        body { margin: 0; font-size: 10pt; }
        .controls, .nav, textarea { display: none !important; }
        th { position: static; }
        th, td { padding: 3px; }
        p { font-size: 10pt; }
        tr { break-inside: avoid; }
        thead { display: table-header-group; }
        #takes { break-before: page; }
        details { margin-top: 10px; }
        summary { list-style: none; font-size: 12pt; }
        summary::-webkit-details-marker { display: none; }
        .take-table tbody tr { display: table-row !important; }
    }
</style>
</head>
<body>
]])
    file:write("<h2>Take Sheet</h2>\n")
    file:write("<p><strong>Project:</strong> ", html_escape(project_name), "</p>\n")
    file:write("<p><strong>Date:</strong> ", os.date("%Y-%m-%d %H:%M"), "</p>\n")
    file:write(string.format("<p><strong>Takes:</strong> %d (%d used in edit)</p>\n", #rows, used_count))
    if not include_private then
        file:write("<p><em>Shared version: rankings, notes and item markers are not included.</em></p>\n")
    end
    file:write('<p class="nav"><a href="#edit-summary">Edit Summary</a> | <a href="#edit-list">Edit List</a>'
        .. ' | <a href="#takes">Takes</a></p>\n')

    file:write('<h3 id="edit-summary">Edit Summary</h3>\n')
    local segments = build_edit_summary(edit_rows)
    if #segments == 0 then
        file:write("<p>No items in the destination folder yet.</p>\n")
    else
        file:write("<p>Which take is heard at each point of the edit (minutes:seconds on the timeline).</p>\n")
        file:write('<table class="summary-table">\n<thead><tr><th>From</th><th>To</th><th>Take</th></tr></thead>\n<tbody>\n')
        for _, seg in ipairs(segments) do
            file:write("<tr><td>", format_clock(seg.from), "</td><td>", format_clock(seg.to), "</td><td>",
                html_escape(seg.label), "</td></tr>\n")
        end
        file:write("</tbody>\n</table>\n")
    end

    if edit_opts.bwf then
        file:write('<h3 id="edit-list">Edit List (using BWF Start Offset)</h3>\n')
    else
        file:write('<h3 id="edit-list">Edit List (using source file timing)</h3>\n')
    end
    if #edit_rows == 0 then
        file:write("<p>No items in the destination folder yet.</p>\n")
    else
        local source_desc = edit_opts.bwf and "absolute timecode references for the source material"
            or "times within the source file"
        file:write(string.format("<p><strong>Frame Rate:</strong> %s fps. Start and End Check are timeline "
            .. "positions; Source In and Source Out are %s (HH:MM:SS:FF). "
            .. "Playback rate is only shown if not equal to 1.</p>\n", tostring(fps), source_desc))
        if edit_opts.offset_frames ~= 0 then
            file:write(string.format('<p><strong style="color: red;">Using user offset of %+d frames</strong></p>\n',
                edit_opts.offset_frames))
        end
        file:write([[<div class="controls">
<button onclick="copyCsv('editCsvData', 'editCopyMessage')">Copy Edit List CSV to Clipboard</button>
<span id="editCopyMessage" style="color: green; margin-left: 10px;"></span>
</div>
<table>
<thead><tr>]])
        for _, name in ipairs(EDIT_HEADERS) do
            file:write("<th>", html_escape(name), "</th>")
        end
        file:write("</tr></thead>\n<tbody>\n")
        for _, row in ipairs(edit_rows) do
            if row.edit_number == "Gap" then
                file:write(string.format('<tr class="gap-row"><td colspan="%d">Gap</td></tr>\n', #EDIT_HEADERS))
            else
                file:write("<tr>")
                for _, v in ipairs(edit_row_values(row)) do
                    file:write("<td>", html_escape(v), "</td>")
                end
                file:write("</tr>\n")
            end
        end
        file:write("</tbody>\n</table>\n")
    end
    file:write('<textarea id="editCsvData" style="position:absolute;left:-9999px;">',
        html_escape(edit_csv, true), "</textarea>\n")
    file:write('<h3 id="takes">Takes</h3>\n')
    file:write([[<div class="controls">
<label><input type="checkbox" id="usedOnly" onclick="filterRows()"> Show only takes used in edit</label>
&nbsp;&nbsp;<button onclick="setGroups(true)">Expand All</button>
<button onclick="setGroups(false)">Collapse All</button>
&nbsp;&nbsp;<button onclick="copyCsv('csvData', 'copyMessage')">Copy CSV to Clipboard</button>
<span id="copyMessage" style="color: green; margin-left: 10px;"></span>
</div>
]])

    local groups, group_index = {}, {}
    for _, row in ipairs(rows) do
        local key = row.session:lower()
        local group = group_index[key]
        if not group then
            group = { name = row.session ~= "" and row.session or "No session", rows = {}, used = 0 }
            group_index[key] = group
            groups[#groups + 1] = group
        end
        group.rows[#group.rows + 1] = row
        if row.used then group.used = group.used + 1 end
    end

    for _, group in ipairs(groups) do
        file:write(string.format('<details open><summary>%s <span>(%d take%s, %d used in edit)</span></summary>\n',
            html_escape(group.name), #group.rows, #group.rows == 1 and "" or "s", group.used))
        file:write('<table class="take-table">\n<thead><tr>')
        for _, col in ipairs(cols) do
            file:write("<th>", html_escape(col.name), "</th>")
        end
        file:write("</tr></thead>\n<tbody>\n")
        for _, row in ipairs(group.rows) do
            local classes = {}
            if not row.used then classes[#classes + 1] = "unused" end
            if not row.in_project then classes[#classes + 1] = "missing" end
            file:write(string.format('<tr class="%s" data-used="%s">',
                table.concat(classes, " "), row.used and "1" or "0"))
            for _, col in ipairs(cols) do
                if col.class then
                    file:write('<td class="', col.class, '">', html_escape(col.get(row)), "</td>")
                else
                    file:write("<td>", html_escape(col.get(row)), "</td>")
                end
            end
            file:write("</tr>\n")
        end
        file:write("</tbody>\n</table>\n</details>\n")
    end

    file:write('<textarea id="csvData" style="position:absolute;left:-9999px;">', html_escape(csv, true),
        "</textarea>\n")
    file:write([[<script>
function filterRows() {
    var usedOnly = document.getElementById("usedOnly").checked;
    document.querySelectorAll(".take-table tbody tr").forEach(function(row) {
        row.style.display = (usedOnly && row.dataset.used !== "1") ? "none" : "";
    });
}
function setGroups(open) {
    document.querySelectorAll("details").forEach(function(d) { d.open = open; });
}
var printState = [];
window.addEventListener("beforeprint", function() {
    printState = [];
    document.querySelectorAll("details").forEach(function(d) { printState.push(d.open); d.open = true; });
});
window.addEventListener("afterprint", function() {
    document.querySelectorAll("details").forEach(function(d, i) { d.open = printState[i]; });
});
function copyCsv(sourceId, messageId) {
    var text = document.getElementById(sourceId).value;
    navigator.clipboard.writeText(text).then(function() {
        var message = document.getElementById(messageId);
        message.innerText = "CSV copied to clipboard!";
        setTimeout(function() { message.innerText = ""; }, 3000);
    });
}
</script>
</body>
</html>
]])
    file:close()
    return true
end

function get_output_base()
    local _, path = EnumProjects(-1)
    if path == "" then
        path = GetProjectPath(0)
    else
        path = path:match("(.+)[\\/][^\\/]+$") or GetProjectPath(0)
    end
    return path .. separator
end

main()
