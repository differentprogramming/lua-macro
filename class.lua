DONT_INHERIT_META = 'DONT_INHERIT_META'
-- BUG needs to handle recursive structures !!!
-- deal with how to print classes later.
-- hmm I should build a browser in wxwidgets later
-- I need to add iterators, since pairs and ipairs don't work with 
-- inheritance

-- I can make an actual copy-on-write type can't I?
-- Objects that support :become could be done with a proxy

-- note, classes/prototypes are default copied and default deep_copied
-- if I want them to have custom copiers then I would need to have a different name for the copy
-- methods or I would need metaclasses
local function copy_table_items(obj)
  if type(obj)~='table' then return obj end
  local copy={}
  for i,v in pairs(obj) do copy[i]=v end
  return copy
end
_G.copy_table_items = copy_table_items

local function simple_copy(obj)
  local copy={}
  for i,v in pairs(obj) do copy[i]=v end
  return setmetatable(copy,getmetatable(obj))
end
_G.simple_copy = simple_copy

local function metacopy(obj)
  if type(obj)=='table' then 
    return setmetatable({},{__index=obj})
  end
  return obj
end
_G.metacopy=metacopy

--note, replacing deep copy with a metacopy implies that 
--the original won't change for the life of the copy
local function deep_copy_by_metacopy(obj,twisel)
  if twisel==nil then twisel={}
  elseif twisel[obj] then return twisel[obj],twisel 
  end
  
  local copy=setmetatable({},{__index=obj})
  twisel[obj]=copy
  
  return copy,twisel
end
_G.deep_copy_by_metacopy=deep_copy_by_metacopy

local function deep_copy_by_simple_copy(obj,twisel)
  if twisel==nil then twisel={}
  elseif twisel[obj] then return twisel[obj],twisel 
  end
  local copy={} 
  twisel[obj]=copy
  for i,v in pairs(obj) do copy[i]=v end
  
  return setmetatable(copy,getmetatable(obj)),twisel
end

_G.deep_copy_by_simple_copy=deep_copy_by_simple_copy

--??? is it right to add metacopies to the twisel that it returned up
--a level?  Do metacopies need to kept separate?
local function deep_copy_by_1_level_metacopy(obj,twisel)
  if twisel==nil then twisel={}
  elseif twisel[obj] then return twisel[obj],twisel 
  end
  local copy={} 
  twisel[obj]=copy
  for i,v in pairs(obj) do 
    if type(v)=='table' then copy[i]=deep_copy_by_metacopy(v,twisel) 
    else copy[i]=v end
  end
  
  return setmetatable(copy,getmetatable(obj)),twisel
end

_G.deep_copy_by_1_level_metacopy=deep_copy_by_1_level_metacopy

-- for non-class types returns the same as type
-- for objects returns the class name
--for classes returns something like "Cons class" instead of what the object would return "Cons" 
local function class_of(obj)
    local c=type(obj)
    if c=='table' and obj.class_name then
        return rawget(obj,'class_class_name') or obj.class_name 
    end
    return c
end
_G.class_of=class_of

local function is_class(obj)
    if type(obj)~='table' then return false end 
    if rawget(obj,'class_name') then return true end
    return false
end
_G.is_class=is_class

local function is_object(obj)
    if type(obj)~='table' then return false end 
    if rawget(obj,'class_name') then return false end
    return obj.class_name ~= nil 
end
_G.is_object=is_object

local function is_simple_table(obj)
    return type(obj)=='table' and obj.class_name == nil
end
_G.is_simple_table=is_simple_table

--simple copies classes, since the copy: function isn't meant for them
local function copy(something)
  if type(something)=='table' then 
    if something.class_name ~= nil and not rawget(something,'class_name') then return something:copy() 
    else return simple_copy(something) 
    end
  else return something
  end
end
_G.copy=copy

local deep_copy;
--note simple_deep_copy is a method for an object, it also works on tables
--but deep_copy is the version meant to be called on any object or value
local function simple_deep_copy(obj,twisel)
  if not twisel then twisel = {} 
  elseif twisel[obj] then return twisel[obj],twisel end
  
  local copy={}
  twisel[obj]=copy
  for i,v in pairs(obj) do copy[i]=deep_copy(v,twisel) end
  return setmetatable(copy,getmetatable(obj)),twisel
end

_G.simple_deep_copy = simple_deep_copy
-- classes are default copied.
deep_copy = function(object, twisel)
  if not twisel then twisel = {} 
  elseif twisel[object] then return twisel[object], twisel 
  end
  
  if type(object)=='table' then 
    if object.class_name ~= nil and not rawget(object,'class_name') then return object:deep_copy(twisel) 
    else 
      local copy={}
      twisel[object]=copy
      for i,v in pairs(object) do copy[i]=deep_copy(v,twisel) end
      return setmetatable(copy,getmetatable(object)),twisel
    end
  end
  return object,twisel
end
_G.deep_copy = deep_copy
    
local deep_to_string
deep_to_stringu = function(object, twisel, dest1)
  dest1=dest1 or {}
  if not twisel then 
    twisel = {} 
  elseif twisel[object] then 
    dest1[twisel[object]]='@'.. twisel[object] .. ', '
      table.insert(dest1,', ')
      table.insert(dest1,'ref to ' .. twisel[object] ..' ')
      return dest1
    
  end
  
  if type(object)=='table' then 
    if object.class_name ~= nil and not rawget(object,'class_name') then 
      table.insert(dest1,', ')
      twisel[object]=#dest1
      table.insert(dest1,to_string(object))
      return dest1
    else 
      twisel[object]=#dest1+1
      table.insert(dest1,', ')
      table.insert(dest1,'{')
      local prevk=0
      for k,v in pairs(object) 
      do 
        if type(k) ~= 'number' or k ~= prevk+1 then
          dest1[#dest1]=dest1[#dest1].."['"..deep_to_string(k).."]'= "
        end
        if type(k) == 'number' then prevk=k end
        deep_to_stringu(v,twisel,dest1) 
      end
      table.insert(dest1,', ')
      table.insert(dest1,'}')
      return dest1
    end
  end
  
  table.insert(dest1,', ')
  twisel[object]=#dest1
  table.insert(dest1,to_string(object))
  return dest1
end
function deep_to_string(o) return table.concat(deep_to_stringu(o),'') end
_G.deep_to_string = deep_to_string

-- to consistently deep copy a group of objects either put them on one table, or save the second returned value
-- and feed it to the subsequent deep_copy calls.
-- I may find problems because of the prototype based class system, it's not ideal to functional programming
-- if you ever change a prototype, then even deep copies are changed.  For it to work with copying then 
-- protypes have to be immutable, but that means that some things that were easy to do with class based 
-- systems become harder.  However classes are copiable, if not custom copiable, and same with deep copying.
-- So prototypes can be copied after they become prototypes.


local function object_to_string(n,sep, r)
        local pos = 1
        local between =""
        local str=(n.class_name or "") .. "{ "
        for i,v in pairs(n) do
            str = str ..  between
            between = sep or ", "
            if i==pos then
                str=str .. to_string(v, r and sep, r) 
            elseif type(i)=='number' and pos<i and i-pos<10 then
                for j=pos,i-1 do str = str .. 'nil' .. (sep or ", ") end
                str=str .. to_string(v, r and sep, r) 
            else
                str=str .. to_string(i, r and sep, r) .." = " .. to_string(v, r and sep, r)
                if sep==' ' then between='; ' end
            end
            if type(i)=='number' then pos =i+1 end
        end
        return str .. " }"
end
_G.object_to_string=object_to_string

local function to_string(n,sep, r)
    if is_simple_table(n) then
        return object_to_string(n,sep,r)
    else
        return tostring(n)
    end
end
_G.to_string=to_string

function out(...)
    local t = table.pack(...) 
    t.n=nil
    local s= to_string( t, " " )
    print( string.sub(s,2,#s-2 ) )
end

--If you want a live object as a prototype then use
--Class(name,metacopy(prototype))
--Note: any table or object used as a prototype is simple_copy'd before being altered
--a limited form of super exists superclass has whatever was the class of the class
--methods actually stored in the prototype aren't part of superclass
--but self.superclass.amethod(self...) works except that super in that method won't be 
--super of super! To do that, the metaclass would have to keep changing and that isn't possible in lua

--metaclass is no longer used.  It being the metaclass of the class, which might already have one being an object
--and it would NEED the pre-existing metaclass for inheritance to work
--can be fixed with a class-send method kinda :/ method(self,class, ... )
--I may need a metalua to fix this

local function named_constructor(self, ... ) return self:new(...) end

function Class(name,class --, metaclass  
    )
    if type(name)~='string' then
        metaclass=class
        class=name
        if type(class)=='table' then class=simple_copy(class) end
        class=class or {}
        if class.class_name then _G[class.class_name]=class end
    else
        if type(class)=='table' then class=simple_copy(class) end
        class=class or {}
        class.class_name=name
        _G[name]=class
    end
    class.class_class_name = class.class_name .. " class"
    class.__index = rawget(class,"__index") or class
    local superclass = class.class
    class.class = class
    class.superclass=superclass
--[[ Ok, this wasn't thought out.  Giving the class a metaclass breaks the fact that it is a prototype
    that may be already an object, and we're depending on it already having __index at very least
    
    So the way it will now work is that it checks if it already has a metaclass and __call operator
    if it doesn't have both then __call is set to point to :new, in a way compatible with the metaclass
    it may or may not have.
    
    But if it's already an object with a __call, then you have to use :new..
    
    There's a possible race condition in the fact that objects don't get metatables till the first call to new.
    BAH!
    Since this is a simple copy, that could be fixed by making the metaclass a copy too?
    But the change of class wouldn't be captured in the closures!  Bah!
    
    We really something better than this delayed scan.
    Make a metaclass for the objects when the class is created
    and have a class:add_method function instead of the build in define
    that could check if it's a metaclass_function
    bah it would have to look like 
    AClass:add_method('name', functiondef..), horrible!

    local metaclass = getmetatable(class)
    if metaclass then
      if nil==metaclass.__call then metaclass.__call=named_constructor
    else setmetatable(class, {__call=named_constructor} )
    end

  for now, no named constructor
  What if Class was always a proxy with a copied metatable?
]]
    --delay creating a metatable until the first time it's needed
    --creates rather than using same table because inheritance doesn't work on metatable lookups
    --this way you can inherit metafunctions like other functions 
    --but is inheriting good, given the odd limits on them?  
    --set a metafunction to NULL to prevent it from being inherited from a superclass
    --it would be better to also have a way to say don't inherit from ME
    --uses a function that replaces itself in the table, Ruby style

    -- I wonder if we want a way to collapse regular table hierachies in a similar way for speed
    --Note, ignores "self" and uses "class" so that you can call new on an object and it refers back to the class
    --I could get rid of the : if I could trust people to type self.setmeta
    -- damn it, there's a race condition with class being a prototype object with it's own setmeta
    -- :/ class 
    class.setmeta = function(self,table)
            local meta={}
            local metamethods = {
            '__index','__add', '__sub', '__mul', '__div', '__mod', '__pow', '__unm', '__concat', 
            '__len', '__eq', '__lt', '__le', '__call', '__tostring', '__newindex','__gc','__metatable'
            }

        for i=1,#metamethods do
            local m=metamethods[i]
            local found=class[m]
            if (found and found~=DONT_INHERIT_META) then
                meta[m]=found 
            end
        end
        meta.__tostring = meta.__tostring or  object_to_string
        meta.__concat = meta.__concat or 
            function (self,other) return tostring(self) .. tostring(other) end
        class.metatable=meta
        
        class.setmeta = 
          function(self,table) 
            --obviously if it already has a metatable, then we can't assign one
            --but that would probably mean that we're copying from an object
            --that could have other references anyway..
            if getmetatable(table) then
              local new={}  --so we make a copy
              for k,v in pairs(table) do new[k]=v end
              table=new
            end
            return setmetatable(table,class.metatable) 
          end
        return class:setmeta(table) 
    end
    if not rawget(class,'new') then
        class.new = function(self,table) return self:setmeta(table or {}) end
    end
    if not rawget(class,'copy') then
        class.copy = simple_copy
    end
    if not rawget(class,'deep_copy') then
        class.deep_copy = simple_deep_copy
    end
    
    return class
end

local function add_table_items(dest,obj)
  for i,v in pairs(obj) do dest[i]=v end
  return dest
end
_G.add_table_items = add_table_items


function array_to_set_table(a)
  if type(a)~='table' then return a end
  local t={}
  for _,v in ipairs(a) do
    t[v]=true
  end
  return t
end

function set_table_to_array(t)
  if type(t)~='table' then return t end
  local a={}
  for k,v in pairs(t) do
    table.insert(a,k)
  end
  return a
end

function in_array(t,vt)
  for _,v in ipairs(t) do
    if v==vt then return true end
  end
  return false
end
  

function set_union(s1,s2)
  local t=copy_table_items(s1)
  return add_table_items(t,s2)
end

function set_intersection(s1,s2)
  local t={}
  for K,_ in pairs(s1) do  
    if s2[k] then t[k]=true end
  end 
  return t
end

function set_difference(s1,s2)
  local t={}
  for K,_ in pairs(s1) do  
    if not s2[k] then t[k]=true end
  end 
  return t
end

function deep_table_copy(obj,twisel)
  if type(obj)~='table' then return obj,twisel end
  if twisel==nil then twisel={}
  elseif twisel[obj] then return twisel[obj],twisel 
  end
  local copy={} 
  twisel[obj]=copy
  for i,v in pairs(obj) do
    local i2=deep_table_copy(i,twisel)
    copy[i2]=deep_table_copy(v,twisel)
  end
  return copy,twisel
end

function deep_table_copy_filter(obj,filter,twisel)
  if type(obj)~='table' then return obj,twisel end
  if twisel==nil then twisel={}
  elseif twisel[obj] then return twisel[obj],twisel 
  end
  local copy={} 
  twisel[obj]=copy
  for i,v in pairs(obj) do
    local i2=deep_table_copy_filter(i,filter,twisel)
    local v2=deep_table_copy_filter(v,filter,twisel)
    copy[i2]=filter(i2,v2)
  end
  return copy,twisel
end


function copy_filter(obj,filter)
  if type(obj)~='table' then return obj end
  local copy={} 
  for k,v in pairs(obj) do
    copy[k]=filter(k,v)
  end
  return copy
end

function do_each(obj,filter)
  if type(obj)~='table' then return end

  for k,v in pairs(obj) do
    filter(k,v)
  end
end

function prepend(v, t)
  table.insert(t,v,1)
  return t
end

function append(t,v)
  table.insert(t,v)
  return t
end

function array_slice(tbl, first, last, step)
  local sliced = {}

  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

function array_equal(t1, t2)
  if #t1~=#t2 then return false end
  for i=1,#t1 do
    if t1[i]~=t2[i] then return false end
  end
  return true
end


local function insure_subtable_exists(original_table,field)
  if not original_table.field then original_table.field={} end
end
