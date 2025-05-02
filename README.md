# Intlang - A toy programming language with a toy compiler

## Introduction
Intlang is a toy programming language.
It's only datatype is the 64 bit signed integer.

## Language structure
An Intlang program is made of functions with names and a optionally paramters.

These Functions contain statements.

The syntax is C-like.

However: There are no comments; only whitespace is permitted.

## Statements
Intlang has 5 kinds of statements:
- expression statements; simply evaluate the expression
- if statements; A condition (non zero is considered true); A block of statements to be executed if the condition holds; optionally a block of statements to be executed otherwise
- return statements; return the value of the given expression as the final value of the function call
- while statements; continously run the body block of statements while the condition still holds

Every statement needs to end in a semicolon; even the if and while statements.

## Expressions
It has the following expression kinds:
- variable access
- function call
- int literal
- negation (infix -)
- comparators and logical operators (<, <=, >, >=, ==, !=, !, |, &, ~, ^)
- arithmetic operators (+, -, *, /, %)

Two functions are builtin: `read()` which returns a decimal integer read from stdin and `write(i)` which writes the given integer (and a newline) to stdout.

The intlang compiler is a toy in multiple aspects:
- It has few safety checks (see [Safety checks](#markdown-header-safety-checks))
- Besides telling you that it could not lex / parse / assemble the program there are no helpful error messages
- It does not optimize the generated code at all resulting in hideous (and slow) assembly
- It doesn't have a register allocation algorithm and thus makes excessive use of the stack
- It only runs on one platform / architecture (see [Supported Systems](#markdown-header-supported-systems))

## Safety checks
There are barely any.

The compiler won't stop you from
- not returning from a function (on my system that's a segfault)
- calling a function with the wrong amount of arguments
- calling a nonexisting function
- not defining a main function
- defining the main function with arguments
- accessing uninitialized variables

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
