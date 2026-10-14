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

local M = {}

M.pair_words = {
    "2ch", "pair", "paire", "paar", "coppia", "par", "para", "пара", "对", "ペア",
    "쌍", "زوج", "pari", "пар", "πάρoς", "двойка", "קבוצה", "çift",
    "pár", "pāris", "pora", "jozi", "जोड़ी", "คู่", "pasang", "cặp",
    "stereo", "stéréo", "estéreo", "立体声", "ステレオ", "스테레오",
    "ستيريو", "στερεοφωνικός", "סטריאו", "stereotipas", "स्टीरियो",
    "สเตอริโอ", "âm thanh nổi", "paarig", "doppel", "duo"
}

M.left_words = {
    "l", "left", "gauche", "sinistra", "izquierda", "esquerda", "ліворуч", "слева", "vlevo", "balra", "vänster",
    "vasakule", "venstre", "vänstra", "levý", "левый", "lijevo", "stânga", "sol", "kushoto", "ซ้าย", "बाएँ", "बायां",
    "links", "linke", "lewa", "lewy", "lewe", "lewo"
}

M.right_words = {
    "r", "right", "droite", "destra", "derecha", "direita", "праворуч", "справа", "vpravo", "jobbra", "höger",
    "paremale", "høyre", "högra", "pravý", "правый", "desno", "dreapta", "sağ", "kulia", "ขวา", "दाएँ", "दायां",
    "rechts", "rechte", "prawa", "prawy", "prawe", "prawo"
}

function M.apply_pan_from_name(mixer_track, name)
    local lower_name = name:lower()

    local is_pair = false
    for _, word in ipairs(M.pair_words) do
        if lower_name:match("%s" .. word .. "$") or lower_name:match(word .. "$") then
            is_pair = true
            break
        end
    end

    local is_left, is_right = false, false
    for _, word in ipairs(M.left_words) do
        if lower_name:match("%s" .. word .. "$") or lower_name:match("^" .. word .. "%s") then
            is_left = true
            break
        end
    end
    if not is_left then
        for _, word in ipairs(M.right_words) do
            if lower_name:match("%s" .. word .. "$") or lower_name:match("^" .. word .. "%s") then
                is_right = true
                break
            end
        end
    end

    if is_left then
        SetMediaTrackInfo_Value(mixer_track, "D_PAN", -1.0)
    elseif is_right then
        SetMediaTrackInfo_Value(mixer_track, "D_PAN", 1.0)
    elseif is_pair then
        SetMediaTrackInfo_Value(mixer_track, "D_PAN", 0.0)
    end
end

return M
