macros = require 'macro_require'

macros.add{
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
t=require 'macrotest'

