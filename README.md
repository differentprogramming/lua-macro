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
* `@apply` {[macro definitions]} – define and apply local macros inside of another macro.lua  
* `@tostring(expression)`- turn parameter or macro expansion into a string. Especially useful for print out a macro to see how it expands.  Note this system expands from right to left, so that parameters are fully expanded before they’re passed to other macros.  
* `@@` - *Concatinate tokens.*  The same as ## in the C preprocessor.
