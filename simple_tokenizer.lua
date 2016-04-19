--[[
lua tokenizer simplified to
1 All tokens that have a special meaning in Lua return type "Atom"
2 You can add constant keywords that override anything, their type is "Special"
3 to always return a type, value and processed value with the idea that the processed value will be the one used 
3 The other usable types are "Number", "String" and "Id"
4 both whitespace and comments are simply "Ignore"
String offset is saved as FilePos
line and line offset are also tracked as x and y
Lua tokenization should be perfect including all the strange number forms,
the string forms, the escapes etc.
Lua's internal read number is used to parse numbers
]]
  
local ascii_tok={}
local special_token_sets={}
local special_token_lists={}

local function add_special_token(s)
  for a=1,#s do
    if not special_token_sets[a] then special_token_sets[a]={} end
  end
  if not special_token_sets[#s][s] then
    special_token_sets[#s][s]=true
    table.insert(special_token_lists,s)
  end
end
--awesome should add line counting and support for indent for formatting altered code
local function tokenize(str,x,y,file_pos)
  for a=#special_token_sets,1,-1 do
    if #special_token_lists[a]~=0 then
      local sub=string.sub(str,file_pos,file_pos+a-1)
      if special_token_sets[a][sub] then 
        return x+#sub,y,file_pos+#sub,'Special',sub,sub 
        end
      end
    end
  return ascii_tok[str:byte(file_pos)](str,x,y,file_pos)
end

local function bad(str,x,y,file_pos) return x+1,y,file_pos+1,'Error',str:sub(file_pos,file_pos),'bad token' end
for a=0,255 do ascii_tok[a]=bad end

local function name_tok(str,x,y,file_pos)
  local tok=str:match("^[%w_]+",file_pos)
  return x+#tok,y,file_pos+#tok, 'Id', tok, tok
end
for a=('a'):byte(1),('z'):byte(1) do ascii_tok[a]=name_tok end
for a=('A'):byte(1),('Z'):byte(1) do ascii_tok[a]=name_tok end
ascii_tok[('_'):byte(1)]=name_tok

--[[
local combinable_punctuation = '+*/%^!@$&|?'
local function punct_tok(str,x,y,file_pos)
  local tok=str:match("^[+*/%^!@$&|?_]+",file_pos)
  return x+#tok,y,file_pos+#tok, 'Atom', tok, tok
end
for a=1,#combinable_punctuation do ascii_tok[combinable_punctuation:byte(a,a)]=punct_tok end
--]]
local singles='+*/%^#(){}];,'
local function single(str,x,y,file_pos) local s = str:sub(file_pos,file_pos); return x+1,y,file_pos+1,"Atom",s,s end
for a=1,#singles do ascii_tok[singles:byte(a,a)]=single end

--long strings are processed to convert \r combinations to \n, like the lua manual states
--so files from windows, old mac style and risk os will still read embedded returns as \n
-- also converting white space, commments and strings with delimiters to make text processing simpler
--starts with the initial indent, and returns the indent of the last line (or the indent unchanged
--if there are no carriage returns).  Also takes initial indent and returns x indent and number
--of carriage returns
--you can use (nlcr_process(str)) if you don't need the indent and line numbers
local function nlcr_process(str,initial_indent)
  initial_indent=initial_indent or 0 
  if str==nil then return nil,initial_indent,0 end
  local s=str:find('\r',1,true)
  local process_returns
  if s then
    str = (((str:gsub("\r\n","\n")):gsub("\n\r","\n")):gsub("\r","\n"))
    process_returns= true
  else 
    process_returns=str:find('\n',1,true)
  end
  if process_returns then
    local p,c,indent=0,-1,0
    repeat 
      p=str:find('\n',p+1,true) --find next cr
      if p then indent=#str-p end --indent is the distance between the final cr and the end character 
      c=c+1
    until p==nil
    return str,indent,c
  end
  return str,initial_indent+#str,0
end

local whites=" \t\v\f"
local carriage_return_whites="\r\n"
local function white(str,x,y,file_pos) 
  local tok=str:match("^[% %\t%\v%\f]+",file_pos)
  return x+#tok,y,file_pos+#tok, 'Ignore', tok, tok
end
local function carriage_return(str,x,y,file_pos) 
  local tok=str:match("^[%\r%\n]+",file_pos)
  local processed,indent,down=nlcr_process(tok,x)
  return indent,y+down,file_pos+#tok, 'Ignore', processed,processed
end
for a=1,#whites do ascii_tok[whites:byte(a,a)]=white end
for a=1,#carriage_return_whites do ascii_tok[carriage_return_whites:byte(a,a)]=carriage_return end

local function set_tok_leq(char,second)
  local con=char..second
  ascii_tok[(char):byte(1)]= function(str,x,y,file_pos) 
  if str:byte(file_pos+1)==(second):byte(1) then return x+2,y,file_pos+2,'Atom',con,con end
  return x+1,y,file_pos+1,'Atom',char,char end
end
set_tok_leq('=', '=')
set_tok_leq('<', '=')
set_tok_leq('>', '=')
set_tok_leq(':', ':')

ascii_tok[('~'):byte(1)]=function(str,x,y,file_pos) 
    if str:byte(file_pos+1)==('='):byte(1) then return x+2,y,file_pos+2,'Atom', '~=', '~=' end
    return x+1,y,file_pos+1,'Error', '~', 'bad token, ~ not followed by =' 
  end

local function longest_number(str,x,y,file_pos)
  local candidate=str:match("^[%x.xXpP+-]+",file_pos) --accepts all of the wierd lua number formats
  while #candidate > 0 do
    local n=tonumber(candidate)
    if n then return x+#candidate,y,file_pos+#candidate,'Number',candidate,n end
    candidate=candidate:sub(1,#candidate-1)
  end
end
ascii_tok[('.'):byte(1)]=function(str,x,y,file_pos)
    do
      local nx,ny,npos,a,b,c = longest_number(str,x,y,file_pos)
      if nx then return nx,ny,npos,a,b,c end   
    end
    if str:byte(file_pos+1)==('.'):byte(1) then 
      if str:byte(file_pos+2)==('.'):byte(1) then 
        return x+3,y,file_pos+3,'Atom', '...', '...'
      end
      return x+2,y,file_pos+2,'Atom', '..', '..'
    end
    return x+1,y,file_pos+1,'Atom', '.', '.'
  end
for a=('0'):byte(1),('9'):byte(1) do ascii_tok[a]=longest_number end

-- one line comments include their cr because they can't scan properly without them
--so they should include what's necessary to recreate a scannable file
ascii_tok[('-'):byte(1)]=function(str,x,y,file_pos)
    if str:byte(file_pos+1)==('-'):byte(1) then -- starts "--"
      local _,l=str:match("^%[(=*)%[.-]%1]()",file_pos+2)
      --oops a bit more complex
      if l then 
        local indent,lines_down
          str,indent,lines_down=nlcr_process(str:sub(file_pos,l-1),x)
        return indent,y+lines_down,l,'Comment',str,str 
      end
      l = str:match("^%[=*%[[^\n\r]*",file_pos+2) 
      if l then return x+#l,y,file_pos+#l,'Error',l,'unfinished long commment' end 
      l=str:match("^[^\n\r]*[\n\r]*",file_pos)
      local indent,lines_down
      str,indent,lines_down=nlcr_process(l,x)
      return 0,y+(lines_down or 1),file_pos+#l,'Comment',str,str
   end
  return x+1,y,file_pos+1,'Atom', '-' ,'-'  
end

local simple_backlash_chars="abfnrtv\\\"'"
local simple_backlash_chars_map="\a\b\f\n\r\t\v\\\"'"
local backslash_char={}
local function set_backslash_error(num)
  backslash_char[num]=function (pos, str, curx, cury,curpos, restfn, str_prefix, processed_prefix)
    return curx+1,cury, curpos+1,'Error',str_prefix..'\\'..string.char(num),'bad escape character in string' 
  end
end

for a=0,255 do set_backslash_error(a) end
local function set_simple_backslashfn(a)
  local char=simple_backlash_chars:sub(a,a)
  local to=simple_backlash_chars_map:sub(a,a)
  backslash_char[char:byte(1)]=function (pos, str, x, y, curpos, restfn, str_prefix, processed_prefix)
    str_prefix=str_prefix..'\\'..char
    processed_prefix=processed_prefix..to
    curpos=curpos+2
    return restfn(pos,str,x+2,y,curpos,str_prefix,processed_prefix)-- finish tomorrow
  end
end
for a=1,#simple_backlash_chars do set_simple_backslashfn(a) end
backslash_char[('x'):byte(1)]=function (pos, str, x, y, curpos, restfn, str_prefix, processed_prefix)
    local tok=str:match("^%x%x",curpos+2)
    if tok==nil then return x+2,y,curpos+2,'Error',str_prefix..'\\x', 'bad hex escape in string' end
    str_prefix=str_prefix..'\\x'+tok
    processed_prefix=processed_prefix .. string.char(tonumber('0x'..tok))
    return restfn(pos,str,x+4,y,curpos+4,str_prefix,processed_prefix)
  end
backslash_char[('z'):byte(1)]=function (pos, str, x, y, curpos, restfn, str_prefix, processed_prefix)
    local tok=str:match("^%s+",curpos+2)
    local indent,down,proc=nlcr_process(tok,x)
    str_prefix=str_prefix..'\\z'+proc
    return restfn(pos,str,indent,y+down,curpos+2+#tok,str_prefix,processed_prefix)
  end
local function set_backslash_num(num)
backslash_char[num+('0'):byte(1)]=function (pos, str, x, y, curpos, restfn, str_prefix, processed_prefix)
    local tok = str:match("^%d%d%d",curpos+1) or str:match("^%d%d",curpos+1) or str:match("^%d",curpos+1)
    str_prefix=str_prefix..'\\'..tok
    processed_prefix=processed_prefix .. string.char(tonumber(tok))
    return restfn(pos,str,x+1+#tok,y,curpos+1+#tok,str_prefix,processed_prefix)
  end
end
for a=0,9 do set_backslash_num(a) end
local function set_string_fn(char)
  local num=char:byte(1)
  local function scan_string(pos,str, x, y, curpos, str_prefix, processed_prefix)
    --luajit has an error if a string has a carrage return in it, but if it's after a \ then the string is nil
    --instead. We just do the error not the wierd nil behavior
    local pref=str:match("^[^\\\n\r"..char.."]*",curpos)
    curpos=curpos+#pref
    processed_prefix=processed_prefix..pref
    str_prefix=str_prefix..pref
    local ended=str:byte(curpos)
    if ended==num then return x+1,y,curpos+1,'String',str_prefix..char,processed_prefix end
    --put in an error scan routine to find the end of string on an error {}{}{}
    if ended==('\\'):byte(1) then return backslash_char[str:byte(curpos+1)](pos,str,x,y,curpos,scan_string,str_prefix,processed_prefix) end
    return x+1,y,curpos+1,'Error',str_prefix,'unfinished string'
  end 
  ascii_tok[num]=function(str,x,y,pos) return scan_string(pos,str,x+1,y,pos+1,char,'') end
end
set_string_fn("'")
set_string_fn('"')
ascii_tok[('['):byte(1)]=function(str,x,y,pos)
    if str:byte(pos+1)==('['):byte(1) or str:byte(pos+1)==('='):byte(1) then
      local _,content_start,content_end,whole_end=str:match("^%[(=*)%[().-()]%1]()",pos)
      if _ then 
        if str:byte(content_start) == ('\n'):byte(1) then content_start=content_start+1 end
        local with_ends, indent, down = nlcr_process(str:sub(pos,whole_end-1))
        return indent,y+down,whole_end,'String',with_ends,(nlcr_process(str:sub(content_start,content_end-1)))
        end
      l = str:match("^%[=*%[[^\n]*",pos) 
      if l then return x+#l,y,pos+#l,'Error',l,'unfinished long string' end 
   end
  return x+1,y,pos+1,'Atom', '[', '['
end

local token_types = { 
  'Error',
    --
    'Id',
    'Atom',
    --
    'Comment',
    'Ignore',
    --
    'Number',
    'String',
}
local not_meaningful={Ignore=true, Comment=true}


local function meaningful_tokenize(str,x,y,file_pos)
  local tok_type, tok_value, processed
  repeat 
    x, y, filepos,tok_type, tok_value, processed = tokenize(input,x,line,pos)
  until not not_meaningful[tok_type] 
  return x, y, filepos,tok_type, tok_value, processed
end

local function tokenize_all(input)
  if not input or 0==#input then return false, {}, {} end
local pos=1
local x=1
local line=1
local source={}
local meaningful={}
local error_pos=false
repeat
    local new_x, new_line, new_pos,tok_type, tok_value, processed = tokenize(input,x,line,pos)
  
  table.insert(source, {from_x=x, to_x=new_x, from_line=line, to_line=new_line, from_pos=pos,to_pos=new_pos-1,type=tok_type, value=tok_value, processed=processed, source_index=#source} )
  pos=new_pos
  x=new_x
  line=new_line
  if not not_meaningful[tok_type] then table.insert(meaningful, #source) end
  
  if not error_pos and tok_type == 'Error' then error_pos=#source end
  
until pos>#input
    return error_pos, source, meaningful
end

local Ascii_Tokenizer = 
{
  --note, can't make a list of dispatch functions because some are closures 
  -- they'd have to be generated in to the table with names.
  special_token_sets=special_token_sets,
  special_token_lists=special_token_lists,
  add_special_token=add_special_token,
  not_meaningful=not_meaningful,
  ascii_tok=ascii_tok, --dispatch table on first character that tokenize() runs off of
  keywords=keywords, -- list of all keywords
  key_tok=key_tok, -- actual test, is a keywords is key_tok[test_value]
  singles=singles, -- the characters that in pure lua can be processed into tokens at one char without look ahead
  nlcr_process=nlcr_process, -- processes strings so that cr are always Unix style
  carriage_return_whites=carriage_return_whites, -- carriage return whitespace
  whites=whites, --other whitespace
  longest_number=longest_number, --finds the longest parsing as a number from the start of a string
  
  token_types=token_types, -- public table, list of all things that can be returned in 4th position
  tokenize=tokenize, --the only part of this that has to be public if you are just USING the tokenizer and not changing it return new_x, new_line, new_pos,tok_type, [tok_value[, processed_tok_value]]
  
  meaningful_tokenize = meaningful_tokenize, --skips whitespace and comments
  tokenize_all = tokenize_all,
}
return Ascii_Tokenizer

