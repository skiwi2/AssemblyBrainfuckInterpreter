# AssemblyBrainfuckInterpreter
A Brainfuck Interpreter written in Assembly.

## Compatibility

This program is intended to run under Windows in 32-bit protected mode on a recent Intel CPU.

## Compilation

The program assumes you have NASM and the Borland 5.5 C compiler installed. Both the `nasm` and `bcc32` executables should be available on the classpath. Furthermore some additional configuration might be neccessary to get the Borland 5.5 C compiler to work.

### Additional configuration for the Borland 5.5 C compiler

First find the folder where the `bcc32` executable is located, a common location is in `C:\Borland\BCC55\Bin`.

Then add a `bcc32.cfg` file with the following contents:

> -I"C:\Borland\Bcc55\include"  
> -L"C:\Borland\Bcc55\lib"

And an `ilink32.cfg` file with the following contents:

> -L"C:\Borland\Bcc55\lib"

### Creating the executable

You can obtain an executable by executing the following commands:

1. `nasm -f obj bf-interpreter-console.asm`
3. `bcc32 bf-interpreter-console.obj`