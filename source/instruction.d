enum InstructionType
{
    MOVE,
    ADD,
    OUT,
    IN,
    JMPZ,
    JMPNZ
}

struct Instruction
{
    InstructionType type;
    int value;
}
