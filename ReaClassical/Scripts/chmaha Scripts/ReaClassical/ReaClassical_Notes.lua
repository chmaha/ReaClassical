local ctx            = reaper.ImGui_CreateContext('Notes Window')
local window_open    = true

-- Default target window size
local DEFAULT_W      = 350
local DEFAULT_H      = 375

-- Minimum heights for each section
local MIN_H_PROJECT  = 60
local MIN_H_TRACK    = 80
local MIN_H_ITEM     = 80

-- Buffers
local project_note   = ""
local track_note     = ""
local item_note      = ""

-- Selection tracking
local last_item      = nil
local last_track     = nil
local last_proj_note = nil

-- Editing freeze pointers
local editing_item   = nil
local editing_track  = nil

-- Helper to get item GUID
local function get_item_guid(item)
    local ok, guid = reaper.GetSetMediaItemInfo_String(item, "GUID", "", false)
    if ok then return guid end
    return nil
end

function main()
    local item  = reaper.GetSelectedMediaItem(0, 0)
    local track = reaper.GetSelectedTrack(0, 0)
    local proj  = 0

    ------------------------------------------------------------------
    -- PROJECT NOTE (load once)
    ------------------------------------------------------------------
    if last_proj_note == nil then
        local _, str = reaper.GetSetProjectNotes(proj, false, "")
        project_note = str or ""
        last_proj_note = project_note
    end

    ------------------------------------------------------------------
    -- TRACK NOTE (flush when selection changes)
    ------------------------------------------------------------------
    local track_guid = track and reaper.GetTrackGUID(track) or nil
    if editing_track ~= track then
        editing_track = nil
        if track then
            local _, str = reaper.GetSetMediaTrackInfo_String(track, "P_EXT:track_notes", "", false)
            track_note = str or ""
        else
            track_note = ""
        end
    end

    ------------------------------------------------------------------
    -- ITEM NOTE (flush when selection changes)
    ------------------------------------------------------------------
    local item_guid = item and get_item_guid(item) or nil
    if editing_item ~= item then
        editing_item = nil
        if item then
            local _, str = reaper.GetSetMediaItemInfo_String(item, "P_NOTES", "", false)
            item_note = str or ""
        else
            item_note = ""
        end
    end

    ------------------------------------------------------------------
    -- WINDOW
    ------------------------------------------------------------------
    if window_open then
        -- Prevent window from shrinking below minimum size
        reaper.ImGui_SetNextWindowSizeConstraints(ctx, DEFAULT_W, DEFAULT_H, 10000, 10000)
        local opened, open_ref = reaper.ImGui_Begin(ctx, "Notes", window_open)
        window_open = open_ref

        if opened then
            local avail_w, avail_h   = reaper.ImGui_GetContentRegionAvail(ctx)

            -- Proportional heights for text boxes
            local static_height      = 3 * reaper.ImGui_GetTextLineHeightWithSpacing(ctx) + 40
            local save_button_height = 30
            local dynamic_h          = math.max(0, avail_h - static_height - save_button_height)

            local base_total         = MIN_H_PROJECT + MIN_H_TRACK + MIN_H_ITEM
            local extra              = math.max(0, dynamic_h - base_total)

            local h_project          = math.max(MIN_H_PROJECT, MIN_H_PROJECT + extra * 0.2)
            local h_track            = math.max(MIN_H_TRACK, MIN_H_TRACK + extra * 0.4)
            local h_item             = math.max(MIN_H_ITEM, MIN_H_ITEM + extra * 0.4)

            ------------------------------------------------------------------
            -- PROJECT NOTE
            ------------------------------------------------------------------
            reaper.ImGui_Text(ctx, "Project Note:")
            local changed_p
            changed_p, project_note = reaper.ImGui_InputTextMultiline(ctx, "##project_note", project_note, avail_w,
                h_project)
            if changed_p then
                reaper.GetSetProjectNotes(proj, true, project_note)
            end

            ------------------------------------------------------------------
            -- TRACK NOTE
            ------------------------------------------------------------------
            reaper.ImGui_Text(ctx, "Track Note:")
            local changed_t
            changed_t, track_note = reaper.ImGui_InputTextMultiline(ctx, "##track_note", track_note, avail_w, h_track)
            if changed_t and editing_track == nil then
                editing_track = track
            end

            ------------------------------------------------------------------
            -- ITEM NOTE
            ------------------------------------------------------------------
            reaper.ImGui_Text(ctx, "Item Note:")
            local changed_i
            changed_i, item_note = reaper.ImGui_InputTextMultiline(ctx, "##item_note", item_note, avail_w, h_item)
            if changed_i and editing_item == nil then
                editing_item = item
            end

            ------------------------------------------------------------------
            -- SAVE BUTTON (always visible)
            ------------------------------------------------------------------
            if reaper.ImGui_Button(ctx, "Save Notes", avail_w, save_button_height) then
                if editing_track then
                    reaper.GetSetMediaTrackInfo_String(editing_track, "P_EXT:track_notes", track_note, true)
                end
                if editing_item then
                    reaper.GetSetMediaItemInfo_String(editing_item, "P_NOTES", item_note, true)
                end
                editing_track = nil
                editing_item  = nil
            end

            reaper.ImGui_End(ctx)
        end

        reaper.defer(main)
    end
end

function toggle_window()
    if window_open then
        window_open = false
    else
        window_open = true
        main()
    end
end

main()

