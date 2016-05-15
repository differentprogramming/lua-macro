@macro { new_tokens = {'nil!'}, head = 'nil! ?1a', body = '?a=nil' } 

@macro { 
  new_tokens = {'_nil!'}, 
  head = '_nil! ?1a', 
  body = function (data)
    return data.params.a .. '=nil'
    end
  } 
  
  @macro { 
    head = 'nif ?exp neg: ??,neg zero: ??,zero pos: ??,pos end',
    body = [[local %result = ?exp
              if %result<0 then ?neg
              elseif %result>0 then ?pos
              else ?zero end
            ]]
            }
  @macro { 
    head = '_nif ?exp neg: ??,neg zero: ??,zero pos: ??,pos end',
    body = function (data)
      local result = macro_system.gensym()
    return  result..'='..data.params.exp.. '\nif '..result..'<0 then '..data.params.neg..'elseif '..result..'>0 then '..data.params.pos..'else '..data.params.zero..' end'
    end
            }
  local a,b = 'a','b'
  
  nil! a
  _nil! b
  print (tostring(a),tostring(b))
  
  nif -1 neg: print 'right 1' zero: print 'wrong 1a' pos: print 'wrong 1b' end 
  nif 0 neg: print 'wrong 2a' zero: print 'right 2' pos: print 'wrong 2b' end 
  nif 1 neg: print 'wrong 3a' zero: print 'wrong 3b' pos: print 'right 3' end 
  _nif -1 neg: print 'right 1p' zero: print 'wrong 1ap' pos: print 'wrong 1bp' end 
  _nif 0 neg: print 'wrong 2ap' zero: print 'right 2p' pos: print 'wrong 2bp' end 
  _nif 1 neg: print 'wrong 3ap' zero: print 'wrong 3bp' pos: print 'right 3p' end 

print(@tostring(nif 1 neg: print 'wrong 3a' zero: print 'wrong 3b' pos: print 'right 3' end ))
print(@tostring(_nif 1 neg: print 'wrong 3ap' zero: print 'wrong 3bp' pos: print 'right 3p' end ))