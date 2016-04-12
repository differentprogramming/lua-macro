# lua-macro
A macro system for lua, somewhat similar to scheme's syntax forms. Both more and less powerful depending on what you're doing.<br/>
<br/>
pre alpha state.<br/>
<br/>
Defines two kinds of macros. <br/>

Simple macros are just nonstandard tokens that are replaced by constant text.<br/>
The other kind are syntax forms.  Those have three parts:<br/>
1) A list of nonstandard tokens used if any<br/>
2) The head, what to match against. A string.  There are 4 kinds of variables that can appear in the head each of which has different matching properties.<br/>
a) note that if you use the same variable more than once in the head that means that you're "guarding" the macro with the assumption that the same text appears more than once.  If the source text matches in all of the places where the same variable appears then the macro can substitute.<br/>
3) a body, which is the text to substitute.  There is a fourth kind of variable that can appear in the body. They represent a unique names, usually used to define a variable or a label. Names such as "__GENVAR_10001__" will be generated with the number incrementing every time a new variable is made.<br/>
<br/>
At the moment a number of simple macros predefined<br/>
Here is the list of predefined macros:<br/>
simple_translate = setmetatable(<br/>
  { ['[|']='function (',<br/>
    ['{|']='coroutine.wrap(function (',<br/>
    ['|']=')',<br/>
    ['@']='return',<br/>
    ['y@']='coroutine.yield',<br/>
    ['Y@']='coroutine.yield',<br/>
    ['|]']='end',<br/>
    ['|}']='end)',<br/>
    ['$#']='select("#",...)',<br/>
    ['$1']='select(1,...)',<br/>
    ['$2']='select(2,...)',<br/>
    ['$3']='select(3,...)',<br/>
    ['$4']='select(4,...)',<br/>
    ['$5']='select(5,...)',<br/>
    ['$6']='select(6,...)',<br/>
  }, { __index = function(_,v) return v end })<br/>
<br/>
Note that "[| a,b,c | print(a,b,c) |]" would translate to "function (a,b,c) print(a,b,c) end"<br/>
"{| a,b,c | print(a,b,c) |}" would translate to "coroutine.wrap(function (a,b,c) print(a,b,c) end)"<br/>
These will be replaced with smarter macros that make sure that there is context.<br/>
<br/>
The final version will have Zerobrane integration.

