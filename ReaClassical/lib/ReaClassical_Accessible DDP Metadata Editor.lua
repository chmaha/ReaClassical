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

-- Accessible DDP metadata editor for screen-reader users (OSARA).
-- Up/Down selects Album or a CD track. Enter walks through every field
-- in order: Enter to keep the current value, or type a replacement and
-- press Enter to save it. After the last field the editor moves to the
-- next item automatically. Escape from the item list saves all changes
-- and re-runs createcd.

-- luacheck: ignore 113

for key in pairs(reaper) do _G[key] = reaper[key] end

local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
local parent_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")

---------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------

local STATE_NAV = "nav"   -- choose which item to edit
local STATE_SEQ = "seq"   -- sequential field-by-field walkthrough

local KEY_UP          = 30064
local KEY_DOWN        = 1685026670
local KEY_LEFT        = 1818584692
local KEY_RIGHT       = 1919379572
local KEY_ENTER       = 13
local KEY_ESC         = 27
local KEY_BACK        = 8
local KEY_PASTE       = 22  -- Ctrl+V / Cmd+V on Mac
local KEY_APPLY_ALL   = 1   -- Ctrl+A: apply value to all CD tracks
local KEY_APPLY_REST  = 18  -- Ctrl+R: apply value to this and all subsequent tracks
local KEY_COPY_PREV   = 16  -- Ctrl+P: copy same field from previous track
local KEY_COPY_ALBUM  = 21  -- Ctrl+U: copy same field from album level

local ALBUM_FIELDS = {
    "title", "performer", "songwriter", "composer", "arranger",
    "genre", "identification", "language", "catalog", "message"
}
local ALBUM_LABELS = {
    "Album Title", "Performer", "Songwriter", "Composer", "Arranger",
    "Genre", "Identification", "Language", "Catalog", "Message"
}

-- ISRC is appended when applicable; see get_fields().
local TRACK_FIELDS_BASE = { "title", "performer", "songwriter", "composer", "arranger", "message" }
local TRACK_LABELS_BASE = { "Title", "Performer", "Songwriter", "Composer", "Arranger", "Message" }

local ISRC_PATTERN    = "^%a%a%w%w%w%d%d%d%d%d%d%d$"
local CATALOG_PATTERN = "^%d+$"   -- all digits; length checked separately (12 or 13)

-- Returns an error string if the value is invalid for this field, nil if OK.
local function validate_new_value(field_key, value)
    if field_key == "isrc" then
        if not value:match(ISRC_PATTERN) then
            return "ISRC needs 2 letters, 3 alphanumeric, 7 digits, no spaces or hyphens"
        end
    elseif field_key == "catalog" then
        if not value:match(CATALOG_PATTERN) or (#value ~= 12 and #value ~= 13) then
            return "catalog number needs 12 or 13 digits"
        end
    end
    return nil
end

---------------------------------------------------------------------
-- Runtime state
---------------------------------------------------------------------

local state      = STATE_NAV
local nav_idx    = 1       -- 1 = Album; 2..n+1 = CD track 1..n
local field_idx  = 1
local edit_str   = ""
local last_char  = 0
local review_pos = nil     -- nil = at end; 1..#buf = character being reviewed

local folder_track         = nil
local album_item           = nil
local album_data           = {}
local cd_items             = {}    -- { item, take, data={} }
local digital_release_only = false
local manual_isrc          = false

---------------------------------------------------------------------
-- Parsing / serialising
---------------------------------------------------------------------

local function find_folder_track()
    local sel = GetSelectedTrack(0, 0)
    if not sel then return nil end
    if GetMediaTrackInfo_Value(sel, "I_FOLDERDEPTH") == 1 then return sel end
    local idx = GetMediaTrackInfo_Value(sel, "IP_TRACKNUMBER") - 1
    for i = idx - 1, 0, -1 do
        local t = GetTrack(0, i)
        local d = GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
        if d < 0 then break end
        if d == 1 then return t end
    end
    return nil
end

local function parse_album(name)
    local d = { genre = "Classical", language = "English" }
    local first = true
    for part in name:gmatch("[^|]+") do
        if first then d.title = part:gsub("^@", ""); first = false
        else
            local k, v = part:match("^(%w+)=(.+)$")
            if k then d[k:lower()] = v end
        end
    end
    d.title = d.title or ""
    return d
end

local function parse_track(name)
    local d = {}
    local first = true
    for part in name:gmatch("[^|]+") do
        if first then d.title = part:gsub("^!", ""); first = false
        else
            local k, v = part:match("^(%w+)=(.+)$")
            if k then
                k = k:lower()
                if k == "offset" then d._offset = v else d[k] = v end
            end
        end
    end
    return d
end

local function serialize_album(d)
    local parts = { "@" .. (d.title or "") }
    for _, k in ipairs({ "performer", "songwriter", "composer", "arranger",
                         "genre", "identification", "language", "catalog", "message" }) do
        if d[k] and d[k] ~= "" then parts[#parts+1] = k:upper() .. "=" .. d[k] end
    end
    return table.concat(parts, "|")
end

local function serialize_track(d)
    local parts = { d.title or "" }
    if d._offset and d._offset ~= "" then parts[#parts+1] = "OFFSET=" .. d._offset end
    for _, k in ipairs({ "performer", "songwriter", "composer", "arranger", "message", "isrc" }) do
        if d[k] and d[k] ~= "" then parts[#parts+1] = k:upper() .. "=" .. d[k] end
    end
    return table.concat(parts, "|")
end

local function increment_isrc(isrc, offset)
    local prefix, year, seq = isrc:match("^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$")
    if not prefix then return isrc end
    return string.format("%s%s%05d", prefix, year, (tonumber(seq) + offset) % 100000)
end

---------------------------------------------------------------------
-- Load / save
---------------------------------------------------------------------

local function load_data()
    album_data = { genre = "Classical", language = "English" }
    album_item = nil
    cd_items   = {}

    local raw = {}
    for i = 0, CountTrackMediaItems(folder_track) - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            name = name or ""
            if name:match("^@") then
                album_item = item
                album_data = parse_album(name)
            elseif name ~= "" then
                raw[#raw+1] = { item = item, take = take, name = name,
                                pos  = GetMediaItemInfo_Value(item, "D_POSITION") }
            end
        end
    end

    table.sort(raw, function(a, b) return a.pos < b.pos end)
    for _, r in ipairs(raw) do
        cd_items[#cd_items+1] = { item = r.item, take = r.take, data = parse_track(r.name) }
    end

    local _, dr = GetProjExtState(0, "ReaClassical", "digital_release_only")
    digital_release_only = dr == "1"
    local _, mi = GetProjExtState(0, "ReaClassical", "manual_isrc_entry")
    manual_isrc = mi == "1"
end

local function save_and_run()
    Undo_BeginBlock()

    if album_item then
        local take = GetActiveTake(album_item)
        if take then
            GetSetMediaItemTakeInfo_String(take, "P_NAME", serialize_album(album_data), true)
        end
    end

    -- ISRC auto-propagation from track 1 when not in manual mode.
    if not manual_isrc and #cd_items > 0 then
        local first_isrc = cd_items[1].data.isrc or ""
        if first_isrc:match(ISRC_PATTERN) then
            for i = 2, #cd_items do
                cd_items[i].data.isrc = increment_isrc(first_isrc, i - 1)
            end
        end
    end

    for _, cd in ipairs(cd_items) do
        GetSetMediaItemTakeInfo_String(GetActiveTake(cd.item), "P_NAME", serialize_track(cd.data), true)
    end

    Undo_EndBlock("DDP Metadata Edit", -1)
    SetProjExtState(0, "ReaClassical", "digital_release_only", digital_release_only and "1" or "0")

    SetOnlyTrackSelected(folder_track)
    _G.RC_TERMINAL_ARGS = {}
    dofile(parent_path .. "ReaClassical_Create CD Markers.lua")
    _G.RC_TERMINAL_ARGS = nil
end

---------------------------------------------------------------------
-- Navigation / field helpers
---------------------------------------------------------------------

local function nav_count() return 1 + #cd_items end

local function nav_label(i)
    if i == 1 then return "Album" end
    local cd = cd_items[i - 1]
    return string.format("%d %s", i - 1, (cd and cd.data and cd.data.title) or "")
end

-- Returns field-key array and label array for the item at nav_i.
local function get_fields(nav_i)
    if nav_i == 1 then return ALBUM_FIELDS, ALBUM_LABELS end
    local show_isrc = manual_isrc or (nav_i == 2)   -- nav_i == 2 → first CD track
    if show_isrc then
        local f, l = {}, {}
        for _, v in ipairs(TRACK_FIELDS_BASE) do f[#f+1] = v end
        for _, v in ipairs(TRACK_LABELS_BASE) do l[#l+1] = v end
        f[#f+1] = "isrc"; l[#l+1] = "ISRC"
        return f, l
    end
    return TRACK_FIELDS_BASE, TRACK_LABELS_BASE
end

local function get_val(nav_i, key)
    if nav_i == 1 then
        return album_data[key] or ""
    end
    local cd = cd_items[nav_i - 1]
    return (cd and cd.data and cd.data[key]) or ""
end

local function set_val(nav_i, key, value)
    if nav_i == 1 then
        album_data[key] = value
    else
        local cd = cd_items[nav_i - 1]
        if cd then cd.data[key] = value end
    end
end

---------------------------------------------------------------------
-- Announce the current field prompt
---------------------------------------------------------------------

local function announce_field()
    local fields, labels = get_fields(nav_idx)
    local key = fields[field_idx]
    local cur = get_val(nav_idx, key)
    say(labels[field_idx] .. ": " .. (cur ~= "" and cur or "empty") .. ". Enter to keep, type to change")
end

---------------------------------------------------------------------
-- GFX drawing
---------------------------------------------------------------------

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_NAV then
        gfx.drawstr("[Nav]  " .. nav_label(nav_idx))
    elseif state == STATE_SEQ then
        local fields, labels = get_fields(nav_idx)
        local key = fields[field_idx] or ""
        local cur = get_val(nav_idx, key)
        gfx.drawstr(nav_label(nav_idx) .. "  |  " .. (labels[field_idx] or "")
            .. ": " .. (edit_str ~= "" and edit_str or cur))
    end
    gfx.update()
end

---------------------------------------------------------------------
-- Key handling
---------------------------------------------------------------------

local function handle_key(char)
    if state == STATE_NAV then
        if char == KEY_UP then
            nav_idx = nav_idx > 1 and nav_idx - 1 or nav_count()
            say(nav_label(nav_idx))
        elseif char == KEY_DOWN then
            nav_idx = nav_idx < nav_count() and nav_idx + 1 or 1
            say(nav_label(nav_idx))
        elseif char == KEY_ENTER then
            field_idx = 1
            edit_str  = ""
            state     = STATE_SEQ
            announce_field()
        elseif char == KEY_ESC then
            save_and_run()
            return false
        end

    elseif state == STATE_SEQ then
        if char >= 32 and char <= 126 then
            if #edit_str < 100 then
                local ch = string.char(char)
                edit_str = edit_str .. ch
                review_pos = nil
                say(ch)
            end
        elseif char == KEY_PASTE then
            if APIExists("CF_GetClipboard") then
                local clip = CF_GetClipboard("")
                if clip and clip ~= "" then
                    local space = 100 - #edit_str
                    if space > 0 then
                        clip = clip:sub(1, space)
                        edit_str = edit_str .. clip
                        review_pos = nil
                        say("pasted: " .. clip)
                    end
                end
            else
                say("Paste requires SWS extension")
            end
        elseif char == KEY_APPLY_ALL then
            local fields = get_fields(nav_idx)
            local field_key = fields[field_idx]
            local val = edit_str ~= "" and edit_str or get_val(nav_idx, field_key)
            if val ~= "" then
                for i = 1, #cd_items do cd_items[i].data[field_key] = val end
                say("Applied to all " .. #cd_items .. " track" .. (#cd_items == 1 and "" or "s"))
            else
                say("Nothing to apply")
            end
        elseif char == KEY_APPLY_REST then
            local fields = get_fields(nav_idx)
            local field_key = fields[field_idx]
            local val = edit_str ~= "" and edit_str or get_val(nav_idx, field_key)
            if val ~= "" then
                local start_i = nav_idx > 1 and (nav_idx - 1) or 1
                local count = #cd_items - start_i + 1
                for i = start_i, #cd_items do cd_items[i].data[field_key] = val end
                say("Applied to " .. count .. " track" .. (count == 1 and "" or "s"))
            else
                say("Nothing to apply")
            end
        elseif char == KEY_COPY_PREV then
            if nav_idx <= 1 then
                say("Not applicable to album")
            elseif nav_idx == 2 then
                say("No previous track")
            else
                local fields = get_fields(nav_idx)
                local field_key = fields[field_idx]
                local prev_val = cd_items[nav_idx - 2].data[field_key] or ""
                if prev_val ~= "" then
                    edit_str = prev_val
                    review_pos = nil
                    say("Copied: " .. prev_val)
                else
                    say("Previous track has no value for this field")
                end
            end
        elseif char == KEY_COPY_ALBUM then
            if nav_idx == 1 then
                say("Already on album")
            else
                local fields = get_fields(nav_idx)
                local field_key = fields[field_idx]
                local album_val = album_data[field_key] or ""
                if album_val ~= "" then
                    edit_str = album_val
                    review_pos = nil
                    say("Copied from album: " .. album_val)
                else
                    say("Album has no value for this field")
                end
            end
        elseif char == KEY_LEFT then
            local fields = get_fields(nav_idx)
            local buf = edit_str ~= "" and edit_str or get_val(nav_idx, fields[field_idx])
            if #buf == 0 then
                say("empty")
            elseif review_pos == nil then
                review_pos = #buf
                say(buf:sub(review_pos, review_pos))
            elseif review_pos > 1 then
                review_pos = review_pos - 1
                say(buf:sub(review_pos, review_pos))
            else
                say("beginning")
            end
        elseif char == KEY_RIGHT then
            local fields = get_fields(nav_idx)
            local buf = edit_str ~= "" and edit_str or get_val(nav_idx, fields[field_idx])
            if #buf == 0 then
                say("empty")
            elseif review_pos == nil or review_pos >= #buf then
                review_pos = nil
                say("end")
            else
                review_pos = review_pos + 1
                say(buf:sub(review_pos, review_pos))
            end
        elseif char == KEY_BACK then
            review_pos = nil
            if #edit_str > 0 then
                local deleted = edit_str:sub(-1)
                edit_str = edit_str:sub(1, -2)
                say(deleted)
            else
                local fields = get_fields(nav_idx)
                local cur = get_val(nav_idx, fields[field_idx])
                if cur ~= "" then
                    local deleted = cur:sub(-1)
                    edit_str = cur:sub(1, -2)
                    say(deleted)
                end
            end
        elseif char == KEY_ENTER then
            review_pos = nil
            local fields    = get_fields(nav_idx)
            local field_key = fields[field_idx]
            local blocked   = false
            if edit_str ~= "" then
                local err = validate_new_value(field_key, edit_str)
                if err then
                    say("Invalid " .. err .. ". Backspace to edit, Escape to keep original")
                    blocked = true   -- leave edit_str intact so user can backspace-correct
                else
                    set_val(nav_idx, field_key, edit_str)
                end
            end
            if not blocked then
                -- When track 1's ISRC is committed in auto mode, propagate immediately.
                local isrc_msg = ""
                if field_key == "isrc" and nav_idx == 2 and not manual_isrc then
                    local new_isrc = cd_items[1].data.isrc or ""
                    if new_isrc ~= "" and new_isrc:match(ISRC_PATTERN) and #cd_items > 1 then
                        Undo_BeginBlock()
                        GetSetMediaItemTakeInfo_String(
                            GetActiveTake(cd_items[1].item), "P_NAME",
                            serialize_track(cd_items[1].data), true)
                        for i = 2, #cd_items do
                            cd_items[i].data.isrc = increment_isrc(new_isrc, i - 1)
                            GetSetMediaItemTakeInfo_String(
                                GetActiveTake(cd_items[i].item), "P_NAME",
                                serialize_track(cd_items[i].data), true)
                        end
                        Undo_EndBlock("Propagate ISRC", -1)
                        isrc_msg = " ISRC propagated to " .. (#cd_items - 1)
                            .. " further track" .. (#cd_items > 2 and "s" or "") .. "."
                    end
                end
                edit_str  = ""
                field_idx = field_idx + 1
                if field_idx > #fields then
                    -- All fields done: return to NAV and advance to next item, wrapping to Album.
                    local done = nav_label(nav_idx)
                    state   = STATE_NAV
                    nav_idx = nav_idx < nav_count() and nav_idx + 1 or 1
                    say("Done with " .. done .. "." .. isrc_msg .. " Now on: " .. nav_label(nav_idx)
                        .. ". Enter to edit, Escape to save and close")
                else
                    if isrc_msg ~= "" then say(isrc_msg) end
                    announce_field()
                end
            end
        elseif char == KEY_ESC then
            review_pos = nil
            if edit_str ~= "" then
                -- Clear typed input and re-announce the same field.
                edit_str = ""
                announce_field()
            else
                -- Abandon sequence, return to item picker.
                state = STATE_NAV
                say(nav_label(nav_idx) .. ". Enter to edit fields, Escape to save and close")
            end
        end
    end
    return true
end

---------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------

local function main()
    local char = gfx.getchar()
    if char == -1 then
        save_and_run()
        return
    end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        if not handle_key(char) then
            gfx.quit()
            return
        end
    end
    draw_window()
    defer(main)
end

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    if string.find(GetOS(), "^OSX") or string.find(GetOS(), "^macOS") then modifier = "Cmd" end
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.",
       "ReaClassical Error", 0)
    return
end

folder_track = find_folder_track()
if not folder_track then
    say("No folder track found. Select a folder track or one of its child tracks.")
    return
end

load_data()

if #cd_items == 0 then
    say("No CD track items found. Run createcd first.")
    return
end

if not album_item then
    say("No album item found. Run createcd first.")
    return
end

gfx.init("Accessible DDP Metadata Editor", 600, 44, 0)

say(string.format(
    "DDP Metadata Editor. Album and %d CD track%s. "
    .. "Up and down to pick an item, Enter to walk through its fields, "
    .. "Escape to save and close. Currently on: %s. "
    .. "While editing a field: Control A applies value to all tracks, "
    .. "Control R applies to this and remaining tracks, "
    .. "Control P copies from previous track, "
    .. "Control U copies from album level. "
    .. "Left and right arrows review characters. Control V pastes.",
    #cd_items, #cd_items == 1 and "" or "s", nav_label(nav_idx)
))

defer(main)
