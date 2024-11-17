#!/usr/bin/lua

local function exec(cmd)
  if not os.execute(cmd) then
    error('command execution failed: '..tostring(cmd))
  end
end

local function execout(cmd)
  local f, e = io.popen(cmd, "r")
  if e ~= nil then error('command execution failed: '..tostring(cmd)) end
  local result = f:read('a')
  f:close()
  return result
end

exec[[lua ./render.lua ./hello_world.tmpl]]

