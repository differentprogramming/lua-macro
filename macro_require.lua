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

local function string_to_token_array(str)
  local error_pos, source, meaningful =tokenizer.tokenize_all(str)
  if not error_pos then
    local flatten={}
    for a = 1,#meaningful do 
      table.insert(flatten, simple_translate[source[meaningful[a]].value]) 
    end 
    return flatten
  end
end

local macro_params={
  --input paramsk
  ['%1']='param',
  ['%2']='param',
  ['%3']='param',
  ['%4']='param',
  ['%5']='param',
  ['%6']='param',
  ['%7']='param',
  ['%8']='param',
  ['%9']='param',
  ['%10']='param',
  --input matches till
  ['%a...']='param until',
  ['%b...']='param until',
  ['%c...']='param until',
  ['%d...']='param until',
  ['%e...']='param until',
  ['%f...']='param until',
  ['%g...']='param until',
  ['%h...']='param until',
  ['%i...']='param until',
  ['%j...']='param until',
  --input matches till next, also matches () {} [] - stops for comma
  --if the expected next is a comma then that matches
  --if the expected next is not a comma and it finds one, that's a failure
  ['%A()...']='param match until',
  ['%B()...']='param match until',
  ['%C()...']='param match until',
  ['%D()...']='param match until',
  ['%E()...']='param match until',
  ['%F()...']='param match until',
  ['%G()...']='param match until',
  ['%H()...']='param match until',
  ['%I()...']='param match until',
  ['%J()...']='param match until',
  --in matches any number of elements including commas
  ['%A,...']='params',
  ['%B,...']='params',
  ['%C,...']='params',
  ['%D,...']='params',
  ['%E,...']='params',
  ['%F,...']='params',
  ['%G,...']='params',
  ['%H,...']='params',
  ['%I,...']='params',
  ['%J,...']='params',
  --generate var
  ['%g1']='generate var',
  ['%g2']='generate var',
  ['%g3']='generate var',
  ['%g4']='generate var',
  ['%g5']='generate var',
  ['%g6']='generate var',
  ['%g7']='generate var',
  ['%g8']='generate var',
  ['%g9']='generate var',
  ['%g10']='generate var',
  ['%g11']='generate var',
  ['%g12']='generate var',
  ['%g13']='generate var',
  ['%g14']='generate var',
  ['%g15']='generate var',
  ['%g16']='generate var',
  ['%g17']='generate var',
  ['%g18']='generate var',
  ['%g19']='generate var',
  ['%g20']='generate var',
  ['%g21']='generate var',
  ['%g22']='generate var',
  ['%g23']='generate var',
  ['%g24']='generate var',
  ['%g25']='generate var',
  ['%g26']='generate var',
  ['%g27']='generate var',
  ['%g28']='generate var',
  ['%g29']='generate var',
  ['%g30']='generate var',
}



add_token_keys(macro_params)

local match=
{
  ['(']=')',
  ['{']='}',
  ['[']=']',
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

local function read_to(token_clist,end_token)
print('read to "', tostring(token_clist),'" to',end_token )  
  local len =0;
  local r=token_clist
  while not nullp(r) and car(r)~=end_token do
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
print('read match to "', tostring(token_clist),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r)~=end_token do
    if match[car(r)] then
      local succ,inc
      succ,r,inc= read_match_to(cdr(r),match[car(r)])
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
print('read match to "', tostring(token_clist),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r)~=end_token and car(r)~=',' do
    if match[car(r)] then
      local succ,inc
      succ,r,inc= read_match_to(cdr(r),match[car(r)])
      if not succ then 
        out('failed')
        return false,token_clist,0 
      end
      len=len+inc+1
    end
    r=cdr(r)
    len=len+1
  end
  if car(r)==end_token then 
    out('succeeded')
    return true,r,len 
  end
  out('failed')
  return false,token_clist,0
end

local function sublist_end(a,p)
  return p==a[2]
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
local function sublist_to_string(s)
  return tostring(sublist_to_list(s))
end

local macros=
{
    {{'&'},
      '&(%a...,%B()...)', 
      [[
        for %g1 in %a... do
          if %g1~=nil then 
            for %g2 in %B()... do
              if %g2~=nil then y@(%g1,%g2)
              end
            end
          end
        end
      ]]},
    {{'|'},
      '|(%A()...,%B()...)', 
      [[
        for %g1 in %A()... do
          Y@(%g1)
        end
        for %g1 in %B()... do
          Y@(%g1)
        end
      ]]}
      
}

local function scan_head_forward(head)
  for i=1,#head do
    if macro_params[head[i]] then
      if macro_params[head[i]]~= 'param' then 
        error('macro must start with a constant token or constant preceded by single token params:'.. head) 
      end
    else
      return true
    end
  end
  error('macro must have a constant token:'.. head)
end
local function scan_head_backward(head)
  for i=#head,1,-1 do
    if macro_params[head[i]] then
      if macro_params[head[i]]~= 'param' then 
        error('macro must end with a constant token or constant preceded by single token params:'.. head) 
      end
    else
      return true
    end
  end
  error('macro must have a constant token:'.. head)
end
local function add_macro(newtokens, head, body)
  scan_head_forward(head)
  scan_head_backward(head)
  add_tokens(newtokens)
  table.insert(macros,{newtokens,
                      string_to_token_array(head),
                      string_to_token_array(body)
                      })
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
  local match = function(match_fn,param_buffer)
      if macro_params[head[hpos+1]] then error "match until must end with a constant token" end
      if not head[hpos+1] then error "match until must have a token after it" end
      local succ, nc, inc = match_fn(c,head[hpos+1])
      if not succ then return false end
      out("match succeeded, inc =",inc)
      if param_buffer[head[hpos]] then -- prolog style equality matching
        if not (sublist_equal(param_buffer[head[hpos]],{c,nc})) then
          out('reusing parameter match failed on', head[hpos] )
          return false
        else 
          out(head[hpos], "= a previous match", sublist_to_string(param_buffer[head[hpos]]))
        end
      else
        param_buffer[head[hpos]]= sublist_to_list({c,nc},1)
        if #(param_buffer[head[hpos]]) == 0 then
          out("empty parameter")
          return false
        end
        out(head[hpos],"set to",tostring(param_buffer[head[hpos]]))
      end
      c=nc
      hpos=hpos+2
      return true
    end
  local param={}
  local params={}
  local param_until={}
  local param_match_until={}
  local generate_var={}
  
  while head[hpos] do --head
    if head[hpos]==car(c) then
      hpos=hpos+1
      c=cdr(c)
    elseif macro_params[head[hpos]] then
      if macro_params[head[hpos]]=='param' then
        if param[head[hpos]] then -- prolog style equality matching
          if param[head[hpos]]~=car(c) then 
            return false,datac 
          else 
            out(head[hpos], "= a previous match", car(c))
          end
        else
          param[head[hpos]]=car(c)
          hpos=hpos+1
          out(head[hpos],"set to",car(c))
        end
      elseif macro_params[head[hpos]]=='param until' then
        if not match(read_to,param_until) then 
          return false,datac 
        end
      elseif macro_params[head[hpos]]=='params' then
        if not match(read_match_to,params) then 
          return false,datac 
        end
      elseif macro_params[head[hpos]]=='param match until' then
        if not match(read_match_to_no_commas,param_match_until) then 
          return false,datac 
        end
      else --read_match_to_no_commas
        error "can't have a generate variable in a macro head"
      end
      c=cdr(c)
    else
      return false,datac
    end
  end
  local dest=c --splices right on !! 
  for bi=#body,1,-1 do
    if not macro_params[body[bi]] then
      dest=cons(body[bi],dest)
      out('>>',body[bi])
    elseif macro_params[body[bi]]=='param' then
      if not param[ body[bi] ] then error(' unmatched parameter '..body[bi]) end
      dest=cons(param[ body[bi] ],dest)
      out('>>',param[body[bi]])
    elseif macro_params[body[bi]]=='param until' then
      if not param_until[ body[bi] ] then error (' unmatched parameter '..body[bi]) end
      dest=list_append(param_until[ body[bi] ],dest)
      print('>>',param_until[body[bi]])
    elseif macro_params[body[bi]]=='param match until' then
      if not param_match_until[ body[bi] ] then error (' unmatched parameter '..body[bi]) end
      dest=list_append(param_match_until[ body[bi] ],dest)
      print('>>',param_match_until[body[bi]])
    elseif macro_params[body[bi]]=='params' then
      if not params[ body[bi] ] then error (' unmatched parameter '..body[bi]) end
      dest=list_append(params[ body[bi] ],dest)
      print('>>',params[body[bi]])
    else --assume 'generate var'
      if not generate_var[ body[bi] ] then
        gen_var_counter=gen_var_counter+1
        generate_var[ body[bi] ] = '__GENVAR_'.. tostring(gen_var_counter) ..'__'
        out('generating variable',body[bi], 'as',generate_var[ body[bi] ] )
      end
      dest=cons(generate_var[ body[bi] ],dest)
       out('>>',generate_var[body[bi]])
    end
  end
  return true,c,dest
end

local function process(str)
  local flatten=array_to_reversed_list(string_to_token_array(str))
  local dest = Nil
  while not nullp(flatten) do
    dest = cons(car(flatten),dest)
    flatten=cdr(flatten)
    local done
    repeat 
      done = true
      for i,v in ipairs(macros) do
        local processed,start
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
  print(dest)
  return concat_cons(dest,' ')
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