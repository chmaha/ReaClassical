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
local render_settings = require("ReaClassical_Render_Settings")
local af = require("ReaClassical_Accessible_Focus")

set_action_options(3)

local WINDOW_TITLE = "Distribute Takes"

local STATE_NAV    = "nav"
local STATE_RENDER = "render"
local STATE_EXPORT = "export"

local KEY_UP    = 30064
local KEY_DOWN  = 1685026670
local KEY_ENTER = 13
local KEY_ESC   = 27

local RENDER_FIELDS = {
    { key = "samplerate", label = "Sample rate", list = render_settings.samplerate_list,
      labels = render_settings.samplerate_labels },
    { key = "bitdepth", label = "Bit depth", list = render_settings.bitdepth_list,
      labels = render_settings.bitdepth_labels },
    { key = "dither", label = "Dither", list = render_settings.dither_list,
      labels = render_settings.dither_list },
}

local EXPORT_FORMATS = {
    { key = "wav",  label = "WAV" },
    { key = "flac", label = "FLAC" },
    { key = "opus", label = "Opus 160" },
    { key = "mp3",  label = "MP3 320" },
}

local state   = STATE_NAV
local nav_idx = 1

local render_field_idx   = 1
local render_pending_idx = 1
local cur_samplerate, cur_bitdepth, cur_dither = render_settings.load()

local export_idx = 1

local function nav_label(i)
    if i == 1 then return "Render Settings" end
    return "Export"
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

local function try_refocus()
    return af.refocus_existing(WINDOW_TITLE)
end

local function do_export(fmt)
    _G.RC_SCRIPT_ARGS = { action = "distribute", format = fmt }
    dofile(parent_path .. "ReaClassical_Distribute Takes.lua")
    _G.RC_SCRIPT_ARGS = nil
end

local function draw_window()
    gfx.set(0.12, 0.12, 0.12, 1)
    gfx.rect(0, 0, gfx.w, gfx.h, true)
    gfx.set(0.9, 0.9, 0.9, 1)
    gfx.setfont(1, "Arial", 15)
    gfx.x, gfx.y = 8, 13
    if state == STATE_NAV then
        gfx.drawstr("[Nav]  " .. nav_label(nav_idx))
    elseif state == STATE_RENDER then
        local f = RENDER_FIELDS[render_field_idx]
        gfx.drawstr("[Render Settings]  " .. f.label .. ": " .. f.labels[render_pending_idx])
    elseif state == STATE_EXPORT then
        gfx.drawstr("[Export]  Format: " .. EXPORT_FORMATS[export_idx].label)
    end
    gfx.update()
end

local function handle_key(char)
    if state == STATE_NAV then
        if char == KEY_UP then
            nav_idx = nav_idx > 1 and nav_idx - 1 or 2
            say(nav_label(nav_idx))
        elseif char == KEY_DOWN then
            nav_idx = nav_idx < 2 and nav_idx + 1 or 1
            say(nav_label(nav_idx))
        elseif char == KEY_ENTER then
            if nav_idx == 1 then
                render_field_idx   = 1
                render_pending_idx = render_current_index(1)
                state = STATE_RENDER
                announce_render_field(true)
            else
                export_idx = 1
                state = STATE_EXPORT
                say("Format: " .. EXPORT_FORMATS[1].label .. ". Up/down to change")
            end
        elseif char == KEY_ESC then
            say("Closing.")
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
    elseif state == STATE_EXPORT then
        if char == KEY_UP then
            export_idx = export_idx > 1 and export_idx - 1 or #EXPORT_FORMATS
            say(EXPORT_FORMATS[export_idx].label)
        elseif char == KEY_DOWN then
            export_idx = export_idx < #EXPORT_FORMATS and export_idx + 1 or 1
            say(EXPORT_FORMATS[export_idx].label)
        elseif char == KEY_ENTER then
            local chosen = EXPORT_FORMATS[export_idx]
            say("Exporting " .. chosen.label .. "...")
            do_export(chosen.key)
            if try_refocus() then
                state = STATE_NAV
                say("Export")
            else
                say("Closing.")
                return false
            end
        elseif char == KEY_ESC then
            state = STATE_NAV
            say("Export")
        end
    end
    return true
end

local function main()
    local char = gfx.getchar()
    if char == -1 then
        return
    end
    if char ~= 0 then
        if not handle_key(char) then
            gfx.quit()
            return
        end
    end
    draw_window()
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

if GetProjectPath() == "" then
    say("Please save the project before distributing takes.")
    return
end

gfx.init(WINDOW_TITLE, 520, 44, 0)

say(string.format(
    "Distribute Takes. Up down to move, Enter to select, Escape to go back or close. On: %s.",
    nav_label(nav_idx)
))

defer(main)
