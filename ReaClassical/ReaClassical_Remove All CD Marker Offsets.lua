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
local main, remove_offsets

---------------------------------------------------------------------

local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
    MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
    return
end

---------------------------------------------------------------------

function main()
    PreventUIRefresh(1)
    Undo_BeginBlock()
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

    SetProjExtState(0, "ReaClassical", "ddp_refresh_trigger", "y")
    local track = GetSelectedTrack(0, 0)
    remove_offsets(track)
    SetProjExtState(0, "ReaClassical", "ddp_silent", "y")
    local create_cd_markers = NamedCommandLookup("_RSa00edf5f46de174e455de2f03cf326ab3db034b9")
    Main_OnCommand(create_cd_markers, 0)

    Undo_EndBlock('Remove All CD Marker Offsets', 0)
    PreventUIRefresh(-1)
    UpdateArrange()
    UpdateTimeline()
end

---------------------------------------------------------------------

function remove_offsets(track)
    if not track then return end
    local num_items = CountTrackMediaItems(track)
    for i = 0, num_items - 1 do
        local item = GetTrackMediaItem(track, i)
        if item then
            local take = GetActiveTake(item)
            if take then
                local _, take_name = GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                if take_name and take_name:match("|OFFSET=") then
                    take_name = take_name:gsub("|OFFSET=[%-%d%.]+", "")
                    GetSetMediaItemTakeInfo_String(take, "P_NAME", take_name, true)
                end
            end
        end
    end
end

---------------------------------------------------------------------

main()


-- Remove |OFFSET=x from all items on a selected track


-- Example usage: remove offsets from first selected track
