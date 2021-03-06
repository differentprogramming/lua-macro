@require 'macrotest'

local foo = [| a,b | @(10*a+b) |]

local amb j = (1+foo(2,5),2+20,3+30,4+40,5+50)  --line 1
  print(j)                                      --line 2
endamb                                          --line3

--before section
@section 'define' --after section
  
 print 'in regular phase' 
@start
   print 'in pre load phase'
   print (@tostring( no/need ), blah.h)
@end 
  
print('returned '..(function()   
  local i,j --[[a different comment]] --line 4
  i=1 --line5
  WHILE i<=6 DO print 'loop 1' TEST
    j=10
    if i==3 then
-- on it's own line      
      i=i+1
        
      CONTINUE 
    end
    if i==5 then BREAK end
    WHILE j<=70 DO print 'loop 2' TEST
      if j==30 then
        j=j+10
        CONTINUE 
      end
      if j==60 then BREAK end
      print(i,j)
      if i+j==54 then return i+j end
      j=j+10
    END
    i=i+1
  END
end)())
  
define foo2(bar)
  print(bar)
  print "bye"
end

define fubar(baz)
  print(baz*2)
end

@macro { 
  new_tokens={'define'}, 
  head= [[define ?1fn ( ?,params ) ?,code end]],
  body = [[?fn = function(?params) ?code end]],
  sections= { 
    define=[[local ?fn ]],
    module=[[?fn = ?fn ,]]
    } 
  }
  
display(macro1(1),5)  
  
@macro {new_tokens={'amb','endamb','inner_amb','no/need'},
  head=[[local amb ?id = ( ?first , ?,rest ) ?,statements endamb]],
  body= [[for _,%i in ipairs{ [|| @ ?first |], inner_amb ?rest } do
    local ?id=%i();
    ?statements
   end]]}
   
@macro {new_tokens={'inner_amb'},head='inner_amb }',body='}'}
@macro {new_tokens={'inner_amb'},head='inner_amb ?a }',body='[||@ ?a |],}'}
@macro {new_tokens={'inner_amb'},head='inner_amb ?first , ?,rest }',body='[||@?first |], inner_amb ?rest }'}

  

@macro {  
  new_tokens={'WHILE','DO','END', 'BREAK', 'CONTINUE'},
  head='WHILE ?exp DO ?,test TEST ?,statements END',
  body=[[
  local function %loop() 
    if ?exp then
      @apply({{head='BREAK',body='?test @"__*done*__"'},
      {head='CONTINUE',body='@ %loop()'},}, ?statements)
      return %loop()
    end
    return '__*done*__'
  end
  local %save=table.pack(%loop())
  if %save[1]~='__*done*__' then return table.unpack(%save,%save.n) end
  ]]
}

local n = {
@section 'module'
}
return n