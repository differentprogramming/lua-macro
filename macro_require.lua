tokenizer=require 'simple_tokenizer'
--comment out to have debugging autostart
started_debugging=true
  if not started_debugging then
    started_debugging = true
    
  
    require('mobdebug').start()
  end
--local serpent = require("serpent")
--require 'class'
--forward references
local strip_tokens_from_list,apply_macros,add_macro,nullp,cdr,car,cadr,cddr,caddr,cdddr,macros,validate_params
local optional_read_match_to,read_match_to,read_match_to_no_commas,sublist_to_list,concat_cons,scan_head_forward,add_token_keys,nthcar
local my_err,cons,list_to_array,copy_list, copy_list_and_object,simple_copy,render,output_render, last_cell,reverse_list_in_place,reverse_list,cons_tostring,Nil,list_append_in_place,process

local token_metatable = {__tostring=
            function(self)
              if self.token and self.macro_token~=self.token.value then
                if self.type == 'String' then return self.token.value end
                return self.token.value .. '-as-' .. self.macro_token 
              end
              return self.macro_token 
              end
            }

local filename2sections = {}
local function insure_subtable_exists(original_table,field)
  if not original_table[field] then original_table[field]={} end
end

-- table_path_get(t,'a','b','c') is t.a.b.c returning nil if any level does not exist
local function table_path_get(r, ...)
  local len=select('#',...)
  for i = 1, len do
    if not r then return nil end
    local selector=select(i,...)
    r=r[selector]
  end
  return r
end

codemap = {}

local function fill_codemap(filename, tokens,m)
  filename='@'..filename
  insure_subtable_exists(codemap,filename)
  local t=tokens
  local ti=1
  local di=1
  local cmap=codemap[filename]
  while not nullp(t) do
    local token = car(t)
    if token.token and token.token.from_line then 
      di=(token.token.from_line+1)*m 
    end
    while #cmap<ti do table.insert(cmap,di) end
--    cmap[ti]=di
    if cmap[ti]<di then cmap[ti]=di end
    ti=ti+1
    t=cdr(t)
  end
  
end

local function my_loadstring(string, filename,tokens,output_string)
  output_string=output_string or string
  fill_codemap(filename,tokens,1)
  if not filename then filename = 'macro_temp.lua' end
  local output_filename = filename .. '.temp.lua'
  local file=io.open(output_filename,"w")
--  file:write('return((')
  file:write(output_string ) --output_render(tokens))
--  file:write(')())')
  file:close()
  local function my_hander(err)
    print('in handler '..tostring(err))
    local token_number,error_text=string.match(tostring(err),":(%d+):(.*)")
    if not token_number then 
      my_err(nil,"can't determine token for error \""..tostring(err)..'"')
    else
      token_number = tonumber(token_number)
      
     print ('error at token '..token_number.. ' error message: "'..error_text..'"')
      if tokens then
          my_err(nthcar( token_number,tokens), error_text)
      else 
        my_err(nil,"can't determine token for error \""..tostring(err)..'"')
      end
    end
  end
  local ret
  local status --= xpcall(my_do,my_hander)
  local function my_do(...)
      local s=table.pack(pcall(status,...))
      if not s[1] then my_hander(s[2]) end
      table.remove(s,1)
      return table.unpack(s,s.n-1)
  end
  if not started_debugging then
    started_debugging = true
    
  
    require('mobdebug').start()
  end
 --editor.autoactivate=true
  status,ret=loadstring(string,"@"..filename)
  if not status then my_hander(ret) end
--  print ('the status is "' .. tostring(status) ..'"')
  return my_do
end

local function my_dostring(string, filename, tokens)

--print('my_dostring 「', string,'」')
  if not filename then filename = 'macro_temp.lua' end
  fill_codemap(filename,tokens,-1)
--  local file=io.open(filename,"w")
--  file:write(string)
--  file:close()
  local function my_hander(err)
--    print('in handler '..tostring(err))
    local token_number,error_text=string.match(tostring(err),":(%d+):(.*)")
    if not token_number then 
      my_err(nil,"can't determine token for error \""..tostring(err)..'"')
    else
      token_number = tonumber(token_number)
      
--      print ('error at token '..token_number.. ' error message: "'..error_text..'"')
      if tokens then
          my_err(nthcar(tokens, token_number), error_text)
      else 
        my_err(nil,"can't determine token for error \""..tostring(err)..'"')
      end
    end
    return true
  end
  local ret
  local function my_do()
 --     ret=dofile(filename)
    ret=assert(loadstring(string,'@'..filename))()
    
  end
  local status = xpcall(my_do,my_hander)

--  print ('the status is "' .. tostring(status) ..'"')
  return ret
end

local function array_to_set_table(a)
  if type(a)~='table' then return a end
  local t={}
  for _,v in ipairs(a) do
    t[v]=true
  end
  return t
end

simple_translate = setmetatable(
  { ['[|']='function (',
    ['{|']='coroutine.wrap(function (',
    ['|']=')',
    ['@']='return',
    ['y@']='coroutine.yield',
    ['Y@']='coroutine.yield',
    ['|]']='end',
    ['|}']='end)',
    ['$#']='select("#",...)',
    ['$1']='select(1,...)',
    ['$2']='select(2,...)',
    ['$3']='select(3,...)',
    ['$4']='select(4,...)',
    ['$5']='select(5,...)',
    ['$6']='select(6,...)',
  }, { __index = function(_,v) return v end })

local function pp_null_fn(lines, line_number) return line_number+1 end

local function file_path(mtoken)
  return table_path_get(mtoken,'token','filename') or '¯\\_(ツ)_/¯'
end

my_err= function (mtoken,err)
  local line=' '
  err=err or 'error'
  if not nullp(mtoken) then 
    if mtoken.token then
      print('token '.. mtoken.macro_token .. ' filename ' .. tostring(mtoken.token.filename) .. ' line '.. tostring(mtoken.token.from_line) ) 
    else
      print('macro token '.. tostring(mtoken) ) 
    end
  end
  if mtoken and mtoken.token then line= ':'..tostring(mtoken.token.from_line+1)..':'..tostring(mtoken.token.from_x+1)..':' end
  io.stderr:write(file_path(mtoken).. line .. err .. '\n')
  os.exit(1)
end

--from is cut, to is cut
local function cut_out_lines(lines,from_line,to_line)
--  print ("delete lines from "..from_line.." to "..to_line)
  while lines[1+from_line]==0 do from_line=from_line+1 end
  while lines[2+to_line]==0  do to_line=to_line+1 end
  
  if to_line<from_line or not lines[1+from_line] then return end
  
  --print ("adjusted delete lines from "..from_line.." to "..to_line)
  
  local at_start=lines[from_line+1]
  local before_start=at_start[1]
  local after_end=lines[to_line+2]
  local at_end
  
  
  if after_end then
    at_end=after_end[1]
  else
    after_end=Nil
  end
  
  if before_start ~= 'Cons' then 
    before_start[3]=after_end
    if after_end~= Nil then after_end[1]=before_start end
  else
    at_start[3]=after_end
    if after_end~= Nil then after_end[1]=at_start end
    at_start[2].macro_token=''
  end
  for j=from_line+1,to_line+1 do lines[j]=0 end
end

local function cut_out_lines_saved(lines,saved)
  cut_out_lines(lines,saved[1],saved[2])
  return saved;
end

local cut_out_if_lines = {}

local if_state = {}

local function redo_if_statements(lines)
  while #cut_out_if_lines>0 do cut_out_lines_saved(lines,table.remove(cut_out_if_lines)) end
end  

local if_special_lines = {
  ['@endif']=true,
  ['@else']=true,
  ['@elseif']=true,
  ['@if']=true
  }

local if_skip_lines = {
  ['@endif']=true,
  ['@if']=true
  }

local function skip_if(lines, curline, line_number)
    ::search_more::
    repeat 
      curline=curline+1
    until not lines[1+curline] or if_skip_lines[car(lines[1+curline]).macro_token]
    if not lines[1+curline] then 
      my_err(cadr(start),'unfinished @if, from line ' .. tostring(line_number))
    end
    if token == '@if' then
      curline=skip_if(lines, curline, line_number)
      goto search_more
    end -- token == '@endif' 
    return curline
end

local function pp_endif(lines,line_number,filename, skipping)
  if skipping then 
    my_err(cadr(start),'internal error.  @endifs should be culled before second pass')
  end
  if #if_state==0 then 
    my_err(cadr(start),'@endif without matching @if')
  end
  table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,line_number}))
  table.remove(if_state)
  return line_number+1
end

local function pp_else(lines,line_number,filename, skipping)
  local start = lines[line_number+1]
  if #if_state==0 then 
    my_err(cadr(start),'@else without matching @if')
  end
  table.remove(if_state)
    local curline=line_number
    ::search_more::
    repeat 
      curline=curline+1
    until not lines[1+curline] or (lines[1+curline]~=0 and if_special_lines[car(lines[1+curline]).macro_token])
    if not lines[1+curline] then 
      my_err(cadr(start),'unfinished @if, from line ' .. tostring(line_number))
    end
    local token = car(lines[1+curline]).macro_token
    if token == '@if' then
      curline=skip_if(lines, curline, line_number)
      goto search_more
    elseif token == '@endif' then
      table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,curline}))
      return curline+1
    elseif token == '@else' then
      my_err(cadr(start),'second @else ' )
    elseif token == '@elseif' then
      my_err(cadr(start),'@elseif after @else ' )
    end    
end

local function pp_elseif(lines,line_number,filename, skipping)
  local start = lines[line_number+1]
  if #if_state==0 then 
    my_err(cadr(start),'@elseif without matching @if')
  end
    local curline=line_number
    ::search_more::
    repeat 
      curline=curline+1
    until not lines[1+curline] or (lines[1+curline]~=0 and if_special_lines[car(lines[1+curline]).macro_token])
    if not lines[1+curline] then 
      my_err(cadr(start),'unfinished @if, from line ' .. tostring(line_number))
    end
    local token = car(lines[1+curline]).macro_token
    if token == '@if' then
      curline=skip_if(lines, curline, line_number)
      goto search_more
    elseif token == '@endif' then
      table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,curline}))
      return curline+1
    elseif token == '@else' then
      table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,curline-1}))
      return pp_else(lines,curline,filename, skipping)
    elseif token == '@elseif' then
      goto search_more
    end    
  table.remove(if_state)
end  

local function pp_if(lines,line_number,filename, skipping)
  local start = lines[line_number+1] --lines are counted from 0 but lua arrays from 1
  if skipping then 
    my_err(cadr(start),'internal error.  @ifs should be culled before second pass')
  end
  
  local function my_handler(err)
    local token_number,error_text=string.match(tostring(err),":(%d+):(.*)")
    if not token_number then 
      my_err(nil,"can't determine token for error \""..tostring(err)..'"')
    else
      token_number = tonumber(token_number)+2
      
      if not nullp(cdr(start)) then
          my_err(nthcar( token_number,cdr(start)), error_text)
      else 
        my_err(nil,"can't determine token for error \""..tostring(err)..'"')
      end
    end
  end
  
  local function do_conditional_expression(line_number)
    local start = lines[line_number+1]
    local exp_start=cdr(lines[line_number+1])
    local exp_end=exp_start
    while not nullp(cadr(exp_end)) and cadr(exp_end).token.from_line == line_number do exp_end=cdr(exp_end) end
    local ret= sublist_to_list({exp_start,exp_end},0)
    if not filename and car(start).token then filename = car(start).token.filename end
    if not skipping then
      if ret then
        ret=process(ret,filename,'no render')
      end
      local cond = my_dostring('return ('.. render(ret).. ')', filename, cdr(start));
--      if not cond then my_err(car(start), 'syntax error in @if or @elseif conditional expression') end
    
--      local _success,_err,result= xpcall(cond,my_handler)
--      print('if result',_success,_err,result)
      return cond
    end
  end
  if do_conditional_expression(line_number) then
--  print('if succeeded')
    table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,line_number}))
    table.insert(if_state, 'if')
    return line_number+1
  
  else
--  print('if failed')
    local curline=line_number
    ::search_more::
    repeat 
      curline=curline+1
    until not lines[1+curline] or (lines[1+curline]~=0 and if_special_lines[car(lines[1+curline]).macro_token])
    if not lines[1+curline] then 
      my_err(cadr(start),'unfinished @if, from line ' .. tostring(line_number))
    end
    local token = car(lines[1+curline]).macro_token
    if token == '@if' then
      curline=skip_if(lines, curline, line_number)
      goto search_more
    elseif token == '@endif' then
      table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,curline}))
      return curline+1
    elseif token == '@else' then
      table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,curline}))
      table.insert(if_state, 'else')
      return curline+1
    elseif token == '@elseif' then
      table.insert(cut_out_if_lines,cut_out_lines_saved(lines,{line_number,curline-1}))
      return pp_if(lines,curline, filename, skipping)
    end    
  end
end


local function pp_section(lines,line_number,filename, skipping)
  local start = lines[line_number+1] --lines are counted from 0 but lua arrays from 1
  if not filename and car(start).token then filename = car(start).token.filename end
  
  local splice_first = start[1] -- can be 'Cons' on the first element
  if cadr(start).type ~= 'String' then
    my_err(cadr(start),'name of a section expected after @section, " or \' expected')
  end--{}{}{}
  local nl = cdr(start)
  
  car(start).macro_token='' 
  cadr(start).macro_token=''
  
  if skipping then 
    insure_subtable_exists(filename2sections,filename)
    if filename2sections[filename][cadr(start).token.processed] then
      my_err(cadr(start),'section '..cadr(start).token.processed..' in file '..filename..' already exists.')
    end
    
    filename2sections[filename][cadr(start).token.processed]= {insertion_point = start}
  end
--  car(start).section = { filename=filename, section_name=cadr(start).token.processed }
  --table.insert(filename2sections[filename],cadr(start).token.processed)
  return car(nl).token.from_line+1
end

local function process_sections(filename)
  local empty
  if not filename2sections[filename] then return end
  repeat
    empty = true
    for k,v in pairs(filename2sections[filename]) do
        macro_list = Nil 
        for i=1,#v do
          if not nullp(v[i]) then macro_list = list_append_in_place(v[i],macro_list) end
          empty=false
        end
        for i=1,#v do table.remove(v) end
        if macro_list then
          macro_list=process(macro_list,filename,'no render')
        end
        if v.processed_macros then 
          v.processed_macros = list_append_in_place(v.processed_macros,macro_list)
        else
          v.processed_macros = macro_list
        end
    end
  until empty
  for k,v in pairs(filename2sections[filename]) do
  --insert processed now
    if not nullp(v.processed_macros) then
    v.insertion_point[3] = list_append_in_place(v.processed_macros,v.insertion_point[3])
    end
  end
end

local function section_object_from_token(token) 
  if not token.section then return nil end
  return filename2sections[token.section.filename][token.section.section_name]
end


local function pp_require(lines,line_number,filename,skipping)
  local start = lines[line_number+1] --lines are counted from 0 but lua arrays from 1
  local splice_first = start[1] -- can be 'Cons' on the first element
  if cadr(start).type ~= 'String' then
    my_err(cadr(start),'name of a file expected after @require, " or \' expected')
  end--{}{}{}
  local nl = cdr(start)
  if not skipping then require(cadr(start).token.processed) end
  if splice_first~= 'Cons' then 
    splice_first[3]=cdr(nl)
    cdr(nl)[1]=splice_first
  else
    start[3]=cdr(nl)
    cdr(nl)[1]=start
    car(start).macro_token=''
  end
  return car(nl).token.from_line+1
end

local function pp_macro(lines,line_number,filename,skipping) 
  local start = lines[line_number+1] --lines are counted from 0 but lua arrays from 1
  local splice_first = start[1] -- can be 'Cons' on the first element
  if cadr(start).macro_token ~= '{' then
    my_err(cadr(start),'struct of macro expected after @macro, { expected')
  end
    local s,nl
    s,nl=optional_read_match_to(cddr(start),'}')
    if not s or nullp(nl) or car(nl).macro_token ~='}' then 
      my_err(start,'struct of macro expected after @macro, } expected')
    end
    local ret = sublist_to_list( {cdr(start),nl} )
--    local filename = nil
   if not filename and car(start).token then filename = car(start).token.filename end
   local macro = my_dostring('return('..render(ret)..')', filename, cdr(start));
   if not macro then my_err(car(start), 'syntax error in table definition for macro') end
   if not skipping then add_macro(macro,macros, filename,car(start).token.from_line) end
  if splice_first~= 'Cons' then 
    splice_first[3]=cdr(nl)
    cdr(nl)[1]=splice_first
  else
    start[3]=cdr(nl)
    cdr(nl)[1]=start
    car(start).macro_token=''
  end
  return car(nl).token.from_line+1
end

local function pp_start(lines,line_number,filename,skipping) 
  local start = lines[line_number+1] --lines are counted from 0 but lua arrays from 1
  local splice_first = start[1] -- can be 'Cons' on the first element
    local s,nl
    s,nl=optional_read_match_to(cddr(start),'@end')
    if not s or nullp(nl) or car(nl).macro_token ~='@end' then 
      my_err(start,'@end expected after @start')
    end
    local ret = sublist_to_list( {cdr(start),nl},1 )
--    local filename = nil
   if not filename and car(start).token then filename = car(start).token.filename end
   if not skipping then 
    if ret then
      ret=process(ret,filename,'no render')
    end
    local macro = my_dostring('return function () '.. render(ret)..' end', filename, cdr(start));
    if not macro then my_err(car(start), 'syntax error @start/@end block') end

  local function my_handler(err)
    local token_number,error_text=string.match(tostring(err),":(%d+):(.*)")
    if not token_number then 
      my_err(nil,"can't determine token for error \""..tostring(err)..'"')
    else
      token_number = tonumber(token_number)+2
      
      if not nullp(cdr(start)) then
          my_err(nthcar( token_number,cdr(start)), error_text)
      else 
        my_err(nil,"can't determine token for error \""..tostring(err)..'"')
      end
    end
  end  
  xpcall(macro,my_handler)
   end
  if splice_first~= 'Cons' then 
    splice_first[3]=cdr(nl)
    cdr(nl)[1]=splice_first
  else
    start[3]=cdr(nl)
    cdr(nl)[1]=start
    car(start).macro_token=''
  end
  return car(nl).token.from_line+1
end

--turn list back to normal cons cells after first stage of preprocessing
local function strip_back_links(list)
  local n=list
  while not nullp(n) do
    n[1]='Cons'
    n=n[3]
  end
  while list.macro_token == '' do list=list[3] end
  return list
end


preprocessor_tokens =  setmetatable({
['@start']=pp_start,
-- ['@end']=pp_null_fn,
--['@define']=pp_null_fn,
['@if']=pp_if,
['@elseif']=pp_elseif,
['@else']=pp_else,
['@endif']=pp_endif,
['@section']=pp_section,
--['@fileout']=pp_null_fn,
['@require']=pp_require,
['@macro']=pp_macro,
}, { __index = function (_,v) return pp_null_fn end})

--macros as first class at expand time
--[==[
 @macro{
  new_tokens={'WHILE','DO','END','BREAK','CONTINUE'},
  head='WHILE ?()...exp DO ?,...statements END',
  body=[[
  local function %loop() 
    if ?exp then
      @apply({{head='BREAK',body='return("__*done*__")'},
      {head='CONTINUE',body='return %loop()'},}, ?statements)
      return %loop()
    end
    return '__*done*__'
  end
  local %save=table.pack(%loop())
  if %save[1]~='__*done*__' then return table.unpack(%save,%save.n) end
  
local fn,err= loadstring(process([[
  local i,j
  i=1 
  WHILE i<=6 DO
    j=10
    if i==3 then CONTINUE end
    if i==5 then BREAK end
    WHILE j<=60 DO
      if j==30 then CONTINUE end
      if j==50 then BREAK end
      print(i,j) 
      --I should test return too
      j=j+10
    END
    i=i+1
  END
  ]]))
  fn()
}

--]==]


add_token_keys= function(t)
  for k,_ in pairs(t) do
    tokenizer.add_special_token(k)
  end
end
local function add_tokens(t)
  if not t then return end
  for _,v in ipairs(t) do
    tokenizer.add_special_token(v)
  end
end

add_token_keys(simple_translate)

local function no_source_token(t)
  return setmetatable({macro_token=t},token_metatable)
end


local function string_to_source_array(str,filename,err_handler)
  local error_pos, source, meaningful =tokenizer.tokenize_all(str,filename,err_handler)
  if not error_pos then
    local flatten={}
    local prevx,prevy,indent=0,0,0
    for a = 1,#meaningful do 
      local ttype = source[meaningful[a]].type
      local value
      local token=source[meaningful[a]]
      if ttype=='String' then
        --we don't want to find escape sequences in our strings, so we use the processed version
        value='[=======['..source[meaningful[a]].processed..']=======]'
      else
        value=source[meaningful[a]].value
      end
      local dy=token.from_line-prevy
      prevy=token.to_line
      local dx,first
      if dy ~= 0 then
        dx=token.from_x
        indent = dx
        first=true
      else
        dx=token.from_x-prevx
        first=false
      end
      prevx=token.to_x
      table.insert(flatten, setmetatable( {first = first,macro_token=simple_translate[value],type=ttype,token=token,dx=dx,dy=dy,indent=indent, splice=false, indent_delta=0},token_metatable)) 
--      print('y = '..tostring( flatten[#flatten].token.from_line )..'\t x = '.. tostring( flatten[#flatten].token.from_x))
    end 
    return flatten
  end
end

local function splice_simple(original_head_list, new_head_array, concat_list)
  if not new_head_array then
    error("internal")
  end
  if #new_head_array == 0 then return concat_list end
  local indent 
  local indent_delta 
  if nullp(original_head_list) then
    indent = (new_head_array[1].indent or car(concat_list).indent or 0)
    indent_delta = 0
  else
    indent =car(original_head_list).indent+car(original_head_list).indent_delta
    indent_delta = indent-((new_head_array[1].indent or 0) + (new_head_array[1].indent_delta or 0))
  end
  local l=concat_list or Nil
  if new_head_array then 
    for i=#new_head_array,1,-1 do
--      if not new_head_array[i].indent then
--        print 'wat'
--      end
      assert (new_head_array[i].indent)
      new_head_array[i].indent_delta=(new_head_array[i].indent_delta or 0)+indent_delta
      l=cons(new_head_array[i],l)
    end
    car(l).splice=true
    car(l).first=true
    car(l).dy=1
    car(l).dx=car(l).indent
    if concat_list and not concat_list[1].first then
      car(concat_list).splice=true
      car(concat_list).first=true
      car(concat_list).dy=1
      car(concat_list).dx=car(concat_list).indent
    end    
  end
  return l
end

local function splice(original_head_list, new_head_array, section, filename)
  --Note, in the first case "section" is the concat list not the section
  if not filename then return splice_simple(original_head_list, new_head_array, section) end
  if not filename2sections[filename] then
    my_err(Nil,'No sections in file '..filename..' have been found.')
  end
  local section_table = filename2sections[filename][section]
  if not section_table then
        my_err(Nil,'no section '..section..' in file '..filename..' found.')
  end 
  local sp= splice_simple(original_head_list, new_head_array) 
  table.insert(section_table,sp)
  return sp
end

simple_copy = function (obj)
  if type(obj) ~= 'table' then return obj end
  local copy={}
  for i,v in pairs(obj) do copy[i]=v end
  return setmetatable(copy,getmetatable(obj))
end

--[[
New syntax
?name 
?...name
?,...name
?()...name
]]


local macro_params={
  --input paramsk
  ['?1']='param',  
  --input matches till
  ['?...']='param until',
  --input matches till next, also matches () {} [] - stops for comma
  --if the expected next is a comma then that matches
  --if the expected next is not a comma and it finds one, that's a failure
  
  ['?']='param match until',
  --in matches any number of elements including commas
  ['?,']='params',
  ['??,']='optional params',--generate var
  ['%']='generate var',
--  ['%external-load:']='global load', -- also need a 4th entry for saving
  ['@apply']='apply macros',
}

add_token_keys(preprocessor_tokens)
tokenizer.add_special_token('@apply') 
tokenizer.add_special_token('@@') --needs a global macro with a function body
tokenizer.add_special_token('@tostring') --needs a global macro with a function body
tokenizer.add_special_token('@end') 


local function skip_one(l)
  if not nullp(l) then return cdr(l) end
  return l
end

local function skip_apply(l, store, filename)
  l=cdr(l)
  if car(l).macro_token ~='(' then my_err(car(l), '( expected after @apply ') end
  l=cdr(l)
  local ret
  local where_struct_goes = l
  if (store) then 
    if car(l).macro_token ~='{' or cadr(l).macro_token ~='{' then my_err(car(l), 'array of macros expected after @apply ( got: '..car(l).macro_token .." ".. cadr(l).macro_token) end
    local s,nl
    s,nl=optional_read_match_to(l,',')
    if not s then my_err(car(l), 'array of macros expected after @apply (') end
    if nullp(nl) then
      my_err(car(l) ', expected after @apply({macros...} ') 
    end
    if car(nl).macro_token ~=',' then 
      my_err(car(nl) ', expected after @apply({macros...} ') 
    end
    --{}{}{} could use formatting
    ret = sublist_to_list( {l,nl},1 )
    local tokens = l
    l=cdr(nl);
    --concat_cons(ret,' ');
   where_struct_goes[2]={}
   local filename=nil
   if l.token then filename=l.token.filename end
   local temp_macros = my_dostring('return('..render(ret)..')', filename, tokens);
   if not temp_macros then my_err(car(nl), 'syntax error in table definition for macro for @apply') end
  
   for i = 1,#temp_macros do
     add_macro(temp_macros[i],where_struct_goes[2],filename)  --
   end
   where_struct_goes[3]=l
  else
    l=cdr(l)
  end
  
  if nullp(l) or not macro_params[car(l).macro_token] then my_err(car(l),'parameter expected after @apply({macros...}, got '.. car(l).macro_token ..' instead') end
  l=cdr(l)
  if nullp(l) or car(l).type~='Id' then my_err (car(l),'Id expected after @apply({macros...}, got '.. car(l).macro_token..' type = "'.. tostring( car(l).type) ..'" instead') end
  l=cdr(l)
  if nullp(l) or car(l).macro_token ~=')' then my_err(car(l), ') expected after @apply({macros...},?Id') end
  return cdr(l),where_struct_goes[2],caddr(where_struct_goes)
end

local skip_param_tokens={
    ['param']=skip_one,
  --input matches till
    ['param until']=skip_one,
  --input matches till next, also matches () {} [] - stops for comma
  --if the expected next is a comma then that matches
  --if the expected next is not a comma and it finds one, that's a failure
  ['param match until']=skip_one,
  --in matches any number of elements including commas
  ['params']=skip_one,
  ['optional params']=skip_one,
  --generate var
  ['generate var']=skip_one,
--  ['%external-load:']='global load', -- also need a 4th entry for saving
  ['apply macros']=skip_apply,
  }


add_token_keys(macro_params)

local match=
{
  ['(']=')',
  ['{']='}',
  ['[']=']',
  ['do']='end',
  ['for']='do', --special cased to go for 'end' after 'do'
  ['while']='do', --special cased to go for 'end' after 'do'
  ['if']='end',
  ['function']='end',
  ['repeat']='until', --really needs to be until exp
}
local starts=
{
  ['for']=true,
  ['while']=true,
  ['if']=true,
  ['function']=true,
  ['repeat']=true,
  ['local']=true,
  ['return']=true,
}
local separators=
{ 
  [',']=true,
  [';']=true,
}
local ends={
  ['end']=true
}
  

--[[
so here, car is [2]
cdr is [3]
--]]


nullp= function(l) return l==Nil end
local function listp(n) 
    return type(n)=='table' and 'Cons' ==  n[1]
end

local function pairp(n)
    return (not nullp(n)) and listp(n)
end

last_cell=function(l)
  while pairp(cdr(l)) do
    l=cdr(l)
  end
  return l
end

car=function(n)
  if n==nil then
    error('car on lua nil')
  end
  return n[2] 
end
cadr=function(n)
  if n==nil then
    error('cadr on lua nil')
  end
  return n[3][2] 
end
caddr=function(n)
  if n==nil then
    error('caddr on lua nil')
  end
  return n[3][3][2] 
end
cdddr=function(n)
  if n==nil then
    error('cdddr on lua nil')
  end
  return n[3][3][3] 
end
cddr=function(n)
  if n==nil then
    error('cddr on lua nil')
  end
  return n[3][3] 
end
cdr= function(n)
  if n==nil then
    error('cdr on lua nil')
  end
  return n[3] 
end

cons = function (first, rest)
return setmetatable({'Cons',first,rest},
  {__tostring = cons_tostring,
   __concat= function(op1,op2) return tostring(op1) .. tostring(op2) end,
   __len=function(self) 
      if nullp(self) then return 0 
      elseif nullp(self[3]) then return 1
      elseif not listp(self[3]) then return 1.5
      end
      return 1+ #(self[3])
    end

    })
end

local function reverse_transfer_one_in_place(dest,source)
  if source==nil then
    print 'wat'
  end
  if not nullp(source) then 
    dest,source,source[3] = source,source[3],dest
  end
  return dest,source
end

reverse_list_in_place= function (l,concat)
  local d=concat or Nil
  while not nullp(l) do
    l,d,l[3]=l[3],l,d
  end
  return d
end

--otherwise known as nconc
list_append_in_place = function(l,concat)
  local r=l
  while r[3]~=Nil do r=r[3] end
  r[3]=concat
  return l
end

reverse_list= function (l,concat)
  local d=concat or Nil
  while not nullp(l) do
    d=cons(l[2],d)
    l=l[3]
  end
  return d
end

local function array_to_list(a, concat)
  local l=concat or Nil
  if a then 
    for i=#a,1,-1 do
      l=cons(a[i],l)
    end
  end
  return l
end

local function append_list_to_array(a,l)
  while not nullp(l) do
    table.insert(a,car(l))
    l=cdr(l)
  end
  return a
end  
local function array_to_reversed_list(a, concat)
  local l=concat or Nil
  if a then 
    for i=1,#a do
      l=cons(a[i],l)
    end
  end
  return l
end

nthcar = function (n,l)
  repeat
    if nullp(l) then return Nil end
    if n>1 then 
      n=n-1
      l=cdr(l)
    else
      break
    end
  until false
  return car(l)
 end
 
local function quoted_tostring(q)
  return tostring(q)
--  if type(q)~='string' then return tostring(q) end
--  if q:find("'",1,true) then
--    if q:find('"',1,true) then
--      return '[['..q..']]'
--    else
--      return '"'..q..'"'
--    end
--  else
--    return "'"..q.."'"
--  end
end
  

local function cons_rest_tostring(self)
        if (nullp(self[3])) then return ' ' .. quoted_tostring(self[2]) .. ' 」'
        elseif (listp(self[3])) then return ' ' .. quoted_tostring(self[2]) .. cons_rest_tostring(self[3])
        else return ' ' .. quoted_tostring(self[2]) .. ' . ' .. quoted_tostring(self[3]) ..' 」'
        end
end;
    
cons_tostring = function(self)  
        if nullp(self) then return '「」'
        elseif nullp(self[3]) then return '「 ' .. quoted_tostring(self[2]) .. ' 」'
        elseif listp(self[3]) then return '「 ' .. quoted_tostring(self[2]) .. cons_rest_tostring(self[3])
        else return '「 ' .. quoted_tostring(self[2]) .. ' . ' .. quoted_tostring(self[3]) ..' 」'
        end
end
  
concat_cons= function(l,v)
  local dest = {}
  while not nullp(l) do table.insert(dest,l[2]) l=l[3] end
  return table.concat(dest,v)
end

output_render= function (l)
  --local d={}
  --while not nullp(l) do
  --  table.insert(d, car(l).macro_token)
  --  l=cdr(l)  
 -- end
  local d={}
 -- local render_line,render_x = 0,0
  local next_line = true
  while not nullp(l) do
    local t=car(l)
    local i,p
    i=t.indent+t.indent_delta
    if  i<0 then i=0 end
    if t.first then next_line = true end
    if next_line then
      table.insert(d,'\n')
      p=i
    else
      p=t.dx
      if not p or p<1 then p=1 end
    end
    table.insert(d, string.rep(' ',p))
    table.insert(d, t.macro_token)
    local k=t.token
 ---[[   
    while k and k.source[k.source_index+1] and not k.source[k.source_index+1].meaningful do
      local n = k.source[k.source_index+1]
      if n.type == "Comment" then 
        if n.from_line ~= k.to_line then
          table.insert(d,'\n')
          table.insert(d,string.rep(' ',i))
        else
          p=n.from_line-k.to_line
          if p<1 then p=1 end
          table.insert(d,string.rep(' ',p))
      end
        table.insert(d,n.value)
--        table.insert(d,'\n')
      end
      k=n
    end
 --]]         
    l=cdr(l)  
    next_line=l.dy 
  end
  return table.concat(d,'')
end
--]=]

render= function (l)
  local d={}
  while not nullp(l) do
    table.insert(d, car(l).macro_token)
    l=cdr(l)  
  end
  return table.concat(d,'\n')
end

Nil = cons()
Nil[2]=Nil
Nil[3]=Nil
assert(Nil==Nil[2])


local function read_to(token_clist,end_token)
--print('read to "', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local len =0;
  local r=token_clist
  while not nullp(r) and car(r).macro_token~=end_token do
    r=cdr(r)
    len=len+1
  end
  if len~=0 and (car(r) or end_token=='@end') then 
--    print('succeeded')
    return true,r,len 
  end
--  print('failed')
  return false,token_clist,0
end

optional_read_match_to = function(token_clist,end_token)
-- print('read match to "', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r).macro_token~=end_token do
    local m= match[car(r).macro_token]
    if m then
      local succ,inc
--      print('found new match '..car(r).macro_token ..' to ' .. match[car(r).macro_token])
      succ,r,inc= optional_read_match_to(cdr(r),m)
      if not succ then 
--        print('failed inner match')
        return false,token_clist,0 
      end
      len=len+inc+1
      if m=='do' then
        if nullp(r) then break end
        succ,r,inc= optional_read_match_to(cdr(r),'end')
      end
    end
    r=cdr(r)
    len=len+1
  end
  if not nullp(r) or end_token=='@end' then 
--    print('succeeded')
    return true,r,len 
  end
--  print('failed')
  return false,token_clist,0
end

read_match_to = function(token_clist,end_token)
-- print('read match to "', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r).macro_token~=end_token do
    local m= match[car(r).macro_token]
    if m then
      local succ,inc
--      print('found new match '..car(r).macro_token ..' to ' .. match[car(r).macro_token])
      succ,r,inc= optional_read_match_to(cdr(r),m)
      if not succ then 
--        print('failed inner match')
        return false,token_clist,0 
      end
      len=len+inc+1
      if m=='do' then
        if nullp(r) then break end
        succ,r,inc= optional_read_match_to(cdr(r),'end')
      end
    end
    r=cdr(r)
    len=len+1
  end
  if len~=0 and (not nullp(r) or end_token=='@end') then 
--    print('succeeded')
    return true,r,len 
  end
--  print('failed')
  return false,token_clist,0
end

read_match_to_no_commas= function(token_clist,end_token)
--print('read match to no commas"', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r).macro_token~=end_token and car(r).macro_token~=','and car(r).macro_token~=';' do
    if match[car(r).macro_token] then
      local succ,inc
--      print('found new match '..car(r).macro_token ..' to ' .. match[car(r).macro_token])
      succ,r,inc= optional_read_match_to(cdr(r),match[car(r).macro_token])
      if not succ then 
--        print('failed inner match')
        return false,token_clist,0 
      end
      len=len+inc+1
    end
    r=cdr(r)
    len=len+1
  end
  if len~=0 and ((nullp(r) and end_token=='@end') or car(r).macro_token==end_token) then 
--    print('succeeded')
    return true,r,len 
  end
--  print('failed')
  return false,token_clist,0
end

local function sublist_end(a,p)
  return p==a[2]
end

local function list_append_to_reverse(r,e)
  while not nullp(e) do
    r=cons(car(e),r)
    e=cdr(e)
  end
  return r
end

local function list_append(l,e)
  if nullp(l) then return e end
  local d=cons(car(l))
  local r1,r2=d,cdr(l)
  while not nullp(r2) do
    r1[3]=cons(car(r2))
    r1=cdr(r1)
    r2=cdr(r2)
  end
  r1[3]=e
  return d  
end

local gen_var_counter = 10000

--sublists are dangerious {pos-in-list, later-pos-in-same-list}
--as long as that invariant holds, we're ok
--not inclusive of second element
local function sublist_equal(a,b)
  local ra=a[1]
  local rb=b[1]
  while not sublist_end(a,ra) and not sublist_end(b,rb) do
    if car(ra)~=car(rb) then return false end
    ra=cdr(ra)
    rb=cdr(rb)
  end
  return sublist_end(a,ra) == sublist_end(b,rb)
end

list_to_array = function(l)
  local d={}
  while not nullp(l) do
    table.insert(d,car(l))
    l=cdr(l)
  end
  return d
end

local function sublist_to_array(s,endoff)
  local d = {}
  local r=s[1]
  endoff=endoff or 0
  repeat
    table.insert(d,car(r))
    if r==s[2] then break end
    r=cdr(r)
  until false
  while endoff>0 do
    table.remove(d)
    endoff=endoff-1
  end
  
  return d
end

sublist_to_list= function (s,endoff)
  return array_to_list(sublist_to_array(s,endoff))
end

strip_tokens_from_list= function(l)
  local d={}
  while not nullp(l) do
    table.insert(d,car(l).macro_token)
    l=cdr(l)
  end
  return array_to_list(d)
end

local function stripped_sublist_equal(a,b)
  return sublist_equal(strip_tokens_from_list(a),strip_tokens_from_list(b))
end

local function sublist_to_stripped_string(s)
  return tostring(strip_tokens_from_list(sublist_to_list(s)))
end

local function sublist_to_string(s)
  return tostring(sublist_to_list(s))
end

macros=
{
}


copy_list = function (l)
  assert(l[1]=='Cons')
	local d=cons(Nil,Nil)
	local r=d
	local p=Nil
	while not nullp(l) do
		r[2]=car(l)
		l=cdr(l)
		r[3]=cons(Nil,Nil)
		p=r
		r=r[3]
	end
	p[3]=Nil
	return d    
end
copy_list_and_object = function (l)
	local d=cons(Nil,Nil)
	local r=d
	local p=Nil
	while not nullp(l) do
		r[2]=simple_copy(car(l))
		l=cdr(l)
		r[3]=cons(Nil,Nil)
		p=r
		r=r[3]
	end
	p[3]=Nil
	return d    
end



local function apply_inner_macros(macros_dest,params,params_info,filename)
  
  local function replace_params(l)
    l=copy_list(l)
	local d=l
  local p=Nil
	while not nullp(l) do
		if car(l).macro_token 
    and macro_params[car(l).macro_token] 
    and cadr(l).macro_token 
    and params_info[cadr(l).macro_token] 
    and params_info[cadr(l).macro_token].value 
    then
      local t
      if params_info[cadr(l).macro_token].value[1]=='Cons' then        
        t = splice(l,list_to_array(params_info[cadr(l).macro_token].value),cddr(l))
      else
        if macro_params[car(l).macro_token] == 'generate var' then
          if not params_info[cadr(l).macro_token].value then
              gen_var_counter=gen_var_counter+1
              params_info[cadr(l).macro_token].value = setmetatable({ macro_token= '__GENVAR_'.. tostring(gen_var_counter) ..'__', type='Id'},token_metatable)
          end          
          
          local k=simple_copy(car(l))
          k.macro_token = params_info[cadr(l).macro_token].value.macro_token
          k.type = 'Id'
          --l[2]=k; l[3]=l[3][3]
          t= splice(p,{ k },cddr(l))
        else
          t= splice(p,{ params_info[cadr(l).macro_token].value},cddr(l))
        end
        if not nullp(p) then p[3]=t end
      end
      if p==Nil then d=t end
      p=l
			l=cddr(l)
		else
      p=l
			l=cdr(l)
		end
	end
	return d
  end
  
  local dest = {}
  if not params.head then 
    error  'inner macros have to have a head' 
  end
  dest.head=replace_params(params.head)--replace_params(array_to_list(string_to_token_array(params.head)))
  if params.body then
    if type(params.body) == 'function'  then
      dest.body = params.body
    else;
      dest.body=replace_params(params.body or {})--replace_params(array_to_list(string_to_token_array(params.body or {})))
    end
  end
  if params.semantic_function and type(params.semantic_function)~='function' then
    error 'semantic_function has to be a function'
  end
  dest.semantic_function = params.semantic_function
  dest.new_tokens = params.new_tokens
  dest.sections = params.section
    
  validate_params(dest.head,true)
  dest.handle, dest.handle_offset = scan_head_forward(dest.head)
--  print('handle == '..dest.handle,'handle offset == '..dest.handle_offset)
--you know what, there's no reason for a limit on how far forward a macro
--can match, it just means the rescan has to go that far.
--  scan_head_backward(dest.head)

  validate_params(dest.body)
  
  if params.sections then
    dest.sections={}
    for k,v in pairs(params.sections) do
      dest.sections[k]=replace_params(array_to_list(string_to_source_array(v)))
      validate_params(dest.sections[k])
    end
  end  
--  print ('inner macro: offset ='..dest.handle_offset..' handle = '..dest.handle)
  while not macros_dest[dest.handle_offset] do table.insert( macros_dest,{} ) end
  if not macros_dest[dest.handle_offset][dest.handle] then macros_dest[dest.handle_offset][dest.handle]={} end 
  table.insert(macros_dest[dest.handle_offset][dest.handle],dest)
end

validate_params= function (head, is_head,filename)
  if not head then
    print 'wat'
  end
  
  --head=array_to_list(head)
  
  while not nullp(head) do
    local c = car(head)
    if not c or not c.macro_token then
      print 'wat'
    end
    local is_param = macro_params[c.macro_token]
    if is_param == 'apply macros' then
        if is_head then error '@apply can not appear in the head' end
    elseif is_param and (nullp(cdr(head)) or cadr(head).type ~= 'Id') then 
      my_err (car(head),"identifier missing after match specifier "..c.macro_token .." in head") 
    end
    local apply_struct
    if is_param then 
      local apply_struct
      head,apply_struct=skip_param_tokens[is_param](head,true,filename)
--      if apply_struct then 
--        print('@apply on these macros:',apply_struct) 
--      end
    else 
      head=cdr(head)
    end
  end
  
end

scan_head_forward= function(head)
  
  --head=array_to_list(head)
  
  i=1
  while not nullp(head) do
    local c = car(head)
    local is_param = macro_params[c.macro_token]
    if is_param then
      if is_param~= 'param' then 
        my_err(car(head),'macro must start with a constant token or constant preceded by single token params:'.. head) 
      end
    else
      return c.macro_token,i
    end
    i=i+1
    if is_param then head=cddr(head) else head=cdr(head) end
  end
  my_err (car(head),'macro must have a constant token:'.. head)
end

local function set_token_list_line(l,line)
  while not nullp(l) do
    local t=car(l)
    t.token.from_line=line
    t.token.from_x=0
    t.token.to_line=line
    t.token.to_x=0
    l=cdr(l)
  end
end

--[[Possibly params
new_tokens,
head (required)
semantic_function
body / (can be a function)
sections = {section_name (can be functions)...}}
macros_dest is optional
]]
add_macro= function (params, macros_dest,filename,line)
  add_tokens(params.new_tokens)
  
  local dest = {}
  if not params.head then error  'macros have to have a head' end
  dest.head=array_to_list(string_to_source_array(params.head,filename,my_err))
      if line then set_token_list_line(dest.head,line) end  
  if params.body then
    if type(params.body) == 'function'  then
      dest.body = params.body
    else
      dest.body=array_to_list(string_to_source_array(params.body or {},filename,my_err))
      if line then set_token_list_line(dest.body,line) end
    end
  end
  if params.semantic_function and type(params.semantic_function)~='function' then
    error 'semantic_function has to be a function'
  end
  dest.semantic_function = params.semantic_function
  dest.new_tokens = params.new_tokens
  dest.sections = params.section
      
  validate_params(dest.head,true,filename)
  dest.handle, dest.handle_offset = scan_head_forward(dest.head)
--  print('handle == '..dest.handle,'handle offset == '..dest.handle_offset)
--you know what, there's no reason for a limit on how far forward a macro
--can match, it just means the rescan has to go that far.
--  scan_head_backward(dest.head)

  if type(dest.body) ~= 'function' then
    validate_params(dest.body,false,filename)
  end
  
  if params.sections then
    dest.sections={}
    for k,v in pairs(params.sections) do
      dest.sections[k]=array_to_list( string_to_source_array(v))
      if line then set_token_list_line(dest.sections[k],line) end
      validate_params(dest.sections[k],false,filename)
    end
  end  
  
  macros_dest = macros_dest or macros
  while not macros_dest[dest.handle_offset] do 
    table.insert(macros_dest,{}) 
  end
  if not macros_dest[dest.handle_offset][dest.handle] then macros_dest[dest.handle_offset][dest.handle]={} end 
  --print('macro on handle '..dest.handle..' defined')
  table.insert(macros_dest[dest.handle_offset][dest.handle],dest)

end

local function token_copy(token)
  local t=simple_copy(token)
  t.token=simple_copy(t.token)
  return t
end


local splice_body = array_to_list(string_to_source_array('?a ?b'))
add_macro({ head='?1a @@ ?1b', 
    body= function(param_info,c,do_body)
      local ok,s,ret,n = do_body(splice_body,c)
      if ok then
        ret[2]=token_copy(ret[2])
        car(ret).macro_token = car(ret).macro_token .. cadr(ret).macro_token
        ret[3]=ret[3][3]
        car(ret).type = 'Id'
      end
      return ok,s,ret,n
     end })

local tostring_body = array_to_list(string_to_source_array('"dummy" ?a'))

add_macro({ head='@tostring(?,a)',
    body= function(param_info,c,do_body)
      local ok,s,ret,n = do_body(tostring_body,c)
      local dest = {'[======['}
      
      if ok then
        ret[2]=token_copy(ret[2])
        
        local l = param_info['a'].value
        local e = ret[3]
        local first=true
        while not nullp(l) do
          e=e[3]
          if not first then table.insert(dest,' ') end
          first = false
          table.insert(dest,car(l).macro_token)
          l=cdr(l)
        end
        table.insert(dest,']======]')
        
        
        car(ret).macro_token = table.concat(dest,'')
        car(ret).token.processed = cadr(ret).macro_token
        car(ret).token.value = car(ret).macro_token
        ret[3]=e
      end
      return ok,s,ret,n
     end })


local function add_simple_translate(m,t)
  simple_translate[m]=t
end


for i,v in ipairs(macros) do
  add_tokens(v.new_tokens)
  v.head=string_to_source_array(v.head)
  v.body=string_to_source_array(v.body)
end

--        processed,replaced_tokens_list,last_replaced_token_list_element =macro_match(flatten,pos,v)
-- needs to return a sublist
-- returns processed/didn't followed by first element replace followed by last element of macro
local function macro_match(datac,macro,filename)
  local head=macro.head --array_to_list(macro.head)
  local c,pos=datac,head
  local param_info={} --type=, value=
  if macro.match_debug then
    print('match debug')
  end
  
  --reading into parameters in the head
  --if they already have values, then verifying that they match
  local match = function(match_fn) -- read_to, read_match_to or read_match_to_no_commas
      --pos must point at the parameter specifier ie ?
      --caddr(pos) will be what we stop at
      if nullp(caddr(pos)) then my_err (cadr(pos), "match until must have a token after it") end
      if macro_params[caddr(pos).macro_token] then my_err (caddr(pos), "match until must end with a constant token") end
      --success, end token (the one targetted), number of tokens matched including final
      local succ, nc, inc = match_fn(c,caddr(pos).macro_token)
      if not succ then return false end
--      print("match succeeded, inc =",inc)
      -- if the parameter you're matching into already has a value, that's ok if the text matched has the same
      -- tokens as what it already holds
      if param_info[cadr(pos).macro_token].value then -- prolog style equality matching
        if not (stripped_sublist_equal(param_info[cadr(pos).macro_token].value,{c,nc})) then
--          print('reusing parameter match failed on', cadr(pos).macro_token )
          return false
        else 
--          print(cadr(pos).macro_token, "= a previous match", sublist_to_stripped_string(param_info[cadr(pos).macro_token]))
        end
      else
        --copy match into the parameter, cutting off the stop character
        param_info[cadr(pos).macro_token].value = sublist_to_list({c,nc},1)
        --if nothing was matched, that's a failure
        --we could make a match type that accepts empty matchesS
        --{}{}{} maybe we should allow this or make it an option maybe ?? instead of ?
--        if #(param_info[cadr(pos).macro_token].value) == 0 then
--          print("empty parameter")
--          return false
--        end
--        print(cadr(pos).macro_token,"set to",tostring(strip_tokens_from_list(param_info[cadr(pos).macro_token].value)))
      end
      c=nc
      pos=cdddr(pos)
      return true
    end
  
  while not nullp(pos) do --head
    if car(pos).macro_token==car(c).macro_token then
      pos=cdr(pos)
      c=cdr(c)
    elseif car(pos).macro_token=='@end' and nullp(c) then 
      pos=cdr(pos)
    elseif macro_params[car(pos).macro_token] then
      local param_type = macro_params[car(pos).macro_token]
      local param_name=cadr(pos).macro_token -- @apply doesn't appear in the head
      if not param_info[param_name] then 
        param_info[param_name]={type=param_type} 
      end
      -- Already checked that the next is an Id
      if param_type=='param' then
        if param_info[param_name].value then -- prolog style equality matching
          if param_info[param_name].value~=car(c).macro_token then 
            return false,datac 
          else 
--            print(cadr(pos).macro_token, "= a previous match", car(c).macro_token)
          end
        else
          param_info[param_name].value=car(c)
--          print(cadr(pos).macro_token,"set to",car(c).macro_token)
        end
        pos=cddr(pos)
      elseif macro_params[car(pos).macro_token]=='param until' then
        if not match(read_to) then 
          return false,datac 
        end
      elseif macro_params[car(pos).macro_token]=='params' then
        if not match(read_match_to) then 
          return false,datac 
        end
      elseif macro_params[car(pos).macro_token]=='optional params' then
        if not match(optional_read_match_to) then 
          return false,datac 
        end
      elseif macro_params[car(pos).macro_token]=='param match until' then
        if not match(read_match_to_no_commas) then 
          return false,datac 
        end
      elseif macro_params[car(pos).macro_token]=='generate var' then 
        my_err (car(pos), "can't have a generate variable in a macro head")
      else --unused so far
      end
      c=cdr(c)
    else
      return false,datac
    end
  end
  
  
  local do_body= function (body,tc,f)
    local dest={} --splices c on after  
    local bi=body 
--    print("Scanning Body", strip_tokens_from_list( body))
    while not nullp(bi) do
   --   if not bi or not body or not body[bi] or not body[bi].macro_token then
   --     print 'breakpoint'
   --   end
      local param_type_text=macro_params[car(bi).macro_token]
      local param_type=nil
        if param_type_text=='apply macros' then
          local inner_macros,p
          bi,inner_macros,p= skip_param_tokens[param_type_text](bi)
--          print('++++++++++++++++++++++++++++', inner_macros)
          local temp={}
          for _,i in ipairs(inner_macros) do
            for _,j in pairs(i) do --ordered by handle offset
              for _,k in ipairs(j) do
                if k.head then apply_inner_macros(temp,k,param_info,filename) end
              end
            end
          end
          temp=apply_macros(temp,param_info[p.macro_token].value,filename)
          dest=append_list_to_array(dest,temp)
        else
          if param_type_text then  
            bi= skip_param_tokens[param_type_text](bi)
          
            if param_type_text=='generate var' then
              if not param_info[car(bi).macro_token] then 
                param_info[car(bi).macro_token]={type='generate var'}
              end
            end
            if not param_info[car(bi).macro_token] then
              my_err(car(bi), "body contains a parameter that isn't in the head")
            end
            
            param_type = param_info[car(bi).macro_token].type
--            print('param type = '..param_type)
          end
      --    if param_type_text=='generate var'
          
          if not param_type_text then
            table.insert(dest,car(bi))
      --      dest=cons(body[bi],dest)
--            print('>>',car(bi).macro_token)
          elseif not param_type then 
             my_err (car(bi),' unmatched parameter '..car(bi).macro_token) 
          elseif param_type=='param' then
            table.insert(dest,param_info[car(bi).macro_token].value)
      --      dest=cons(param_info[body[bi].macro_token].value,dest)
--            print('>>',param_info[car(bi).macro_token].value)
          elseif param_type=='param until' 
          or param_type=='param match until' 
          or param_type=='params' 
          or param_type=='optional params' 
          then
            dest=append_list_to_array(dest,param_info[car(bi).macro_token].value)
--            print('>>',param_info[car(bi).macro_token].value)
          elseif param_type=='generate var' then 
            if not param_info[car(bi).macro_token].value then
              gen_var_counter=gen_var_counter+1
              param_info[car(bi).macro_token].value = setmetatable({ macro_token= '__GENVAR_'.. tostring(gen_var_counter) ..'__', type='Id'},token_metatable)
--              print('generating variable',car(bi).macro_token, 'as',param_info[car(bi).macro_token].value )
            end
      --      dest=cons(param_info[body[bi].macro_token].value,dest)
             local t = simple_copy(car(bi))
             t.macro_token = param_info[car(bi).macro_token].value.macro_token
             t.type = dest,param_info[car(bi).macro_token].value.type
             table.insert(dest,t)
--             print('>>',param_info[car(bi).macro_token].value)
          else --unused so far
          end
          bi=cdr(bi)
        end --~= apply macro
    end --while
    --
    return true,tc,splice(datac,dest,tc,f)
  end --function do_body
  if macro.sections then --{}{}{} ignore sections for now
    for section,m in pairs(macro.sections) do
      if type(m) == 'function' then
        if not filename2sections[filename] then
          my_err(cadr(start),'No sections in file '..filename..' have been found.')
        end
        local sublist = filename2sections[filename][section]
        if not sublist then
              my_err(cadr(start),'no section '..cadr(start).token.processed..' in file '..filename..' found.')
        end 
        m(param_info,sublist[2][3])
      else
          do_body(m,section,filename)
      end
    end
  end
  if macro.semantic_function then
    local sem_return = macro.semantic_function(param_info,c)
      if not sem_return then return false,datac end
      if sem_return~=true then return true,sem_return end
  end
  if macro.body then
    if type(macro.body) == 'function' then
      local body_ret,b,c = macro.body(param_info,c,do_body)
      if body_ret then return body_ret,b,c end
      return false,datac 
    else
      return do_body(macro.body,c)
    end
  end     
end

-- this could be written differently if 'list' is always a double linked list
apply_macros = function(macros, flatten,filename)
  flatten=reverse_list_in_place(flatten)                    -- we keep the active portion of the expansion by transfering between a reversed and a forward list
                                                            -- instead of having a double linked list.  
  
  local dest = Nil                                          -- dest is the forward list, we will move forward as we expand
  while not nullp(flatten) do
    dest,flatten = reverse_transfer_one_in_place(dest,flatten)  -- move one token from the beginning of the reversed list to the beginning of the forward list
--    dest = cons(car(flatten),dest)
--    flatten=cdr(flatten)
    local done                                              -- we are done at a token when we've tried all macros and none expanded
                                                            -- eventually we should optimize this, but we have to keep the macros in order so it won't be simple
    repeat 
      done = true
      for nth,macros_per_offset in ipairs(macros) do
        local t=macros_per_offset[nthcar(nth,dest).macro_token]
        if t then 
          for i,v in ipairs(t) do
            local processed,start
            --a bit of optimization
            --if I can table drive this more it could be more optimized, but
            --how to maintain macro order then?
            assert(nth == v.handle_offset)
            
            assert( v.handle == nthcar(nth,dest).macro_token)  -- have we found a macro with the right handle?
            processed,dest,start=macro_match(dest,v,filename)                    -- if so process the macro
            if processed then                                           -- if the macro expanded, it did so at the beginning of dest
                                                                        -- dump the whole processed portion back into the reverse list to rescan
              done = false                                             
              --set rescan back by the whole macro
              --is it possible that it sets up less than a whole macro?  
              --rescan from the end of the new substitution
              while start~=dest do
                flatten, start = reverse_transfer_one_in_place(flatten,start)
  --              flatten=cons(car(start),flatten)
  --              start=cdr(start)
              end
              break -- should always scan macros in order!
            end
          end
        end
      end
    until done
  end
  return dest
end

local function token_error_handler(token)
  my_err(setmetatable({macro_token=simple_translate[token.value], type = token.type, token=token},token_metatable),'illegal token')
end

--process as used by process sections just processes a list and returns a list
--no preprocessing, no rendering to a string
--this is signaled by no_render not being nil

process =  function(str,filename, no_render,skipping)
  local source_array 
  local source_list
  if no_render then
    source_list = str
  else
    source_array = string_to_source_array(str,filename,token_error_handler)   -- stores simple translated names in macro_token, and the whole token in token
    source_list=array_to_list(source_array)               -- convert to sexpr so that it's more   end
  end                                                            
  local lines = {}                                            -- make array of lines in order to handle preprocessor directives that only appear at the beginning of lines
                                                              -- 'lines[]' contains pointers into the continuous sexpr in source_list
  local function add_line(i,v)
    if not lines[i+1] then --plus 1 because I count lines from 0
      while #lines <= i do table.insert(lines,0) end
      lines[i+1]=v
    end
  end
  
  local p,prev=source_list,'Cons'                             -- the first element of the double linked list remains a cons cell, It would be better to have a root cell
                                                              -- I currently have to fake changing the first element, and that might not work in all cases.
  if not no_render  then
    while not nullp(p) do                                       -- turn source_list into a double linked list
      add_line(car(p).token.from_line,p)
      p[1]=prev
      prev=p
      p=cdr(p)
    end
    
    if skipping then redo_if_statements(lines) end
    
    local i=0 --line numbers and x positions count from 0 
    while i < #lines do                                         -- handle preprocessor directives that only appear as the first token of lines
  --    if lines[i] == 0 then 
  --      print('line '..i..' is blank')
  --    else
  --      print('line '..i.. 'is at ' .. car(lines[i]).token.from_line .. ' is a '.. car(lines[i]).macro_token)
  --      if lines[i][1]=='Cons' then print ('is first token') else print('prev token at line '..car(lines[i][1]).token.from_line .. ' is a '.. car(lines[i][1]).macro_token) end
  --    end
      if lines[i+1] ~= 0 then
        i = preprocessor_tokens[car(lines[i+1]).macro_token](lines,i,filename, skipping) -- returns the next line to process
      else
        i=i+1
      end
    end
    --kludge so that special tokens will be added
    if not skipping then
   --   print 'phase 2'
      return process(str,filename, no_render,true) 
    end
  end
--  print('after preprocess statements are removed, file is [' .. strip_tokens_from_list(source_list) .. ']')
  

  local dest= apply_macros(macros,strip_back_links(source_list), filename)  -- apply global macros. I strip the back links and nulified intial links just so that 
                                                                  -- there can't be any bugs caused by using the back links when they're no longer valid
  --{}{}{} could use formatting
  if no_render then return dest end
  process_sections(filename)
  local ret=render(dest,'\n') 
--  print(strip_tokens_from_list( dest))
  return ret,dest,output_render(dest)
end

local macro_path = string.gsub(package.path,'%.lua','.pp.lua')
-- Install the loader so that it's callled just before the normal Lua loader
local function load(modulename)
  local errmsg = ""
  -- Find source
  local modulepath = string.gsub(modulename, "%.", "/")
  for path in string.gmatch(macro_path, "([^;]+)") do
    local filename = string.gsub(path, "%?", modulepath)
    local file = io.open(filename, "rb")
    if file then
      -- Compile and return the module      print('here!')
      local string, tokens,output_string = process(assert(file:read("*a")),filename)
      return assert(my_loadstring(string, filename,tokens,output_string))
    end
    errmsg = errmsg.."\n\tno file '"..filename.."' (checked with custom loader)"
  end
  return errmsg
end
table.insert(package.loaders, 2, load)



local function scriptload(modulename)
  local errmsg = ""
  -- Find source
  local modulepath = string.gsub(modulename, "%.", "/")
  for path in string.gmatch(macro_path, "([^;]+)") do
    local filename = modulename
    local file = io.open(filename, "rb")
    if file then
      -- Compile and return the module      print('here!')
      local string, tokens,output_string = process(assert(file:read("*a")),filename)
      return assert(my_loadstring(string, filename,tokens,output_string))
    end
    errmsg = errmsg.."\n\tno file '"..filename.."' (checked with custom loader)"
  end
  return errmsg
end


macro_system = {
  add = add_macro,
  add_simple=add_simple_translate,
  load=load,
  scriptload=scriptload,
}

return macro_system