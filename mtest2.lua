macros = require 'macro_require'

macros.add({'amb','endamb','inner_amb'},
  [[local amb %1 = ( %A()... , %B,... ) %C,... endamb]],
   [[for _,%g1 in ipairs{ [|| @ %A()... |], inner_amb %B,... } do
    local %1=%g1();
    %C,...
   end]])
   
macros.add({'inner_amb'},'inner_amb }','}')
macros.add({'inner_amb'},'inner_amb %A()... }','[||@%A()... |],}')
macros.add({'inner_amb'},'inner_amb %A()... , %B,... }','[||@%A()... |], inner_amb %B,... }')

t=require 'macrotest'

