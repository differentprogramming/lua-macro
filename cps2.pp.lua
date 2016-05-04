
--before section
@section 'define' --after section
  

@macro {  
  head= [[define ?1fn ( ??,params ) ?,code end]],
  body = [[?fn = function(?params) ?code end]],
  sections= { 
    define=[[local ?fn ]],
    module=[[?fn = ?fn ,]]
    } 
  }

@macro {
  head='callcc ?,v = ?cfun (?,values) ??,rest endcc',
  body ='?cfun(function(...) ?v=...; ?rest end,?values)' 
  }
 @macro {
  head='callcc ?,v = ?cfun () ??,rest endcc',
  body ='?cfun(function(...) ?v=...; ?rest end)'
  }
@macro {
  head='callcc ?cfun (?,values) ??,rest endcc',
  body ='?cfun(function() ?rest end,?values)' 
  }
@macro {
  head='callcc ?cfun () ??,rest endcc',
  body ='?cfun(function() ?rest end)' 
  }


@macro {  
  head= [[funcc ( ?,params ) ??,statements end]],
  body = 
  [=[function(C,?params) 
    @apply({{head='retc(??,values)',body='return C(?values)'},
    {head='while',body='WHILE'},
    {head='break',body='BREAK'},
    {head='continue',body='continue'},
    {head='call ?,v = ?cfun (?,values) ??,rest @end',
    body ='?cfun(function(...) ?v=...; ?rest end,?values)' },
    {head='call ?,v = ?cfun () ??,rest @end',
    body ='?cfun(function(...) ?v=...; ?rest end)' },
    {head='call ?cfun (?,values) ??,rest @end',
    body ='?cfun(function() ?rest end,?values)' },
    {head='call ?cfun () ??,rest @end',
    body ='?cfun(function() ?rest end)' },
    {head ='store_and_ret_cc(?dest) ??,rest @end',
    body=[[
    local %temp = funcc() ?rest end 
    ?dest = %temp
    retc ()]]
    },
    {head ='store_and_ret_cc(?dest, ??,values) ??,rest @end',
    body=[[
    local %temp = funcc() ?rest end 
    ?dest = %temp
    retc (?values)]]
    },
    }, 
    ?statements) 
  end]=],
  }
@macro {  
  head= [[funcc () ??,statements end]],
  body = 
  [=[function(C) 
    @apply({{head='retc(??,values)',body='return C(?values)'},
    {head='while',body='WHILE'},
    {head='break',body='BREAK'},
    {head='continue',body='continue'},
    {head='call ?,v = ?cfun (?,values) ??,rest @end',
    body ='?cfun(function(...) ?v=...; ?rest end,?values)' },
    {head='call ?,v = ?cfun () ??,rest @end',
    body ='?cfun(function(...) ?v=...; ?rest end)' },
    {head='call ?cfun (?,values) ??,rest @end',
    body ='?cfun(function() ?rest end,?values)' },
    {head='call ?cfun () ??,rest @end',
    body ='?cfun(function() ?rest end)' },
    {head ='store_and_ret_cc(?dest) ??,rest @end',
    body=[[
    local %temp = funcc() ?rest end 
    ?dest = %temp
    retc ()]]
    },
    {head ='store_and_ret_cc(?dest, ?,values) ??,rest @end',
    body=[[
    local %temp = funcc() ?rest end 
    ?dest = %temp
    retc (?values)]]
    },
    }, 
    ?statements) 
  end]=],
  }


@macro {  
  head= [[defc ?1fn ( ??,params ) ??,statements end]],
  body = [[?fn = funcc(?params) ?statements end]],
  sections= { 
    define=[[local ?fn ]],
    module=[[?fn = ?fn ,]]
    } 
  }

count3 = funcc(store)
    local n=1
    store_and_ret_cc(store[1],n)
    n=2
    store_and_ret_cc(store[1],n)
    n=3
    retc(n)
  end
 
  
  local cont={}
  local m
  callcc m=count3(cont)
    print(m)
    callcc m=cont[1](cont)
      print(m)
      callcc m=cont[1](cont)
        print(m)
      endcc
    endcc
  endcc

funcc_count3 = funcc(cont) 
    local m
    call m=count3(cont)
    print(m)
    call m=cont[1](cont)
    print(m)
    call m=cont[1](cont)
    print(m)
    retc()
end    
  
callcc funcc_count3(cont)
endcc

  --oops, no continuation allowed in the test!
@macro {  
  head='WHILE ?exp DO ??,statements END',
  body=[[
  local function %loop() 
    if ?exp then
      @apply({{head='BREAK',body= "__*done*__"},
      {head='CONTINUE',body='@ %loop()'},}, ?statements)
      return %loop()
    end
    return '__*done*__'
  end
  local %save=table.pack(%loop())
  if %save[1]~='__*done*__' then retc(table.unpack(%save,%save.n)) end
  ]]
}

local n = {
@section 'module'
}
return n