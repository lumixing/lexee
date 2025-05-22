## lexee, a configurable lexer
a powerful and configurable lexer for odin

### usage
```odin
package main

import lx "lexee"

Punct :: enum {
    LParen, RParen,
    LBrace, RBrace,
    Semicolon,
}

punct_map := map[string]Punct{
    "(" = .LParen,
    ")" = .RParen,
    "{" = .LBrace,
    "}" = .RBrace,
    ";" = .Semicolon,
}

Keyword :: enum {
    Int,
    Return,
}

keyword_map := map[string]Keyword {
    "int"    = .Int,
    "Return" = .Return,
}

main :: proc() {
    input := `int main() { printf("hello world"); return 0; }`
    tokens, err := lx.lex(input, Punct, punct_map, Keyword, keyword_map)
    if err, ok := err.?; ok {
        /* handle error */
    }
}
```
