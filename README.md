# AssemblyBrainfuckInterpreter
A Brainfuck Interpreter written in Assembly.

## Compatibility

This program is intended to run under Windows in 32-bit protected mode on a recent Intel CPU.

## Compilation

The program assumes you have NASM and MinGW's GCC Compiler installed. Both the `nasm` and `gcc` executables should be available on the classpath.

### Creating the executable

You can obtain the executable by executing the following commands:

1. `nasm -f win32 bf-interpreter.asm`
2. `gcc -o bf-interpreter bf-interpreter.obj`
3. `nasm -f win32 bf-interpreter-console.asm`
4. `gcc -o bf-interpreter-console bf-interpreter-console.obj`