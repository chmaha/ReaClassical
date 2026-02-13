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
local main, is_special_track, check_for_automation_on_special_tracks
---------------------------------------------------------------------
local SWS_exists = APIExists("CF_GetSWSVersion")
if not SWS_exists then
MB('Please install SWS/S&M extension before running this function', 'Error: Missing Extension', 0)
return
end

function is_special_track(track)
  local _, mixer_state = GetSetMediaTrackInfo_String(track, "P_EXT:mixer", "", false)
  local _, aux_state = GetSetMediaTrackInfo_String(track, "P_EXT:aux", "", false)
  local _, submix_state = GetSetMediaTrackInfo_String(track, "P_EXT:submix", "", false)

  return mixer_state == "y" or aux_state == "y" or submix_state == "y"
end

function check_for_automation_on_special_tracks()
  local has_automation = false

  for i = 0, CountTracks(0) - 1 do
    local track = GetTrack(0, i)
    if is_special_track(track) then
      local num_envelopes = CountTrackEnvelopes(track)
      for env_idx = 0, num_envelopes - 1 do
        local env = GetTrackEnvelope(track, env_idx)

        -- Check if envelope is visible, active, or armed
        local _, visible_str = GetSetEnvelopeInfo_String(env, "VISIBLE", "", false)
        local _, active_str = GetSetEnvelopeInfo_String(env, "ACTIVE", "", false)
        local _, arm_str = GetSetEnvelopeInfo_String(env, "ARM", "", false)

        -- If any of these are "1", the envelope is considered active
        if visible_str == "1" or active_str == "1" or arm_str == "1" then
          has_automation = true
          break
        end
      end
      if has_automation then break end
    end
  end

  return has_automation
end

function main()
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
PreventUIRefresh(1)
local num_pre_selected = CountSelectedTracks(0)
local pre_selected = {}
if num_pre_selected > 0 then
for i = 0, num_pre_selected - 1, 1 do
local track = GetSelectedTrack(0, i)
table.insert(pre_selected, track)
end
end
Main_OnCommand(40296, 0) -- Track: Select all tracks

-- Check for automation on special tracks and choose appropriate zoom command
local has_automation = check_for_automation_on_special_tracks()
local zoom
if has_automation then
  zoom = NamedCommandLookup("_SWS_VZOOMFITMIN")
else
  zoom = NamedCommandLookup("_SWS_VZOOMFIT")
end

Main_OnCommand(zoom, 0)  -- SWS: Vertical zoom to selected tracks
Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks
if num_pre_selected > 0 then
PreventUIRefresh(1)
Main_OnCommand(40297, 0) --unselect_all
SetOnlyTrackSelected(pre_selected[1])
for _, track in ipairs(pre_selected) do
if pcall(IsTrackSelected, track) then SetTrackSelected(track, 1) end
end
end
PreventUIRefresh(-1)
end
---------------------------------------------------------------------
main()