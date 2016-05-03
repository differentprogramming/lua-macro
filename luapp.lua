dofile 'interpreters/luabase.lua'
local intr = MakeLuaInterpreter()
intr.name = "Lua PP"
intr.skipcompile = true
intr.frun = function(self,wfilename,rundebug)
  local exe = self:fexepath("")
  local filepath = wfilename:GetFullPath()

  do
    -- if running on Windows and can't open the file, this may mean that
    -- the file path includes unicode characters that need special handling
    local fh = io.open(filepath, "r")
    if fh then fh:close() end
    if ide.osname == 'Windows' and pcall(require, "winapi")
    and wfilename:FileExists() and not fh then
      winapi.set_encoding(winapi.CP_UTF8)
      local shortpath = winapi.short_path(filepath)
      if shortpath == filepath then
        DisplayOutputLn(
          ("Can't get short path for a Unicode file name '%s' to open the file.")
          :format(filepath))
        DisplayOutputLn(
          ("You can enable short names by using `fsutil 8dot3name set %s: 0` and recreate the file or directory.")
          :format(wfilename:GetVolume()))
      end
      filepath = shortpath
    end
  end
local init = [=[
(loadstring or load)([[
if pcall(require, "mobdebug") then
  local mdb = require "mobdebug"
  mdb.linemap = function(line, src)  --print("line",line, tostring(codemap[src][line]),'src','"'..src..'"') 
  return math.abs(codemap[src][line] or line) end
end
]])()
]=]

  if rundebug then
   
    DebuggerAttachDefault({init = init,runstart = ide.config.debugger.runonstart == true})
    -- update arg to point to the proper file
    rundebug = ('if arg then arg[0] = [[%s]] end '):format(filepath)..rundebug

    local tmpfile = wx.wxFileName()
    tmpfile:AssignTempFileName(".")
    filepath = tmpfile:GetFullPath()
    local f = io.open(filepath, "w")
    if not f then
      DisplayOutputLn("Can't open temporary file '"..filepath.."' for writing.")
      return
    end
    f:write(rundebug)
    f:close()
  else 
    DebuggerAttachDefault({init = init})
  end
  local params = ide.config.arg.any or ide.config.arg.lua
  local code = ([[-e "io.stdout:setvbuf('no')" "C:\ZeroBrane1.30\lualibs\myppscript.lua" "%s"]]):format(filepath)
  local cmd = '"'..exe..'" '..code..(params and " "..params or "")

  -- modify CPATH to work with other Lua versions
  local envname = "LUA_CPATH"
  if version then
    local env = "LUA_CPATH_"..string.gsub(version, '%.', '_')
    if os.getenv(env) then envname = env end
  end

  local cpath = os.getenv(envname)
  if rundebug and cpath and not ide.config.path['lua'..(version or "")] then
    -- prepend osclibs as the libraries may be needed for debugging,
    -- but only if no path.lua is set as it may conflict with system libs
    wx.wxSetEnv(envname, ide.osclibs..';'..cpath)
  end
  if version and cpath then
    local cpath = os.getenv(envname)
    local clibs = string.format('/clibs%s/', version):gsub('%.','')
    if not cpath:find(clibs, 1, true) then cpath = cpath:gsub('/clibs/', clibs) end
    wx.wxSetEnv(envname, cpath)
  end

  -- CommandLineRun(cmd,wdir,tooutput,nohide,stringcallback,uid,endcallback)
  local pid = CommandLineRun(cmd,self:fworkdir(wfilename),true,false,nil,nil,
    function() if rundebug then wx.wxRemoveFile(filepath) end end)

  if (rundebug or version) and cpath then wx.wxSetEnv(envname, cpath) end
  return pid
end

return intr