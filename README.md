# lua-macro
A macro system for lua, somewhat similar to scheme's syntax forms. Both more and less powerful depending on what you're doing.

pre alpha state.

Defines two kinds of macros. 

Simple macros are just nonstandard tokens that are replaced by constant text.
The other kind are syntax forms.  Those have three parts:
1) A list of nonstandard tokens used if any
2) The head, what to match against. A string.  There are 4 kinds of variables that can appear in the head each of which has different matching properties.
a) note that if you use the same variable more than once in the head that means that you're "guarding" the macro with the assumption that the same text appears more than once.  If the source text matches in all of the places where the same variable appears then the macro can substitute.
3) a body, which is the text to substitute.  There is a fourth kind of variable that can appear in the body. They represent a unique names, usually used to define a variable or a label. Names such as "__GENVAR_10001__" will be generated with the number incrementing every time a new variable is made.

At the moment a number of simple macros predefined
Here is the list of predefined macros:
simple_translate = setmetatable(
  { ['[|']='function (',
    ['{|']='coroutine.wrap(function (',
    ['|']=')',
    ['@']='return',
    ['y@']='coroutine.yield',
    ['Y@']='coroutine.yield',
    ['|]']='end',
    ['|}']='end)',
    ['$#']='select("#",...)',
    ['$1']='select(1,...)',
    ['$2']='select(2,...)',
    ['$3']='select(3,...)',
    ['$4']='select(4,...)',
    ['$5']='select(5,...)',
    ['$6']='select(6,...)',
  }, { __index = function(_,v) return v end })

Note that "[| a,b,c | print(a,b,c) |]" would translate to "function (a,b,c) print(a,b,c) end"
"{| a,b,c | print(a,b,c) |}" would translate to "coroutine.wrap(function (a,b,c) print(a,b,c) end)"
These will be replaced with smarter macros that make sure that there is context.

The final version will have Zerobrane integration.

