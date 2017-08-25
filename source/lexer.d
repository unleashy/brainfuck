import std.stdio;

import token;

struct Lexer
{
    private enum CHUNK_SIZE = 4096;

    private File file;
    private char[] currentChunk;
    private size_t cursor = -1;

    this(in string filename)
    {
        file = File(filename, "rb");
    }

    ~this()
    {
        file.close();
    }

    Token next()
    {
        char nextChar = '\0';
        do {
            if (!readMoreIfNeeded()) {
                return Token.EOF;
            }

            nextChar = currentChunk[cursor++];
        } while (!isValidToken(nextChar));

        return cast(Token) nextChar;
    }

    private bool readMoreIfNeeded()
    {
        return cursor >= currentChunk.length ? readMore() : true;
    }

    private bool readMore()
    {
        if (file.eof) return false;

        currentChunk = file.rawRead(new char[CHUNK_SIZE]);
        cursor = 0;

        return true;
    }

    private bool isValidToken(in char c)
    {
        import std.traits : EnumMembers;
        import std.algorithm.searching : any;

        return [EnumMembers!Token].any!(tok => c == tok);
    }
}