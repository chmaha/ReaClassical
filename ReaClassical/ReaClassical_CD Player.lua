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
package.path = package.path .. ";" .. script_path .. "?.lua;" .. script_path .. "lib/?.lua;"
local say  = require("ReaClassical_Announce")
local cd   = require("ReaClassical_CD_Player_Data")
local ctrl = require("ReaClassical_CD_Player_Controls")
local solo_first_folder = require("ReaClassical_Folder_Solo").solo_first_folder
local help = require("ReaClassical_Accessible_Help")
local ui_input = require("ReaClassical_Accessible_Input")

if APIExists("clara_outputMessage") then
    set_action_options(3)
else
    set_action_options(2)
end

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

local layout, album_end = cd.get_cd_layout()
if not layout then
    MB("No CD markers found. Run \"Create CD Markers\" (Y) first.", "CD Player", 0)
    return
end

solo_first_folder()

cd.remove_stale_end_pad()
local last_item_end = cd.get_last_item_end()
local end_pad_item = cd.ensure_end_pad(album_end)

local album_meta, track_meta = cd.load_metadata()
local album_title = (album_meta and album_meta.title ~= "" and album_meta.title) or "Untitled Album"

local function track_title(idx)
    local m = track_meta and track_meta[idx]
    if m and m.title and m.title ~= "" then return m.title end
    return "Track " .. idx
end

local function composer_for(idx)
    local m = track_meta and track_meta[idx]
    return (m and m.composer) or ""
end

local function performer_for(idx)
    local m = track_meta and track_meta[idx]
    return (m and m.performer) or ""
end

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_LEFT  = 1818584692
local KEY_RIGHT = 1919379572
local KEY_ESC   = 27
local KEY_ENTER = 13

local entry_cursor_pos = GetCursorPosition()

SetEditCurPos(0, false, false)

local ready = false
local time_mode = "track_elapsed"
local repeat_mode = "off"

local reviewing_boundaries = false
local review_boundaries = {}
local review_idx = 1
local review_pre_roll = 10
local review_post_roll = 3

local nav_since_stop = false

local WINDOW_W, WINDOW_H = 600, 202
gfx.init("CD Player", WINDOW_W, WINDOW_H, 0)

say("Reading disc...")

local intro_start = time_precise()
local last_track_idx = nil
local last_char = 0
local mouse_was_down = false
local mouse_was_right_down = false

local FLASH_SECONDS = 1.0
local flash_text = nil
local flash_until = 0

local function flash(text)
    flash_text = text
    flash_until = time_precise() + FLASH_SECONDS
end

local SCROLL_SPEED = 40
local SCROLL_GAP   = 40
local scroll_key   = nil
local scroll_start = 0

local function draw_line(str, x, y, max_w)
    local str_w = gfx.measurestr(str)
    if str_w <= max_w then
        gfx.x, gfx.y = x, y
        gfx.drawstr(str)
        return
    end
    if str ~= scroll_key then
        scroll_key = str
        scroll_start = time_precise()
    end
    local period = str_w + SCROLL_GAP
    local offset = ((time_precise() - scroll_start) * SCROLL_SPEED) % period
    gfx.x, gfx.y = x - offset, y
    gfx.drawstr(str)
    gfx.x, gfx.y = x - offset + period, y
    gfx.drawstr(str)
end

local BTN_ROW_Y  = 128
local BTN_ROW2_Y = 164
local BTN_H     = 32
local BTN_GAP   = 4
local BTN_MARGIN = 6

local BTN_CLUSTER_GAP = 16
local CLUSTER1_SHARE = 0.75
local GROUP_TINT = {
    [1] = { 0.16, 0.16, 0.16 },
    [2] = { 0.10, 0.10, 0.18 },
    [3] = { 0.20, 0.10, 0.10 },
}

local BUTTONS
local NUM_BUTTONS

local function draw_button_row(buttons, row_y)
    local clusters = { [1] = {}, [2] = {} }
    for _, btn in ipairs(buttons) do
        table.insert(clusters[btn.cluster or 1], btn)
    end

    local raw_usable = gfx.w - 2 * BTN_MARGIN - BTN_CLUSTER_GAP
    local cluster_w = { [1] = raw_usable * CLUSTER1_SHARE, [2] = raw_usable * (1 - CLUSTER1_SHARE) }

    gfx.setfont(1, "Arial", 13)
    local x = BTN_MARGIN
    for c = 1, 2 do
        local btns = clusters[c]
        local total_weight = 0
        for _, btn in ipairs(btns) do total_weight = total_weight + (btn.weight or 1) end
        local unit_w = (cluster_w[c] - (#btns - 1) * BTN_GAP) / total_weight

        for i, btn in ipairs(btns) do
            if i > 1 then x = x + BTN_GAP end
            local btn_w = unit_w * (btn.weight or 1)
            btn.x, btn.y, btn.w, btn.h = x, row_y, btn_w, BTN_H
            local tint = GROUP_TINT[btn.group] or GROUP_TINT[1]
            gfx.set(tint[1], tint[2], tint[3], 1)
            gfx.rect(x, row_y, btn_w, BTN_H, true)
            gfx.set(0.4, 0.4, 0.4, 1)
            gfx.rect(x, row_y, btn_w, BTN_H, false)
            gfx.set(0.85, 0.85, 0.85, 1)
            local tw, th = gfx.measurestr(btn.label)
            gfx.x, gfx.y = x + (btn_w - tw) / 2, row_y + (BTN_H - th) / 2
            gfx.drawstr(btn.label)
            x = x + btn_w
        end
        if c == 1 then x = x + BTN_CLUSTER_GAP end
    end
end

local function draw_buttons()
    draw_button_row(BUTTONS, BTN_ROW_Y)
    draw_button_row(NUM_BUTTONS, BTN_ROW2_Y)
end

local FLASH_Y = BTN_ROW_Y - 20

local function draw_flash()
    if not flash_text or time_precise() >= flash_until then return end
    gfx.set(0.596, 0.792, 0.882, 1)
    gfx.setfont(1, "Arial", 14)
    local tw = gfx.measurestr(flash_text)
    gfx.x, gfx.y = (gfx.w - tw) / 2, FLASH_Y
    gfx.drawstr(flash_text)
end

local function handle_mouse()
    local down = (gfx.mouse_cap & 1) == 1
    local right_down = (gfx.mouse_cap & 2) == 2
    local clicked = down and not mouse_was_down
    local right_clicked = right_down and not mouse_was_right_down
    mouse_was_down = down
    mouse_was_right_down = right_down

    if clicked or right_clicked then
        for _, row in ipairs({ BUTTONS, NUM_BUTTONS }) do
            for _, btn in ipairs(row) do
                if gfx.mouse_x >= btn.x and gfx.mouse_x <= btn.x + btn.w
                    and gfx.mouse_y >= btn.y and gfx.mouse_y <= btn.y + btn.h then
                    if right_clicked then
                        if btn.on_right_click then btn.on_right_click() end
                        return true
                    end
                    btn.action()
                    if btn.quit then return false end
                    return true
                end
            end
        end
    end
    return true
end

local function draw_bg()
    gfx.set(0.07, 0.07, 0.07, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.2, 0.95, 0.4, 1)
end

local function draw_intro()
    draw_bg()
    gfx.setfont(1, "Arial", 22)
    gfx.x, gfx.y = 10, 15
    gfx.drawstr("Reading... " .. string.format("%02d", math.random(0, 99)))
    gfx.setfont(1, "Arial", 14)
    gfx.x, gfx.y = 10, 55
    gfx.update()
end

local function draw_summary()
    draw_bg()
    local max_w = gfx.w - 20
    gfx.setfont(1, "Arial", 16)
    draw_line(album_title, 10, 8, max_w)
    gfx.setfont(1, "Arial", 13)
    draw_line("Composer: " .. ((album_meta and album_meta.composer) or ""), 10, 30, max_w)
    draw_line("Performer: " .. ((album_meta and album_meta.performer) or ""), 10, 48, max_w)
    gfx.setfont(1, "Arial", 20)
    gfx.x, gfx.y = 10, 70
    gfx.drawstr(cd.format_time(album_end, false))
    gfx.setfont(1, "Arial", 13)
    gfx.x, gfx.y = 10, 96
    gfx.drawstr("Total Time, " .. #layout .. " track" .. (#layout == 1 and "" or "s"))
    draw_flash()
    draw_buttons()
    gfx.update()
end

local function draw_ready(idx, in_pregap, pregap_remaining, time_str, time_label, transport_str, rep_mode, review_info)
    draw_bg()
    local max_w = gfx.w - 20
    gfx.setfont(1, "Arial", 16)
    if in_pregap then
        draw_line(string.format("Pregap -> Track %d", idx), 10, 8, max_w)
    else
        draw_line(string.format("Track %d: %s", idx, track_title(idx)), 10, 8, max_w)
    end
    gfx.setfont(1, "Arial", 13)
    draw_line("Composer: " .. composer_for(idx), 10, 30, max_w)
    draw_line("Performer: " .. performer_for(idx), 10, 48, max_w)
    gfx.setfont(1, "Arial", 20)
    gfx.x, gfx.y = 10, 70
    if in_pregap then
        gfx.drawstr(cd.format_time(pregap_remaining, true))
    else
        gfx.drawstr(time_str)
    end
    gfx.setfont(1, "Arial", 13)
    gfx.x, gfx.y = 10, 96
    local repeat_str = rep_mode ~= "off" and (" | Repeat: " .. rep_mode) or ""
    local review_str = review_info and string.format(" | Reviewing %d/%d", review_info.idx, review_info.total) or ""
    gfx.drawstr((in_pregap and "Pregap" or time_label) .. " | " .. transport_str .. repeat_str .. review_str)
    draw_flash()
    draw_buttons()
    gfx.update()
end

local function announce_ready()
    say(string.format("Ready: %s. %d track%s, total time %s", album_title, #layout,
        #layout == 1 and "" or "s", cd.format_time(album_end, false)))
end

local function announce_track(idx)
    say(string.format("Track %d: %s", idx, track_title(idx)))
end

local function do_jump_to_track(n)
    nav_since_stop = true
    local idx = ctrl.jump_to_track(layout, n)
    if idx then
        last_track_idx = idx
        announce_track(idx)
    else
        say("No track " .. n)
        flash("Track not found")
    end
end

local function do_play_pause()
    if cd.is_stopped() then
        ctrl.play_from_here()
    elseif ctrl.pause() then
        say("Paused")
    else
        say("Resumed")
    end
end

local function do_stop()
    last_track_idx = ctrl.stop()
    nav_since_stop = false
end

local function do_next()
    local first_reveal = cd.is_stopped() and not nav_since_stop
    nav_since_stop = true
    local idx
    if first_reveal then
        idx = ctrl.jump_to_track(layout, 1)
    else
        idx = ctrl.next_track(layout)
    end
    if idx then
        last_track_idx = idx
        announce_track(idx)
    else
        say("Last track")
    end
end

local function do_previous()
    nav_since_stop = true
    last_track_idx = ctrl.previous_track(layout)
    announce_track(last_track_idx)
end

local function do_fast_forward()
    nav_since_stop = true
    ctrl.fast_forward(album_end)
end

local function do_rewind()
    nav_since_stop = true
    ctrl.rewind()
end

local function do_cycle_time()
    time_mode = ctrl.cycle_time_mode(time_mode)
    say(ctrl.TIME_LABELS[time_mode])
    if not cd.is_playing() then flash(ctrl.TIME_LABELS[time_mode]) end
end

local function do_cycle_repeat()
    repeat_mode = ctrl.cycle_repeat_mode(repeat_mode)
    say(ctrl.REPEAT_LABELS[repeat_mode])
    if not cd.is_playing() then flash(ctrl.REPEAT_LABELS[repeat_mode]) end
end

local function do_toggle_review()
    if reviewing_boundaries then
        reviewing_boundaries = false
        say("Review off")
        return
    end

    local boundaries = cd.get_boundaries(layout, last_item_end)
    local _, pre_str = GetProjExtState(0, "ReaClassical", "CDBoundaryPreRoll")
    local _, post_str = GetProjExtState(0, "ReaClassical", "CDBoundaryPostRoll")
    review_pre_roll = tonumber(pre_str) or 10
    review_post_roll = tonumber(post_str) or 3
    review_boundaries = boundaries

    local idx = ctrl.start_review(boundaries, review_pre_roll, review_post_roll)
    if not idx then
        say("Nothing left to review")
        return
    end

    review_idx = idx
    reviewing_boundaries = true
    nav_since_stop = true
    last_track_idx = cd.track_index_at(layout, cd.current_pos())
    say(string.format("Reviewing transitions. Transition %d of %d", review_idx, #review_boundaries))
end

local function ask_roll_seconds(stage_label, current)
    while true do
        local ok, entered = ui_input.ask("CD Player", stage_label,
            stage_label .. " seconds (0-99)", current)
        if not ok then return nil end
        local n = tonumber(entered)
        if n and n >= 0 and n <= 99 and n == math.floor(n) then return n end
        say("Please enter a whole number from 0 to 99")
    end
end

local function do_edit_review_settings()
    reviewing_boundaries = false
    local _, pre = GetProjExtState(0, "ReaClassical", "CDBoundaryPreRoll")
    local _, post = GetProjExtState(0, "ReaClassical", "CDBoundaryPostRoll")
    local pre_n = ask_roll_seconds("Pre-Roll", pre ~= "" and pre or "3")
    if pre_n == nil then say("Cancelled") return end
    SetProjExtState(0, "ReaClassical", "CDBoundaryPreRoll", tostring(pre_n))
    say("Pre-roll: " .. pre_n .. " seconds")
    local post_n = ask_roll_seconds("Post-Roll", post ~= "" and post or "3")
    if post_n == nil then say("Cancelled") return end
    SetProjExtState(0, "ReaClassical", "CDBoundaryPostRoll", tostring(post_n))
    say("Post-roll: " .. post_n .. " seconds set")
end

local function do_enter_track_number()
    local ok, entered = ui_input.ask("CD Player", "Track Number",
        "Track number", "")
    if not ok then
        say("Cancelled")
        return
    end
    local n = tonumber(entered)
    if n then
        do_jump_to_track(n)
    else
        say("Please enter a track number")
    end
end

local function do_power_off() end

BUTTONS = {
    { label = "|<  Prev", action = do_previous, group = 1, cluster = 1 },
    { label = "<<  Rew",  action = do_rewind, group = 1, cluster = 1 },
    { label = "Play/Pause", action = do_play_pause, group = 1, cluster = 1 },
    { label = "Stop", action = do_stop, group = 1, cluster = 1 },
    { label = "Fwd  >>", action = do_fast_forward, group = 1, cluster = 1 },
    { label = "Next  >|", action = do_next, group = 1, cluster = 1 },
    { label = "Time", action = do_cycle_time, group = 2, cluster = 2, weight = 0.6 },
    { label = "Repeat", action = do_cycle_repeat, group = 2, cluster = 2 },
    { label = "Review", action = do_toggle_review, on_right_click = do_edit_review_settings,
        group = 2, cluster = 2 },
}

NUM_BUTTONS = {
    { label = "1", action = function() do_jump_to_track(1) end, group = 1, cluster = 1 },
    { label = "2", action = function() do_jump_to_track(2) end, group = 1, cluster = 1 },
    { label = "3", action = function() do_jump_to_track(3) end, group = 1, cluster = 1 },
    { label = "4", action = function() do_jump_to_track(4) end, group = 1, cluster = 1 },
    { label = "5", action = function() do_jump_to_track(5) end, group = 1, cluster = 1 },
    { label = "6", action = function() do_jump_to_track(6) end, group = 1, cluster = 1 },
    { label = "7", action = function() do_jump_to_track(7) end, group = 1, cluster = 1 },
    { label = "8", action = function() do_jump_to_track(8) end, group = 1, cluster = 1 },
    { label = "9", action = function() do_jump_to_track(9) end, group = 1, cluster = 1 },
    { label = "Track...", action = do_enter_track_number, group = 2, cluster = 2, weight = 1.6 },
    { label = "Power Off", action = do_power_off, group = 3, cluster = 2, quit = true, weight = 2 },
}

local CD_PLAYER_SHORTCUTS = {
    { key = "S", desc = "Stop" },
    { key = "P", desc = "Play, pause, or resume" },
    { key = "D", desc = "Enter a track number" },
    { key = "Right arrow", desc = "Next track" },
    { key = "Left arrow", desc = "Previous track" },
    { key = "Up arrow", desc = "Fast forward" },
    { key = "Down arrow", desc = "Rewind" },
    { key = "T", desc = "Cycle time display mode" },
    { key = "R", desc = "Cycle repeat mode" },
    { key = "B", desc = "Toggle Transition Review" },
    { key = "W", desc = "Set Transition Review's pre and post-roll" },
    { key = "1 through 9", desc = "Jump directly to that track" },
    { key = "Escape", desc = "Power off" },
}

local function handle_key(char)
    if char == 72 or char == 104 then
        help.enter(CD_PLAYER_SHORTCUTS, "Back to CD Player.")
        return true
    end

    if reviewing_boundaries and char ~= 66 and char ~= 98 then
        reviewing_boundaries = false
    end

    if char == KEY_ESC then
        return false
    elseif char == 83 or char == 115 then
        do_stop()
    elseif char == 80 or char == 112 then
        do_play_pause()
    elseif char == 68 or char == 100 then
        do_enter_track_number()
    elseif char == KEY_RIGHT then
        do_next()
    elseif char == KEY_LEFT then
        do_previous()
    elseif char == KEY_UP then
        do_fast_forward()
    elseif char == KEY_DOWN then
        do_rewind()
    elseif char == 84 or char == 116 then
        do_cycle_time()
    elseif char == 82 or char == 114 then
        do_cycle_repeat()
    elseif char == 66 or char == 98 then
        do_toggle_review()
    elseif char == 87 or char == 119 then
        do_edit_review_settings()
    elseif char >= 49 and char <= 57 then
        do_jump_to_track(char - 48)
    end
    return true
end

local function at_exit()
    Main_OnCommand(1016, 0)
    SetEditCurPos(entry_cursor_pos, false, false)
    cd.remove_end_pad(end_pad_item)
    gfx.quit()
    say("CD Player off")
end

local function main()
    local char = gfx.getchar()
    if char == -1 then return end

    if not ready then
        if time_precise() - intro_start > 1.3 then
            ready = true
            last_track_idx = 1
            announce_ready()
        else
            draw_intro()
            defer(main)
            return
        end
    end

    if char ~= 0 and char ~= last_char then
        last_char = char
        local consumed = help.is_active() and help.handle_key(char)
        if not consumed then
            if not handle_key(char) then return end
        end
    elseif char == 0 then
        last_char = 0
    end

    if not handle_mouse() then return end

    if cd.is_stopped() and not nav_since_stop then
        last_track_idx = cd.track_index_at(layout, cd.current_pos())
        draw_summary()
        defer(main)
        return
    end

    local pos = cd.current_pos()
    local idx = cd.track_index_at(layout, pos)
    local t = layout[idx]
    local in_pregap = t.pregap_start ~= nil and pos < t.start_pos
    local pregap_remaining = in_pregap and (t.start_pos - pos) or nil

    if cd.is_playing() and idx ~= last_track_idx then
        last_track_idx = idx
        announce_track(idx)
    end

    if cd.is_playing() then
        if reviewing_boundaries then
            local next_idx = ctrl.advance_review(review_boundaries, review_idx, review_pre_roll, review_post_roll)
            if not next_idx then
                reviewing_boundaries = false
                last_track_idx = ctrl.stop()
                nav_since_stop = false
                say("Review complete")
                defer(main)
                return
            elseif next_idx ~= review_idx then
                review_idx = next_idx
                say(string.format("Transition %d of %d", review_idx, #review_boundaries))
            end
        elseif repeat_mode == "track" and pos >= t.end_pos - 0.05 then
            cd.seek(t.start_pos)
        elseif repeat_mode == "album" and pos >= album_end - 0.05 then
            cd.seek(layout[1].pregap_start or layout[1].start_pos)
        elseif repeat_mode == "off" and pos >= album_end - 0.05 then
            last_track_idx = ctrl.stop()
            nav_since_stop = false
            defer(main)
            return
        end
    end

    local time_str
    if time_mode == "track_elapsed" then
        time_str = cd.format_time(pos - t.start_pos, false)
    elseif time_mode == "track_remaining" then
        time_str = cd.format_time(t.end_pos - pos, true)
    elseif time_mode == "album_elapsed" then
        time_str = cd.format_time(pos, false)
    else
        time_str = cd.format_time(album_end - pos, true)
    end

    local transport_str
    if cd.is_playing() then
        transport_str = "Playing"
    elseif cd.is_paused() then
        transport_str = "Paused"
    else
        transport_str = "Stopped"
    end
    local review_info = reviewing_boundaries and { idx = review_idx, total = #review_boundaries } or nil
    draw_ready(idx, in_pregap, pregap_remaining, time_str, ctrl.TIME_LABELS[time_mode], transport_str, repeat_mode,
        review_info)

    defer(main)
end

atexit(at_exit)
defer(main)
