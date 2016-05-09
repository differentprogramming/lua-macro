--joyish
local function_prototype = {
  ['type']='function'
}

local number_prototype = {
  as_number=function(self) return self[1] end,
  ['type']='number'
}

local number_metatable = {__tostring=function (self) return tostring(self[1]) end,
      __call= function(self,...) return self,... end,
      __index = number_prototype,
    }

@section 'define'

local function array_copy(obj)
  if type(obj) ~= 'table' then return obj end
  local copy={}
  for i,v in ipairs(obj) do copy[i]=v end
  return setmetatable(copy,getmetatable(obj))
end


define number(a,...)
  return setmetatable({a},number_metatable),...
end

local list_prototype = {
  type='list'
  }

local function list_call_u(pos,self,...)
  if pos<= #self then
    return list_call_u(pos+1,self,self[pos](...))
  else
    return ...
  end
end

local list_metatable = {__tostring=function (self)
    local temp={'['}
    for _,v in ipairs(self) do table.insert(temp,tostring(v)) end
    table.insert(temp,']')
    return tostring(table.concat(temp,' ')) 
  end,
  __call= function(self,...) 
    return list_call_u(1,self,...)
  end,
  __index = list_prototype,
}

define list(a,...)
  return setmetatable(a,list_metatable),...
end


@macro { 
  new_tokens={'define'}, 
  head= [[define ?1fn ( ??,params ) ??,code end]],
  body = [[?fn = function(?params) ?code end]],
  sections= { 
    define=[[local ?fn ;]],
    module=[[?fn = ?fn ,]],
    export = '..@tostring(local ?fn = joy_module.?fn;)'
    } 
  }

@macro { head='fn ?1fn (?,params) ??,statements end',
  body= [[?fn = setmetatable({},?fn @@ _metatable)]],
  sections = { 
    define = [[local ?fn; local ?fn @@ _metatable = {
  __index = function_prototype,
  __tostring= function(self) return @tostring(?fn) end,
  __call = function(self,?params) print(tostring(self)); ?statements end,
  }]],
    module = "?fn = ?fn,",
    export = '..@tostring(local ?fn = joy_module.?fn;)'
    },
  }

fn concat(a,b,...)
  for _,v in ipairs(a) do table.insert(b,v) end
  return b,...
end

fn dup(a,...) 
  if a.type == 'list' then
    return array_copy(a), a, ...
  end
  return a,a,...
end

fn cons(obj, l,...)
  table.insert(l,obj)
  return l, ...
end

fn doit(a,...)
  return a(...)
end

fn map(func, l,...)
  local t=list({})
  for _,v in ipairs(l) do
    cons(doit(func,v),t)
  end
  return t,...
end

fn swap(a,b,...) 
  return b,a,...
end

fn add(a,b,...) 
  return number(a:as_number()+b:as_number()),...
end

fn mul(a,b,...) 
  return number(a:as_number()*b:as_number()),...
end

define joy(a,...)
  if a==nil then return end
  if type(a) == 'number' then return number(a), joy(...) end
  if type(a) == 'table' then 
    if a.type == nil then
      local t=list({})
      for i=1,#a do table.insert(t,joy(a[i])) end
      return t,joy(...)
    end
  end
  return a,joy(...)
end

joy_module = {
  @section 'module'
}


macro_system.add { head="import_joy",
  body= ''
@section 'export'
}

return joy_module
