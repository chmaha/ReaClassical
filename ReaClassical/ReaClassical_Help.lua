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

local main, get_manual_path, load_markdown_file, filename_to_title, load_image
local scan_manual_files, generate_main_menu, get_page, get_page_with_fallback
local parse_markdown_line, parse_inline, parse_markdown, parse_table, render_inline_segments
local render_markdown_element, render_main_menu_columns, navigate_to, navigate_back, navigate_forward

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('ReaClassical Help System')
local window_open = true

local DEFAULT_W = 800
local DEFAULT_H = 760

-- Navigation state
local current_page = "main_menu"
local page_history = { "main_menu" }
local history_index = 1

-- Scroll position memory for each page
local scroll_positions = {}

-- Image cache
local image_cache = {}

local manual_path = nil
local pages = {}

---------------------------------------------------------------------

function main()
    if not window_open then
        return
    end

    local _, FLT_MAX = ImGui.NumericLimits_Float()
    ImGui.SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, FLT_MAX, FLT_MAX)

    local visible, open = ImGui.Begin(ctx, "ReaClassical Help System", true)
    window_open = open

    if visible then
        local page = get_page_with_fallback(current_page)

        -- Navigation buttons
        if ImGui.Button(ctx, "←", 40, 0) then
            navigate_back()
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Back")
        end

        ImGui.SameLine(ctx)

        if ImGui.Button(ctx, "→", 40, 0) then
            navigate_forward()
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Forward")
        end

        ImGui.SameLine(ctx)

        if ImGui.Button(ctx, "⌂", 40, 0) then
            navigate_to("main_menu")
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Home")
        end

        ImGui.SameLine(ctx)
        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + 20)
        ImGui.Text(ctx, page.title)

        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- Render page content
        local elements = parse_markdown(page.content)

        -- Special rendering for main_menu page with columns
        if current_page == "main_menu" then
            render_main_menu_columns(elements)
        else
            for _, element in ipairs(elements) do
                render_markdown_element(element)
            end
        end

        ImGui.End(ctx)
    end

    defer(main)
end

---------------------------------------------------------------------

function get_manual_path()
    if manual_path then return manual_path end

    local resource_path = GetResourcePath()
    local pathseparator = package.config:sub(1, 1)
    manual_path = resource_path .. table.concat(
        { "", "Scripts", "chmaha Scripts", "ReaClassical", "manual", "" },
        pathseparator
    )
    return manual_path
end

---------------------------------------------------------------------

function load_markdown_file(page_id)
    local filepath = get_manual_path() .. page_id .. ".md"
    local file = io.open(filepath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        return content
    end
    return nil
end

---------------------------------------------------------------------

function filename_to_title(filename)
    -- Remove .md extension if present
    filename = filename:gsub("%.md$", "")
    -- Replace underscores with spaces
    filename = filename:gsub("_", " ")
    -- Capitalize first letter of each word
    return filename:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

---------------------------------------------------------------------

function scan_manual_files()
    local files = {}
    local path = get_manual_path()

    -- Try to enumerate files in directory
    local i = 0
    while true do
        local retval, filename = EnumerateFiles(path, i)
        if not retval then break end

        if filename:match("%.md$") and filename ~= "main_menu.md" then
            local page_id = filename:gsub("%.md$", "")
            table.insert(files, page_id)
        end

        i = i + 1
    end

    return files
end

---------------------------------------------------------------------

function generate_main_menu()
    -- Try to load main_menu.md first - this gives full manual control
    local content = load_markdown_file("main_menu")

    if content then
        return content
    end

    -- If no main_menu.md exists, provide a helpful default
    return [[

Welcome to the ReaClassical help documentation.

**Note**: Create a `main_menu.md` file in the `manual` folder to customize this page.

For now, here are the available help files:

]] .. table.concat(
        (function()
            local files = scan_manual_files()
            local lines = {}
            for _, page_id in ipairs(files) do
                local title = filename_to_title(page_id)
                table.insert(lines, "- [" .. title .. "](" .. page_id .. ")")
            end
            return lines
        end)(),
        "\n"
    ) .. "\n\n---\n\n**Tip**: Use the ← and → buttons to navigate between pages you've visited.\n"
end

---------------------------------------------------------------------

function get_page(page_id)
    -- Return cached page if available
    if pages[page_id] then
        return pages[page_id]
    end

    -- Special handling for main menu
    if page_id == "main_menu" then
        local content = generate_main_menu()

        pages[page_id] = {
            title = "Main Menu",
            content = content
        }
        return pages[page_id]
    end

    -- Try to load the markdown file
    local content = load_markdown_file(page_id)
    if content then
        -- Extract title from first H1 or use filename
        local title = content:match("^#%s+(.-)%s*\n") or filename_to_title(page_id)

        pages[page_id] = {
            title = title,
            content = content
        }
        return pages[page_id]
    end

    -- Page not found
    return nil
end

---------------------------------------------------------------------

function get_page_with_fallback(page_id)
    local page = get_page(page_id)
    if page then
        return page
    end

    -- Return a "not found" page
    return {
        title = "Page Not Found",
        content = "# Page Not Found\n\nThe page '" ..
        page_id .. "' could not be found.\n\n[Return to Main Menu](main_menu)"
    }
end

---------------------------------------------------------------------

function parse_markdown_line(line)
    local elements = {}

    -- Check for headers (H1-H6)
    local header_level = line:match("^(#+)%s")
    if header_level then
        local text = line:match("^#+%s+(.+)$")
        table.insert(elements, {
            type = "header",
            level = #header_level,
            text = text or ""
        })
        return elements
    end

    -- Check for horizontal rule
    if line:match("^%-%-%-+$") or line:match("^%*%*%*+$") or line:match("^___+$") then
        table.insert(elements, { type = "hr" })
        return elements
    end

    -- Check for blockquote
    if line:match("^>%s") then
        local text = line:match("^>%s+(.+)$") or ""
        table.insert(elements, {
            type = "blockquote",
            text = text
        })
        return elements
    end

    -- Check for unordered list
    if line:match("^[%s]*[%-%*%+]%s") then
        local indent = #(line:match("^(%s*)") or "")
        local text = line:match("^%s*[%-%*%+]%s+(.+)$") or ""
        table.insert(elements, {
            type = "list_unordered",
            text = text,
            indent = math.floor(indent / 2)
        })
        return elements
    end

    -- Check for ordered list
    if line:match("^[%s]*%d+%.%s") then
        local indent = #(line:match("^(%s*)") or "")
        local num = line:match("^%s*(%d+)%.")
        local text = line:match("^%s*%d+%.%s+(.+)$") or ""
        table.insert(elements, {
            type = "list_ordered",
            text = text,
            number = tonumber(num),
            indent = math.floor(indent / 2)
        })
        return elements
    end

    -- Check for code block markers
    if line:match("^```") then
        table.insert(elements, { type = "code_fence" })
        return elements
    end

    -- Regular paragraph - parse inline elements
    if line:match("%S") then
        table.insert(elements, {
            type = "paragraph",
            text = line
        })
    else
        table.insert(elements, { type = "blank" })
    end

    return elements
end

---------------------------------------------------------------------

function parse_inline(text)
    local segments = {}
    local pos = 1

    while pos <= #text do
        -- Try to match various inline patterns
        local found = false

        -- Bold + Italic (***text*** or ___text___)
        local bold_italic_start, bold_italic_end, bold_italic_text = text:find("%*%*%*(.-)%*%*%*", pos)
        if not bold_italic_start then
            bold_italic_start, bold_italic_end, bold_italic_text = text:find("___(.-)___", pos)
        end

        -- Bold (**text** or __text__)
        local bold_start, bold_end, bold_text = text:find("%*%*(.-)%*%*", pos)
        if not bold_start then
            bold_start, bold_end, bold_text = text:find("__(.-)__", pos)
        end

        -- Italic (*text* or _text_)
        local italic_start, italic_end, italic_text = text:find("%*(.-)%*", pos)
        if not italic_start then
            italic_start, italic_end, italic_text = text:find("_(.-)_", pos)
        end

        -- Inline code (`code`)
        local code_start, code_end, code_text = text:find("`([^`]-)`", pos)

        -- Links [text](url)
        local link_start, link_end, link_text, link_url = text:find("%[(.-)%]%((.-)%)", pos)

        -- Images ![alt](url)
        local img_start, img_end, img_alt, img_url = text:find("!%[(.-)%]%((.-)%)", pos)

        -- Find the earliest match
        local earliest = math.huge
        local match_type = nil
        local match_start, match_end, match_data = nil, nil, nil

        if img_start and img_start < earliest then
            earliest = img_start
            match_type = "image"
            match_start, match_end = img_start, img_end
            match_data = { alt = img_alt, url = img_url }
        end

        if link_start and link_start < earliest then
            earliest = link_start
            match_type = "link"
            match_start, match_end = link_start, link_end
            match_data = { text = link_text, url = link_url }
        end

        if code_start and code_start < earliest then
            earliest = code_start
            match_type = "code"
            match_start, match_end = code_start, code_end
            match_data = code_text
        end

        if bold_italic_start and bold_italic_start < earliest then
            earliest = bold_italic_start
            match_type = "bold_italic"
            match_start, match_end = bold_italic_start, bold_italic_end
            match_data = bold_italic_text
        end

        if bold_start and bold_start < earliest and (not bold_italic_start or bold_start ~= bold_italic_start) then
            earliest = bold_start
            match_type = "bold"
            match_start, match_end = bold_start, bold_end
            match_data = bold_text
        end

        if italic_start and italic_start < earliest and (not bold_start or italic_start ~= bold_start) and (not bold_italic_start or italic_start ~= bold_italic_start) then
            earliest = italic_start
            match_type = "italic"
            match_start, match_end = italic_start, italic_end
            match_data = italic_text
        end

        if match_type then
            -- Add any plain text before the match
            if match_start > pos then
                table.insert(segments, {
                    type = "text",
                    text = text:sub(pos, match_start - 1)
                })
            end

            -- Add the matched element
            if match_type == "image" then
                table.insert(segments, {
                    type = "image",
                    alt = match_data.alt,
                    url = match_data.url
                })
            elseif match_type == "link" then
                table.insert(segments, {
                    type = "link",
                    text = match_data.text,
                    url = match_data.url
                })
            elseif match_type == "code" then
                table.insert(segments, {
                    type = "code",
                    text = match_data
                })
            elseif match_type == "bold" then
                table.insert(segments, {
                    type = "bold",
                    text = match_data
                })
            elseif match_type == "italic" then
                table.insert(segments, {
                    type = "italic",
                    text = match_data
                })
            elseif match_type == "bold_italic" then
                table.insert(segments, {
                    type = "bold_italic",
                    text = match_data
                })
            end

            pos = match_end + 1
            found = true
        else
            -- No more matches, add remaining text
            table.insert(segments, {
                type = "text",
                text = text:sub(pos)
            })
            break
        end
    end

    return segments
end

---------------------------------------------------------------------

function parse_markdown(content)
    local lines = {}
    for line in content:gmatch("[^\r\n]*") do
        table.insert(lines, line)
    end

    local elements = {}
    local in_code_block = false
    local code_block_lines = {}
    local in_table = false
    local table_lines = {}

    for i, line in ipairs(lines) do
        -- Handle code blocks
        if line:match("^```") then
            if in_code_block then
                -- End code block
                table.insert(elements, {
                    type = "code_block",
                    lines = code_block_lines
                })
                code_block_lines = {}
                in_code_block = false
            else
                -- Start code block
                in_code_block = true
            end
        elseif in_code_block then
            table.insert(code_block_lines, line)
        else
            -- Check for table
            if line:match("^|.+|$") then
                if not in_table then
                    in_table = true
                    table_lines = {}
                end
                table.insert(table_lines, line)
            else
                -- End table if we were in one
                if in_table then
                    table.insert(elements, {
                        type = "table",
                        lines = table_lines
                    })
                    table_lines = {}
                    in_table = false
                end

                -- Parse regular line
                local line_elements = parse_markdown_line(line)
                for _, elem in ipairs(line_elements) do
                    table.insert(elements, elem)
                end
            end
        end
    end

    -- Handle any remaining table
    if in_table and #table_lines > 0 then
        table.insert(elements, {
            type = "table",
            lines = table_lines
        })
    end

    return elements
end

---------------------------------------------------------------------

function parse_table(lines)
    local rows = {}
    local is_header = true

    for _, line in ipairs(lines) do
        -- Skip separator lines (|---|---|)
        if not line:match("^|[%-%s|:]+|$") then
            local cells = {}
            -- Split by | and trim
            for cell in line:gmatch("|([^|]*)") do
                local trimmed = cell:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    table.insert(cells, trimmed)
                end
            end

            if #cells > 0 then
                table.insert(rows, {
                    cells = cells,
                    is_header = is_header
                })
            end
            is_header = false
        end
    end

    return rows
end

---------------------------------------------------------------------

function render_inline_segments(segments)
    for i, segment in ipairs(segments) do
        if segment.type == "text" then
            ImGui.Text(ctx, segment.text)
        elseif segment.type == "bold" then
            -- Simulate bold by drawing text multiple times with slight offset
            local x, y = ImGui.GetCursorPos(ctx)
            ImGui.Text(ctx, segment.text)
            ImGui.SetCursorPos(ctx, x + 0.5, y)
            ImGui.Text(ctx, segment.text)
            ImGui.SetCursorPos(ctx, x + ImGui.CalcTextSize(ctx, segment.text), y)
        elseif segment.type == "italic" then
            -- Can't do true italics, but we can use color
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x888888FF)
            ImGui.Text(ctx, segment.text)
            ImGui.PopStyleColor(ctx)
        elseif segment.type == "bold_italic" then
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x666666FF)
            local x, y = ImGui.GetCursorPos(ctx)
            ImGui.Text(ctx, segment.text)
            ImGui.SetCursorPos(ctx, x + 0.5, y)
            ImGui.Text(ctx, segment.text)
            ImGui.SetCursorPos(ctx, x + ImGui.CalcTextSize(ctx, segment.text), y)
            ImGui.PopStyleColor(ctx)
        elseif segment.type == "code" then
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xFF6666FF)
            ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0x00000033)
            local x, y = ImGui.GetCursorPos(ctx)
            ImGui.SetCursorPos(ctx, x, y - 2)
            ImGui.Button(ctx, " " .. segment.text .. " ", 0, 0)
            ImGui.SetCursorPos(ctx, x + ImGui.CalcTextSize(ctx, " " .. segment.text .. " ") + 8, y)
            ImGui.PopStyleColor(ctx, 2)
        elseif segment.type == "link" then
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x4A90E2FF)
            ImGui.Text(ctx, segment.text)
            if ImGui.IsItemHovered(ctx) then
                ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_Hand)
                -- Draw underline
                local min_x, min_y = ImGui.GetItemRectMin(ctx)
                local max_x, max_y = ImGui.GetItemRectMax(ctx)
                local draw_list = ImGui.GetWindowDrawList(ctx)
                ImGui.DrawList_AddLine(draw_list, min_x, max_y, max_x, max_y, 0x4A90E2FF)
            end
            if ImGui.IsItemClicked(ctx) then
                navigate_to(segment.url)
            end
            ImGui.PopStyleColor(ctx)
        elseif segment.type == "image" then
            -- Try to load and display image
            local img = load_image(segment.url)
            if img then
                local img_w, img_h = ImGui.Image_GetSize(img)
                local avail_w = ImGui.GetContentRegionAvail(ctx)
                local scale = 1.0
                if img_w > avail_w - 20 then
                    scale = (avail_w - 20) / img_w
                end
                ImGui.Image(ctx, img, img_w * scale, img_h * scale)
            else
                ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0x888888FF)
                ImGui.Text(ctx, "[Image: " .. segment.alt .. "]")
                ImGui.PopStyleColor(ctx)
            end
        end

        -- Add SameLine except for last segment or if next segment is image
        if i < #segments then
            local next_seg = segments[i + 1]
            if next_seg.type ~= "image" then
                ImGui.SameLine(ctx, 0, 0)
            end
        end
    end
end

---------------------------------------------------------------------

function render_markdown_element(element)
    if element.type == "header" then
        -- Render headers with proper font scaling and bold text
        local font_scales = { 1.8, 1.5, 1.3, 1.15, 1.05, 1.0 } -- H1-H6 size multipliers
        local spacing_before = { 10, 8, 6, 5, 4, 3 }
        local spacing_after = { 6, 5, 4, 3, 2, 2 }
        local boldness = { 3, 3, 2, 2, 1, 1 } -- How many times to overdraw for bold effect

        local level = element.level
        local base_font_size = ImGui.GetFontSize(ctx)
        local scaled_size = base_font_size * font_scales[level]

        -- Add spacing before header
        for i = 1, spacing_before[level] or 2 do
            ImGui.Spacing(ctx)
        end

        -- Push scaled font
        ImGui.PushFont(ctx, nil, scaled_size)

        -- Make headers bold by drawing multiple times with slight offset
        local cur_x, cur_y = ImGui.GetCursorPos(ctx)
        for b = 0, boldness[level] - 1 do
            ImGui.SetCursorPos(ctx, cur_x + b * 0.5, cur_y)
            ImGui.Text(ctx, element.text)
        end

        -- Pop font
        ImGui.PopFont(ctx)

        -- Add spacing after header
        for i = 1, spacing_after[level] or 1 do
            ImGui.Spacing(ctx)
        end
    elseif element.type == "paragraph" then
        local segments = parse_inline(element.text)
        render_inline_segments(segments)
        ImGui.Spacing(ctx)
    elseif element.type == "blockquote" then
        ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, 0x00000022)
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, 0)
        local avail_w = ImGui.GetContentRegionAvail(ctx)
        ImGui.BeginChild(ctx, "blockquote_" .. tostring(element), avail_w - 20, 0, ImGui.ChildFlags_AutoResizeY)
        ImGui.Indent(ctx, 10)
        local segments = parse_inline(element.text)
        render_inline_segments(segments)
        ImGui.Unindent(ctx, 10)
        ImGui.EndChild(ctx)
        ImGui.PopStyleVar(ctx)
        ImGui.PopStyleColor(ctx)
        ImGui.Spacing(ctx)
    elseif element.type == "list_unordered" then
        ImGui.Indent(ctx, 10 + element.indent * 20)
        ImGui.Bullet(ctx)
        ImGui.SameLine(ctx)
        local segments = parse_inline(element.text)
        render_inline_segments(segments)
        ImGui.Unindent(ctx, 10 + element.indent * 20)
    elseif element.type == "list_ordered" then
        ImGui.Indent(ctx, 10 + element.indent * 20)
        ImGui.Text(ctx, tostring(element.number) .. ".")
        ImGui.SameLine(ctx)
        local segments = parse_inline(element.text)
        render_inline_segments(segments)
        ImGui.Unindent(ctx, 10 + element.indent * 20)
    elseif element.type == "code_block" then
        ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, 0x00000033)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, 0xAAAAAAFF)
        local code_text = table.concat(element.lines, "\n")
        local avail_w = ImGui.GetContentRegionAvail(ctx)
        ImGui.InputTextMultiline(ctx, "##code_" .. tostring(element), code_text, avail_w - 10, 0,
            ImGui.InputTextFlags_ReadOnly)
        ImGui.PopStyleColor(ctx, 2)
        ImGui.Spacing(ctx)
    elseif element.type == "hr" then
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)
    elseif element.type == "table" then
        local rows = parse_table(element.lines)
        if #rows > 0 then
            local col_count = #rows[1].cells

            if ImGui.BeginTable(ctx, "table_" .. tostring(element), col_count, ImGui.TableFlags_Borders | ImGui.TableFlags_RowBg) then
                for _, row in ipairs(rows) do
                    ImGui.TableNextRow(ctx)
                    for col_idx, cell in ipairs(row.cells) do
                        ImGui.TableSetColumnIndex(ctx, col_idx - 1)
                        if row.is_header then
                            -- Make header bold by drawing twice with offset
                            local x, y = ImGui.GetCursorPos(ctx)
                            local segments = parse_inline(cell)
                            render_inline_segments(segments)
                            ImGui.SetCursorPos(ctx, x + 0.5, y)
                            render_inline_segments(segments)
                        else
                            local segments = parse_inline(cell)
                            render_inline_segments(segments)
                        end
                    end
                end
                ImGui.EndTable(ctx)
            end
        end
        ImGui.Spacing(ctx)
    elseif element.type == "blank" then
        ImGui.Spacing(ctx)
    end
end

---------------------------------------------------------------------

function render_main_menu_columns(elements)
    -- Separate elements into sections based on H2 headers
    local sections = {}
    local current_section = { header = nil, elements = {} }
    local before_sections = {} -- For H1 and content before first H2
    local after_sections = {}  -- For content after last H2 section
    local in_sections = false

    for _, element in ipairs(elements) do
        if element.type == "header" and element.level == 2 then
            -- Start a new section
            if #current_section.elements > 0 or current_section.header then
                table.insert(sections, current_section)
            end
            current_section = { header = element.text, elements = {} }
            in_sections = true
        elseif element.type == "header" and element.level == 1 then
            -- H1 goes before sections
            table.insert(before_sections, element)
        elseif in_sections and element.type == "hr" then
            -- Horizontal rule after sections - switch to after_sections
            if #current_section.elements > 0 or current_section.header then
                table.insert(sections, current_section)
                current_section = { header = nil, elements = {} }
            end
            in_sections = false
            table.insert(after_sections, element)
        elseif not in_sections and #sections == 0 then
            -- Before first H2
            table.insert(before_sections, element)
        elseif not in_sections and #sections > 0 then
            -- After last H2 section
            table.insert(after_sections, element)
        else
            -- Add to current section
            table.insert(current_section.elements, element)
        end
    end

    -- Add final section if it has content
    if #current_section.elements > 0 or current_section.header then
        table.insert(sections, current_section)
    end

    -- Render elements before sections
    for _, element in ipairs(before_sections) do
        render_markdown_element(element)
    end

    -- Render sections in a 2-column layout (top to bottom, left to right)
    if #sections > 0 then
        if ImGui.BeginTable(ctx, "main_menu_grid", 2) then
            ImGui.TableNextRow(ctx)

            -- Left column (sections 1 and 2)
            ImGui.TableSetColumnIndex(ctx, 0)
            if sections[1] then
                if sections[1].header then
                    render_markdown_element({
                        type = "header",
                        level = 2,
                        text = sections[1].header
                    })
                end
                for _, element in ipairs(sections[1].elements) do
                    render_markdown_element(element)
                end
            end

            if sections[2] then
                if sections[2].header then
                    render_markdown_element({
                        type = "header",
                        level = 2,
                        text = sections[2].header
                    })
                end
                for _, element in ipairs(sections[2].elements) do
                    render_markdown_element(element)
                end
            end

            -- Right column (sections 3 and 4)
            ImGui.TableSetColumnIndex(ctx, 1)
            if sections[3] then
                if sections[3].header then
                    render_markdown_element({
                        type = "header",
                        level = 2,
                        text = sections[3].header
                    })
                end
                for _, element in ipairs(sections[3].elements) do
                    render_markdown_element(element)
                end
            end

            if sections[4] then
                if sections[4].header then
                    render_markdown_element({
                        type = "header",
                        level = 2,
                        text = sections[4].header
                    })
                end
                for _, element in ipairs(sections[4].elements) do
                    render_markdown_element(element)
                end
            end

            ImGui.EndTable(ctx)
        end

        -- If there are more than 4 sections, render them normally below
        if #sections > 4 then
            ImGui.Spacing(ctx)
            for idx = 5, #sections do
                local section = sections[idx]
                if section.header then
                    render_markdown_element({
                        type = "header",
                        level = 2,
                        text = section.header
                    })
                end
                for _, element in ipairs(section.elements) do
                    render_markdown_element(element)
                end
            end
        end
    end

    -- Render elements after sections
    for _, element in ipairs(after_sections) do
        render_markdown_element(element)
    end
end

---------------------------------------------------------------------

function navigate_to(page_id)
    -- Check if page exists before navigating
    local page = get_page_with_fallback(page_id)
    if not page then
        return -- Invalid page
    end

    -- Save scroll position of current page
    scroll_positions[current_page] = ImGui.GetScrollY(ctx)

    -- If we're not at the end of history, truncate it
    if history_index < #page_history then
        for i = #page_history, history_index + 1, -1 do
            table.remove(page_history, i)
        end
    end

    -- Add new page to history
    table.insert(page_history, page_id)
    history_index = #page_history
    current_page = page_id

    -- Reset scroll for new page
    ImGui.SetScrollY(ctx, scroll_positions[page_id] or 0)
end

---------------------------------------------------------------------

function navigate_back()
    if history_index > 1 then
        scroll_positions[current_page] = ImGui.GetScrollY(ctx)
        history_index = history_index - 1
        current_page = page_history[history_index]
        ImGui.SetScrollY(ctx, scroll_positions[current_page] or 0)
    end
end

---------------------------------------------------------------------

function navigate_forward()
    if history_index < #page_history then
        scroll_positions[current_page] = ImGui.GetScrollY(ctx)
        history_index = history_index + 1
        current_page = page_history[history_index]
        ImGui.SetScrollY(ctx, scroll_positions[current_page] or 0)
    end
end

---------------------------------------------------------------------

function load_image(filepath)
    if image_cache[filepath] then
        return image_cache[filepath]
    end

    local pathseparator = package.config:sub(1, 1)
    local manual_image_path = get_manual_path() .. "images" .. pathseparator .. filepath

    if FileExists(manual_image_path) then
        local img = ImGui.CreateImage(manual_image_path)
        if img then
            image_cache[filepath] = img
            return img
        end
    end

    return nil
end

---------------------------------------------------------------------

function FileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

---------------------------------------------------------------------

defer(main)
