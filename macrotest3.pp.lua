

local foo = [| a,b | @(10*a+b) |]

local amb j = (1+foo(2,5),2+20,3+30,4+40,5+50)
  print(j)
endamb

  
print('returned '..(function()   
  local i,j
  i=1 
  WHILE i<=6 DO
    j=10
    if i==3 then
      i=i+1
      CONTINUE 
    end
    if i==5 then BREAK end
    WHILE j<=70 DO
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
  
  
#macro {new_tokens={'amb','endamb','inner_amb'},
  head=[[local amb ?id = ( ?()...first , ?,...rest ) ?,...statements endamb]],
  body= [[for _,%i in ipairs{ [|| @ ?first |], inner_amb ?rest } do
    local ?id=%i();
    ?statements
   end]]}
   
#macro {new_tokens={'inner_amb'},head='inner_amb }',body='}'}
#macro {new_tokens={'inner_amb'},head='inner_amb ?()...a }',body='[||@?a |],}'}
#macro {new_tokens={'inner_amb'},head='inner_amb ?...first , ?,...rest }',body='[||@?first |], inner_amb ?rest }'}

  

#macro {  
  new_tokens={'WHILE','DO','END', 'BREAK', 'CONTINUE'},
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
  ]]
}

