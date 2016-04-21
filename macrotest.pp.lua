
#macro { new_tokens={'macro1'}, head='macro1(?...a)', body='1001+?a' }
#macro { head="sout", body="io.stdout:write" }

function display(n,...)
  if n then io.stdout:write(tostring(n)) end
  if $# ~= 0 then 
    sout(', ')
    @ display(...) 
  end
end