--[[
@noindex

This file is a part of "ReaClassical" package.
See "ReaClassical.lua" for more information.

Author: BirdBird

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

Thanks Embass for the function!
]]

local r = reaper
local l_proj_count = -1
local get_child_tracks, edit_is_envelope, extend_razor_edits

function Main()
  local proj_count = r.GetProjectStateChangeCount(0)
  if l_proj_count ~= proj_count then
    local action = r.Undo_CanUndo2(0)
    if action and string.find(string.lower(action), "razor") then
      extend_razor_edits()
    end
  end
  l_proj_count = proj_count
  r.defer(Main)
end

function get_child_tracks(folder_track)
  local all_tracks = {}
  if r.GetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH") ~= 1 then
    return all_tracks
  end
  local tracks_count = r.CountTracks(0)
  local folder_track_depth = r.GetTrackDepth(folder_track)
  local track_index = r.GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER")
  for i = track_index, tracks_count - 1 do
    local track = r.GetTrack(0, i)
    local track_depth = r.GetTrackDepth(track)
    if track_depth > folder_track_depth then
      table.insert(all_tracks, track)
    else
      break
    end
  end
  return all_tracks
end

function edit_is_envelope(edit)
  local t = {}
  for match in (edit .. ' '):gmatch("(.-)" .. ' ') do
    table.insert(t, match);
  end
  local is_env = true
  for i = 1, #t / 3 do
    is_env = is_env and t[i * 3] ~= '""'
  end
  return is_env
end

function extend_razor_edits()
  local t_tracks = {}
  local track_count = r.CountTracks(0)
  for i = 0, track_count - 1 do
    local track = r.GetTrack(0, i)
    local rv, edits = r.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', '', false)
    if edits ~= "" and not edit_is_envelope(edits) then
      local child_tracks = get_child_tracks(track)
      if #child_tracks > 0 then
        for i = 1, #child_tracks do
          local c_track = child_tracks[i]
          table.insert(t_tracks, { track = c_track, edits = edits })
        end
      end
      -- table.insert(t_tracks, {track = track, edits = edits})
    end
  end
  if #t_tracks > 0 then
    r.PreventUIRefresh(1)
    for i = 1, #t_tracks do
      local track = t_tracks[i].track
      local edits = t_tracks[i].edits
      if r.IsTrackVisible(track, false) then
        r.GetSetMediaTrackInfo_String(track, 'P_RAZOREDITS', edits, true)
      end
    end
    r.PreventUIRefresh(-1)
  end
end

Main()
