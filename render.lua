#!/usr/bin/lua5.4

local CACHEDIR = "./cache/"
local BUILDDIR = ""
local SCRIPTDIR = arg[0]:gsub('[^/]*$', '')

package.path = package.path .. ';'..SCRIPTDIR..'?.lua'

local DATE = os.date('!%Y-%m-%d %H:%M:%SZ')

local function exec(cmd)
  --print("EXEC: "..cmd)
  if not os.execute(cmd) then
    error('command execution failed: '..tostring(cmd))
  end
end

local function log(...)
  print(os.date('![%H:%M:%S ')..tostring(os.clock())..']', ...)
end

local function load_file(path)
  local f, e = io.open(path, 'r')
  if e then
    return nil, 'can not find '..path
  end
  local c = f:read('a')
  f:close()
  return c
end

local function load_lua_data(path)
  local c, e = load_file(path)
  if e then return nil, e end
  local f, e = load('return '..c)
  if e then return nil, e end
  return f()
end

local function get_content(wrk, filename)
  local content = wrk.file_cache[filename]
  if content then return content end
  local content, e = load_file(SCRIPTDIR..filename, 'r')
  if e then
    content, e = load_file("./"..filename, 'r')
    if e then
      error('can not find '..filename..' '..SCRIPTDIR..' or ./')
    end
  end
  wrk.file_cache[filename] = content
  return content
end

local function virtual_content(wrk, filename, content)
  if "string" ~= content then
    error('empty content for virutal file')
  end
  wrk.file_cache[filename] = content
end

local function store_file(filename, content)
  local f, e = io.open(filename, 'wb')
  if e then error(e) end
  if content then f:write(content)end
  f:close()
end

local function make_deps()
  exec("mkdir -p '"..CACHEDIR.."'")
  if not load_file(CACHEDIR.."weasyprint.done") then
    exec("cd '"..CACHEDIR.."' && curl -o dw.zip https://codeload.github.com/Kozea/WeasyPrint/zip/refs/tags/v60.2")
    exec("cd '"..CACHEDIR.."' && unzip dw.zip")
    exec("cd '"..CACHEDIR.."' && rm dw.zip")
    store_file(CACHEDIR..'weasyprint.done')
  end
  if not load_file(CACHEDIR.."pydyf.done") then
    exec("cd '"..CACHEDIR.."' && curl -o dw.zip https://codeload.github.com/CourtBouillon/pydyf/zip/refs/tags/v0.8.0")
    exec("cd '"..CACHEDIR.."' && unzip dw.zip")
    exec("cd '"..CACHEDIR.."' && rm dw.zip")
    store_file(CACHEDIR..'pydyf.done')
  end
  if not load_file(CACHEDIR.."weasyprint") then
    store_file(CACHEDIR..'weasyprint', [[#!/bin/sh
      export PYTHONPATH="]]..CACHEDIR..[[WeasyPrint-60.2:]]..CACHEDIR..[[pydyf-0.8.0:$PYTHONPATH"
      python3 -m weasyprint $@
    ]])
    exec("chmod ugo+x '"..CACHEDIR.."weasyprint'")
  end
end

local function render(wrk, content, template)

  exec("rm -f '"..BUILDDIR.."tmp.md'")
  local t, e = io.open(BUILDDIR.."tmp.md", 'w')
  if e then error(e) end
  t:write(content,'\n')
  t:close()
  local t, err = io.popen("markdown -f footnotes -f fencedcode '"..BUILDDIR.."tmp.md'")
  if e then error(e) end
  content = t:read('a')
  t:close()
  template = template:gsub('@{include"([^"]*)"}', function(...) return get_content(wrk, ...) end)
  content = content:gsub('%%', '%%%%')
  content = template:gsub("@{generate_html%(%)}", content)
  content = content:gsub('@{get_snippet%(([^)]*)%)}', wrk.snippet)
  return content
end

local function remove_todo(content)
  --return content:gsub('TODO.-(\n?)\n', '%1')
  return content:gsub('\nTODO.-\n\n', '\n\n'):gsub('\nTODO.-\n', '\n')
end

local function add_revision(content)
  return content:gsub('(\n[# ]*CREDITS)', '%0\n\nv0.1 '..DATE..' - The whole text is a draft. Look at the markdown version for a TODO list.\n', 1)
end

local function parse_footnote(content)
  content = content:gsub('\n%[^([0-9])%]:(.-)(\n\n)', '%3<a href="#fn-%1">[%1]:</a> <fn id="fn-%1">%2</fn>%3')
  content = content:gsub('%[^([0-9])%]', '<a href="#fn-%1">[%1]</a>')
  return content
end

local function parse_block_class(content)
  -- content = content:gsub('([\n]+)```html,page,break[\n]+```', '%1<div class="PageBreak"></div>') -- DISABLE THIS when using the github version of weasyprint since it has a bug
  content = content:gsub('([\n]+)```html,move,diagram[\n]+```', '%1<img src="../move_diagram.svg" style="column-span:all;width:200%%;"></img>')
  return content
end

local function parse_dice_refs(content)

  -- -- mode 1 : keep table
  -- return content

  return (content..'\n'):gsub('\n|.-\n\n', function(i)

    local x = i:gsub('^.-\n.-\n.-\n', ''):gsub('\n[| \t]*\n','\n')

    local a, b = 1, 0
    local y = x:gsub('|', function()
      b = b + 1
      if b > 6 then
        a = a + 1
        b = 0
      end
      return '['..tostring(a)..'.'..tostring(b)..']'
    end)

    -- -- mode 2 : compact paragraph
    -- return '\n'..y..'\n'

    local z = y:gsub('[ \t\n][ \t\n]*',' ')..'['
    z = z:gsub('%[(%d)%.(%d)%]([ ]*.-%f[ ])(.-%f[[])', function(a,b,c,d)
      return '<span style="white-space:pre">['..a..'.'..b..']'..c:gsub('[\n]',' ')..'</span><span>'..d..'</span>'
    end)
    z = string.sub(z,1,-2)

    -- mode 3 : paragrapsh with non breaking ref
    return '\n'..z..'\n'

    -- -- more 4 : comparison !
    -- return '\n'..i .. '\n\nVS\n\n' .. y .. '\n\nVS\n\n' .. z

  end)
end

local function tweak_example_block(x)
  x = x:gsub('<pre><code>(.-)</code></pre>',function(content)
    return '<div class="example"><p>'..(content:gsub('(\n\n)','</p>%1<p>'))..'</p></div>'
  end)
  return x
end

local function clean_img_count(wrk)
  wrk.imglst = {}
  if wrk.section_image then
    for _, v in pairs(wrk.section_image) do wrk.imglst[v] = 0 end
  end
  if wrk.title and wrk.title.image then
    wrk.imglst[wrk.title.image] = 0
  end
end

local function img_count(wrk, img)
  if not wrk.imglst[img] then
    error('unknown image "'..img..'"')
  end
  wrk.imglst[img] = wrk.imglst[img] + 1
end

local function inject_images(wrk, x)
  x = x:gsub('(\n?)(##*[^\n]*)',function(y,z)
    local img = wrk.section_image[z]
local function deblog(...)
  --print(...)
end

    if not img then
      img = ""
    else
      img_count(wrk, img)
      img = '\n\n<img class="section_image" src="../asset/'..img..'" />\n\n'
    end
    return img..y..z
  end)
  return x
end

local function inject_section_decoration(wrk, x)
  x = x:gsub('(\n?)(##*[^\n]*)',function(y,z)
    local pre = wrk.section_pre[z]
    if not pre then
      pre = ""
    end
    return pre..y..z
  end)
  return x
end


local function add_front_page(wrk, x)
  img_count(wrk, wrk.title.image)
  return ''
         .. '<div class="title">\n'
         .. '  <div class="title_text">'.. wrk.title.text .. '</div>\n'
         .. '  <div class="title_author">'.. wrk.title.author .. '</div>\n'
         .. '  <img class="title_image" src="../asset/'.. wrk.title.image .. '" />\n'
         .. '</div>\n'
         .. x
end

local function get_map_stat(map)
  local unused, multiple, tot = {}, {}, 0
  if map then
    for k, v in pairs(map) do
      local typ = type(v)
      if 'number' == typ then tot = tot + v end
      if 'boolean' == typ and v then tot = tot + 1 end
      if 'number' == typ and 1 < v  then multiple[1+#multiple] = k end
      if 'number' == typ and 1 > v then unused[1+#unused] = k end
      if 'boolean' == typ and not v then unused[1+#unused] = k end
    end
  end
  return unused, multiple, tot
end

local function img_get_stat(wrk)
  return get_map_stat(wrk.imglst)
end

local function make_single_html(wrk, opt, dst)
  if '' ~= dst then -- TODO : remove this check
    local src, mode = opt[2], opt[1]
    log('generating '..dst..'.pdf')
    clean_img_count(wrk)

    log('- reading content and template')

    local content = opt.content
    if not content then content = get_content(wrk, src) end
    local template = get_content(wrk, mode)

    log('- preprocessing md')

    content = content:gsub('\r','')
    content = remove_todo(content)
    content = add_revision(content)
    --content = parse_footnote(content)
    --content = parse_block_class(content)
    -- content = parse_dice_refs(content)
    if opt.insert_image then   content = inject_images(wrk, content) end
    if opt.add_front_page then content = add_front_page(wrk, content) end
    if opt.section_decoration then content = inject_section_decoration(wrk, content) end
    if opt.content_pre then content = opt.content_pre .." " .. content end
    if opt.content_post then content = content .. " " .. opt.content_post end

    if opt.insert_image then
      local unused, multiple, tot = img_get_stat(wrk)
      if 0 ~= #unused then log('- '..#unused..' unused images:', table.unpack(unused)) end
      if 0 ~= #multiple then log('- '..#multiple..' images used multiple times:', table.unpack(multiple)) end
    end

    log('- inserted ' ..tostring(tot).. ' images')

    log('- rendering html')

    local x = render(wrk, content, template)
    
    log('- postprocessing html')

    x = x:gsub('\r','')
    x = tweak_example_block(x)

    wrk.output[BUILDDIR..dst..'.html'] = x
  end
end

local function make_pdfs(wrk)
  for _, d in ipairs(wrk.outdef) do
    local dst = d[2]:match('[^/\\]*$')
    if '' ~= dst then
      dst = dst:gsub('%..*$','')
      dst = dst .. '-' .. d[1]:gsub('%..*$','')

      make_single_html(wrk, d, dst)

      local x = wrk.output[BUILDDIR..dst..'.html']
      local f, e = io.open(BUILDDIR..dst..'.html', 'wb')
      if e then error(e) end
      f:write(x)
      f:close()
      log('- generating pdf')
      exec(CACHEDIR.."weasyprint '"..BUILDDIR.."'"..dst..".html '"..BUILDDIR.."'"..dst..'.pdf')
      log('- done')
      --exec("cd '"..BUILDDIR.."' && pdfjam --landscape --signature 1 "..dst..'.pdf')
    end
  end
end

local function make_all(arg)
  log("Reference build date: "..DATE)
  local workspace, e = load_lua_data(arg[1])

  if e then error(e) end
  if type(workspace.path.build) ~= 'string' or workspace.path.build == '' then
    error("no path.build in the description file")
  end
  BUILDDIR = workspace.path.build .. '/'

  make_deps()

  exec("mkdir -p '"..BUILDDIR.."'")
  if SCRIPTDIR[#SCRIPTDIR] ~= '/' then
    SCRIPTDIR = SCRIPTDIR .. '/'
  end
  workspace.file_cache = {}
  workspace.outdef = workspace.output
  workspace.output = {}

  make_pdfs(workspace)
end

-----------------------------------------------------------------------------------

make_all(arg)

