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
      --I should test return too
      j=j+10
    END
    i=i+1
  END
end)())
