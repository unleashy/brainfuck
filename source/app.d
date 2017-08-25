import std.stdio,
       std.file;

import executor,
       parser,
       instruction;

int main(string[] args)
{
	if (args.length < 2) {
        stderr.writeln("error: please provide a filename");
        return 1;
    }

    immutable filename = args[1];
    if (!exists(filename)) {
        stderr.writeln("error: given file does not exist");
        return 1;
    }

    try {
        Instruction[] instrs = void;

        {
            Parser parser = Parser(filename);
            instrs = parser.parse();
        }

        Executor executor = Executor();
        executor.execute(instrs);
    } catch (ParserException e) {
        stderr.writefln("error: %s", e.msg);

        return 1;
    }

    return 0;
}
