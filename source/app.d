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
    brainfuck [-d | --dump] <filename>
    brainfuck -h | --help
    brainfuck --version

Options:
    -h --help  Show this screen.
    --version  Show the interpreter's version.
    -d --dump  Dump the instruction stream to a file.
";

int main(string[] rawArgs)
{
    auto args = docopt.docopt(DOC, rawArgs[1 .. $], true, "brainfuck v" ~ VERSION);

    const filename = args["<filename>"].toString;
    if (!exists(filename)) {
        stderr.writefln("error: could not find a file named %s", filename);
        return 1;
    }

    try {
        Instruction[] instrs = Parser(filename).parse();
        Executor executor = Executor();
        executor.execute(instrs);
    } catch (ParserException e) {
        stderr.writefln("error: %s", e.msg);

        return 1;
    }

    return 0;
}
