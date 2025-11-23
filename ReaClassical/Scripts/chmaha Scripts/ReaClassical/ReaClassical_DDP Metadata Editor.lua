-- @noindex

for key in pairs(reaper) do _G[key] = reaper[key] end

if not reaper.APIExists("ImGui_GetVersion") then
    reaper.MB('Please install ReaImGui before running this script', 'Error', 0)
    return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

local ctx = reaper.ImGui_CreateContext('DDP Metadata Editor')
local window_open = true

-- Track item labels
local labels = { "Title", "Performer", "Songwriter", "Composer", "Arranger", "Message", "ISRC" }
local keys = { "title", "performer", "songwriter", "composer", "arranger", "message", "isrc" }

-- Album labels
local album_keys_line1 = { "title", "performer", "songwriter", "composer", "arranger" }
local album_labels_line1 = { "Album Title", "Performer", "Songwriter", "Composer", "Arranger" }
local album_keys_line2 = { "genre", "identification", "language", "catalog", "message" }
local album_labels_line2 = { "Genre", "Identification", "Language", "Catalog", "Message" }

-- Parse item name
local function parseItemName(name, is_album)
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
                    for j = 1, #keys do if k == keys[j] then data[k] = v end end
                end
            end
        end
    else
        data.title = name:gsub("^@", "")
    end
    return data
end

-- Serialize metadata
local function serializeMetadata(data, is_album)
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
        for _, k in ipairs(keys) do
            if k ~= "title" and data[k] and data[k] ~= "" then parts[#parts + 1] = k:upper() .. "=" .. data[k] end
        end
    end
    return table.concat(parts, "|")
end

-- ISRC validation pattern (no hyphens)
local isrc_pattern = "^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$"

-- Increment ISRC
local function incrementISRC(isrc, offset)
    local prefix, year, seq = isrc:match("^(%a%a%w%w%w)(%d%d)(%d%d%d%d%d)$")
    if not prefix or not year or not seq then return isrc end
    local new_seq = tonumber(seq) + offset
    return string.format("%s%s%05d", prefix, year, new_seq)
end

-- Update nearest marker and region for a track item
local function update_marker_and_region(item)
    if not item then return end
    local take = reaper.GetActiveTake(item)
    if not take then return end
    local _, item_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not item_name or item_name == "" then return end

    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local threshold = 0.5 -- seconds, allow slightly before the item start

    local num_markers, num_regions = reaper.CountProjectMarkers(0)

    -- First, update the marker
    for idx = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnID = reaper.EnumProjectMarkers(idx)
        if not isrgn and pos <= item_pos and item_pos - pos <= threshold then
            reaper.SetProjectMarkerByIndex(0, idx, false, pos, 0, markrgnID, "#" .. item_name, 0)
            break -- only update first matching marker
        end
    end

    -- Then, update the region
    for idx = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnID = reaper.EnumProjectMarkers(idx)
        if isrgn and pos <= item_pos and item_pos <= rgnend then
            reaper.SetProjectMarkerByIndex(0, idx, true, pos, rgnend, markrgnID, parseItemName(item_name,false).title, 0)
            break -- only update first matching region
        end
    end
end

-- Update album marker (@) by name
local function update_album_marker(album_item)
    if not album_item then return end
    local take = reaper.GetActiveTake(album_item)
    if not take then return end
    local _, item_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
    if not item_name or not item_name:match("^@") then return end

    local num_markers, num_regions = reaper.CountProjectMarkers(0)
    for idx = 0, num_markers + num_regions - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnID = reaper.EnumProjectMarkers(idx)
        if not isrgn and name:match("^@") then
            reaper.SetProjectMarkerByIndex(0, idx, false, pos, 0, markrgnID, item_name, 0)
            break
        end
    end
end

local function main()
    if not window_open then return end

    local album_total_width = 900
    reaper.ImGui_SetNextWindowSizeConstraints(ctx, album_total_width, 0, 10000, 10000)
    local opened, open_ref = reaper.ImGui_Begin(ctx, "DDP Metadata Editor", window_open)
    window_open = open_ref

    if opened then
        local selected_track = reaper.GetSelectedTrack(0, 0)
        if not selected_track then return end

        -- Find folder parent
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

        -- Find album metadata item
        local album_metadata, album_item = nil, nil
        for i = 0, reaper.CountTrackMediaItems(selected_track) - 1 do
            local item = reaper.GetTrackMediaItem(selected_track, i)
            local take = reaper.GetActiveTake(item)
            local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            if name:match("^@") then
                album_metadata = parseItemName(name, true)
                album_item = item
                break
            end
        end

        -- Album editor
        if album_metadata then
            reaper.ImGui_Text(ctx, "Album Metadata:")
            reaper.ImGui_Separator(ctx)
            local spacing = 5
            local line1_units = { 2, 1, 1, 1, 1 }
            local line2_units = { 1, 1, 1, 1, 1 }
            local total_units1, total_units2 = 0,0
            for _, u in ipairs(line1_units) do total_units1 = total_units1 + u end
            for _, u in ipairs(line2_units) do total_units2 = total_units2 + u end
            local line1_widths, line2_widths = {},{}
            for i,u in ipairs(line1_units) do line1_widths[i] = album_total_width*(u/total_units1) end
            for i,u in ipairs(line2_units) do line2_widths[i] = album_total_width*(u/total_units2) end

            -- line1
            for j = 1,#album_keys_line1 do
                reaper.ImGui_BeginGroup(ctx)
                reaper.ImGui_AlignTextToFramePadding(ctx)
                reaper.ImGui_Text(ctx, album_labels_line1[j])
                reaper.ImGui_PushItemWidth(ctx, line1_widths[j])
                local changed
                changed, album_metadata[album_keys_line1[j]] = reaper.ImGui_InputText(ctx, "##album_"..album_keys_line1[j], album_metadata[album_keys_line1[j]] or "",128)
                reaper.ImGui_PopItemWidth(ctx)
                reaper.ImGui_EndGroup(ctx)
                if j < #album_keys_line1 then reaper.ImGui_SameLine(ctx, 0, spacing) end
                if changed then
                    local take = reaper.GetActiveTake(album_item)
                    local new_name = serializeMetadata(album_metadata,true)
                    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name, true)
                    update_album_marker(album_item)
                end
            end

            -- line2
            for j = 1,#album_keys_line2 do
                reaper.ImGui_BeginGroup(ctx)
                reaper.ImGui_AlignTextToFramePadding(ctx)
                reaper.ImGui_Text(ctx, album_labels_line2[j])
                reaper.ImGui_PushItemWidth(ctx, line2_widths[j])
                local original_val = album_metadata[album_keys_line2[j]]
                local changed
                changed, album_metadata[album_keys_line2[j]] = reaper.ImGui_InputText(ctx,"##album_"..album_keys_line2[j],album_metadata[album_keys_line2[j]] or "",128)
                reaper.ImGui_PopItemWidth(ctx)
                reaper.ImGui_EndGroup(ctx)
                if j < #album_keys_line2 then reaper.ImGui_SameLine(ctx,0,spacing) end
                if changed then
                    local take = reaper.GetActiveTake(album_item)
                    local new_name = serializeMetadata(album_metadata,true)
                    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", new_name,true)
                    update_album_marker(album_item)
                end
            end
            reaper.ImGui_Dummy(ctx,0,15)
        end

        -- Track items editor
        reaper.ImGui_Text(ctx,"Track Metadata:")
        reaper.ImGui_Separator(ctx)
        local item_count = reaper.CountTrackMediaItems(selected_track)
        local spacing = 5
        local padding_right = 15
        local first_item_done = false
        local track_number_counter = 1
        local avail_w,_ = reaper.ImGui_GetContentRegionAvail(ctx)
        local normal_boxes = #keys - 1
        local normal_box_w = (avail_w - padding_right - spacing*(#keys)) / (normal_boxes + 2)
        local title_box_w = 2 * normal_box_w
        local first_isrc = nil

        -- Draw labels
        if not first_item_done then
            local track_number_w,_ = reaper.ImGui_CalcTextSize(ctx,"00")
            track_number_w = track_number_w + spacing
            reaper.ImGui_Dummy(ctx, track_number_w,0)
            reaper.ImGui_SameLine(ctx,0,spacing)
            for j=1,#keys do
                reaper.ImGui_BeginGroup(ctx)
                local w = (j==1) and title_box_w or normal_box_w
                reaper.ImGui_Dummy(ctx,w,0)
                reaper.ImGui_AlignTextToFramePadding(ctx)
                reaper.ImGui_Text(ctx,labels[j])
                reaper.ImGui_EndGroup(ctx)
                if j<#keys then reaper.ImGui_SameLine(ctx,0,spacing) end
            end
            reaper.ImGui_Dummy(ctx,0,5)
        end

        -- First ISRC
        for i=0,item_count-1 do
            local item = reaper.GetTrackMediaItem(selected_track,i)
            local take = reaper.GetActiveTake(item)
            local _, name = reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false)
            if name and name:match("%S") and not name:match("^@") then
                local md = parseItemName(name,false)
                if md.isrc and md.isrc:match(isrc_pattern) then
                    first_isrc = md.isrc
                    break
                end
            end
        end

        -- Draw items
        for i=0,item_count-1 do
            local item = reaper.GetTrackMediaItem(selected_track,i)
            local take = reaper.GetActiveTake(item)
            local _, name = reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME","",false)
            if name and name:match("%S") and not name:match("^@") then
                local md = parseItemName(name,false)
                -- Track number + title
                reaper.ImGui_BeginGroup(ctx)
                local track_number_str = string.format("%02d",track_number_counter)
                reaper.ImGui_AlignTextToFramePadding(ctx)
                reaper.ImGui_Text(ctx,track_number_str)
                reaper.ImGui_SameLine(ctx,0,spacing)
                local original_title = md.title
                reaper.ImGui_PushItemWidth(ctx,title_box_w)
                local changed
                changed, md.title = reaper.ImGui_InputText(ctx,"##"..i.."_title",md.title or "",128)
                reaper.ImGui_PopItemWidth(ctx)
                if md.title=="" then md.title=original_title end
                reaper.ImGui_EndGroup(ctx)

                -- Remaining boxes
                for j=2,#keys do
                    reaper.ImGui_SameLine(ctx,0,spacing)
                    reaper.ImGui_BeginGroup(ctx)
                    reaper.ImGui_PushItemWidth(ctx, normal_box_w)
                    local original_val = md[keys[j]]
                    changed, md[keys[j]] = reaper.ImGui_InputText(ctx,"##"..i.."_"..keys[j],md[keys[j]] or "",128)
                    if keys[j]=="isrc" then
                        if md.isrc~="" and md.isrc:match(isrc_pattern) then
                            if i==0 then first_isrc = md.isrc end
                        else
                            md.isrc = first_isrc and incrementISRC(first_isrc, track_number_counter-1) or ""
                        end
                        if i>0 and first_isrc then
                            md.isrc = incrementISRC(first_isrc, track_number_counter-1)
                        end
                    end
                    reaper.ImGui_PopItemWidth(ctx)
                    reaper.ImGui_EndGroup(ctx)
                end

                -- Apply changes
                local new_name = serializeMetadata(md,false)
                reaper.GetSetMediaItemTakeInfo_String(take,"P_NAME",new_name,true)
                update_marker_and_region(item)

                first_item_done = true
                track_number_counter = track_number_counter + 1
                reaper.ImGui_Dummy(ctx,0,10)
            end
        end
    end

    reaper.ImGui_End(ctx)
    reaper.defer(main)
end

reaper.defer(main)
