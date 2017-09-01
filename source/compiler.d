import std.stdio,
       std.file,
       std.path,
       std.format;

import instruction;

private enum SKEL =
q{module %s;

import std.stdio, std.container.array;

pragma(inline, true)
void boundsCheck(ref byte[] data, in ptrdiff_t dataPtr) @trusted
{
    if (dataPtr < 0) {
        import core.stdc.stdlib : exit;
        stderr.writeln("data pointer out of bounds (less than 0)");
        exit(1);
    } else if (dataPtr >= data.length) {
        data.length = dataPtr + 1;
    }
}

void main()
{
    byte[] data;
    data.reserve(30_000);
    ptrdiff_t dataPtr;
    char inptmp;

    data.length = 1;

%s
}

};

private static immutable string[InstructionType] INSTR_MAP;

shared static this()
{
    import std.exception : assumeUnique;
    import std.conv : to;

    string[InstructionType] instrMapBuf;

    instrMapBuf[InstructionType.MOVE]  = `dataPtr %c= %d; boundsCheck(data, dataPtr);`;
    instrMapBuf[InstructionType.ADD]   = `data[dataPtr] %c= %d;`;
    instrMapBuf[InstructionType.OUT]   = `write(cast(char) data[dataPtr]);`;
    instrMapBuf[InstructionType.IN]    = `readf!"%c"(inptmp); data[dataPtr] = cast(byte) inptmp;`;
    instrMapBuf[InstructionType.JMPZ]  = `while (data[dataPtr]) {`;
    instrMapBuf[InstructionType.JMPNZ] = `}`;

    instrMapBuf.rehash;
    INSTR_MAP = assumeUnique(instrMapBuf);
}

int compile(
    in Instruction[] instrs,
    in string compilerPath,
    in string[] compilerArgs,
    in string bfFilename,
    in bool keepGeneratedFile
)
{
    immutable dfileName = keepGeneratedFile ? bfFilename ~ ".d" : tempFileName(bfFilename);
    std.file.write(dfileName, buildCode(instrs, dfileName));
    scope(exit) if (!keepGeneratedFile) std.file.remove(dfileName);

    return callCompiler(
        dfileName,
        bfFilename,
        compilerPath,
        compilerArgs
    );
}

private int callCompiler(
    in string inputFilename,
    in string outputFilename,
    in string compilerPath,
    in string[] compilerArgs
) @trusted
{
    import std.process : spawnProcess, wait;

    return spawnProcess(
        [compilerPath, "-of=" ~ outputFilename] ~ compilerArgs ~ [inputFilename]
    ).wait();
}

private string buildCode(in Instruction[] instrs, in string filename) @safe
{
    import std.array : appender, replicate;
    import std.conv  : to;
    import std.math  : abs;

    auto buffer = appender!(string);

    // reserve space for the largest instruction string times the length of
    // instructions, just to be safe
    buffer.reserve(instrs.length * INSTR_MAP[InstructionType.MOVE].length);

    auto nesting = 1;

    foreach (const ref instr; instrs) {
        if (instr.type != InstructionType.JMPNZ) buffer ~= "\t".replicate(nesting);

        final switch (instr.type) with (InstructionType) {
            case MOVE:
            case ADD:
                buffer ~= format(
                    INSTR_MAP[instr.type],
                    instr.value >= 0 ? '+' : '-',
                    abs(instr.value)
                );

                break;

            case JMPNZ:
                --nesting;
                buffer ~= "\t".replicate(nesting);
                goto case IN;

            case JMPZ:
                ++nesting;
                goto case;

            case OUT:
            case IN:
                buffer ~= INSTR_MAP[instr.type];
        }

        buffer ~= format!" // %s: %s\n"(to!string(instr.type), instr.value);
    }

    return format!SKEL(normalisedModuleName(filename), buffer.data);
}

private string tempFileName(in string bfFilename) @trusted
{
    import std.uuid : sha1UUID;

    return buildNormalizedPath(
        tempDir,
        "brainfuck-d." ~ sha1UUID(bfFilename).toString ~ ".d"
    );
}

private string normalisedModuleName(in string filename) @trusted
{
    import std.regex : ctRegex, replaceAll;
    import std.path  : baseName;

    return replaceAll(baseName(filename, ".d"), ctRegex!`[^A-Za-z0-9_]`, "_");
}
