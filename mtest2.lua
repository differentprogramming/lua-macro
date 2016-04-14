macros = require 'macro_require'

macros.add({'amb','endamb','inner_amb'},
  [[local amb ?id = ( ?()...first , ?,...rest ) ?,...statements endamb]],
   [[for _,%i in ipairs{ [|| @ ?first |], inner_amb ?rest } do
    local ?id=%i();
    ?statements
   end]])
   
macros.add({'inner_amb'},'inner_amb }','}')
macros.add({'inner_amb'},'inner_amb ?()...a }','[||@?a |],}')
macros.add({'inner_amb'},'inner_amb ?...first , ?,...rest }','[||@?first |], inner_amb ?rest }')

t=require 'macrotest'

