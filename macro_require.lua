tokenizer=require 'simple_tokenizer'
require 'class'
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

local function add_token_keys(t)
  for k,_ in pairs(t) do
    tokenizer.add_special_token(k)
  end
end
local function add_tokens(t)
  for _,v in ipairs(t) do
    tokenizer.add_special_token(v)
  end
end

add_token_keys(simple_translate)

local function no_source_token(t)
  return {macro_token=t}
end

local function string_to_source_array(str)
  local error_pos, source, meaningful =tokenizer.tokenize_all(str)
  if not error_pos then
    local flatten={}
    for a = 1,#meaningful do 
      table.insert(flatten, {macro_token=simple_translate[source[meaningful[a]].value],type=source[meaningful[a]].type,token=source[meaningful[a]]}) 
    end 
    return flatten
  end
end

local function string_to_token_array(str)
  local error_pos, source, meaningful =tokenizer.tokenize_all(str)
  if not error_pos then
    local flatten={}
    for a = 1,#meaningful do 
      table.insert(flatten, {macro_token=simple_translate[source[meaningful[a]].value], type = source[meaningful[a]].type}) 
    end 
    return flatten
  end
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
  ['?']='param',
  --input matches till
  ['?...']='param until',
  --input matches till next, also matches () {} [] - stops for comma
  --if the expected next is a comma then that matches
  --if the expected next is not a comma and it finds one, that's a failure
  ['?()...']='param match until',
  --in matches any number of elements including commas
  ['?,...']='params',
  --generate var
  ['%']='generate var',
--  ['%external-load:']='global load', -- also need a 4th entry for saving
}



add_token_keys(macro_params)

local match=
{
  ['(']=')',
  ['{']='}',
  ['[']=']',
  ['do']='end',
  ['for']='do',
  ['while']='do',
  ['if']='end',
  ['function']='end',
  ['repeat']='until',
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
  

local cons_tostring

local Nil;
--[[
so here, car is [2]
cdr is [3]
--]]


local function nullp(l) return l==Nil end
local function listp(n) 
    return type(n)=='table' and 'Cons' ==  n[1]
end

local function pairp(n)
    return (not nullp(n)) and listp(n)
end

local function car(n)
  return n[2] 
end
local function cdr(n)
  return n[3] 
end

local function cons(first, rest)
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


local function reverse_list(l,concat)
  print 'enter reverse list'
  local d=concat or Nil
  while not nullp(l) do
    d=cons(l[2],d)
    l=l[3]
  end
  print 'exit reverse list'
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
  
local function concat_cons(l,v)
  dest = {}
  while not nullp(l) do table.insert(dest,l[2]) l=l[3] end
  return table.concat(dest,v)
end

Nil = cons()
Nil[2]=Nil
Nil[3]=Nil
assert(Nil==Nil[2])

--forward reference
local strip_tokens_from_list 

local function read_to(token_clist,end_token)
print('read to "', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local len =0;
  local r=token_clist
  while not nullp(r) and car(r).macro_token~=end_token do
    r=cdr(r)
    len=len+1
  end
  if car(r) then 
    out('succeeded')
    return true,r,len 
  end
  out('failed')
  return false,token_clist,0
end

local function read_match_to(token_clist,end_token)
print('read match to "', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r).macro_token~=end_token do
    if match[car(r)] then
      local succ,inc
      succ,r,inc= read_match_to(cdr(r),match[car(r).macro_token])
      if not succ then 
        out('failed')
        return false,token_clist,0 
      end
      len=len+inc+1
    end
    r=cdr(r)
    len=len+1
  end
  if car(r) then 
    out('succeeded')
    return true,r,len 
  end
  out('failed')
  return false,token_clist,0
end

local function read_match_to_no_commas(token_clist,end_token)
print('read match to "', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r).macro_token~=end_token and car(r).macro_token~=',' do
    if match[car(r).macro_token] then
      local succ,inc
      succ,r,inc= read_match_to(cdr(r),match[car(r).macro_token])
      if not succ then 
        out('failed')
        return false,token_clist,0 
      end
      len=len+inc+1
    end
    r=cdr(r)
    len=len+1
  end
  if car(r).macro_token==end_token then 
    out('succeeded')
    return true,r,len 
  end
  out('failed')
  return false,token_clist,0
end

local function sublist_end(a,p)
  return p==a[2]
end

local function list_append_to_reverse(r,e)
  print "enter list_append_to_reverse"
  while not nullp(e) do
    r=cons(car(e),r)
    e=cdr(e)
  end
  print "leave list_append_to_reverse"
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

local function sublist_to_list(s,endoff)
  return array_to_list(sublist_to_array(s,endoff))
end

strip_tokens_from_list= function(l)
  print 'enter strip_tokens_from_list'
  local d={}
  while not nullp(l) do
    table.insert(d,car(l).macro_token)
    l=cdr(l)
  end
  print 'exit strip_tokens_from_list'
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

local macros=
{      
}

local function validate_params(head)
  local i=1
  while i<=#head do
    local is_param = macro_params[head[i].macro_token]
    if is_param and (i==#head or head[i+1].type ~= 'Id') then 
      error ("identifier missing after match specifier in head") 
    end
    if is_param then i=i+2 else i=i+1 end
  end
  
end

local function scan_head_forward(head)
  local i=1
  while i<=#head do
    local is_param = macro_params[head[i].macro_token]
    if is_param then
      if is_param~= 'param' then 
        error('macro must start with a constant token or constant preceded by single token params:'.. head) 
      end
    else
      return true
    end
    if is_param then i=i+2 else i=i+1 end
  end
  error('macro must have a constant token:'.. head)
end
local function scan_head_backward(head)
  local i = #head
  while i>=1 do
    local is_param;
    if i>1 then is_param = macro_params[head[i-1].macro_token] else is_param=false end 
    if is_param then
      if is_param~= 'param' then 
        error('macro must end with a constant token or constant preceded by single token params:'.. head) 
      end
    else
      return true
    end
    if is_param then i=i-2 else i=i-1 end
  end
  error('macro must have a constant token:'.. head)
end
local function add_macro(newtokens, head, body)
  head=string_to_token_array(head)
  body=string_to_token_array(body)

  validate_params(head)
  scan_head_forward(head)
  scan_head_backward(head)
  validate_params(body)
  add_tokens(newtokens)
  table.insert(macros,{newtokens,head,body})
end


local function add_simple_translate(m,t)
  simple_translate[m]=t
end


for i,v in ipairs(macros) do
  add_tokens(v[1])
  v[2]=string_to_token_array(v[2])
  v[3]=string_to_token_array(v[3])
end

--        processed,new_pos=macro_match(flatten,pos,v)
-- needs to return a sublist
local function macro_match(datac,macro)
  local head,body=macro[2],macro[3]
  local c,hpos=datac,1
  local param_info={} --type=, value=
  local match = function(match_fn)
      if not head[hpos+2] then error "match until must have a token after it" end
      if macro_params[head[hpos+2].macro_token] then error "match until must end with a constant token" end
      local succ, nc, inc = match_fn(c,head[hpos+2].macro_token)
      if not succ then return false end
      out("match succeeded, inc =",inc)
      if param_info[head[hpos+1].macro_token].value then -- prolog style equality matching
        if not (stripped_sublist_equal(param_info[head[hpos+1].macro_token].value,{c,nc})) then
          out('reusing parameter match failed on', head[hpos+1].macro_token )
          return false
        else 
          out(head[hpos+1].macro_token, "= a previous match", sublist_to_stripped_string(param_info[head[hpos+1].macro_token]))
        end
      else
        param_info[head[hpos+1].macro_token].value = sublist_to_list({c,nc},1)
        if #(param_info[head[hpos+1].macro_token].value) == 0 then
          out("empty parameter")
          return false
        end
        out(head[hpos+1].macro_token,"set to",tostring(strip_tokens_from_list(param_info[head[hpos+1].macro_token].value)))
      end
      c=nc
      hpos=hpos+3
      return true
    end
  
  while head[hpos] do --head
    if head[hpos].macro_token==car(c).macro_token then
      hpos=hpos+1
      c=cdr(c)
    elseif macro_params[head[hpos].macro_token] then
      local param_type = macro_params[head[hpos].macro_token]
      local param_name=head[hpos+1].macro_token
      if not param_info[param_name] then 
        param_info[param_name]={type=param_type} 
      end
      -- Already checked that the next is an Id
      if param_type=='param' then
        if param_info[param_name].value then -- prolog style equality matching
          if param_info[param_name].value~=car(c).macro_token then 
            return false,datac 
          else 
            out(head[hpos+1].macro_token, "= a previous match", car(c).macro_token)
          end
        else
          param_info[param_name].value=car(c)
          out(head[hpos+1].macro_token,"set to",car(c).macro_token)
        end
        hpos=hpos+2
      elseif macro_params[head[hpos].macro_token]=='param until' then
        if not match(read_to) then 
          return false,datac 
        end
      elseif macro_params[head[hpos].macro_token]=='params' then
        if not match(read_match_to) then 
          return false,datac 
        end
      elseif macro_params[head[hpos].macro_token]=='param match until' then
        if not match(read_match_to_no_commas) then 
          return false,datac 
        end
      elseif macro_params[head[hpos].macro_token]=='generate var' then 
        error "can't have a generate variable in a macro head"
      else --unused so far
      end
      c=cdr(c)
    else
      return false,datac
    end
  end
  local dest={} --splices c on after  
  local bi=1 
  while bi<=#body do
 --   if not bi or not body or not body[bi] or not body[bi].macro_token then
 --     print 'breakpoint'
 --   end
    local param_type_text=macro_params[body[bi].macro_token]
    local param_type=nil
    if param_type_text then 
      bi=bi+1
      if param_type_text=='generate var' then
        if not param_info[body[bi].macro_token] then 
          param_info[body[bi].macro_token]={type='generate var'}
        end
      end
      if not param_info[body[bi].macro_token] then
        error "body contains a parameter that isn't in the head"
      end
      
      param_type = param_info[body[bi].macro_token].type
      print('param type = '..param_type)
    end
--    if param_type_text=='generate var'
    
    if not param_type_text then
      table.insert(dest,body[bi])
--      dest=cons(body[bi],dest)
      out('>>',body[bi].macro_token)
    elseif not param_type then 
       error(' unmatched parameter '..body[bi].macro_token) 
    elseif param_type=='param' then
      table.insert(dest,param_info[body[bi].macro_token].value)
--      dest=cons(param_info[body[bi].macro_token].value,dest)
      out('>>',param_info[body[bi].macro_token].value)
    elseif param_type=='param until' 
    or param_type=='param match until' 
    or param_type=='params' then
      dest=append_list_to_array(dest,param_info[body[bi].macro_token].value)
      print('>>',param_info[body[bi].macro_token].value)
    elseif param_type=='generate var' then 
      if not param_info[body[bi].macro_token].value then
        gen_var_counter=gen_var_counter+1
        param_info[body[bi].macro_token].value = { macro_token= '__GENVAR_'.. tostring(gen_var_counter) ..'__', type='Id'}
        out('generating variable',body[bi].macro_token, 'as',param_info[body[bi].macro_token].value )
      end
--      dest=cons(param_info[body[bi].macro_token].value,dest)
       table.insert(dest,param_info[body[bi].macro_token].value)
       out('>>',param_info[body[bi].macro_token].value)
    else --unused so far
    end
    bi=bi+1
  end
  return true,c,array_to_list(dest,c)
end

local function process(str)
  local flatten=array_to_reversed_list(string_to_source_array(str))
  local dest = Nil
  while not nullp(flatten) do
    dest = cons(car(flatten),dest)
    flatten=cdr(flatten)
    local done
    repeat 
      done = true
      for i,v in ipairs(macros) do
        local processed,start
        --{}{}{} start isn't in dest because I reversed the list after adding start
        processed,dest,start=macro_match(dest,v)
        if processed then 
          done = false
          --set rescan back by the whole macro
          --is it possible that it sets up less than a whole macro?  
          while start~=dest do
            flatten=cons(car(start),flatten)
            start=cdr(start)
          end
        end
      end
    until done
  end
  local ret=concat_cons(strip_tokens_from_list(dest),' ')
  print(strip_tokens_from_list( dest))
  return ret
end

local macro_path = string.gsub(package.path,'%.lua','.pp.lua')

local function load(modulename)
  local errmsg = ""
  -- Find source
  local modulepath = string.gsub(modulename, "%.", "/")
  for path in string.gmatch(macro_path, "([^;]+)") do
    local filename = string.gsub(path, "%?", modulepath)
    local file = io.open(filename, "rb")
    if file then
      -- Compile and return the module      print('here!')
      return assert(loadstring(process(assert(file:read("*a"))), filename))
    end
    errmsg = errmsg.."\n\tno file '"..filename.."' (checked with custom loader)"
  end
  return errmsg
end

-- Install the loader so that it's callled just before the normal Lua loader
table.insert(package.loaders, 2, load)

return {
  add = add_macro,
  add_simple=add_simple_translate,
  }