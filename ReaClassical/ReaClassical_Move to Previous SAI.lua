for key in pairs(reaper) do _G[key] = reaper[key] end
local solo, mixer, get_color_table, get_path, trackname_check

function prev_sai_marker()
    local playPos = GetPlayPosition()   -- current playhead
    local editPos = GetCursorPosition() -- edit cursor
    local sel_track = GetSelectedTrack(0, 0)
    local start_track_idx = sel_track and math.floor(GetMediaTrackInfo_Value(sel_track, "IP_TRACKNUMBER")) or 1
    local num_tracks = CountTracks(0)

    -- If playhead is > 2s ahead of edit cursor, just move to edit cursor
    if playPos - editPos > 2 then
        SetEditCurPos(editPos, true, true)
        return
    end

    -- collect all SAI markers by track
    local track_markers = {}
    local num_markers = CountProjectMarkers(0)
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, idx = EnumProjectMarkers(i)
        if not isrgn then
            local track_num = tonumber(name:match("^(%d+):"))
            if track_num and name:match("SAI") then
                track_markers[track_num] = track_markers[track_num] or {}
                table.insert(track_markers[track_num], {pos=pos, idx=idx})
            end
        end
    end

    -- search for previous marker starting from current track, going backward
    for offset = 0, num_tracks-1 do
        local track_idx = ((start_track_idx - offset - 1 + num_tracks) % num_tracks) + 1
        local markers = track_markers[track_idx]
        if markers then
            table.sort(markers, function(a,b) return a.pos > b.pos end) -- sort descending
            for _, marker in ipairs(markers) do
                if offset > 0 or marker.pos < editPos - 1e-9 then
                    local track = GetTrack(0, track_idx-1)
                    SetEditCurPos(marker.pos, true, true) -- move cursor and scroll
                    Main_OnCommand(40297, 0) -- unselect all tracks
                    SetTrackSelected(track, true)
                    solo() -- call your existing solo function
                    return
                end
            end
        end
    end
end

function solo()
    Main_OnCommand(40491, 0) -- un-arm all tracks for recording
    local selected_track = GetSelectedTrack(0, 0)
    local parent = GetMediaTrackInfo_Value(selected_track, "I_FOLDERDEPTH")

    for i = 0, CountTracks(0) - 1, 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
        local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)
        local _, rt_state = GetSetMediaTrackInfo_String(track, "P_EXT:roomtone", "", false)
        local _, ref_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcref", "", false)
        local _, rcmaster_state = GetSetMediaTrackInfo_String(track, "P_EXT:rcmaster", "", false)

        if mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y" or ref_state == "y" then
            local num_of_sends = GetTrackNumSends(track, 0)
            for j = 0, num_of_sends - 1, 1 do
                SetTrackSendInfo_Value(track, 0, j, "B_MUTE", 0)
            end
        end

        if not (mixer_state == "y" or aux_state == "y" or submix_state == "y" or rt_state == "y"
                or ref_state == "y" or rcmaster_state == "y") then
            if IsTrackSelected(track) and parent ~= 1 then
                SetMediaTrackInfo_Value(track, "I_SOLO", 2)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            elseif IsTrackSelected(track) == false and GetParentTrack(track) ~= selected_track then
                SetMediaTrackInfo_Value(track, "B_MUTE", 1)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            else
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if rt_state == "y" then
            if IsTrackSelected(track) then
                SetMediaTrackInfo_Value(track, "B_MUTE", 0)
                SetMediaTrackInfo_Value(track, "I_SOLO", 0)
            end
        end

        if ref_state == "y" then
            local is_selected = IsTrackSelected(track)
            local mute_state = 1
            local solo_state = 0

            if is_selected then
                Main_OnCommand(40340, 0) -- unsolo all tracks
                mute_state = 0
                solo_state = 1
            elseif ref_is_guide == 1 then
                mute_state = 0
                solo_state = 0
            end

            SetMediaTrackInfo_Value(track, "B_MUTE", mute_state)
            SetMediaTrackInfo_Value(track, "I_SOLO", solo_state)
        end

        if rcmaster_state == "y" then
            SetMediaTrackInfo_Value(track, "B_MUTE", 0)
            SetMediaTrackInfo_Value(track, "I_SOLO", 0)
        end
    end
end

-- call it
prev_sai_marker()