@macro { head = '(?a add ?b)', body ='(?a+?b)' }
@macro { head = '(?a sub ?b)', body ='(?a-?b)' }
@macro { head = '(?a mul ?b)', body ='(?a*?b)' }
@macro { head = '(?a div ?b)', body ='(?a/?b)' }
@macro { head = '(?a at ?b)', body ='(?a[?b])' }
@macro { head = '(?a at ?b put ?c)', body ='([| %e | ?a[?b]=%e @%e |])(?c)' }
@macro { head = '?1b put ?c;', body ='([| %e | ?b=%e @%e |])(?c)', match_debug=true }
@macro { head = 'square(?a)', body ='([| %e | @%e*%e |])(?a)' }
@macro { head = 'c', body ='b' }

local bb1
bb1 put square(square(5)) add square(square(4));

print(b @@ c @@ 1 .. " equal? " .. (5*5*5*5 + 4*4*4*4) .. " test " ..@tostring( c @@ "hello" @@c ) )