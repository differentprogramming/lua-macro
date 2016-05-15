*note: state of the code is, still being debugged. Has random logging to std err still on.*
*There are no showstopper bugs that I'm aware of at the moment.*
*Also the state of this document is that I'm actively working on it.*
#Lua Preprocessor

I haven’t decided what to name this system, I should come up with a name that shows up in google searches as distinct from the many similar systems…

The features of this Lua preprocessor:
1. It’s a relatively simple preprocessor, providing both template based substitution similar to scheme and procedural substitution similar to Common Lisp.  
2. It allows a single macro to generate code in multiple places at one time, helping with one of the most annoying problems with boilerplate code.   
3. The processor runs in pure lua and can export preprocessed files that are pure lua, facilitating compiling them for embedding.  The resulting code doesn’t need to include the macro library.  
4. Other preprocessor functions such as ifdefing out macros or code are also supported, helping you create custom versions of programs.  
5. The system is simple.  It knows just enough lua grammar to facilitate having a few easy to use kinds of input parameters, such as ones that accept a single expression, ones that accept a list of expressions or statements into a parameter and a couple more kinds of parameters.  
6. There are easy to use facilities to help you keep macros hygienic (avoid variable capture).  
7. The system is (will be) documented, with full explanations of the features and examples.  
8. There is some integration into Zerobrane Studio, making it easier to find errors and debug processed code.  

There are two modes for defining a macro:

1. normal lua.  You define macros by passing tables describing them to an add_macro function, then you load or require the file that you want processed.  
2. macros inline with the code being processed:  
   In that case, you use C preprocessor like line markings.  @macro at the beginning of a line or other preprocessor directives.
   In this case the file is processed in two passes (actually 3 but who is counting). All of the preprocessor directives are processed before the other content of the file.  Macros don’t have to be defined before they are used.
As an example I’m going to show the same simple macro in both styles
First a macro in regular lua style. 
```lua 
 macro_system.add {
   head='assert_compared(?1op,?a,?b)',
   body=[[ if not(?a ?op ?b) then 
           io.stderr:write('assertion ',@tostring(?a ?op ?b),' failed, returning ', tostring(?a), ' and ',tostring(?b),'\n')
           os.exit(1)
         end]]
 }
```
Now the same macro in macro directive style:
```lua
 @macro {
   head='assert_compared(?1op,?a,?b)',
   body=[[ if not(?a ?op ?b) then 
           io.stderr:write('assertion ',@tostring(?a ?op ?b),' failed, returning ', tostring(?a), ' and ',tostring(?b),'\n')
           os.exit(1)
         end]]
 }
```

Unless you’re depending on Zerobrane integration which isn’t complete yet, you’ll need a lua file to load the macro system then to load a file you want processed.

This file needs `require 'macro_require'` before loading the file.  Macro require patches “require” so that you include a macro file through require.  You have to name your macro files specially with “.pp.lua” so that “require” knows to process them through the macro processor.  So you could name your file “equal_assert.pp.lua” then require it with  `require 'equal_assert'`.

So to make it concrete you’ll need two files, the driver file that bootstraps the macro system [for instance call it boot_macro.lua]:
```lua
 require 'macro_require'
 
 require 'assert_test'
```
And your first macro file [call it *assert_test.pp.lua]:*
```lua
 @macro {
   head='assert_compared(?op,?a,?b)',
   body=[[ if not(?a ?op ?b) then 
           io.stderr:write('assertion ',@tostring(?a ?op ?b),' failed, returning ', tostring(?a), ' and ',tostring(?b),'\n')
           os.exit(1)
         end]]
 }
 
 assert_compared(==,3+3,3+4)
```
If you run it, it prints `“assertion 3 + 3 == 3 + 4 failed, returning 6 and 7”`

If you wanted to do this the pure lua way then you’d have to load the macro before you load any file that uses it, in which case your files could look like *[boot_macro.lua]:*
```lua
local macro_system = require 'macro_require' --the assignment isn’t necessary, since macro_require exports it as a global
 macro_system.add {
   head='assert_compared(?op,?a,?b)',
   body=[[ if not(?a ?op ?b) then 
           io.stderr:write('assertion ',@tostring(?a ?op ?b),' failed, returning ', tostring(?a), ' and ',tostring(?b),'\n')
           os.exit(1)
         end]]
 }
 
 require 'assert_test'
```

In this case the file to be processed is just *[assert_test.pp.lua]:*

```lua
 assert_compared(==,3+3,3+4)
```

But using macro directives is easier, I recommend using them except when you have to generate macros manually.  If you use the Zerobrane integration and set the interpreter to the preprocessor, then you don’t need the driver files, just the preprocessor ones. In that case you’ll also be able to single step macro files, though it doesn’t work perfectly.

The system has the following preprocessor directives
[the following can only appear at the beginning of a line]:
* `@macro` – define a macro along with non-standard tokens (marked with the new_tokens tag).  
* `@if, @elseif, @else, @endif` – conditional inclusion and conditional macro definitions  
* `@start, @end` – run lua code in the preprocessor phase.  Needed to define variables to test in `@if`  
* `@require 'filename'`– include macro files from other macro files in the preprocessor phase  
* `@section 'sectionname'` – specify inclusion points for macros that generate code non-locally.  

[macro directives that appear in OTHER places than the beginning of a line]:
* `@apply` {[macro definitions]} – define and apply local macros inside of another macro.lua. This directive can only appear inside a macro body.  
`@tostring(expression)`- turn parameter or macro expansion into a string. Especially useful for print out a macro to see how it expands.  Note this system expands from right to left, so that parameters are fully expanded before they’re passed to other macros.  
`@@` - *Concatinate tokens.*  The same as ## in the C preprocessor.

##The Anatomy of Macros

Macros are templates that, wherever they match in the source that source is replaced with something else, and text elsewhere can be generated too.
A *head* is a template describing the text that has to be matched to, it is a list of parameters with literal text between these parameters. 
The following kind of parameters exist:
* those preceded by `?`: For a single expression or statement.  These must be followed by a literal token as a delimeter and they match until they hit that token with the following caveats:  
1) the matcher is smart enough to know that ‘(‘ must have ‘)’ to match it, ‘[‘ matches ‘]’ and ‘{‘ matches ‘}’ when it sees one of those while scanning it will automatcially keep scanning till it finds the match, and won’t stop even for the token it’s looking for. It also knows about Lua statements, it knows that `if` ends in `end` that `for` is followed by `do` and then `end` etc.  It will skip over statements as well. *Third of all it WILL stop for a comma or a semicolon.*  If it stops for one of those early and the delimiter it’s looking for is not what it stopped on then the match fails and that macro won’t be substituted.
* those preceded by `?,`:  For multiple expressions or statements.  The same as `?` but in this case it is happy to skip over commas and semicolons.
* those preceded by `??,`: For multiple expressions or statements or *no expression or statement.* The same as `?,` but won’t fail if it finds NOTHING before the delimiter.
* those preceded by `?...`: Dumb matching till literal.  This one knows nothing about lua syntax and simply matches tokens till it sees the literal that came after it in the head.   It doesn’t treat parens specially or statements. 
* finally one with different rules `?1`:  Match *one* token.  In this case it’s not necessary to have a literal token as a delimiter after or before, it knows to take exactly one token and stop.

Note, if the same parameter appears more than once in the head, it’s used as a “guard”.  If both inputs aren’t the same then the match fails.

Here is an example of using `?,` to destructure input and using `@tostring` to report the literals of the expression being logged.
```lua
@macro { 
  head='log(?a,?,b)',
  body=[[io.stderr:write(@tostring(?a),'=',tostring(?a),' ') log(?b)]]
}
@macro { 
  head='log(?a)',
  body=[[io.stderr:write(@tostring(?a),'=',tostring(?a),'\n')]]
}

local A='hello'
local B=' there'
local C='Mom'
local D=55

log(A..B,C,NOTDEFINED,D)
```
which should return
`A .. B=hello there C=Mom NOTDEFINED=nil D=55`

A *body* describes what the text that matches the head will be replaced with.  There are two kinds of bodies, a body can be a template like the head or it can be a function.

In a templated body, parameters are marked with a `?` in front of them.  There is also a new kind of variable that doesn’t exist in the head.  If you mark a name with `%` instead of `?` then it names a local variable instead of naming an input parameter.  For each local a unique name is generated, this solves the problem of “variable capture” and makes macros “hygienic”.   For people not familiar with the problem, this will require some explanation, which I will give later.  Note that variable names and parameter names are taken from the same namespace, it’s an error to try to reuse the name of a parameter as the name of a variable.

Macros have the following sections (all are optional except *head* and *body):* 

`head` - the head is a string listing input parameters and the literal tokens between them.  This is what the text has to match in order to trigger the macro.
`body` - the body can either be a string or a function, th
if it’s a string it’s a list of literal tokens, input parameters, 
`new_tokens`
`sections`
`semantic_function`

