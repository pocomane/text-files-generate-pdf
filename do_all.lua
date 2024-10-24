#!/usr/bin/lua5.4

local function exec(cmd)
  --print("EXEC:", cmd)
  if not os.execute(cmd) then
    error('command execution failed: '..tostring(cmd))
  end
end

local script_dir = arg[0]:gsub('/[^/]*$', '/')
exec("'"..script_dir.."render.lua' ./desc.lua")

-- cd "$SCRIPTDIR"/../build
-- pdfjam --nup 2x1 --landscape trollbabe-summary-a5-twocol.pdf -o a.pdf
-- pdfjam --angle 90 --scale 1.1 --landscape trollbabe-sheet-a4.pdf -o b.pdf
-- pdfjam --landscape a.pdf b.pdf -o c.pdf
--
-- cp trollbabe-summary-a5-twocol.pdf Trollbabe-Quickrules-v0.4.pdf
-- mv c.pdf Trollbabe-Quickrules-And-Sheet-v0.4.pdf

