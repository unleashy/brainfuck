import std.exception;

import lexer,
       token,
       instruction;

class ParserException : Exception
{
    mixin basicExceptionCtors;
}

struct Parser
{
    private Lexer lexer;

    this(string filename)
    {
        lexer = Lexer(filename);
    }

    Instruction[] parse()
    {
        Instruction[] instrs;
        Token nextToken;

        do {
            nextToken = lexer.next();

            final switch (nextToken) with (Token) {
                case RIGHT_ARROW:
                case LEFT_ARROW:
                    {
                        int val = nextToken == RIGHT_ARROW ? 1 : -1;
                        if (instrs.length > 0 && instrs[$ - 1].type == InstructionType.MOVE) {
                            instrs[$ - 1].value += val;
                        } else {
                            instrs ~= Instruction(InstructionType.MOVE, val);
                        }
                    }
                    break;

                case PLUS:
                case MINUS:
                    {
                        int val = nextToken == PLUS ? 1 : -1;
                        if (instrs.length > 0 && instrs[$ - 1].type == InstructionType.ADD) {
                            instrs[$ - 1].value += val;
                        } else {
                            instrs ~= Instruction(InstructionType.ADD, val);
                        }
                    }
                    break;

                case DOT:
                    instrs ~= Instruction(InstructionType.OUT, 0);
                    break;

                case COMMA:
                    instrs ~= Instruction(InstructionType.IN, 0);
                    break;

                case RIGHT_BRACKET:
                    instrs ~= Instruction(InstructionType.JMPZ, 0);
                    break;

                case LEFT_BRACKET:
                    instrs ~= Instruction(InstructionType.JMPNZ, 0);
                    break;

                case EOF: break;
            }
        } while (nextToken != Token.EOF);

        import std.stdio : File;
        import std.conv : to;
        auto dump = File("instrdump.txt", "wb");

        dump.writeln("Raw:");
        foreach (instr; instrs) {
            dump.writefln!"%s\t\t%d"(to!string(instr.type), instr.value);
        }
        dump.writeln("\n");

        optimize(instrs);

        dump.writeln("Optimized:");
        foreach (instr; instrs) {
            dump.writefln!"%s\t\t%d"(to!string(instr.type), instr.value);
        }
        dump.writeln("\n");

        linkJumps(instrs);

        dump.writeln("Optimized with Jumps linked:");
        foreach (instr; instrs) {
            dump.writefln!"%s\t\t%d"(to!string(instr.type), instr.value);
        }
        dump.write("\n");
        dump.close();

        return instrs;
    }

    private void optimize(ref Instruction[] instrs)
    {
        import std.algorithm.mutation : remove, SwapStrategy;

        Instruction[] newInstrs;
        bool inInitialCommentLoop;
        uint curLevel = 1;

        foreach (i, instr; instrs) with (InstructionType) {
            // remove initial comment loops
            if (i == 0 && instr.type == JMPZ) {
                inInitialCommentLoop = true;
            }

            if (!inInitialCommentLoop && !((instr.type == ADD || instr.type == MOVE) && instr.value == 0)) {
                newInstrs ~= instr;
            }

            if (inInitialCommentLoop && instr.type == JMPZ && i != 0) {
                ++curLevel;
            } else if (inInitialCommentLoop && instr.type == JMPNZ) {
                if (curLevel == 1) {
                    inInitialCommentLoop = false;
                    continue;
                }

                --curLevel;
            }
        }

        instrs = newInstrs;
    }

    private void linkJumps(ref Instruction[] instrs)
    {
        size_t findJmpnz(in size_t from, in uint level)
        {
            uint curLevel = level;

            foreach (i, instr; instrs[from + 1 .. $]) with (InstructionType) {
                if (instr.type == JMPZ) {
                    ++curLevel;
                } else if (instr.type == JMPNZ) {
                    if (curLevel == level) {
                        return from + i + 1;
                    }

                    --curLevel;
                }
            }

            return -1;
        }

        uint jmpLevel;

        foreach (i, ref instr; instrs) with (InstructionType) {
            if (instr.type == JMPZ) {
                ++jmpLevel;

                const jmpnzAt = findJmpnz(i, jmpLevel);
                if (jmpnzAt < 0) {
                    // could not find jmpnz, error out.
                    throw new ParserException("unbalanced brackets.");
                }

                instrs[jmpnzAt].value = cast(int) i;
                instr.value = cast(int) jmpnzAt;
            } else if (instr.type == JMPNZ) {
                --jmpLevel;
            }
        }

        if (jmpLevel != 0) {
            // unbalanced brackets, error out.
            throw new ParserException("unbalanced brackets.");
        }
    }
}
