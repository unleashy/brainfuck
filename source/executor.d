import std.stdio;

import instruction;

struct Executor
{
    private struct Tape
    {
        private byte[] data_;

        void initialize()
        {
            data_.reserve(30_000);
        }

        const(byte[]) data() @property const nothrow pure
        {
            return data_;
        }

        byte opIndex(size_t i)
        {
            expand(i);

            return data_[i];
        }

        byte opIndexAssign(byte value, size_t i)
        {
            expand(i);

            data_[i] = value;
            return value;
        }

        byte opIndexOpAssign(string op)(byte value, size_t i)
        {
            expand(i);

            mixin("data_[i] " ~ op ~ "= value;");
            return data_[i];
        }

        private void expand(size_t i)
        {
            if (i >= data_.length) {
                data_.length = i + 1;
            }
        }
    }

    void execute(ref Instruction[] instrs)
    {
        size_t tapeIndex;
        Tape tape;
        tape.initialize();

        for (int i; i < instrs.length; ++i) {
            const instr = instrs[i];
            final switch (instr.type) with (InstructionType) {
                case MOVE:
                    tapeIndex += instr.value;
                    break;

                case ADD:
                    tape[tapeIndex] += cast(byte) instr.value;
                    break;

                case OUT:
                    write(cast(dchar) tape[tapeIndex]);
                    break;

                case IN:
                    char c;
                    readf!"%c"(c);
                    tape[tapeIndex] = cast(byte) c;
                    break;

                case JMPZ:
                    if (tape[tapeIndex] == 0) {
                        i = instr.value;
                    }
                    break;

                case JMPNZ:
                    if (tape[tapeIndex] != 0) {
                        i = instr.value;
                    }
                    break;
            }
        }
    }
}
