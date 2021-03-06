# **Index**

- [**Subroutines**](#subroutines)
  - [**Functions**](#functions)
  - [**Procedures**](#procedures)
  - [**Subroutines call**](#subroutines-call)
  - [**Parameters by value and reference**](#parameters-by-value-and-reference)
  - [**Recursion**](#recursion)

---
---
# **Subroutines**

## **Functions**

> **`monster`** *id* **`(`** *type parameter's id*, ... **`)`** *return type* **`:`**
> 
>   *Instructions list*
> 
>   **`unlock`** *expression*
> 
> **`.~`**

They take any number of parameters or none.

The parameters can be any type and return a scalar type.

The return's *expression* has to be the same type of the *return type*.

---
## **Procedures**

> **`boss`** *id* **`(`** *type parameter's id*, ... **`)`** **`:`**
> 
>   *Instructions list*
> 
> **`.~`**

They're functions that alaways returns de *unit* value.

---
## **Subroutines call**

> **`kill`** *subroutine's id*
> 
> *variable* **`equip`** **`kill`** *moster id*

It can be an expression if its *killing* a **`monster`**, meaning it can be **`equiped`** to a *variable*.
The type of the *variable* has to be the same of the **`monster`**.

---
## **Parameters by value and reference**

> Parameter by reference: **`?`** *parameter's id*

```Playit
boss f(type parameter by value, type ?parameter by reference) :
  Instructions list
  unlock expression
.~
```

When a pointer its passed to a subroutine that expects a parameter by reference,
the value of the pointer its the ine that's passed.

---
## **Recursion**

```Playit
boss p( Parameters ):
  Instructions list
  kill p( Parameters )
  variable equip kill f( Parameters )
.~
```

```Playit
monster f( Parameters ) type:
  Instructions list
  kill p( Parameters )
  unlock expression
.~

variable equip kill f( Parameters )
```

**Example:**

```Playit
monster factorial(Power n) Power:
  Button:
    | n < 0 } unlock 0
    | n == 0 } unlock 1
    | n > 0 } unlock n * kill factorial(n-1)
  .~
.~

Power n
n = joystick ~n: ~
drop ~Factorial of ~, n, ~ is ~, kill factorial(n)
```

Result of the executed code:

```
n: 5
Factorial of 5 is 120
```

[**Next page ->**](08-Compile-and-run.md/#index)

---
---
# **Table of content** <!-- omit in toc -->

- [**Playit Programming language**](../README.md/#playit-programming-language)
- [**Program's Structure**](01-Program-and-files.md/#programs-structure)
- [**Source code file extension**](01-Program-and-files.md/#source-code-file-extension)
- [**Variables identifiers (id's)**](02-Id's-and-types.md/#variables-identifiers-(id's))
  - [**Declaration and initialization of variables**](02-Id's-and-types.md/#declaration-and-initialization-of-variables)
- [**Data types. Scalars**](02-Id's-and-types.md/#data-types-scalars)
  - [**Characters**](02-Id's-and-types.md/#characters)
  - [**Booleans**](02-Id's-and-types.md/#booleans)
  - [**Integers**](02-Id's-and-types.md/#integers)
  - [**Floating point numbers**](02-Id's-and-types.md/#floating-point-numbers)
- [**Data types. Composite**](02-Id's-and-types.md/#data-types-composite)
  - [**Arrays**](02-Id's-and-types.md/#arrays)
  - [**Strings**](02-Id's-and-types.md/#strings)
  - [**Lists**](02-Id's-and-types.md/#lists)
  - [**Records**](02-Id's-and-types.md/#records)
  - [**Variant Records. Unions**](02-Id's-and-types.md/#variant-records-unions)
  - [**Pointers**](02-Id's%20and%20types.md/#pointers)
- [**Expressions**](03-Expressions.md/#expressions)
  - [**Aritmetics**](03-Expressions.md/#aritmetics)
  - [**Boolean**](03-Expressions.md/#boolean)
  - [**Characters**](03-Expressions.md/#characters)
  - [**Arrays and Lists**](03-Expressions.md/#arrays-and-lists)
  - [**Records**](03-Expressions.md/#records)
  - [**Pointers**](03-Expressions.md/#pointers)
- [**Expressions evaluation**](03-Expressions.md/#expressions-evaluation)
  - [**Operators precedence**](03-Expressions.md/#operators-precedence)
  - [**Operators associativity**](03-Expressions.md/#operators-associativity)
  - [**Evaluation order**](03-Expressions.md/#evaluation-order)
- [**Block and Scope**](04-Block-Scope-Comments.md/#block-and-scope)
- [**Comments and White spaces**](04-Block-Scope-Comments.md/#comments-and-white-spaces)
- [**Instructions**](05-Instructions.md/#instructions)
  - [**Assignment**](05-Instructions.md/#assignment)
    - [**Special assignments**](05-Instructions.md/#special-assignments)
  - [**Conditional**](05-Instructions.md/#conditional)
  - [**Loops**](05-Instructions.md/#loops)
  - [**Input/Output**](05-Instructions.md/#inputoutput)
  - [**Map**](05-Instructions.md/#map-(*Under-development*)) (*Under development*)
- [**Flow control structures**](06-Flow-control.md/#flow-control-structures)
  - [**Selection**](06-Flow-control.md/#selection)
  - [**Loops**](06-Flow-control.md/#loops)
    - [**Determined**](06-Flow-control.md/#determined)
    - [**Indetermined**](06-Flow-control.md/#indetermined)
    - [**Loop break**](06-Flow-control.md/#loop-break)
    - [**Skip current iteration**](06-Flow-control.md/#skip-current-iteration)
    - [**Alter current execution**](06-Flow-control.md/#alter-current-execution-(*Under-development*)) (*Under development*)
- [**Examples**](../README.md/#examples)
- [**Compile and run**](08-Compile-and-run.md/#compile-and-run)
  - [**Run unit tests**](08-Compile-and-run.md/#run-unit-tests)
  - [**Get stack here**](08-Compile-and-run.md/#get-stack-here)
- [**Extras**](../README.md/#extras)
