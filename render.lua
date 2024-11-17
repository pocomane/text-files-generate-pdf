#!/usr/bin/lua5.4

-----------------------------------------------------------------------------------
-- luasnip-templua WITH MOD

-- NOTE: this is almost iddentical to the luasnip version.
-- THE IMPROVEMENT is the handling of the Transformations

-- TODO : port the Trasformation to luasnip ???
-- TODO : rename "clear" utility function ???

local setmetatable, load = setmetatable, load
local fmt, tostring = string.format, tostring
local error = error

local function templua( template ) --> ( sandbox ) --> expstr, err
   local function expr(e) return ' out('..e..')' end

   -- Generate a script that expands the template
   local script, position, max = '', 1, #template
   while position <= max do -- TODO : why '(.-)@(%b{})([^@]*)' is so much slower? The loop is needed to avoid a simpler gsub on that pattern!
     local start, finish = template:find('@%b{}', position)
     if not start then
       script = script .. expr( fmt( '%q', template:sub(position, max) ) )
       position = max + 1
     else
       if start > position then
         script = script .. expr( fmt( '%q', template:sub(position, start-1) ) )
       end
       if template:match( '^@{{.*}}', start ) then
          script = script .. template:sub( start+3, finish-2 )
       else
          script = script .. expr( template:sub( start+2, finish-1 ) )
       end
       position = finish + 1
     end
   end

   -- Utility to append the script to the error string
   local function report_error( err )
     return nil, err..'\nTemplate script: [[\n'..script..'\n]]'
   end

   -- Special case when no template tag is found
   if script == template then
     return function() return script end
   end

   -- Compile the template expander in a empty environment
   local env = {}
   script = 'local _ENV, out, clear, transform = _ENV.extract(); ' .. script
   local generate, err = load( script, 'templua_script', 't', env )
   if err ~= nil then return report_error( err ) end

   -- Return a function that runs the expander with a custom environment
   return function( sandbox )

     -- Transformations handling
     local pipeline = {}
     local clear = function() pipeline = {} end
     local transform = function( a, b ) pipeline[1+#pipeline] = {a,b} end
     local apply_transform = function( str )
       for _, t in ipairs(pipeline) do
         --if str ~= "" then
           -- Apply tranform only on non-empty strings. Transform can be used
           -- just to add suffix/postfix decorations: without this check it
           -- could be triggered by the empty string between tags.
           -- TODO : remove ? it can be emulated with subst function, and actually
           -- pure prepend/postpend without pre-matching is rare (and can be
           -- done witout tranformation)
           str = str:gsub( t[1], t[2] )
         --end
       end
       return str
     end

     -- Template output generation
     local expstr = ''
     local function out( out )
       expstr = expstr..apply_transform( tostring( out ))
     end

     -- Template environment and utility function
     env.extract = function() return sandbox, out, clear, transform end

     -- Run the template
     local ok, err = pcall(generate)
     if not ok then return report_error( err ) end
     return expstr
  end
end

-----------------------------------------------------------------------------------
-- pseudo-markdown

local next_class = nil
local function set_class(c) next_class = c end
local function get_class(c)
	if not next_class then return "" end
	local result = ' class="'..next_class..'"'
	next_class = nil -- next_class = "base"
	return result
end
get_class()

local demarkdown_block
local demarkdown

function demarkdown_block(s)

	local done = false
	local function first_or_skip_sub(str, pat, sub)
	  if done then return str end
	  local result = str:gsub(pat, sub)
	  if not result then result = str end
	  if result ~= str then done = true end
	  return result
	end

	  s = s:gsub('^ *', '')
	  if s == "" then return "" end

    -- TODO's
	  s = s:gsub('^[ ]*[Tt][Oo][Dd][Oo].*', function(a, b)
		  return ''
	  end)

	  -- links
	  s = s:gsub('%[([^]]*)%]%(([^)]*)%)[^\n]*', function(a, b)
		  if a == "" or b == "" then
			  -- If one is missin, it will be parsed as "class extension"
			  return nil
		  end
		  return '<a href="'..b..'">'..a..'</a>'
	  end)

	  -- class extension
	  s = first_or_skip_sub(s, '^%[([^]]*)%]%(([^)]*)%)[^\n]*\n?(.*)', function(a, b, c)
		  if not a or a == "" then a = b end
		  set_class(a)
		  if #c < 1 then return ""
		  else return demarkdown_block(c)
		  end
	  end)

	   -- headers
	  s = first_or_skip_sub(s, '^(##*) *(.*)', function(a, b)
		   return '\n<h'..#a..'>'..b..'</h'..#a..'>'
	  end)

	  -- code block
	  s = first_or_skip_sub(s, '^~~*[^\n]*\n(.*)\n~~*$', function(a)
       local class = get_class()
       if class == "" then class = ' class="example"' end
		   return '<div'..class..'>'..demarkdown(a)..'</div>'
       -- -- TODO : change to:
		   -- return '<code'..get_class()..'>'..a..'</code>'
	  end)

	  -- list
	  s = first_or_skip_sub(s, '^%-.*', function(a)
      a = a:gsub("^[ ]*%-[ ]*","<li>")
      a = a:gsub("\n[ ]*%-[ ]*","</li>\n<li>")
      a = a .. '</li>'
		  return "<ul"..get_class()..">\n"..a.."</ul>"
	  end)

	  -- table
	  s = first_or_skip_sub(s, '^|[^\n]*|[^\n]*\n|[^\n]*%-[^\n]*\n(.*)', function(a)
		   a = a:gsub('\n|', '\n')
		   a = a:gsub('|[ ]*\n', '\n')
		   a = a:gsub('^|', '<tr><td>')
		   a = a:gsub('|', '</td><td>')
		   a = a:gsub('\n', '</td></tr>\n<tr><td>')
		   a = '<table'..get_class()..'>\n'..a..'</td></tr>\n</table>'
		   return a
	  end)

	  -- default block
	  s = first_or_skip_sub(s, '(.*)', function(a)
		  return '<p'..get_class()..'>'..a..'</p>'
	  end)

	  return s .. '\n\n'
end

function demarkdown(str)

	-- clean up / normalize whitespaces to simplify further processing
	str = str:gsub('\r\n','\n')
	str = str:gsub('\r','\n')
	str = str:gsub('^\n*','')
	str = str:gsub('\n*$','')
	str = str:gsub('\t','  ')
	str = str:gsub(' *\n','\n')
	str = str:gsub('\n\n\n*','\n\n\n\n')
	str = '\n\n'..str..'\n\n'
  if str:match("^[\n ]*$") then
    return str
  end

	-- parse text block by block
	local pieces = {}
	local maxpos = #str
	local position = 1
	while position < maxpos do
		--print(">>>>>>>>>> ---------------------------------------------------------")
		--print(">>>>>>>>>> first part of processing block ["..str:sub(position,position+10).."] at", s)
		local s, e = str:find('\n\n.-\n\n', position)
		if not s then break end
		local start_fence, ee = str:find('\n~~~~*\n', position)
		--print(">>>>>>>>>> start fence", start_fence, ee)
		if start_fence and start_fence <= e then
		  local has_terminal_fence, end_fence = str:find('\n~~~~*\n\n', ee + 1)
		  --print(">>>>>>>>>> end fence", has_terminal_fence, end_fence)
		  if has_terminal_fence then
			  e = end_fence
		  end
		end
		position = e + 1
		s = s + 2
		e = e - 2
		--print(">>>>>>>>>> final processing block ["..str:sub(s,e).."] at", s)
		--print(">>>>>>>>>> ---------------------------------------------------------")
		local block = str:sub(s, e)
		if #block > 0 then
			pieces[1+#pieces] = demarkdown_block(block)
		end
	end

	return table.concat(pieces)
end

-----------------------------------------------------------------------------------
-- render

local CACHEDIR = "./cache/"
local BUILDDIR = "./build/"
local SCRIPTDIR = arg[0]:gsub('[^/]*$', '')

package.path = package.path .. ';'..SCRIPTDIR..'?.lua'

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

local function tweak_example_block(x)
  x = x:gsub('<pre><code>(.-)</code></pre>',function(content)
    return '<div class="example"><p>'..(content:gsub('(\n\n)','</p>%1<p>'))..'</p></div>'
  end)
  return x
end

-- TODO : find another way
local function add_front_page(wrk, x)
  return ''
         .. '<div class="title">\n'
         .. '  <div class="title_text">'.. wrk.title.text .. '</div>\n'
         .. '  <div class="title_author">'.. wrk.title.author .. '</div>\n'
         .. '  <img class="title_image" src="../asset/'.. wrk.title.image .. '" />\n'
         .. '</div>\n'
         .. x
end

local function expand_content(wrk, src, env)
  local content = get_content(wrk, src)
  local generate, err = templua(content)
  if err ~= nil then
    log('ERROR - while compiling template '..src..': '..err)
    return content
  end
  if env == nil then
    env = {
      log = log,
      include = function(src, pat) return expand_content(wrk, src, env) end,
      mdtohtml = function(src) return demarkdown(src) end,
      date = os.date('!%Y-%m-%d %H:%M:%SZ'),
    }
  end
  local expanded, err = generate(env)
  if err ~= nil then
    log('ERROR - while expanding '..src..': '..err)
    return content
  end
  return expanded
end

local function render_html(wrk, src, dst)
  log('- expanding template')
  local content = expand_content(wrk, src)
  log('- postprocessing html')
  content = tweak_example_block(content)
  wrk.output[dst] = content
end

-----------------------------------------------------------------------------------
-- pdfize

local function make_deps()
  local function store_file(filename, content)
    local f, e = io.open(filename, 'wb')
    if e then error(e) end
    if content then f:write(content)end
    f:close()
  end
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

local function make_pdfs(wrk, dst)
  exec("mkdir -p '"..BUILDDIR.."'")
  log('-----------------')
  log('- working on '..dst)
  local basename = dst:gsub("^.*/",""):gsub('%.[Tt][m][p][l]$','')
  local htmlout = BUILDDIR..basename..'.html'
  render_html(wrk, dst, htmlout)
  local x = wrk.output[htmlout]
  local f, e = io.open(htmlout, 'wb')
  if e then error(e) end
  f:write(x)
  f:close()
  log('- generating pdf')
  local pdfout = BUILDDIR..basename..'.pdf'
  exec(CACHEDIR.."weasyprint '"..htmlout.."' '"..pdfout.."'")
  log('- done')
  --exec("cd '"..BUILDDIR.."' && pdfjam --landscape --signature 1 "..dst..'.pdf')
end

local function main(arg)
  make_deps()
  exec("pwd")
  local wrk = {output={},file_cache={}}
  for k = 1, #arg do
    make_pdfs(wrk, arg[k])
  end
end

-----------------------------------------------------------------------------------

main(arg)

