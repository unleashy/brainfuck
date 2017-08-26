import std.stdio,
       std.file;

import docopt;

import executor,
       parser,
       instruction;

enum VERSION = "0.1.0";

enum DOC =
r"brainfuck v" ~ VERSION ~ "

Usage:
    brainfuck [-d | --dump] [-c | -e | --compile | --execute] <filename>
    brainfuck -h | --help
    brainfuck --version

Options:
    -h --help     Show this screen.
    --version     Show the interpreter's version.
    -d --dump     Dump the instruction stream to a file.
    -c --compile  Output a binary file with the instructions that can
                  then be ran directly with `-e <filename>`.
    -e --execute  Execute a compiled file created by `--compile`.
";

enum MAGIC_NUMBER = cast(ubyte[]) "DBFC1";

void dumpInstrs(in Instruction[] instrs, in string filename)
{
    import std.conv : to;

    auto file = File(filename, "wb");

    foreach (ref instr; instrs) {
        file.writefln("%s %d", to!string(instr.type), instr.value);
    }
}

/*
format of a compiled file:

header - MAGIC_NUMBER nul
body   - instruction_type (1 byte) instruction_value (4 bytes)
         ^ repeating until EOF
*/
void compileInstrs(in Instruction[] instrs, in string filename)
{
    auto file = File(filename, "wb");

    // magic number
    file.rawWrite(MAGIC_NUMBER ~ cast(ubyte) 0);

    foreach (ref instr; instrs) {
        file.rawWrite([cast(ubyte) instr.type]);
        file.rawWrite([cast(int) instr.value]);
    }
}

Instruction[] readCompiledInstrs(in string filename)
{
    Instruction[] buf;
    auto file = File(filename, "rb");

    T[] readCheckEof(T)(T[] read) {
        if (file.eof) throw new ParserException("unexpected end of file");
        return read;
    }

    if (readCheckEof(file.rawRead(new ubyte[6]))[0 .. 5] != MAGIC_NUMBER) {
        throw new ParserException("the given file is not valid compiled brainfuck code");
    }

    while (true) {
        const instrType = file.rawRead(new ubyte[1]);
        if (file.eof) break;

        if (instrType[0] < InstructionType.min || instrType[0] > InstructionType.max) {
            throw new ParserException("unknown instruction found when reading file");
        }

        const instrValue = file.rawRead(new int[1]);
        if (file.eof) break;

        buf ~= Instruction(cast(InstructionType) instrType[0], instrValue[0]);
    }

    return buf;
}

string removeExt(in string filename) pure
{
    import std.algorithm.searching : findSplitBefore;

    return findSplitBefore(filename, ".")[0];
}

int main(string[] rawArgs)
{
    auto args = docopt.docopt(DOC, rawArgs[1 .. $], true, "brainfuck v" ~ VERSION);

    const filename = args["<filename>"].toString;
    if (!exists(filename)) {
        stderr.writefln("error: could not find a file named %s", filename);
        return 1;
    }

    const filenameNoExt = filename.removeExt();

    try {
        const instrs = args["--execute"].isTrue ? readCompiledInstrs(filename) : Parser(filename).parse();

        if (args["--dump"].isTrue) dumpInstrs(instrs, filenameNoExt ~ ".bfidmp");
        if (args["--compile"].isTrue) {
            compileInstrs(instrs, filenameNoExt ~ ".bfc");
        } else {
            Executor().execute(instrs);
        }
    } catch (ParserException e) {
        stderr.writefln("error: %s", e.msg);

        return 1;
    }

    return 0;
}
