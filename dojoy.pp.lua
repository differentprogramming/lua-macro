@require 'joyish'

import_joy

local function J(...)
  return doit(joy(...))
end

print(add(number(1),number(3)))
print(tostring(add.type), getmetatable(add).__index)
print(joy{2,1,add})
print(J{3,dup,add})
print(J({dup,mul},10))
print(J(map,{dup,mul},{1,2,3,4}))
