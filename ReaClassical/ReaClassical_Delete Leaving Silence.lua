--[[
@noindex
]]
local script_path = debug.getinfo(1, "S").source:match("@(.+[\\/])")
loadfile(script_path .. "ReaClassical_Loader.lua")(script_path .. "")
dofile(script_path .. "ReaClassical_Delete Leaving Silence.lua.rc")
