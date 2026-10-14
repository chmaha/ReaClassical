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
local parent_path = script_path:match("^(.+[\\/]).+[\\/]$") or script_path
package.path = package.path .. ";" .. script_path .. "?.lua;"
local say = require("ReaClassical_Announce")
local gui_mode = require("ReaClassical_GuiMode")
local render_settings = require("ReaClassical_Render_Settings")
local render_range = require("ReaClassical_Render_Range")
local af = require("ReaClassical_Accessible_Focus")
local album_meta_store = require("ReaClassical_Album_Metadata")
local help = require("ReaClassical_Accessible_Help")

set_action_options(3)

local WINDOW_TITLE = "DDP Metadata Editor"

local STATE_NAV          = "nav"
local STATE_RENDER       = "render"
local STATE_RENDER_TRACK = "render_track"
local STATE_CDSET        = "cdset"

local KEY_UP          = 30064
local KEY_DOWN        = 1685026670
local KEY_LEFT        = 1818584692
local KEY_RIGHT       = 1919379572
local KEY_ENTER       = 13
local KEY_ESC         = 27
local KEY_APPLY_ALL   = 1
local KEY_APPLY_REST  = 18
local KEY_COPY_PREV   = 16
local KEY_COPY_ALBUM  = 21

local FIELD_LABELS = {
    title = "Title", performer = "Performer", songwriter = "Songwriter",
    composer = "Composer", arranger = "Arranger", message = "Message",
    isrc = "ISRC", genre = "Genre", identification = "Identification",
    language = "Language", catalog = "Catalog",
}

local ALBUM_COLUMNS = {
    "title", "performer", "songwriter", "composer", "arranger",
    "genre", "identification", "language", "catalog", "message"
}

local PROPAGATE_FIELDS = { "performer", "songwriter", "composer", "arranger" }

local TRACK_COLUMNS = { "title", "performer", "songwriter", "composer", "arranger", "message" }

local ISRC_PATTERN    = "^%a%a%w%w%w%d%d%d%d%d%d%d$"
local CATALOG_PATTERN = "^%d+$"

local function catalog_checksum_valid(catalog)
    local sum = 0
    local weight = 3
    for i = #catalog - 1, 1, -1 do
        sum = sum + tonumber(catalog:sub(i, i)) * weight
        weight = weight == 3 and 1 or 3
    end
    local expected = (10 - (sum % 10)) % 10
    return expected == tonumber(catalog:sub(-1))
end

local RENDER_FIELDS = {
    { key = "samplerate", label = "Sample rate", list = render_settings.samplerate_list,
      labels = render_settings.samplerate_labels },
    { key = "bitdepth", label = "Bit depth", list = render_settings.bitdepth_list,
      labels = render_settings.bitdepth_labels },
    { key = "dither", label = "Dither", list = render_settings.dither_list,
      labels = render_settings.dither_list },
}

local RENDER_TRACK_FORMATS = {
    { key = "ddp",  label = "DDP",       range_eligible = false },
    { key = "cue",  label = "Cue Audio", range_eligible = false },
    { key = "wav",  label = "WAV",       range_eligible = true },
    { key = "flac", label = "FLAC",      range_eligible = true },
    { key = "opus", label = "Opus 160",  range_eligible = true },
    { key = "mp3",  label = "MP3 320",   range_eligible = true },
    { key = "stems", label = "M: Stems", range_eligible = true },
    { key = "custom", label = "Custom",  range_eligible = false },
}

local CDSET_FIELDS = {
    { key = "digital",       label = "Digital Release Only",       kind = "bool" },
    { key = "isrc_manual",   label = "Manual ISRC Entry",          kind = "bool" },
    { key = "people_manual", label = "Manual Contributors Entry",  kind = "bool" },
    { key = "cdpre",         label = "CD Pre-Roll in Seconds",     kind = "number" },
    { key = "cdpost",        label = "CD Post-Roll in Seconds",    kind = "number" },
    { key = "offsets",       label = "Marker Offsets",             kind = "action" },
}

local function validate_new_value(field_key, value)
    if field_key == "isrc" then
        if not value:match(ISRC_PATTERN) then
            return "ISRC needs 2 letters, 3 alphanumeric, 7 digits, no spaces or hyphens"
        end
    elseif field_key == "catalog" then
        if not value:match(CATALOG_PATTERN) or (#value ~= 12 and #value ~= 13) then
            return "catalog number needs 12 or 13 digits"
        elseif not catalog_checksum_valid(value) then
            return "catalog number check digit is invalid"
        end
    end
    return nil
end

local state      = STATE_NAV
local nav_idx    = 3
local album_col_idx = 1
local track_col_idx = 1
local last_char  = 0

local render_field_idx   = 1
local render_pending_idx = 1
local cur_samplerate, cur_bitdepth, cur_dither = render_settings.load()

local render_track_range   = ""
local render_track_fmt_idx = 1

local folder_track         = nil
local album_legacy_item    = nil
local found_album_metadata = false
local album_data           = {}
local cd_items             = {}
local digital_release_only = false
local manual_isrc          = false
local manual_people_entry  = false
local cd_pre_roll          = 10
local cd_post_roll         = 3

local cdset_idx = 1

local function find_folder_track()
    local t = GetTrack(0, 0)
    if t and GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then return t end
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

local function propagate_isrc()
    if manual_isrc or #cd_items < 2 then return false end
    local first_isrc = cd_items[1].data.isrc or ""
    if not first_isrc:match(ISRC_PATTERN) then return false end
    local changed = false
    for i = 2, #cd_items do
        local new_isrc = increment_isrc(first_isrc, i - 1)
        if cd_items[i].data.isrc ~= new_isrc then
            cd_items[i].data.isrc = new_isrc
            changed = true
        end
    end
    return changed
end

local function propagate_album_fields()
    local changed = false
    for _, f in ipairs(PROPAGATE_FIELDS) do
        local val, mixed = nil, false
        for _, cd in ipairs(cd_items) do
            local v = cd.data[f]
            if v and v ~= "" then
                if not val then val = v
                elseif val ~= v then mixed = true end
            end
        end
        local desired = mixed and "Various" or val
        if (album_data[f] or "") ~= (desired or "") then
            album_data[f] = desired
            changed = true
        end
    end
    return changed
end

local function load_data()
    album_data = { genre = "Classical", language = "English" }
    album_legacy_item, found_album_metadata = nil, false
    cd_items   = {}

    local raw = {}
    for i = 0, CountTrackMediaItems(folder_track) - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            name = name or ""
            if not name:match("^@") and name ~= "" then
                raw[#raw+1] = { item = item, take = take, name = name,
                                pos  = GetMediaItemInfo_Value(item, "D_POSITION") }
            end
        end
    end

    local album_str, legacy_item = album_meta_store.get_album_metadata_str(folder_track)
    if album_str then
        album_data = parse_album(album_str)
        album_legacy_item = legacy_item
        found_album_metadata = true
    end

    table.sort(raw, function(a, b) return a.pos < b.pos end)
    for _, r in ipairs(raw) do
        cd_items[#cd_items+1] = { item = r.item, take = r.take, data = parse_track(r.name) }
    end

    local _, dr = GetProjExtState(0, "ReaClassical", "digital_release_only")
    digital_release_only = dr == "1"
    local _, mi = GetProjExtState(0, "ReaClassical", "manual_isrc_entry")
    manual_isrc = mi == "1"
    local _, pre = GetProjExtState(0, "ReaClassical", "CDBoundaryPreRoll")
    cd_pre_roll = tonumber(pre) or 3
    local _, post = GetProjExtState(0, "ReaClassical", "CDBoundaryPostRoll")
    cd_post_roll = tonumber(post) or 3
    local _, mp = GetProjExtState(0, "ReaClassical", "manual_people_entry")
    manual_people_entry = mp == "1"

    local isrc_changed = propagate_isrc()
    local album_changed = (not manual_people_entry) and propagate_album_fields()
    return isrc_changed, album_changed
end

local function save_data()
    if found_album_metadata then
        album_meta_store.set_album_metadata_str(folder_track, serialize_album(album_data), album_legacy_item)
    end

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

    SetProjExtState(0, "ReaClassical", "digital_release_only", digital_release_only and "1" or "0")
    SetProjExtState(0, "ReaClassical", "manual_isrc_entry", manual_isrc and "1" or "0")
    SetProjExtState(0, "ReaClassical", "manual_people_entry", manual_people_entry and "1" or "0")
    SetProjExtState(0, "ReaClassical", "CDBoundaryPreRoll", tostring(cd_pre_roll))
    SetProjExtState(0, "ReaClassical", "CDBoundaryPostRoll", tostring(cd_post_roll))
    SetOnlyTrackSelected(folder_track)
end

local function save_and_run(announce)
    Undo_BeginBlock()
    save_data()
    _G.RC_SCRIPT_ARGS = { no_undo_wrap = true, silent = not announce }
    dofile(parent_path .. "ReaClassical_Create CD Markers.lua")
    _G.RC_SCRIPT_ARGS = nil
    Undo_EndBlock("DDP Metadata Edit", -1)
end

local function marker_offsets_status()
    for i = 0, CountTrackMediaItems(folder_track) - 1 do
        local item = GetTrackMediaItem(folder_track, i)
        local take = item and GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if name and name:match("|OFFSET=") then return "active" end
        end
    end
    return "none"
end

local function do_marker_offsets_action()
    local has_offsets = marker_offsets_status() == "active"
    save_data()
    if has_offsets then
        dofile(parent_path .. "ReaClassical_Remove All CD Marker Offsets.lua")
    else
        dofile(parent_path .. "ReaClassical_Add CD Marker Offsets.lua")
    end
    load_data()
end

local function try_refocus()
    return af.refocus_existing(WINDOW_TITLE)
end

local function render_tracks(fmt, range_str)
    Undo_BeginBlock()
    save_data()
    _G.RC_SCRIPT_ARGS = { action = "render", format = fmt,
        track_range = (range_str ~= "" and range_str or nil), no_undo_wrap = true }
    dofile(parent_path .. "ReaClassical_Create CD Markers.lua")
    _G.RC_SCRIPT_ARGS = nil
    Undo_EndBlock("DDP Metadata Edit", -1)
end

local function nav_count() return 4 + #cd_items end

local function nav_label(i)
    if i == 1 then return "Render Settings" end
    if i == 2 then return "Render" end
    if i == 3 then return "Album" end
    if i == nav_count() then return "CD Settings" end
    local cd = cd_items[i - 3]
    return string.format("%d %s", i - 3, (cd and cd.data and cd.data.title) or "")
end

local function active_columns()
    if nav_idx == 3 then
        return ALBUM_COLUMNS, math.min(album_col_idx, #ALBUM_COLUMNS)
    end
    if nav_idx >= 4 and nav_idx <= #cd_items + 3 then
        local cols = {}
        for _, c in ipairs(TRACK_COLUMNS) do cols[#cols + 1] = c end
        cols[#cols + 1] = "isrc"
        return cols, math.min(track_col_idx, #cols)
    end
    return nil, nil
end

local function nav_columns()
    local cols = active_columns()
    return cols
end

local function column_key()
    local cols, idx = active_columns()
    if not cols then return nil end
    return cols[idx]
end

local function set_column_idx(i)
    if nav_idx == 3 then album_col_idx = i else track_col_idx = i end
end

local function column_value(key)
    if nav_idx == 3 then return album_data[key] or "" end
    local cd = cd_items[nav_idx - 3]
    return (cd and cd.data[key]) or ""
end

local function commit_column(key, value)
    if nav_idx == 3 then
        album_data[key] = value
    else
        local cd = cd_items[nav_idx - 3]
        if cd then cd.data[key] = value end
    end
    if nav_idx > 3 and not manual_people_entry then
        for _, f in ipairs(PROPAGATE_FIELDS) do
            if f == key then propagate_album_fields() break end
        end
    end
end

local function column_readonly(key)
    if key == "isrc" and not manual_isrc and nav_idx > 4 then
        return "ISRC is auto-derived from track 1; enable Manual ISRC Entry in CD Settings to edit"
    end
    if nav_idx == 3 and not manual_people_entry then
        for _, f in ipairs(PROPAGATE_FIELDS) do
            if f == key then
                return "Auto-derived from tracks; enable Manual Contributors Entry in CD Settings to edit"
            end
        end
    end
    return nil
end

local function announce_nav_position()
    local cols = nav_columns()
    local key = cols and column_key() or nil
    if not key then
        say(nav_label(nav_idx))
        return
    end
    local label = FIELD_LABELS[key] or key
    local val = column_value(key)
    local val_part = (val ~= "" and val or "empty")
    local msg
    if nav_idx == 3 then
        msg = "Album " .. label .. ": " .. val_part
    elseif key == "title" then
        msg = "Track " .. (nav_idx - 3) .. ": " .. val_part
    else
        msg = "Track " .. (nav_idx - 3) .. " " .. label .. ": " .. val_part
    end
    local ro = column_readonly(key)
    if ro then msg = msg .. ". " .. ro end
    say(msg)
end

local function prompt_value(title, caption, prefill)
    local ok, csv = GetUserInputs(title, 1, caption .. ",extrawidth=300", prefill or "")
    try_refocus()
    return ok, csv or ""
end

local function prompt_column_value(key, initial)
    local caption = FIELD_LABELS[key] or key
    local value = initial ~= nil and initial or column_value(key)
    while true do
        local ok, new_value = prompt_value(nav_label(nav_idx), caption, value)
        if not ok then return false, value end
        local err = validate_new_value(key, new_value)
        if not err then return true, new_value end
        say("Invalid: " .. err .. ". Correct it or Cancel")
        value = new_value
    end
end

local function propagate_isrc_if_first_track(key)
    if not (key == "isrc" and nav_idx == 4 and not manual_isrc and #cd_items > 1) then
        return ""
    end
    local first_isrc = cd_items[1].data.isrc or ""
    if not (first_isrc ~= "" and first_isrc:match(ISRC_PATTERN)) then return "" end
    Undo_BeginBlock()
    GetSetMediaItemTakeInfo_String(
        GetActiveTake(cd_items[1].item), "P_NAME",
        serialize_track(cd_items[1].data), true)
    for i = 2, #cd_items do
        cd_items[i].data.isrc = increment_isrc(first_isrc, i - 1)
        GetSetMediaItemTakeInfo_String(
            GetActiveTake(cd_items[i].item), "P_NAME",
            serialize_track(cd_items[i].data), true)
    end
    Undo_EndBlock("Propagate ISRC", -1)
    return " ISRC propagated to " .. (#cd_items - 1)
        .. " further track" .. (#cd_items > 2 and "s" or "") .. "."
end

local function edit_row_from_viewed()
    local cols, i = active_columns()
    local key = cols[i]
    local ro = column_readonly(key)
    if ro then
        say((FIELD_LABELS[key] or key) .. ": " .. ro)
        return
    end
    local ok, value = prompt_column_value(key)
    if not ok then
        say("Cancelled")
        announce_nav_position()
        return
    end
    commit_column(key, value)
    local isrc_msg = propagate_isrc_if_first_track(key)
    if isrc_msg ~= "" then
        say((FIELD_LABELS[key] or key) .. " saved." .. isrc_msg)
    else
        say((FIELD_LABELS[key] or key) .. " saved")
    end
    save_and_run()
end

local function render_current_index(i)
    local f = RENDER_FIELDS[i]
    local cur = (f.key == "samplerate" and cur_samplerate)
        or (f.key == "bitdepth" and cur_bitdepth)
        or cur_dither
    for idx, v in ipairs(f.list) do
        if v == cur then return idx end
    end
    return 1
end

local function announce_render_field(with_hint)
    local f = RENDER_FIELDS[render_field_idx]
    local msg = f.label .. ": " .. f.labels[render_pending_idx]
    if with_hint then msg = msg .. ". Up/down to change" end
    say(msg)
end

local function announce_render_format(move_hint)
    local fmt = RENDER_TRACK_FORMATS[render_track_fmt_idx]
    local msg = "Format: " .. fmt.label
    if move_hint then msg = msg .. ". Up/down to change" end
    say(msg)
end

local function cdset_value_label(i)
    local f = CDSET_FIELDS[i]
    if f.key == "digital" then return digital_release_only and "On" or "Off" end
    if f.key == "isrc_manual" then return manual_isrc and "On" or "Off" end
    if f.key == "people_manual" then return manual_people_entry and "On" or "Off" end
    if f.key == "cdpre" then return tostring(cd_pre_roll) end
    if f.key == "cdpost" then return tostring(cd_post_roll) end
    return marker_offsets_status() == "active" and "Active (Enter to clear)" or "None (Enter to add)"
end

local function announce_cdset_field(with_hint)
    local f = CDSET_FIELDS[cdset_idx]
    local msg = f.label .. ": " .. cdset_value_label(cdset_idx)
    if with_hint then
        msg = msg .. (f.kind == "action" and ". Enter to run" or ". Enter to change")
    end
    say(msg)
end

local function nav_shortcuts()
    return {
        { key = "Up/Down", desc = "Move between items; on Album or a track this is the metadata row" },
        { key = "Left/Right", desc = "Choose the metadata type shown for the row" },
        { key = "Enter", desc = "Edit the viewed cell in a prefilled input box" },
        { key = "Inside an edit box", desc = "Text arrives pre-selected: Left/Right places the caret so Backspace/Delete edit per character; typing replaces the whole value; Enter keeps an untouched value" },
        { key = "Escape", desc = "Save all changes and rebuild CD markers" },
        { key = "Ctrl+A, on a table row", desc = "Apply the viewed value to every CD track" },
        { key = "Ctrl+R, on a track row", desc = "Apply the viewed value to this and every later CD track" },
        { key = "Ctrl+P, on a track row", desc = "Edit the viewed field prefilled from the previous CD track" },
        { key = "Ctrl+U, on a track row", desc = "Edit the viewed field prefilled from the album" },
    }
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_NAV then
        local cols = nav_columns()
        local key = cols and column_key() or nil
        if key and key ~= "title" then
            gfx.drawstr("[Nav]  " .. nav_label(nav_idx) .. "  |  "
                .. (FIELD_LABELS[key] or key) .. ": " .. column_value(key))
        else
            gfx.drawstr("[Nav]  " .. nav_label(nav_idx))
        end
    elseif state == STATE_RENDER then
        local f = RENDER_FIELDS[render_field_idx]
        gfx.drawstr("[Render Settings]  " .. f.label .. ": " .. f.labels[render_pending_idx])
    elseif state == STATE_RENDER_TRACK then
        gfx.drawstr("[Render]  Format: " .. RENDER_TRACK_FORMATS[render_track_fmt_idx].label
            .. "  |  Range: " .. (render_track_range ~= "" and render_track_range or "all"))
    elseif state == STATE_CDSET then
        local f = CDSET_FIELDS[cdset_idx]
        gfx.drawstr("[CD Settings]  " .. f.label .. ": " .. cdset_value_label(cdset_idx))
    end
    gfx.update()
end

local function handle_key(char)
    if state == STATE_NAV then
        if char == KEY_UP or char == KEY_DOWN then
            local prev = nav_idx
            if char == KEY_UP then
                nav_idx = nav_idx > 1 and nav_idx - 1 or nav_count()
            else
                nav_idx = nav_idx < nav_count() and nav_idx + 1 or 1
            end
            if prev ~= 3 and nav_idx == 3 then album_col_idx = 1 end
            announce_nav_position()
        elseif char == KEY_LEFT or char == KEY_RIGHT then
            local cols = nav_columns()
            if not cols then
                say("No metadata columns on this row")
            else
                local delta = char == KEY_RIGHT and 1 or -1
                local cur = select(2, active_columns())
                set_column_idx(((cur - 1 + delta) % #cols) + 1)
                announce_nav_position()
            end
        elseif char == KEY_ENTER then
            if nav_idx == 1 then
                render_field_idx   = 1
                render_pending_idx = render_current_index(1)
                state = STATE_RENDER
                announce_render_field(true)
            elseif nav_idx == 2 then
                render_track_fmt_idx = 1
                render_track_range   = ""
                state = STATE_RENDER_TRACK
                announce_render_format(true)
            elseif nav_idx >= 3 and nav_idx <= #cd_items + 3 then
                edit_row_from_viewed()
            elseif nav_idx == nav_count() then
                cdset_idx = 1
                state = STATE_CDSET
                announce_cdset_field(true)
            end
        elseif char == KEY_APPLY_ALL then
            local key = column_key()
            local ro = key and column_readonly(key)
            if ro or not key then
                say(ro or "Move to Album or a track first")
            else
                local val = column_value(key)
                if val ~= "" then
                    for i = 1, #cd_items do cd_items[i].data[key] = val end
                    say("Applied to all " .. #cd_items .. " track" .. (#cd_items == 1 and "" or "s"))
                    if nav_idx > 3 and not manual_people_entry then
                        for _, f in ipairs(PROPAGATE_FIELDS) do
                            if f == key then propagate_album_fields() break end
                        end
                    end
                    save_and_run()
                else
                    say("Nothing to apply")
                end
            end
        elseif char == KEY_APPLY_REST then
            local key = column_key()
            local ro = key and column_readonly(key)
            if ro or not key then
                say(ro or "Move to Album or a track first")
            else
                local val = column_value(key)
                if val ~= "" then
                    local start_i = nav_idx > 3 and (nav_idx - 3) or 1
                    local count = #cd_items - start_i + 1
                    for i = start_i, #cd_items do cd_items[i].data[key] = val end
                    say("Applied to " .. count .. " track" .. (count == 1 and "" or "s"))
                    if nav_idx > 3 and not manual_people_entry then
                        for _, f in ipairs(PROPAGATE_FIELDS) do
                            if f == key then propagate_album_fields() break end
                        end
                    end
                    save_and_run()
                else
                    say("Nothing to apply")
                end
            end
        elseif char == KEY_COPY_PREV then
            local key = column_key()
            if not key then
                say("Move to Album or a track first")
            elseif nav_idx <= 3 then
                say("Not applicable to album")
            elseif nav_idx == 4 then
                say("No previous track")
            elseif column_readonly(key) then
                say(column_readonly(key))
            else
                local prev_val = cd_items[nav_idx - 4].data[key] or ""
                if prev_val ~= "" then
                    say("Copied from previous track: " .. prev_val)
                    local ok, value = prompt_column_value(key, prev_val)
                    if ok then
                        commit_column(key, value)
                        local isrc_msg = propagate_isrc_if_first_track(key)
                        announce_nav_position()
                        if isrc_msg ~= "" then say(isrc_msg) end
                        save_and_run()
                    end
                else
                    say("Previous track has no value for this field")
                end
            end
        elseif char == KEY_COPY_ALBUM then
            local key = column_key()
            if not key then
                say("Move to Album or a track first")
            elseif nav_idx == 3 then
                say("Already on album")
            elseif column_readonly(key) then
                say(column_readonly(key))
            else
                local album_val = album_data[key] or ""
                if album_val ~= "" then
                    say("Copied from album: " .. album_val)
                    local ok, value = prompt_column_value(key, album_val)
                    if ok then
                        commit_column(key, value)
                        announce_nav_position()
                        save_and_run()
                    end
                else
                    say("Album has no value for this field")
                end
            end
        elseif char == 104 or char == 72 then
            help.enter(nav_shortcuts(), function() say(nav_label(nav_idx)) end)
        elseif char == KEY_ESC then
            save_and_run(true)
            return false
        end
    elseif state == STATE_RENDER then
        local f = RENDER_FIELDS[render_field_idx]
        if char == KEY_UP then
            render_pending_idx = render_pending_idx > 1 and render_pending_idx - 1 or #f.list
            say(f.labels[render_pending_idx])
        elseif char == KEY_DOWN then
            render_pending_idx = render_pending_idx < #f.list and render_pending_idx + 1 or 1
            say(f.labels[render_pending_idx])
        elseif char == KEY_ENTER then
            local chosen = f.list[render_pending_idx]
            if f.key == "samplerate" then
                cur_samplerate = chosen
                render_settings.save_samplerate(chosen)
            elseif f.key == "bitdepth" then
                cur_bitdepth = chosen
                render_settings.save_bitdepth(chosen)
                if chosen ~= 16 then
                    cur_dither = "Off"
                    render_settings.save_dither("Off")
                end
            else
                cur_dither = chosen
                render_settings.save_dither(chosen)
            end

            render_field_idx = render_field_idx + 1

            if render_field_idx == 3 and cur_bitdepth ~= 16 then
                state = STATE_NAV
                say("Dither not applicable above 16-bit. Saved.")
            elseif render_field_idx > #RENDER_FIELDS then
                state = STATE_NAV
                say("Render Settings saved")
            else
                render_pending_idx = render_current_index(render_field_idx)
                announce_render_field()
            end
        elseif char == KEY_ESC then
            state = STATE_NAV
            say("Render Settings")
        end
    elseif state == STATE_RENDER_TRACK then
        local fmt = RENDER_TRACK_FORMATS[render_track_fmt_idx]
        if char == KEY_UP or char == KEY_DOWN then
            if char == KEY_UP then
                render_track_fmt_idx = render_track_fmt_idx > 1 and render_track_fmt_idx - 1 or #RENDER_TRACK_FORMATS
            else
                render_track_fmt_idx = render_track_fmt_idx < #RENDER_TRACK_FORMATS and render_track_fmt_idx + 1 or 1
            end
            announce_render_format()
        elseif char == KEY_ENTER then
            if fmt.range_eligible then
                say("Range: leave empty for all tracks, or enter one such as 1-3")
                local value = ""
                while true do
                    local ok, rng = prompt_value(fmt.label .. " - Track Range",
                        "Track range, blank for all", value)
                    if not ok then
                        say("Cancelled")
                        announce_render_format(true)
                        break
                    end
                    local regions = render_range.get_regions(0)
                    local _, err = render_range.parse(rng, #regions)
                    if err then
                        say("Invalid: " .. err .. ". Correct it or Cancel")
                        value = rng
                    else
                        render_track_range = rng
                        say("Rendering " .. fmt.label
                            .. (render_track_range ~= ""
                                and (", tracks " .. render_track_range) or ", full album."))
                        render_tracks(fmt.key, render_track_range)
                        if try_refocus() then
                            state = STATE_NAV
                            say("Render")
                        else
                            say("Closing.")
                            return false
                        end
                        break
                    end
                end
            elseif fmt.key == "custom" then
                say("Opening render dialog.")
                render_tracks(fmt.key, "")
                return false
            else
                say("Rendering " .. fmt.label .. ", full album.")
                render_tracks(fmt.key, "")
                if try_refocus() then
                    state = STATE_NAV
                    say("Render")
                else
                    say("Closing.")
                    return false
                end
            end
        elseif char == KEY_ESC then
            state = STATE_NAV
            say("Render")
        end
    elseif state == STATE_CDSET then
        local f = CDSET_FIELDS[cdset_idx]
        if char == KEY_UP then
            cdset_idx = cdset_idx > 1 and cdset_idx - 1 or #CDSET_FIELDS
            announce_cdset_field(true)
        elseif char == KEY_DOWN then
            cdset_idx = cdset_idx < #CDSET_FIELDS and cdset_idx + 1 or 1
            announce_cdset_field(true)
        elseif char == KEY_ENTER then
            if f.key == "digital" then
                digital_release_only = not digital_release_only
                say(cdset_value_label(cdset_idx))
            elseif f.key == "isrc_manual" then
                manual_isrc = not manual_isrc
                if not manual_isrc then propagate_isrc() end
                say(cdset_value_label(cdset_idx))
            elseif f.key == "people_manual" then
                manual_people_entry = not manual_people_entry
                if not manual_people_entry then propagate_album_fields() end
                say(cdset_value_label(cdset_idx))
            elseif f.key == "offsets" then
                do_marker_offsets_action()
            else
                local current = tostring(f.key == "cdpre" and cd_pre_roll or cd_post_roll)
                local ok, num_str = prompt_value(f.label, f.label .. " in seconds", current)
                if not ok then
                    say("Cancelled")
                else
                    local num = tonumber(num_str)
                    if num and num > 0 then
                        if f.key == "cdpre" then cd_pre_roll = num else cd_post_roll = num end
                        say(cdset_value_label(cdset_idx))
                    else
                        say("Please enter a positive number of seconds")
                    end
                end
            end
        elseif char == KEY_ESC then
            state = STATE_NAV
            say(nav_label(nav_idx))
        end
    end
    return true
end

local ddp_window_has_drawn = false

local function main()
    if not gui_mode.accessible() then
        save_and_run()
        gfx.quit()
        gui_mode.switch_window("ReaClassical_Create CD Markers.lua")
        return
    end

    if ddp_window_has_drawn then
        show_pending_ddp_warnings()
    end

    local char = gfx.getchar()
    if char ~= last_char and gui_mode.gfx_shortcut(char) then
        last_char = char
        gui_mode.toggle_and_announce()
        defer(main)
        return
    end
    if char == -1 then
        save_and_run(true)
        return
    end
    if char == 0 then
        last_char = 0
    elseif char ~= last_char then
        last_char = char
        local consumed = help.is_active() and help.handle_key(char)
        if not consumed then
            if not handle_key(char) then
                gfx.quit()
                return
            end
        end
    end
    draw_window()
    ddp_window_has_drawn = true
    defer(main)
end

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
    say("First track isn't a folder. Run createcd first.")
    return
end

local isrc_changed, album_changed = load_data()

if #cd_items == 0 then
    say("No CD track items found. Run createcd first.")
    return
end

if not found_album_metadata then
    say("No album metadata found. Run createcd first.")
    return
end

if isrc_changed or album_changed then
    Undo_BeginBlock()
    if isrc_changed then
        for i = 2, #cd_items do
            local cd = cd_items[i]
            GetSetMediaItemTakeInfo_String(cd.take, "P_NAME", serialize_track(cd.data), true)
        end
    end
    if album_changed then
        album_meta_store.set_album_metadata_str(folder_track, serialize_album(album_data), album_legacy_item)
    end
    _G.RC_SCRIPT_ARGS = { no_undo_wrap = true }
    dofile(parent_path .. "ReaClassical_Create CD Markers.lua")
    _G.RC_SCRIPT_ARGS = nil
    Undo_EndBlock("DDP Metadata Auto-Populate", -1)
    load_data()
end

gfx.init(WINDOW_TITLE, 600, 44, 0)

say(string.format(
    "DDP Metadata Editor. %d CD track%s. Up down to move, Left right to "
    .. "choose a metadata type, Enter to edit the viewed cell, H for "
    .. "shortcuts, Escape to save and close. On: %s.",
    #cd_items, #cd_items == 1 and "" or "s", nav_label(nav_idx)
))

defer(main)
