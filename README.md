# Intlang - A toy programming language with a toy compiler

## Introduction
Intlang is a toy programming language.
It's only datatype is the 64 bit signed integer.

## Language structure
An Intlang program is made of functions with names and optionally parameters.

These functions contain statements.

The syntax is C-like.

The language supports C-style comments. Use `//` to start a line comment, `/*` to start a block comment and `*/` to end one.

## Statements
Intlang has 5 kinds of statements:
- expression statements; simply evaluate the expression
- if statements; A condition (non zero is considered true); A block of statements to be executed if the condition holds; optionally a block of statements to be executed otherwise
- break statements; break out of the nearest (or optionally named) loop
- continue statements; starts next iteration of the nearest (or optionally named) loop
- return statements; return the value of the given expression as the final value of the function call
- while statements; continously run the body block of statements while the condition still holds; can optionally be labeled
- assignment statement; reassigns a variable or writes to memory using the indexing operator

Every statement needs to end in a semicolon; even the if and while statements.

## Expressions
It has the following expression kinds:
- variable access
- function call
- int literal
- char literal (evaluates to the unicode codepoint)
- string literal (evaluates to a pointer to read only memory containing the length prefixed codepoints)
- negation (unary prefix -)
- comparators and logical operators (<, <=, >, >=, ==, !=, !, |, &, ~, ^)
- indexing operator (`p[n]`) that accesses the `n`th integer starting at `p`
- arithmetic operators (+, -, *, /, %)

A couple of functions are builtin:
- `read()` returns a decimal integer read from stdin
- `write(i)` writes the given integer (as a decimal with potential minus sign) and a newline to stdout
- `read_c()` reads a utf-8 character from stdin and returns it's codepoint or `-1` in case of eof
- `write_c(c)` writes the utf-8 character with the codepoint `c` to stdout
- `malloc(n)` allocates heap memory for `n` integers and returns a pointer to that memory
- `realloc(p, n)` resizes the heap memory starting at `p` to accommodate for `n` integers
- `free(p)` deallocates the heap memory starting at `p`

The intlang compiler is a toy in multiple aspects:
- It has few safety checks (see [Safety checks](#safety-checks))
- Besides telling you that it could not lex / parse / assemble the program there are no helpful error messages
- It does not optimize the generated code at all resulting in hideous (and slow) assembly
- It doesn't have a register allocation algorithm and thus makes excessive use of the stack
- It only runs on one platform / architecture (see [Supported Systems](#supported-systems))

## Safety checks
There are barely any.

The compiler won't stop you from
- not returning from a function (on my system that's a segfault)
- calling a function with the wrong amount of arguments
- calling a nonexisting function
- not defining a main function
- defining the main function with arguments
- accessing uninitialized variables
- accessing uninitialized memory
- using heap memory after having freed it
- double freeing heap memory

## Supported Systems
Intlang only runs on x86-64 Linux. It needs both `gcc` and `nasm`.

## Example Code
See [`examples/`](https://github.com/Cookie04DE/intlang/tree/master/examples) for a list of example Intlang programs.

## Usage
Compile this binary and run it on one of the examples (or your own program).

`$ intlang calc.il`

In case of success there should now be an executable with the same name (but no extension) next to it.

Now you can run it.

`$ ./calc`
