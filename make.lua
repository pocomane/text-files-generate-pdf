#!/usr/bin/lua

-- utility

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

-- dependency

exec[[mkdir -p ./cache]]

-- if "" == execout[[cd ./cache; ls ./text-files-generate-pdf.done ; exit 0]] then
--   exec[[mkdir -p ./cache]]
--   exec[[cd ./cache && curl -L -o ./tmp.zip https://github.com/pocomane/text-files-generate-pdf/archive/refs/heads/main.zip]]
--   exec[[cd ./cache && unzip tmp.zip && rm tmp.zip]]
--   exec[[cd ./cache && touch ./text-files-generate-pdf.done]]
-- end

if "" == execout[[cd ./cache; ls ./weasyprint.done ; exit 0]] then
  exec[[cd ./cache && curl -o dw.zip https://codeload.github.com/Kozea/WeasyPrint/zip/refs/tags/v60.2]]
  exec[[cd ./cache && unzip dw.zip]]
  exec[[cd ./cache && rm dw.zip]]
  exec[[cd ./cache && touch ./weasyprint.done]]
end

if "" == execout[[cd ./cache; ls ./pydyf.done ; exit 0]] then
  exec[[cd ./cache && curl -o dw.zip https://codeload.github.com/CourtBouillon/pydyf/zip/refs/tags/v0.8.0]]
  exec[[cd ./cache && unzip dw.zip]]
  exec[[cd ./cache && rm dw.zip]]
  exec[[cd ./cache && touch ./pydyf.done]]
end

if "" == execout[[cd ./cache; ls ./weasyprint ; exit 0]] then
  local cachedir = execout[[cd ./cache && pwd]]:gsub("[\n\r]*$","")
  exec[[echo '#!/bin/sh' > ./cache/weasyprint]]
  exec([[echo 'export PYTHONPATH="]] .. cachedir .. [[/WeasyPrint-60.2:]] .. cachedir.. [[/pydyf-0.8.0:$PYTHONPATH"' >> ./cache/weasyprint]])
  exec[[echo 'python3 -m weasyprint $@' >> ./cache/weasyprint]]
  exec[[chmod ugo+x ./cache/weasyprint]]
end

-- run

print("- generating html")
exec[[lua ./render.lua ./hello_world.tmpl]]
print('- generating pdf')
exec[[./cache/weasyprint ./build/hello_world.html ./build/hello_world.pdf]]
--exec("cd '"..BUILDDIR.."' && pdfjam --landscape --signature 1 "..dst..'.pdf')
print('done.')

