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

local main, parse_item_name, serialize_metadata, increment_isrc
local update_marker_and_region, update_album_marker, propagate_album_field
local track_has_valid_items, create_metadata_report_and_cue

-- local profiler = dofile(GetResourcePath() ..
--     '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
-- defer = profiler.defer

---------------------------------------------------------------------

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    local modifier = "Ctrl"
    local system = GetOS()
    if string.find(system, "^OSX") or string.find(system, "^macOS") then
        modifier = "Cmd"
    end
    MB("Please create a ReaClassical project via " .. modifier .. "+N to use this function.", "ReaClassical Error", 0)
    return
end

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

set_action_options(2)

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = ImGui.CreateContext('DDP Metadata Editor')
local window_open = true

local labels = { "Title", "Performer", "Songwriter", "Composer", "Arranger", "Message", "ISRC" }
local keys = { "title", "performer", "songwriter", "composer", "arranger", "message", "isrc" }

local album_keys_line1 = { "title", "performer", "songwriter", "composer", "arranger" }
local album_labels_line1 = { "Album Title", "Performer", "Songwriter", "Composer", "Arranger" }
local album_keys_line2 = { "genre", "identification", "language", "catalog", "message" }
local album_labels_line2 = { "Genre", "Identification", "Language", "Catalog", "Message" }

local isrc_pattern = "^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$"

local editing_track
local album_metadata, album_item
local track_items_metadata = {}
local prev_isrc_values = {}

local _, manual_isrc_entry_str = GetProjExtState(0, "ReaClassical", "manual_isrc_entry")
local manual_isrc_entry = manual_isrc_entry_str == "1"

local _, manual_people_entry_str = GetProjExtState(0, "ReaClassical", "manual_people_entry")
local manual_people_entry = manual_people_entry_str == "1"

local create_CD_markers = NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")

local first_run = true

---------------------------------------------------------------------

function main()
    if not window_open then
        create_metadata_report_and_cue()
        return
    end

    local _, FLT_MAX = ImGui.NumericLimits_Float()
    -- local album_total_width = 900
    ImGui.SetNextWindowSizeConstraints(ctx, 1000, 500, FLT_MAX, FLT_MAX)
    local opened, open_ref = ImGui.Begin(ctx, "ReaClassical DDP Metadata Editor", window_open)
    window_open = open_ref

    if opened then
        local selected_track = GetSelectedTrack(0, 0)
        if selected_track then
            local depth = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")
            if depth ~= 1 then
                local track_index = GetMediaTrackInfo_Value(selected_track, "IP_TRACKNUMBER") - 1
                local folder_track = nil
                for i = track_index - 1, 0, -1 do
                    local t = GetTrack(0, i)
                    if GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH") == 1 then
                        folder_track = t
                        break
                    end
                end
                if folder_track then selected_track = folder_track end
            end
        end
        local valid_items = track_has_valid_items(selected_track)

        if selected_track and not valid_items then
            ImGui.Text(ctx, "No valid item names found for DDP metadata editing.")
        elseif selected_track then
            local _, trigger = GetProjExtState(0, "ReaClassical", "ddp_refresh_trigger")
            if trigger == "y" then
                editing_track = nil
                SetProjExtState(0, "ReaClassical", "ddp_refresh_trigger", "")
            end

            if editing_track ~= selected_track then
                editing_track = selected_track
                Main_OnCommand(create_CD_markers, 0)
                create_metadata_report_and_cue()
                album_metadata, album_item = nil, nil
                for i = 0, CountTrackMediaItems(selected_track) - 1 do
                    local item = GetTrackMediaItem(selected_track, i)
                    local take = GetActiveTake(item)
                    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    if name:match("^@") then
                        album_metadata = parse_item_name(name, true)
                        album_item = item
                        break
                    end
                end

                track_items_metadata = {}
                local item_count = CountTrackMediaItems(selected_track)
                for i = 0, item_count - 1 do
                    local item = GetTrackMediaItem(selected_track, i)
                    local take = GetActiveTake(item)
                    local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    if name and name:match("%S") and not name:match("^@") then
                        track_items_metadata[i] = parse_item_name(name, false)
                    end
                end
            end

            if album_metadata then
                local previous_valid_catalog = album_metadata.catalog or ""
                ImGui.Text(ctx, "Album Metadata:")
                ImGui.Separator(ctx)
                ImGui.Dummy(ctx, 0, 10)

                local spacing = 5

                -- right-align the whole group
                local avail = select(1, ImGui.GetContentRegionAvail(ctx))
                local text_w = ImGui.CalcTextSize(ctx, "Manual Contributors Entry")
                local checkbox_w = ImGui.GetFrameHeight(ctx)

                ImGui.SetCursorPosX(ctx, avail - (text_w + checkbox_w + 8))

                ImGui.Text(ctx, "Manual Contributors Entry")
                ImGui.SameLine(ctx)

                _, manual_people_entry = ImGui.Checkbox(ctx, "##manual_people_chk", manual_people_entry)
                SetProjExtState(0, "ReaClassical", "manual_people_entry", manual_people_entry and "1" or "0")

                -- Units remain the same, only width calculation changes
                local line1_units = { 2, 1, 1, 1, 1 }
                local line2_units = { 0.5, 1, 0.5, 0.5, 2 }

                -- Total horizontal space available *right now*
                local avail_w = select(1, ImGui.GetContentRegionAvail(ctx))

                local total_units1, total_units2 = 0, 0
                for _, u in ipairs(line1_units) do total_units1 = total_units1 + u end
                for _, u in ipairs(line2_units) do total_units2 = total_units2 + u end

                -- Compute widths as a fraction of available window space
                local line1_widths, line2_widths = {}, {}
                for i, u in ipairs(line1_units) do
                    line1_widths[i] = (avail_w - spacing * (#line1_units - 1)) * (u / total_units1)
                end
                for i, u in ipairs(line2_units) do
                    line2_widths[i] = (avail_w - spacing * (#line2_units - 1)) * (u / total_units2)
                end

                if not manual_people_entry then
                    -- Track if any field changed
                    local album_changed = false

                    -- Propagate performer, songwriter, composer, arranger
                    for _, f in ipairs({ "performer", "songwriter", "composer", "arranger" }) do
                        local old_value = album_metadata[f]
                        propagate_album_field(f)
                        if album_metadata[f] ~= old_value then
                            album_changed = true
                        end
                    end

                    -- Write back to album item and update marker only if something changed
                    if album_changed and album_item then
                        local take = GetActiveTake(album_item)
                        if take then
                            local new_name = serialize_metadata(album_metadata, true)
                            GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                            update_album_marker(album_item)
                        end
                    end
                end

                for j = 1, #album_keys_line1 do
                    if not manual_people_entry and (album_keys_line1[j] ~= "title") then
                        ImGui.BeginDisabled(ctx)
                    end
                    ImGui.BeginGroup(ctx)
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, album_labels_line1[j])
                    ImGui.PushItemWidth(ctx, line1_widths[j])
                    local changed
                    local albumkeys1_widget_id = "##album_" .. album_keys_line1[j] .. "_" .. tostring(selected_track)
                    changed, album_metadata[album_keys_line1[j]] = ImGui.InputText(
                        ctx,
                        albumkeys1_widget_id,
                        album_metadata[album_keys_line1[j]] or "",
                        128
                    )
                    ImGui.PopItemWidth(ctx)
                    ImGui.EndGroup(ctx)
                    if j < #album_keys_line1 then ImGui.SameLine(ctx, 0, spacing) end
                    if changed and GetSelectedTrack(0, 0) == editing_track then
                        local take = GetActiveTake(album_item)
                        local new_name = serialize_metadata(album_metadata, true)
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                        update_album_marker(album_item)
                    end
                    if not manual_people_entry and (album_keys_line1[j] ~= "title") then
                        ImGui.EndDisabled(ctx)
                    end
                end

                for j = 1, #album_keys_line2 do
                    ImGui.BeginGroup(ctx)
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, album_labels_line2[j])
                    ImGui.PushItemWidth(ctx, line2_widths[j])

                    local key = album_keys_line2[j]
                    local changed
                    local albumkeys2_widget_id = "##album_" .. key .. "_" .. tostring(selected_track)
                    changed, album_metadata[key] = ImGui.InputText(
                        ctx,
                        albumkeys2_widget_id,
                        album_metadata[key] or "",
                        128
                    )

                    ImGui.PopItemWidth(ctx)
                    ImGui.EndGroup(ctx)
                    if j < #album_keys_line2 then ImGui.SameLine(ctx, 0, spacing) end

                    if changed and GetSelectedTrack(0, 0) == editing_track then
                        if key == "catalog" then
                            local v = album_metadata.catalog or ""

                            if not v:match("^%d*$") or (v ~= "" and (#v ~= 12 and #v ~= 13)) then
                                album_metadata.catalog = previous_valid_catalog
                                goto skip_album_write
                            end

                            previous_valid_catalog = v
                        end

                        local take = GetActiveTake(album_item)
                        local new_name = serialize_metadata(album_metadata, true)
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                        update_album_marker(album_item)

                        ::skip_album_write::
                    end
                end
            end
            ImGui.Dummy(ctx, 0, 10)
            ImGui.Text(ctx, "Track Metadata:")
            ImGui.Separator(ctx)

            -- right-align the whole group
            local avail = select(1, ImGui.GetContentRegionAvail(ctx))
            local text_w = ImGui.CalcTextSize(ctx, "Manual ISRC entry")
            local checkbox_w = ImGui.GetFrameHeight(ctx)

            ImGui.SetCursorPosX(ctx, avail - (text_w + checkbox_w + 8))

            ImGui.Text(ctx, "Manual ISRC entry")
            ImGui.SameLine(ctx)

            _, manual_isrc_entry = ImGui.Checkbox(ctx, "##manual_isrc_chk", manual_isrc_entry)
            SetProjExtState(0, "ReaClassical", "manual_isrc_entry", manual_isrc_entry and "1" or "0")

            local item_count = CountTrackMediaItems(selected_track)
            local spacing = 5
            local padding_right = 15

            local track_number_counter = 1
            local avail_w, _ = ImGui.GetContentRegionAvail(ctx)
            local normal_boxes = #keys - 1
            local normal_box_w = (avail_w - padding_right - spacing * (#keys)) / (normal_boxes + 2)
            local title_box_w = 2 * normal_box_w
            local first_isrc = nil

            local track_number_w, _ = ImGui.CalcTextSize(ctx, "00")
            track_number_w = track_number_w + spacing
            ImGui.Dummy(ctx, track_number_w, 0)
            ImGui.SameLine(ctx, 0, spacing)
            for j = 1, #keys do
                ImGui.BeginGroup(ctx)
                local w = (j == 1) and title_box_w or normal_box_w
                ImGui.Dummy(ctx, w, 0)
                ImGui.AlignTextToFramePadding(ctx)
                ImGui.Text(ctx, labels[j])
                ImGui.EndGroup(ctx)
                if j < #keys then ImGui.SameLine(ctx, 0, spacing) end
            end

            ImGui.Dummy(ctx, 0, 5)

            for i = 0, item_count - 1 do
                local md = track_items_metadata[i]
                if md and md.isrc and md.isrc:match(isrc_pattern) then
                    first_isrc = md.isrc
                    break
                end
            end

            local any_changed = false
            local changed

            for i = 0, item_count - 1 do
                local item = GetTrackMediaItem(selected_track, i)
                local take = GetActiveTake(item)
                local md = track_items_metadata[i]
                if md then
                    ImGui.BeginGroup(ctx)
                    local track_number_str = string.format("%02d", track_number_counter)
                    ImGui.AlignTextToFramePadding(ctx)
                    ImGui.Text(ctx, track_number_str)
                    ImGui.SameLine(ctx, 0, spacing)
                    local original_title = md.title
                    ImGui.PushItemWidth(ctx, title_box_w)
                    local title_widget_id = "##" .. i .. "_title_" .. tostring(selected_track)
                    changed, md.title = ImGui.InputText(ctx, title_widget_id, md.title or "", 128)
                    any_changed = any_changed or changed
                    ImGui.PopItemWidth(ctx)
                    if md.title == "" then md.title = original_title end
                    ImGui.EndGroup(ctx)

                    for j = 2, #keys do
                        ImGui.SameLine(ctx, 0, spacing)
                        ImGui.BeginGroup(ctx)
                        ImGui.PushItemWidth(ctx, normal_box_w)
                        local keys_widget_id = "##" .. i .. "_" .. keys[j] .. " " .. tostring(selected_track)
                        if keys[j] == "isrc" and not manual_isrc_entry and i > 0 then
                            ImGui.BeginDisabled(ctx)
                        end
                        changed, md[keys[j]] = ImGui.InputText(ctx, keys_widget_id, md[keys[j]] or "", 128)
                        if keys[j] == "isrc" and not manual_isrc_entry and i > 0 then
                            ImGui.EndDisabled(ctx)
                        end
                        any_changed = any_changed or changed

                        if keys[j] == "isrc" then
                            local prev_isrc = prev_isrc_values[i] or md.isrc -- default to current
                            if manual_isrc_entry then
                                -- In manual mode, validate after input
                                if changed then
                                    if md.isrc ~= "" and not md.isrc:match(isrc_pattern) then
                                        md.isrc = prev_isrc -- revert if invalid
                                    end
                                end
                            else
                                -- Auto-increment mode (existing logic)
                                if i == 0 then
                                    if md.isrc == "" then
                                        first_isrc = nil
                                    elseif md.isrc:match(isrc_pattern) then
                                        first_isrc = md.isrc
                                    else
                                        md.isrc = first_isrc or ""
                                    end
                                else
                                    if first_isrc then
                                        md.isrc = increment_isrc(first_isrc, track_number_counter - 1)
                                    else
                                        if md.isrc ~= "" and not md.isrc:match(isrc_pattern) then
                                            md.isrc = ""
                                        end
                                    end
                                end
                            end
                            -- Store current value as previous for next frame
                            prev_isrc_values[i] = md.isrc
                        end

                        ImGui.PopItemWidth(ctx)
                        ImGui.EndGroup(ctx)
                    end

                    if any_changed or first_run then
                        local new_name = serialize_metadata(md, false)
                        GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                        update_marker_and_region(item)
                    end

                    track_number_counter = track_number_counter + 1
                    ImGui.Dummy(ctx, 0, 10)
                end
            end
            first_run = false
        else
            ImGui.Text(ctx, "No track selected. Please select a folder track to edit metadata.")
        end

        ImGui.End(ctx)
    end

    defer(main)
end

---------------------------------------------------------------------

function parse_item_name(name, is_album)
    local data = {}
    local parts = {}
    for part in name:gmatch("[^|]+") do table.insert(parts, part) end
    if #parts > 0 then
        if is_album then
            data.title = parts[1]:gsub("^@", "")
            for i = 2, #parts do
                local k, v = parts[i]:match("^(%w+)=(.+)$")
                if k and v then
                    k = k:lower()
                    for j = 1, #album_keys_line1 do if k == album_keys_line1[j] then data[k] = v end end
                    for j = 1, #album_keys_line2 do if k == album_keys_line2[j] then data[k] = v end end
                end
            end
        else
            data.title = parts[1] or name
            for i = 2, #parts do
                local k, v = parts[i]:match("^(%w+)=(.+)$")
                if k and v then
                    k = k:lower()
                    -- Preserve OFFSET
                    if k == "offset" then
                        data._offset = v
                    else
                        for _, kk in ipairs(keys) do
                            if k == kk then data[k] = v end
                        end
                    end
                end
            end
        end
    else
        data.title = name:gsub("^@", "")
    end
    return data
end

---------------------------------------------------------------------

function serialize_metadata(data, is_album)
    local parts = {}
    if is_album then
        parts[#parts + 1] = "@" .. (data.title or "")
        for _, k in ipairs(album_keys_line1) do
            if k ~= "title" and data[k] and data[k] ~= "" then parts[#parts + 1] = k:upper() .. "=" .. data[k] end
        end
        for _, k in ipairs(album_keys_line2) do
            if data[k] and data[k] ~= "" then parts[#parts + 1] = k:upper() .. "=" .. data[k] end
        end
    else
        parts[#parts + 1] = data.title or ""

        -- Insert OFFSET immediately after title if present
        if data._offset and data._offset ~= "" then
            parts[#parts + 1] = "OFFSET=" .. data._offset
        end

        for _, k in ipairs(keys) do
            if k ~= "title" and data[k] and data[k] ~= "" then
                parts[#parts + 1] = k:upper() .. "=" .. data[k]
            end
        end
    end
    return table.concat(parts, "|")
end

---------------------------------------------------------------------

function increment_isrc(isrc, offset)
    local prefix, year, seq = isrc:match("^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$")
    if not prefix or not year or not seq then return isrc end
    local new_seq = tonumber(seq) + offset
    return string.format("%s%s%05d", prefix, year, new_seq)
end

---------------------------------------------------------------------

function update_marker_and_region(item)
    if not item then return end

    local take = GetActiveTake(item)
    if not take then return end

    local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not item_name or item_name == "" then return end

    -- Clean name (remove OFFSET)
    local clean_name = item_name:gsub("|OFFSET=[%d%.%-]+", "")

    local track = GetMediaItemTrack(item)
    local track_color = GetTrackColor(track)

    -- Get stored marker GUID from item's P_EXT:cdmarker
    local ok, guid = GetSetMediaItemInfo_String(item, "P_EXT:cdmarker", "", false)
    if not ok or guid == "" then return end

    -- Find marker index using GUID
    local ok_index, mark_index_str = GetSetProjectInfo_String(0, "MARKER_INDEX_FROM_GUID:" .. guid, "", false)
    if not ok_index or mark_index_str == "" then return end

    local mark_index = tonumber(mark_index_str)
    if not mark_index then return end

    -- Update the marker
    local retval, isrgn, pos, rgnend, _, markrgnID, color = EnumProjectMarkers3(0, mark_index)
    if retval and not isrgn and track_color == color then
        SetProjectMarkerByIndex(0, mark_index, false, pos, 0, markrgnID, "#" .. clean_name, color)
    end

    -- Find and update the associated region
    local item_pos = GetMediaItemInfo_Value(item, "D_POSITION")
    local num_markers, num_regions = CountProjectMarkers(0)

    for idx = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, rgnend, _, markrgnID, color = EnumProjectMarkers3(0, idx)
        if isrgn and pos <= item_pos and item_pos <= rgnend then
            if track_color == color then
                SetProjectMarkerByIndex(0, idx, true, pos, rgnend, markrgnID,
                    parse_item_name(clean_name, false).title, color)
            end
            break
        end
    end
end

---------------------------------------------------------------------

function update_album_marker(item)
    if not item then return end
    local take = GetActiveTake(item)
    if not take then return end
    local _, item_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not item_name or not item_name:match("^@") then return end

    local num_markers, num_regions = CountProjectMarkers(0)
    for idx = 0, num_markers + num_regions - 1 do
        local _, isrgn, pos, _, name, markrgnID = EnumProjectMarkers(idx)
        if not isrgn and name:match("^@") then
            SetProjectMarkerByIndex(0, idx, false, pos, 0, markrgnID, item_name, 0)
            break
        end
    end
end

---------------------------------------------------------------------

function propagate_album_field(field)
    local val, mixed = nil, false

    -- Gather track values
    for _, md in pairs(track_items_metadata) do
        if md and md[field] and md[field] ~= "" then
            if not val then
                val = md[field]
            elseif val ~= md[field] then
                mixed = true
                break
            end
        end
    end

    -- Determine desired album value
    local desired = nil
    if val then
        desired = mixed and "Various" or val
    end

    album_metadata[field] = desired
end

---------------------------------------------------------------------

function track_has_valid_items(track)
    if not track then return false end
    local item_count = CountTrackMediaItems(track)
    if item_count == 0 then return false end
    for i = 0, item_count - 1 do
        local item = GetTrackMediaItem(track, i)
        local take = GetActiveTake(item)
        if take then
            local _, name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if name and (name:match("^@") or name:match("^#")) then return true end
        end
    end
    return false
end

---------------------------------------------------------------------

function create_metadata_report_and_cue()
    local metadata_report = NamedCommandLookup("_RS9dfbe237f69ecb0151b67e27e607b93a7bd0c4b4")
    Main_OnCommand(metadata_report, 0)
end

---------------------------------------------------------------------

-- profiler.attachToWorld()
-- profiler.run()

defer(main)
