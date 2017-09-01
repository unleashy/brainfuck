import std.stdio,
       std.file;

import docopt;

import executor,
       parser,
       instruction,
       compiler;

enum VERSION = "1.0.0";

enum DOC =
r"brainfuck v" ~ VERSION ~ "

Usage:
    brainfuck [run] [-d | --dump] <filename>
    brainfuck compile [-d | --dump] [--keep-generated] [--compiler=<path>] <filename> [(-- <args>...)]
    brainfuck -h | --help
    brainfuck --version

Options:
    -h --help          Show this screen.
    --version          Show the program's version.
    -d --dump          Dump the instruction stream to a file.
    --compiler=<path>  Use the given `<path>` as the path to the D compiler
                       to use for compiling to an executable. Pass arguments
                       to the D compiler after `--`. [default: dmd]
    --keep-generated   Keep generated D files when the `compile` command is
                       used.
";

private struct Options
{
    import argvalue : ArgValue;

    string filename;
    bool dump;
    bool compile;
    string compilerPath;
    string[] compilerArgs;
    bool keepGenerated;

    static Options parse(ArgValue[string] args)
    {
        return Options(
            args["<filename>"].toString,
            args["--dump"].isTrue,
            args["compile"].isTrue,
            args["--compiler"].toString,
            args["<args>"].asList,
            args["--keep-generated"].isTrue
        );
    }
}

int main(string[] args)
{
    auto opts = Options.parse(docopt.docopt(DOC, args[1 .. $], true, "brainfuck v" ~ VERSION));

    if (!exists(opts.filename)) {
        stderr.writefln("error: could not find a file named %s", opts.filename);
        return 1;
    }

    const filenameNoExt = opts.filename.removeExt();

    try {
        const instrs = Parser(opts.filename).parse();

        if (opts.dump) dumpInstrs(instrs, filenameNoExt ~ ".bfidmp");
        if (opts.compile) {
            import std.path : absolutePath;

            version (Windows) {
                immutable string exeName = filenameNoExt ~ ".exe";
            } else {
                immutable string exeName = filenameNoExt ~ ".o";
            }

            immutable ret = compiler.compile(
                instrs,
                opts.compilerPath,
                opts.compilerArgs,
                absolutePath(exeName),
                opts.keepGenerated
            );

            if (ret != 0) {
                stderr.writefln("Compilation failed (error code %d).", ret);

                return 1;
            }
        } else {
            Executor().execute(instrs);
        }
    } catch (ParserException e) {
        stderr.writefln("error: %s", e.msg);

        return 1;
    }

    return 0;
}

void dumpInstrs(in Instruction[] instrs, in string filename)
{
    import std.conv : to;

    auto file = File(filename, "wb");

    foreach (ref instr; instrs) {
        file.writefln("%s %d", to!string(instr.type), instr.value);
    }
}

string removeExt(in string filename) pure
{
    import std.algorithm.searching : findSplitBefore;

    return findSplitBefore(filename, ".")[0];
}
