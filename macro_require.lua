--[[
debug.setmetatable(nil, {
    __index = function(t, i)
        return nil
    end
})
--]]
--[[Things to add
top level macros, or top parts to macro
bottom, export
other file
execute

macro phases?
inner info?
]]
tokenizer=require 'simple_tokenizer'
require 'class'

--forward references
local strip_tokens_from_list,apply_macros,add_macro,nullp,cdr,car,cadr,cddr,caddr,cdddr,macros,validate_params
local read_match_to,read_match_to_no_commas,sublist_to_list,concat_cons,scan_head_forward
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

tokenizer.add_special_token('#start')
tokenizer.add_special_token('#end')

tokenizer.add_special_token('#macro') --match {}
tokenizer.add_special_token('#if') 
tokenizer.add_special_token('#elseif') 
tokenizer.add_special_token('#else') 
tokenizer.add_special_token('#endif') 
tokenizer.add_special_token('#section') 
tokenizer.add_special_token('#fileout') 
tokenizer.add_special_token('#require') 
tokenizer.add_special_token('#define') 
tokenizer.add_special_token('#apply') 

--macros as first class at expand time
--[==[
 #macro{
  new_tokens={'WHILE','DO','END','BREAK','CONTINUE'},
  head='WHILE ?()...exp DO ?,...statements END',
  body=[[
  local function %loop() 
    if ?exp then
      #apply({{head='BREAK',body='return("__*done*__")'},
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


local function add_token_keys(t)
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
  ['#apply']='apply macros'
}

local function skip_one(l)
  if not nullp(l) then return cdr(l) end
  return l
end

local function skip_apply(l, store)
  l=cdr(l)
  if car(l).macro_token ~='(' then error '( expected after #apply ' end
  l=cdr(l)
  local ret
  local where_struct_goes = l
  if (store) then 
    if car(l).macro_token ~='{' or cadr(l).macro_token ~='{' then error( 'array of macros expected after #apply ( got: '..car(l).macro_token .." ".. cadr(l).macro_token) end
    local s,nl
    s,nl=read_match_to(l,',')
    if not s then error 'array of macros expected after #apply (' end
    if nullp(nl) or car(nl).macro_token ~=',' then error ', expected after #apply({macros...} ' end
    ret = strip_tokens_from_list(sublist_to_list( {l,nl},1 ))
    l=cdr(nl);
    --concat_cons(ret,' ');
   where_struct_goes[2]={}
   local temp_macros = loadstring('return('..concat_cons(ret,' ')..')')();
   for i = 1,#temp_macros do
     add_macro(temp_macros[i],where_struct_goes[2])
   end
   where_struct_goes[3]=l
  else
    l=cdr(l)
  end
  
  if nullp(l) or not macro_params[car(l).macro_token] then error ('parameter expected after #apply({macros...}, got '.. car(l).macro_token ..' instead') end
  l=cdr(l)
  if nullp(l) or car(l).type~='Id' then error ('Id expected after #apply({macros...}, got '.. car(l).macro_token..' type = "'.. tostring( car(l).type) ..'" instead') end
  l=cdr(l)
  if nullp(l) or car(l).macro_token ~=')' then error ') expected after #apply({macros...},?Id' end
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


nullp= function(l) return l==Nil end
local function listp(n) 
    return type(n)=='table' and 'Cons' ==  n[1]
end

local function pairp(n)
    return (not nullp(n)) and listp(n)
end

car=function(n)
  return n[2] 
end
cadr=function(n)
  return n[3][2] 
end
caddr=function(n)
  return n[3][3][2] 
end
cdddr=function(n)
  return n[3][3][3] 
end
cddr=function(n)
  return n[3][3] 
end
cdr= function(n)
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

local function reverse_transfer_one_in_place(dest,source)
  if not nullp(source) then 
    dest,source,source[3] = source,source[3],dest
  end
  return dest,source
end

local function reverse_list_in_place(l,concat)
  local d=concat or Nil
  while not nullp(l) do
    l,d,l[3]=l[3],l,d
  end
  return d
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

local function nthcar(n,l)
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

Nil = cons()
Nil[2]=Nil
Nil[3]=Nil
assert(Nil==Nil[2])


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

read_match_to = function(token_clist,end_token)
print('read match to "', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r).macro_token~=end_token do
    if match[car(r).macro_token] then
      local succ,inc
      print('found new match '..car(r).macro_token ..' to ' .. match[car(r).macro_token])
      succ,r,inc= read_match_to(cdr(r),match[car(r).macro_token])
      if not succ then 
        out('failed inner match')
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

read_match_to_no_commas= function(token_clist,end_token)
print('read match to no commas"', tostring(strip_tokens_from_list(token_clist)),'" to',end_token )  
  local r=token_clist
  local len=0
  while not nullp(r) and car(r).macro_token~=end_token and car(r).macro_token~=',' do
    if match[car(r).macro_token] then
      local succ,inc
      print('found new match '..car(r).macro_token ..' to ' .. match[car(r).macro_token])
      succ,r,inc= read_match_to(cdr(r),match[car(r).macro_token])
      if not succ then 
        out('failed inner match')
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


local function apply_inner_macros(macros_dest,params,params_info)
  
  local function replace_params(l)
	local d=cons(Nil,Nil)
	local r=d
	local p=Nil
	while not nullp(l) do
		if macro_params[car(l).macro_token] and params_info[cadr(l).macro_token].value then
			r[2]=params_info[cadr(l).macro_token].value
			l=cddr(l)
		else
			r[2]=car(l)
			l=cdr(l)
		end
		r[3]=cons(Nil,Nil)
		p=r
		r=r[3]
	end
	p[3]=Nil
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
    else
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
  print('handle == '..dest.handle,'handle offset == '..dest.handle_offset)
--you know what, there's no reason for a limit on how far forward a macro
--can match, it just means the rescan has to go that far.
--  scan_head_backward(dest.head)

  validate_params(dest.body)
  
  if params.sections then
    dest.sections={}
    for k,v in pairs(params.sections) do
      dest.sections[k]=replace_params(array_to_list(string_to_token_array(v)))
      validate_params(dest.sections[k])
    end
  end  
  
  table.insert(macros_dest,dest)
end

validate_params= function (head, is_head)
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
        if is_head then error '#apply can not appear in the head' end
    elseif is_param and (nullp(cdr(head)) or cadr(head).type ~= 'Id') then 
      error ("identifier missing after match specifier "..c.macro_token .." in head") 
    end
    local apply_struct
    if is_param then 
      local apply_struct
      head,apply_struct=skip_param_tokens[is_param](head,true)
      if apply_struct then 
        print('#apply on these macros:',apply_struct) 
      end
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
        error('macro must start with a constant token or constant preceded by single token params:'.. head) 
      end
    else
      return c.macro_token,i
    end
    if is_param then i=i+2 else i=i+1 end
  end
  error('macro must have a constant token:'.. head)
end

--[[Possibly params
new_tokens,
head (required)
semantic_function
body / (can be a function)
sections = {section_name (can be functions)...}}
macros_dest is optional
]]
add_macro= function (params, macros_dest)
  
  local dest = {}
  if not params.head then error  'macros have to have a head' end
  dest.head=array_to_list(string_to_token_array(params.head))
  if params.body then
    if type(params.body) == 'function'  then
      dest.body = params.body
    else
      dest.body=array_to_list(string_to_token_array(params.body or {}))
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
  print('handle == '..dest.handle,'handle offset == '..dest.handle_offset)
--you know what, there's no reason for a limit on how far forward a macro
--can match, it just means the rescan has to go that far.
--  scan_head_backward(dest.head)

  validate_params(dest.body)
  
  if params.sections then
    dest.sections={}
    for k,v in pairs(params.sections) do
      dest.sections[k]=array_to_list( string_to_token_array(v))
      validate_params(dest.sections[k])
    end
  end  
  add_tokens(dest.new_tokens)
  
  table.insert(macros_dest or macros,dest)
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
  local head=macro.head --array_to_list(macro.head)
  local c,pos=datac,head
  local param_info={} --type=, value=
  local match = function(match_fn)
      if nullp(caddr(pos)) then error "match until must have a token after it" end
      if macro_params[caddr(pos).macro_token] then error "match until must end with a constant token" end
      local succ, nc, inc = match_fn(c,caddr(pos).macro_token)
      if not succ then return false end
      out("match succeeded, inc =",inc)
      if param_info[cadr(pos).macro_token].value then -- prolog style equality matching
        if not (stripped_sublist_equal(param_info[cadr(pos).macro_token].value,{c,nc})) then
          out('reusing parameter match failed on', cadr(pos).macro_token )
          return false
        else 
          out(cadr(pos).macro_token, "= a previous match", sublist_to_stripped_string(param_info[cadr(pos).macro_token]))
        end
      else
        param_info[cadr(pos).macro_token].value = sublist_to_list({c,nc},1)
        if #(param_info[cadr(pos).macro_token].value) == 0 then
          out("empty parameter")
          return false
        end
        out(cadr(pos).macro_token,"set to",tostring(strip_tokens_from_list(param_info[cadr(pos).macro_token].value)))
      end
      c=nc
      pos=cdddr(pos)
      return true
    end
  
  while not nullp(pos) do --head
    if car(pos).macro_token==car(c).macro_token then
      pos=cdr(pos)
      c=cdr(c)
    elseif macro_params[car(pos).macro_token] then
      local param_type = macro_params[car(pos).macro_token]
      local param_name=cadr(pos).macro_token -- #apply doesn't appear in the head
      if not param_info[param_name] then 
        param_info[param_name]={type=param_type} 
      end
      -- Already checked that the next is an Id
      if param_type=='param' then
        if param_info[param_name].value then -- prolog style equality matching
          if param_info[param_name].value~=car(c).macro_token then 
            return false,datac 
          else 
            out(cadr(pos).macro_token, "= a previous match", car(c).macro_token)
          end
        else
          param_info[param_name].value=car(c)
          out(cadr(pos).macro_token,"set to",car(c).macro_token)
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
      elseif macro_params[car(pos).macro_token]=='param match until' then
        if not match(read_match_to_no_commas) then 
          return false,datac 
        end
      elseif macro_params[car(pos).macro_token]=='generate var' then 
        error "can't have a generate variable in a macro head"
      else --unused so far
      end
      c=cdr(c)
    else
      return false,datac
    end
  end
  local do_body= function (body)
    local dest={} --splices c on after  
    local bi=body 
    print("Scanning Body", strip_tokens_from_list( body))
    while not nullp(bi) do
   --   if not bi or not body or not body[bi] or not body[bi].macro_token then
   --     print 'breakpoint'
   --   end
      local param_type_text=macro_params[car(bi).macro_token]
      local param_type=nil
        if param_type_text=='apply macros' then
          local inner_macros,p
          bi,inner_macros,p= skip_param_tokens[param_type_text](bi)
          print('++++++++++++++++++++++++++++', inner_macros)
          local temp={}
          for i=1,#inner_macros do
            apply_inner_macros(temp,inner_macros[i],param_info)
          end
          temp=apply_macros(temp,param_info[p.macro_token].value)
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
              error "body contains a parameter that isn't in the head"
            end
            
            param_type = param_info[car(bi).macro_token].type
            print('param type = '..param_type)
          end
      --    if param_type_text=='generate var'
          
          if not param_type_text then
            table.insert(dest,car(bi))
      --      dest=cons(body[bi],dest)
            out('>>',car(bi).macro_token)
          elseif not param_type then 
             error(' unmatched parameter '..car(bi).macro_token) 
          elseif param_type=='param' then
            table.insert(dest,param_info[car(bi).macro_token].value)
      --      dest=cons(param_info[body[bi].macro_token].value,dest)
            out('>>',param_info[car(bi).macro_token].value)
          elseif param_type=='param until' 
          or param_type=='param match until' 
          or param_type=='params' then
            dest=append_list_to_array(dest,param_info[car(bi).macro_token].value)
            print('>>',param_info[car(bi).macro_token].value)
          elseif param_type=='generate var' then 
            if not param_info[car(bi).macro_token].value then
              gen_var_counter=gen_var_counter+1
              param_info[car(bi).macro_token].value = { macro_token= '__GENVAR_'.. tostring(gen_var_counter) ..'__', type='Id'}
              out('generating variable',car(bi).macro_token, 'as',param_info[car(bi).macro_token].value )
            end
      --      dest=cons(param_info[body[bi].macro_token].value,dest)
             table.insert(dest,param_info[car(bi).macro_token].value)
             out('>>',param_info[car(bi).macro_token].value)
          else --unused so far
          end
          bi=cdr(bi)
        end --~= apply macro
    end --while
    return true,c,array_to_list(dest,c)
  end --function do_body
  if macro.sections then --{}{}{} ignore sections for now
  end
  if macro.semantic_function then
    local sem_return = macro.semantic_function(param_info,c)
      if not sem_return then return false,datac end
      if sem_return~=true then return true,sem_return end
  end
  if macro.body then
    if type(macro.body) == 'function' then
      local body_ret = macro.body(param_info,c)
      if body_ret then return true,body_ret end
      return false,datac 
    else
      return do_body(macro.body)
    end
  end     
end

apply_macros = function(macros, list)
  local flatten=reverse_list(list)
  
  local dest = Nil
  while not nullp(flatten) do
    dest,flatten = reverse_transfer_one_in_place(dest,flatten)
--    dest = cons(car(flatten),dest)
--    flatten=cdr(flatten)
    local done
    repeat 
      done = true
      for i,v in ipairs(macros) do
        local processed,start
        --{}{}{} start isn't in dest because I reversed the list after adding start
        --a bit of optimization
        --if I can table drive this more it could be more optimized, but
        --how to maintain macro order then?
        if v.handle == nthcar(v.handle_offset,dest).macro_token then 
          processed,dest,start=macro_match(dest,v)
          if processed then 
            done = false
            --set rescan back by the whole macro
            --is it possible that it sets up less than a whole macro?  
            --rescan from the end of the new substitution
            while start~=dest do
              flatten, start = reverse_transfer_one_in_place(flatten,start)
--              flatten=cons(car(start),flatten)
--              start=cdr(start)
            end
          end
        end
      end
    until done
  end
  return dest
end

local function process(str)
  local source_array = string_to_source_array(str)
  
  local prev_line=-1
  local line = {}
  for i=1,#source_array do
    if source_array[i].token.y ~= prev_line then
      if #line~=0 then 
        print('**'..table.concat(line,' ')..'**')
        line={}
        prev_line = source_array[i].token.y
      end
    end
    table.insert(line,source_array[i].macro_token)
  end
  if #line~=0 then 
    print('**'..table.concat(line,' ')..'**')
    line={}
  end
  
--{}{}{}  
  local dest= apply_macros(macros,array_to_list( source_array))
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