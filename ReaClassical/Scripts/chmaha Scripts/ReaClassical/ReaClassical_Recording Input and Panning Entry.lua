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

local imgui_exists = APIExists("ImGui_GetVersion")
if not imgui_exists then
    MB('Please install reaimgui extension before running this function', 'Error: Missing Extension', 0)
    return
end

local _, workflow = GetProjExtState(0, "ReaClassical", "Workflow")
if workflow == "" then
    MB("Please create a ReaClassical project using F7 or F8 to use this function.", "ReaClassical Error", 0)
    return
end

package.path = ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.10'

---------------------------------------------------------------------

local ctx = ImGui.CreateContext('Track and input management')
local window_open = true

local MAX_INPUTS = GetNumAudioInputs()
local TRACKS_PER_TAB = 8

-- State storage
local mixer_tracks = {}
local d_tracks = {}            -- D: tracks from first folder (one per mixer)
local input_channels = {}      -- Store selected input channel index
local input_channels_mono = {} -- Remember mono selection when switching to stereo
local input_channels_stereo = {} -- Remember stereo selection when switching to mono
local mono_has_been_set = {}   -- Track if user has manually set mono
local stereo_has_been_set = {} -- Track if user has manually set stereo
local is_stereo = {}           -- Store stereo checkbox state
local pan_values = {}          -- Store pan values for each track
local track_names = {}         -- Store mixer track names (without M: prefix)
local current_tab = 0
local selected_track = nil     -- Currently selected track index
local sync_needed = false      -- Flag to trigger sync at end of frame
local pan_reset = {}           -- Track double-click reset for pan sliders

-- Generate input options
local mono_options = {}
local stereo_options = {}
local track_num_format = "%d"  -- Will be set based on number of tracks

function GenerateInputOptions()
    mono_options = {}
    stereo_options = {}
    table.insert(mono_options, "None")
    table.insert(stereo_options, "None")  -- Add None option for stereo too
    for i = 1, MAX_INPUTS do
        table.insert(mono_options, tostring(i))
    end
    
    for i = 1, MAX_INPUTS - 1 do
        table.insert(stereo_options, string.format("%d+%d", i, i + 1))
    end
end

function ResetPanOnDoubleClick(id, value, default)
    if ImGui.IsItemDeactivated(ctx) and pan_reset[id] then
        pan_reset[id] = nil
        return default
    elseif ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
        pan_reset[id] = true
    end
    
    return value
end

---------------------------------------------------------------------

function GetDTracksFromFirstFolder()
    local tracks = {}
    local first_folder_idx = nil
    
    -- Find the first folder
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        if folder_depth == 1 then
            first_folder_idx = i
            break
        end
    end
    
    if not first_folder_idx then return tracks end
    
    -- Get all tracks in the first folder
    -- The folder track is the first one
    table.insert(tracks, GetTrack(0, first_folder_idx))
    
    -- Continue adding tracks until we hit the end of the folder
    local i = first_folder_idx + 1
    local depth = 1
    
    while i < CountTracks(0) and depth > 0 do
        local track = GetTrack(0, i)
        local folder_change = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        
        -- Add track before checking depth (so we include the last track)
        if depth > 0 then
            table.insert(tracks, track)
        end
        
        -- Update depth after adding
        depth = depth + folder_change
        i = i + 1
    end
    
    return tracks
end

function CreateMixerTable()
    local tracks = {}
    
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
        if mixer_state == "y" then
            table.insert(tracks, {
                mixer_track = track,
                mixer_index = i
            })
        end
    end
    return tracks
end

function GetCurrentInputInfo(d_track)
    local recInput = GetMediaTrackInfo_Value(d_track, "I_RECINPUT")
    local is_stereo_input = false
    local channel_index = 0
    
    if recInput < 0 then
        -- None
        channel_index = 0
        is_stereo_input = false
    elseif recInput >= 1024 then
        -- Stereo pair
        local ch = recInput - 1024
        channel_index = ch + 1  -- +1 because index 0 is now "None"
        is_stereo_input = true
    else
        -- Mono
        channel_index = recInput + 1  -- +1 because index 0 is "None"
        is_stereo_input = false
    end
    
    return channel_index, is_stereo_input
end

function ApplyInputSelection(d_track, is_stereo_input, channel_index)
    local recInput
    
    if not is_stereo_input then
        -- Mono
        if channel_index == 0 then
            recInput = -1  -- None
        else
            recInput = channel_index - 1  -- -1 because index 0 is "None"
        end
    else
        -- Stereo
        if channel_index == 0 then
            recInput = -1  -- None
        else
            recInput = 1024 + (channel_index - 1)  -- -1 because index 0 is "None"
        end
    end
    
    SetMediaTrackInfo_Value(d_track, "I_RECINPUT", recInput)
end

function RenameTracksForMixer(track_info, new_name)
    -- Rename mixer track with M: prefix
    GetSetMediaTrackInfo_String(track_info.mixer_track, "P_NAME", "M:" .. new_name, true)
    
    -- Get the mixer track's position in the list (1-based)
    local mixer_position = nil
    for idx, info in ipairs(mixer_tracks) do
        if info.mixer_track == track_info.mixer_track then
            mixer_position = idx
            break
        end
    end
    
    if not mixer_position then return end
    
    -- Find all folder tracks in the project
    local folder_number = 0
    for i = 0, CountTracks(0) - 1 do
        local track = GetTrack(0, i)
        local folder_depth = GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
        
        -- If this is a folder track (depth == 1)
        if folder_depth == 1 then
            folder_number = folder_number + 1
            
            -- The folder track itself is the first track (mixer_position 1)
            -- So for mixer_position 1, we want track at index i
            -- For mixer_position 2, we want track at index i+1, etc.
            local track_index = i + (mixer_position - 1)
            local target_track = GetTrack(0, track_index)
            
            if target_track then
                -- Determine prefix based on folder number (not mixer position!)
                local prefix
                if folder_number == 1 then
                    prefix = "D:"
                else
                    prefix = "S" .. (folder_number - 1) .. ":"
                end
                
                -- Rename the track
                GetSetMediaTrackInfo_String(target_track, "P_NAME", prefix .. new_name, true)
            end
        end
    end
end

function FormatPanString(panVal)
    if math.abs(panVal) < 0.01 then
        return "C"
    elseif panVal < 0 then
        return tostring(math.floor(-panVal * 100 + 0.5)) .. "L"
    else
        return tostring(math.floor(panVal * 100 + 0.5)) .. "R"
    end
end

function SyncBasedOnWorkflow()
    if workflow == "Vertical" then
        local F8_sync = NamedCommandLookup("_RSbc3e25053ffd4a2dff87f6c3e49c0dadf679a549")
        Main_OnCommand(F8_sync, 0)
    elseif workflow == "Horizontal" then
        local F7_sync = NamedCommandLookup("_RS59740cdbf71a5206a68ae5222bd51834ec53f6e6")
        Main_OnCommand(F7_sync, 0)
    end
end

function ReorderMixerTrack(from_idx, to_idx)
    if from_idx == to_idx then return end
    
    -- Get the mixer track to move
    local from_track = mixer_tracks[from_idx].mixer_track
    
    -- Get the target position (which mixer track it should be before)
    local before_track
    if to_idx < from_idx then
        -- Moving up - place before the to_idx track
        before_track = mixer_tracks[to_idx].mixer_track
    else
        -- Moving down - place before the track after to_idx (or at end if last)
        if to_idx < #mixer_tracks then
            before_track = mixer_tracks[to_idx + 1].mixer_track
        else
            -- Moving to end - use the track count
            before_track = nil
        end
    end
    
    -- Select only the from_track
    Main_OnCommand(40297, 0)  -- Unselect all tracks
    SetTrackSelected(from_track, true)
    
    -- Get the track index to move before (0-based)
    local before_track_idx
    if before_track then
        before_track_idx = GetMediaTrackInfo_Value(before_track, "IP_TRACKNUMBER") - 1
    else
        -- Move to end
        before_track_idx = CountTracks(0)
    end
    
    -- Reorder the track
    ReorderSelectedTracks(before_track_idx, 0)
    
    -- Sync based on workflow
    SyncBasedOnWorkflow()
    
    -- Completely reinitialize
    InitializeState()
end

function DeleteMixerTrack(track_info)
    -- Unselect all tracks
    Main_OnCommand(40297, 0)  -- Track: Unselect all tracks
    
    -- Select only this mixer track
    SetTrackSelected(track_info.mixer_track, true)
    
    -- Run the delete mixer command
    local delete_mixer = NamedCommandLookup("_RS3e0eac1c51cbab48f6c385d7f39529ad5f16f961")
    Main_OnCommand(delete_mixer, 0)
    
    -- Completely reinitialize
    selected_track = nil
    InitializeState()
end

function AddMixerTrack()
    -- Run the add mixer command
    local add_mixer = NamedCommandLookup("_RS6b2e20ac7202f36f624ce019fce5d87f9f28489b")
    Main_OnCommand(add_mixer, 0)
    
    -- Completely reinitialize from scratch
    selected_track = nil
    InitializeState()
end

function InitializeState()
    GenerateInputOptions()
    
    -- Get D: tracks from first folder
    d_tracks = GetDTracksFromFirstFolder()
    
    -- Get mixer tracks
    mixer_tracks = CreateMixerTable()
    
    if #mixer_tracks == 0 then
        MB("No mixer tracks found.", "Error", 0)
        return false
    end
    
    if #d_tracks < #mixer_tracks then
        MB("Not enough D: tracks in first folder for all mixers.", "Error", 0)
        return false
    end
    
    -- Calculate zero padding for track numbers
    local num_digits = #tostring(#mixer_tracks)
    track_num_format = "%0" .. num_digits .. "d"
    
    -- Clear all state
    input_channels = {}
    input_channels_mono = {}
    input_channels_stereo = {}
    mono_has_been_set = {}
    stereo_has_been_set = {}
    is_stereo = {}
    pan_values = {}
    track_names = {}
    
    -- Initialize by reading from D: tracks (first folder)
    for i = 1, #mixer_tracks do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i]  -- Corresponding D: track
        
        local ch, stereo = GetCurrentInputInfo(d_track)
        input_channels[i] = ch
        is_stereo[i] = stereo
        
        -- Initialize both mono and stereo memory
        if stereo then
            input_channels_stereo[i] = ch
            input_channels_mono[i] = 0  -- Default mono to "None"
            stereo_has_been_set[i] = true  -- Current value was set
            mono_has_been_set[i] = false
        else
            input_channels_mono[i] = ch
            input_channels_stereo[i] = 0  -- Default stereo to first pair
            mono_has_been_set[i] = true  -- Current value was set
            stereo_has_been_set[i] = false
        end
        
        pan_values[i] = GetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN")
        
        -- Get mixer track name without M: prefix
        local _, mixer_name = GetTrackName(track_info.mixer_track)
        track_names[i] = mixer_name:gsub("^M:?", "")
    end
    
    return true
end

---------------------------------------------------------------------

function Loop()
    if not ImGui.ValidatePtr(ctx, 'ImGui_Context*') then
        return
    end
    
    ImGui.SetNextWindowSize(ctx, 600, 0, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, 'Track and Record Input Management', true, ImGui.WindowFlags_AlwaysAutoResize)
    
    if visible then
        local num_tabs = math.ceil(#mixer_tracks / TRACKS_PER_TAB)
        
        if num_tabs > 1 then
            if ImGui.BeginTabBar(ctx, "##tabs") then
                for tab = 0, num_tabs - 1 do
                    local start_idx = tab * TRACKS_PER_TAB + 1
                    local end_idx = math.min(start_idx + TRACKS_PER_TAB - 1, #mixer_tracks)
                    local tab_label = string.format("Tracks %d-%d", start_idx, end_idx)
                    
                    if ImGui.BeginTabItem(ctx, tab_label) then
                        current_tab = tab
                        DrawTrackControls(start_idx, end_idx)
                        ImGui.EndTabItem(ctx)
                    end
                end
                ImGui.EndTabBar(ctx)
            end
        else
            DrawTrackControls(1, #mixer_tracks)
        end
        
        -- Add button at the bottom
        ImGui.Separator(ctx)
        
        -- Up arrow button
        if ImGui.Button(ctx, "↑") and selected_track and selected_track > 1 then
            ReorderMixerTrack(selected_track, selected_track - 1)
            selected_track = selected_track - 1
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Move selected track up")
        end
        
        -- Down arrow button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "↓") and selected_track and selected_track < #mixer_tracks then
            ReorderMixerTrack(selected_track, selected_track + 1)
            selected_track = selected_track + 1
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Move selected track down")
        end
        
        -- Add mixer track button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "+") then
            AddMixerTrack()
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Add track to all folders")
        end
        
        -- Invisible button to fill remaining space and clear selection
        ImGui.SameLine(ctx)
        local remaining_width = ImGui.GetContentRegionAvail(ctx)
        ImGui.InvisibleButton(ctx, "##clearselect", remaining_width, ImGui.GetTextLineHeight(ctx))
        if ImGui.IsItemClicked(ctx) then
            selected_track = nil
        end
        
        ImGui.End(ctx)
    end
    
    -- Run sync after ImGui frame is complete if flag is set
    if sync_needed then
        sync_needed = false
        SyncBasedOnWorkflow()
    end
    
    if open then
        defer(Loop)
    end
end

function DrawTrackControls(start_idx, end_idx)
    for i = start_idx, end_idx do
        local track_info = mixer_tracks[i]
        local d_track = d_tracks[i]
        
        ImGui.PushID(ctx, i)
        
        -- Draw background highlight if selected (pastel blue)
        local is_selected = (selected_track == i)
        if is_selected then
            local draw_list = ImGui.GetWindowDrawList(ctx)
            local cursor_screen_x, cursor_screen_y = ImGui.GetCursorScreenPos(ctx)
            local window_width = ImGui.GetWindowWidth(ctx)
            local item_height = ImGui.GetTextLineHeightWithSpacing(ctx)
            ImGui.DrawList_AddRectFilled(draw_list, cursor_screen_x, cursor_screen_y, 
                cursor_screen_x + window_width, cursor_screen_y + item_height, 
                0xADD8E688)  -- Pastel blue (RGBA)
        end
        
        -- Track number  
        ImGui.Text(ctx, string.format(track_num_format, i))
        
        -- Check if this row should be selected (clicking on track number)
        if ImGui.IsItemClicked(ctx) then
            selected_track = i
        end
        
        -- Track name input
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 120)
        local changed_name, new_name = ImGui.InputText(ctx, "##name", track_names[i])
        if changed_name then
            track_names[i] = new_name
            RenameTracksForMixer(track_info, new_name)
        end
        
        -- Mono/Stereo radio buttons
        ImGui.SameLine(ctx)
        local changed_to_mono = ImGui.RadioButton(ctx, "M##mono", not is_stereo[i])
        ImGui.SameLine(ctx)
        local changed_to_stereo = ImGui.RadioButton(ctx, "S##stereo", is_stereo[i])
        
        if changed_to_mono and is_stereo[i] then
            -- Save current stereo value and switch to mono
            input_channels_stereo[i] = input_channels[i]
            stereo_has_been_set[i] = true
            is_stereo[i] = false
            
            -- On first switch, use channel 1 if available, otherwise None
            if not mono_has_been_set[i] then
                if MAX_INPUTS >= 1 then
                    input_channels[i] = 1  -- Channel 1 (index 1 in mono_options)
                else
                    input_channels[i] = 0  -- None
                end
                input_channels_mono[i] = input_channels[i]
                mono_has_been_set[i] = true
            else
                input_channels[i] = input_channels_mono[i]
            end
            
            ApplyInputSelection(d_track, is_stereo[i], input_channels[i])
            
            -- Set flag if vertical workflow
            if workflow == "Vertical" then
                sync_needed = true
            end
        elseif changed_to_stereo and not is_stereo[i] then
            -- Save current mono value and switch to stereo
            input_channels_mono[i] = input_channels[i]
            mono_has_been_set[i] = true
            is_stereo[i] = true
            
            -- On first switch, use 1+2 if available, otherwise None
            if not stereo_has_been_set[i] then
                if MAX_INPUTS >= 2 then
                    input_channels[i] = 1  -- 1+2 (index 1 in stereo_options)
                else
                    input_channels[i] = 0  -- None
                end
                input_channels_stereo[i] = input_channels[i]
                stereo_has_been_set[i] = true
            else
                input_channels[i] = input_channels_stereo[i]
            end
            
            ApplyInputSelection(d_track, is_stereo[i], input_channels[i])
            
            -- Set flag if vertical workflow
            if workflow == "Vertical" then
                sync_needed = true
            end
        end
        
        -- Input dropdown
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 80)
        local options = is_stereo[i] and stereo_options or mono_options
        local options_str = table.concat(options, "\0") .. "\0"
        local changed_input, new_input = ImGui.Combo(ctx, "##input", input_channels[i], options_str)
        if changed_input then
            input_channels[i] = new_input
            
            -- Save to appropriate memory and mark as set
            if is_stereo[i] then
                input_channels_stereo[i] = new_input
                stereo_has_been_set[i] = true
            else
                input_channels_mono[i] = new_input
                mono_has_been_set[i] = true
            end
            
            ApplyInputSelection(d_track, is_stereo[i], input_channels[i])
            
            -- Set flag if vertical workflow
            if workflow == "Vertical" then
                sync_needed = true
            end
        end
        
        -- Pan slider
        ImGui.SameLine(ctx)
        ImGui.SetNextItemWidth(ctx, 150)
        local changed_pan, new_pan = ImGui.SliderDouble(ctx, "##pan" .. i, pan_values[i], -1.0, 1.0, FormatPanString(pan_values[i]))
        
        -- Check for double-click reset to center
        new_pan = ResetPanOnDoubleClick("##pan" .. i, new_pan, 0.0)
        
        if changed_pan or new_pan ~= pan_values[i] then
            pan_values[i] = new_pan
            SetMediaTrackInfo_Value(track_info.mixer_track, "D_PAN", new_pan)
        end
        
        -- Delete button
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "✕##delete" .. i) then
            DeleteMixerTrack(track_info)
            -- Break out of the loop since we've modified the tracks array
            ImGui.PopID(ctx)
            return
        end
        if ImGui.IsItemHovered(ctx) then
            ImGui.SetTooltip(ctx, "Delete this track from all folders")
        end
        
        -- Invisible button to fill the rest of the row and make it clickable
        ImGui.SameLine(ctx)
        local remaining_width = ImGui.GetContentRegionAvail(ctx)
        ImGui.InvisibleButton(ctx, "##rowclick", remaining_width, ImGui.GetTextLineHeight(ctx))
        if ImGui.IsItemClicked(ctx) then
            selected_track = i
        end
        
        ImGui.PopID(ctx)
    end
end

---------------------------------------------------------------------

if InitializeState() then
    defer(Loop)
end