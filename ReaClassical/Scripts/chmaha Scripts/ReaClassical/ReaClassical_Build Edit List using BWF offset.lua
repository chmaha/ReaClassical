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
local main, build_item_table, format_timecode, get_html_file
local parse_timecode, get_offset

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
    local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
    if workflow == "" then
        MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
        return
    end

    local offset = get_offset()

    local project_name = GetProjectName(0)
    local fps = TimeMap_curFrameRate(0)
    local date = os.date("%y-%m-%d %H:%M:%S")
    local items = build_item_table(fps, offset)

    -- Initialize CSV variable with the header row
    local csv = "Edit,Start,Source In,Source Out,End Check,Playback Rate\n"
    -- Append each item's data to the CSV variable
    for _, item in ipairs(items) do
        csv = csv .. string.format("%s,%s,%s,%s,%s,%s\n",
            item.edit_number,
            item.position,
            item.s_in,
            item.s_out,
            item.dest_end,
            item.playrate
        )
    end

    -- Write HTML content
    local file_path = get_html_file()
    local file = io.open(file_path, "w")
    if not file then
        MB("Failed to create HTML file.", "Error", 0)
        return
    end

    file:write([[
        <html>
        <head>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; padding: 0; }
            .container { width: 75%; margin: auto; text-align: left; } /* Centers the section but aligns text left */
            h1 { font-size: 24px; margin-bottom: 5px; }
            p { font-size: 16px; color: #555; margin-bottom: 10px; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid black; padding: 5px; text-align: center; }
            th { background-color: #f2f2f2; }
            .gap-row { background-color: #e0e0e0; } /* Light gray */
            .disabled-row { background-color: #d0d0d0 !important; color: #777 !important; } /* Greyed out */
            .label { font-size: 0.9em;font-weight: bold; color: #333; }
            .description { font-size: 0.9em; color: #555; }
            input[type="checkbox"] { cursor: pointer; }
        </style>
        <script>
        function toggleRow(checkbox) {
            let row = checkbox.closest("tr");
            if (checkbox.checked) {
                row.classList.add("disabled-row");
            } else {
                row.classList.remove("disabled-row");
            }
        }
        </script>
        </head>
        <body>
        ]])

    file:write("<div class='info'>\n")
    file:write("  <h2>Edit List (using BWF Start Offset)</h2>\n")
    file:write("  <p><strong>Project Name:</strong> ", (project_name or "Untitled"), "</p>\n")
    file:write("  <p><strong>Date:</strong> ", (date), "</p>\n")
    file:write("  <p><strong>Frame Rate:</strong> ", (fps or "Unknown"), "</p>\n")
    file:write(
        [[<p><span class="label">Start:</span>
            <span class="description">Absolute timeline location for building the edit</span><br>
            <span class="label">Source In and Source Out:</span>
            <span class="description">Absolute timecode references for source material</span><br>
            <span class="label">End:</span>
            <span class="description">
            A reference check for where the inserted material ends on the timeline after the 3-point edit
            </span><br>
            <span class="label">Playback rate:</span>
            <span class="description">Only shown if not equal to 1</span><br>
            <span class="description"><br>Time is in the format HH:MM:SS:FF</span></p>]])
    if offset ~= 0 then
        file:write(string.format(
            '<p><strong style="color: red;">Using user offset of %+d frames</strong></p>\n', offset))
    end
    file:write("</div>\n")

    file:write([[<table>
            <thead>
                <tr>
                    <th>Done</th>
                    <th>Edit</th>
                    <th>Start</th>
                    <th>Source In</th>
                    <th>Source Out</th>
                    <th>End Check</th>
                    <th>Playback Rate</th>
                </tr>
            </thead>
            <tbody>
        ]])

    -- Append table rows from items
    for _, item in ipairs(items) do
        if item.edit_number == "Gap" then
            file:write(string.format('<tr class="gap-row"><td colspan="8">%s</td></tr>\n', item.edit_number))
        else
            file:write(string.format(
                '<tr><td><input type="checkbox" onclick="toggleRow(this)"></td><td>%s</td>' ..
                '<td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n',
                item.edit_number, item.position, item.s_in, item.s_out, item.dest_end, item.playrate
            ))
        end
    end

    file:write([[</tbody></table>


    <div style="margin-top: 20px;">
        <textarea id="csvData" style="position:absolute;left:-9999px;">]] .. csv .. [[</textarea>
        <button class="copy-btn" onclick="copyToClipboard()">Copy CSV Table Data to Clipboard</button>
        <p id="copyMessage" style="margin-top: 10px; font-size: 14px; color: green;"></p> <!-- Message appears here -->
    </div>

<script>
    function copyToClipboard() {
        var copyText = document.getElementById("csvData");

        navigator.clipboard.writeText(copyText.value).then(function() {
            var message = document.getElementById("copyMessage");
            message.innerText = "CSV copied to clipboard!";

            // Clear message after 3 seconds
            setTimeout(function() {
                message.innerText = "";
            }, 3000);
        }).catch(function(err) {
            console.error("Failed to copy: ", err);
        });
    }
</script>

</div>
</body>
</html>
]])

    file:close()


    -- Open in default web browser
    CF_ShellExecute(file_path)

    Undo_EndBlock('Build Edit List', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

-- Function to format timecode
function format_timecode(seconds, fps, offset_frames)
    local total_frames = math.floor(seconds * fps) + offset_frames
    local h = math.floor(total_frames / (3600 * fps))
    local m = math.floor((total_frames % (3600 * fps)) / (60 * fps))
    local s = math.floor((total_frames % (60 * fps)) / fps)
    local f = total_frames % fps
    return string.format("%02d:%02d:%02d:%02d", h, m, s, f)
end

---------------------------------------------------------------------

-- Function to build the item table
function build_item_table(fps, offset)
    local item_table = {}
    local track = GetTrack(0, 0) -- Default to first track

    if not track then return item_table end

    local time_sel_start, time_sel_end = GetSet_LoopTimeRange(false, false, 0, 0, false)
    local has_time_sel = (time_sel_end > time_sel_start)

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

        local retval, bwf_offset_str = GetMediaFileMetadata(source, "Generic:StartOffset")
        local bwf_offset = (retval and bwf_offset_str ~= "") and parse_timecode(bwf_offset_str) or 0

        local item_offset = GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")

        local start_offset = bwf_offset + item_offset

        -- Determine end time
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
            position = format_timecode(position, fps, offset),
            filename = filename,
            s_in = format_timecode(start_offset, fps, offset),
            s_out = format_timecode(end_offset, fps, offset),
            dest_end = format_timecode(position + source_length, fps, offset),
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

---------------------------------------------------------------------

function get_html_file()
    local _, path = EnumProjects(-1)
    local slash = package.config:sub(1, 1)
    if path == "" then
        path = GetProjectPath()
    else
        local pattern = "(.+)" .. slash .. ".+[.][Rr][Pp][Pp]"
        path = path:match(pattern)
    end
    local file = path .. slash .. 'edit_list_bwfso.html'
    return file
end

---------------------------------------------------------------------

function parse_timecode(timecode)
    local h, m, s = timecode:match("^(%d+):(%d+):([%d%.]+)$")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end

    m, s = timecode:match("^(%d+):([%d%.]+)$")
    if m then
        return tonumber(m) * 60 + tonumber(s)
    end

    return tonumber(timecode) or 0 -- Fallback if just seconds are provided
end

---------------------------------------------------------------------

function get_offset()
    local retval, input = GetUserInputs("Frame Offset", 1, "Enter offset (frames):", "0")
    if retval then
        return tonumber(input) or 0
    end
    return 0 -- Default if cancelled or invalid input
end

---------------------------------------------------------------------

main()
