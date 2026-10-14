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

local keymap_ok, keymap = pcall(require, "ReaClassical_Keymap_Shortcuts")
local say = require("ReaClassical_Announce")

local M = {}

local lib_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
M.script_dir = lib_path:gsub("lib[\\/]$", "")

function M.screen_reader_present()
    if APIExists("clara_outputMessage") then return true end
    local _, debug_announce = GetProjExtState(0, "ReaClassical", "DebugAnnounce")
    return debug_announce == "on"
end

function M.accessible()
    return M.screen_reader_present() and GetExtState("ReaClassical", "GuiMode") ~= "imgui"
end

function M.toggle()
    if not M.screen_reader_present() then return nil end
    local to_accessible = not M.accessible()
    SetExtState("ReaClassical", "GuiMode", to_accessible and "accessible" or "imgui", true)
    return to_accessible
end

local TOGGLE_DESC = "Toggle GUI Mode"

local _, own_script_file = get_action_context()
local OWN_DESC = (own_script_file or ""):match("([^/\\]+)%.lua$")
OWN_DESC = OWN_DESC and OWN_DESC:gsub("^ReaClassical_", "")

local MOD_NAMES = { ctrl = "ctrl", control = "ctrl", cmd = "ctrl", shift = "shift", alt = "alt", opt = "alt" }
local function parse_label(label)
    local b = { ctrl = false, shift = false, alt = false }
    local rest = label
    while true do
        local mod, tail = rest:match("^(%a+)%+(.+)$")
        local name = mod and MOD_NAMES[mod:lower()]
        if not name then break end
        b[name] = true
        rest = tail
    end
    b.key = rest:upper()
    b.literal = #rest == 1 and not rest:match("%w")
    return b
end

local all_shortcuts
local bindings = {}

local function bindings_for(desc)
    if not bindings[desc] then
        if not all_shortcuts then
            all_shortcuts = keymap_ok and keymap.shortcuts_for_section(0) or {}
        end
        local list = {}
        for _, e in ipairs(all_shortcuts) do
            if e.desc == desc then list[#list + 1] = parse_label(e.key) end
        end
        bindings[desc] = list
    end
    return bindings[desc]
end

local GFX_NAMES = {
    [32] = "SPACE", [27] = "ESCAPE",
    [1818584692] = "LEFT", [1919379572] = "RIGHT", [30064] = "UP", [1685026670] = "DOWN",
    [1752132965] = "HOME", [6647396] = "END", [1885828464] = "PAGEUP", [1885824110] = "PAGEDOWN",
    [6909555] = "INSERT", [6579564] = "DELETE",
}
for i = 1, 12 do GFX_NAMES[26160 + i] = "F" .. i end

function M.gfx_shortcut(char)
    if char <= 0 then return false end
    local list = bindings_for(TOGGLE_DESC)
    if #list == 0 then return false end

    local cap = gfx.mouse_cap
    local ctrl, shift, alt = cap & 4 ~= 0, cap & 8 ~= 0, cap & 16 ~= 0
    if char > 256 and char < 512 then char = char - 256 end
    local name = GFX_NAMES[char]
    if not name then
        if char >= 1 and char <= 26 and char ~= 8 and char ~= 9 and char ~= 13 then
            name, ctrl = string.char(char + 64), true
        elseif char >= 33 and char <= 126 then
            name = string.char(char):upper()
            if char >= 65 and char <= 90 then shift = true end
        else
            for _, b in ipairs(list) do
                if #b.key == 1 and b.key:match("%w") and (b.ctrl or b.alt)
                    and b.ctrl == ctrl and b.alt == alt and b.shift == shift
                    and gfx.getchar(b.key:byte()) > 0 then
                    return true
                end
            end
            return false
        end
    end
    local literal = #name == 1 and not name:match("%w")
    for _, b in ipairs(list) do
        if b.key == name and b.ctrl == ctrl and b.alt == alt and (literal or b.shift == shift) then
            return true
        end
    end
    return false
end

local IMGUI_KEYS = {
    SPACE = "Space", LEFT = "LeftArrow", RIGHT = "RightArrow", UP = "UpArrow", DOWN = "DownArrow",
    HOME = "Home", END = "End", PAGEUP = "PageUp", PAGEDOWN = "PageDown", INSERT = "Insert",
    DELETE = "Delete", ENTER = "Enter", [","] = "Comma", ["."] = "Period", ["-"] = "Minus",
    ["="] = "Equal", ["["] = "LeftBracket", ["]"] = "RightBracket", [";"] = "Semicolon",
    ["'"] = "Apostrophe", ["/"] = "Slash", ["\\"] = "Backslash", ["`"] = "GraveAccent",
}

local function imgui_key_name(key)
    if IMGUI_KEYS[key] then return IMGUI_KEYS[key] end
    if key:match("^%w$") or key:match("^F%d%d?$") then return key end
    return nil
end

local is_mac = (GetOS():match("^OSX") or GetOS():match("^macOS")) ~= nil

function M.imgui_shortcut(ImGui, ctx, desc)
    local list = bindings_for(desc or TOGGLE_DESC)
    if #list == 0 then return false end

    local ctrl = ImGui.IsKeyDown(ctx, ImGui.Mod_Ctrl) or (is_mac and ImGui.IsKeyDown(ctx, ImGui.Mod_Super)) or false
    local shift = ImGui.IsKeyDown(ctx, ImGui.Mod_Shift)
    local alt = ImGui.IsKeyDown(ctx, ImGui.Mod_Alt)
    if not (ctrl or alt) and ImGui.IsAnyItemActive(ctx) then return false end

    for _, b in ipairs(list) do
        if b.ctrl == ctrl and b.alt == alt and (b.literal or b.shift == shift) then
            local key_name = imgui_key_name(b.key)
            local key = key_name and ImGui["Key_" .. key_name]
            if key and ImGui.IsKeyPressed(ctx, key, false) then return true end
        end
    end
    return false
end

function M.imgui_close_shortcut(ImGui, ctx)
    return OWN_DESC ~= nil and M.imgui_shortcut(ImGui, ctx, OWN_DESC)
end

function M.toggle_and_announce()
    local now_accessible = M.toggle()
    if now_accessible ~= nil then
        say(now_accessible and "Accessible windows" or "ReaImGui windows")
    end
    return now_accessible
end

function M.switch_window(entry_script)
    dofile(M.script_dir .. entry_script)
end

return M
